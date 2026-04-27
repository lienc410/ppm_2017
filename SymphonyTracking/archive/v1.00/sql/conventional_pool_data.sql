-- Refinance Queries (Pool Level)


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
WHERE TransactionType = 'ALL_TRANSACTIONS' --'PURCHASE_ONLY' --
    AND loadQuarter = (SELECT max(loadQuarter) FROM hpi.HomePriceIndex)
    AND RegionType IN ('STATE','US_AND_CENSUS','USA')
    --AND RegionType IN ('MSA','STATE','STATE_NONMSA','US_AND_CENSUS')
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

CREATE INDEX series_idx ON #Mtg30YrRates_monthly(SeriesName);
CREATE INDEX asOf_idx ON #Mtg30YrRates_monthly(asOf);
CREATE INDEX asOf_lag1_idx ON #Mtg30YrRates_monthly(asOf_lag1);
CREATE INDEX asOf_lag2_idx ON #Mtg30YrRates_monthly(asOf_lag2);
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
    f2.schamBalance, -- offset by 1 so that our model projection for the factor date will match the prepay for that period
    f.wac, 
    CASE WHEN f.waoltv = -999 THEN NULL ELSE f.waoltv END as waoltv,
    CASE WHEN f.waclSize = -999 THEN NULL ELSE f.waclSize END as waclSize,
    CASE WHEN f.waolSize = -999 THEN NULL ELSE f.waolSize END as waolSize,
    CASE WHEN f.waocs = -999 THEN NULL ELSE f.waocs END as waocs, 
    f2.currentBalance, -- offset by 1 so that our model projection for the factor date will match the prepay for that period
    f2.inVoluntaryAmount,
    s.waCLTV,
    s.refi_incentive as incentive,
    s.currLLPA as cLLPA,
    s.currPMI as cPMI,
    s.origPMI as oPMI,
    s.percentHARP as Pct_HARP,
    mr.MtgRate as MtgRate,
    s.burnout as burnout,
    cast(NULL as numeric(8, 4)) as SATO,
    cast(NULL as numeric(8, 4)) as HPA,
    cast(NULL as numeric(8, 4)) as HPI,
    cast(NULL as numeric(8, 4)) as HPA_1YR,
    cast(NULL as numeric(8, 4)) as HPA_2YR,
    cast(100.0 as numeric(8, 2)) as Pct_OWNER,
    cast(0.0 as numeric(8, 2)) as Pct_2ND,
    cast(0.0 as numeric(8, 2)) as Pct_INV,
    cast(100.0 as numeric(8, 2)) as Pct_CURRENT,
    cast(0.0 as numeric(8, 2)) as Pct_DELQ,
    cast(0.0 as numeric(8, 2)) as Pct_D30,
    cast(0.0 as numeric(8, 2)) as Pct_D60,
    cast(0.0 as numeric(8, 2)) as Pct_D90
INTO #FHL_Pools
FROM fhl.sec p
JOIN fhl.Prefix x
    ON p.prefix = x.prefix
    AND p.product = x.product
JOIN #ticker tk
    ON p.marketTicker = tk.tickerName   
JOIN fhl.secFactor f
    ON p.issueId = f.issueId
JOIN fhl.secFactor f2
    ON p.issueId = f2.issueId
    AND f.asOf = dateadd(month, -1, f2.asOf)
JOIN #Mtg30YrRates_monthly mr
    ON mr.asOf_lag1 = f.asOf
    AND mr.SeriesName = tk.mtgRateSeries
LEFT JOIN fhl.secSupp s
    ON p.issueId = s.issueId
    AND s.asOf = f.asOf
WHERE 1=1
    AND p.collateralType = 'LOAN'
    AND f.wala >= 1
    AND f.schamBalance > 0.01
    AND f2.schamBalance > 0.01
    AND f.wac > 0
;
COMMIT;

CREATE INDEX issueId_idx ON #FHL_Pools(issueId);
CREATE INDEX issueDate_idx ON #FHL_Pools(issueDate);
CREATE INDEX asOf_idx ON #FHL_Pools(asOf);
COMMIT;

  -- Fannie
DROP TABLE IF EXISTS #FNMA_Pools;
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
    f2.schamBalance, -- offset by 1 so that our model projection for the factor date will match the prepay for that period
    f.wac, 
    CASE WHEN f.waoltv = -999 THEN NULL ELSE f.waoltv END as waoltv,
    CASE WHEN f.waclSize = -999 THEN NULL ELSE f.waclSize END as waclSize,
    CASE WHEN f.waolSize = -999 THEN NULL ELSE f.waolSize END as waolSize,
    CASE WHEN f.waocs = -999 THEN NULL ELSE f.waocs END as waocs, 
    f2.currentBalance, -- offset by 1 so that our model projection for the factor date will match the prepay for that period
    f2.inVoluntaryAmount, --always NULL for Fannie Data
    s.waCLTV,
    s.refi_incentive as incentive,
    s.currLLPA as cLLPA,
    s.currPMI as cPMI,
    s.origPMI as oPMI,
    s.percentHARP as Pct_HARP,
    mr.MtgRate as MtgRate,
    s.burnout as burnout,
    cast(NULL as numeric(8, 4)) as SATO,
    cast(NULL as numeric(8, 4)) as HPA,
    cast(NULL as numeric(8, 4)) as HPI,
    cast(NULL as numeric(8, 4)) as HPA_1YR,
    cast(NULL as numeric(8, 4)) as HPA_2YR,
    cast(100.0 as numeric(8, 2)) as Pct_OWNER,
    cast(0.0 as numeric(8, 2)) as Pct_2ND,
    cast(0.0 as numeric(8, 2)) as Pct_INV,
    cast(100.0 as numeric(8, 2)) as Pct_CURRENT,
    cast(0.0 as numeric(8, 2)) as Pct_DELQ,
    cast(0.0 as numeric(8, 2)) as Pct_D30,
    cast(0.0 as numeric(8, 2)) as Pct_D60,
    cast(0.0 as numeric(8, 2)) as Pct_D90
INTO #FNMA_Pools
FROM fnm.sec p
JOIN fnm.Prefix x
    ON p.prefix = x.prefix
    AND p.product = x.product
JOIN #ticker tk
    ON p.marketTicker = tk.tickerName  
JOIN fnm.secFactor f
    ON p.issueId = f.issueId
JOIN fnm.secFactor f2
    ON p.issueId = f2.issueId
    AND f.asOf = dateadd(month, -1, f2.asOf)
JOIN #Mtg30YrRates_monthly mr
    ON mr.asOf_lag1 = f.asOf
    AND mr.SeriesName = tk.mtgRateSeries
LEFT JOIN fnm.secSupp s
    ON p.issueId = s.issueId
    AND s.asOf = f.asOf
WHERE  1=1
    AND p.collateralType = 'LOAN'
    AND f.wala >= 1
    AND f.schamBalance > 0.01
    AND f2.schamBalance > 0.01
    AND f.wac > 0
;
COMMIT;

CREATE INDEX issueId_idx ON #FNMA_Pools(issueId);
CREATE INDEX issueDate_idx ON #FNMA_Pools(issueDate);
CREATE INDEX asOf_idx ON #FNMA_Pools(asOf);
COMMIT;


-- Update HPA_XYR and HPI
UPDATE #FHL_Pools perf SET perf.HPA_2YR = hpi.HPA_2YR, perf.HPA_1YR = hpi.HPA_1YR, perf.HPI = hpi.HPIndex
FROM #HPA_MA hpi
WHERE perf.asOf = hpi.asOf 
    AND hpi.Region = 'USA'
;

UPDATE #FNMA_Pools perf SET perf.HPA_2YR = hpi.HPA_2YR, perf.HPA_1YR = hpi.HPA_1YR, perf.HPI = hpi.HPIndex
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
DROP TABLE IF EXISTS #FNMA_MinDate_FICO;
SELECT
    marketTicker,
    issueId,
    issueDate,
    min(asOf) as asOf,
    cast(NULL as numeric(8, 4)) as waocs
INTO #FNMA_MinDate_FICO
FROM #FNMA_Pools p
WHERE p.waocs IS NOT NULL 
    AND p.waocs <> -999
GROUP BY marketTicker, issueId, issueDate
;
COMMIT;

UPDATE #FNMA_MinDate_FICO s SET s.waocs = d.waocs
FROM #FNMA_Pools d
WHERE s.issueId = d.issueId
    AND s.asOf = d.asOf
;

DROP TABLE IF EXISTS #FNMA_MinDate_OLTV;
SELECT
    marketTicker,
    issueId,
    issueDate,
    min(asOf) as asOf,
    cast(NULL as numeric(8, 4)) as waoltv
INTO #FNMA_MinDate_OLTV
FROM #FNMA_Pools p
WHERE p.waoltv IS NOT NULL
    AND p.waoltv <> -999
GROUP BY marketTicker, issueId, issueDate
;
COMMIT;

UPDATE #FNMA_MinDate_OLTV s SET s.waoltv = d.waoltv
FROM #FNMA_Pools d
WHERE s.issueId = d.issueId
    AND s.asOf = d.asOf
;

DROP TABLE IF EXISTS #FNMA_Origination;
SELECT
    marketTicker,
    issueId,
    cast(NULL as date) as originationDate,
    min(asOf) as asOf,
    cast(NULL as numeric(8, 4)) as HPI_orig
INTO #FNMA_Origination
FROM #FNMA_Pools p
GROUP BY marketTicker, issueId
;
COMMIT;

UPDATE #FNMA_Origination s SET s.originationDate = p.originationDate
FROM #FNMA_Pools p
WHERE p.issueId = s.issueId
    AND p.asOf = s.asOf
;
COMMIT;

UPDATE #FNMA_Origination s SET s.HPI_orig = hpi.HPIndex
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
UPDATE #FNMA_Pools perf SET perf.waocs = s.waocs
FROM #FNMA_MinDate_FICO s
WHERE perf.issueId = s.issueId 
    AND perf.waocs IS NULL
;

DROP TABLE IF EXISTS #FNMA_IssueDate_FICO;
SELECT
    issueDate,
    sum(schambalance * waocs) / sum(schambalance) as WAVG_FICO
INTO #FNMA_IssueDate_FICO
FROM #FNMA_Pools p
WHERE waocs IS NOT NULL
GROUP BY issueDate
;
COMMIT;

UPDATE #FNMA_Pools perf SET perf.waocs = oc.WAVG_FICO
FROM #FNMA_IssueDate_FICO oc
WHERE perf.issueDate = oc.issueDate
    AND perf.waocs IS NULL 
;

UPDATE #FNMA_Pools perf SET perf.waocs = 710
WHERE perf.waocs IS NULL 
    OR perf.waocs = -999
    OR perf.waocs = 999
;

    -- OLTV
UPDATE #FNMA_Pools perf SET perf.waoltv = s.waoltv
FROM #FNMA_MinDate_OLTV s
WHERE perf.issueId = s.issueId 
    AND perf.waoltv IS NULL
;

DROP TABLE IF EXISTS #FNMA_IssueDate_OLTV;
SELECT
    issueDate,
    sum(schambalance * waoltv) / sum(schambalance) as WAVG_OLTV
INTO #FNMA_IssueDate_OLTV
FROM #FNMA_Pools p
WHERE waoltv IS NOT NULL
GROUP BY issueDate
;
COMMIT;

UPDATE #FNMA_Pools perf SET perf.waoltv = ltv.WAVG_OLTV
FROM #FNMA_IssueDate_OLTV ltv
WHERE perf.issueDate = ltv.issueDate
    AND perf.waocs IS NULL 
;

UPDATE #FNMA_Pools perf SET perf.waoltv = 75
WHERE waoltv IS NULL 
    OR waoltv = -999
    OR waoltv = 999
;

    -- HPA / CLTV
UPDATE #FNMA_Pools perf SET perf.HPA = perf.HPI / s.HPI_orig
FROM #FNMA_Origination s
WHERE perf.issueId = s.issueId 
;

UPDATE #FNMA_Pools perf SET perf.wacltv = perf.waoltv * perf.factor / perf.HPA
WHERE wacltv IS NULL 
    OR wacltv = -999
    OR wacltv = 999
;

-- Pool Distributions
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

  -- Fannie
DROP TABLE IF EXISTS #FNMA_Occ_Dist;
SELECT
    issueId,
    asOf,
    sum(Pct_OWNER) as Pct_OWNER,
    sum(Pct_2ND) as Pct_2ND,
    sum(Pct_INV) as Pct_INV,
    Pct_OWNER + Pct_2ND + Pct_INV as Pct_Total
INTO #FNMA_Occ_Dist
FROM
(
SELECT
    p.issueId,
    p.asOf,
    CASE WHEN distributionType IN ('OWNER') THEN percentRpb ELSE 0.0 END as Pct_OWNER,
    CASE WHEN distributionType IN ('2ND','N/A') THEN percentRpb ELSE 0.0 END as Pct_2ND,
    CASE WHEN distributionType IN ('INV') THEN percentRpb ELSE 0.0 END as Pct_INV
FROM #FNMA_Pools p
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

CREATE INDEX issueId_idx ON #FNMA_Occ_Dist(issueId);
CREATE INDEX asOf_idx ON #FNMA_Occ_Dist(asOf);
COMMIT;

-- Update Rows that don't sum to 1
UPDATE #FHL_Occ_Dist SET Pct_OWNER = 100.0, Pct_2ND = 0.0, Pct_INV = 0.0, Pct_Total = 100.0
WHERE abs(Pct_Total - 100.0) > 1
;

UPDATE #FNMA_Occ_Dist SET Pct_OWNER = 100.0, Pct_2ND = 0.0, Pct_INV = 0.0, Pct_Total = 100.0
WHERE abs(Pct_Total - 100.0) > 1
;

-- Update the Pools Tables with the Occ Type Info
UPDATE #FHL_Pools perf SET perf.Pct_OWNER = occ.Pct_OWNER, perf.Pct_2ND = occ.Pct_2ND, perf.Pct_INV = occ.Pct_INV
FROM #FHL_Occ_Dist occ
WHERE perf.issueId = occ.issueId 
    AND perf.asOf = occ.asOf
;

UPDATE #FNMA_Pools perf SET perf.Pct_OWNER = occ.Pct_OWNER, perf.Pct_2ND = occ.Pct_2ND, perf.Pct_INV = occ.Pct_INV
FROM #FNMA_Occ_Dist occ
WHERE perf.issueId = occ.issueId 
    AND perf.asOf = occ.asOf
;

 -- Delinquency (Freddie Only)
DROP TABLE IF EXISTS #FHL_DELQ_Dist;
SELECT
    p.issueId,
    p.asOf,
    sum(CASE WHEN percentrpb_DEL30 = -999 THEN 0 ELSE IFNULL(percentrpb_DEL30, 0.0, percentrpb_DEL30) END) as Pct_DQ30,
    sum(CASE WHEN percentrpb_DEL60 = -999 THEN 0 ELSE IFNULL(percentrpb_DEL60, 0.0, percentrpb_DEL60) END) as Pct_DQ60,
    sum(CASE WHEN percentrpb_DEL90 = -999 THEN 0 ELSE IFNULL(percentrpb_DEL90, 0.0, percentrpb_DEL90) END) as Pct_DQ90
INTO #FHL_DELQ_Dist
FROM #FHL_Pools p
LEFT JOIN fhl.PivotedDelinqDist s 
    ON p.issueID = s.issueID
    AND p.asOF = s.asOf
GROUP BY p.issueId, p.asOf
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


-- Update SATO

-- Store all pools with pertinent data
DROP TABLE IF EXISTS #refinance_pools;
SELECT
    issueId,
    year(issueDate) as vintage,
    marketTicker as marketTicket,
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
    CASE WHEN Pct_CURRENT IS NULL THEN 100.0 ELSE Pct_CURRENT END as ppct_CURRENT,
    CASE WHEN Pct_DELQ IS NULL THEN 0.0 ELSE Pct_DELQ END as ppct_DELQ,
    CASE WHEN Pct_D30 IS NULL THEN 0.0 ELSE Pct_D30 END as ppct_D30,
    CASE WHEN Pct_D60 IS NULL THEN 0.0 ELSE Pct_D60 END as ppct_D60,
    CASE WHEN Pct_D90 IS NULL THEN 0.0 ELSE Pct_D90 END as ppct_D90,
    incentive as iincentive,
    MtgRate,
    burnout as bburnout,
    cLLPA as ccLLPA,
    cPMI as ccPMI,
    oPMI as ooPMI,
    Pct_HARP as ppct_HARP,
	SSATO as ssato,
	wacltv as ccltv,
    CASE WHEN waclSize = -999 THEN NULL ELSE waclSize END as wwacls,
	waoltv as wwaoltv,
	wwala as wwala,
	wwac as wwac,
	waocs as ffico,
    100 * HPA_2YR as hhpa2yr,
    convert(decimal(10,6), CASE WHEN 1.0 - currentBalance / schamBalance < 0 THEN 0.0 ELSE 1.0 - currentBalance / schamBalance END) as smm,
    convert(decimal(10,6), IFNULL(inVoluntaryAmount, 0.0, CASE WHEN 1.0 - inVoluntaryAmount / schamBalance < 0 THEN 0.0 ELSE 1.0 - inVoluntaryAmount / schamBalance END)) as mdr
INTO #refinance_pools
FROM
(
SELECT p.marketTicker, p.issueId, p.pct_owner, p.pct_2nd, p.pct_inv, p.Pct_CURRENT,  p.Pct_DELQ,  p.Pct_D30,  p.Pct_D60, p.Pct_D90, wala as wwala, SATO as SSATO, HPA_1YR, HPA_2YR, p.asOf, p.issueDate, p.OrigCoupon, schamBalance, currentBalance, inVoluntaryAmount, incentive, waoltv, wacltv, waclSize, waocs, wac as wwac, MtgRate, burnout, cLLPA, cPMI, oPMI, Pct_HARP
FROM #FHL_Pools p
WHERE 1=1
    AND p.wala >= 1

UNION ALL

SELECT p.marketTicker, p.issueId, p.pct_owner, p.pct_2nd, p.pct_inv, p.Pct_CURRENT,  p.Pct_DELQ,  p.Pct_D30,  p.Pct_D60, p.Pct_D90, wala as wwala, SATO as SSATO, HPA_1YR, HPA_2YR, p.asOf, p.issueDate, p.OrigCoupon, schamBalance, currentBalance, inVoluntaryAmount, incentive, waoltv, wacltv, waclSize, waocs, wac as wwac, MtgRate, burnout, cLLPA, cPMI, oPMI, Pct_HARP
FROM #FNMA_Pools p
WHERE 1=1
    AND p.wala >= 1
) o
;
COMMIT;

  -- All Conventional Conforming Pools (FGLMC and FNCL)
DROP TABLE IF EXISTS #refinanceable;
SELECT
    asOfDate,
    100.0 * sum(CASE WHEN refi_incentive >= 50.0 THEN currentBalance ELSE 0.0 END) / sum(currentBalance) as pct_refinancible_pool
INTO #refinanceable
FROM (
    SELECT s.asOf as asOfDate, refi_incentive, currentBalance
    FROM fhl.sec p
    JOIN fhl.secFactor f
        ON p.issueId = f.issueId
        AND p.marketTicker in ('FGLMC')
    LEFT JOIN fhl.secSupp s
        ON p.issueId = s.issueId
        AND s.asOf = f.asOf
    WHERE 1=1
        AND p.collateralType = 'LOAN'
    
    UNION ALL
    
    SELECT s.asOf as asOfDate, refi_incentive, currentBalance
    FROM fnm.sec p
    JOIN fnm.secFactor f
        ON p.issueId = f.issueId
        AND p.marketTicker in ('FNCL')
    LEFT JOIN fnm.secSupp s
        ON p.issueId = s.issueId
        AND s.asOf = f.asOf
    WHERE 1=1
        AND p.collateralType = 'LOAN'
    ) t
WHERE asOFDate IS NOT NULL 
GROUP BY asOfDate
HAVING sum(currentBalance) > 0
ORDER BY asOfDate
;

