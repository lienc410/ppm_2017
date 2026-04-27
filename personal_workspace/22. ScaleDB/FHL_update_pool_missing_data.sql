-- Freddie Conventional
-- Pool Level
-- Part 1 of 6
-- Script to update missing data
-- Updates CLTV, HPA, FICO, etc.


INSERT INTO scale.jobstatus(StartTime,JobName,JobStatus)
VALUES (getdate(),'FHL_Pool_Step 1_Create_Pool_Table','START');
COMMIT;

-- Before execute the script, need to set the dates to run for
DROP TABLE IF EXISTS #tmp_asOf;
SELECT CAST('#####ASOF#####' AS DATE) asOf, CAST('#####LAST#####' AS DATE) asOf_last INTO #tmp_asOf
--SELECT CAST ('1994-01-01' AS DATE) asOf, CAST('2018-04-01' AS DATE) asOf_last INTO #tmp_asOf
;
-- Before execute the script, need to set the appType to run for
DROP TABLE IF EXISTS #tmp_appType;
SELECT '#####APPTYPE#####' AS appType INTO #tmp_appType
--SELECT '9.98' AS appType INTO #tmp_appType
;

-- Before execute the script, need to set the tickers
DROP TABLE IF EXISTS #ticker;
CREATE TABLE #ticker(
    tickerName varchar(20),
    mtgRateSeries varchar(30)
)
;
INSERT #ticker SELECT 'FGLMC', 'CONVENTIONAL_30YR';   --30 Yr Conventional Freddie
INSERT #ticker SELECT 'FGT6', 'JUMBO_30YR';           --30 Yr Jumbo Freddie
INSERT #ticker SELECT 'FGU6', 'CONVENTIONAL_30YR';    --30 Yr CQ Freddie High LTV[105-125]
INSERT #ticker SELECT 'FGU9', 'CONVENTIONAL_30YR';    --30 Yr CR Freddie High LTV[125-150]
--INSERT #ticker SELECT 'FGTW', 'CONVENTIONAL_20YR';    --20 Yr Conventional Freddie
--INSERT #ticker SELECT 'FGCI', 'CONVENTIONAL_15YR';    --15 Yr Conventional Freddie
COMMIT;

CREATE LF INDEX loan_tickerName_idx ON #ticker(tickerName);
COMMIT;

-- Before execute the script, need to set the version to run for
DROP TABLE IF EXISTS #tmp_version;
SELECT mvc.tickerName, mvc.appType, mvc.originationVersion_LL as originationVersion 
INTO #tmp_version
FROM scale.ModelVersionConfig mvc
JOIN #tmp_appType tat
     ON mvc.appType = tat.appType
JOIN #ticker tk
     ON mvc.tickerName = tk.tickerName
;
COMMIT;

-- Create Monthly HPI data
-- Requires Extending the Time Series to the latest factor date using an assumption of 3% HPA
DROP TABLE IF EXISTS #HomePriceIndex_monthly;
SELECT asof, 
    NonSeasonAdjIndex as HPIndex
INTO #HomePriceIndex_monthly
FROM hpi.PIV_HomePriceIndexMonthly
WHERE transactionType = 'PURCHASE_ONLY'
AND region = 'USA'
;

DROP TABLE IF EXISTS #HPA_MA;
SELECT
    'USA' as Region,
    t1.asOf,
    t1.HPIndex as HPIndex,
    t2.HPIndex as HPIndex_1YR,
    t3.HPIndex as HPIndex_2YR,
    CASE WHEN t2.HPIndex IS NULL THEN NULL ELSE t1.HPIndex / t2.HPIndex END as HPA_1YR,
    CASE WHEN t3.HPIndex IS NULL THEN NULL ELSE t1.HPIndex / t3.HPIndex END as HPA_2YR
INTO #HPA_MA
FROM #HomePriceIndex_monthly t1
LEFT JOIN #HomePriceIndex_monthly t2
    ON t1.asOf = dateadd(month, 12, t2.asOf)
LEFT JOIN #HomePriceIndex_monthly t3
    ON t1.asOf = dateadd(month, 24, t3.asOf)
;
COMMIT;

CREATE LF INDEX asOf_idx ON #HPA_MA(asOf);
COMMIT;

DELETE FROM #HPA_MA WHERE HPA_1YR IS NULL;
COMMIT;

DELETE FROM #HPA_MA WHERE HPA_2YR IS NULL;
COMMIT;

DROP TABLE IF EXISTS #HPI_Earliest;
SELECT
    min(asOf) as hpi_earliest_date,
    cast(NULL as numeric(8, 4)) as hpi_earliest_value
INTO #HPI_Earliest
FROM #HPA_MA
WHERE Region = 'USA'
;
COMMIT;

UPDATE #HPI_Earliest he SET he.hpi_earliest_value = hpi.HPIndex
FROM #HPA_MA hpi
WHERE he.hpi_earliest_date = hpi.asOf
    AND Region = 'USA'
;
COMMIT;

-- Create Weighted Average CLTV from Loan Level
DROP TABLE IF EXISTS #FHL_LoanCLTV;
SELECT cl.issueId, sfl.asOf,convert(numeric(6,2),sum(sfl.cltv * sfl.balance)/sum(sfl.balance)) as wcltv
INTO #FHL_LoanCLTV
FROM fhl.PIV_Loan cl
JOIN scale.fhl_loanhist sfl
ON cl.loanseqnum=sfl.loanseqnum
GROUP BY cl.issueId, sfl.asof
;

-- Create Pool Historical Data
DROP TABLE IF EXISTS #FHL_PoolHist;
SELECT
    p.marketTicker,
    p.issueId,
    f.asOf,
    CASE WHEN f.schambalance IS NULL THEN f.currentBalance ELSE f.schambalance END as balance,
    f.currentBalance,
    CASE WHEN f.calcOrigMonth IS NULL THEN p.issueDate ELSE convert(date, convert(char(8), f.calcOrigMonth * 100 + 1)) END as originationDate,
    CASE WHEN a.wtdAvg = -999 THEN NULL WHEN a.wtdAvg = 999999999 THEN NULL ELSE a.wtdAvg END as waolSize,
    CASE WHEN f.waocs = -999 OR f.waocs <= 0 THEN NULL ELSE f.waocs END as waocs,
    CASE WHEN f.waoltv = -999 OR f.waoltv <= 0 OR f.waoltv = 999 THEN NULL ELSE f.waoltv END as waoltv,
    1.0 - (POWER(1.0 + f.wac / 1200.0, f.wala) - 1.0) / (POWER(1.0 + f.wac / 1200.0, 360) - 1.0) as factor_1,
    CASE WHEN factor_1 < 0.0 THEN 0.0 WHEN factor_1 > 1.0 THEN 1.0 ELSE factor_1 END as factor,
    f.wala,
    f.wac,
    CASE WHEN currNumLoans > 0 THEN f.currentBalance / currNumLoans ELSE f.waclSize END as waclSize,
    lc.wcltv as waCLTV,
    cast(NULL as numeric(10, 4)) as HPI_orig,
    cast(NULL as numeric(10, 4)) as HPA,
    cast(NULL as numeric(10, 4)) as HPI,
    cast(NULL as numeric(10, 4)) as miLevel
INTO #FHL_PoolHist
FROM fhl.sec p
JOIN #ticker tk
    ON p.marketTicker = tk.tickerName
JOIN fhl.secFactor f
    ON p.issueId = f.issueId
LEFT JOIN #FHL_LoanCLTV lc
    ON f.issueId = lc.issueId
    AND f.asOf = lc.asOf
LEFT JOIN fhl.AOLSQuartile a 
    ON f.issueId = a.issueId
    AND f.asOf = a.asOf
WHERE 1=1
    AND p.collateralType = 'LOAN'
    AND f.wala >= 0
    AND f.wac > 0
    AND balance > 0.01
    AND f.asOf NOT IN ('1994-05-01','1997-01-01') 
    AND f.asOf >= (select asOf from #tmp_asOf)
	AND f.asOf <= (select asOf_last from #tmp_asOf)
;
COMMIT;

CREATE HG INDEX issueId_idx ON #FHL_PoolHist(issueId);
CREATE LF INDEX asOf_idx ON #FHL_PoolHist(asOf);
CREATE LF INDEX ticker_idx ON #FHL_PoolHist(marketTicker);
COMMIT;

-- Update WACLTV from Pool Level Data
update #FHL_PoolHist ph SET ph.waCLTV=fss.waCLTV_currentBalance
FROM fhl.secSupp fss
where 1=1
and ph.issueId=fss.issueId
and ph.asof=fss.asof
and ph.waCLTV IS NULL

-- Delete bad data periods
DELETE FROM #FHL_PoolHist WHERE marketTicker = 'FGU6' AND asOf IN ('2009-10-01'); 
COMMIT;

-- Update HPA_XYR and HPI
UPDATE #FHL_PoolHist perf SET perf.HPI = hpi.HPIndex
FROM #HPA_MA hpi
WHERE perf.asOf = hpi.asOf 
    AND hpi.Region = 'USA'
;

-- Update HPI_orig
UPDATE #FHL_PoolHist perf SET perf.HPI_orig = hpi.HPIndex
FROM #HPA_MA hpi
WHERE perf.originationDate = hpi.asOf
    AND hpi.Region = 'USA'
;
UPDATE #FHL_PoolHist perf SET perf.HPI_orig = he.hpi_earliest_value * power(1 + 3.0 / 100.0, -(datediff(MONTH, perf.originationDate, he.hpi_earliest_date) / 12.0))
FROM #HPI_Earliest he
WHERE perf.HPI_orig IS NULL
;
COMMIT;


-- Populate Missing Data
-- First Create Pool Origination Data (or Oldest data available)

-- OLS
DROP TABLE IF EXISTS #FHL_MinDate_OLS;
SELECT
    marketTicker,
    issueId,
    min(asOf) as asOf,
    cast(NULL as numeric(12, 2)) as waolSize
INTO #FHL_MinDate_OLS
FROM #FHL_PoolHist p
WHERE p.waolSize IS NOT NULL 
    AND p.waolSize <> -999
    AND p.waolSize > 0
GROUP BY marketTicker, issueId
;
COMMIT;

UPDATE #FHL_MinDate_OLS s SET s.waolSize = d.waolSize
FROM #FHL_PoolHist d
WHERE s.issueId = d.issueId
    AND s.asOf = d.asOf
;

    -- FICO
DROP TABLE IF EXISTS #FHL_MinDate_FICO;
SELECT
    marketTicker,
    issueId,
    min(asOf) as asOf,
    cast(NULL as numeric(8, 4)) as waocs
INTO #FHL_MinDate_FICO
FROM #FHL_PoolHist p
WHERE p.waocs IS NOT NULL 
    AND p.waocs <> -999
GROUP BY marketTicker, issueId
;
COMMIT;

UPDATE #FHL_MinDate_FICO s SET s.waocs = d.waocs
FROM #FHL_PoolHist d
WHERE s.issueId = d.issueId
    AND s.asOf = d.asOf
;

    -- OLTV
DROP TABLE IF EXISTS #FHL_MinDate_OLTV;
SELECT
    marketTicker,
    issueId,
    min(asOf) as asOf,
    cast(NULL as numeric(8, 4)) as waoltv
INTO #FHL_MinDate_OLTV
FROM #FHL_PoolHist p
WHERE p.waoltv IS NOT NULL
    AND p.waoltv <> -999
    AND p.waoltv > 0
GROUP BY marketTicker, issueId
;
COMMIT;

UPDATE #FHL_MinDate_OLTV s SET s.waoltv = d.waoltv
FROM #FHL_PoolHist d
WHERE s.issueId = d.issueId
    AND s.asOf = d.asOf
;

  -- Update OLS, FICO, OLTV, HPA, CLS, CLTV

    -- OLS
UPDATE #FHL_PoolHist perf SET perf.waolSize = s.waolSize
FROM #FHL_MinDate_OLS s
WHERE perf.issueId = s.issueId 
    AND (perf.waolSize IS NULL OR perf.waolSize <= 0)
;

DROP TABLE IF EXISTS #FHL_OriginationDate_OLS;
SELECT
    year(originationDate) as origYear,
    sum(balance * waolSize) / sum(balance) as WAVG_OLS,
    sum(balance) as sum_ls
INTO #FHL_OriginationDate_OLS
FROM #FHL_PoolHist p
WHERE waolSize IS NOT NULL 
    AND waolSize > 0
GROUP BY origYear
HAVING sum_ls > 10000000
;
COMMIT;

UPDATE #FHL_PoolHist perf SET perf.waolSize = ols.WAVG_OLS
FROM #FHL_OriginationDate_OLS ols
WHERE  year(perf.originationDate) = ols.origYear
    AND (perf.waolSize IS NULL OR perf.waolSize <= 0)
;

UPDATE #FHL_PoolHist perf SET perf.waolSize = (
    SELECT sum(balance * waolSize) / sum(balance) as WAVG_OLS 
    FROM #FHL_PoolHist p
    WHERE waolSize IS NOT NULL
        AND waolSize > 0
    )
WHERE perf.waolSize IS NULL OR perf.waolSize <= 0
;

-- FICO
UPDATE #FHL_PoolHist perf SET perf.waocs = s.waocs
FROM #FHL_MinDate_FICO s
WHERE perf.issueId = s.issueId 
    AND perf.waocs IS NULL
;

DROP TABLE IF EXISTS #FHL_OriginationDate_FICO;
SELECT
    year(originationDate) as origYear,
    sum(balance * waocs) / sum(balance) as WAVG_FICO,
    sum(balance) as sum_ls
INTO #FHL_OriginationDate_FICO
FROM #FHL_PoolHist p
WHERE waocs IS NOT NULL
GROUP BY origYear
HAVING sum_ls > 10000000
;
COMMIT;

UPDATE #FHL_PoolHist perf SET perf.waocs = oc.WAVG_FICO
FROM #FHL_OriginationDate_FICO oc
WHERE  year(perf.originationDate) = oc.origYear
    AND perf.waocs IS NULL 
;

UPDATE #FHL_PoolHist perf SET perf.waocs = (
    SELECT sum(balance * waocs) / sum(balance) as WAVG_FICO 
    FROM #FHL_PoolHist p
    WHERE waocs IS NOT NULL
    )
WHERE perf.waocs IS NULL
;

DELETE FROM #FHL_PoolHist WHERE waocs IS NULL ;
COMMIT;

-- OLTV
UPDATE #FHL_PoolHist perf SET perf.waoltv = s.waoltv
FROM #FHL_MinDate_OLTV s
WHERE perf.issueId = s.issueId 
    AND perf.waoltv IS NULL
;

DROP TABLE IF EXISTS #FHL_OriginationDate_OLTV;
SELECT
    year(originationDate) as origYear,
    sum(balance * waoltv) / sum(balance) as WAVG_OLTV,
    sum(balance) as sum_ls
INTO #FHL_OriginationDate_OLTV
FROM #FHL_PoolHist p
WHERE waoltv IS NOT NULL
GROUP BY origYear
HAVING sum_ls > 10000000
;
COMMIT;

UPDATE #FHL_PoolHist perf SET perf.waoltv = ltv.WAVG_OLTV
FROM #FHL_OriginationDate_OLTV ltv
WHERE year(perf.originationDate) = ltv.origYear
    AND perf.waoltv IS NULL 
;

UPDATE #FHL_PoolHist perf SET perf.waoltv = (
    SELECT sum(balance * waoltv) / sum(balance) as WAVG_OLTV 
    FROM #FHL_PoolHist p
    WHERE waoltv IS NOT NULL
    )
WHERE perf.waoltv IS NULL 
;
COMMIT;

DELETE FROM #FHL_PoolHist WHERE waoltv IS NULL ;
COMMIT;

-- HPA / CLS / CLTV
UPDATE #FHL_PoolHist SET HPA = HPI / HPI_orig
;

UPDATE #FHL_PoolHist perf SET perf.waclSize = perf.waolSize / perf.HPA
WHERE waclSize IS NULL
    OR waclSize = 0
    OR waclSize = -999
    OR waclSize = 999
;

UPDATE #FHL_PoolHist perf SET perf.wacltv = perf.waoltv * perf.factor / perf.HPA
WHERE wacltv IS NULL 
    OR wacltv = -999
    OR wacltv = 999
;
UPDATE #FHL_PoolHist perf SET perf.wacltv = 0.01
WHERE wacltv <= 0.0
;
COMMIT;

-- MI Level from Loan Data
DROP TABLE IF EXISTS #FHL_LoanMILevel;
SELECT
    issueId,
    sum(miLevel * origLoanSize) / sum(origLoanSize) as miLevel
INTO #FHL_LoanMILevel
FROM fhl.PIV_Loan cl
JOIN scale.FHL_Loan_Dev sl
    ON cl.loanSeqNum = sl.loanSeqNum
WHERE sl.miLevel IS NOT NULL
    AND sl.version in (select originationVersion from #tmp_version)
GROUP BY issueID
HAVING sum(origLoanSize) > 0.01
;

UPDATE #FHL_PoolHist pd SET 
    pd.miLevel = b.miLevel
FROM #FHL_LoanMILevel b
WHERE pd.issueId = b.issueID
;
COMMIT;

DROP TABLE IF EXISTS #FHL_OriginationDate_MI;
SELECT
    year(originationDate) as origYear,
    sum(balance * miLevel) / sum(balance) as WAVG_MI,
    sum(balance) as sum_ls
INTO #FHL_OriginationDate_MI
FROM #FHL_PoolHist p
WHERE miLevel IS NOT NULL
GROUP BY origYear
HAVING sum_ls > 10000000
;
COMMIT;

UPDATE #FHL_PoolHist perf SET perf.miLevel = mi.WAVG_MI
FROM #FHL_OriginationDate_MI mi
WHERE year(perf.originationDate) = mi.origYear
    AND perf.miLevel IS NULL 
;

UPDATE #FHL_PoolHist perf SET perf.miLevel = (
    SELECT sum(balance * miLevel) / sum(balance) as WAVG_MI
    FROM #FHL_PoolHist p
    WHERE miLevel IS NOT NULL
    )
WHERE perf.miLevel IS NULL 
;

DELETE FROM #FHL_PoolHist WHERE miLevel IS NULL ;
COMMIT;



-- Tests

-- Time Series Tests
-- History for: CLTV, HPA, HPA_2YR
--SELECT marketTicker, asOf, count(1), sum(balance), sum(balance * waolSize) / sum(balance) as wavg_ols FROM #FHL_PoolHist GROUP BY marketTicker, asOf ORDER BY asOf
--SELECT marketTicker, originationDate, count(1), sum(balance), sum(balance * waolSize) / sum(balance) as wavg_ols FROM #FHL_PoolHist GROUP BY marketTicker, originationDate ORDER BY originationDate

--SELECT marketTicker, asOf, count(1), sum(balance), sum(balance * waocs) / sum(balance) as wavg_ocs FROM #FHL_PoolHist GROUP BY marketTicker, asOf ORDER BY asOf
--SELECT marketTicker, originationDate, count(1), sum(balance), sum(balance * waocs) / sum(balance) as wavg_ocs FROM #FHL_PoolHist GROUP BY marketTicker, originationDate ORDER BY originationDate

--SELECT marketTicker, asOf, count(1), sum(balance), sum(balance * waoltv) / sum(balance) as wavg_oltv FROM #FHL_PoolHist GROUP BY marketTicker, asOf ORDER BY asOf
--SELECT marketTicker, originationDate, count(1), sum(balance), sum(balance * waoltv) / sum(balance) as wavg_oltv FROM #FHL_PoolHist GROUP BY marketTicker, originationDate ORDER BY originationDate

--SELECT marketTicker, asOf, count(1), sum(balance), sum(balance * wac) / sum(balance) as wavg_wac FROM #FHL_PoolHist GROUP BY marketTicker, asOf ORDER BY asOf
--SELECT marketTicker, originationDate, count(1), sum(balance), sum(balance * wac) / sum(balance) as wavg_wac FROM #FHL_PoolHist GROUP BY marketTicker, originationDate ORDER BY originationDate

--SELECT marketTicker, asOf, count(1), sum(balance), sum(balance * waclSize) / sum(balance) as wavg_cls FROM #FHL_PoolHist GROUP BY marketTicker, asOf ORDER BY asOf
--SELECT marketTicker, originationDate, count(1), sum(balance), sum(balance * waclSize) / sum(balance) as wavg_cls FROM #FHL_PoolHist GROUP BY marketTicker, originationDate ORDER BY originationDate

--SELECT marketTicker, asOf, count(1), sum(balance), sum(balance * waCLTV) / sum(balance) as wavg_cltv FROM #FHL_PoolHist GROUP BY marketTicker, asOf ORDER BY asOf
--SELECT marketTicker, originationDate, count(1), sum(balance), sum(balance * waCLTV) / sum(balance) as wavg_cltv FROM #FHL_PoolHist GROUP BY marketTicker, originationDate ORDER BY originationDate

--SELECT marketTicker, asOf, count(1), sum(balance), sum(balance * HPA) / sum(balance) as wavg_hpa FROM #FHL_PoolHist GROUP BY marketTicker, asOf ORDER BY asOf
--SELECT marketTicker, originationDate, count(1), sum(balance), sum(balance * HPA) / sum(balance) as wavg_hpa FROM #FHL_PoolHist GROUP BY marketTicker, originationDate ORDER BY originationDate

--SELECT marketTicker, asOf, count(1), sum(balance), sum(balance * miLevel) / sum(balance) as wavg_level FROM #FHL_PoolHist GROUP BY marketTicker, asOf ORDER BY asOf
--SELECT marketTicker, originationDate, count(1), sum(balance), sum(balance * miLevel) / sum(balance) as wavg_level FROM #FHL_PoolHist GROUP BY marketTicker, originationDate ORDER BY originationDate

----------------------------------------------------------------------------------------------
-- Check to see if Pools have originationDate IS NULL OR originationDate <= '1950-01-01'
----------------------------------------------------------------------------------------------
        declare   @cnt int
        SELECT
            @cnt =  count(1)
        FROM #FHL_PoolHist  WHERE originationDate IS NULL OR originationDate <= '1950-01-01'

        if (@cnt > 0)
        BEGIN
            RAISERROR 99999 'Number of FHL Pools with WRONG VALUE for CLTV: %1!', @cnt
            RETURN
        END

----------------------------------------------------------------------------------------------
-- Check to see if Pools have balance IS NULL OR balance <= 0.0
----------------------------------------------------------------------------------------------
        SELECT
            @cnt =  count(1)
        FROM #FHL_PoolHist WHERE balance IS NULL OR balance <= 0.0

        if (@cnt > 0)
        BEGIN
            RAISERROR 99999 'Number of FHL Pools with WRONG VALUE for balance: %1!', @cnt
            RETURN
        END
        
----------------------------------------------------------------------------------------------
-- Check to see if Pools have waolSize IS NULL OR waolSize <= 0.0 OR waolSize > 1500000
----------------------------------------------------------------------------------------------
        SELECT
            @cnt =  count(1)
        FROM #FHL_PoolHist WHERE waolSize IS NULL OR waolSize <= 0.0 OR waolSize > 1500000

        if (@cnt > 0)
        BEGIN
            RAISERROR 99999 'Number of FHL Pools with WRONG VALUE for waolSize: %1!', @cnt
            RETURN
        END

----------------------------------------------------------------------------------------------
-- Check to see if Pools have waocs IS NULL OR waocs <= 0.0 OR waocs > 900
----------------------------------------------------------------------------------------------
        SELECT
            @cnt =  count(1)
        FROM #FHL_PoolHist WHERE waocs IS NULL OR waocs <= 0.0 OR waocs > 900

        if (@cnt > 0)
        BEGIN
            RAISERROR 99999 'Number of FHL Pools with WRONG VALUE for waocs: %1!', @cnt
            RETURN
        END

----------------------------------------------------------------------------------------------
-- Check to see if Pools have waoltv IS NULL OR waoltv <= 0.0 OR waoltv > 1000
----------------------------------------------------------------------------------------------
        SELECT
            @cnt =  count(1)
        FROM #FHL_PoolHist WHERE waoltv IS NULL OR waoltv <= 0.0 OR waoltv > 1000

        if (@cnt > 0)
        BEGIN
            RAISERROR 99999 'Number of FHL Pools with WRONG VALUE for waoltv: %1!', @cnt
            RETURN
        END
        
----------------------------------------------------------------------------------------------
-- Check to see if Pools have factor IS NULL OR factor < 0.0 OR factor > 1.0
----------------------------------------------------------------------------------------------
        SELECT
            @cnt =  count(1)
        FROM #FHL_PoolHist WHERE factor IS NULL OR factor < 0.0 OR factor > 1.0

        if (@cnt > 0)
        BEGIN
            RAISERROR 99999 'Number of FHL Pools with WRONG VALUE for factor: %1!', @cnt
            RETURN
        END
        
----------------------------------------------------------------------------------------------
-- Check to see if Pools have wac IS NULL OR wac <= 0.0 OR wac > 20
----------------------------------------------------------------------------------------------
        SELECT
            @cnt =  count(1)
        FROM #FHL_PoolHist WHERE wac IS NULL OR wac <= 0.0 OR wac > 20

        if (@cnt > 0)
        BEGIN
            RAISERROR 99999 'Number of FHL Pools with WRONG VALUE for wac: %1!', @cnt
            RETURN
        END

----------------------------------------------------------------------------------------------
-- Check to see if Pools have waclSize IS NULL OR waclSize <= 0.0 OR waclSize > 1500000
----------------------------------------------------------------------------------------------
        SELECT
            @cnt =  count(1)
        FROM #FHL_PoolHist WHERE waclSize IS NULL OR waclSize <= 0.0 OR waclSize > 1500000

        if (@cnt > 0)
        BEGIN
            RAISERROR 99999 'Number of FHL Pools with WRONG VALUE for waclSize: %1!', @cnt
            RETURN
        END

----------------------------------------------------------------------------------------------
-- Check to see if Pools have waCLTV IS NULL OR waCLTV <= 0.0 OR waCLTV > 1000
----------------------------------------------------------------------------------------------
        SELECT
            @cnt =  count(1)
        FROM #FHL_PoolHist WHERE waCLTV IS NULL OR waCLTV <= 0.0 OR waCLTV > 1000

        if (@cnt > 0)
        BEGIN
            RAISERROR 99999 'Number of FHL Pools with WRONG VALUE for waCLTV: %1!', @cnt
            RETURN
        END
        
----------------------------------------------------------------------------------------------
-- Check to see if Pools have HPI_orig IS NULL OR HPI_orig < 0.0 OR HPI_orig > 1000
----------------------------------------------------------------------------------------------
        SELECT
            @cnt =  count(1)
        FROM #FHL_PoolHist WHERE HPI_orig IS NULL OR HPI_orig < 0.0 OR HPI_orig > 1000

        if (@cnt > 0)
        BEGIN
            RAISERROR 99999 'Number of FHL Pools with WRONG VALUE for HPI_orig: %1!', @cnt
            RETURN
        END

----------------------------------------------------------------------------------------------
-- Check to see if Pools have HPA IS NULL OR HPA < 0.5 OR HPA > 10
----------------------------------------------------------------------------------------------
        SELECT
            @cnt =  count(1)
        FROM #FHL_PoolHist WHERE HPA IS NULL OR HPA < 0.5 OR HPA > 10

        if (@cnt > 0)
        BEGIN
            RAISERROR 99999 'Number of FHL Pools with WRONG VALUE for HPA: %1!', @cnt
            RETURN
        END

----------------------------------------------------------------------------------------------
-- Check to see if Pools have miLevel IS NULL OR miLevel < 0.0 OR miLevel > 50
----------------------------------------------------------------------------------------------
        SELECT
            @cnt =  count(1)
        FROM #FHL_PoolHist WHERE miLevel IS NULL OR miLevel < 0.0 OR miLevel > 50

        if (@cnt > 0)
        BEGIN
            RAISERROR 99999 'Number of FHL Pools with WRONG VALUE for miLevel: %1!', @cnt
            RETURN
        END     
----------------------------------------------------------------------------------------------
-- Check to see if new pools are loaded into database (need to be commented unless load new data)
----------------------------------------------------------------------------------------------
--     declare @count_previous int
--	 SELECT @count_previous = count(distinct(issueId))
--	 FROM scale.FHL_PoolHist
--	 WHERE marketTicker IN (SELECT tickerName FROM #ticker)
--	 AND asOf >= (SELECT asOf from #tmp_asOf)
--   AND asOf<= (select asOf_last from #tmp_asOf)

--	 declare @count_current int
--	 SELECT @count_current = count(distinct(issueId))
--	 FROM #FHL_PoolHist
--  WHERE asOf >= (SELECT asOf from #tmp_asOf)
--  AND asOf <= (select asOf_last from #tmp_asOf)
	 
--	 if (@count_current - @count_previous <= 0 )
--        BEGIN
--           RAISERROR 99999 'There is no new pool loading into database. Previous pool count: %1!; Current pool count: %2!', @count_previous, @count_current
--           RETURN
 --      END 
 
-- End Tests



-- Load Data into Scale Tables
DELETE FROM scale.FHL_PoolHist
WHERE marketTicker IN (SELECT tickerName FROM #ticker)
    AND asOf >= (SELECT asOf from #tmp_asOf)
	AND asOf <= (SELECT asOf_last from #tmp_asOf)
;

INSERT INTO scale.FHL_PoolHist (issueId, marketTicker, asOf, balance, originationDate, origLoanSize, origFICO, origLTV, origNoteRate, currLoanSize, cltv, hpa, miLevel)
SELECT
    issueId,
    marketTicker,
    asOf,
    balance,
    originationDate,
    waolSize,
    waocs,
    waoltv,
    wac,
    waclSize,
    waCLTV,
    HPA,
    miLevel
FROM #FHL_PoolHist
WHERE marketTicker IN (SELECT tickerName FROM #ticker)
    AND asOf >= (SELECT asOf from #tmp_asOf)
	AND asOf <= (SELECT asOf_last from #tmp_asOf)
;


declare @count_previous int
   
    SELECT @count_previous = count(distinct(issueId))
    FROM scale.FHL_PoolHist
	WHERE marketTicker IN (SELECT tickerName FROM #ticker)
	AND asOf >= (SELECT asOf from #tmp_asOf)
	
declare @count_current int
	 
	 SELECT @count_current = count(distinct(issueId))
	 FROM #FHL_PoolHist
	 WHERE asOf >= (SELECT asOf from #tmp_asOf)
	 AND asOf <= (SELECT asOf_last from #tmp_asOf)
	 
INSERT INTO scale.JobStatus (EndTime, JobName, JobStatus, #LoansBeforeProcess, #LoansUpdated, #LoansAfterProcess)
    SELECT
     getdate(),
    'FHL_Pool_Step 1_Create_Pool_Table',
    'SUCCESS', 
    @count_previous,
    @count_current,
	CASE WHEN(@count_previous>@count_current) THEN @count_previous ELSE @count_current END
;
COMMIT;