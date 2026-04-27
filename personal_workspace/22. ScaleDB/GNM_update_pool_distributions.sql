-- Ginnie
-- Pool Level
-- Part 2 of 6
-- Script to update distribution data
-- Updates Occupancy, Purpose, Delinquency, Channel, FHA/VA

-- Before execute the script, need to set the dates to run for
DROP TABLE IF EXISTS #tmp_asOf;
SELECT CAST('#####ASOF#####' AS DATE) asOf INTO #tmp_asOf
--SELECT CAST ('2017-06-01' AS DATE) asOf INTO #tmp_asOf
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


-- Create Pool Historical Data
DROP TABLE IF EXISTS #GNM_PoolDistribution;
SELECT
    ph.marketTicker,
    ph.issueId,
    ph.originationDate,
    ph.asOf,
    ph.balance,
    cast(NULL as numeric(6, 3)) as Pct_PURCH,
    cast(NULL as numeric(6, 3)) as Pct_REFI,
--    cast(NULL as numeric(6, 3)) as Pct_HMOD,
--    cast(NULL as numeric(6, 3)) as Pct_NHMOD,
--    cast(NULL as numeric(6, 3)) as Pct_NA,
    cast(NULL as numeric(6, 3)) as Pct_CURRENT,
    cast(NULL as numeric(6, 3)) as Pct_DELQ30p,
    cast(NULL as numeric(6, 3)) as Pct_DELQ60p,
    cast(NULL as numeric(6, 3)) as Pct_DELQ90p,
    cast(NULL as numeric(6, 3)) as Pct_RETAIL,
    cast(NULL as numeric(6, 3)) as Pct_BROKER,
    cast(NULL as numeric(6, 3)) as Pct_CORRES,
    cast(NULL as numeric(6, 3)) as Pct_SINGLE_UNIT,
    cast(NULL as numeric(6, 3)) as Pct_MULTIPLE_UNIT,
    cast(NULL as numeric(6, 3)) as Pct_FHA,
    cast(NULL as numeric(6, 3)) as Pct_VA,
    cast(NULL as numeric(6, 3)) as Pct_NON_FHA_VA
INTO #GNM_PoolDistribution
FROM scale.GNM_PoolHist ph
JOIN #ticker tk
    ON ph.marketTicker = tk.tickerName
WHERE 1=1
    AND ph.asOf >= (select dateadd(month, -12, asOf) as asOf from #tmp_asOf)
;
COMMIT;

CREATE INDEX issueId_idx ON #GNM_PoolDistribution(issueId);
CREATE INDEX asOf_idx ON #GNM_PoolDistribution(asOf);
COMMIT;


-- Loan Purpose Distribution
DROP TABLE IF EXISTS #GNM_Purpose_Dist;
SELECT
    issueId,
    asOf,
    sum(Pct_PURCH) as Pct_PURCH,
    sum(Pct_REFI) as Pct_REFI
--    sum(Pct_HMOD) as Pct_HMOD,
--    sum(Pct_NHMOD) as Pct_NHMOD,
--    sum(Pct_NA) as Pct_NA
INTO #GNM_Purpose_Dist
FROM
(
SELECT
    p.issueId,
    p.asOf,
    CASE WHEN distributionType IN ('PURCH') THEN percentRpb ELSE 0.0 END as Pct_PURCH,
    CASE WHEN distributionType IN ('RE-FI') THEN percentRpb ELSE 0.0 END as Pct_REFI
--    CASE WHEN distributionType IN ('HMOD') THEN percentRpb ELSE 0.0 END as Pct_HMOD,
--    CASE WHEN distributionType IN ('NHMOD') THEN percentRpb ELSE 0.0 END as Pct_NHMOD,
--    CASE WHEN distributionType IN ('N/A') THEN percentRpb ELSE 0.0 END as Pct_NA
FROM #GNM_PoolDistribution p
JOIN gnm.PIV_LoanDist d
    ON p.issueId = d.issueId
    AND p.asof = d.asOf
    AND distributionName = 'LOANPURPOSE'
    AND subtype = 'ALL'
    --AND originationDate >= '1991-03-01'
    AND p.asOf >= '2004-07-01' --'2005-08-01'
    AND p.asOf NOT IN ('2012-02-01')
) t
GROUP BY issueId, asOf
;
COMMIT;

CREATE INDEX issueId_idx ON #GNM_Purpose_Dist(issueId);
CREATE INDEX asOf_idx ON #GNM_Purpose_Dist(asOf);
COMMIT;

UPDATE #GNM_Purpose_Dist SET Pct_PURCH = NULL, Pct_REFI = NULL WHERE abs(Pct_PURCH + Pct_REFI - 100.0) > 15.0;
COMMIT;

UPDATE #GNM_PoolDistribution perf SET perf.Pct_PURCH = purp.Pct_PURCH, perf.Pct_REFI = purp.Pct_REFI --, perf.Pct_HMOD = purp.Pct_HMOD, perf.Pct_NHMOD = purp.Pct_NHMOD, perf.Pct_NA = purp.Pct_NA
FROM #GNM_Purpose_Dist purp
WHERE perf.issueId = purp.issueId 
    AND perf.asOf = purp.asOf
;
COMMIT;

-- fix '2012-02-01' asof (set = to '2012-03-01' if available
UPDATE #GNM_PoolDistribution t SET t.Pct_PURCH = t1.Pct_PURCH, t.Pct_REFI = t1.Pct_REFI 
FROM #GNM_PoolDistribution t1
WHERE 1=1
    AND t.issueId = t1.issueId
    AND t.asOf = '2012-02-01'
    AND t1.asOf = '2012-03-01'
    AND t1.Pct_PURCH IS NOT NULL
    AND t1.Pct_REFI IS NOT NULL
;
COMMIT;

-- fix dates back in time (min asof etc)
DROP TABLE IF EXISTS #GNM_MinDate_PURP;
SELECT
    issueId,
    min(asOf) as asOf,
    cast(NULL as numeric(12, 2)) as Pct_PURCH,
    cast(NULL as numeric(12, 2)) as Pct_REFI
INTO #GNM_MinDate_PURP
FROM #GNM_Purpose_Dist p
WHERE p.Pct_PURCH IS NOT NULL AND p.Pct_REFI IS NOT NULL
GROUP BY issueId
;
COMMIT;

UPDATE #GNM_MinDate_PURP s SET s.Pct_PURCH = d.Pct_PURCH, s.Pct_REFI = d.Pct_REFI
FROM #GNM_Purpose_Dist d
WHERE s.issueId = d.issueId
    AND s.asOf = d.asOf
;

UPDATE #GNM_PoolDistribution perf SET perf.Pct_PURCH = s.Pct_PURCH, perf.Pct_REFI = s.Pct_REFI
FROM #GNM_MinDate_PURP s
WHERE perf.issueId = s.issueId 
    AND (perf.Pct_PURCH IS NULL OR perf.Pct_REFI IS NULL)
    AND perf.asOf <= s.asOf
;

-- insert origination data
DROP TABLE IF EXISTS #GNM_OriginationDate_PURP;
SELECT
    year(originationDate) as origYear,
    sum(balance * Pct_PURCH) / sum(balance) as WAVG_PURCH,
    sum(balance * Pct_REFI) / sum(balance) as WAVG_REFI,
    sum(balance) as sum_ls
INTO #GNM_OriginationDate_PURP
FROM #GNM_PoolDistribution
WHERE Pct_PURCH IS NOT NULL AND Pct_REFI IS NOT NULL
GROUP BY origYear
HAVING sum_ls > 100000000
;
COMMIT;

UPDATE #GNM_PoolDistribution perf SET perf.Pct_PURCH = purp.WAVG_PURCH, perf.Pct_REFI = purp.WAVG_REFI
FROM #GNM_OriginationDate_PURP purp
WHERE year(perf.originationDate) = purp.origYear
    AND (perf.Pct_PURCH IS NULL OR perf.Pct_REFI IS NULL)
;
COMMIT;

UPDATE #GNM_PoolDistribution SET Pct_PURCH = 100.0
WHERE Pct_PURCH > 100.0
;

UPDATE #GNM_PoolDistribution SET Pct_PURCH = 0.0
WHERE Pct_PURCH < 0.0
;

UPDATE #GNM_PoolDistribution SET Pct_REFI = 100.0
WHERE Pct_REFI > 100.0
;

UPDATE #GNM_PoolDistribution SET Pct_REFI = 0.0
WHERE Pct_REFI < 0.0
;

UPDATE #GNM_PoolDistribution SET Pct_PURCH = Pct_PURCH - ((Pct_PURCH + Pct_REFI - 100.0) / 2.0), Pct_REFI = Pct_REFI - ((Pct_PURCH + Pct_REFI - 100.0) / 2.0)
WHERE abs(Pct_PURCH + Pct_REFI - 100.0) > 0.0
;
COMMIT;

-- Delinquency Distribution
DROP TABLE IF EXISTS #GNMA_DELQ_Dist;
SELECT
    p.issueId,
    p.asOf,
    sum(IFNULL(rpb_RPDEL , 0.0, rpb_RPDEL ) + IFNULL(rpb_FORECL , 0.0, rpb_FORECL ) + IFNULL(rpb_REPLMT , 0.0, rpb_REPLMT )) as default_bal,
    sum(CASE WHEN percentrpb_DEL30 = -999 THEN 0 ELSE IFNULL(percentrpb_DEL30, 0.0, percentrpb_DEL30) END) as Pct_DQ30,
    sum(CASE WHEN percentrpb_DEL60 = -999 THEN 0 ELSE IFNULL(percentrpb_DEL60, 0.0, percentrpb_DEL60) END) as Pct_DQ60,
    sum(CASE WHEN percentrpb_DEL90 = -999 THEN 0 ELSE IFNULL(percentrpb_DEL90, 0.0, percentrpb_DEL90) END) as Pct_DQ90,
    sum(CASE WHEN percentrpb_DEL120 = -999 THEN 0 ELSE IFNULL(percentrpb_DEL120, 0.0, percentrpb_DEL120) END) as Pct_DQ120
INTO #GNMA_DELQ_Dist
FROM #GNM_PoolDistribution p
LEFT JOIN gnm.PivotedDelinqDist s 
    ON p.issueID = s.issueID
    AND p.asOF = s.asOf
GROUP BY p.issueId, p.asOf
;
COMMIT;

CREATE INDEX issueId_idx ON #GNMA_DELQ_Dist(issueId);
CREATE INDEX asOf_idx ON #GNMA_DELQ_Dist(asOf);
COMMIT;

UPDATE #GNM_PoolDistribution perf SET perf.Pct_DELQ30p = dist.Pct_DQ30 + dist.Pct_DQ60 + dist.Pct_DQ90 + dist.Pct_DQ120, 
    perf.Pct_DELQ60p = dist.Pct_DQ60 + dist.Pct_DQ90 + dist.Pct_DQ120,
    perf.Pct_DELQ90p = dist.Pct_DQ90 + dist.Pct_DQ120
FROM #GNMA_DELQ_Dist dist
WHERE perf.issueId = dist.issueId 
    AND perf.asOf = dist.asOf
;
UPDATE #GNM_PoolDistribution perf SET perf.Pct_CURRENT = 100.0 - perf.Pct_DELQ30p;

UPDATE #GNM_PoolDistribution perf SET perf.Pct_CURRENT = 0.0 WHERE perf.Pct_CURRENT < 0;
UPDATE #GNM_PoolDistribution perf SET perf.Pct_DELQ30p = 0.0 WHERE perf.Pct_DELQ30p < 0;
UPDATE #GNM_PoolDistribution perf SET perf.Pct_DELQ60p = 0.0 WHERE perf.Pct_DELQ60p < 0;
UPDATE #GNM_PoolDistribution perf SET perf.Pct_DELQ90p = 0.0 WHERE perf.Pct_DELQ90p < 0;
UPDATE #GNM_PoolDistribution perf SET perf.Pct_CURRENT = 100.0 WHERE perf.Pct_CURRENT > 100;
UPDATE #GNM_PoolDistribution perf SET perf.Pct_DELQ30p = 100.0 WHERE perf.Pct_DELQ30p > 100;
UPDATE #GNM_PoolDistribution perf SET perf.Pct_DELQ60p = 100.0 WHERE perf.Pct_DELQ60p > 100;
UPDATE #GNM_PoolDistribution perf SET perf.Pct_DELQ90p = 100.0 WHERE perf.Pct_DELQ90p > 100;

UPDATE #GNM_PoolDistribution perf SET perf.Pct_CURRENT = NULL, perf.Pct_DELQ30p = NULL, perf.Pct_DELQ60p = NULL, perf.Pct_DELQ90p = NULL
WHERE perf.asOf < '2005-12-01'
;
COMMIT;

-- Origination Channel Distribution
DROP TABLE IF EXISTS #GNM_Channel_Dist;
SELECT
    marketTicker,
    issueId,
    asOf,
    sum(Pct_RETAIL) as Pct_RETAIL,
    sum(Pct_BROKER) as Pct_BROKER,
    sum(Pct_CORRES) as Pct_CORRES,
    Pct_RETAIL + Pct_BROKER + Pct_CORRES as Pct_Total
INTO #GNM_Channel_Dist
FROM
(
SELECT
    p.marketTicker,
    p.issueId,
    p.asOf,
    CASE WHEN distributionType IN ('RETAIL') THEN percentRpb ELSE 0.0 END as Pct_RETAIL,
    CASE WHEN distributionType IN ('BROKER') THEN percentRpb ELSE 0.0 END as Pct_BROKER,
    CASE WHEN distributionType IN ('CORRES') THEN percentRpb ELSE 0.0 END as Pct_CORRES
FROM #GNM_PoolDistribution p
JOIN gnm.PIV_LoanDist d
    ON p.issueId = d.issueId
    AND p.asof = d.asOf
    AND distributionName = 'TPO'
    AND subtype = 'ALL'
WHERE 1=1
) t
GROUP BY marketTicker, issueId, asOf
;
COMMIT;

CREATE INDEX issueId_idx ON #GNM_Channel_Dist(issueId);
CREATE INDEX asOf_idx ON #GNM_Channel_Dist(asOf);
COMMIT;

UPDATE #GNM_Channel_Dist SET Pct_RETAIL = NULL, Pct_BROKER = NULL, Pct_CORRES = NULL WHERE abs(Pct_Total - 100.0) > 15.0;
COMMIT;

UPDATE #GNM_PoolDistribution perf SET perf.Pct_RETAIL = ch.Pct_RETAIL, perf.Pct_BROKER = ch.Pct_BROKER, perf.Pct_CORRES = ch.Pct_CORRES
FROM #GNM_Channel_Dist ch
WHERE perf.issueId = ch.issueId 
    AND perf.asOf = ch.asOf
;
COMMIT;

DROP TABLE IF EXISTS #GNM_OriginationDate_CHAN;
SELECT
    --marketTicker,
    year(originationDate) as origYear,
    sum(balance * Pct_RETAIL) / sum(balance) as WAVG_RETAIL,
    sum(balance * Pct_BROKER) / sum(balance) as WAVG_BROKER,
    sum(balance * Pct_CORRES) / sum(balance) as WAVG_CORRES,
    sum(balance) as sum_ls
INTO #GNM_OriginationDate_CHAN
FROM #GNM_PoolDistribution
WHERE Pct_RETAIL IS NOT NULL AND Pct_BROKER IS NOT NULL AND Pct_CORRES IS NOT NULL
GROUP BY marketTicker, origYear
HAVING sum_ls > 100000000
;
COMMIT;
 
UPDATE #GNM_PoolDistribution perf SET perf.Pct_RETAIL = chan.WAVG_RETAIL, perf.Pct_BROKER = chan.WAVG_BROKER, perf.Pct_CORRES = chan.WAVG_CORRES
FROM #GNM_OriginationDate_CHAN chan
WHERE 1=1
    AND year(perf.originationDate) = chan.origYear
    AND (perf.Pct_RETAIL IS NULL OR perf.Pct_BROKER IS NULL OR perf.Pct_CORRES IS NULL)
   -- AND perf.marketTicker = chan.marketTicker
;
COMMIT;

UPDATE #GNM_PoolDistribution SET Pct_RETAIL = 100.0
WHERE Pct_RETAIL > 100.0
;

UPDATE #GNM_PoolDistribution SET Pct_RETAIL = 0.0
WHERE Pct_RETAIL < 0.0
;

UPDATE #GNM_PoolDistribution SET Pct_BROKER = 100.0
WHERE Pct_BROKER > 100.0
;

UPDATE #GNM_PoolDistribution SET Pct_BROKER = 0.0
WHERE Pct_BROKER < 0.0
;

UPDATE #GNM_PoolDistribution SET Pct_CORRES = 100.0
WHERE Pct_CORRES > 100.0
;

UPDATE #GNM_PoolDistribution SET Pct_CORRES = 0.0
WHERE Pct_CORRES < 0.0
;

UPDATE #GNM_PoolDistribution SET Pct_RETAIL = Pct_RETAIL - ((Pct_RETAIL + Pct_BROKER + Pct_CORRES - 100.0) / 3.0), 
    Pct_BROKER = Pct_BROKER - ((Pct_RETAIL + Pct_BROKER + Pct_CORRES - 100.0) / 3.0), 
    Pct_CORRES = Pct_CORRES - ((Pct_RETAIL + Pct_BROKER + Pct_CORRES - 100.0) / 3.0)
WHERE abs(Pct_RETAIL + Pct_BROKER + Pct_CORRES - 100.0) > 0.0
;
COMMIT;

-- Number Units Distribution
DROP TABLE IF EXISTS #GNM_Unit_Dist;
SELECT
    issueId,
    asOf,
    sum(Pct_Single) as Pct_SINGLE_UNIT,
    sum(Pct_multiple) as Pct_MULTIPLE_UNIT
INTO #GNM_Unit_Dist
FROM
(
SELECT
    p.issueId,
    p.asOf,
    CASE WHEN distributionType IN ('1-UNIT') THEN percentRpb ELSE 0.0 END as Pct_Single,
    CASE WHEN distributionType IN ('2-4UN') THEN percentRpb ELSE 0.0 END as Pct_Multiple
FROM #GNM_PoolDistribution p
JOIN gnm.PIV_LoanDist d
    ON p.issueId = d.issueId
    AND p.asof = d.asOf
    AND distributionName = 'PROPERTY'
    AND subtype = 'ALL'
) t
GROUP BY issueId, asOf
;
COMMIT;

CREATE INDEX issueId_idx ON #GNM_Unit_Dist(issueId);
CREATE INDEX asOf_idx ON #GNM_Unit_Dist(asOf);
COMMIT;

UPDATE #GNM_Unit_Dist SET Pct_SINGLE_UNIT = NULL, Pct_MULTIPLE_UNIT = NULL WHERE abs(Pct_SINGLE_UNIT + Pct_MULTIPLE_UNIT - 100.0) > 15.0;
COMMIT;

UPDATE #GNM_PoolDistribution perf SET perf.Pct_SINGLE_UNIT = un.Pct_SINGLE_UNIT, perf.Pct_MULTIPLE_UNIT = un.Pct_MULTIPLE_UNIT
FROM #GNM_Unit_Dist un
WHERE perf.issueId = un.issueId 
    AND perf.asOf = un.asOf
;
COMMIT;

DROP TABLE IF EXISTS #GNM_MinDate_UNIT;
SELECT
    issueId,
    min(asOf) as asOf,
    cast(NULL as numeric(12, 2)) as Pct_SINGLE_UNIT,
    cast(NULL as numeric(12, 2)) as Pct_MULTIPLE_UNIT
INTO #GNM_MinDate_UNIT
FROM #GNM_Unit_Dist p
WHERE p.Pct_SINGLE_UNIT IS NOT NULL AND p.Pct_MULTIPLE_UNIT IS NOT NULL
GROUP BY issueId
;
COMMIT;

UPDATE #GNM_MinDate_UNIT s SET s.Pct_SINGLE_UNIT = d.Pct_SINGLE_UNIT, s.Pct_MULTIPLE_UNIT = d.Pct_MULTIPLE_UNIT
FROM #GNM_Unit_Dist d
WHERE s.issueId = d.issueId
    AND s.asOf = d.asOf
;

UPDATE #GNM_PoolDistribution perf SET perf.Pct_SINGLE_UNIT = s.Pct_SINGLE_UNIT, perf.Pct_MULTIPLE_UNIT = s.Pct_MULTIPLE_UNIT
FROM #GNM_MinDate_UNIT s
WHERE perf.issueId = s.issueId 
    AND (perf.Pct_SINGLE_UNIT IS NULL OR perf.Pct_MULTIPLE_UNIT IS NULL)
    AND perf.asOf <= s.asOf
;

DROP TABLE IF EXISTS #GNM_OriginationDate_UNIT;
SELECT
    year(originationDate) as origYear,
    sum(balance * Pct_SINGLE_UNIT) / sum(balance) as WAVG_Single,
    sum(balance * Pct_MULTIPLE_UNIT) / sum(balance) as WAVG_Multiple,
    sum(balance) as sum_ls
INTO #GNM_OriginationDate_UNIT
FROM #GNM_PoolDistribution
WHERE Pct_SINGLE_UNIT IS NOT NULL AND Pct_MULTIPLE_UNIT IS NOT NULL
GROUP BY origYear
HAVING sum_ls > 100000000
;
COMMIT;

UPDATE #GNM_PoolDistribution perf SET perf.Pct_SINGLE_UNIT = unit.WAVG_Single, perf.Pct_MULTIPLE_UNIT = unit.WAVG_Multiple
FROM #GNM_OriginationDate_UNIT unit
WHERE year(perf.originationDate) = unit.origYear
    AND (perf.Pct_SINGLE_UNIT IS NULL OR perf.Pct_MULTIPLE_UNIT IS NULL)
;
COMMIT;

UPDATE #GNM_PoolDistribution SET Pct_SINGLE_UNIT = 100.0
WHERE Pct_SINGLE_UNIT > 100.0
;

UPDATE #GNM_PoolDistribution SET Pct_SINGLE_UNIT = 0.0
WHERE Pct_SINGLE_UNIT < 0.0
;

UPDATE #GNM_PoolDistribution SET Pct_MULTIPLE_UNIT = 100.0
WHERE Pct_MULTIPLE_UNIT > 100.0
;

UPDATE #GNM_PoolDistribution SET Pct_MULTIPLE_UNIT = 0.0
WHERE Pct_MULTIPLE_UNIT < 0.0
;

COMMIT;

UPDATE #GNM_PoolDistribution SET Pct_SINGLE_UNIT = Pct_SINGLE_UNIT - ((Pct_SINGLE_UNIT + Pct_MULTIPLE_UNIT - 100.0) / 2.0), Pct_MULTIPLE_UNIT = Pct_MULTIPLE_UNIT - ((Pct_SINGLE_UNIT + Pct_MULTIPLE_UNIT - 100.0) / 2.0)
WHERE abs(Pct_SINGLE_UNIT + Pct_MULTIPLE_UNIT - 100.0) > 0.0
;
COMMIT;


-- FHA/VA Distribution
DROP TABLE IF EXISTS #GNM_Type_Dist;
SELECT
    marketTicker,
    issueId,
    asOf,
    sum(Pct_FHA) as Pct_FHA_TYPE,
    sum(Pct_VA) as Pct_VA_TYPE,
    sum(Pct_NON_FHA_VA) as Pct_NON_FHA_VA_TYPE
INTO #GNM_Type_Dist
FROM
(
SELECT
    p.marketTicker,
    p.issueId,
    p.asOf,
    CASE WHEN state IN ('FHA') THEN percentRpb ELSE 0.0 END as Pct_FHA,
    CASE WHEN state IN ('VA') THEN percentRpb ELSE 0.0 END as Pct_VA,
    CASE WHEN state IN ('PIH','RHS') THEN percentRpb ELSE 0.0 END as Pct_NON_FHA_VA
FROM #GNM_PoolDistribution p
JOIN gnm.PIV_FhaVaDist d
    ON p.issueId = d.issueId
    AND p.asof = d.asOf
) t
GROUP BY marketTicker, issueId, asOf
;
COMMIT;

CREATE INDEX issueId_idx ON #GNM_Type_Dist(issueId);
CREATE INDEX asOf_idx ON #GNM_Type_Dist(asOf);
COMMIT;

UPDATE #GNM_PoolDistribution perf SET perf.Pct_FHA = ty.Pct_FHA_TYPE, perf.Pct_VA = ty.Pct_VA_TYPE, perf.Pct_NON_FHA_VA = ty.Pct_NON_FHA_VA_TYPE
FROM #GNM_Type_Dist ty
WHERE perf.issueId = ty.issueId 
    AND perf.asOf = ty.asOf
;
COMMIT;

-- assume that we can populate missing VA data from FHA prior to 5/1/1999
UPDATE #GNM_PoolDistribution SET Pct_VA = 100.0 - Pct_FHA
WHERE 1=1
    AND asOf < '1999-05-01'
    AND Pct_FHA >= 0.0 AND Pct_FHA <= 100.0
    AND (Pct_VA = 0.0 OR Pct_VA IS NULL)
    AND marketTicker = 'GNSF'
;
COMMIT;

-- assume that we can populate missing VA data from FHA prior to 7/1/1999
UPDATE #GNM_PoolDistribution SET Pct_VA = 100.0 - Pct_FHA
WHERE 1=1
    AND asOf < '1999-07-01'
    AND Pct_FHA >= 0.0 AND Pct_FHA <= 100.0
    AND (Pct_VA = 0.0 OR Pct_VA IS NULL)
    AND marketTicker = 'G2SF'
;
COMMIT;

-- assume that we can populate missing FHA and VA data from FHA and VA prior to 9/1/2005
UPDATE #GNM_PoolDistribution SET Pct_NON_FHA_VA = 100.0 - Pct_FHA - Pct_VA
WHERE 1=1
    AND asOf < '2005-09-01' AND asOf >= '1999-07-01'
    AND Pct_FHA >= 0.0 AND Pct_FHA <= 100.0
    AND Pct_VA >= 0.0 AND Pct_VA <= 100.0
    AND (Pct_NON_FHA_VA = 0.0 OR Pct_NON_FHA_VA IS NULL)
    AND 100.0 - Pct_FHA - Pct_VA >= 0.0
;
COMMIT;


-- populate missing FHA/VA pools
DROP TABLE IF EXISTS #GNM_MinDate_TYPE;
SELECT
    issueId,
    min(asOf) as asOf,
    cast(NULL as numeric(12, 2)) as Pct_FHA,
    cast(NULL as numeric(12, 2)) as Pct_VA,
    cast(NULL as numeric(12, 2)) as Pct_NON_FHA_VA
INTO #GNM_MinDate_TYPE
FROM #GNM_PoolDistribution p
WHERE p.Pct_FHA IS NOT NULL AND p.Pct_VA IS NOT NULL AND Pct_NON_FHA_VA IS NOT NULL
GROUP BY issueId
;
COMMIT;

UPDATE #GNM_MinDate_TYPE s SET s.Pct_FHA = d.Pct_FHA, s.Pct_VA = d.Pct_VA, s.Pct_NON_FHA_VA = d.Pct_NON_FHA_VA
FROM #GNM_PoolDistribution d
WHERE s.issueId = d.issueId
    AND s.asOf = d.asOf
;

UPDATE #GNM_PoolDistribution perf SET perf.Pct_FHA = s.Pct_FHA, perf.Pct_VA = s.Pct_VA, perf.Pct_NON_FHA_VA = s.Pct_NON_FHA_VA
FROM #GNM_MinDate_TYPE s
WHERE perf.issueId = s.issueId 
    AND (perf.Pct_FHA IS NULL OR perf.Pct_VA IS NULL)
    AND perf.asOf <= s.asOf
;

DROP TABLE IF EXISTS #GNM_OriginationDate_TYPE;
SELECT
    year(originationDate) as origYear,
    sum(balance * Pct_FHA) / sum(balance) as WAVG_FHA,
    sum(balance * Pct_VA) / sum(balance) as WAVG_VA,
    sum(balance * Pct_NON_FHA_VA) / sum(balance) as WAVG_NON_FHA_VA,
    sum(balance) as sum_ls
INTO #GNM_OriginationDate_TYPE
FROM #GNM_PoolDistribution
WHERE Pct_FHA IS NOT NULL AND Pct_VA IS NOT NULL AND Pct_NON_FHA_VA IS NOT NULL
GROUP BY origYear
HAVING sum_ls > 100000000
;
COMMIT;

UPDATE #GNM_PoolDistribution perf SET perf.Pct_FHA = type.WAVG_FHA, perf.Pct_VA = type.WAVG_VA, perf.Pct_NON_FHA_VA = type.WAVG_NON_FHA_VA
FROM #GNM_OriginationDate_TYPE type
WHERE year(perf.originationDate) = type.origYear
    AND (perf.Pct_FHA IS NULL OR perf.Pct_VA IS NULL)
;
COMMIT;

UPDATE #GNM_PoolDistribution SET Pct_FHA = 100.0
WHERE Pct_FHA > 100.0
;

UPDATE #GNM_PoolDistribution SET Pct_FHA = 0.0
WHERE Pct_FHA < 0.0
;

UPDATE #GNM_PoolDistribution SET Pct_VA = 100.0
WHERE Pct_VA > 100.0
;

UPDATE #GNM_PoolDistribution SET Pct_VA = 0.0
WHERE Pct_VA < 0.0
;

UPDATE #GNM_PoolDistribution SET Pct_NON_FHA_VA = 100.0
WHERE Pct_NON_FHA_VA > 100.0
;

UPDATE #GNM_PoolDistribution SET Pct_NON_FHA_VA = 0.0
WHERE Pct_NON_FHA_VA < 0.0
;

COMMIT;

UPDATE #GNM_PoolDistribution SET Pct_FHA = avg_FHA, Pct_VA = avg_VA, Pct_NON_FHA_VA = avg_NON_FHA_VA
FROM (SELECT avg(Pct_FHA) as avg_FHA, avg(Pct_VA) as avg_VA, avg(Pct_NON_FHA_VA) as avg_NON_FHA_VA FROM #GNM_PoolDistribution WHERE Pct_FHA IS NOT NULL) t
WHERE Pct_FHA IS NULL OR Pct_VA IS NULL OR Pct_NON_FHA_VA IS NULL
;
COMMIT;

-- Normalize to 100%
UPDATE #GNM_PoolDistribution SET Pct_FHA = Pct_FHA - ((Pct_FHA + Pct_VA - 100.0) / 2.0), 
    Pct_VA = Pct_VA - ((Pct_FHA + Pct_VA - 100.0) / 2.0)
WHERE abs(Pct_FHA + Pct_VA + Pct_NON_FHA_VA - 100.0) > 0.01
    AND Pct_NON_FHA_VA = 0.0
;
COMMIT;

UPDATE #GNM_PoolDistribution SET Pct_FHA = Pct_FHA - ((Pct_FHA + Pct_NON_FHA_VA - 100.0) / 2.0), 
    Pct_NON_FHA_VA = Pct_NON_FHA_VA - ((Pct_FHA + Pct_NON_FHA_VA - 100.0) / 2.0)
WHERE abs(Pct_FHA + Pct_VA + Pct_NON_FHA_VA - 100.0) > 0.01
    AND Pct_VA = 0.0
;
COMMIT;

UPDATE #GNM_PoolDistribution SET Pct_FHA = Pct_FHA - ((Pct_FHA + Pct_VA + Pct_NON_FHA_VA - 100.0) / 3.0), 
    Pct_VA = Pct_VA - ((Pct_FHA + Pct_VA + Pct_NON_FHA_VA - 100.0) / 3.0), 
    Pct_NON_FHA_VA = Pct_NON_FHA_VA - ((Pct_FHA + Pct_VA + Pct_NON_FHA_VA - 100.0) / 3.0)
WHERE abs(Pct_FHA + Pct_VA + Pct_NON_FHA_VA - 100.0) > 0.01
;
COMMIT;

UPDATE #GNM_PoolDistribution SET Pct_FHA = 0.0, 
    Pct_VA = CASE WHEN Pct_VA > Pct_NON_FHA_VA THEN Pct_VA + Pct_FHA ELSE Pct_VA END,
    Pct_NON_FHA_VA = CASE WHEN Pct_VA <= Pct_NON_FHA_VA THEN Pct_NON_FHA_VA + Pct_FHA ELSE Pct_NON_FHA_VA END
WHERE Pct_FHA < 0.0
;

UPDATE #GNM_PoolDistribution SET Pct_FHA = CASE WHEN Pct_FHA > Pct_NON_FHA_VA THEN Pct_FHA + Pct_VA ELSE Pct_FHA END,
    Pct_VA = 0.0,
    Pct_NON_FHA_VA = CASE WHEN Pct_FHA <= Pct_NON_FHA_VA THEN Pct_NON_FHA_VA + Pct_VA ELSE Pct_NON_FHA_VA END
WHERE Pct_VA < 0.0
;

UPDATE #GNM_PoolDistribution SET Pct_FHA = CASE WHEN Pct_FHA > Pct_VA THEN Pct_FHA + Pct_NON_FHA_VA ELSE Pct_FHA END,
    Pct_VA = CASE WHEN Pct_FHA <= Pct_VA THEN Pct_VA + Pct_NON_FHA_VA ELSE Pct_VA END,
    Pct_NON_FHA_VA = 0.0
WHERE Pct_NON_FHA_VA < 0.0
;
COMMIT;



-- Tests

---- Time Series Tests

--SELECT 
--    marketTicker, 
--    originationDate, 
--    count(1), 
--    sum(balance), 
--    sum(balance * Pct_SINGLE_UNIT) / sum(CASE WHEN Pct_SINGLE_UNIT IS NULL THEN 0.0 ELSE balance END) as wavg_single,
--    sum(balance * Pct_MULTIPLE_UNIT) / sum(CASE WHEN Pct_MULTIPLE_UNIT IS NULL THEN 0.0 ELSE balance END) as wavg_multiple
--FROM #GNM_PoolDistribution 
--GROUP BY marketTicker, originationDate 
--ORDER BY originationDate
--;

--SELECT 
--    marketTicker, 
--    asOf, 
--    count(1), 
--    sum(balance), 
--    sum(balance * Pct_SINGLE_UNIT) / sum(CASE WHEN Pct_SINGLE_UNIT IS NULL THEN 0.0 ELSE balance END) as wavg_single,
--    sum(balance * Pct_MULTIPLE_UNIT) / sum(CASE WHEN Pct_MULTIPLE_UNIT IS NULL THEN 0.0 ELSE balance END) as wavg_multiple
--FROM #GNM_PoolDistribution 
--GROUP BY marketTicker, asOf 
--ORDER BY asOf
--;

--SELECT 
--    marketTicker, 
--    originationDate, 
--    count(1), 
--    sum(balance), 
--    sum(balance * Pct_FHA) / sum(CASE WHEN Pct_FHA IS NULL THEN 0.0 ELSE balance END) as wavg_fha,
--    sum(balance * Pct_VA) / sum(CASE WHEN Pct_VA IS NULL THEN 0.0 ELSE balance END) as wavg_va,
--    sum(balance * Pct_NON_FHA_VA) / sum(CASE WHEN Pct_NON_FHA_VA IS NULL THEN 0.0 ELSE balance END) as wavg_non_fha_va
--FROM #GNM_PoolDistribution 
--GROUP BY marketTicker, originationDate 
--ORDER BY originationDate
--;

--SELECT 
--    marketTicker, 
--    asOf, 
--    count(1), 
--    sum(balance), 
--    sum(balance * Pct_FHA) / sum(CASE WHEN Pct_FHA IS NULL THEN 0.0 ELSE balance END) as wavg_fha,
--    sum(balance * Pct_VA) / sum(CASE WHEN Pct_VA IS NULL THEN 0.0 ELSE balance END) as wavg_va,
--    sum(balance * Pct_NON_FHA_VA) / sum(CASE WHEN Pct_NON_FHA_VA IS NULL THEN 0.0 ELSE balance END) as wavg_non_fha_va
--FROM #GNM_PoolDistribution 
--GROUP BY marketTicker, asOf 
--ORDER BY asOf
--;

--SELECT 
--    marketTicker, 
--    originationDate, 
--    count(1), 
--    sum(balance), 
--    sum(balance * Pct_RETAIL) / sum(CASE WHEN Pct_RETAIL IS NULL THEN 0.0 ELSE balance END) as wavg_retail,
--    sum(balance * Pct_BROKER) / sum(CASE WHEN Pct_BROKER IS NULL THEN 0.0 ELSE balance END) as wavg_broker,
--    sum(balance * Pct_CORRES) / sum(CASE WHEN Pct_CORRES IS NULL THEN 0.0 ELSE balance END) as wavg_corres
--FROM #GNM_PoolDistribution 
--GROUP BY marketTicker, originationDate 
--ORDER BY originationDate
--;

--SELECT 
--    marketTicker, 
--    asOf, 
--    count(1), 
--    sum(balance), 
--    sum(balance * Pct_RETAIL) / sum(CASE WHEN Pct_RETAIL IS NULL THEN 0.0 ELSE balance END) as wavg_retail,
--    sum(balance * Pct_BROKER) / sum(CASE WHEN Pct_BROKER IS NULL THEN 0.0 ELSE balance END) as wavg_broker,
--    sum(balance * Pct_CORRES) / sum(CASE WHEN Pct_CORRES IS NULL THEN 0.0 ELSE balance END) as wavg_corres
--FROM #GNM_PoolDistribution 
--GROUP BY marketTicker, asOf 
--ORDER BY asOf
--;

--SELECT 
--    marketTicker, 
--    originationDate, 
--    count(1), 
--    sum(balance), 
--    sum(balance * Pct_CURRENT) / sum(CASE WHEN Pct_CURRENT IS NULL THEN 0.0 ELSE balance END) as wavg_current,
--    sum(balance * Pct_DELQ30p) / sum(CASE WHEN Pct_DELQ30p IS NULL THEN 0.0 ELSE balance END) as wavg_delq30p,
--    sum(balance * Pct_DELQ60p) / sum(CASE WHEN Pct_DELQ60p IS NULL THEN 0.0 ELSE balance END) as wavg_delq60p,
--    sum(balance * Pct_DELQ90p) / sum(CASE WHEN Pct_DELQ90p IS NULL THEN 0.0 ELSE balance END) as wavg_delq90p
--FROM #GNM_PoolDistribution 
--GROUP BY marketTicker, originationDate 
--ORDER BY originationDate
--;

--SELECT 
--    marketTicker, 
--    asOf, 
--    count(1), 
--    sum(balance), 
--    sum(balance * Pct_CURRENT) / sum(CASE WHEN Pct_CURRENT IS NULL THEN 0.0 ELSE balance END) as wavg_current,
--    sum(balance * Pct_DELQ30p) / sum(CASE WHEN Pct_DELQ30p IS NULL THEN 0.0 ELSE balance END) as wavg_delq30p,
--    sum(balance * Pct_DELQ60p) / sum(CASE WHEN Pct_DELQ60p IS NULL THEN 0.0 ELSE balance END) as wavg_delq60p,
--    sum(balance * Pct_DELQ90p) / sum(CASE WHEN Pct_DELQ90p IS NULL THEN 0.0 ELSE balance END) as wavg_delq90p
--FROM #GNM_PoolDistribution 
--GROUP BY marketTicker, asOf 
--ORDER BY asOf
--;

--SELECT 
--    marketTicker, 
--    originationDate, 
--    count(1), 
--    sum(balance), 
--    sum(balance * Pct_PURCH) / sum(CASE WHEN Pct_PURCH IS NULL THEN 0.0 ELSE balance END) as wavg_purch,
--    sum(balance * Pct_REFI) / sum(CASE WHEN Pct_REFI IS NULL THEN 0.0 ELSE balance END) as wavg_refi
----    sum(balance * Pct_HMOD) / sum(CASE WHEN Pct_HMOD IS NULL THEN 0.0 ELSE balance END) as wavg_hmod,
----    sum(balance * Pct_NHMOD) / sum(CASE WHEN Pct_NHMOD IS NULL THEN 0.0 ELSE balance END) as wavg_nhmod,
----    sum(balance * Pct_NA) / sum(CASE WHEN Pct_NA IS NULL THEN 0.0 ELSE balance END) as wavg_na
--FROM #GNM_PoolDistribution 
--GROUP BY marketTicker, originationDate 
--ORDER BY originationDate
--;

--SELECT 
--    marketTicker, 
--    asOf, 
--    count(1), 
--    sum(balance), 
--    sum(balance * Pct_PURCH) / sum(CASE WHEN Pct_PURCH IS NULL THEN 0.0 ELSE balance END) as wavg_purch,
--    sum(balance * Pct_REFI) / sum(CASE WHEN Pct_REFI IS NULL THEN 0.0 ELSE balance END) as wavg_refi
----    sum(balance * Pct_HMOD) / sum(CASE WHEN Pct_HMOD IS NULL THEN 0.0 ELSE balance END) as wavg_hmod,
----    sum(balance * Pct_NHMOD) / sum(CASE WHEN Pct_NHMOD IS NULL THEN 0.0 ELSE balance END) as wavg_nhmod,
----    sum(balance * Pct_NA) / sum(CASE WHEN Pct_NA IS NULL THEN 0.0 ELSE balance END) as wavg_na
--FROM #GNM_PoolDistribution 
--GROUP BY marketTicker, asOf 
--ORDER BY asOf
--;

----------------------------------------------------------------------------------------------
-- Check to see if Pools have (Pct_PURCH IS NULL OR Pct_PURCH < 0.0 OR Pct_PURCH > 100.0) AND originationDate >= '1994-01-01'
----------------------------------------------------------------------------------------------
        declare   @cnt int
        SELECT
            @cnt =  count(1)
        FROM #GNM_PoolDistribution WHERE (Pct_PURCH IS NULL OR Pct_PURCH < 0.0 OR Pct_PURCH > 100.0) AND originationDate >= '1994-01-01'

        if (@cnt > 0)
        BEGIN
            RAISERROR 99999 'GNM Pools with INVALID VALUE for Pct_PURCH PoolCount : %1!', @cnt
            RETURN
        END

----------------------------------------------------------------------------------------------
-- Check to see if Pools have (Pct_REFI IS NULL OR Pct_REFI < 0.0 OR Pct_REFI > 100.0) AND originationDate >= '1994-01-01'
----------------------------------------------------------------------------------------------

        SELECT
            @cnt =  count(1)
        FROM #GNM_PoolDistribution WHERE (Pct_REFI IS NULL OR Pct_REFI < 0.0 OR Pct_REFI > 100.0) AND originationDate >= '1994-01-01'

        if (@cnt > 0)
        BEGIN
            RAISERROR 99999 'GNM Pools with INVALID VALUE for Pct_REFI PoolCount : %1!', @cnt
            RETURN
        END

----------------------------------------------------------------------------------------------
-- Check to see if Pools have abs(Pct_PURCH + Pct_REFI - 100.0) > 0.1
----------------------------------------------------------------------------------------------

        SELECT
            @cnt =  count(1)
        FROM #GNM_PoolDistribution WHERE abs(Pct_PURCH + Pct_REFI - 100.0) > 0.1

        if (@cnt > 0)
        BEGIN
            RAISERROR 99999 'GNM Pools with Purpose not summing to 100 PoolCount : %1!', @cnt
            RETURN
        END
        
----------------------------------------------------------------------------------------------
-- Check to see if Pools have asOf >= '2005-12-01' AND (Pct_CURRENT IS NULL OR Pct_CURRENT < 0.0 OR Pct_CURRENT > 100.0)
----------------------------------------------------------------------------------------------

        SELECT
            @cnt =  count(1)
        FROM #GNM_PoolDistribution WHERE asOf >= '2005-12-01' AND (Pct_CURRENT IS NULL OR Pct_CURRENT < 0.0 OR Pct_CURRENT > 100.0)

        if (@cnt > 0)
        BEGIN
            RAISERROR 99999 'GNM Pools with INVALID VALUE for Pct_CURRENT PoolCount : %1!', @cnt
            RETURN
        END

----------------------------------------------------------------------------------------------
-- Check to see if Pools have asOf >= '2005-12-01' AND (Pct_DELQ30p IS NULL OR Pct_DELQ30p < 0.0 OR Pct_DELQ30p > 100.0)
----------------------------------------------------------------------------------------------

        SELECT
            @cnt =  count(1)
        FROM #GNM_PoolDistribution WHERE asOf >= '2005-12-01' AND (Pct_DELQ30p IS NULL OR Pct_DELQ30p < 0.0 OR Pct_DELQ30p > 100.0)

        if (@cnt > 0)
        BEGIN
            RAISERROR 99999 'GNM Pools with INVALID VALUE for Pct_DELQ30p PoolCount : %1!', @cnt
            RETURN
        END

----------------------------------------------------------------------------------------------
-- Check to see if Pools have asOf >= '2005-12-01' AND (Pct_DELQ60p IS NULL OR Pct_DELQ60p < 0.0 OR Pct_DELQ60p > 100.0)
----------------------------------------------------------------------------------------------

        SELECT
            @cnt =  count(1)
        FROM #GNM_PoolDistribution WHERE asOf >= '2005-12-01' AND (Pct_DELQ60p IS NULL OR Pct_DELQ60p < 0.0 OR Pct_DELQ60p > 100.0)

        if (@cnt > 0)
        BEGIN
            RAISERROR 99999 'GNM Pools with INVALID VALUE for Pct_DELQ60p PoolCount : %1!', @cnt
            RETURN
        END

----------------------------------------------------------------------------------------------
-- Check to see if Pools have asOf >= '2005-12-01' AND (Pct_DELQ90p IS NULL OR Pct_DELQ90p < 0.0 OR Pct_DELQ90p > 100.0)
----------------------------------------------------------------------------------------------

        SELECT
            @cnt =  count(1)
        FROM #GNM_PoolDistribution WHERE asOf >= '2005-12-01' AND (Pct_DELQ90p IS NULL OR Pct_DELQ90p < 0.0 OR Pct_DELQ90p > 100.0)

        if (@cnt > 0)
        BEGIN
            RAISERROR 99999 'GNM Pools with INVALID VALUE for Pct_DELQ90p PoolCount : %1!', @cnt
            RETURN
        END

----------------------------------------------------------------------------------------------
-- Check to see if Pools have abs(Pct_CURRENT + Pct_DELQ30p - 100.0) > 0.1
----------------------------------------------------------------------------------------------

        SELECT
            @cnt =  count(1)
        FROM #GNM_PoolDistribution WHERE abs(Pct_CURRENT + Pct_DELQ30p - 100.0) > 0.1

        if (@cnt > 0)
        BEGIN
            RAISERROR 99999 'GNM Pools with Delinquency Status not summing to 100 PoolCount : %1!', @cnt
            RETURN
        END

----------------------------------------------------------------------------------------------
-- Check to see if Pools have (Pct_RETAIL IS NULL OR Pct_RETAIL < 0.0 OR Pct_RETAIL > 100.0) AND originationDate >= '2008-01-01'
----------------------------------------------------------------------------------------------

        SELECT
            @cnt =  count(1)
        FROM #GNM_PoolDistribution WHERE (Pct_RETAIL IS NULL OR Pct_RETAIL < 0.0 OR Pct_RETAIL > 100.0) AND originationDate >= '2008-01-01'

        if (@cnt > 0)
        BEGIN
            RAISERROR 99999 'GNM Pools with INVALID VALUE for Pct_RETAIL PoolCount : %1!', @cnt
            RETURN
        END

----------------------------------------------------------------------------------------------
-- Check to see if Pools have (Pct_BROKER IS NULL OR Pct_BROKER < 0.0 OR Pct_BROKER > 100.0) AND originationDate >= '2008-01-01'
----------------------------------------------------------------------------------------------

        SELECT
            @cnt =  count(1)
        FROM #GNM_PoolDistribution WHERE (Pct_BROKER IS NULL OR Pct_BROKER < 0.0 OR Pct_BROKER > 100.0) AND originationDate >= '2008-01-01'

        if (@cnt > 0)
        BEGIN
            RAISERROR 99999 'GNM Pools with INVALID VALUE for Pct_BROKER PoolCount : %1!', @cnt
            RETURN
        END

----------------------------------------------------------------------------------------------
-- Check to see if Pools have (Pct_CORRES IS NULL OR Pct_CORRES < 0.0 OR Pct_CORRES > 100.0) AND originationDate >= '2008-01-01'
----------------------------------------------------------------------------------------------

        SELECT
            @cnt =  count(1)
        FROM #GNM_PoolDistribution WHERE (Pct_CORRES IS NULL OR Pct_CORRES < 0.0 OR Pct_CORRES > 100.0) AND originationDate >= '2008-01-01'

        if (@cnt > 0)
        BEGIN
            RAISERROR 99999 'GNM Pools with INVALID VALUE for Pct_CORRES PoolCount : %1!', @cnt
            RETURN
        END

----------------------------------------------------------------------------------------------
-- Check to see if Pools have abs(Pct_RETAIL + Pct_BROKER + Pct_CORRES - 100.0) > 0.1
----------------------------------------------------------------------------------------------

        SELECT
            @cnt =  count(1)
        FROM #GNM_PoolDistribution WHERE abs(Pct_RETAIL + Pct_BROKER + Pct_CORRES - 100.0) > 0.1

        if (@cnt > 0)
        BEGIN
            RAISERROR 99999 'GNM Pools with Channel not summing to 100 PoolCount : %1!', @cnt
            RETURN
        END
        
----------------------------------------------------------------------------------------------
-- Check to see if Pools have (Pct_SINGLE_UNIT IS NULL OR Pct_SINGLE_UNIT < 0.0 OR Pct_SINGLE_UNIT > 100.0) AND originationDate >= '1994-01-01'
----------------------------------------------------------------------------------------------

        SELECT
            @cnt =  count(1)
        FROM #GNM_PoolDistribution WHERE (Pct_SINGLE_UNIT IS NULL OR Pct_SINGLE_UNIT < 0.0 OR Pct_SINGLE_UNIT > 100.0) AND originationDate >= '1994-01-01'

        if (@cnt > 0)
        BEGIN
            RAISERROR 99999 'GNM Pools with INVALID VALUE for Pct_SINGLE_UNIT PoolCount : %1!', @cnt
            RETURN
        END

----------------------------------------------------------------------------------------------
-- Check to see if Pools have (Pct_MULTIPLE_UNIT IS NULL OR Pct_MULTIPLE_UNIT < 0.0 OR Pct_MULTIPLE_UNIT > 100.0) AND originationDate >= '1994-01-01'
----------------------------------------------------------------------------------------------

        SELECT
            @cnt =  count(1)
        FROM #GNM_PoolDistribution WHERE (Pct_MULTIPLE_UNIT IS NULL OR Pct_MULTIPLE_UNIT < 0.0 OR Pct_MULTIPLE_UNIT > 100.0) AND originationDate >= '1994-01-01'

        if (@cnt > 0)
        BEGIN
            RAISERROR 99999 'GNM Pools with INVALID VALUE for Pct_MULTIPLE_UNIT PoolCount : %1!', @cnt
            RETURN
        END

----------------------------------------------------------------------------------------------
-- Check to see if Pools have abs(Pct_SINGLE_UNIT + Pct_MULTIPLE_UNIT - 100.0) > 0.1
----------------------------------------------------------------------------------------------

        SELECT
            @cnt =  count(1)
        FROM #GNM_PoolDistribution WHERE abs(Pct_SINGLE_UNIT + Pct_MULTIPLE_UNIT - 100.0) > 0.1

        if (@cnt > 0)
        BEGIN
            RAISERROR 99999 'GNM Pools with Units not summing to 100 PoolCount : %1!', @cnt
            RETURN
        END

----------------------------------------------------------------------------------------------
-- Check to see if Pools have Pct_FHA IS NULL OR Pct_FHA < 0.0 OR Pct_FHA > 100.0
----------------------------------------------------------------------------------------------

        SELECT
            @cnt =  count(1)
        FROM #GNM_PoolDistribution WHERE Pct_FHA IS NULL OR Pct_FHA < 0.0 OR Pct_FHA > 100.0

        if (@cnt > 0)
        BEGIN
            RAISERROR 99999 'GNM Pools with INVALID VALUE for Pct_FHA PoolCount : %1!', @cnt
            RETURN
        END

----------------------------------------------------------------------------------------------
-- Check to see if Pools have Pct_VA IS NULL OR Pct_VA < 0.0 OR Pct_VA > 100.0
----------------------------------------------------------------------------------------------

        SELECT
            @cnt =  count(1)
        FROM #GNM_PoolDistribution WHERE Pct_VA IS NULL OR Pct_VA < 0.0 OR Pct_VA > 100.0

        if (@cnt > 0)
        BEGIN
            RAISERROR 99999 'GNM Pools with INVALID VALUE for Pct_VA PoolCount : %1!', @cnt
            RETURN
        END

----------------------------------------------------------------------------------------------
-- Check to see if Pools have Pct_NON_FHA_VA IS NULL OR Pct_NON_FHA_VA < 0.0 OR Pct_NON_FHA_VA > 100.0
----------------------------------------------------------------------------------------------

        SELECT
            @cnt =  count(1)
        FROM #GNM_PoolDistribution WHERE Pct_NON_FHA_VA IS NULL OR Pct_NON_FHA_VA < 0.0 OR Pct_NON_FHA_VA > 100.0

        if (@cnt > 0)
        BEGIN
            RAISERROR 99999 'GNM Pools with INVALID VALUE for Pct_NON_FHA_VA PoolCount : %1!', @cnt
            RETURN
        END

----------------------------------------------------------------------------------------------
-- Check to see if Pools have abs(Pct_FHA + Pct_VA + Pct_NON_FHA_VA - 100.0) > 0.1
----------------------------------------------------------------------------------------------

        SELECT
           @cnt =  count(1)
        FROM #GNM_PoolDistribution WHERE abs(Pct_FHA + Pct_VA + Pct_NON_FHA_VA - 100.0) > 0.1

        if (@cnt > 0)
        BEGIN
            RAISERROR 99999 'GNM Pools with Type not summing to 100 PoolCount : %1!', @cnt
            RETURN
        END
        
-- End Tests



-- Load Data into Scale Tables
DELETE FROM scale.GNM_PoolDistribution
FROM scale.GNM_PoolDistribution spd, #GNM_PoolDistribution pd
WHERE 1=1
    AND spd.issueId = pd.issueId
    AND spd.asOf = pd.asOf
    AND pd.marketTicker IN (SELECT tickerName FROM #ticker)
    AND spd.asOf >= (SELECT asOf from #tmp_asOf)
;

INSERT INTO scale.GNM_PoolDistribution (issueId, asOf, percentPURP_PURCH, percentPURP_REFI, percentCHANNEL_RETAIL, percentCHANNEL_BROKER, percentCHANNEL_CORRES, percentUNIT_SINGLE, percentUNIT_MULTIPLE, percentCURRENT, percentDELQ30plus, percentDELQ60plus, percentDELQ90plus, percentTYPE_FHA, percentTYPE_VA, percentTYPE_OTHER)
SELECT
    issueId, 
    asOf,  
    Pct_PURCH, 
    Pct_REFI, 
    Pct_RETAIL, 
    Pct_BROKER, 
    Pct_CORRES, 
    Pct_SINGLE_UNIT, 
    Pct_MULTIPLE_UNIT,
    Pct_CURRENT,
    Pct_DELQ30p,
    Pct_DELQ60p,
    Pct_DELQ90p,
    Pct_FHA,
    Pct_VA,
    Pct_NON_FHA_VA
FROM #GNM_PoolDistribution
WHERE marketTicker IN (SELECT tickerName FROM #ticker)
    AND asOf >= (SELECT asOf from #tmp_asOf)
;
