-- Refinance Queries (Pool Level)


-- Before execute the script, need to set the ticker 
--      Coventional:    FNCL, FGLMC
--      Jumbo:          FNCK, FGT6
DROP TABLE IF EXISTS #ticker;
CREATE TABLE #ticker(
    tickerName varchar(20)
)
;
INSERT #ticker SELECT 'FNCL';    --Conventional Fannie
INSERT #ticker SELECT 'FGLMC';   --Conventional Freddie
INSERT #ticker SELECT 'FNCK';    --Jumbo Fannie
INSERT #ticker SELECT 'FGT6';    --Jumbo Freddie
INSERT #ticker SELECT 'FGU6';    --CQ Freddie High LTV[105-125]
INSERT #ticker SELECT 'FGU9';    --CR Freddie High LTV[125-150]
INSERT #ticker SELECT 'FNCQ30';  --CQ Fannie High LTV[105-125]
INSERT #ticker SELECT 'FNCR';    --CR Fannie High LTV[125-150]
COMMIT;
CREATE INDEX loan_tickerName_idx ON #ticker(tickerName);
COMMIT;


-- Refinance Queries (Pool Level)


-- Create Sample of Pools
DROP TABLE IF EXISTS #PoolIssueId;
SELECT issueId, NEWID() as IDX, marketTicker
INTO #PoolIssueId
FROM (
SELECT distinct issueId, marketTicker FROM fhl.sec p WHERE p.collateralType = 'LOAN'
    UNION
SELECT distinct issueId, marketTicker FROM fnm.sec p WHERE p.collateralType = 'LOAN'
) o
WHERE o.marketTicker IN (SELECT tickerName FROM #ticker)
;
COMMIT;

DROP TABLE IF EXISTS #PoolIDSample;
--SELECT top 1000 issueId 
SELECT issueId
INTO #PoolIDSample FROM #PoolIssueId 
--WHERE issueId = 2863040
--WHERE issueId IN (SELECT issueId FROM report.Scale_V2_conv_samples_id)
ORDER BY IDX;
COMMIT;



-- Create Monthly HPI data from raw FHFA data
DROP TABLE IF EXISTS #t;
CREATE TABLE #t(
    monthInQuarter int
)
;    
INSERT #t SELECT 1;
INSERT #t SELECT 2;
INSERT #t SELECT 3;
COMMIT;

DROP TABLE IF EXISTS #HomePriceIndex_temp1;
SELECT
    RegionType,
    Region,
    MSACode,
    Year,
    Quarter,
    convert(date, convert(char(8), Year * 10000 + (3 * Quarter) * 100 + 1)) as asOf,
    NSAIndex as HPIndex
INTO #HomePriceIndex_temp1
FROM hpi.HomePriceIndex
WHERE TransactionType = 'ALL_TRANSACTIONS'
    AND loadQuarter = (SELECT max(loadQuarter) FROM hpi.HomePriceIndex)
    AND RegionType IN ('STATE','US_AND_CENSUS','USA')
;
COMMIT;

-- Extend Time Series for several months after end
DROP TABLE IF EXISTS #HomePriceIndex_1Q;
SELECT
    RegionType,
    Region,
    MSACode,
    year(nextAsOf) as Year,
    quarter(nextAsOf) as Quarter,
    dateadd(month,3,AsOf) as nextAsOf,
    HPIndex * power(1.0 + 3.0 / 100.0, 3.0 / 12.0)
INTO #HomePriceIndex_1Q
FROM #HomePriceIndex_temp1
WHERE asOf = (SELECT max(asOf) FROM #HomePriceIndex_temp1)
;
COMMIT;

DROP TABLE IF EXISTS #HomePriceIndex_2Q;
SELECT
    RegionType,
    Region,
    MSACode,
    year(nextAsOf) as Year,
    quarter(nextAsOf) as Quarter,
    dateadd(month,6,AsOf) as nextAsOf,
    HPIndex * power(1.0 + 3.0 / 100.0, 3.0 / 12.0) * power(1.0 + 3.0 / 100.0, 3.0 / 12.0)
INTO #HomePriceIndex_2Q
FROM #HomePriceIndex_temp1
WHERE asOf = (SELECT max(asOf) FROM #HomePriceIndex_temp1)
;
COMMIT;

INSERT INTO #HomePriceIndex_temp1 SELECT * FROM #HomePriceIndex_1Q;
INSERT INTO #HomePriceIndex_temp1 SELECT * FROM #HomePriceIndex_2Q;

DROP TABLE IF EXISTS #HomePriceIndex_norm;
SELECT
    t1.RegionType,
    t1.Region,
    t1.MSACode,
    t1.asOf as beginDate,
    t2.asOf as endDate,
    t1.HPIndex as from_Idx,
    t2.HPIndex as to_Idx,
    t1.HPIndex + (t2.HPIndex - t1.HPIndex) / 3.0 as interp1,
    t1.HPIndex + 2 * (t2.HPIndex - t1.HPIndex) / 3.0 as interp2
INTO #HomePriceIndex_norm
FROM #HomePriceIndex_temp1 t1
JOIN #HomePriceIndex_temp1 t2
    ON t1.asOf = dateadd(month,-3,t2.AsOf)
    AND t1.RegionType = t2.RegionType
    AND (t1.Region = t2.Region OR t1.MSACode = t2.MSACode)
;
COMMIT;

DROP TABLE IF EXISTS #HomePriceIndex_monthly;
SELECT
    t1.RegionType as RegionType,
    t1.Region as Region,
    t1.MSACode as MSACode,
    t1.Year as Year,
    t1.Quarter as Quarter,
    convert(date, convert(char(8), Year * 10000 + (3 * (Quarter - 1) + t.monthInQuarter) * 100 + 1)) as asOf,
    CASE 
        WHEN t.monthInQuarter = 1 THEN norm.interp1 
        WHEN t.monthInQuarter = 2 THEN norm.interp2 
        ELSE t1.HPIndex 
    END as HPIndex
INTO #HomePriceIndex_monthly
FROM #HomePriceIndex_temp1 t1
CROSS JOIN #t t
LEFT JOIN #HomePriceIndex_norm norm
    ON t1.asOf = norm.endDate
    AND t1.RegionType = norm.RegionType
    AND (t1.Region = norm.Region OR t1.MSACode = norm.MSACode)
;
COMMIT;

CREATE INDEX loan_asOf_idx ON #HomePriceIndex_monthly(asOf);
COMMIT;

  -- Creates a X YR Moving HPA
DROP TABLE IF EXISTS #HPA_MA;
SELECT
    t1.RegionType,
    t1.Region,
    t1.MSACode,
    t1.asOf,
    t1.HPIndex as HPIndex,
    t2.HPIndex as HPIndex_1YR,
    t3.HPIndex as HPIndex_2YR,
    CASE WHEN t2.HPIndex IS NULL THEN NULL ELSE t1.HPIndex / t2.HPIndex END as HPA_1YR,
    CASE WHEN t3.HPIndex IS NULL THEN NULL ELSE t1.HPIndex / t3.HPIndex END as HPA_2YR
INTO #HPA_MA
FROM #HomePriceIndex_monthly t1
LEFT JOIN #HomePriceIndex_monthly t2
    ON t1.RegionType = t2.RegionType
    AND t1.Region = t2.Region
    AND (t1.MSACode = t2.MSACode OR t1.MSACode IS NULL AND t2.MSACode IS NULL)
    AND t1.asOf = dateadd(month, 12, t2.asOf)
LEFT JOIN #HomePriceIndex_monthly t3
    ON t1.RegionType = t3.RegionType
    AND t1.Region = t3.Region
    AND (t1.MSACode = t3.MSACode OR t1.MSACode IS NULL AND t3.MSACode IS NULL)
    AND t1.asOf = dateadd(month, 24, t3.asOf)
;
COMMIT;

CREATE INDEX asOf_idx ON #HPA_MA(asOf);
COMMIT;

DELETE FROM #HPA_MA WHERE HPA_1YR IS NULL;
COMMIT;

DELETE FROM #HPA_MA WHERE HPA_2YR IS NULL;
COMMIT;



 -- Get the Mortgage Rates from Time Series Database
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
;
COMMIT;

-- Pivot table for Mtg Rate
DROP TABLE IF EXISTS #MtgRate;
SELECT  c.asof, 
        c.asof_lag1,
        c.asof_lag2,
        MtgRate_conv = c.MtgRate, 
        MtgRate_gnma = g.MtgRate
INTO #MtgRate
FROM #Mtg30YrRates_monthly c
LEFT JOIN #Mtg30YrRates_monthly g ON c.asOf = g.asOf AND g.SeriesName in ('GINNIE_30YR')
WHERE c.SeriesName in ('CONVENTIONAL_30YR')
;
COMMIT;



-- Pool Ids and Dates

  -- Freddie
DROP TABLE IF EXISTS #FHL_Pools;
SELECT
    p.marketTicker,
    p.issueId,
    p.OrigCoupon,
    f.asOf,
    p.issueDate,
    CASE WHEN f.calcOrigMonth IS NULL THEN p.issueDate ELSE convert(date, convert(char(8), f.calcOrigMonth * 100 + 1)) END as originationDate,
    x.originalTerm as origTerm,
    1.0 - ((1.0 + f.wac / 1200.0)^f.wala - 1.0) / ((1.0 + f.wac / 1200.0)^360 - 1.0) as factor,
    f.wala, 
    f.schamBalance, -- offset by 1 so that our model projection for the factor date will match the prepay for that period
    f.wac, 
    CASE WHEN f.waoltv = -999 THEN NULL ELSE f.waoltv END as waoltv,
    CASE WHEN f.waclSize = -999 THEN NULL ELSE f.waclSize END as waclSize,
    CASE WHEN f.waolSize = -999 THEN NULL ELSE f.waolSize END as waolSize,
    CASE WHEN f.waocs = -999 THEN NULL ELSE f.waocs END as waocs, 
    f.currentBalance, -- offset by 1 so that our model projection for the factor date will match the prepay for that period
    f.inVoluntaryAmount,
    s.waCLTV,
    s.refi_incentive as incentive_PL,
    cast(NULL as numeric(10, 4)) as incentive_LL,
    cast(NULL as numeric(10, 4)) as incentive_ToConv,
    cast(NULL as numeric(10, 4)) as incentive_ToGNMA_PL,
    cast(NULL as numeric(10, 4)) as incentive_ToGNMA_LL,
    cast(NULL as numeric(10, 4)) as incentive_ToGNMA,
    cast(NULL as numeric(10, 4)) as incentive,
    cast(NULL as numeric(10, 4)) as refiEligPct,
    s.currLLPA as cLLPA,
    s.currPMI as cPMI,
    s.origPMI as oPMI,
    CASE WHEN s.percentHARP IS NULL THEN 0.0 ELSE s.percentHARP END as Pct_HARP,
    s.burnout as burnout_OLD,
    cast(NULL as numeric(12, 4)) as burnout,
    s.SATO as SATO,
    cast(NULL as numeric(10, 4)) as HPA,
    cast(NULL as numeric(10, 4)) as HPI,
    cast(NULL as numeric(10, 4)) as HPA_1YR,
    cast(NULL as numeric(10, 4)) as HPA_2YR,
    cast(NULL as numeric(8, 2)) as Pct_OWNER,
    cast(NULL as numeric(8, 2)) as Pct_2ND,
    cast(NULL as numeric(8, 2)) as Pct_INV,
    cast(NULL as numeric(8, 2)) as Pct_OTHERS,
    cast(NULL as numeric(8, 2)) as Pct_PURCH,
    cast(NULL as numeric(8, 2)) as Pct_REFI,
    cast(NULL as numeric(8, 2)) as Pct_CURRENT,
    cast(NULL as numeric(8, 2)) as Pct_DELQ,
    cast(NULL as numeric(8, 2)) as Pct_D30,
    cast(NULL as numeric(8, 2)) as Pct_D60,
    cast(NULL as numeric(8, 2)) as Pct_D90,
    cast(NULL as numeric(8, 2)) as Pct_TPO
INTO #FHL_Pools
FROM fhl.sec p
JOIN fhl.Prefix x
    ON p.prefix = x.prefix
    AND p.product = x.product
JOIN fhl.secFactor f
    ON p.issueId = f.issueId
--JOIN fhl.secFactor f2
--    ON p.issueId = f2.issueId
--    AND f.asOf = dateadd(month, -1, f2.asOf)
LEFT JOIN fhl.secSupp s
    ON p.issueId = s.issueId
    AND s.asOf = f.asOf
JOIN #PoolIDSample pid ON pid.issueId = p.issueId
WHERE 1=1
    AND p.marketTicker IN (SELECT tickerName FROM #ticker)
    AND p.collateralType = 'LOAN'
    AND f.wala >= 1
    AND f.schamBalance > 0.01
--    AND f2.schamBalance > 0.01
    AND f.wac > 0
;
COMMIT;

CREATE INDEX issueId_idx ON #FHL_Pools(issueId);
CREATE INDEX issueDate_idx ON #FHL_Pools(issueDate);
CREATE INDEX asOf_idx ON #FHL_Pools(asOf);
COMMIT;



-- Update HPA_XYR and HPI
UPDATE #FHL_Pools perf SET perf.HPA_2YR = hpi.HPA_2YR, perf.HPA_1YR = hpi.HPA_1YR, perf.HPI = hpi.HPIndex
FROM #HPA_MA hpi
WHERE perf.asOf = hpi.asOf 
    AND hpi.Region = 'USA'
;


  -- Fannie
DROP TABLE IF EXISTS #fnm_Pools;
SELECT
    p.marketTicker,
    p.issueId,
    p.OrigCoupon,
    f.asOf,
    p.issueDate,
    CASE WHEN f.calcOrigMonth IS NULL THEN p.issueDate ELSE convert(date, convert(char(8), f.calcOrigMonth * 100 + 1)) END as originationDate,
    x.originalTerm as origTerm,
    1.0 - ((1.0 + f.wac / 1200.0)^f.wala - 1.0) / ((1.0 + f.wac / 1200.0)^360 - 1.0) as factor,
    f.wala, 
    f.schamBalance, -- offset by 1 so that our model projection for the factor date will match the prepay for that period
    f.wac, 
    CASE WHEN f.waoltv = -999 THEN NULL ELSE f.waoltv END as waoltv,
    CASE WHEN f.waclSize = -999 THEN NULL ELSE f.waclSize END as waclSize,
    CASE WHEN f.waolSize = -999 THEN NULL ELSE f.waolSize END as waolSize,
    CASE WHEN f.waocs = -999 THEN NULL ELSE f.waocs END as waocs, 
    f.currentBalance, -- offset by 1 so that our model projection for the factor date will match the prepay for that period
    f.inVoluntaryAmount,
    s.waCLTV,
    s.refi_incentive as incentive_PL,
    cast(NULL as numeric(10, 4)) as incentive_LL,
    cast(NULL as numeric(10, 4)) as incentive_ToConv,
    cast(NULL as numeric(10, 4)) as incentive_ToGNMA_PL,
    cast(NULL as numeric(10, 4)) as incentive_ToGNMA_LL,
    cast(NULL as numeric(10, 4)) as incentive_ToGNMA,
    cast(NULL as numeric(10, 4)) as incentive,
    cast(NULL as numeric(10, 4)) as refiEligPct,
    s.currLLPA as cLLPA,
    s.currPMI as cPMI,
    s.origPMI as oPMI,
    CASE WHEN s.percentHARP IS NULL THEN 0.0 ELSE s.percentHARP END as Pct_HARP,
    s.burnout as burnout_OLD,
    cast(NULL as numeric(12, 4)) as burnout,
    s.SATO as SATO,
    cast(NULL as numeric(10, 4)) as HPA,
    cast(NULL as numeric(10, 4)) as HPI,
    cast(NULL as numeric(10, 4)) as HPA_1YR,
    cast(NULL as numeric(10, 4)) as HPA_2YR,
    cast(NULL as numeric(8, 2)) as Pct_OWNER,
    cast(NULL as numeric(8, 2)) as Pct_2ND,
    cast(NULL as numeric(8, 2)) as Pct_INV,
    cast(NULL as numeric(8, 2)) as Pct_OTHERS,
    cast(NULL as numeric(8, 2)) as Pct_PURCH,
    cast(NULL as numeric(8, 2)) as Pct_REFI,
    cast(NULL as numeric(8, 2)) as Pct_CURRENT,
    cast(NULL as numeric(8, 2)) as Pct_DELQ,
    cast(NULL as numeric(8, 2)) as Pct_D30,
    cast(NULL as numeric(8, 2)) as Pct_D60,
    cast(NULL as numeric(8, 2)) as Pct_D90,
    cast(NULL as numeric(8, 2)) as Pct_TPO
INTO #fnm_Pools
FROM fnm.sec p
JOIN fnm.Prefix x
    ON p.prefix = x.prefix
    AND p.product = x.product
JOIN fnm.secFactor f
    ON p.issueId = f.issueId
--JOIN fnm.secFactor f2
--    ON p.issueId = f2.issueId
--    AND f.asOf = dateadd(month, -1, f2.asOf)
LEFT JOIN fnm.secSupp s
    ON p.issueId = s.issueId
    AND s.asOf = f.asOf
JOIN #PoolIDSample pid ON pid.issueId = p.issueId
WHERE 1=1
    AND p.marketTicker IN (SELECT tickerName FROM #ticker)
    AND p.collateralType = 'LOAN'
    AND f.wala >= 1
    AND f.schamBalance > 0.01
--    AND f2.schamBalance > 0.01
    AND f.wac > 0
;
COMMIT;

CREATE INDEX issueId_idx ON #fnm_Pools(issueId);
CREATE INDEX issueDate_idx ON #fnm_Pools(issueDate);
CREATE INDEX asOf_idx ON #fnm_Pools(asOf);
COMMIT;


-- Update HPA_XYR and HPI
--  Freddie
UPDATE #fhl_Pools perf SET perf.HPA_2YR = hpi.HPA_2YR, perf.HPA_1YR = hpi.HPA_1YR, perf.HPI = hpi.HPIndex
FROM #HPA_MA hpi
WHERE perf.asOf = hpi.asOf 
    AND hpi.Region = 'USA'
;


--  Fannie
UPDATE #fnm_Pools perf SET perf.HPA_2YR = hpi.HPA_2YR, perf.HPA_1YR = hpi.HPA_1YR, perf.HPI = hpi.HPIndex
FROM #HPA_MA hpi
WHERE perf.asOf = hpi.asOf 
    AND hpi.Region = 'USA'
;


-- Pool Origination Data (or Oldest data available)
  
  -- Freddie
DROP TABLE IF EXISTS #FHL_MinDate_FICO;
SELECT
    marketTicker,
    issueId,
    issueDate,
    min(asOf) as asOf,
    cast(NULL as numeric(8, 4)) as waocs
INTO #FHL_MinDate_FICO
FROM #FHL_Pools p
WHERE p.waocs IS NOT NULL 
    AND p.waocs <> -999
GROUP BY marketTicker, issueId, issueDate
;
COMMIT;

UPDATE #FHL_MinDate_FICO s SET s.waocs = d.waocs
FROM #FHL_Pools d
WHERE s.issueId = d.issueId
    AND s.asOf = d.asOf
;

DROP TABLE IF EXISTS #FHL_MinDate_OLTV;
SELECT
    marketTicker,
    issueId,
    issueDate,
    min(asOf) as asOf,
    cast(NULL as numeric(8, 4)) as waoltv
INTO #FHL_MinDate_OLTV
FROM #FHL_Pools p
WHERE p.waoltv IS NOT NULL
    AND p.waoltv <> -999
GROUP BY marketTicker, issueId, issueDate
;
COMMIT;

UPDATE #FHL_MinDate_OLTV s SET s.waoltv = d.waoltv
FROM #FHL_Pools d
WHERE s.issueId = d.issueId
    AND s.asOf = d.asOf
;

DROP TABLE IF EXISTS #FHL_Origination;
SELECT
    marketTicker,
    issueId,
    cast(NULL as date) as originationDate,
    min(asOf) as asOf,
   cast(NULL as numeric(8, 4)) as HPI_orig
INTO #FHL_Origination
FROM #FHL_Pools p
GROUP BY marketTicker, issueId
;
COMMIT;

UPDATE #FHL_Origination s SET s.originationDate = p.originationDate
FROM #FHL_Pools p
WHERE p.issueId = s.issueId
    AND p.asOf = s.asOf
;
COMMIT;

UPDATE #FHL_Origination s SET s.HPI_orig = hpi.HPIndex
FROM #HPA_MA hpi
WHERE s.originationDate = hpi.asOf
;
COMMIT;

  
  -- Fannie
DROP TABLE IF EXISTS #fnm_MinDate_FICO;
SELECT
    marketTicker,
    issueId,
    issueDate,
    min(asOf) as asOf,
    cast(NULL as numeric(8, 4)) as waocs
INTO #fnm_MinDate_FICO
FROM #fnm_Pools p
WHERE p.waocs IS NOT NULL 
    AND p.waocs <> -999
GROUP BY marketTicker, issueId, issueDate
;
COMMIT;

UPDATE #fnm_MinDate_FICO s SET s.waocs = d.waocs
FROM #fnm_Pools d
WHERE s.issueId = d.issueId
    AND s.asOf = d.asOf
;

DROP TABLE IF EXISTS #fnm_MinDate_OLTV;
SELECT
    marketTicker,
    issueId,
    issueDate,
    min(asOf) as asOf,
    cast(NULL as numeric(8, 4)) as waoltv
INTO #fnm_MinDate_OLTV
FROM #fnm_Pools p
WHERE p.waoltv IS NOT NULL
    AND p.waoltv <> -999
GROUP BY marketTicker, issueId, issueDate
;
COMMIT;

UPDATE #fnm_MinDate_OLTV s SET s.waoltv = d.waoltv
FROM #fnm_Pools d
WHERE s.issueId = d.issueId
    AND s.asOf = d.asOf
;

DROP TABLE IF EXISTS #fnm_Origination;
SELECT
    marketTicker,
    issueId,
    cast(NULL as date) as originationDate,
    min(asOf) as asOf,
   cast(NULL as numeric(8, 4)) as HPI_orig
INTO #fnm_Origination
FROM #fnm_Pools p
GROUP BY marketTicker, issueId
;
COMMIT;

UPDATE #fnm_Origination s SET s.originationDate = p.originationDate
FROM #fnm_Pools p
WHERE p.issueId = s.issueId
    AND p.asOf = s.asOf
;
COMMIT;

UPDATE #fnm_Origination s SET s.HPI_orig = hpi.HPIndex
FROM #HPA_MA hpi
WHERE s.originationDate = hpi.asOf
;
COMMIT;

-- Update FICO, OLTV, HPA, CLTV
  -- Freddie
  
  -- FICO
UPDATE #FHL_Pools perf SET perf.waocs = s.waocs
FROM #FHL_MinDate_FICO s
WHERE perf.issueId = s.issueId 
    AND perf.waocs IS NULL
;

DROP TABLE IF EXISTS #FHL_IssueDate_FICO;
SELECT
    issueDate,
    sum(schambalance * waocs) / sum(schambalance) as WAVG_FICO
INTO #FHL_IssueDate_FICO
FROM #FHL_Pools p
WHERE waocs IS NOT NULL
GROUP BY issueDate
;
COMMIT;

UPDATE #FHL_Pools perf SET perf.waocs = oc.WAVG_FICO
FROM #FHL_IssueDate_FICO oc
WHERE perf.issueDate = oc.issueDate
    AND perf.waocs IS NULL 
;

UPDATE #FHL_Pools perf SET perf.waocs = 710
WHERE perf.waocs IS NULL 
    OR perf.waocs = -999
    OR perf.waocs = 999
;

    -- OLTV
UPDATE #FHL_Pools perf SET perf.waoltv = s.waoltv
FROM #FHL_MinDate_OLTV s
WHERE perf.issueId = s.issueId 
    AND perf.waoltv IS NULL
;

DROP TABLE IF EXISTS #FHL_IssueDate_OLTV;
SELECT
    issueDate,
    sum(schambalance * waoltv) / sum(schambalance) as WAVG_OLTV
INTO #FHL_IssueDate_OLTV
FROM #FHL_Pools p
WHERE waoltv IS NOT NULL
GROUP BY issueDate
;
COMMIT;

UPDATE #FHL_Pools perf SET perf.waoltv = ltv.WAVG_OLTV
FROM #FHL_IssueDate_OLTV ltv
WHERE perf.issueDate = ltv.issueDate
    AND perf.waocs IS NULL 
;

UPDATE #FHL_Pools perf SET perf.waoltv = 75
WHERE waoltv IS NULL 
    OR waoltv = -999
    OR waoltv = 999
;

    -- HPA / CLTV
UPDATE #FHL_Pools perf SET perf.HPA = perf.HPI / s.HPI_orig
FROM #FHL_Origination s
WHERE perf.issueId = s.issueId 
;

UPDATE #FHL_Pools perf SET perf.wacltv = perf.waoltv * perf.factor / perf.HPA
WHERE wacltv IS NULL 
    OR wacltv = -999
    OR wacltv = 999
;

  -- Fannie
  
  -- FICO
UPDATE #fnm_Pools perf SET perf.waocs = s.waocs
FROM #fnm_MinDate_FICO s
WHERE perf.issueId = s.issueId 
    AND perf.waocs IS NULL
;

DROP TABLE IF EXISTS #fnm_IssueDate_FICO;
SELECT
    issueDate,
    sum(schambalance * waocs) / sum(schambalance) as WAVG_FICO
INTO #fnm_IssueDate_FICO
FROM #fnm_Pools p
WHERE waocs IS NOT NULL
GROUP BY issueDate
;
COMMIT;

UPDATE #fnm_Pools perf SET perf.waocs = oc.WAVG_FICO
FROM #fnm_IssueDate_FICO oc
WHERE perf.issueDate = oc.issueDate
    AND perf.waocs IS NULL 
;

UPDATE #fnm_Pools perf SET perf.waocs = 710
WHERE perf.waocs IS NULL 
    OR perf.waocs = -999
    OR perf.waocs = 999
;

    -- OLTV
UPDATE #fnm_Pools perf SET perf.waoltv = s.waoltv
FROM #fnm_MinDate_OLTV s
WHERE perf.issueId = s.issueId 
    AND perf.waoltv IS NULL
;

DROP TABLE IF EXISTS #fnm_IssueDate_OLTV;
SELECT
    issueDate,
    sum(schambalance * waoltv) / sum(schambalance) as WAVG_OLTV
INTO #fnm_IssueDate_OLTV
FROM #fnm_Pools p
WHERE waoltv IS NOT NULL
GROUP BY issueDate
;
COMMIT;

UPDATE #fnm_Pools perf SET perf.waoltv = ltv.WAVG_OLTV
FROM #fnm_IssueDate_OLTV ltv
WHERE perf.issueDate = ltv.issueDate
    AND perf.waocs IS NULL 
;

UPDATE #fnm_Pools perf SET perf.waoltv = 75
WHERE waoltv IS NULL 
    OR waoltv = -999
    OR waoltv = 999
;

    -- HPA / CLTV
UPDATE #fnm_Pools perf SET perf.HPA = perf.HPI / s.HPI_orig
FROM #fnm_Origination s
WHERE perf.issueId = s.issueId 
;

UPDATE #fnm_Pools perf SET perf.wacltv = perf.waoltv * perf.factor / perf.HPA
WHERE wacltv IS NULL 
    OR wacltv = -999
    OR wacltv = 999
;

-------------------------------------------
-- Use LL incentive
-------------------------------------------
--     Freddie
DROP TABLE IF EXISTS #incentive_LL;
SELECT 
    l.issueId,
    h.asOf,
    sum(CASE WHEN h.refi_incentive IS NULL THEN 0.0 ELSE h.refi_incentive END * h.schamBalance) / sum(CASE WHEN h.refi_incentive IS NULL THEN 0.0 ELSE h.schamBalance END) as refi_incentive
INTO #incentive_LL
FROM fhl.PIV_Loan l
JOIN fhl.PIV_LoanHist h
    ON l.loanSeqNum = h.loanSeqNum
JOIN #PoolIDSample pid ON pid.issueId = l.issueId
WHERE 1=1
    AND l.marketTicker in ('FGLMC', 'FGT6', 'FGU6', 'FGU9')
    AND h.schamBalance > 0
    AND h.refi_incentive IS NOT NULL
GROUP BY h.asOf, l.issueId
;
Commit;

UPDATE #FHL_Pools perf SET perf.incentive_LL = il.refi_incentive
FROM #incentive_LL il
WHERE perf.issueId = il.issueId 
AND perf.asof = il.asOf
;
Commit;

UPDATE #FHL_Pools perf SET perf.incentive_ToConv = CASE WHEN perf.incentive_LL IS NOT NULL THEN perf.incentive_LL ELSE perf.incentive_PL END
;
Commit;

--     Fannie
DROP TABLE IF EXISTS #incentive_LL;
SELECT 
    l.issueId,
    h.asOf,
    sum(CASE WHEN h.refi_incentive IS NULL THEN 0.0 ELSE h.refi_incentive END * h.schamBalance) / sum(CASE WHEN h.refi_incentive IS NULL THEN 0.0 ELSE h.schamBalance END) as refi_incentive
INTO #incentive_LL
FROM fnm.PIV_Loan l
JOIN (select issueID, loanSeqNum,asOf,cltv,schamBalance,currentRPB,refi_incentive,refiEligToConvFlag from fnm.PIV_LoanHist where asOf>='20140101'
    UNION ALL
    select issueID, loanSeqNum,asOf,cltv,schamBalance,currentRPB,refi_incentive,refiEligToConvFlag from fnm.PIV_Derived_LoanHist ) h
    ON l.loanSeqNum = h.loanSeqNum
JOIN #PoolIDSample pid ON pid.issueId = l.issueId
WHERE 1=1
    AND l.marketTicker in ('FNCL', 'FNCK', 'FNCQ30', 'FNCR')
    AND h.schamBalance > 0
    AND h.refi_incentive IS NOT NULL
GROUP BY h.asOf, l.issueId
;
Commit;

UPDATE #fnm_Pools perf SET perf.incentive_LL = il.refi_incentive
FROM #incentive_LL il
WHERE perf.issueId = il.issueId 
AND perf.asof = il.asOf
;
Commit;

UPDATE #fnm_Pools perf SET perf.incentive_ToConv = CASE WHEN perf.incentive_LL IS NOT NULL THEN perf.incentive_LL ELSE perf.incentive_PL END
;
Commit;


-------------------------------------------
-- Incentive from conventional to GNMA
-------------------------------------------
    -- Freddie
-- Calculate incentive for loans refi from conventional to FHA (Loan Level)
DROP TABLE IF EXISTS #incentive_convToGNMA_loan;
SELECT  lh.issueId, 
        lh.asof,
        l.loanseqNum,
        currentRPB,
        mip = (mip.AnnualMIPPoints + mip.UpfrontMIPPoints / 12.0) / 100,
        incentive_gnma = (origNoteRate + l.origPMI / 100.0) - (MtgRate_gnma + mip)
INTO #incentive_convToGNMA_loan
FROM fhl.PIV_loanhist lh
JOIN fhl.PIV_loan l ON lh.loanseqNum = l.loanseqNum
JOIN gnm.MIPRulesMatrix mip
    ON l.origTerm           >  mip.origTermLowBound  
	AND l.origTerm          <= mip.origTermHighBound 
	AND lh.CLTV             >  mip.LTVLowBound  
	AND lh.CLTV             <= mip.LTVHighBound 
	AND lh.schamBalance     >  mip.LoanOrigAmountLowBound 
	AND lh.schamBalance     <= mip.LoanOrigAmountHighBound
	AND l.firstpaymtdt      >  mip.LoanOrigDateLowBound
	AND l.firstpaymtdt      <= mip.LoanOrigDateHighBound
	AND lh.asOf             >  mip.CaseAssignDateLowBound
	AND lh.asOf             <= mip.CaseAssignDateHighBound
JOIN #MtgRate r on r.asof_lag1 = lh.asof
JOIN #PoolIDSample pid ON pid.issueId = l.issueId
WHERE 1=1
    AND marketticker in ('FGLMC', 'FGU6','FGU9','FGT6')
order by lh.asof
;
COMMIT;

DROP TABLE IF EXISTS #incentive_convToGNMA_loan_WA;
SELECT  igl.issueId,
        asof,
        incentive_gnma = CASE WHEN sum(igl.currentRPB) = 0 THEN 0.0 ELSE sum(CASE WHEN igl.incentive_gnma IS NULL THEN 0.0 ELSE igl.incentive_gnma * igl.currentRPB END) / sum(igl.currentRPB) END
INTO #incentive_convToGNMA_loan_WA
FROM #incentive_convToGNMA_loan igl
GROUP BY igl.issueId, asof;
COMMIT;

-- Calculate incentive for loans refi from conventional to FHA (Pool Level)
DROP TABLE IF EXISTS #incentive_convToGNMA_pool;
SELECT  p.issueId, 
        p.asof,
        mip = (CASE WHEN mip.AnnualMIPPoints IS NOT NULL THEN mip.AnnualMIPPoints ELSE 50.0 END + CASE WHEN mip.UpfrontMIPPoints IS NOT NULL THEN mip.UpfrontMIPPoints ELSE 0.0 END / 12.0) / 100,
        incentive_gnma = (wac + oPMI / 100.0) - (MtgRate_gnma + mip)
INTO #incentive_convToGNMA_pool
FROM #FHL_Pools p
LEFT JOIN gnm.MIPRulesMatrix mip
    ON p.origTerm           >  mip.origTermLowBound  
	AND p.origTerm          <= mip.origTermHighBound 
	AND p.waCLTV            >  mip.LTVLowBound  
	AND p.waCLTV            <= mip.LTVHighBound 
	AND p.schamBalance      >  mip.LoanOrigAmountLowBound 
	AND p.schamBalance      <= mip.LoanOrigAmountHighBound
	AND p.originationDate  >  mip.LoanOrigDateLowBound
	AND p.originationDate  <= mip.LoanOrigDateHighBound
	AND p.asOf             >  mip.CaseAssignDateLowBound
	AND p.asOf             <= mip.CaseAssignDateHighBound
JOIN #MtgRate r on r.asof_lag1 = p.asof
JOIN #PoolIDSample pid ON pid.issueId = p.issueId
WHERE 1=1
    AND p.marketticker in ('FGLMC', 'FGU6','FGU9','FGT6')
order by p.asof
;
COMMIT;



UPDATE #FHL_Pools perf SET perf.incentive_ToGNMA_PL = igp.incentive_gnma
FROM #incentive_convToGNMA_pool igp
WHERE perf.issueId = igp.issueId 
AND perf.asof = igp.asOf
;
Commit;

UPDATE #FHL_Pools perf SET perf.incentive_ToGNMA_LL = igl.incentive_gnma
FROM #incentive_convToGNMA_loan_WA igl
WHERE perf.issueId = igl.issueId 
AND perf.asof = igl.asOf
;
Commit;

UPDATE #FHL_Pools SET incentive_ToGNMA = CASE WHEN incentive_ToGNMA_LL IS NOT NULL THEN incentive_ToGNMA_LL * 100 ELSE incentive_ToGNMA_PL * 100 END
;
Commit;

UPDATE #FHL_Pools SET incentive = CASE WHEN incentive_ToConv >= incentive_ToGNMA THEN incentive_ToConv ELSE incentive_ToGNMA END
;
Commit;


--     Fannie

-- Calculate incentive for loans refi from conventional to FHA (Loan Level)
DROP TABLE IF EXISTS #incentive_convToGNMA_loan;
SELECT  lh.issueId, 
        lh.asof,
        l.loanseqNum,
        currentRPB,
        mip = (mip.AnnualMIPPoints + mip.UpfrontMIPPoints / 12.0) / 100,
        incentive_gnma = (origNoteRate + l.origPMI / 100.0) - (MtgRate_gnma + mip)
INTO #incentive_convToGNMA_loan
FROM (select issueID, loanSeqNum,asOf,cltv,schamBalance,currentRPB,refi_incentive,refiEligToConvFlag from fnm.PIV_LoanHist where asOf>='20140101'
    UNION ALL
    select issueID, loanSeqNum,asOf,cltv,schamBalance,currentRPB,refi_incentive,refiEligToConvFlag from fnm.PIV_Derived_LoanHist ) lh
JOIN fnm.PIV_loan l ON lh.loanseqNum = l.loanseqNum
JOIN gnm.MIPRulesMatrix mip
    ON l.origTerm           >  mip.origTermLowBound  
	AND l.origTerm          <= mip.origTermHighBound 
	AND lh.CLTV             >  mip.LTVLowBound  
	AND lh.CLTV             <= mip.LTVHighBound 
	AND lh.schamBalance     >  mip.LoanOrigAmountLowBound 
	AND lh.schamBalance     <= mip.LoanOrigAmountHighBound
	AND l.firstpaymtdt      >  mip.LoanOrigDateLowBound
	AND l.firstpaymtdt      <= mip.LoanOrigDateHighBound
	AND lh.asOf             >  mip.CaseAssignDateLowBound
	AND lh.asOf             <= mip.CaseAssignDateHighBound
JOIN #MtgRate r on r.asof_lag1 = lh.asof
JOIN #PoolIDSample pid ON pid.issueId = l.issueId
WHERE 1=1
    AND marketticker in  ('FNCL', 'FNCK', 'FNCQ30', 'FNCR')
order by lh.asof
;
COMMIT;

DROP TABLE IF EXISTS #incentive_convToGNMA_loan_WA;
SELECT  igl.issueId,
        asof,
        incentive_gnma = CASE WHEN sum(igl.currentRPB) = 0 THEN 0.0 ELSE sum(CASE WHEN igl.incentive_gnma IS NULL THEN 0.0 ELSE igl.incentive_gnma * igl.currentRPB END) / sum(igl.currentRPB) END
INTO #incentive_convToGNMA_loan_WA
FROM #incentive_convToGNMA_loan igl
GROUP BY igl.issueId, asof;
COMMIT;

-- Calculate incentive for loans refi from conventional to FHA (Pool Level)
DROP TABLE IF EXISTS #incentive_convToGNMA_pool;
SELECT  p.issueId, 
        p.asof,
        mip = (CASE WHEN mip.AnnualMIPPoints IS NOT NULL THEN mip.AnnualMIPPoints ELSE 50.0 END + CASE WHEN mip.UpfrontMIPPoints IS NOT NULL THEN mip.UpfrontMIPPoints ELSE 0.0 END / 12.0) / 100,
        incentive_gnma = (wac + oPMI / 100.0) - (MtgRate_gnma + mip)
INTO #incentive_convToGNMA_pool
FROM #fnm_Pools p
LEFT JOIN gnm.MIPRulesMatrix mip
    ON p.origTerm           >  mip.origTermLowBound  
	AND p.origTerm          <= mip.origTermHighBound 
	AND p.waCLTV            >  mip.LTVLowBound  
	AND p.waCLTV            <= mip.LTVHighBound 
	AND p.schamBalance      >  mip.LoanOrigAmountLowBound 
	AND p.schamBalance      <= mip.LoanOrigAmountHighBound
	AND p.originationDate  >  mip.LoanOrigDateLowBound
	AND p.originationDate  <= mip.LoanOrigDateHighBound
	AND p.asOf             >  mip.CaseAssignDateLowBound
	AND p.asOf             <= mip.CaseAssignDateHighBound
JOIN #MtgRate r on r.asof_lag1 = p.asof
WHERE 1=1
    AND p.marketticker in  ('FNCL', 'FNCK', 'FNCQ30', 'FNCR')
order by p.asof
;
COMMIT;



UPDATE #fnm_Pools perf SET perf.incentive_ToGNMA_PL = igp.incentive_gnma
FROM #incentive_convToGNMA_pool igp
WHERE perf.issueId = igp.issueId 
AND perf.asof = igp.asOf
;
Commit;

UPDATE #fnm_Pools perf SET perf.incentive_ToGNMA_LL = igl.incentive_gnma
FROM #incentive_convToGNMA_loan_WA igl
WHERE perf.issueId = igl.issueId 
AND perf.asof = igl.asOf
;
Commit;

UPDATE #fnm_Pools SET incentive_ToGNMA = CASE WHEN incentive_ToGNMA_LL IS NOT NULL THEN incentive_ToGNMA_LL * 100 ELSE incentive_ToGNMA_PL * 100 END
;
Commit;

UPDATE #fnm_Pools SET incentive = CASE WHEN incentive_ToConv >= incentive_ToGNMA THEN incentive_ToConv ELSE incentive_ToGNMA END
;
Commit;




------------------------------------------
----- Burnout
------------------------------------------
----- Relative Incentive computation
DROP TABLE IF EXISTS #PoolsTmp;
select 
    p.issueId,
    MtgRate_conv as MtgRate,
    p.asOf,
    p.wac,
    p.wala,
    p.cLLPA as currLLPA,
    p.cPMI as currPMI,
    p.oPMI as origPMI
into #PoolsTmp
from #FHL_Pools p         
join #Mtgrate f                 on f.asOf_lag1 = p.asOf
;
commit;
 
create LF index asOf_1 on  #PoolsTmp(asOf);
create HG index issueId_1 on  #PoolsTmp(issueId);
COMMIT;
 
DROP TABLE IF EXISTS #RelativeIncentive_Pool;
select  
    t.issueId,
    t.asOf as asOf,
    log(CASE WHEN (t.wac + t.origPMI/100) / (t.MtgRate + t.currLLPA/400 + t.currPMI/100) <= 1 THEN 1 ELSE (t.wac + t.origPMI/100) / (t.MtgRate + t.currLLPA/400 + t.currPMI/100)  END) * 100 as relat_incentive_pool
into #RelativeIncentive_Pool
from #PoolsTmp t
;
commit;


drop table if exists #RelativeIncentive_Loan;
select  
    t.loanSeqNum,
    t.asOf as asOf,
    l.issueId,
    t.schamBalance,
    log(CASE WHEN (l.origNoteRate + l.origPMI/100) / (f.MtgRate_conv + t.currLLPA/400 + t.currPMI/100) <= 1 THEN 1 ELSE (l.origNoteRate + l.origPMI/100) / (f.MtgRate_conv + t.currLLPA/400 + t.currPMI/100) END) * 100 as relat_incentive_loan
into #RelativeIncentive_Loan
from fhl.PIV_LoanHist t
join fhl.PIV_Loan l           on t.loanSeqNum = l.loanSeqNum  --and l.loanSeqNum in (select loanSeqNum from LoanFileData)
join #Mtgrate f                 on f.asOf_lag1 = t.asOf 
JOIN #PoolIDSample pid          ON pid.issueId = l.issueId
where t.currLLPA is not null 
and t.currPMI is not null
--and l.issueId = 1101080
;
commit;

drop table if exists #RelativeIncentive_Loan_WA;
select 
    issueId,
    asOf,
    sum(CASE WHEN l.relat_incentive_loan IS NULL THEN 0.0 ELSE l.relat_incentive_loan END * l.schamBalance) / sum(CASE WHEN l.relat_incentive_loan IS NULL THEN 0.0 ELSE l.schamBalance END) as relat_incentive_loan
into #RelativeIncentive_Loan_WA
from #RelativeIncentive_Loan l 
WHERE 1=1
    AND l.schamBalance > 0
GROUP BY l.asOf, l.issueId--, p.relat_incentive_pool
;
commit;


drop table if exists #RelativeIncentive;
select 
    p.issueId,
    p.asOf,
    p.relat_incentive_pool,
    cast(NULL as numeric(8, 4)) as relat_incentive_loan,
    cast(NULL as numeric(8, 4)) as relat_incentive
into #RelativeIncentive
from #RelativeIncentive_Pool p
;
commit;


update #RelativeIncentive p set p.relat_incentive_loan = l.relat_incentive_loan
from #RelativeIncentive_Loan_WA l 
where p.issueId = l.issueId 
and p.asof = l.asof
;
commit;


update #RelativeIncentive p1 
set p1.relat_incentive = (CASE WHEN p2.relat_incentive_loan IS NOT NULL THEN p2.relat_incentive_loan ELSE p2.relat_incentive_pool END)
from #RelativeIncentive p2 
where p1.issueId = p2.issueId 
and p1.asof = p2.asof
;
commit;


----- Burnout computation ----
DROP TABLE IF EXISTS #BurnoutTmp;
select  
    t0.issueId,
    t0.asOf as asOf,
    sum(CASE WHEN t1.relat_incentive_pool IS NULL THEN 0 ELSE t1.relat_incentive_pool END) as burnout_OLD,
    sum(t1.relat_incentive) as burnout
into #BurnoutTmp
from #RelativeIncentive t0
join #RelativeIncentive t1           on t0.issueId = t1.issueId    and t0.asOf >= t1.asOf
where t1.relat_incentive IS NOT NULL
group BY t0.issueId, t0.asOf;
commit;


--------- Earliest Pool instance -----
DROP TABLE IF EXISTS #poolsAtOrigination;
 select
    rp.issueId,
    rp.asOf,
    cast(dateadd(month, -(t.wala), rp.asOf ) as date) as originationDate,
    t.wala,
    t.wac,
    cast(NULL as numeric(8, 4)) as burnout_OLD,
    cast(NULL as numeric(8, 4)) as burnout
into #poolsAtOrigination
from  #BurnoutTmp rp
join (
        select
            issueId,
            min(asOf) as first_asOf
        from  #BurnoutTmp 
        group by  issueId
    ) orp    ON rp.issueId = orp.issueId    AND rp.asOf  = orp.first_asOf 
join #PoolsTmp t on t.issueId = orp.issueId and t.asOf  = orp.first_asOf; 
commit;


----  create missing periods from pool origination date to first instance
DROP TABLE IF EXISTS #unique_dates;
select convert(date,dateadd(month, -num, mn.asOf)) as asOf
INTO #unique_dates
FROM report.nums,
(select convert(date,dateadd(day, -datepart(day,getdate())+1 ,getdate())) asOf)mn;
commit;

DROP TABLE IF EXISTS #PoolHist;
 select 
    r.issueId, 
    t.asOf, 
    r.wac,
    f.MtgRate_conv as MtgRate
into #PoolHist
from  #poolsAtOrigination r
join  #unique_dates t     ON t.asOf > r.originationDate     AND t.asOf <= r.asOf 
left outer join #MtgRate f on    f.asOf_lag1 = t.asOf;
commit;
 
UPDATE #PoolHist inc SET inc.MtgRate = r.MtgRate_conv
FROM #MtgRate r
WHERE r.asOf_lag1 = (SELECT min(asOf_lag1) FROM #MtgRate)
    AND inc.MtgRate IS NULL;
commit;

DROP TABLE IF EXISTS #Hist_Burnout;
select 
t0.issueId,
t0.asOf ,
sum(log(CASE WHEN t1.wac / t1.MtgRate <= 1 THEN 1 ELSE t1.wac / t1.MtgRate END)) *100 as burnout
into #Hist_Burnout
from  #PoolHist t0
join #PoolHist t1        ON t0.issueId = t1.issueId        AND t0.asOf >= t1.asOf
group by  t0.issueId, t0.asOf;
commit;



---- update burnout for first instance
update #poolsAtOrigination l set burnout = h.burnout
from #Hist_Burnout h
where h.issueId = l.issueId
and h.asOf = l.asOf;
commit;
  

---- update burnout for first instance as well as well as asOfs after first
DROP TABLE IF EXISTS #BurnoutResult;
select  
    h.issueId,
    h.asOf as asOf,
    burnout = h.burnout + brn.burnout, 
    burnout_OLD = h.burnout_OLD + brn.burnout
into #BurnoutResult
from #BurnoutTmp h
Join #poolsAtOrigination  brn on  h.issueId = brn.issueId;
commit;


UPDATE #FHL_Pools perf SET perf.burnout = b.burnout
FROM #BurnoutResult b
WHERE perf.issueId = b.issueId 
AND perf.asof = b.asOf
;
Commit;


--      Fannie
----- Relative Incentive computation
DROP TABLE IF EXISTS #PoolsTmp;
select 
    p.issueId,
    MtgRate_conv as MtgRate,
    p.asOf,
    p.wac,
    p.wala,
    p.cLLPA as currLLPA,
    p.cPMI as currPMI,
    p.oPMI as origPMI
into #PoolsTmp
from #fnm_Pools p         
join #Mtgrate f                 on f.asOf_lag1 = p.asOf
;
commit;
 
create LF index asOf_1 on  #PoolsTmp(asOf);
create HG index issueId_1 on  #PoolsTmp(issueId);
COMMIT;
 
DROP TABLE IF EXISTS #RelativeIncentive_Pool;
select  
    t.issueId,
    t.asOf as asOf,
    log(CASE WHEN (t.wac + t.origPMI/100) / (t.MtgRate + t.currLLPA/400 + t.currPMI/100) <= 1 THEN 1 ELSE (t.wac + t.origPMI/100) / (t.MtgRate + t.currLLPA/400 + t.currPMI/100)  END) * 100 as relat_incentive_pool
into #RelativeIncentive_Pool
from #PoolsTmp t
;
commit;


drop table if exists #RelativeIncentive_Loan;
select  
    t.loanSeqNum,
    t.asOf as asOf,
    l.issueId,
    t.schamBalance,
    log(CASE WHEN (l.origNoteRate + l.origPMI/100) / (f.MtgRate_conv + t.currLLPA/400 + t.currPMI/100) <= 1 THEN 1 ELSE (l.origNoteRate + l.origPMI/100) / (f.MtgRate_conv + t.currLLPA/400 + t.currPMI/100) END) * 100 as relat_incentive_loan
into #RelativeIncentive_Loan
from (select issueID, loanSeqNum,asOf,cltv,schamBalance,currentRPB,refi_incentive,refiEligToConvFlag,currLLPA,currPMI from fnm.PIV_LoanHist where asOf>='20140101'
    UNION ALL
    select issueID, loanSeqNum,asOf,cltv,schamBalance,currentRPB,refi_incentive,refiEligToConvFlag,currLLPA,currPMI from fnm.PIV_Derived_LoanHist ) t
join fnm.PIV_Loan l           on t.loanSeqNum = l.loanSeqNum  --and l.loanSeqNum in (select loanSeqNum from LoanFileData)
join #Mtgrate f                 on f.asOf_lag1 = t.asOf 
JOIN #PoolIDSample pid          ON pid.issueId = l.issueId
where t.currLLPA is not null 
and t.currPMI is not null
--and l.issueId = 1101080
;
commit;

drop table if exists #RelativeIncentive_Loan_WA;
select 
    issueId,
    asOf,
    sum(CASE WHEN l.relat_incentive_loan IS NULL THEN 0.0 ELSE l.relat_incentive_loan END * l.schamBalance) / sum(CASE WHEN l.relat_incentive_loan IS NULL THEN 0.0 ELSE l.schamBalance END) as relat_incentive_loan
into #RelativeIncentive_Loan_WA
from #RelativeIncentive_Loan l 
WHERE 1=1
    AND l.schamBalance > 0
GROUP BY l.asOf, l.issueId--, p.relat_incentive_pool
;
commit;


drop table if exists #RelativeIncentive;
select 
    p.issueId,
    p.asOf,
    p.relat_incentive_pool,
    cast(NULL as numeric(8, 4)) as relat_incentive_loan,
    cast(NULL as numeric(8, 4)) as relat_incentive
into #RelativeIncentive
from #RelativeIncentive_Pool p
;
commit;


update #RelativeIncentive p set p.relat_incentive_loan = l.relat_incentive_loan
from #RelativeIncentive_Loan_WA l 
where p.issueId = l.issueId 
and p.asof = l.asof
;
commit;


update #RelativeIncentive p1 
set p1.relat_incentive = (CASE WHEN p2.relat_incentive_loan IS NOT NULL THEN p2.relat_incentive_loan ELSE p2.relat_incentive_pool END)
from #RelativeIncentive p2 
where p1.issueId = p2.issueId 
and p1.asof = p2.asof
;
commit;


----- Burnout computation ----
DROP TABLE IF EXISTS #BurnoutTmp;
select  
    t0.issueId,
    t0.asOf as asOf,
    sum(CASE WHEN t1.relat_incentive_pool IS NULL THEN 0 ELSE t1.relat_incentive_pool END) as burnout_OLD,
    sum(t1.relat_incentive) as burnout
into #BurnoutTmp
from #RelativeIncentive t0
join #RelativeIncentive t1           on t0.issueId = t1.issueId    and t0.asOf >= t1.asOf
where t1.relat_incentive IS NOT NULL
group BY t0.issueId, t0.asOf;
commit;


--------- Earliest Pool instance -----
DROP TABLE IF EXISTS #poolsAtOrigination;
 select
    rp.issueId,
    rp.asOf,
    cast(dateadd(month, -(t.wala), rp.asOf ) as date) as originationDate,
    t.wala,
    t.wac,
    cast(NULL as numeric(12, 4)) as burnout_OLD,
    cast(NULL as numeric(12, 4)) as burnout
into #poolsAtOrigination
from  #BurnoutTmp rp
join (
        select
            issueId,
            min(asOf) as first_asOf
        from  #BurnoutTmp 
        group by  issueId
    ) orp    ON rp.issueId = orp.issueId    AND rp.asOf  = orp.first_asOf 
join #PoolsTmp t on t.issueId = orp.issueId and t.asOf  = orp.first_asOf; 
commit;


----  create missing periods from pool origination date to first instance
DROP TABLE IF EXISTS #unique_dates;
select convert(date,dateadd(month, -num, mn.asOf)) as asOf
INTO #unique_dates
FROM report.nums,
(select convert(date,dateadd(day, -datepart(day,getdate())+1 ,getdate())) asOf)mn;
commit;

DROP TABLE IF EXISTS #PoolHist;
 select 
    r.issueId, 
    t.asOf, 
    r.wac,
    f.MtgRate_conv as MtgRate
into #PoolHist
from  #poolsAtOrigination r
join  #unique_dates t     ON t.asOf > r.originationDate     AND t.asOf <= r.asOf 
left outer join #MtgRate f on    f.asOf_lag1 = t.asOf;
commit;
 
UPDATE #PoolHist inc SET inc.MtgRate = r.MtgRate_conv
FROM #MtgRate r
WHERE r.asOf_lag1 = (SELECT min(asOf_lag1) FROM #MtgRate)
    AND inc.MtgRate IS NULL;
commit;

DROP TABLE IF EXISTS #Hist_Burnout;
select 
t0.issueId,
t0.asOf ,
sum(log(CASE WHEN t1.wac / t1.MtgRate <= 1 THEN 1 ELSE t1.wac / t1.MtgRate END)) *100 as burnout
into #Hist_Burnout
from  #PoolHist t0
join #PoolHist t1        ON t0.issueId = t1.issueId        AND t0.asOf >= t1.asOf
group by  t0.issueId, t0.asOf;
commit;


---- update burnout for first instance
update #poolsAtOrigination l set burnout = h.burnout
from #Hist_Burnout h
where h.issueId = l.issueId
and h.asOf = l.asOf;
commit;
  

---- update burnout for first instance as well as well as asOfs after first
DROP TABLE IF EXISTS #BurnoutResult;
select  
    h.issueId,
    h.asOf as asOf,
    burnout = h.burnout + brn.burnout, 
    burnout_OLD = h.burnout_OLD + brn.burnout
into #BurnoutResult
from #BurnoutTmp h
Join #poolsAtOrigination  brn on  h.issueId = brn.issueId;
commit;


UPDATE #fnm_Pools perf SET perf.burnout = b.burnout
FROM #BurnoutResult b
WHERE perf.issueId = b.issueId 
AND perf.asof = b.asOf
;
Commit;


------------------------------------------------
-- Refi Eligibility Flag
------------------------------------------------
--      Freddie
-- Aggregate loan level refi_eligible_pct to pools
DROP TABLE IF EXISTS #refiElig;
select  sf.issueId, 
        sf.asof, 
        refi_eligible_pct = sum(CASE WHEN lh.refiEligToConvFlag = 'Y' THEN lh.schamBalance ELSE 0 END) / sum(lh.schamBalance)
into #refiElig
from #FHL_Pools sf
left join fhl.PIV_loanhist lh on lh.issueId = sf.issueId and sf.asof = lh.asof
where 1=1
and sf.schamBalance > 0
group by sf.issueId, sf.asof
order by sf.issueId, sf.asof
;
commit;


-- Update refi_eligible_pct for preHARP pools
update #refiElig r set r.refi_eligible_pct = CASE WHEN f.CalcOrigMonth < 200906 THEN 1.0 ELSE r.refi_eligible_pct END
from fhl.secfactor f
where f.issueId = r.issueId 
and f.asof = r.asof
;

UPDATE #FHL_Pools perf SET perf.refiEligPct = r.refi_eligible_pct
FROM #refiElig r
WHERE perf.issueId = r.issueId 
AND perf.asof = r.asOf
;
Commit;

--      Fannie
-- Aggregate loan level refi_eligible_pct to pools
DROP TABLE IF EXISTS #refiElig;
select  sf.issueId, 
        sf.asof, 
        refi_eligible_pct = sum(CASE WHEN lh.refiEligToConvFlag = 'Y' THEN lh.schamBalance ELSE 0 END) / sum(lh.schamBalance)
into #refiElig
from #fnm_Pools sf
left join (select issueID, loanSeqNum,asOf,cltv,schamBalance,currentRPB,refi_incentive,refiEligToConvFlag from fnm.PIV_LoanHist where asOf>='20140101'
    UNION ALL
    select issueID, loanSeqNum,asOf,cltv,schamBalance,currentRPB,refi_incentive,refiEligToConvFlag from fnm.PIV_Derived_LoanHist ) lh on lh.issueId = sf.issueId and sf.asof = lh.asof
where 1=1
and sf.schamBalance > 0
group by sf.issueId, sf.asof
order by sf.issueId, sf.asof
;
commit;


-- Update refi_eligible_pct for preHARP pools
update #refiElig r set r.refi_eligible_pct = CASE WHEN f.CalcOrigMonth < 200906 THEN 1.0 ELSE r.refi_eligible_pct END
from fnm.secfactor f
where f.issueId = r.issueId 
and f.asof = r.asof
;

UPDATE #fnm_Pools perf SET perf.refiEligPct = r.refi_eligible_pct
FROM #refiElig r
WHERE perf.issueId = r.issueId 
AND perf.asof = r.asOf
;
Commit;


------------------------------------------------
-- percentHARP
------------------------------------------------
--      Freddie
DROP TABLE IF EXISTS #pctHARP;
SELECT
    lh.issueID,
    lh.asOf,
    Pct_HARP = CASE WHEN sum(lh.currentRPB) = 0 THEN 0 ELSE sum(CASE WHEN l.percentHARP IS NULL THEN 0.0 ELSE l.percentHARP END * lh.currentRPB) / sum(lh.currentRPB) END
INTO #pctHARP
FROM fhl.PIV_Loan l
JOIN fhl.PIV_LoanHist lh ON l.loanseqNum = lh.loanSeqNum
JOIN #PoolIDSample pid ON pid.issueId = l.issueId
--AND perf.asof < '2016-03-01'
GROUP BY lh.issueID, asof
;
Commit;

UPDATE #FHL_Pools perf SET perf.Pct_HARP = l.Pct_HARP
FROM #pctHARP l
WHERE perf.issueId = l.issueId
AND perf.asof = l.asof;
COMMIT;

--      Fannie
DROP TABLE IF EXISTS #pctHARP;
SELECT
    lh.issueID,
    lh.asOf,
    Pct_HARP = CASE WHEN sum(lh.currentRPB) = 0 THEN 0 ELSE sum(CASE WHEN l.percentHARP IS NULL THEN 0.0 ELSE l.percentHARP END * lh.currentRPB) / sum(lh.currentRPB) END
INTO #pctHARP
FROM fnm.PIV_Loan l
JOIN (select issueID, loanSeqNum,asOf,cltv,schamBalance,currentRPB,refi_incentive,refiEligToConvFlag from fnm.PIV_LoanHist where asOf>='20140101'
    UNION ALL
    select issueID, loanSeqNum,asOf,cltv,schamBalance,currentRPB,refi_incentive,refiEligToConvFlag from fnm.PIV_Derived_LoanHist ) lh ON l.loanseqNum = lh.loanSeqNum
JOIN #PoolIDSample pid ON pid.issueId = l.issueId
    --AND perf.asof < '2016-03-01'
GROUP BY lh.issueID, asof
;
Commit;

UPDATE #fnm_Pools perf SET perf.Pct_HARP = l.Pct_HARP
FROM #pctHARP l
WHERE perf.issueId = l.issueId
AND perf.asof = l.asof;
COMMIT;


------------------------------------------------
-- Percent TPO (Origination Channel)
------------------------------------------------

--      Freddie
DROP TABLE IF EXISTS #pct_tpo_fhl;
select d.asof, d.issueId, sum(d.percentRpb) as percentRpb
INTO #pct_tpo_fhl
FROM fhl.PIV_LoanDist d
JOIN #FHL_Pools perf    ON perf.issueId = d.issueId 
                        AND perf.asof = d.asOf
WHERE 1=1
AND distributionName='TPO'
AND distributionType in ('CORRES','BROKER') and subtype='ALL'
group by d.asof, d.issueId 
;
Commit;

UPDATE #FHL_Pools perf SET perf.Pct_TPO = d.percentRpb
FROM #pct_tpo_fhl d
WHERE perf.issueId = d.issueId 
AND perf.asof = d.asOf
;
Commit;


--      Fannie
DROP TABLE IF EXISTS #pct_tpo_fnm;
select d.asof, d.issueId, sum(d.percentRpb) as percentRpb
INTO #pct_tpo_fnm
FROM fnm.PIV_LoanDist d
JOIN #FNM_Pools perf    ON perf.issueId = d.issueId 
                        AND perf.asof = d.asOf
WHERE 1=1
AND distributionName='TPO'
AND distributionType in ('CORRES','BROKER') and subtype='ALL'
group by d.asof, d.issueId 
;
Commit;

UPDATE #FNM_Pools perf SET perf.Pct_TPO = d.percentRpb
FROM #pct_tpo_fnm d
WHERE perf.issueId = d.issueId 
AND perf.asof = d.asOf
;
Commit;

----------------------------------------------------------
-- Pool Distributions
----------------------------------------------------------
  -- Freddie
DROP TABLE IF EXISTS #FHL_Occ_Dist;
SELECT
    issueId,
    asOf,
    sum(Pct_OWNER) as Pct_OWNER,
    sum(Pct_2ND) as Pct_2ND,
    sum(Pct_INV) as Pct_INV,
    Pct_OWNER + Pct_2ND + Pct_INV as Pct_Total
INTO #FHL_Occ_Dist
FROM
(
SELECT
    p.issueId,
    p.asOf,
    CASE WHEN distributionType IN ('OWNER') THEN percentRpb ELSE 0.0 END as Pct_OWNER,
    CASE WHEN distributionType IN ('2ND','N/A') THEN percentRpb ELSE 0.0 END as Pct_2ND,
    CASE WHEN distributionType IN ('INV') THEN percentRpb ELSE 0.0 END as Pct_INV
FROM #FHL_Pools p
JOIN fhl.SecMaxAsOf s 
    ON p.issueID = s.issueID
    AND p.asOF = s.factorASOf
LEFT JOIN fhl.OccupancyDist occ
    ON p.issueId = occ.issueId
    AND s.occupancyAsOf = occ.asOf
) t
GROUP BY issueId, asOf
;
COMMIT;

CREATE INDEX issueId_idx ON #FHL_Occ_Dist(issueId);
CREATE INDEX asOf_idx ON #FHL_Occ_Dist(asOf);
COMMIT;


-- Update Rows that don't sum to 1
UPDATE #FHL_Occ_Dist SET Pct_OWNER = 100.0, Pct_2ND = 0.0, Pct_INV = 0.0, Pct_Total = 100.0
WHERE abs(Pct_Total - 100.0) > 1
;

-- Update the Pools Tables with the Occ Type Info
UPDATE #FHL_Pools perf SET perf.Pct_OWNER = occ.Pct_OWNER, perf.Pct_2ND = occ.Pct_2ND, perf.Pct_INV = occ.Pct_INV
FROM #FHL_Occ_Dist occ
WHERE perf.issueId = occ.issueId 
    AND perf.asOf = occ.asOf
;

  -- Fannie
DROP TABLE IF EXISTS #fnm_Occ_Dist;
SELECT
    issueId,
    asOf,
    sum(Pct_OWNER) as Pct_OWNER,
    sum(Pct_2ND) as Pct_2ND,
    sum(Pct_INV) as Pct_INV,
    Pct_OWNER + Pct_2ND + Pct_INV as Pct_Total
INTO #fnm_Occ_Dist
FROM
(
SELECT
    p.issueId,
    p.asOf,
    CASE WHEN distributionType IN ('OWNER') THEN percentRpb ELSE 0.0 END as Pct_OWNER,
    CASE WHEN distributionType IN ('2ND','N/A') THEN percentRpb ELSE 0.0 END as Pct_2ND,
    CASE WHEN distributionType IN ('INV') THEN percentRpb ELSE 0.0 END as Pct_INV
FROM #fnm_Pools p
JOIN fnm.SecMaxAsOf s 
    ON p.issueID = s.issueID
    AND p.asOF = s.factorASOf
LEFT JOIN fnm.OccupancyDist occ
    ON p.issueId = occ.issueId
    AND s.occupancyAsOf = occ.asOf
) t
GROUP BY issueId, asOf
;
COMMIT;

CREATE INDEX issueId_idx ON #fnm_Occ_Dist(issueId);
CREATE INDEX asOf_idx ON #fnm_Occ_Dist(asOf);
COMMIT;


-- Update Rows that don't sum to 1
UPDATE #fnm_Occ_Dist SET Pct_OWNER = 100.0, Pct_2ND = 0.0, Pct_INV = 0.0, Pct_Total = 100.0
WHERE abs(Pct_Total - 100.0) > 1
;

-- Update the Pools Tables with the Occ Type Info
UPDATE #fnm_Pools perf SET perf.Pct_OWNER = occ.Pct_OWNER, perf.Pct_2ND = occ.Pct_2ND, perf.Pct_INV = occ.Pct_INV
FROM #fnm_Occ_Dist occ
WHERE perf.issueId = occ.issueId 
    AND perf.asOf = occ.asOf
;


----------------------------------------
-- Purpose Distribution
----------------------------------------
  -- Freddie
DROP TABLE IF EXISTS #FHL_Purpose_Dist;
SELECT
    issueId,
    asOf,
    sum(Pct_PURCH) as Pct_PURCH,
    sum(Pct_REFI) as Pct_REFI,
	100 - Pct_PURCH - Pct_REFI as Pct_OTHERS,
    Pct_PURCH + Pct_REFI + Pct_OTHERS as Pct_Total
INTO #FHL_Purpose_Dist
FROM
(
SELECT
    p.issueId,
    p.asOf,
    CASE WHEN (distributionType IN ('PURCH') AND purp.subType IN ('ALL','1')) THEN percentRpb ELSE 0.0 END as Pct_PURCH,
    CASE WHEN (distributionType IN ('RE-FI') AND purp.subType NOT IN ('ALL')) THEN percentRpb ELSE 0.0 END as Pct_REFI
FROM #FHL_Pools p
JOIN fhl.SecMaxAsOf s 
    ON p.issueID = s.issueID
    AND p.asOF = s.factorASOf
LEFT JOIN fhl.LoanPurposeDist purp
    ON p.issueId = purp.issueId
    AND s.LoanPurposeAsOf = purp.asOf
    AND purp.rpb <> 0
) t
GROUP BY issueId, asOf
;
COMMIT;

CREATE INDEX issueId_idx ON #FHL_Purpose_Dist(issueId);
CREATE INDEX asOf_idx ON #FHL_Purpose_Dist(asOf);
COMMIT;


-- Update the Pools Tables with the purp Type Info
UPDATE #FHL_Pools perf SET perf.Pct_PURCH = purp.Pct_PURCH, perf.Pct_REFI = purp.Pct_REFI, perf.Pct_OTHERS = purp.Pct_OTHERS
FROM #FHL_Purpose_Dist purp
WHERE perf.issueId = purp.issueId 
    AND perf.asOf = purp.asOf
;


  -- Fannie
DROP TABLE IF EXISTS #fnm_Purpose_Dist;
SELECT
    issueId,
    asOf,
    sum(Pct_PURCH) as Pct_PURCH,
    sum(Pct_REFI) as Pct_REFI,
	100 - Pct_PURCH - Pct_REFI as Pct_OTHERS,
    Pct_PURCH + Pct_REFI + Pct_OTHERS as Pct_Total
INTO #fnm_Purpose_Dist
FROM
(
SELECT
    p.issueId,
    p.asOf,
    CASE WHEN (distributionType IN ('PURCH') AND purp.subType IN ('ALL','1')) THEN percentRpb ELSE 0.0 END as Pct_PURCH,
    CASE WHEN (distributionType IN ('RE-FI') AND purp.subType NOT IN ('ALL')) THEN percentRpb ELSE 0.0 END as Pct_REFI
FROM #fnm_Pools p
JOIN fnm.SecMaxAsOf s 
    ON p.issueID = s.issueID
    AND p.asOF = s.factorASOf
LEFT JOIN fnm.LoanPurposeDist purp
    ON p.issueId = purp.issueId
    AND s.LoanPurposeAsOf = purp.asOf
    AND purp.rpb <> 0
) t
GROUP BY issueId, asOf
;
COMMIT;

CREATE INDEX issueId_idx ON #fnm_Purpose_Dist(issueId);
CREATE INDEX asOf_idx ON #fnm_Purpose_Dist(asOf);
COMMIT;


-- Update the Pools Tables with the purp Type Info
UPDATE #fnm_Pools perf SET perf.Pct_PURCH = purp.Pct_PURCH, perf.Pct_REFI = purp.Pct_REFI, perf.Pct_OTHERS = purp.Pct_OTHERS
FROM #fnm_Purpose_Dist purp
WHERE perf.issueId = purp.issueId 
    AND perf.asOf = purp.asOf
;

----------------------------------------------------
 -- Delinquency 
---------------------------------------------------
--      Freddie
-- Pool level distribution
DROP TABLE IF EXISTS #FHL_DELQ_Dist;
SELECT
    issueId,
    asOf,
    sum(CASE WHEN Pct_D30 IS NULL THEN NULL ELSE Pct_D30 END) as Pct_DQ30,
    sum(CASE WHEN Pct_D60 IS NULL THEN NULL ELSE Pct_D60 END) as Pct_DQ60,
    sum(CASE WHEN Pct_D90 IS NULL THEN NULL ELSE Pct_D90 END) as Pct_DQ90
INTO #FHL_DELQ_Dist
FROM
(
SELECT
    p.issueId,
    p.asOf,
    CASE WHEN distributionType IN ('DEL30') THEN percentRpb ELSE NULL END as Pct_D30,
    CASE WHEN distributionType IN ('DEL60') THEN percentRpb ELSE NULL END as Pct_D60,
    CASE WHEN distributionType IN ('DEL90') THEN percentRpb ELSE NULL END as Pct_D90
FROM #FHL_Pools p
JOIN fhl.SecMaxAsOf s 
    ON p.issueID = s.issueID
    AND p.asOF = s.factorASOf
LEFT JOIN fhl.DelinqDist dist
    ON p.issueId = dist.issueId
    AND s.delqASOf = dist.AsOf
    AND subType = 'ALL'
) t
GROUP BY issueId, asOf
;
COMMIT;


CREATE INDEX issueId_idx ON #FHL_DELQ_Dist(issueId);
CREATE INDEX asOf_idx ON #FHL_DELQ_Dist(asOf);
COMMIT;

-- Update the Pools Tables with the Delinquency Info
UPDATE #FHL_Pools perf SET perf.Pct_DELQ = dist.Pct_DQ30 + dist.Pct_DQ60 + dist.Pct_DQ90, 
    perf.Pct_D30 = dist.Pct_DQ30, 
    perf.Pct_D60 = dist.Pct_DQ60, 
    perf.Pct_D90 = dist.Pct_DQ90
FROM #FHL_DELQ_Dist dist
WHERE perf.issueId = dist.issueId 
    AND perf.asOf = dist.asOf
;
UPDATE #FHL_Pools perf SET perf.Pct_CURRENT = 100.0 - perf.Pct_DELQ;

-- Loan level delinq information for pre-2011
--DROP TABLE IF EXISTS #dq_pct_LL
--select 
--    d.beginDate as asOfDate,
--    cltvBucket = (case
--                  when origLTV / HPA < 10 THEN 10
--                  when origLTV / HPA < 20 THEN 20
--                  when origLTV / HPA < 30 THEN 30
--                  when origLTV / HPA < 40 THEN 40
--                  when origLTV / HPA < 50 THEN 50
--                  when origLTV / HPA < 60 THEN 60
--                  when origLTV / HPA < 70 THEN 70
--                  when origLTV / HPA < 80 THEN 80
--                  when origLTV / HPA < 90 THEN 90
--                  when origLTV / HPA < 100 THEN 100
--                  when origLTV / HPA < 110 THEN 110
--                  when origLTV / HPA < 120 THEN 120
--                  when origLTV / HPA < 130 THEN 130
--                  when origLTV / HPA < 140 THEN 140
--                  else 150 end), 
--	walaBucket = (case 
--                   when beginLoanAge < 1 then 0
--                   when beginLoanAge < 10 then 10
--    	     	   when beginLoanAge < 20 then 20
--    	           when beginLoanAge < 30 then 30
--    	           when beginLoanAge < 40 then 40
--    	           when beginLoanAge < 50 then 50
--    	           when beginLoanAge < 60 then 60
--    	           when beginLoanAge < 70 then 70
--    	           when beginLoanAge < 80 then 80
--    	           when beginLoanAge < 90 then 90
--    	           when beginLoanAge < 100 then 100
--    	           when beginLoanAge < 110 then 110
--    	           when beginLoanAge < 120 then 120
--    	           when beginLoanAge < 130 then 130
--    	           when beginLoanAge < 140 then 140
--    	           when beginLoanAge < 150 then 150
--    	           when beginLoanAge < 160 then 160
--    	           when beginLoanAge < 170 then 170
--    	           when beginLoanAge < 180 then 180
--    	           when beginLoanAge < 190 then 190
--    	           else 200 end),
--	ficoBucket = (case 
--	           when origFICO < 500 then 500
--	           when origFICO < 540 then 540
--	           when origFICO < 580 then 580
--	           when origFICO < 600 then 600
--	           when origFICO < 620 then 620
--	           when origFICO < 640 then 640
--	           when origFICO < 660 then 660
--	           when origFICO < 680 then 680
--	           when origFICO < 700 then 700
--	           when origFICO < 720 then 720
--	           when origFICO < 740 then 740
--	           when origFICO < 760 then 760
--	           when origFICO < 780 then 780
--	           when origFICO < 800 then 800
--	           else 820 end),
--    convert(decimal(10,6), sum(CASE WHEN endStatus IN ('1','2','3') THEN beginBalance ELSE 0.0 END) / sum(beginBalance)) * 100 as pct_dq
--INTO #dq_pct_LL
--FROM fhl.PIV_CreditOrigination s
--JOIN fhl.PIV_CreditPerformanceHist d ON s.loanID = d.loanID
--GROUP BY beginDate, cltvBucket, walaBucket, ficoBucket
--ORDER BY beginDate, cltvBucket, walaBucket, ficoBucket
--
--Commit

--SELECT * INTO report.FHL_dq_pct_LL_SymphonyTracking FROM #dq_pct_LL
--COMMIT


UPDATE #FHL_Pools perf SET perf.Pct_DELQ = CASE WHEN perf.pct_CURRENT IS NULL AND dl.pct_DQ IS NULL THEN 0.0 ELSE (CASE WHEN perf.pct_CURRENT IS NOT NULL THEN perf.pct_DELQ ELSE dl.pct_DQ END) END,
                           perf.Pct_CURRENT = CASE WHEN perf.pct_CURRENT IS NULL AND dl.pct_DQ IS NULL THEN 100.0 ELSE (CASE WHEN perf.pct_CURRENT IS NOT NULL THEN perf.pct_CURRENT ELSE (100-dl.pct_DQ) END) END
From #FHL_Pools perf 
--left join #dq_pct_LL dl 	on dl.asOfDate = perf.asOf
left join report.FHL_dq_pct_LL_SymphonyTracking dl 	on dl.asOfDate = perf.asOf
where 1=1
	AND wacltv <= dl.cltvBucket
    AND wacltv > dl.cltvBucket - 10
	AND wala <= dl.walaBucket
	AND wala > dl.walaBucket - 10
	AND waocs <= dl.ficoBucket
    AND waocs > dl.ficoBucket - 20
;


UPDATE #FHL_Pools perf SET perf.Pct_DELQ = 0,
                           perf.Pct_CURRENT = 100
    where perf.Pct_DELQ IS NULL;

-- Delinquent Cohort from FHL
DROP TABLE IF EXISTS #dq_pct_FHL;
select 
    asOf,
    cltvBucket = (case
                  when wacltv < 10 THEN 10
                  when wacltv < 20 THEN 20
                  when wacltv < 30 THEN 30
                  when wacltv < 40 THEN 40
                  when wacltv < 50 THEN 50
                  when wacltv < 60 THEN 60
                  when wacltv < 70 THEN 70
                  when wacltv < 80 THEN 80
                  when wacltv < 90 THEN 90
                  when wacltv < 100 THEN 100
                  when wacltv < 110 THEN 110
                  when wacltv < 120 THEN 120
                  when wacltv < 130 THEN 130
                  when wacltv < 140 THEN 140
                  else 150 end), 
	walaBucket = (case 
                   when wala < 1 then 0
                   when wala < 10 then 10
    	     	   when wala < 20 then 20
    	           when wala < 30 then 30
    	           when wala < 40 then 40
    	           when wala < 50 then 50
    	           when wala < 60 then 60
    	           when wala < 70 then 70
    	           when wala < 80 then 80
    	           when wala < 90 then 90
    	           when wala < 100 then 100
    	           when wala < 110 then 110
    	           when wala < 120 then 120
    	           when wala < 130 then 130
    	           when wala < 140 then 140
    	           when wala < 150 then 150
    	           when wala < 160 then 160
    	           when wala < 170 then 170
    	           when wala < 180 then 180
    	           when wala < 190 then 190
    	           else 200 end),
	ficoBucket = (case 
	           when waocs < 500 then 500
	           when waocs < 540 then 540
	           when waocs < 580 then 580
	           when waocs < 600 then 600
	           when waocs < 620 then 620
	           when waocs < 640 then 640
	           when waocs < 660 then 660
	           when waocs < 680 then 680
	           when waocs < 700 then 700
	           when waocs < 720 then 720
	           when waocs < 740 then 740
	           when waocs < 760 then 760
	           when waocs < 780 then 780
	           when waocs < 800 then 800
	           else 820 end),
   convert(decimal(10,6), sum(CASE WHEN Pct_DELQ IS NOT NULL THEN Pct_DELQ * schamBalance ELSE 0.0 END) / sum(schamBalance)) as pct_dq
INTO #dq_pct_FHL
FROM #FHL_Pools
GROUP BY asof, cltvBucket, walaBucket, ficoBucket
ORDER BY asof, cltvBucket, walaBucket, ficoBucket
;
Commit;
     

--      Fannie
-- As we don't have any pool level dq information for Fannie, we use loan level credit data
-- But we have around 3 or 4 month lag

-- Loan level delinq information
--SET TEMPORARY OPTION IQGOVERN_PRIORITY  = 3
--DROP TABLE IF EXISTS #dq_pct_LL
--select 
--    d.beginDate as asOfDate,
--    cltvBucket = (case
--                  when origLTV / HPA < 10 THEN 10
--                  when origLTV / HPA < 20 THEN 20
--                  when origLTV / HPA < 30 THEN 30
--                  when origLTV / HPA < 40 THEN 40
--                  when origLTV / HPA < 50 THEN 50
--                  when origLTV / HPA < 60 THEN 60
--                  when origLTV / HPA < 70 THEN 70
--                  when origLTV / HPA < 80 THEN 80
--                  when origLTV / HPA < 90 THEN 90
--                  when origLTV / HPA < 100 THEN 100
--                  when origLTV / HPA < 110 THEN 110
--                  when origLTV / HPA < 120 THEN 120
--                  when origLTV / HPA < 130 THEN 130
--                  when origLTV / HPA < 140 THEN 140
--                  else 150 end), 
--	walaBucket = (case 
--                   when beginLoanAge < 1 then 0
--                   when beginLoanAge < 10 then 10
--    	     	   when beginLoanAge < 20 then 20
--    	           when beginLoanAge < 30 then 30
--    	           when beginLoanAge < 40 then 40
--    	           when beginLoanAge < 50 then 50
--    	           when beginLoanAge < 60 then 60
--    	           when beginLoanAge < 70 then 70
--    	           when beginLoanAge < 80 then 80
--    	           when beginLoanAge < 90 then 90
--    	           when beginLoanAge < 100 then 100
--    	           when beginLoanAge < 110 then 110
--    	           when beginLoanAge < 120 then 120
--    	           when beginLoanAge < 130 then 130
--    	           when beginLoanAge < 140 then 140
--    	           when beginLoanAge < 150 then 150
--    	           when beginLoanAge < 160 then 160
--    	           when beginLoanAge < 170 then 170
--    	           when beginLoanAge < 180 then 180
--    	           when beginLoanAge < 190 then 190
--    	           else 200 end),
--	ficoBucket = (case 
--	           when origFICO < 500 then 500
--	           when origFICO < 540 then 540
--	           when origFICO < 580 then 580
--	           when origFICO < 600 then 600
--	           when origFICO < 620 then 620
--	           when origFICO < 640 then 640
--	           when origFICO < 660 then 660
--	           when origFICO < 680 then 680
--	           when origFICO < 700 then 700
--	           when origFICO < 720 then 720
--	           when origFICO < 740 then 740
--	           when origFICO < 760 then 760
--	           when origFICO < 780 then 780
--	           when origFICO < 800 then 800
--	           else 820 end),
--    convert(decimal(10,6), sum(CASE WHEN endStatus IN ('1','2','3') THEN beginBalance ELSE 0.0 END) / sum(beginBalance)) * 100 as pct_dq
--INTO #dq_pct_LL
--FROM fnm.PIV_CreditOrigination s
--JOIN fnm.PIV_CreditPerformanceHist d ON s.loanID = d.loanID
--GROUP BY beginDate, cltvBucket, walaBucket, ficoBucket
--ORDER BY beginDate, cltvBucket, walaBucket, ficoBucket
--
--Commit

--SELECT * INTO report.FNM_dq_pct_LL_SymphonyTracking FROM #dq_pct_LL
--COMMIT

-- update from credit loan data
UPDATE #FNM_Pools perf SET perf.Pct_DELQ = CASE WHEN perf.pct_CURRENT IS NULL AND dl.pct_DQ IS NULL THEN 0.0 ELSE (CASE WHEN perf.pct_CURRENT IS NOT NULL THEN perf.pct_DELQ ELSE dl.pct_DQ END) END,
                           perf.Pct_CURRENT = CASE WHEN perf.pct_CURRENT IS NULL AND dl.pct_DQ IS NULL THEN 100.0 ELSE (CASE WHEN perf.pct_CURRENT IS NOT NULL THEN perf.pct_CURRENT ELSE (100-dl.pct_DQ) END) END
From #FNM_Pools perf 
--left join #dq_pct_LL dl 	on dl.asOfDate = perf.asOf
left join report.FHL_dq_pct_LL_SymphonyTracking dl 	on dl.asOfDate = perf.asOf
where 1=1
	AND wacltv <= dl.cltvBucket
    AND wacltv > dl.cltvBucket - 10
	AND wala <= dl.walaBucket
	AND wala > dl.walaBucket - 10
	AND waocs <= dl.ficoBucket
    AND waocs > dl.ficoBucket - 20
;

-- update from FHL data
UPDATE #FNM_Pools perf SET perf.Pct_DELQ = CASE WHEN perf.pct_CURRENT IS NULL AND dl.pct_DQ IS NULL THEN 0.0 ELSE (CASE WHEN perf.pct_CURRENT IS NOT NULL THEN perf.pct_DELQ ELSE dl.pct_DQ END) END,
                           perf.Pct_CURRENT = CASE WHEN perf.pct_CURRENT IS NULL AND dl.pct_DQ IS NULL THEN 100.0 ELSE (CASE WHEN perf.pct_CURRENT IS NOT NULL THEN perf.pct_CURRENT ELSE (100-dl.pct_DQ) END) END
From #FNM_Pools perf 
left join #dq_pct_FHL dl 	on dl.asOf = perf.asOf
where 1=1
	AND wacltv <= dl.cltvBucket
    AND wacltv > dl.cltvBucket - 10
	AND wala <= dl.walaBucket
	AND wala > dl.walaBucket - 10
	AND waocs <= dl.ficoBucket
    AND waocs > dl.ficoBucket - 20
;

UPDATE #FNM_Pools perf SET perf.Pct_DELQ = 0,
                           perf.Pct_CURRENT = 100
    where perf.Pct_DELQ IS NULL;



-----------------------------------------------------------
-- Store all pools with pertinent data
-----------------------------------------------------------
DROP TABLE IF EXISTS #refinance_pools;
SELECT
    issueId,
    year(issueDate) as vintage,
    issueDate,
    marketTicker,
    OrigCoupon as origCoupon,
    asOf as asOfDate,
	monthBucket = (case 
        		    when month(asOf) = 1  then 'Jan'
        		    when month(asOf) = 2  then 'Feb'
        		    when month(asOf) = 3  then 'Mar'
        		    when month(asOf) = 4  then 'Apr'
        		    when month(asOf) = 5  then 'May'
        		    when month(asOf) = 6  then 'Jun'
        		    when month(asOf) = 7  then 'Jul'
        		    when month(asOf) = 8  then 'Aug'
         		    when month(asOf) = 9  then 'Sep'
        		    when month(asOf) = 10 then 'Oct'
                    when month(asOf) = 11 then 'Nov'
                    when month(asOf) = 12 then 'Dec'
        		    end),
	currentBalance as cbal,
	schamBalance as bbal,
    CASE WHEN Pct_OWNER IS NULL THEN 100.0 ELSE Pct_OWNER END as ppct_OWNER,
    CASE WHEN Pct_2ND IS NULL THEN 0.0 ELSE Pct_2ND END as ppct_2ND,
    CASE WHEN Pct_INV IS NULL THEN 0.0 ELSE Pct_INV END as ppct_INV,
    CASE WHEN Pct_PURCH IS NULL THEN 100.0 ELSE Pct_PURCH END as ppct_PURCH,
    CASE WHEN Pct_REFI IS NULL THEN 0.0 ELSE Pct_REFI END as ppct_REFI,
    CASE WHEN Pct_OTHERS IS NULL THEN 0.0 ELSE Pct_OTHERS END as ppct_PurpOTHERS,
    Pct_DELQ as ppct_DELQ, 
    100.0 - ppct_DELQ as ppct_CURRENT, 
    CASE WHEN incentive IS NULL THEN 0.0 ELSE incentive END as iincentive,
    incentive_ToConv as iincentive_ToConv,
--    MtgRate,
    burnout as bburnout,
    cLLPA as ccLLPA,
    cPMI as ccPMI,
    oPMI as ooPMI,
    Pct_HARP as ppct_HARP,
    Pct_TPO as ppct_TPO,
	SSATO as ssato,
	wacltv as ccltv,
    CASE WHEN waclSize = -999 THEN NULL ELSE waclSize END as wwacls,
	waoltv as wwaoltv,
	wwala as wwala,
	wwac as wwac,
	waocs as ffico,
    refiEligPct * 100 as refiEligPct,
    100 * HPA_2YR as hhpa2yr,
    convert(decimal(10,6), CASE WHEN 1.0 - currentBalance / schamBalance < 0 THEN 0.0 ELSE 1.0 - currentBalance / schamBalance END) as smm,
    convert(decimal(10,6), IFNULL(inVoluntaryAmount, 0.0, CASE WHEN 1.0 - inVoluntaryAmount / schamBalance < 0 THEN 0.0 ELSE 1.0 - inVoluntaryAmount / schamBalance END)) as mdr
INTO #refinance_pools
FROM
(
SELECT p.marketTicker, p.issueId, p.pct_owner, p.pct_2nd, p.pct_inv, p.Pct_PURCH, p.Pct_REFI, p.Pct_OTHERS, p.Pct_CURRENT,  p.Pct_DELQ,  p.Pct_D30,  p.Pct_D60, p.Pct_D90, wala as wwala, SATO as SSATO, HPA_1YR, HPA_2YR, p.asOf, p.issueDate, p.OrigCoupon, schamBalance, currentBalance, inVoluntaryAmount, incentive, incentive_ToConv, waoltv, wacltv, waclSize, waocs, wac as wwac,  burnout, cLLPA, cPMI, oPMI, Pct_HARP, refiEligPct, Pct_TPO
FROM #FHL_Pools p
WHERE 1=1
    AND p.wala >= 1
UNION
SELECT p.marketTicker, p.issueId, p.pct_owner, p.pct_2nd, p.pct_inv, p.Pct_PURCH, p.Pct_REFI, p.Pct_OTHERS, p.Pct_CURRENT,  p.Pct_DELQ,  p.Pct_D30,  p.Pct_D60, p.Pct_D90, wala as wwala, SATO as SSATO, HPA_1YR, HPA_2YR, p.asOf, p.issueDate, p.OrigCoupon, schamBalance, currentBalance, inVoluntaryAmount, incentive, incentive_ToConv, waoltv, wacltv, waclSize, waocs, wac as wwac, burnout, cLLPA, cPMI, oPMI, Pct_HARP, refiEligPct, Pct_TPO
FROM #FNM_Pools p
WHERE 1=1
    AND p.wala >= 1
) o
;
COMMIT;



-----------------------------------------------------------
-- Create Media Effect Series for Scale

-- Combined Loan and Pool Percent Refinanceable Percent
-- Lag of 1 Month is Assumed
-----------------------------------------------------------
DROP TABLE IF EXISTS #refinanceable;
SELECT
    convert(date, dateadd(month, +1, AsOfDate)) as asOf,
    convert(numeric(6,2), 100.0 * SeriesNumValue) as pct_refinancible
INTO #refinanceable
FROM report.TimeSeries
WHERE 1=1
    AND TimeSeriesMetaId = (SELECT TimeSeriesMetaId FROM report.TimeSeriesMeta WHERE Source = 'PIV' AND TickerName = 'CONVENTIONAL_30YR_COMBINED' AND SeriesType = 'MONTHLY_PCT_REFI' AND ModelType = 'ScaleMediaEffectModel v3.0')
ORDER BY asOf
;
COMMIT;

CREATE INDEX asOf_idx ON #refinanceable(asOf);
COMMIT;



-----------------------------------------------------------
-- Create Mortgage Credit Availability Series for Scale

-- Raw Series from MBA
-----------------------------------------------------------
DROP TABLE IF EXISTS #CreditAvailability_mba;
SELECT
    AsOfDate as asOf,
    convert(numeric(6,2), SeriesNumValue) as mca_index
INTO #CreditAvailability_mba
FROM report.TimeSeries
WHERE 1=1
    AND TimeSeriesMetaId = (SELECT TimeSeriesMetaId FROM report.TimeSeriesMeta WHERE Source = 'PIV' AND TickerName = 'MBA_CAI_Composite' AND SeriesType = 'Index' AND ModelType = 'MCAI_v1.0')
ORDER BY asOf
;
COMMIT;

-- Extend Time Series for several months after end
DROP TABLE IF EXISTS #CreditAvailability_extended;
SELECT
    asOf,
    mca_index
INTO #CreditAvailability_extended
FROM #CreditAvailability_mba
;
COMMIT;

INSERT INTO #CreditAvailability_extended
SELECT dateadd(month,1,asOf), mca_index FROM #CreditAvailability_mba
WHERE asOf = (SELECT max(asOf) FROM #CreditAvailability_mba)
;

INSERT INTO #CreditAvailability_extended
SELECT dateadd(month,2,asOf), mca_index FROM #CreditAvailability_mba
WHERE asOf = (SELECT max(asOf) FROM #CreditAvailability_mba)
;

DROP TABLE IF EXISTS #CreditAvailability;
SELECT 
    t1.asOf, 
    avg(t2.mca_index) AS mca_18mo
INTO #CreditAvailability
FROM #CreditAvailability_extended t1, #CreditAvailability_extended t2
WHERE t2.asOf
BETWEEN (dateadd(month,-17,t1.AsOf)) AND t1.asOf -- 18 Month average, but 17 is used with the BETWEEN clause
GROUP BY t1.asOf
ORDER BY t1.asOf
;
COMMIT;

CREATE INDEX asOf_idx ON #CreditAvailability(asOf);
COMMIT;

