-- Fannie Conventional
-- Pool Level
-- Part 6 of 6
-- Script to update the burnout metrics
-- Updates Burnout

-- Before execute the script, need to set the version to run for
DROP TABLE IF EXISTS #tmp_version;
SELECT CAST ('2.50' AS varchar(5)) version INTO #tmp_version
;

-- Before execute the script, need to set the dates to run for
DROP TABLE IF EXISTS #tmp_asOf;
SELECT CAST('#####ASOF#####' AS DATE) asOf INTO #tmp_asOf
--SELECT CAST ('1994-01-01' AS DATE) asOf INTO #tmp_asOf
;

-- Before execute the script, need to set the tickers
DROP TABLE IF EXISTS #ticker;
CREATE TABLE #ticker(
    tickerName varchar(20),
    mtgRateSeries varchar(30)
)
;
INSERT #ticker SELECT 'FNCL', 'CONVENTIONAL_30YR';    --Conventional Fannie
INSERT #ticker SELECT 'FNCK', 'JUMBO_30YR';           --Jumbo Fannie
INSERT #ticker SELECT 'FNCQ30', 'CONVENTIONAL_30YR';  --CQ Fannie High LTV[105-125]
INSERT #ticker SELECT 'FNCR', 'CONVENTIONAL_30YR';    --CR Fannie High LTV[125-150]
COMMIT;

CREATE LF INDEX loan_tickerName_idx ON #ticker(tickerName);
COMMIT;


-- Creates the 30 YR FRM Rate (point adjusted)
DROP TABLE IF EXISTS #Mtg30YrRates_monthly;
SELECT
    TickerName as SeriesName,
    AsOfDate as asOf, 
    convert(date, dateadd(month, +1, AsOfDate)) as asOf_lag1,
    convert(date, dateadd(month, +2, AsOfDate)) as asOf_lag2,
    SeriesNumValue as MtgRate
INTO #Mtg30YrRates_monthly
FROM report.TimeSeries ts
JOIN report.TimeSeriesMeta tsm
    ON ts.TimeSeriesMetaId = tsm.TimeSeriesMetaId
WHERE 1=1
    AND SeriesType = 'MONTHLY_MTG_RATE'
	AND ModelType = 'ScaleMtgRateModel v2.0'
;
COMMIT;

CREATE LF INDEX series_idx ON #Mtg30YrRates_monthly(SeriesName);
CREATE LF INDEX asOf_idx ON #Mtg30YrRates_monthly(asOf);
CREATE LF INDEX asOf_lag1_idx ON #Mtg30YrRates_monthly(asOf_lag1);
CREATE LF INDEX asOf_lag2_idx ON #Mtg30YrRates_monthly(asOf_lag2);

COMMIT;

-- Create history of asOf dates
DROP TABLE IF EXISTS #unique_dates;
SELECT convert(date,dateadd(month, -num, mn.asOf)) as asOf
INTO #unique_dates
FROM report.nums,
(SELECT convert(date, dateadd(day, -datepart(day, getdate()) + 1, getdate())) asOf) mn
;
COMMIT;

-- Create Pool Historical Data
DROP TABLE IF EXISTS #FNM_PoolBurnout;
SELECT
    ph.marketTicker,
    ph.issueId,
    ph.asOf,
    ph.originationDate,
    ph.balance,
    p.issueDate,
    ph.origNoteRate, 
    pe.HARP_eligible,
    pe.conventional_eligible,
    pe.fha_eligible,
    pe.refi_eligible,
    mr.MtgRate,
    cast(0 as tinyint) as has_loan_data,
    spi.origPMI,
    spi.currPMI,
    spi.currLLPA,
    spi.currMIP,
	spi.conventional_refi_incentive,
    spi.fha_refi_incentive,
    cast(NULL as NUMERIC(10,4)) as burnout
INTO #FNM_PoolBurnout
FROM scale.FNM_PoolHist ph
JOIN #ticker tk
    ON ph.marketTicker = tk.tickerName
JOIN fnm.sec p
    ON ph.issueId = p.issueId
JOIN fnm.Prefix x
    ON p.prefix = x.prefix
    AND p.product = x.product
JOIN scale.FNM_PoolEligibility pe
    ON ph.issueId = pe.issueId
    AND ph.asOf = pe.asOf
JOIN scale.FNM_PoolIncentive spi
    ON ph.issueId = spi.issueId
    AND ph.asOf = spi.asOf
JOIN #Mtg30YrRates_monthly mr
    ON mr.asOf_lag1 = spi.asOf
    AND mr.SeriesName = tk.mtgRateSeries
WHERE 1=1
    AND spi.version = '2.41' --(select version from #tmp_version)
;
COMMIT;

CREATE HG INDEX issueId_idx ON #FNM_PoolBurnout(issueId);
CREATE LF INDEX asOf_idx ON #FNM_PoolBurnout(asOf);
CREATE LF INDEX ticker_idx ON #FNM_PoolBurnout(marketTicker);
COMMIT;

------------------------------------------------------------
-- Step 1: Compute Burnout by Rolling up Loan Data
------------------------------------------------------------
DROP TABLE IF EXISTS #FNM_LoanBasedBurnout;
SELECT
    pb.issueId,
    pb.asOf,
    sum(slb.burnout * slh.balance) / sum(CASE WHEN slb.burnout IS NULL THEN 0.0 ELSE slh.balance END) as wavg_burnout
INTO #FNM_LoanBasedBurnout
FROM #FNM_PoolBurnout pb
JOIN fnm.PIV_Loan cl
    ON pb.issueId = cl.issueId
JOIN scale.FNM_Loan sl
    ON cl.loanSeqNum = sl.loanSeqNum
JOIN scale.FNM_LoanHist slh
    ON sl.loanSeqNum = slh.loanSeqNum
    AND pb.asOf = slh.asOf
JOIN scale.FNM_LoanBurnout slb
    ON slh.loanSeqNum = slb.loanSeqNum
    AND slh.asOf = slb.asOf
WHERE 1=1
    AND slb.version = (select version from #tmp_version)
GROUP BY pb.issueId, pb.asOf
;
COMMIT;

---------------------------------------------------------
-- Step 2: Update Pool Burnout with Loan Level Burnout
---------------------------------------------------------
UPDATE #FNM_PoolBurnout pb SET
    pb.burnout = lb.wavg_burnout
FROM #FNM_LoanBasedBurnout lb
WHERE pb.issueId = lb.issueId
    AND pb.asOf = lb.asOf
;

UPDATE #FNM_PoolBurnout pb SET has_loan_data = 1
WHERE pb.issueId IN (SELECT distinct issueId FROM #FNM_LoanBasedBurnout WHERE wavg_burnout IS NOT NULL)
COMMIT;

---------------------------------------------------------
-- Update Incenitve for Pools w/ no burnout from loans
---------------------------------------------------------
DROP TABLE IF EXISTS #FNM_PoolIncentive;
SELECT 
    pb.asof,
    pb.issueId,
    CASE WHEN HARP_eligible >= conventional_eligible THEN HARP_eligible ELSE conventional_eligible END / 100 * conventional_refi_incentive AS conventional_incentive,
    fha_eligible / 100.0                                                                                     * fha_refi_incentive          AS fha_incentive,
    CASE WHEN fha_incentive >= conventional_refi_incentive THEN fha_incentive ELSE conventional_refi_incentive END as incentive
INTO #FNM_PoolIncentive
FROM #FNM_PoolBurnout pb
WHERE 1=1
    AND pb.burnout IS NULL
;
COMMIT;


DROP TABLE IF EXISTS #FNM_PoolIncentive_LoanSize;
SELECT 
    tpi.issueId,
    tpi.asOf,
    currLoanSize,
    CASE WHEN tpi.conventional_incentive > 200 THEN 200 ELSE tpi.conventional_incentive END   AS conventional_incentive,
    CASE WHEN tpi.fha_incentive          > 200 THEN 200 ELSE tpi.fha_incentive END            AS fha_incentive,
    CASE WHEN fha_incentive >= conventional_incentive THEN fha_incentive ELSE conventional_incentive END as incentive
INTO #FNM_PoolIncentive_LoanSize
FROM #FNM_PoolIncentive tpi
JOIN scale.FNM_PoolHist sph ON tpi.issueId = sph.issueId AND tpi.asOf = sph.asOf
;
COMMIT;

CREATE HG INDEX issueId_idx ON #FNM_PoolIncentive_LoanSize(issueId);
CREATE LF INDEX asOf_idx ON #FNM_PoolIncentive_LoanSize(asOf);
COMMIT;


---------------------------------------------------------
-- Step 3: Update Missing Burnout Data (Latest Date)
---------------------------------------------------------
DROP TABLE IF EXISTS #FNM_LoanLatestBurnout;
SELECT
    pb.issueId,
    o.max_asOf,
    pb.burnout as max_burnout
INTO #FNM_LoanLatestBurnout
FROM #FNM_PoolBurnout pb
JOIN (
        SELECT
            issueId,
            max(asOf) as max_asOf
        FROM #FNM_PoolBurnout
        WHERE has_loan_data = 1
            AND burnout IS NOT NULL
        GROUP BY issueId
    ) o
    ON pb.issueId = o.issueId
    AND pb.asOf = o.max_asOf
;

DROP TABLE IF EXISTS #FNM_PoolLastDate;
SELECT
    issueId,
    max(asOf) as max_asOf
INTO #FNM_PoolLastDate
FROM #FNM_PoolBurnout 
WHERE has_loan_data = 1
GROUP BY issueId
;

UPDATE #FNM_PoolBurnout pb SET burnout = llb.max_burnout + (CASE WHEN incentive <= 0.0 THEN 0.0 ELSE incentive END)
FROM #FNM_LoanLatestBurnout llb, #FNM_PoolLastDate pld, #FNM_PoolIncentive_LoanSize pils
WHERE 1=1
    AND llb.issueId = pld.issueId
    AND pb.issueId = llb.issueId
	AND pb.issueId = pils.issueId
    AND pb.asOf = pld.max_asOf
    AND llb.max_asOf != pld.max_asOf
	AND pb.asOf = pils.asOf
    AND pb.has_loan_data = 1
    AND pb.burnout IS NULL
;
COMMIT;

---------------------------------------------------------------
-- Step 4: Update Missing Burnout Data (Earliest Dates)
---------------------------------------------------------------

-- Calculate Burnout from Relative Incentive
DROP TABLE IF EXISTS #FNM_EarliestLoanBasedBurnout;
SELECT  
    t0.issueId,
    t0.asOf as asOf,
    sum(CASE 
                    WHEN t1.incentive <= 0.0 THEN 0.0
                    ELSE t1.incentive
                END) as burnout
INTO #FNM_EarliestLoanBasedBurnout
FROM #FNM_PoolIncentive_LoanSize t0
JOIN #FNM_PoolIncentive_LoanSize t1
    ON t0.issueId = t1.issueId
    AND t0.asOf > t1.asOf
WHERE t0.asOf >= (select asOf from #tmp_asOf)
GROUP BY t0.issueId, t0.asOf
;
COMMIT;

-- Update Pool Burnout with Earliest Loan Burnout
UPDATE #FNM_PoolBurnout pb SET
    pb.burnout = elb.burnout
FROM #FNM_EarliestLoanBasedBurnout elb
WHERE pb.issueId = elb.issueId
    AND pb.asOf = elb.asOf
    AND pb.burnout IS NULL
;
COMMIT;


----------------------------------------------------------------------------------
-- Step 1: Calculate Relative Incentive for Pools (w/ no burnout from loans)
-- Calculate Burnout from Relative Incentive
------------------------------------------------------------
DROP TABLE IF EXISTS #FNM_PoolBasedBurnout;
SELECT  
    t0.issueId,
    t0.asOf as asOf,
    sum(CASE 
                    WHEN t1.incentive <= 0.0 THEN 0.0
                    ELSE t1.incentive
                END) as burnout
INTO #FNM_PoolBasedBurnout
FROM #FNM_PoolIncentive_LoanSize t0
JOIN #FNM_PoolIncentive_LoanSize t1
    ON t0.issueId = t1.issueId
    AND t0.asOf > t1.asOf
WHERE t0.asOf >= (select asOf from #tmp_asOf)
GROUP BY t0.issueId, t0.asOf
;
COMMIT;

------------------------------------------------------------
-- Step 2: Calculate Burnout for Missing Early Dates
------------------------------------------------------------
DROP TABLE IF EXISTS #FNM_Earliest;
SELECT
    pbb.issueId,
    o.first_asOf,
    pb.issueDate as originationDate,
    pb.origNoteRate,
    pb.marketTicker,
    cast(0.0 as numeric(10, 4)) as burnout
INTO #FNM_Earliest
FROM #FNM_PoolBasedBurnout pbb
JOIN #FNM_PoolBurnout pb
    ON pbb.issueId = pb.issueId
    AND pbb.asOf = pb.asOf 
JOIN (
        SELECT
            issueId,
            min(asOf) as first_asOf
        FROM #FNM_PoolBasedBurnout
        GROUP BY issueId
    ) o
    ON pb.issueId = o.issueId
    AND pb.asOf = o.first_asOf
;
COMMIT;

-- Create missing periods from origination date to first asOf date
DROP TABLE IF EXISTS #FNM_MissingHist;
SELECT 
    e.issueId, 
    t.asOf, 
    e.origNoteRate,
    mtg.MtgRate
INTO #FNM_MissingHist
FROM #FNM_Earliest e
JOIN #unique_dates t
    ON t.asOf > e.originationDate
    AND t.asOf <= e.first_asOf
JOIN #ticker tk
    ON e.marketTicker = tk.tickerName
JOIN #Mtg30YrRates_monthly mtg
    ON mtg.asOf_lag1 = t.asOf
    AND mtg.SeriesName = tk.mtgRateSeries
;
COMMIT;

CREATE HG INDEX issueId_idx ON #FNM_MissingHist(issueId);
CREATE LF INDEX asOf_idx ON #FNM_MissingHist(asOf);
COMMIT;

-- Historical Burnout computation
-- Simple Calculation involving MortgageRate and Note Rate
DROP TABLE IF EXISTS #FNM_PoolBurnoutHist;
SELECT 
    t0.issueId,
    t0.asOf,
    sum(CASE WHEN t1.origNoteRate - t1.MtgRate <= 0.0 THEN 0.0 ELSE t1.origNoteRate - t1.MtgRate END) as burnout
INTO #FNM_PoolBurnoutHist
FROM #FNM_MissingHist t0
JOIN #FNM_MissingHist t1
    ON t0.issueId = t1.issueId
WHERE t0.asOf >= (select asOf from #tmp_asOf)
GROUP BY t0.issueId, t0.asOf
;
COMMIT;

-- Update Burnout for first instance
UPDATE #FNM_Earliest e SET e.burnout = bh.burnout
FROM #FNM_PoolBurnoutHist bh
WHERE bh.issueId = e.issueId
    AND bh.asOf = e.first_asOf;
COMMIT;

-- Update Burnout with Historical Burnout
UPDATE #FNM_PoolBasedBurnout b SET b.burnout = b.burnout + e.burnout
FROM #FNM_Earliest e
WHERE b.issueId = e.issueId
;
COMMIT;

-- Update FNM_PoolBurnout Table
UPDATE #FNM_PoolBurnout pb SET pb.burnout = pbb.burnout
FROM #FNM_PoolBasedBurnout pbb
WHERE pb.issueId = pbb.issueId
    AND pb.asOf = pbb.asOf
    AND pb.burnout IS NULL
    AND pb.has_loan_data = 0
;
COMMIT;

-- Update FNM_PoolBurnout Table with empty cells
UPDATE #FNM_PoolBurnout pb SET pb.burnout = 0.0
WHERE pb.burnout IS NULL
;
COMMIT;


-- Tests

-- Time Series Tests
-- History for: burnout
--SELECT marketTicker, originationDate, count(1), sum(balance), sum(balance * burnout) / sum(CASE WHEN burnout IS NULL THEN 0.0 ELSE balance END) as wavg_burnout FROM #FNM_PoolBurnout GROUP BY marketTicker, originationDate ORDER BY originationDate
--SELECT marketTicker, asOf, count(1), sum(balance), sum(balance * burnout) / sum(CASE WHEN burnout IS NULL THEN 0.0 ELSE balance END) as wavg_burnout FROM #FNM_PoolBurnout GROUP BY marketTicker, asOf ORDER BY asOf

----------------------------------------------------------------------------------------------
-- Check to see if Pools have burnout populated
----------------------------------------------------------------------------------------------
        declare   @cnt int
        SELECT
            @cnt =  count(1)
        FROM #FNM_PoolBurnout WHERE burnout IS NULL

        if (@cnt > 0)
        BEGIN
            RAISERROR 99999 'FNM Pools with NULL Burnout LoanCount : %1!', @cnt
            RETURN
        END
----------------------------------------------------------------------------------------------
-- Check to see if burnout is in valid range
----------------------------------------------------------------------------------------------
        SELECT
            @cnt =  count(1)
        FROM #FNM_PoolBurnout WHERE burnout < 0.0;-- OR burnout > 25000;

        if (@cnt > 0)
        BEGIN
            RAISERROR 99999 'FNM Pools with Invalid burnout Range LoanCount : %1!', @cnt
            RETURN
        END
----------------------------------------------------------------------------------------------
-- Check to see if count of current month changes in a noticeable amount compare with previous month
----------------------------------------------------------------------------------------------
        declare   @cnt_previous int
        SELECT
            @cnt =  count(1)
        FROM #FNM_PoolBurnout WHERE asof = (SELECT asOf FROM #tmp_asOf)

        SELECT
            @cnt_previous =  count(1)
        FROM scale.FNM_PoolBurnout WHERE asof = (SELECT dateadd(month, -1, asOf) FROM #tmp_asOf) AND version = (select  version from #tmp_version)
        
        if (@cnt - @cnt_previous > 0.1 * @cnt_previous OR @cnt_previous - @cnt > 0.1 * @cnt_previous)
        BEGIN
            RAISERROR 99999 'FNM PoolBurnout with INVALID COUNT compare with previous month. Current: %1!; Previous: %2!', @cnt, @cnt_previous
            RETURN
        END 
-- End Tests



-- Load Data into Scale Burnout Table
DELETE FROM scale.FNM_PoolBurnout
FROM scale.FNM_PoolBurnout spb, #FNM_PoolBurnout pb
WHERE 1=1
    AND spb.issueId = pb.issueId
    AND spb.asOf = pb.asOf
    AND pb.marketTicker IN (SELECT tickerName FROM #ticker)
    AND spb.asOf >= (SELECT asOf from #tmp_asOf)
    AND version = (SELECT version from #tmp_version)
;

DECLARE @version varchar(5)
SELECT @version = (select * from #tmp_version)

INSERT INTO scale.FNM_PoolBurnout (issueId, asOf, version, burnout)
SELECT
    issueId,
    asOf,
    @version,
    burnout
FROM #FNM_PoolBurnout
WHERE marketTicker IN (SELECT tickerName FROM #ticker)
    AND asOf >= (SELECT asOf from #tmp_asOf)
; 