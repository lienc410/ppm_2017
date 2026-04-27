-- Ginnie
-- Pool Level
-- Part 1 of 6
-- Script to update missing data
-- Updates CLTV, HPA, FICO, etc.

-- Before execute the script, need to set the dates to run for
DROP TABLE IF EXISTS #tmp_asOf;
SELECT CAST('#####ASOF#####' AS DATE) asOf INTO #tmp_asOf
--SELECT CAST ('1994-02-01' AS DATE) asOf INTO #tmp_asOf
;

-- Before execute the script, need to set the tickers
DROP TABLE IF EXISTS #ticker;
CREATE TABLE #ticker(
    tickerName varchar(20),
    mtgRateSeries varchar(30)
)
;
INSERT #ticker SELECT 'GNSF', 'GINNIE_30YR';   -- Ginnie 1
INSERT #ticker SELECT 'G2SF', 'GINNIE_30YR';   -- Ginnie 2
INSERT #ticker SELECT 'G2SF-JM', 'GINNIE_30YR';-- Ginnie Jumbo
COMMIT;


-- Create Monthly HPI data
-- Requires Extending the Time Series to the latest factor date using an assumption of 3% HPA
DROP TABLE IF EXISTS #t;
CREATE TABLE #t(
    projected_month int
)
;    
INSERT #t SELECT 1;
INSERT #t SELECT 2;
INSERT #t SELECT 3;
INSERT #t SELECT 4;
INSERT #t SELECT 5;
INSERT #t SELECT 6;
COMMIT;

DROP TABLE IF EXISTS #HPI_Latest_Date;
SELECT
    TimeSeriesMetaId,
    max(AsOfDate) as latest_asOf
INTO #HPI_Latest_Date
FROM report.TimeSeries
WHERE TimeSeriesMetaId = (SELECT TimeSeriesMetaId FROM report.TimeSeriesMeta WHERE Source = 'PIV' AND TickerName = 'HPI_USA_ALL_TRANSACTIONS' AND Category = 'HPI' AND SeriesType = 'HPIndex')
GROUP BY TimeSeriesMetaId
;
COMMIT;

DROP TABLE IF EXISTS #HomePriceIndex_projected;
SELECT
    dateadd(MONTH, t.projected_month, ts.AsOfDate) as asOf,
    ts.SeriesNumValue * power(1.0 + 3.0 / 100.0, t.projected_month / 12.0) as HPIndex
INTO #HomePriceIndex_projected
FROM report.TimeSeries ts
JOIN #HPI_Latest_Date ld
    ON ts.AsOfDate = ld.latest_asOf
    AND ts.TimeSeriesMetaId = ld.TimeSeriesMetaId
CROSS JOIN #t t
;
COMMIT;

DROP TABLE IF EXISTS #HomePriceIndex_monthly;
SELECT
    t.asOf,
    t.HPIndex
INTO #HomePriceIndex_monthly
FROM(
    SELECT asOfDate as asOf, SeriesNumValue as HPIndex FROM report.TimeSeries WHERE TimeSeriesMetaId = (SELECT TimeSeriesMetaId FROM #HPI_Latest_Date)
    
    UNION
    
    SELECT asOf, HPIndex FROM #HomePriceIndex_projected
) t
;
COMMIT;

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

CREATE INDEX asOf_idx ON #HPA_MA(asOf);
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


-- Create Pool Historical Data
DROP TABLE IF EXISTS #GNM_PoolHist;
SELECT
    p.marketTicker,
    p.issueId,
    f.asOf,
    CASE WHEN f.schambalance IS NULL THEN f.currentBalance ELSE f.schambalance END as balance,
    f.currentBalance,
    CASE WHEN f.calcOrigMonth IS NULL THEN p.issueDate ELSE convert(date, convert(char(8), f.calcOrigMonth * 100 + 1)) END as originationDate,
    CASE WHEN a.wtdAvg = -999 THEN NULL WHEN a.wtdAvg = 999999999 THEN NULL ELSE a.wtdAvg END as waolSize,
    CASE WHEN f.waocs = -999 OR f.waocs < 300 OR f.waocs > 900 THEN NULL ELSE f.waocs END as waocs,
    CASE WHEN f.waoltv = -999 THEN NULL ELSE f.waoltv END as waoltv,
    1.0 - ((1.0 + f.wac / 1200.0)^f.wala - 1.0) / ((1.0 + f.wac / 1200.0)^360 - 1.0) as factor_1,
    CASE WHEN factor_1 < 0.0 THEN 0.0 WHEN factor_1 > 1.0 THEN 1.0 ELSE factor_1 END as factor,
    f.wala,
    f.wac,
    CASE WHEN currNumLoans > 0 THEN f.currentBalance / currNumLoans ELSE f.waclSize END as waclSize,
    s.waCLTV,
    cast(NULL as numeric(10, 4)) as HPI_orig,
    cast(NULL as numeric(10, 4)) as HPA,
    cast(NULL as numeric(10, 4)) as HPI
INTO #GNM_PoolHist
FROM gnm.sec p
JOIN #ticker tk
    ON p.marketTicker = tk.tickerName
JOIN gnm.secFactor f
    ON p.issueId = f.issueId
LEFT JOIN gnm.secSupp s
    ON f.issueId = s.issueId
    AND f.asOf = s.asOf
LEFT JOIN gnm.AOLSQuartile a 
    ON f.issueId = a.issueId
    AND f.asOf = a.actualAsOf
WHERE 1=1
    AND p.collateralType = 'LOAN'
    AND f.wala >= 0
    AND f.wac > 0
	AND balance > 0.01
    AND f.asOf >= (select asOf from #tmp_asOf)
;
COMMIT;

CREATE INDEX issueId_idx ON #GNM_PoolHist(issueId);
CREATE INDEX asOf_idx ON #GNM_PoolHist(asOf);
COMMIT;

-- Update bad data
UPDATE #GNM_PoolHist SET waclSize = NULL
WHERE waclSize > 1500000 OR waclSize <= 0
;

UPDATE #GNM_PoolHist SET waCLTV = NULL
WHERE waCLTV <= 0.0 OR waCLTV > 250
;

UPDATE #GNM_PoolHist SET waCLTV = NULL, waclSize = NULL
WHERE asOf in ('2004-03-01', '2004-06-01')
;

UPDATE #GNM_PoolHist SET waclSize = NULL
WHERE asOf in ('2004-03-01', '2004-04-01', '2004-06-01')
;

-- Update HPA_XYR and HPI
UPDATE #GNM_PoolHist perf SET perf.HPI = hpi.HPIndex
FROM #HPA_MA hpi
WHERE perf.asOf = hpi.asOf 
    AND hpi.Region = 'USA'
;

-- Update HPI_orig
UPDATE #GNM_PoolHist perf SET perf.HPI_orig = hpi.HPIndex
FROM #HPA_MA hpi
WHERE perf.originationDate = hpi.asOf
    AND hpi.Region = 'USA'
;
UPDATE #GNM_PoolHist perf SET perf.HPI_orig = he.hpi_earliest_value * power(1 + 3.0 / 100.0, -(datediff(MONTH, perf.originationDate, he.hpi_earliest_date) / 12.0))
FROM #HPI_Earliest he
WHERE perf.HPI_orig IS NULL
;
COMMIT;


-- Populate Missing Data
  -- First Create Pool Origination Data (or Oldest data available)

    -- OLS
DROP TABLE IF EXISTS #GNM_MinDate_OLS;
SELECT
    marketTicker,
    issueId,
    min(asOf) as asOf,
    cast(NULL as numeric(12, 2)) as waolSize
INTO #GNM_MinDate_OLS
FROM #GNM_PoolHist p
WHERE p.waolSize IS NOT NULL 
    AND p.waolSize <> -999
    AND p.waolSize > 0
GROUP BY marketTicker, issueId
;
COMMIT;

UPDATE #GNM_MinDate_OLS s SET s.waolSize = d.waolSize
FROM #GNM_PoolHist d
WHERE s.issueId = d.issueId
    AND s.asOf = d.asOf
;

    -- FICO
DROP TABLE IF EXISTS #GNM_MinDate_FICO;
SELECT
    marketTicker,
    issueId,
    min(asOf) as asOf,
    cast(NULL as numeric(8, 4)) as waocs
INTO #GNM_MinDate_FICO
FROM #GNM_PoolHist p
WHERE p.waocs IS NOT NULL 
    AND p.waocs <> -999
GROUP BY marketTicker, issueId
;
COMMIT;

UPDATE #GNM_MinDate_FICO s SET s.waocs = d.waocs
FROM #GNM_PoolHist d
WHERE s.issueId = d.issueId
    AND s.asOf = d.asOf
;

    -- OLTV
DROP TABLE IF EXISTS #GNM_MinDate_OLTV;
SELECT
    marketTicker,
    issueId,
    min(asOf) as asOf,
    cast(NULL as numeric(8, 4)) as waoltv
INTO #GNM_MinDate_OLTV
FROM #GNM_PoolHist p
WHERE p.waoltv IS NOT NULL
    AND p.waoltv <> -999
    AND p.waoltv > 0
GROUP BY marketTicker, issueId
;
COMMIT;

UPDATE #GNM_MinDate_OLTV s SET s.waoltv = d.waoltv
FROM #GNM_PoolHist d
WHERE s.issueId = d.issueId
    AND s.asOf = d.asOf
;

  -- Update OLS, FICO, OLTV, HPA, CLS, CLTV

    -- OLS
UPDATE #GNM_PoolHist perf SET perf.waolSize = s.waolSize
FROM #GNM_MinDate_OLS s
WHERE perf.issueId = s.issueId 
    AND (perf.waolSize IS NULL OR perf.waolSize <= 0)
;

DROP TABLE IF EXISTS #GNM_OriginationDate_OLS;
SELECT
    year(originationDate) as origYear,
    sum(balance * waolSize) / sum(balance) as WAVG_OLS,
    sum(balance) as sum_ls
INTO #GNM_OriginationDate_OLS
FROM #GNM_PoolHist p
WHERE waolSize IS NOT NULL 
    AND waolSize > 0
GROUP BY origYear
HAVING sum_ls > 10000000
;
COMMIT;

UPDATE #GNM_PoolHist perf SET perf.waolSize = ols.WAVG_OLS
FROM #GNM_OriginationDate_OLS ols
WHERE  year(perf.originationDate) = ols.origYear
    AND (perf.waolSize IS NULL OR perf.waolSize <= 0)
;

UPDATE #GNM_PoolHist perf SET perf.waolSize = (
    SELECT sum(balance * waolSize) / sum(balance) as WAVG_OLS 
    FROM #GNM_PoolHist p
    WHERE waolSize IS NOT NULL
        AND waolSize > 0
        AND year(p.originationDate) <= 1975
    )
WHERE year(perf.originationDate) <= 1975 AND (perf.waolSize IS NULL OR perf.waolSize <= 0)
;

UPDATE #GNM_PoolHist perf SET perf.waolSize = (
    SELECT sum(balance * waolSize) / sum(balance) as WAVG_OLS 
    FROM #GNM_PoolHist p
    WHERE waolSize IS NOT NULL
        AND waolSize > 0
    )
WHERE perf.waolSize IS NULL OR perf.waolSize <= 0
;

    -- FICO
UPDATE #GNM_PoolHist perf SET perf.waocs = s.waocs
FROM #GNM_MinDate_FICO s
WHERE perf.issueId = s.issueId 
    AND perf.waocs IS NULL
;

DROP TABLE IF EXISTS #GNM_OriginationDate_FICO;
SELECT
    year(originationDate) as origYear,
    sum(balance * waocs) / sum(balance) as WAVG_FICO,
    sum(balance) as sum_ls
INTO #GNM_OriginationDate_FICO
FROM #GNM_PoolHist p
WHERE waocs IS NOT NULL
GROUP BY origYear
HAVING sum_ls > 10000000
;
COMMIT;

UPDATE #GNM_PoolHist perf SET perf.waocs = oc.WAVG_FICO
FROM #GNM_OriginationDate_FICO oc
WHERE  year(perf.originationDate) = oc.origYear
    AND perf.waocs IS NULL 
;

UPDATE #GNM_PoolHist perf SET perf.waocs = (
    SELECT sum(balance * waocs) / sum(balance) as WAVG_FICO 
    FROM #GNM_PoolHist p
    WHERE waocs IS NOT NULL
    )
WHERE perf.waocs IS NULL 
;

    -- OLTV
UPDATE #GNM_PoolHist perf SET perf.waoltv = s.waoltv
FROM #GNM_MinDate_OLTV s
WHERE perf.issueId = s.issueId 
    AND perf.waoltv IS NULL
;

DROP TABLE IF EXISTS #GNM_OriginationDate_OLTV;
SELECT
    year(originationDate) as origYear,
    sum(balance * waoltv) / sum(balance) as WAVG_OLTV,
    sum(balance) as sum_ls
INTO #GNM_OriginationDate_OLTV
FROM #GNM_PoolHist p
WHERE waoltv IS NOT NULL
GROUP BY origYear
HAVING sum_ls > 10000000
;
COMMIT;

UPDATE #GNM_PoolHist perf SET perf.waoltv = ltv.WAVG_OLTV
FROM #GNM_OriginationDate_OLTV ltv
WHERE year(perf.originationDate) = ltv.origYear
    AND perf.waoltv IS NULL 
;

UPDATE #GNM_PoolHist perf SET perf.waoltv = (
    SELECT sum(balance * waoltv) / sum(balance) as WAVG_OLTV 
    FROM #GNM_PoolHist p
    WHERE waoltv IS NOT NULL
    )
WHERE perf.waoltv IS NULL 
;
COMMIT;

    -- HPA / CLS / CLTV
UPDATE #GNM_PoolHist SET HPA = HPI / HPI_orig
;

UPDATE #GNM_PoolHist perf SET perf.waclSize = perf.waolSize / perf.HPA
WHERE waclSize IS NULL
    OR waclSize = 0
    OR waclSize = -999
    OR waclSize = 999
;

UPDATE #GNM_PoolHist perf SET perf.wacltv = perf.waoltv * perf.factor / perf.HPA
WHERE wacltv IS NULL 
    OR wacltv = -999
    OR wacltv = 999
;
UPDATE #GNM_PoolHist perf SET perf.wacltv = 0.01
WHERE wacltv <= 0.0
;
COMMIT;



-- Tests

-- Time Series Tests
-- History for: CLTV, HPA, HPA_2YR
--SELECT marketTicker, asOf, count(1), sum(balance), sum(balance * waolSize) / sum(balance) as wavg_ols FROM #GNM_PoolHist GROUP BY marketTicker, asOf ORDER BY asOf
--SELECT marketTicker, originationDate, count(1), sum(balance), sum(balance * waolSize) / sum(balance) as wavg_ols FROM #GNM_PoolHist GROUP BY marketTicker, originationDate ORDER BY originationDate

--SELECT marketTicker, asOf, count(1), sum(balance), sum(balance * waocs) / sum(balance) as wavg_ocs FROM #GNM_PoolHist GROUP BY marketTicker, asOf ORDER BY asOf
--SELECT marketTicker, originationDate, count(1), sum(balance), sum(balance * waocs) / sum(balance) as wavg_ocs FROM #GNM_PoolHist GROUP BY marketTicker, originationDate ORDER BY originationDate

--SELECT marketTicker, asOf, count(1), sum(balance), sum(balance * waoltv) / sum(balance) as wavg_oltv FROM #GNM_PoolHist GROUP BY marketTicker, asOf ORDER BY asOf
--SELECT marketTicker, originationDate, count(1), sum(balance), sum(balance * waoltv) / sum(balance) as wavg_oltv FROM #GNM_PoolHist GROUP BY marketTicker, originationDate ORDER BY originationDate

--SELECT marketTicker, asOf, count(1), sum(balance), sum(balance * wac) / sum(balance) as wavg_wac FROM #GNM_PoolHist GROUP BY marketTicker, asOf ORDER BY asOf
--SELECT marketTicker, originationDate, count(1), sum(balance), sum(balance * wac) / sum(balance) as wavg_wac FROM #GNM_PoolHist GROUP BY marketTicker, originationDate ORDER BY originationDate

--SELECT marketTicker, asOf, count(1), sum(balance), sum(balance * waclSize) / sum(balance) as wavg_cls FROM #GNM_PoolHist GROUP BY marketTicker, asOf ORDER BY asOf
--SELECT marketTicker, originationDate, count(1), sum(balance), sum(balance * waclSize) / sum(balance) as wavg_cls FROM #GNM_PoolHist GROUP BY marketTicker, originationDate ORDER BY originationDate

--SELECT marketTicker, asOf, count(1), sum(balance), sum(balance * waCLTV) / sum(balance) as wavg_cltv FROM #GNM_PoolHist GROUP BY marketTicker, asOf ORDER BY asOf
--SELECT marketTicker, originationDate, count(1), sum(balance), sum(balance * waCLTV) / sum(balance) as wavg_cltv FROM #GNM_PoolHist GROUP BY marketTicker, originationDate ORDER BY originationDate

--SELECT marketTicker, asOf, count(1), sum(balance), sum(balance * HPA) / sum(balance) as wavg_hpa FROM #GNM_PoolHist GROUP BY marketTicker, asOf ORDER BY asOf
--SELECT marketTicker, originationDate, count(1), sum(balance), sum(balance * HPA) / sum(balance) as wavg_hpa FROM #GNM_PoolHist GROUP BY marketTicker, originationDate ORDER BY originationDate

----------------------------------------------------------------------------------------------
-- Check to see if Pools have originationDate IS NULL OR originationDate <= '1950-01-01'
----------------------------------------------------------------------------------------------
        declare   @cnt int
        SELECT
            @cnt =  count(1)
        FROM #GNM_PoolHist  WHERE originationDate IS NULL OR originationDate <= '1950-01-01'

        if (@cnt > 0)
        BEGIN
            RAISERROR 99999 'GNM Pools with INVALID VALUE for  CLTV PoolCount : %1!', @cnt
            RETURN
        END

----------------------------------------------------------------------------------------------
-- Check to see if Pools have balance IS NULL OR balance <= 0.0
----------------------------------------------------------------------------------------------
        SELECT
            @cnt =  count(1)
        FROM #GNM_PoolHist WHERE balance IS NULL OR balance <= 0.0

        if (@cnt > 0)
        BEGIN
            RAISERROR 99999 'GNM Pools with INVALID VALUE for balance PoolCount : %1!', @cnt
            RETURN
        END
        
----------------------------------------------------------------------------------------------
-- Check to see if Pools have waolSize IS NULL OR waolSize <= 0.0 OR waolSize > 1500000
----------------------------------------------------------------------------------------------
        SELECT
            @cnt =  count(1)
        FROM #GNM_PoolHist WHERE waolSize IS NULL OR waolSize <= 0.0 OR waolSize > 1500000

        if (@cnt > 0)
        BEGIN
            RAISERROR 99999 'GNM Pools with INVALID VALUE for waolSize PoolCount : %1!', @cnt
            RETURN
        END

----------------------------------------------------------------------------------------------
-- Check to see if Pools have waocs IS NULL OR waocs <= 0.0 OR waocs > 1000
----------------------------------------------------------------------------------------------
        SELECT
            @cnt =  count(1)
        FROM #GNM_PoolHist WHERE waocs IS NULL OR waocs <= 0.0 OR waocs > 1000

        if (@cnt > 0)
        BEGIN
            RAISERROR 99999 'GNM Pools with INVALID VALUE for waocs PoolCount : %1!', @cnt
            RETURN
        END
        
----------------------------------------------------------------------------------------------
-- Check to see if Pools have waoltv IS NULL OR waoltv <= 0.0 OR waoltv > 300
----------------------------------------------------------------------------------------------
        SELECT
            @cnt =  count(1)
        FROM #GNM_PoolHist WHERE waoltv IS NULL OR waoltv <= 0.0 OR waoltv > 300

        if (@cnt > 0)
        BEGIN
            RAISERROR 99999 'GNM Pools with INVALID VALUE for waoltv PoolCount : %1!', @cnt
            RETURN
        END
        
----------------------------------------------------------------------------------------------
-- Check to see if Pools have factor IS NULL OR factor < 0.0 OR factor > 1.0
----------------------------------------------------------------------------------------------
        SELECT
            @cnt =  count(1)
        FROM #GNM_PoolHist WHERE factor IS NULL OR factor < 0.0 OR factor > 1.0

        if (@cnt > 0)
        BEGIN
            RAISERROR 99999 'GNM Pools with INVALID VALUE for factor PoolCount : %1!', @cnt
            RETURN
        END
        
----------------------------------------------------------------------------------------------
-- Check to see if Pools have wac IS NULL OR wac <= 0.0 OR wac > 20
----------------------------------------------------------------------------------------------
        SELECT
            @cnt =  count(1)
        FROM #GNM_PoolHist WHERE wac IS NULL OR wac <= 0.0 OR wac > 20

        if (@cnt > 0)
        BEGIN
            RAISERROR 99999 'GNM Pools with INVALID VALUE for wac PoolCount : %1!', @cnt
            RETURN
        END

----------------------------------------------------------------------------------------------
-- Check to see if Pools have waclSize IS NULL OR waclSize <= 0.0 OR waclSize > 1500000
----------------------------------------------------------------------------------------------
        SELECT
            @cnt =  count(1)
        FROM #GNM_PoolHist WHERE waclSize IS NULL OR waclSize <= 0.0 OR waclSize > 1500000

        if (@cnt > 0)
        BEGIN
            RAISERROR 99999 'GNM Pools with INVALID VALUE for waclSize PoolCount : %1!', @cnt
            RETURN
        END

----------------------------------------------------------------------------------------------
-- Check to see if Pools have waCLTV IS NULL OR waCLTV <= 0.0 OR waCLTV > 300
----------------------------------------------------------------------------------------------
        SELECT
            @cnt =  count(1)
        FROM #GNM_PoolHist WHERE waCLTV IS NULL OR waCLTV <= 0.0 OR waCLTV > 300

        if (@cnt > 0)
        BEGIN
            RAISERROR 99999 'GNM Pools with INVALID VALUE for waCLTV PoolCount : %1!', @cnt
            RETURN
        END
        
----------------------------------------------------------------------------------------------
-- Check to see if Pools have HPI_orig IS NULL OR HPI_orig < 0.0 OR HPI_orig > 1000
----------------------------------------------------------------------------------------------
        SELECT
            @cnt =  count(1)
        FROM #GNM_PoolHist WHERE HPI_orig IS NULL OR HPI_orig < 0.0 OR HPI_orig > 1000

        if (@cnt > 0)
        BEGIN
            RAISERROR 99999 'GNM Pools with INVALID VALUE for HPI_orig PoolCount : %1!', @cnt
            RETURN
        END

----------------------------------------------------------------------------------------------
-- Check to see if Pools have HPA IS NULL OR HPA < 0.5 OR HPA > 10
----------------------------------------------------------------------------------------------
        SELECT
            @cnt =  count(1)
        FROM #GNM_PoolHist WHERE HPA IS NULL OR HPA < 0.5 OR HPA > 10

        if (@cnt > 0)
        BEGIN
            RAISERROR 99999 'GNM Pools with INVALID VALUE for HPA PoolCount : %1!', @cnt
            RETURN
        END

-- End Tests



-- Load Data into Scale Tables
DELETE FROM scale.GNM_PoolHist
WHERE marketTicker IN (SELECT tickerName FROM #ticker)
    AND asOf >= (SELECT asOf from #tmp_asOf)
;

INSERT INTO scale.GNM_PoolHist (issueId, marketTicker, asOf, balance, originationDate, origLoanSize, origFICO, origLTV, origNoteRate, currLoanSize, cltv, hpa)
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
    HPA
FROM #GNM_PoolHist
WHERE marketTicker IN (SELECT tickerName FROM #ticker)
    AND asOf >= (SELECT asOf from #tmp_asOf)
;

