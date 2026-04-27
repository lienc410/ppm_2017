-- Fannie Conventional
-- Loan Level
-- Part 7 of 7
-- Script to update Burnout
-- Updates Burnout

--INSERT INTO scale.jobstatus(StartTime,JobName,JobStatus)
--VALUES (getdate(),'FHL_Loan_Step 7_Create_Loan_Burnout_Table','START');
--COMMIT;

-- Before execute the script, need to set the appType to run for
DROP TABLE IF EXISTS #tmp_appType;
SELECT '#####APPTYPE#####' AS appType INTO #tmp_appType
--SELECT '9.98' AS appType INTO #tmp_appType
;

-- Before execute the script, need to set the dates to run for
DROP TABLE IF EXISTS #tmp_asOf;
SELECT 
CAST('#####ASOF#####' AS DATE) asOf, 
CAST('#####LAST#####' AS DATE) asOf_last,
CAST('2014-01-01' AS DATE) asOf_start
INTO #tmp_asOf
--SELECT CAST ('2014-01-01' AS DATE) asOf INTO #tmp_asOf
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
--INSERT #ticker SELECT 'FNCT', 'CONVENTIONAL_20YR';    --20 Yr Conventional Fannie
--INSERT #ticker SELECT 'FNCI', 'CONVENTIONAL_15YR';    --15 Yr Conventional Fannie
COMMIT;

CREATE LF INDEX loan_tickerName_idx ON #ticker(tickerName);
COMMIT;

-- Before execute the script, need to set the version to run for
DROP TABLE IF EXISTS #tmp_version;
SELECT mvc.tickerName, mvc.appType, mvc.burnoutVersion_LL as burnoutVersion, mvc.incentiveVersion_LL as incentiveVersion, mvc.originationVersion_LL as originationVersion
INTO #tmp_version
FROM scale.ModelVersionConfig mvc
JOIN #tmp_appType tat
     ON mvc.appType = tat.appType
JOIN #ticker tk
     ON mvc.tickerName = tk.tickerName
;
COMMIT;

-- Create Incentive Data
DROP TABLE IF EXISTS #FNM_LoanIncentive;
SELECT
    sli.loanSeqNum,
    sli.asOf,
    CASE WHEN (refi_incentive_eligible IS NULL OR refi_incentive_eligible<0) THEN 0.0 ELSE refi_incentive_eligible END AS incentive,
	CASE WHEN (refi_incentive_eligible_fixed_cost IS NULL OR refi_incentive_eligible_fixed_cost<0) THEN 0.0 ELSE refi_incentive_eligible_fixed_cost END AS incentive_fc
INTO #FNM_LoanIncentive
FROM scale.FNM_Loan_Dev sl
JOIN #ticker tk
    ON sl.marketTicker = tk.tickerName
JOIN 
    (select loanseqnum, asof, refi_incentive_eligible, refi_incentive_eligible_fixed_cost, version from scale.FNM_LoanIncentive
    union
    select loanseqnum, asof, refi_incentive_eligible, refi_incentive_eligible_fixed_cost, version from scale.fnm_missing_hist) sli
    ON sl.loanSeqNum = sli.loanSeqNum 
WHERE sli.version IN (select  incentiveVersion from #tmp_version)
    AND sl.version in (select  originationVersion from #tmp_version)
;
COMMIT;

UPDATE #FNM_LoanIncentive tli
SET incentive = 0, incentive_fc = 0
FROM FNM.PIV_LoanHist clh
WHERE tli.loanSeqNum = clh.loanSeqNum
AND tli.asOf = clh.asOf
AND clh.loanAge = -1;
COMMIT;

CREATE HG INDEX id_idx ON #FNM_LoanIncentive(loanSeqNum);
CREATE LF INDEX asOf_idx ON #FNM_LoanIncentive(asOf);
COMMIT;


-- Update burnout (cap at 200 bps)
DROP TABLE IF EXISTS #FNM_LoanIncentive_LoanSize;
SELECT
    tli.loanSeqNum,
    tli.asOf,

    CASE WHEN tli.incentive > 200 THEN 200 ELSE tli.incentive END AS incentive,
    CASE WHEN tli.incentive_fc > 200 THEN 200 ELSE tli.incentive_fc END AS incentive_fc
INTO #FNM_LoanIncentive_LoanSize
FROM #FNM_LoanIncentive tli;
COMMIT;

CREATE HG INDEX id_idx ON #FNM_LoanIncentive_LoanSize(loanSeqNum);
CREATE LF INDEX asOf_idx ON #FNM_LoanIncentive_LoanSize(asOf);
COMMIT;

-- Initial Burnout computation
-- Incentive Calculation involving Mortgage Rate, Note Rate, LLPA and PMI
DROP TABLE IF EXISTS #FNM_LoanBurnout;

CREATE TABLE #FNM_LoanBurnout(
marketTicker  char(10), 
version char(10), 
loanSeqNum char(25), 
asOf date, 
burnout numeric(10,4),
burnout_fc numeric(10,4));
COMMIT;



declare @boundary date
set @boundary='1978-12-31'

WHILE @boundary<=dateadd(year,+1,getdate())
BEGIN

INSERT INTO  #FNM_LoanBurnout
SELECT
    sl.marketTicker,
	tpv.burnoutVersion as version,
    t0.loanSeqNum,
    t0.asOf as asOf,
    sum(t1.incentive) as burnout,
    sum(t1.incentive_fc) as burnout_fc
FROM scale.FNM_Loan_Dev sl
JOIN #ticker tk
    ON sl.marketTicker = tk.tickerName
JOIN #tmp_version tpv
    ON sl.marketTicker = tpv.tickerName
JOIN #FNM_LoanIncentive_LoanSize t0
    ON sl.loanSeqNum = t0.loanSeqNum
JOIN #FNM_LoanIncentive_LoanSize t1
    ON t0.loanSeqNum = t1.loanSeqNum
    AND t0.asOf > t1.asOf
WHERE 1=1
    AND sl.version in (select originationVersion from #tmp_version)
	AND sl.originationdate<=@boundary
	AND sl.originationdate>dateadd(year,-1,@boundary)
GROUP BY sl.marketTicker, t0.loanSeqNum, t0.asOf, version


set @boundary=dateadd(year,1,@boundary)

END;

delete from #FNM_LoanBurnout where asof<(select asOf_start from #tmp_asOf);
commit;

-- Update Burnout with empty cells
UPDATE #FNM_LoanBurnout b SET b.burnout = 0.0
WHERE b.burnout is NULL
;
COMMIT;

UPDATE #FNM_LoanBurnout b SET b.burnout_fc = 0.0
WHERE b.burnout_fc is NULL
;
COMMIT;


-- Tests

--SELECT l.marketTicker, sl.originationDate, count(1), sum(balance), sum(balance * l.burnout) / sum(CASE WHEN l.burnout IS NULL THEN 0.0 ELSE balance END) as wavg_burnout FROM #FNM_LoanBurnout l JOIN fnm.PIV_LoanHist lh ON l.loanSeqNum = lh.loanSeqNum AND l.asOf = lh.asOf JOIN scale.FNM_Loan sl ON sl.loanSeqNum = lh.loanSeqNum GROUP BY l.marketTicker, sl.originationDate ORDER BY sl.originationDate
--SELECT l.marketTicker, l.asOf, count(1), sum(balance), sum(balance * l.burnout) / sum(CASE WHEN l.burnout IS NULL THEN 0.0 ELSE balance END) as wavg_burnout FROM #FNM_LoanBurnout l JOIN fnm.PIV_LoanHist lh ON l.loanSeqNum = lh.loanSeqNum AND l.asOf = lh.asOf GROUP BY l.marketTicker, l.asOf ORDER BY l.asOf

----------------------------------------------------------------------------------------------
-- Check to see if Loans have burnout populated
----------------------------------------------------------------------------------------------
        declare   @cnt int
        SELECT
            @cnt =  count(1)
        FROM #FNM_LoanBurnout WHERE burnout IS NULL

        if (@cnt > 0)
        BEGIN
            RAISERROR 99999 'Number of FNM Loans with NULL Value for Burnout: %1!', @cnt
            RETURN
        END
----------------------------------------------------------------------------------------------
-- Check to see if burnout is in valid range
----------------------------------------------------------------------------------------------
        SELECT
            @cnt =  count(1)
        FROM
            #FNM_LoanBurnout
        WHERE
            burnout < 0.0 
        if (@cnt > 0)
        BEGIN
            RAISERROR 99999 'Number of FNM Loans with INVALID Value for Burnout: %1!', @cnt
            RETURN
        END
----------------------------------------------------------------------------------------------
-- Check to see if new loans are loaded into database (need to be commented unless load new data)
----------------------------------------------------------------------------------------------
--     declare @count_previous int
--	 SELECT @count_previous = count(distinct(loanSeqNum))
--	 FROM scale.FNM_LoanBurnout

--	 declare @count_current int
--	 SELECT @count_current = count(distinct(loanSeqNum))
--	 FROM #FNM_LoanBurnout
	 
--	 if (@cnt_current - @cnt_previous <= 0 )
--        BEGIN
--           RAISERROR 99999 'There is no new loan loading into database for burnout table. Previous loan count: %1!; Current loan count: %2!', @cnt_previous, @cnt_current
--           RETURN
 --      END 
 
  ----------------------------------------------------------------------------------------------
-- Check to see if previous incentive is available for burnout
----------------------------------------------------------------------------------------------

--	 declare @count_check int
--	 SELECT @count_current = count(distinct(loanSeqNum))
--	 FROM #FNM_LoanBurnout
	 
--	 if (@cnt_check = 0 )
--        BEGIN
--           RAISERROR 99999 'There is not enough data to calculate burnout. Load more incentive!'
--           RETURN
 --      END 
-- End Tests



-- Load Data into Scale Burnout Table
DELETE FROM scale.FNM_LoanBurnout
FROM scale.FNM_LoanBurnout slb, #FNM_LoanBurnout lb
WHERE 1=1
    AND slb.loanSeqNum = lb.loanSeqNum
    AND slb.asOf = lb.asOf
    AND lb.marketTicker IN (SELECT tickerName FROM #ticker)
    AND slb.asOf >= (SELECT asOf_start from #tmp_asOf)
	AND slb.asOf <= (SELECT asOf_last from #tmp_asOf)
    AND slb.version IN (SELECT burnoutVersion from #tmp_version)
;


INSERT INTO scale.FNM_LoanBurnout (loanSeqNum, asOf, version, burnout, burnout_fixed_cost)
SELECT
    loanSeqNum,
    asOf,
    version,
    burnout,
	burnout_fc
FROM #FNM_LoanBurnout
WHERE marketTicker IN (SELECT tickerName FROM #ticker)
    AND asOf >= (SELECT asOf_start from #tmp_asOf)
	AND asOf <= (SELECT asOf_last from #tmp_asOf)
;
COMMIT;