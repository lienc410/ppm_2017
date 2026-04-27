-- Ginnie
-- Pool Level
-- Part 3 of 6
-- Script to update delinquency estimate data
-- Updates Delinquency Estimates

-- Before execute the script, need to set the dates to run for
DROP TABLE IF EXISTS #tmp_asOf;
--SELECT CAST('#####ASOF#####' AS DATE) asOf INTO #tmp_asOf
SELECT CAST ('1994-01-01' AS DATE) asOf INTO #tmp_asOf
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

CREATE INDEX loan_tickerName_idx ON #ticker(tickerName);
COMMIT;


-- Create Pool Historical Data
DROP TABLE IF EXISTS #GNM_PoolDelinquency;
SELECT
    ph.marketTicker,
    ph.issueId,
    ph.originationDate,
    ph.asOf,
    sf.wala,
    ph.origFICO,
    ph.cltv,
    cltvBucket = case
                    when ph.cltv < 40 THEN 40
                    when ph.cltv >= 120 THEN 140
                    else convert(int, ph.cltv / 20) * 20 + 20
                    end,
	walaBucket = case 
                    when sf.wala < 1 THEN 1
                    when sf.wala < 2 THEN 2
                    when sf.wala < 3 THEN 3
                    when sf.wala < 4 THEN 4
                    when sf.wala < 5 THEN 5
                    when sf.wala < 6 THEN 6
                    when sf.wala >= 160 THEN 180
                    else convert(int, sf.wala / 20) * 20 + 20
                    end,
	ficoBucket = case 
                    when ph.origFICO < 540 THEN 540
                    when ph.origFICO >= 780 THEN 800
                    else convert(int, ph.origFICO / 20, 0) * 20 + 20
                    end,
    ph.balance,
    cast(NULL as numeric(6, 3)) as Est_Pct_CURRENT,
    --cast(NULL as numeric(6, 3)) as Est_Pct_DELQ30,
    --cast(NULL as numeric(6, 3)) as Est_Pct_DELQ60,
    cast(NULL as numeric(6, 3)) as Est_Pct_DELQ30p,
    cast(NULL as numeric(6, 3)) as Est_Pct_DELQ60p,
    cast(NULL as numeric(6, 3)) as Est_Pct_DELQ90p,
    cast(NULL as numeric(6, 3)) as Est_Pct_Total
INTO #GNM_PoolDelinquency
FROM scale.GNM_PoolHist ph
JOIN #ticker tk
    ON ph.marketTicker = tk.tickerName
JOIN gnm.secFactor sf
    ON ph.issueId = sf.issueId
    AND ph.asOf = sf.asOf
WHERE 1=1
    AND ph.asOf >= (select asOf from #tmp_asOf)
;
COMMIT;

CREATE HG INDEX issueId_idx ON #GNM_PoolDelinquency(issueId);
CREATE LF INDEX asOf_idx ON #GNM_PoolDelinquency(asOf);
CREATE LF INDEX ticker_idx ON #GNM_PoolDelinquency(marketTicker);
COMMIT;


-- Create AsOf Date Delinquency Estimates using Loan Level Credit Data
DROP TABLE IF EXISTS #FHL_AsOf_PoolDelinquencyBuckets;
SELECT 
    d.asOf,
    cltvBucket = case
                    when cltv < 40 THEN 40
                    when cltv >= 120 THEN 140
                    else convert(int, cltv / 20) * 20 + 20
                    end,
	walaBucket = case 
                    when wala < 1 THEN 1
                    when wala < 2 THEN 2
                    when wala < 3 THEN 3
                    when wala < 4 THEN 4
                    when wala < 5 THEN 5
                    when wala < 6 THEN 6
                    when wala >= 160 THEN 180
                    else convert(int, wala / 20) * 20 + 20
                    end,
	ficoBucket = case 
                    when origFICO < 540 THEN 540
                    when origFICO >= 780 THEN 800
                    else convert(int, origFICO / 20) * 20 + 20
                    end,
    sum(h.balance) as balance,
    sum(CASE WHEN percentCURRENT IS NULL THEN est_pct_CURRENT ELSE percentCURRENT END * h.balance) / sum(h.balance) as Pct_CURRENT,
    sum(CASE WHEN percentDELQ30plus IS NULL THEN est_pct_DELQ30plus ELSE percentDELQ30plus END * h.balance) / sum(h.balance) as Pct_DELQ30p,
    sum(CASE WHEN percentDELQ60plus IS NULL THEN est_pct_DELQ60plus ELSE percentDELQ60plus END * h.balance) / sum(h.balance) as Pct_DELQ60p,
    sum(CASE WHEN percentDELQ90plus IS NULL THEN est_pct_DELQ90plus ELSE percentDELQ90plus END * h.balance) / sum(h.balance) as Pct_DELQ90p
INTO #FHL_AsOf_PoolDelinquencyBuckets
FROM scale.FHL_PoolDistribution d
JOIN scale.FHL_PoolHist h
    ON h.issueId = d.issueId
    AND h.asof = d.asof
JOIN fhl.secFactor s
    ON s.issueId = d.issueId
    AND s.asof = d.asof
WHERE 1=1
    --AND marketTicker = 'FGLMC'
GROUP BY d.asOf, cltvBucket, walaBucket, ficoBucket
ORDER BY d.asOf, cltvBucket, walaBucket, ficoBucket
;
COMMIT;

-- Update the Delinquency Estimates
UPDATE #GNM_PoolDelinquency pd SET 
    pd.Est_Pct_CURRENT = ldb.Pct_CURRENT,
    pd.Est_Pct_DELQ30p = ldb.Pct_DELQ30p,
    pd.Est_Pct_DELQ60p = ldb.Pct_DELQ60p,
    pd.Est_Pct_DELQ90p = ldb.Pct_DELQ90p
FROM #FHL_AsOf_PoolDelinquencyBuckets ldb
WHERE pd.asOf = ldb.asOf
    AND pd.cltvBucket = ldb.cltvBucket
    AND pd.walaBucket = ldb.walaBucket
    AND pd.ficoBucket = ldb.ficoBucket
;
COMMIT;


-- Create Aggregate Pct Delinquency Estimates using FHL Pool Data - no asOf group
DROP TABLE IF EXISTS #FHL_AVG_PoolDelinquencyBuckets;
SELECT
    cltvBucket,
    walaBucket,
    ficoBucket,
    sum(b.Pct_CURRENT * balance) / sum(balance) as Avg_Pct_CURRENT,
    sum(b.Pct_DELQ30p * balance) / sum(balance) as Avg_Pct_DELQ30p,
    sum(b.Pct_DELQ60p * balance) / sum(balance) as Avg_Pct_DELQ60p,
    sum(b.Pct_DELQ90p * balance) / sum(balance) as Avg_Pct_DELQ90p
INTO #FHL_AVG_PoolDelinquencyBuckets
FROM #FHL_AsOf_PoolDelinquencyBuckets b
WHERE 1=1
    AND Pct_CURRENT IS NOT NULL
    AND Pct_DELQ30p IS NOT NULL
    AND Pct_DELQ60p IS NOT NULL
    AND Pct_DELQ90p IS NOT NULL
GROUP BY cltvBucket, walaBucket, ficoBucket
ORDER BY cltvBucket, walaBucket, ficoBucket
;
COMMIT;

-- Update the Delinquency Estimates, where current/dq30/dq60/dq90 is still null
UPDATE #GNM_PoolDelinquency pd SET 
    pd.Est_Pct_CURRENT = ldb.Avg_Pct_CURRENT,
    pd.Est_Pct_DELQ30p = ldb.Avg_Pct_DELQ30p,
    pd.Est_Pct_DELQ60p = ldb.Avg_Pct_DELQ60p,
    pd.Est_Pct_DELQ90p = ldb.Avg_Pct_DELQ90p
FROM #FHL_AVG_PoolDelinquencyBuckets ldb
WHERE 1=1
    AND pd.cltvBucket = ldb.cltvBucket
    AND pd.walaBucket = ldb.walaBucket
    AND pd.ficoBucket = ldb.ficoBucket
    AND pd.Est_Pct_CURRENT IS NULL;
;
COMMIT;



-- Create Aggregate Pct Delinquency Estimates using FHL Pool Data - no asOf group
DROP TABLE IF EXISTS #FHL_AVG_PoolDelinquencyBuckets;
SELECT
    cltvBucket,
    walaBucket,
    ficoBucket,
    sum(b.Pct_CURRENT * balance) / sum(balance) as Avg_Pct_CURRENT,
    sum(b.Pct_DELQ30p * balance) / sum(balance) as Avg_Pct_DELQ30p,
    sum(b.Pct_DELQ60p * balance) / sum(balance) as Avg_Pct_DELQ60p,
    sum(b.Pct_DELQ90p * balance) / sum(balance) as Avg_Pct_DELQ90p
INTO #FHL_AVG_PoolDelinquencyBuckets
FROM #FHL_AsOf_PoolDelinquencyBuckets b
WHERE 1=1
    AND Pct_CURRENT IS NOT NULL
    AND Pct_DELQ30p IS NOT NULL
    AND Pct_DELQ60p IS NOT NULL
    AND Pct_DELQ90p IS NOT NULL
GROUP BY cltvBucket, walaBucket, ficoBucket
ORDER BY cltvBucket, walaBucket, ficoBucket
;
COMMIT;

-- Update the Delinquency Estimates, where current/dq30/dq60/dq90 is still null
UPDATE #GNM_PoolDelinquency pd SET 
    pd.Est_Pct_CURRENT = ldb.Avg_Pct_CURRENT,
    pd.Est_Pct_DELQ30p = ldb.Avg_Pct_DELQ30p,
    pd.Est_Pct_DELQ60p = ldb.Avg_Pct_DELQ60p,
    pd.Est_Pct_DELQ90p = ldb.Avg_Pct_DELQ90p
FROM #FHL_AVG_PoolDelinquencyBuckets ldb
WHERE 1=1
    AND pd.cltvBucket = ldb.cltvBucket
    AND pd.walaBucket = ldb.walaBucket
    AND pd.ficoBucket = ldb.ficoBucket
    AND pd.Est_Pct_CURRENT IS NULL;
;
COMMIT;


-- Create Aggregate Pct Delinquency Estimates using FHL Pool Data - no asOf or cltv group
DROP TABLE IF EXISTS #FHL_SIMPLE_AVG_PoolDelinquencyBuckets;
SELECT
    walaBucket,
    ficoBucket,
    sum(b.Pct_CURRENT * balance) / sum(balance) as Avg_Pct_CURRENT,
    sum(b.Pct_DELQ30p * balance) / sum(balance) as Avg_Pct_DELQ30p,
    sum(b.Pct_DELQ60p * balance) / sum(balance) as Avg_Pct_DELQ60p,
    sum(b.Pct_DELQ90p * balance) / sum(balance) as Avg_Pct_DELQ90p
INTO #FHL_SIMPLE_AVG_PoolDelinquencyBuckets
FROM #FHL_AsOf_PoolDelinquencyBuckets b
WHERE 1=1
    AND cltvBucket > 90
    AND Pct_CURRENT IS NOT NULL
    AND Pct_DELQ30p IS NOT NULL
    AND Pct_DELQ60p IS NOT NULL
    AND Pct_DELQ90p IS NOT NULL
GROUP BY walaBucket, ficoBucket
ORDER BY walaBucket, ficoBucket
;
COMMIT;

-- Update the Delinquency Estimates, where current/dq30/dq60/dq90 is still null
UPDATE #GNM_PoolDelinquency pd SET 
    pd.Est_Pct_CURRENT = ldb.Avg_Pct_CURRENT,
    pd.Est_Pct_DELQ30p = ldb.Avg_Pct_DELQ30p,
    pd.Est_Pct_DELQ60p = ldb.Avg_Pct_DELQ60p,
    pd.Est_Pct_DELQ90p = ldb.Avg_Pct_DELQ90p
FROM #FHL_SIMPLE_AVG_PoolDelinquencyBuckets ldb
WHERE 1=1
    AND pd.walaBucket = ldb.walaBucket
    AND pd.ficoBucket = ldb.ficoBucket
    AND pd.Est_Pct_CURRENT IS NULL;
;
COMMIT;


-- Create Aggregate Pct Delinquency Estimates using FHL Pool Data - no asOf or cltv or wala group
DROP TABLE IF EXISTS #FHL_SUPER_SIMPLE_AVG_PoolDelinquencyBuckets;
SELECT
    ficoBucket,
    sum(b.Pct_CURRENT * balance) / sum(balance) as Avg_Pct_CURRENT,
    sum(b.Pct_DELQ30p * balance) / sum(balance) as Avg_Pct_DELQ30p,
    sum(b.Pct_DELQ60p * balance) / sum(balance) as Avg_Pct_DELQ60p,
    sum(b.Pct_DELQ90p * balance) / sum(balance) as Avg_Pct_DELQ90p
INTO #FHL_SUPER_SIMPLE_AVG_PoolDelinquencyBuckets
FROM #FHL_AsOf_PoolDelinquencyBuckets b
WHERE 1=1
    AND cltvBucket > 90
    AND walaBucket > 80
    AND Pct_CURRENT IS NOT NULL
    AND Pct_DELQ30p IS NOT NULL
    AND Pct_DELQ60p IS NOT NULL
    AND Pct_DELQ90p IS NOT NULL
GROUP BY ficoBucket
ORDER BY ficoBucket
;
COMMIT;

-- Update the Delinquency Estimates, where current/dq30/dq60/dq90 is still null
UPDATE #GNM_PoolDelinquency pd SET 
    pd.Est_Pct_CURRENT = ldb.Avg_Pct_CURRENT,
    pd.Est_Pct_DELQ30p = ldb.Avg_Pct_DELQ30p,
    pd.Est_Pct_DELQ60p = ldb.Avg_Pct_DELQ60p,
    pd.Est_Pct_DELQ90p = ldb.Avg_Pct_DELQ90p
FROM #FHL_SUPER_SIMPLE_AVG_PoolDelinquencyBuckets ldb
WHERE 1=1
    AND pd.ficoBucket = ldb.ficoBucket
    AND pd.Est_Pct_CURRENT IS NULL;
;
COMMIT;


-- Sum the Delinquency Estimates
UPDATE #GNM_PoolDelinquency SET 
    Est_Pct_Total = Est_Pct_CURRENT + Est_Pct_DELQ30p
;
COMMIT;


-- Adjust for 0 Totals
UPDATE #GNM_PoolDelinquency SET
    Est_Pct_CURRENT = 100.0,
    Est_Pct_Total = 100.0
WHERE Est_Pct_Total <= 0.0
;
COMMIT;

-- Normalize the Delinquency Estimates to Sum to 100
UPDATE #GNM_PoolDelinquency SET 
    Est_Pct_CURRENT = 100.0 * (Est_Pct_CURRENT / Est_Pct_Total),
    Est_Pct_DELQ30p = 100.0 * (Est_Pct_DELQ30p / Est_Pct_Total),
    Est_Pct_DELQ60p = 100.0 * (Est_Pct_DELQ60p / Est_Pct_Total),
    Est_Pct_DELQ90p = 100.0 * (Est_Pct_DELQ90p / Est_Pct_Total)
;
COMMIT;



-- Tests

-- Time Series Tests
-- History for: delinquency
--SELECT 
--    marketTicker, 
--    asOf, 
--    count(1), 
--    sum(balance), 
--    sum(balance * Est_Pct_CURRENT) / sum(CASE WHEN Est_Pct_CURRENT IS NULL THEN 0.0 ELSE balance END) as wavg_current,
--    sum(balance * Est_Pct_DELQ30p) / sum(CASE WHEN Est_Pct_DELQ30p IS NULL THEN 0.0 ELSE balance END) as wavg_delq30p,
--    sum(balance * Est_Pct_DELQ60p) / sum(CASE WHEN Est_Pct_DELQ60p IS NULL THEN 0.0 ELSE balance END) as wavg_delq60p,
--    sum(balance * Est_Pct_DELQ90p) / sum(CASE WHEN Est_Pct_DELQ90p IS NULL THEN 0.0 ELSE balance END) as wavg_delq90p
--FROM #GNM_PoolDelinquency 
--GROUP BY marketTicker, asOf 
--ORDER BY asOf
--;

--SELECT 
--    marketTicker, 
--    pd.asOf, 
--    count(1), 
--    sum(balance), 
--    sum(balance * CASE WHEN percentCURRENT IS NULL THEN Est_Pct_CURRENT ELSE percentCURRENT END) / sum(CASE WHEN Est_Pct_CURRENT IS NULL THEN 0.0 ELSE balance END) as wavg_current,
--    sum(balance * CASE WHEN percentDELQ30plus IS NULL THEN Est_Pct_DELQ30plus ELSE percentDELQ30plus END) / sum(CASE WHEN Est_Pct_DELQ30plus IS NULL THEN 0.0 ELSE balance END) as wavg_delq30p,
--    sum(balance * CASE WHEN percentDELQ60plus IS NULL THEN Est_Pct_DELQ60plus ELSE percentDELQ60plus END) / sum(CASE WHEN Est_Pct_DELQ60plus IS NULL THEN 0.0 ELSE balance END) as wavg_delq60p,
--    sum(balance * CASE WHEN percentDELQ90plus IS NULL THEN Est_Pct_DELQ90plus ELSE percentDELQ90plus END) / sum(CASE WHEN Est_Pct_DELQ90plus IS NULL THEN 0.0 ELSE balance END) as wavg_delq90p
--FROM scale.GNM_PoolDistribution pd
--JOIN scale.GNM_PoolHist ph
--    ON pd.issueId = ph.issueId
--    AND pd.asOf = ph.asOf
--GROUP BY marketTicker, pd.asOf 
--ORDER BY pd.asOf
--;

--SELECT marketTicker, asOf, count(1), sum(balance), sum(balance * Est_Pct_CURRENT) / sum(balance) as wavg_curr FROM #GNM_PoolDelinquency GROUP BY marketTicker, asOf ORDER BY asOf

--SELECT marketTicker, asOf, count(1), sum(balance), sum(balance * Est_Pct_DELQ30p) / sum(balance) as wavg_dq30p FROM #GNM_PoolDelinquency GROUP BY marketTicker, asOf ORDER BY asOf

--SELECT marketTicker, asOf, count(1), sum(balance), sum(balance * Est_Pct_DELQ60p) / sum(balance) as wavg_dq60p FROM #GNM_PoolDelinquency GROUP BY marketTicker, asOf ORDER BY asOf

--SELECT marketTicker, asOf, count(1), sum(balance), sum(balance * Est_Pct_DELQ90p) / sum(balance) as wavg_dq90p FROM #GNM_PoolDelinquency GROUP BY marketTicker, asOf ORDER BY asOf

----------------------------------------------------------------------------------------------
-- Check to see if Pools have Est_Pct_CURRENT IS NULL OR Est_Pct_CURRENT < 0.0 OR Est_Pct_CURRENT > 100.0
----------------------------------------------------------------------------------------------
        declare   @cnt int
        SELECT
            @cnt =  count(1)
        FROM #GNM_PoolDelinquency WHERE Est_Pct_CURRENT IS NULL OR Est_Pct_CURRENT < 0.0 OR Est_Pct_CURRENT > 100.0

        if (@cnt > 0)
        BEGIN
            RAISERROR 99999 'GNM Pools with INVALID VALUE for Est_Pct_CURRENT PoolCount : %1!', @cnt
            RETURN
        END

----------------------------------------------------------------------------------------------
-- Check to see if Pools have Est_Pct_DELQ30p IS NULL OR Est_Pct_DELQ30p < 0.0 OR Est_Pct_DELQ30p > 100.0
----------------------------------------------------------------------------------------------

        SELECT
            @cnt =  count(1)
        FROM #GNM_PoolDelinquency WHERE Est_Pct_DELQ30p IS NULL OR Est_Pct_DELQ30p < 0.0 OR Est_Pct_DELQ30p > 100.0

        if (@cnt > 0)
        BEGIN
            RAISERROR 99999 'GNM Pools with INVALID VALUE for Est_Pct_DELQ30p PoolCount : %1!', @cnt
            RETURN
        END

----------------------------------------------------------------------------------------------
-- Check to see if Pools have Est_Pct_DELQ60p IS NULL OR Est_Pct_DELQ60p < 0.0 OR Est_Pct_DELQ60p > 100.0
----------------------------------------------------------------------------------------------

        SELECT
            @cnt =  count(1)
        FROM #GNM_PoolDelinquency WHERE Est_Pct_DELQ60p IS NULL OR Est_Pct_DELQ60p < 0.0 OR Est_Pct_DELQ60p > 100.0

        if (@cnt > 0)
        BEGIN
            RAISERROR 99999 'GNM Pools with INVALID VALUE for Est_Pct_DELQ60p PoolCount : %1!', @cnt
            RETURN
        END

----------------------------------------------------------------------------------------------
-- Check to see if Pools have Est_Pct_DELQ90p IS NULL OR Est_Pct_DELQ90p < 0.0 OR Est_Pct_DELQ90p > 100.0
----------------------------------------------------------------------------------------------

        SELECT
            @cnt =  count(1)
        FROM #GNM_PoolDelinquency WHERE Est_Pct_DELQ90p IS NULL OR Est_Pct_DELQ90p < 0.0 OR Est_Pct_DELQ90p > 100.0

        if (@cnt > 0)
        BEGIN
            RAISERROR 99999 'GNM Pools with INVALID VALUE for Est_Pct_DELQ90p PoolCount : %1!', @cnt
            RETURN
        END

----------------------------------------------------------------------------------------------
-- Check to see if Pools have abs(Est_Pct_CURRENT + Est_Pct_DELQ30p - 100.0) > 0.1
----------------------------------------------------------------------------------------------

        SELECT
            @cnt =  count(1)
        FROM #GNM_PoolDelinquency WHERE abs(Est_Pct_CURRENT + Est_Pct_DELQ30p - 100.0) > 0.1

        if (@cnt > 0)
        BEGIN
            RAISERROR 99999 'GNM Pools with Est Delinquency Status not summing to 100 PoolCount : %1!', @cnt
            RETURN
        END

-- End Tests



-- Update Scale Pool Tables
UPDATE scale.GNM_PoolDistribution_v2_00 spd SET 
    spd.Est_Pct_CURRENT = pd.Est_Pct_CURRENT,
    spd.Est_Pct_DELQ30plus = pd.Est_Pct_DELQ30p,
    spd.Est_Pct_DELQ60plus = pd.Est_Pct_DELQ60p,
    spd.Est_Pct_DELQ90plus = pd.Est_Pct_DELQ90p
FROM #GNM_PoolDelinquency pd
WHERE 1=1
    AND spd.issueId = pd.issueId
    AND spd.asOf = pd.asOf
    AND pd.marketTicker IN (SELECT tickerName FROM #ticker)
    AND pd.asOf >= (SELECT asOf from #tmp_asOf)
;