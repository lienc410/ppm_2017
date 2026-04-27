-- Freddie Conventional
-- Loan Level
-- Part 7 of 7
-- Script to update Burnout
-- Updates Burnout

-- Before execute the script, need to set the version to run for
DROP TABLE IF EXISTS #tmp_version;
SELECT CAST ('2.50' AS varchar(5)) version INTO #tmp_version
;

-- Before execute the script, need to set the dates to run for
DROP TABLE IF EXISTS #tmp_asOf;
SELECT CAST('#####ASOF#####' AS DATE) asOf INTO #tmp_asOf
--SELECT CAST ('2017-04-01' AS DATE) asOf INTO #tmp_asOf
;

-- Before execute the script, need to set the tickers
DROP TABLE IF EXISTS #ticker;
CREATE TABLE #ticker(
    tickerName varchar(20),
    mtgRateSeries varchar(30)
)
;
INSERT #ticker SELECT 'FGLMC', 'CONVENTIONAL_30YR';   --Conventional Freddie
INSERT #ticker SELECT 'FGT6', 'JUMBO_30YR';           --Jumbo Freddie
INSERT #ticker SELECT 'FGU6', 'CONVENTIONAL_30YR';    --CQ Freddie High LTV[105-125]
INSERT #ticker SELECT 'FGU9', 'CONVENTIONAL_30YR';    --CR Freddie High LTV[125-150]
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

-- Create Incentive Data
DROP TABLE IF EXISTS #FHL_LoanIncentive;
SELECT
    sli.loanSeqNum,
    sli.asOf,
    CASE WHEN (HARP_eligible = 1 OR conventional_eligible = 1) THEN conventional_refi_incentive   ELSE 0.0 END AS conventional_incentive,
    CASE WHEN fha_eligible = 1                                 THEN fha_refi_incentive            ELSE 0.0 END AS fha_incentive
INTO #FHL_LoanIncentive
FROM scale.FHL_Loan_Dev sl
JOIN #ticker tk
    ON sl.marketTicker = tk.tickerName
JOIN scale.FHL_LoanIncentive sli
    ON sl.loanSeqNum = sli.loanSeqNum 
JOIN scale.FHL_LoanEligibility sle
    ON sli.loanSeqNum = sle.loanSeqNum
    AND sli.asOf = sle.asOf
JOIN #Mtg30YrRates_monthly mtg
    ON mtg.asOf_lag1 = sli.asOf
    AND mtg.SeriesName = tk.mtgRateSeries
WHERE sli.version = (select version from #tmp_version)
    AND sl.version = (select version from #tmp_version)
;
COMMIT;

CREATE HG INDEX id_idx ON #FHL_LoanIncentive(loanSeqNum);
CREATE LF INDEX asOf_idx ON #FHL_LoanIncentive(asOf);
COMMIT;



-- Update burnout (cap at 200 bps)
DROP TABLE IF EXISTS #FHL_LoanIncentive_LoanSize;
SELECT
    tli.loanSeqNum,
    tli.asOf,
    slh.balance,
    CASE WHEN tli.conventional_incentive > 200 THEN 200 ELSE tli.conventional_incentive END   AS conventional_incentive,
    CASE WHEN tli.fha_incentive          > 200 THEN 200 ELSE tli.fha_incentive END            AS fha_incentive
INTO #FHL_LoanIncentive_LoanSize
FROM #FHL_LoanIncentive tli
JOIN scale.FHL_LoanHist slh ON tli.loanSeqNum = slh.loanSeqNum AND tli.asOf = slh.asOf
;
COMMIT;

CREATE HG INDEX id_idx ON #FHL_LoanIncentive_LoanSize(loanSeqNum);
CREATE LF INDEX asOf_idx ON #FHL_LoanIncentive_LoanSize(asOf);
COMMIT;

-- Initial Burnout computation
-- Incentive Calculation involving Mortgage Rate, Note Rate, LLPA and PMI
DROP TABLE IF EXISTS #FHL_LoanBurnout;
SELECT
    sl.marketTicker,
    t0.loanSeqNum,
    t0.asOf as asOf,
    sum(CASE WHEN                t1.conventional_incentive > t1.fha_incentive AND t1.conventional_incentive > 0.0 THEN t1.conventional_incentive 
                 ELSE CASE WHEN  t1.fha_incentive > t1.conventional_incentive AND t1.fha_incentive > 0.0          THEN t1.fha_incentive
                 ELSE 0.0 
                 END   
            END) as burnout
INTO #FHL_LoanBurnout
FROM scale.FHL_Loan_Dev sl
JOIN #ticker tk
    ON sl.marketTicker = tk.tickerName
JOIN #FHL_LoanIncentive_LoanSize t0
    ON sl.loanSeqNum = t0.loanSeqNum
JOIN #FHL_LoanIncentive_LoanSize t1
    ON t0.loanSeqNum = t1.loanSeqNum
    AND t0.asOf > t1.asOf
WHERE t0.asOf >= (select asOf from #tmp_asOf)
    AND sl.version = (select version from #tmp_version)
GROUP BY sl.marketTicker, t0.loanSeqNum, t0.asOf
;
COMMIT;

-- Earliest AsOf Date
DROP TABLE IF EXISTS #FHL_Earliest;
SELECT
    l.loanSeqNum,
    l.marketTicker,
    o.first_asOf,
    l.originationDate,
    l.origNoteRate,
    cast(0.0 as numeric(10, 4)) as burnout
INTO #FHL_Earliest
FROM scale.FHL_Loan_Dev l
JOIN (
        SELECT
            loanSeqNum,
            min(asOf) as first_asOf
        FROM fhl.PIV_LoanHist  
        GROUP BY loanSeqNum
    ) o
    ON l.loanSeqNum = o.loanSeqNum
WHERE 1=1
    AND l.version = (select version from #tmp_version)
;
COMMIT;

-- Create missing periods from origination date to first asOf date
DROP TABLE IF EXISTS #FHL_MissingHist;
SELECT 
    e.loanSeqNum, 
    t.asOf, 
    e.origNoteRate,
    mtg.MtgRate
INTO #FHL_MissingHist
FROM #FHL_Earliest e
JOIN #ticker tk
    ON e.marketTicker = tk.tickerName
JOIN #unique_dates t
    ON t.asOf > e.originationDate
    AND t.asOf <= e.first_asOf 
JOIN #Mtg30YrRates_monthly mtg
    ON mtg.asOf_lag1 = t.asOf
    AND mtg.SeriesName = tk.mtgRateSeries
;
COMMIT;

-- Historical Burnout computation
-- Simple Calculation involving MortgageRate and Note Rate
DROP TABLE IF EXISTS #FHL_LoanBurnoutHist;
SELECT 
    t0.loanSeqNum,
    t0.asOf,
    sum(CASE WHEN t1.origNoteRate - t1.MtgRate <= 0.0 THEN 0.0 ELSE t1.origNoteRate - t1.MtgRate END) as burnout
INTO #FHL_LoanBurnoutHist
FROM #FHL_MissingHist t0
JOIN #FHL_MissingHist t1
    ON t0.loanSeqNum = t1.loanSeqNum
    AND t0.asOf > t1.asOf
GROUP BY t0.loanSeqNum, t0.asOf
;
COMMIT;

-- Update Burnout for first instance
UPDATE #FHL_Earliest e SET e.burnout = bh.burnout
FROM #FHL_LoanBurnoutHist bh
WHERE bh.loanSeqNum = e.loanSeqNum
    AND bh.asOf = e.first_asOf;
COMMIT;

-- Update Burnout with Historical Burnout
UPDATE #FHL_LoanBurnout b SET b.burnout = b.burnout + e.burnout
FROM #FHL_Earliest e
WHERE b.loanSeqNum = e.loanSeqNum
;
COMMIT;

-- Update Burnout with empty cells
UPDATE #FHL_LoanBurnout b SET b.burnout = 0.0
WHERE b.burnout = NULL
;
COMMIT;


-- Tests

--SELECT l.marketTicker, sl.originationDate, count(1), sum(balance), sum(balance * l.burnout) / sum(CASE WHEN l.burnout IS NULL THEN 0.0 ELSE balance END) as wavg_burnout FROM #FHL_LoanBurnout l JOIN fhl.PIV_LoanHist lh ON l.loanSeqNum = lh.loanSeqNum AND l.asOf = lh.asOf JOIN scale.FHL_Loan sl ON sl.loanSeqNum = lh.loanSeqNum GROUP BY l.marketTicker, sl.originationDate ORDER BY sl.originationDate
--SELECT l.marketTicker, l.asOf, count(1), sum(schamBalance), sum(schamBalance * l.burnout) / sum(CASE WHEN l.burnout IS NULL THEN 0.0 ELSE schamBalance END) as wavg_burnout FROM #FHL_LoanBurnout l JOIN fhl.PIV_LoanHist lh ON l.loanSeqNum = lh.loanSeqNum AND l.asOf = lh.asOf GROUP BY l.marketTicker, l.asOf ORDER BY l.asOf

----------------------------------------------------------------------------------------------
-- Check to see if Loans have burnout populated
----------------------------------------------------------------------------------------------
        declare   @cnt int
        SELECT
            @cnt =  count(1)
        FROM #FHL_LoanBurnout WHERE burnout IS NULL

        if (@cnt > 0)
        BEGIN
            RAISERROR 99999 'FHL Loans with NULL Burnout LoanCount : %1!', @cnt
            RETURN
        END
----------------------------------------------------------------------------------------------
-- Check to see if burnout is in valid range
----------------------------------------------------------------------------------------------
        SELECT
            @cnt =  count(1)
        FROM
            #FHL_LoanBurnout
        WHERE
            burnout < 0.0 --OR burnout > 350

        if (@cnt > 0)
        BEGIN
            RAISERROR 99999 'FHL Loans with Invalid burnout Range LoanCount : %1!', @cnt
            RETURN
        END
----------------------------------------------------------------------------------------------
-- Check to see if count of current month changes in a noticeable amount compare with previous month
----------------------------------------------------------------------------------------------
        declare   @cnt_previous int
        SELECT
            @cnt =  count(1)
        FROM #FHL_LoanBurnout WHERE asof = (SELECT asOf FROM #tmp_asOf where asOf>'20060901')

        SELECT
            @cnt_previous =  count(1)
        FROM scale.FHL_LoanBurnout WHERE asof = (SELECT dateadd(month, -1, asOf) FROM #tmp_asOf where asOf>'20060901') AND version = (select  version from #tmp_version)
        
        if (@cnt - @cnt_previous > 0.1 * @cnt_previous OR @cnt_previous - @cnt > 0.1 * @cnt_previous)
        BEGIN
            RAISERROR 99999 'FHL LoanBurnout with INVALID COUNT compare with previous month. Current: %1!; Previous: %2!', @cnt, @cnt_previous
            RETURN
        END 
-- End Tests



-- Load Data into Scale Burnout Table
DELETE FROM scale.FHL_LoanBurnout
FROM scale.FHL_LoanBurnout slb, #FHL_LoanBurnout lb
WHERE 1=1
    AND slb.loanSeqNum = lb.loanSeqNum
    AND slb.asOf = lb.asOf
    AND lb.marketTicker IN (SELECT tickerName FROM #ticker)
    AND slb.asOf >= (SELECT asOf from #tmp_asOf)
    AND version = (SELECT version from #tmp_version)
;

DECLARE @version varchar(5)
SELECT @version = (select * from #tmp_version)

INSERT INTO scale.FHL_LoanBurnout (loanSeqNum, asOf, version, burnout)
SELECT
    loanSeqNum,
    asOf,
    @version,
    burnout-- * 100.0
FROM #FHL_LoanBurnout
WHERE marketTicker IN (SELECT tickerName FROM #ticker)
    AND asOf >= (SELECT asOf from #tmp_asOf)
;
