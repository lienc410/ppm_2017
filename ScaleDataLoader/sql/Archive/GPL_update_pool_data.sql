-- Ginnie Project Loans
-- Pool Level
-- Part 1 of 4
-- Script to combine static data
-- Updates CLTV, HPA, FICO, etc.

-- Before execute the script, need to set the dates to run for
DROP TABLE IF EXISTS #tmp_asOf;
--SELECT CAST('#####ASOF#####' AS DATE) asOf INTO #tmp_asOf
SELECT CAST ('1994-02-01' AS DATE) asOf INTO #tmp_asOf
;

-- Before execute the script, need to set the tickers
DROP TABLE IF EXISTS #ticker;
CREATE TABLE #ticker(
    tickerName varchar(20),
    mtgRateSeries varchar(30)
)
;
INSERT #ticker SELECT 'GPL', 'GNM_PL';   --Ginnie Project Loan
COMMIT;

CREATE LF INDEX tickerName_idx ON #ticker(tickerName);
COMMIT;


-- Creates the 30 YR FRM Rate (point adjusted)
DROP TABLE IF EXISTS #Mtg30YrRates_monthly;
SELECT
    TickerName as SeriesName,
    AsOfDate as asOf, 
    convert(date, dateadd(month, +1, AsOfDate)) as asOf_lag1,
    convert(date, dateadd(month, +2, AsOfDate)) as asOf_lag2,
    convert(date, dateadd(month, +3, AsOfDate)) as asOf_lag3,
    SeriesNumValue as MtgRate
INTO #Mtg30YrRates_monthly
FROM report.TimeSeries ts
JOIN report.TimeSeriesMeta tsm
    ON ts.TimeSeriesMetaId = tsm.TimeSeriesMetaId
WHERE 1=1
    AND Source = 'PIV'
    AND SeriesType = 'MONTHLY_MTG_RATE'
    AND ModelType = 'ScaleMtgRateModel v2.0'
;
COMMIT;

CREATE LF INDEX series_idx ON #Mtg30YrRates_monthly(SeriesName);
CREATE LF INDEX asOf_idx ON #Mtg30YrRates_monthly(asOf);
CREATE LF INDEX asOf_lag1_idx ON #Mtg30YrRates_monthly(asOf_lag1);
CREATE LF INDEX asOf_lag2_idx ON #Mtg30YrRates_monthly(asOf_lag2);
CREATE LF INDEX asOf_lag3_idx ON #Mtg30YrRates_monthly(asOf_lag3);

COMMIT;

-- Create Origination Data
DROP TABLE IF EXISTS #GPL_Pool;
SELECT
    ps.issueId,
    ps.poolNumber,
    ps.loanNumber,
    tk.tickerName as marketTicker,
    ps.poolType,
    ps.term,
    ps.origIssueAmount,
    ps.issuerName as origIssuer,
    ps.loanInterestRate,
    ps.securityInterestRate,
    ps.fhaNumber,
    ps.fhaProgram,
    ps.cityLocated,
    ps.stateLocated,
    ps.poolIsUnique,
    ps.poolInDeal,
    CASE WHEN ps.associatedPoolNumber IS NULL THEN 'N' ELSE 'Y' END as beganAsConstructionLoan,
    pns.issueDate,
    CASE 
        WHEN ps.firstPaymentDate IS NULL THEN dateadd(month, +1, pns.issueDate) 
        WHEN ps.firstPaymentDate < '1950-01-01' THEN dateadd(month, +1, pns.issueDate) 
        ELSE ps.firstPaymentDate
    END as firstPaymentDate,
    pns.lockoutEndDate,
    pns.prepayPenaltyEndDate,
    pns.maturityDate,
    pns.globalPenaltyCode,
    ps.payoffDate,
    ps.payoffType,
    cast(NULL as NUMERIC(16,2)) as histPenaltyAmount,
    cast(0 as TINYINT)  as isEstimate
INTO #GPL_Pool
FROM project_loan.SecPoolSummary sps
JOIN project_loan.PoolSummary ps
    ON sps.poolNumber = ps.poolNumber
JOIN #ticker tk
    ON 'GPL' = tk.tickerName
JOIN project_loan.PenaltySummary pns
    ON ps.loanNumber = pns.loanNumber
WHERE 1=1
;
COMMIT;

-- Update Actual Payoff Info
UPDATE #GPL_Pool gp SET 
    gp.histPenaltyAmount = hpp.penaltyAmount,
    gp.isEstimate = hpp.isEstimate
FROM project_loan.HistoricalPoolPayoff hpp
WHERE 1=1
    AND gp.loanNumber = hpp.loanNumber
    AND hpp.penaltyAmount IS NOT NULL
;
COMMIT;


-- Create Historical Data
DROP TABLE IF EXISTS #GPL_PoolHist;
SELECT
    ps.issueId,
    ps.poolNumber,
    ps.loanNumber,
    tk.tickerName as marketTicker,
    sfps.asOf, --factor date
    CASE WHEN sfps.schambalance IS NULL THEN sfps.currentBalance ELSE sfps.schambalance END as balance,
    CASE 
        WHEN datediff(month, ps.firstPaymentDate, sfps.asOf) + 1 >= -1 THEN datediff(month, ps.firstPaymentDate, sfps.asOf) + 1
        ELSE datediff(month, ps.issueDate, sfps.asOf)
    END as wala,
    datediff(month, sfps.asOf, ps.maturityDate) + 1 as wam,

    sfps.issuerName,

    pts.canPrepay,
    pts.penaltyRate,
    pts.penaltyAmount,

    cast(0 as smallint) as hasDelinqInfo,
    cast(NULL as VARCHAR(3)) as delinqStatus,
    cast(NULL as smallint) as isDelinq,
    cast(NULL as smallint) as ageSinceLastCurrent,
    cast(NULL as smallint) as monthsInStatus,
    cast(NULL as smallint) as monthsInStatus_DQ,

    cast(NULL as smallint) as monthsToReset,
    cast(NULL as smallint) as monthsSinceReset,
    cast(NULL as smallint) as monthsSinceLockoutEndDate,
    cast(NULL as VARCHAR(4)) as penaltyCycle,
    mtg.MtgRate,
    100.0 * (ps.loanInterestRate - mtg.MtgRate) as penaltyNonAdjustedIncentive
INTO #GPL_PoolHist
FROM #GPL_Pool ps
JOIN #ticker tk
    ON ps.marketTicker = tk.tickerName
JOIN project_loan.SecFactorPoolSummary sfps
    ON ps.poolNumber = sfps.poolNumber
JOIN project_loan.PenaltyTimeSeries pts
    ON ps.loanNumber = pts.loanNumber
    AND pts.asOf = sfps.asOf
JOIN #Mtg30YrRates_monthly mtg
    ON sfps.asOf = mtg.asOf_lag2 -- (2 month lag impossed here, factor date lag of 2 months)
    AND mtg.SeriesName = tk.mtgRateSeries
WHERE 1=1
    AND sfps.asOf >= (select asOf from #tmp_asOf)
    AND wala >= -1
;
COMMIT;

-- Update Delinquency Info
UPDATE #GPL_PoolHist fp SET 
    fp.hasDelinqInfo = 1,
    fp.delinqStatus = pd.delinqStatus,
    fp.isDelinq = pd.isDelinq,
    fp.ageSinceLastCurrent = pd.ageSinceLastCurrent,
    fp.monthsInStatus = pd.monthsInStatus,
    fp.monthsInStatus_DQ = pd.monthsInStatus_DQ
FROM project_loan.PoolDelinquency pd
WHERE 1=1
    AND fp.poolNumber = pd.poolNumber
    AND fp.asOf = pd.asOf
    AND pd.delinqStatus IS NOT NULL
;
COMMIT;

-- Update Delinquency Info (last status)
UPDATE #GPL_PoolHist fp SET 
    fp.hasDelinqInfo = 1,
    fp.delinqStatus = pd.delinqStatus,
    fp.isDelinq = pd.isDelinq,
    fp.ageSinceLastCurrent = pd.ageSinceLastCurrent,
    fp.monthsInStatus = pd.monthsInStatus,
    fp.monthsInStatus_DQ = pd.monthsInStatus_DQ
FROM project_loan.PoolDelinquency pd
WHERE 1=1
    AND fp.poolNumber = pd.poolNumber
    AND fp.asOf = dateadd(month, 1, pd.asOf)
    AND pd.delinqStatus IS NOT NULL
    AND fp.delinqStatus IS NULL
;
COMMIT;

-- Update MonthsToReset
UPDATE #GPL_PoolHist fp SET fp.monthsToReset = datediff(month, fp.asOf, pm.endDate)
FROM project_loan.PenaltyRateMatrix pm
WHERE 1=1
    AND fp.loanNumber = pm.loanNumber
    AND fp.asOf >= pm.startDate
    AND fp.asOf < pm.endDate
;
COMMIT;

-- Update MonthsSinceReset
UPDATE #GPL_PoolHist fp SET fp.monthsSinceReset = datediff(month, pm.startDate, fp.asOf)
FROM project_loan.PenaltyRateMatrix pm
WHERE 1=1
    AND fp.loanNumber = pm.loanNumber
    AND fp.asOf >= pm.startDate
    AND fp.asOf < pm.endDate
;
COMMIT;

-- Update MonthsSinceLockoutEndDate
UPDATE #GPL_PoolHist fp SET fp.monthsSinceLockoutEndDate = CASE WHEN p.lockoutEndDate IS NOT NULL THEN datediff(month, p.lockoutEndDate, fp.asOf) ELSE fp.wala END
FROM #GPL_Pool p
WHERE 1=1
    AND fp.loanNumber = p.loanNumber
;
COMMIT;

-- Update PenaltyCycle
--UPDATE #GPL_PoolHist SET penaltyCycle = CASE WHEN monthsToReset = 1 THEN '0001' WHEN monthsSinceReset = 0 THEN '0011' WHEN monthsSinceReset = 1 THEN '1100' WHEN monthsSinceReset = 2 THEN '1000' ELSE '0000' END;
--UPDATE #GPL_PoolHist SET penaltyCycle = CASE WHEN wala < 12 THEN '0000' ELSE penaltyCycle END
--COMMIT;
UPDATE #GPL_PoolHist SET penaltyCycle = CASE WHEN monthsToReset = 2 THEN '0001' WHEN monthsToReset = 1 THEN '0011' WHEN monthsSinceReset = 0 THEN '1100' WHEN monthsSinceReset = 1 THEN '1000' ELSE '0000' END;
UPDATE #GPL_PoolHist SET penaltyCycle = CASE WHEN wala < 10 THEN '0000' ELSE penaltyCycle END
;
COMMIT;
--UPDATE #GPL_PoolHist SET penaltyCycle = CASE WHEN monthsToReset = 3 THEN '0001' WHEN monthsToReset = 2 THEN '0011' WHEN monthsToReset = 1 THEN '1100' WHEN monthsSinceReset = 0 THEN '1000' ELSE '0000' END;
--UPDATE #GPL_PoolHist SET penaltyCycle = CASE WHEN wala < 12 THEN '0000' ELSE penaltyCycle END
;
--COMMIT;



-- Load Data into Scale Tables
DELETE FROM scale.GPL_Pool
WHERE marketTicker IN (SELECT tickerName FROM #ticker)
;

INSERT INTO scale.GPL_Pool 
(
    issueId, 
    poolNumber, 
    loanNumber, 
    marketTicker, 
    poolType, 
    term, 
    origIssueAmount, 
    origIssuer, 
    loanInterestRate, 
    securityInterestRate, 
    fhaNumber, 
    fhaProgram, 
    cityLocated, 
    stateLocated, 
    poolIsUnique, 
    poolInDeal,
    beganAsConstructionLoan,
    issueDate, 
    firstPaymentDate, 
    lockoutEndDate, 
    prepayPenaltyEndDate, 
    maturityDate, 
    globalPenaltyCode, 
    payoffDate, 
    payoffType, 
    histPenaltyAmount, 
    isEstimate
)
SELECT
    issueId, 
    poolNumber, 
    loanNumber, 
    marketTicker, 
    poolType, 
    term, 
    origIssueAmount, 
    origIssuer, 
    loanInterestRate, 
    securityInterestRate, 
    fhaNumber, 
    fhaProgram, 
    cityLocated, 
    stateLocated, 
    poolIsUnique, 
    poolInDeal,
    beganAsConstructionLoan,
    issueDate, 
    firstPaymentDate, 
    lockoutEndDate, 
    prepayPenaltyEndDate, 
    maturityDate, 
    globalPenaltyCode, 
    payoffDate, 
    payoffType, 
    histPenaltyAmount, 
    isEstimate
FROM #GPL_Pool
WHERE marketTicker IN (SELECT tickerName FROM #ticker)
;

DELETE FROM scale.GPL_PoolHist
FROM scale.GPL_PoolHist sph, scale.GPL_Pool sp
WHERE 1=1
    AND sph.loanNumber = sp.loanNumber
    AND sp.marketTicker IN (SELECT tickerName FROM #ticker)
    AND sph.asOf >= (SELECT asOf from #tmp_asOf)
;

INSERT INTO scale.GPL_PoolHist 
(
    issueId, 
    poolNumber, 
    loanNumber,  
    asOf, 
    balance, 
    wala, 
    wam, 
    issuerName, 
    canPrepay, 
    penaltyRate, 
    penaltyAmount, 
    hasDelinqInfo, 
    delinqStatus, 
    isDelinq, 
    ageSinceLastCurrent, 
    monthsInStatus, 
    monthsToReset,
    monthsSinceReset,
    monthsSinceLockoutEndDate,
    penaltyCycle,
    penalty_non_adjusted_incentive
)
SELECT
    issueId, 
    poolNumber, 
    loanNumber, 
    asOf, --store data by Factor Date 
    balance, 
    wala, 
    wam, 
    issuerName, 
    canPrepay, 
    penaltyRate, 
    penaltyAmount, 
    hasDelinqInfo, 
    delinqStatus, 
    isDelinq, 
    ageSinceLastCurrent, 
    monthsInStatus, 
    monthsToReset,
    monthsSinceReset,
    monthsSinceLockoutEndDate,
    penaltyCycle,
    penaltyNonAdjustedIncentive
FROM #GPL_PoolHist
WHERE marketTicker IN (SELECT tickerName FROM #ticker)
    AND asOf >=  (SELECT asOf from #tmp_asOf)
;

