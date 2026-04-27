-- Ginnie Project Loans
-- Pool Level
-- Part 3 of 4
-- Script to update the refinance incentive metrics
-- Updates penalty_adjusted_refi_incentive

-- Before execute the script, need to set the dates to run for
DROP TABLE IF EXISTS #tmp_asOf;
--SELECT CAST('#####ASOF#####' AS DATE) asOf INTO #tmp_asOf
SELECT CAST ('1994-02-01' AS DATE) asOf INTO #tmp_asOf
;

-- Before execute the script, need to set the version to run for
DROP TABLE IF EXISTS #tmp_version;
SELECT CAST ('1.30' AS varchar(5)) version INTO #tmp_version
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


-- Save Pool Data
DROP TABLE IF EXISTS #GPL_PoolIncentive;
SELECT
    sp.marketTicker,
    sph.issueId,
    sph.poolNumber,
    sph.loanNumber,
    sph.asOf, -- Factor Date
    sph.balance,
    sph.canPrepay,
    100.0 * (sp.loanInterestRate - (mtg.MtgRate + sph.penaltyRate / 10.0)) as pp_refi_incentive,
    CASE
        WHEN sph.canPrepay = 1 THEN pp_refi_incentive
        ELSE -9999.0 
    END as mod_pp_refi_incentive,
    cast(NULL as Numeric(10, 4)) as max_pp_refi_incentive
INTO #GPL_PoolIncentive
FROM scale.GPL_Pool sp
JOIN scale.GPL_PoolHist sph
    ON sp.loanNumber = sph.loanNumber
JOIN #ticker tk
    ON sp.marketTicker = tk.tickerName
JOIN #Mtg30YrRates_monthly mtg
    ON sph.asOf = mtg.asOf_lag2 -- (2 month lag impossed here, factor date lag of 2 months)
    AND mtg.SeriesName = tk.mtgRateSeries
WHERE 1=1
    AND sph.asOf >= (select asOf from #tmp_asOf)
;
COMMIT;


-- Calculate the Max Life Incentive
DROP TABLE IF EXISTS #max_incentive;
SELECT
    t.loanNumber,
    t.poolNumber, 
    t.asOf, --factor date
    t.mod_pp_refi_incentive,
    max(t2.mod_pp_refi_incentive) as max_penalty_adjusted_incentive
INTO #max_incentive
FROM #GPL_PoolIncentive t, #GPL_PoolIncentive t2
WHERE 1=1
    AND t.loanNumber  = t2.loanNumber
    AND t.poolNumber = t2.poolNumber
    AND datediff(mm, t.asOf, t2.asOf) <= -2  --two month lag
    AND t.mod_pp_refi_incentive IS NOT NULL
GROUP BY  t.loanNumber, t.poolNumber, t.asOf, t.mod_pp_refi_incentive
;
COMMIT;

UPDATE #max_incentive SET max_penalty_adjusted_incentive = NULL WHERE max_penalty_adjusted_incentive <= -9999.0;
COMMIT;

UPDATE #GPL_PoolIncentive i SET i.max_pp_refi_incentive = mx.max_penalty_adjusted_incentive
FROM #max_incentive mx
WHERE i.loanNumber = mx.loanNumber
    AND i.poolNumber = mx.poolNumber
    AND i.asOf = mx.asOf
;
COMMIT;
UPDATE #GPL_PoolIncentive SET max_pp_refi_incentive = 0.0 WHERE max_pp_refi_incentive IS NULL and canPrepay = 1;
COMMIT;



-- Load Data into Scale Incentive Table
DELETE FROM scale.GPL_PoolIncentive
FROM scale.GPL_PoolIncentive spi, scale.GPL_Pool sp
WHERE 1=1
    AND spi.loanNumber = sp.loanNumber
    AND sp.marketTicker IN (SELECT tickerName FROM #ticker)
    AND spi.asOf >= (SELECT asOf from #tmp_asOf)
    AND version = (SELECT version from #tmp_version)
;


INSERT INTO scale.GPL_PoolIncentive (issueId, poolNumber, loanNumber, asOf, version, penalty_adjusted_incentive, max_penalty_adjusted_incentive)
SELECT
    issueId,
    poolNumber,
    loanNumber,
    asOf, --factor date
    version ,
    pp_refi_incentive,
    max_pp_refi_incentive
FROM #GPL_PoolIncentive
JOIN #tmp_version on 1=1
WHERE marketTicker IN (SELECT tickerName FROM #ticker)
    AND asOf >= (SELECT asOf from #tmp_asOf)
;

