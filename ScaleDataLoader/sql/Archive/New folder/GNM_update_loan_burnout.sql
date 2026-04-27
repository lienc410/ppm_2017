-- Ginnie
-- Loan Level
-- Part 6 of 6
-- Script to update Burnout
-- Updates Burnout

-- Before execute the script, need to set the dates to run for
DROP TABLE IF EXISTS #tmp_asOf;
SELECT CAST('#####ASOF#####' AS DATE) asOf INTO #tmp_asOf
--SELECT CAST ('2017-01-01' AS DATE) asOf INTO #tmp_asOf
;

-- Before execute the script, need to set the version to run for
DROP TABLE IF EXISTS #tmp_version;
SELECT CAST ('2.42' AS varchar(5)) version INTO #tmp_version
;

-- Before execute the script, need to set the tickers
DROP TABLE IF EXISTS #ticker;
CREATE TABLE #ticker(
    tickerName varchar(20),
    mtgRateSeries varchar(30)
)
;
INSERT #ticker SELECT 'GNSF', 'GINNIE_30YR';   --Ginnie
INSERT #ticker SELECT 'G2SF', 'GINNIE_30YR';   --Ginnie
INSERT #ticker SELECT 'G2SF-JM', 'GINNIE_30YR';-- Ginnie Jumbo
COMMIT;

CREATE LF INDEX loan_tickerName_idx ON #ticker(tickerName);
COMMIT;


-- Initial Burnout computation
-- The calculation is too expensive for DB, need to run it ticker by ticker
-- GNSF
DROP TABLE IF EXISTS #GNM_LoanBurnout_GNSF;
SELECT
    sl.marketTicker, 
    t0.loanSeqNum,
    t0.asOf as asOf,
    sum(CASE WHEN t1.refi_incentive_eligible < 0.0 THEN 0.0
             ELSE CASE WHEN t1.refi_incentive_eligible > 200.0 THEN 200.0
             ELSE t1.refi_incentive_eligible END END
        ) as burnout
INTO #GNM_LoanBurnout_GNSF
FROM scale.GNM_Loan sl
JOIN #ticker tk
    ON sl.marketTicker = tk.tickerName
JOIN scale.GNM_LoanIncentive t0
    ON sl.loanSeqNum = t0.loanSeqNum
JOIN scale.GNM_LoanIncentive t1
    ON t0.loanSeqNum = t1.loanSeqNum
    AND t0.asOf >= t1.asOf
WHERE 1=1
    AND t0.version = (select  version from #tmp_version)
    AND t1.version = (select  version from #tmp_version)
    AND sl.marketTicker = 'GNSF'
GROUP BY sl.marketTicker, t0.loanSeqNum, t0.asOf
;
COMMIT;

DROP TABLE IF EXISTS #GNM_LoanBurnout;
SELECT * INTO #GNM_LoanBurnout FROM #GNM_LoanBurnout_GNSF;
DROP TABLE IF EXISTS #GNM_LoanBurnout_GNSF;


-- G2SF
DROP TABLE IF EXISTS #GNM_LoanBurnout_G2SF;
SELECT
    sl.marketTicker, 
    t0.loanSeqNum,
    t0.asOf as asOf,
    sum(CASE WHEN t1.refi_incentive_eligible < 0.0 THEN 0.0
             ELSE CASE WHEN t1.refi_incentive_eligible > 200.0 THEN 200.0
             ELSE t1.refi_incentive_eligible END END
        ) as burnout
INTO #GNM_LoanBurnout_G2SF
FROM scale.GNM_Loan sl
JOIN #ticker tk
    ON sl.marketTicker = tk.tickerName
JOIN scale.GNM_LoanIncentive t0
    ON sl.loanSeqNum = t0.loanSeqNum
JOIN scale.GNM_LoanIncentive t1
    ON t0.loanSeqNum = t1.loanSeqNum
    AND t0.asOf >= t1.asOf
WHERE 1=1
    AND t0.version = (select  version from #tmp_version)
    AND t1.version = (select  version from #tmp_version)
    AND sl.marketTicker = 'G2SF'
GROUP BY sl.marketTicker, t0.loanSeqNum, t0.asOf
;
COMMIT;

INSERT INTO #GNM_LoanBurnout (marketTicker, loanSeqNum, asOf, burnout)
SELECT * FROM #GNM_LoanBurnout_G2SF;
DROP TABLE IF EXISTS #GNM_LoanBurnout_G2SF;

-- G2SF-JM
DROP TABLE IF EXISTS #GNM_LoanBurnout_G2SF-JM;
SELECT
    sl.marketTicker, 
    t0.loanSeqNum,
    t0.asOf as asOf,
    sum(CASE WHEN t1.refi_incentive_eligible < 0.0 THEN 0.0
             ELSE CASE WHEN t1.refi_incentive_eligible > 200.0 THEN 200.0
             ELSE t1.refi_incentive_eligible END END
        ) as burnout
INTO #GNM_LoanBurnout_G2SF-JM
FROM scale.GNM_Loan sl
JOIN #ticker tk
    ON sl.marketTicker = tk.tickerName
JOIN scale.GNM_LoanIncentive t0
    ON sl.loanSeqNum = t0.loanSeqNum
JOIN scale.GNM_LoanIncentive t1
    ON t0.loanSeqNum = t1.loanSeqNum
    AND t0.asOf >= t1.asOf
WHERE 1=1
    AND t0.version = (select  version from #tmp_version)
    AND t1.version = (select  version from #tmp_version)
    AND sl.marketTicker = 'G2SF-JM'
GROUP BY sl.marketTicker, t0.loanSeqNum, t0.asOf
;
COMMIT;

INSERT INTO #GNM_LoanBurnout (marketTicker, loanSeqNum, asOf, burnout)
SELECT * FROM #GNM_LoanBurnout_G2SF-JM;
DROP TABLE IF EXISTS #GNM_LoanBurnout_G2SF-JM;

-- Tests

--SELECT l.marketTicker, sl.originationDate, count(1), sum(balance), sum(balance * l.burnout) / sum(CASE WHEN l.burnout IS NULL THEN 0.0 ELSE balance END) as wavg_burnout FROM #GNM_LoanBurnout l JOIN scale.GNM_LoanHist lh ON l.loanSeqNum = lh.loanSeqNum AND l.asOf = lh.asOf JOIN scale.GNM_Loan sl ON sl.loanSeqNum = lh.loanSeqNum GROUP BY l.marketTicker, sl.originationDate ORDER BY sl.originationDate
--SELECT l.marketTicker, l.asOf, count(1), sum(balance), sum(balance * l.burnout) / sum(CASE WHEN l.burnout IS NULL THEN 0.0 ELSE balance END) as wavg_burnout FROM #GNM_LoanBurnout l JOIN scale.GNM_LoanHist lh ON l.loanSeqNum = lh.loanSeqNum AND l.asOf = lh.asOf GROUP BY l.marketTicker, l.asOf ORDER BY l.asOf

----------------------------------------------------------------------------------------------
-- Check to see if Loans have burnout populated
----------------------------------------------------------------------------------------------
        declare   @cnt int
        SELECT
            @cnt =  count(1)
        FROM #GNM_LoanBurnout WHERE burnout IS NULL

        if (@cnt > 0)
        BEGIN
            RAISERROR 99999 'GNM Loans with NULL Burnout LoanCount : %1!', @cnt
            RETURN
        END
----------------------------------------------------------------------------------------------
-- Check to see if burnout is in valid range
----------------------------------------------------------------------------------------------
        SELECT
            @cnt =  count(1)
        FROM
            #GNM_LoanBurnout
        WHERE
            burnout < 0.0

        if (@cnt > 0)
        BEGIN
            RAISERROR 99999 'GNM Loans with Invalid burnout Range LoanCount : %1!', @cnt
            RETURN
        END
----------------------------------------------------------------------------------------------
-- Check to see if count of current month changes in a noticeable amount compare with previous month
----------------------------------------------------------------------------------------------
        declare   @cnt_previous int
        SELECT
            @cnt =  count(1)
        FROM #GNM_LoanBurnout WHERE asof = (SELECT asOf FROM #tmp_asOf)

        SELECT
            @cnt_previous =  count(1)
        FROM scale.GNM_LoanBurnout WHERE asof = (SELECT dateadd(month, -1, asOf) FROM #tmp_asOf) AND version = (SELECT version from #tmp_version)
        
        if (@cnt - @cnt_previous > 0.1 * @cnt_previous OR @cnt_previous - @cnt > 0.1 * @cnt_previous)
        BEGIN
            RAISERROR 99999 'GNM LoanBurnout with INVALID COUNT compare with previous month. Current: %1!; Previous: %2!', @cnt, @cnt_previous
            RETURN
        END 
-- End Tests



-- Load Data into Scale Burnout Table
DELETE FROM scale.GNM_LoanBurnout
FROM scale.GNM_LoanBurnout slb, #GNM_LoanBurnout lb
WHERE 1=1
    AND slb.loanSeqNum = lb.loanSeqNum
    AND slb.asOf = lb.asOf
    AND lb.marketTicker IN (SELECT tickerName FROM #ticker)
    AND slb.asOf >= (SELECT asOf from #tmp_asOf)
    AND version = (SELECT version from #tmp_version)
;

DECLARE @version varchar(5)
SELECT @version = (select * from #tmp_version)

INSERT INTO scale.GNM_LoanBurnout (loanSeqNum, asOf, version, burnout)
SELECT
    loanSeqNum,
    asOf,
    @version,
    burnout
FROM #GNM_LoanBurnout
WHERE marketTicker IN (SELECT tickerName FROM #ticker)
    AND asOf >= (SELECT asOf from #tmp_asOf)
;