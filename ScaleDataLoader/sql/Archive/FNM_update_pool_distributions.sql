-- Fannie Conventional
-- Pool Level
-- Part 2 of 6
-- Script to update distribution data
-- Updates Occupancy, Purpose, Delinquency, Channel, HARPed

-- Before execute the script, need to set the dates to run for
DROP TABLE IF EXISTS #tmp_asOf;
SELECT CAST('#####ASOF#####' AS DATE) asOf INTO #tmp_asOf
--SELECT CAST ('1994-02-01' AS DATE) asOf INTO #tmp_asOf
;
-- Before execute the script, need to set the version to run for
DROP TABLE IF EXISTS #tmp_version;
SELECT CAST ('2.50' AS varchar(5)) version INTO #tmp_version
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


-- Create Pool Historical Data
DROP TABLE IF EXISTS #FNM_PoolDistribution;
SELECT
    ph.marketTicker,
    ph.issueId,
    ph.originationDate,
    ph.asOf,
    sf.wala,
    ph.origFICO,
    ph.origLTV,
    oltvBucket = case
                    when ph.origLTV < 10 THEN 10
                    when ph.origLTV >= 140 THEN 150
                    else convert(int, ph.origLTV / 10) * 10 + 10
                    end,
	walaBucket = case 
                    when sf.wala <= 1 THEN 1
                    when sf.wala <= 2 THEN 2
                    when sf.wala <= 3 THEN 3
                    when sf.wala <= 4 THEN 4
                    when sf.wala <= 5 THEN 5
                    when sf.wala <= 6 THEN 6
                    when sf.wala >= 190 THEN 200
                    else convert(int, sf.wala / 10) * 10 + 10
                    end,
	ficoBucket = case 
                    when ph.origFICO < 500 THEN 500
                    when ph.origFICO >= 800 THEN 820
                    else convert(int, ph.origFICO / 20, 0) * 20 + 20
                    end,
    ph.balance,
    cast(NULL as numeric(6, 3)) as Pct_HARPed,
    cast(NULL as numeric(6, 3)) as Est_Pct_HARPed,
    cast(NULL as numeric(6, 3)) as Pct_MtgIns,
    cast(NULL as numeric(6, 3)) as Pct_OWNER,
    cast(NULL as numeric(6, 3)) as Pct_2ND,
    cast(NULL as numeric(6, 3)) as Pct_INV,
    cast(NULL as numeric(6, 3)) as Pct_PURCH,
    cast(NULL as numeric(6, 3)) as Pct_REFI,
    cast(NULL as numeric(6, 3)) as Pct_RETAIL,
    cast(NULL as numeric(6, 3)) as Pct_BROKER,
    cast(NULL as numeric(6, 3)) as Pct_CORRES,
    cast(NULL as numeric(6, 3)) as Pct_SINGLE_UNIT,
    cast(NULL as numeric(6, 3)) as Pct_MULTIPLE_UNIT
INTO #FNM_PoolDistribution
FROM scale.FNM_PoolHist ph
JOIN #ticker tk
    ON ph.marketTicker = tk.tickerName
JOIN fnm.secFactor sf
    ON ph.issueId = sf.issueId
    AND ph.asOf = sf.asOf
WHERE 1=1
    AND ph.asOf >= (select dateadd(month, -12, asOf) as asOf from #tmp_asOf)
;
COMMIT;

CREATE HG INDEX issueId_idx ON #FNM_PoolDistribution(issueId);
CREATE LF INDEX asOf_idx ON #FNM_PoolDistribution(asOf);
CREATE LF INDEX ticker_idx ON #FNM_PoolDistribution(marketTicker);
COMMIT;

-- Percent HARPed
DROP TABLE IF EXISTS #FNM_Pct_HARP;
SELECT
    pd.issueID,
    pd.asOf,
    sum(sl.percentHARPed * slh.balance) / sum(CASE WHEN sl.percentHARPed IS NULL THEN 0.0 ELSE slh.balance END) as pctHARPed
INTO #FNM_Pct_HARP
FROM #FNM_PoolDistribution pd
JOIN fnm.PIV_Loan cl
    ON pd.issueId = cl.issueId
JOIN scale.FNM_Loan_dev sl
    ON cl.loanSeqNum = sl.loanSeqNum
JOIN scale.FNM_LoanHist slh
    ON cl.loanseqNum = slh.loanSeqNum
    AND pd.asOf = slh.asOf
WHERE sl.percentHARPed IS NOT NULL
    AND sl.version = (select version from #tmp_version)
GROUP BY pd.issueID, pd.asOf
HAVING sum(slh.balance) > 0.01
;
COMMIT;

UPDATE #FNM_PoolDistribution perf SET perf.Pct_HARPed = ph.pctHARPed
FROM #FNM_Pct_HARP ph
WHERE perf.issueId = ph.issueId
AND perf.asof = ph.asof
;
COMMIT;


UPDATE #FNM_PoolDistribution SET Pct_HARPed = 0.0 WHERE asOf < '2009-06-01' AND Pct_HARPed IS NULL;
COMMIT;

UPDATE #FNM_PoolDistribution SET Pct_HARPed = 0.0 WHERE originationDate < '2009-06-01' AND Pct_HARPed IS NULL;
COMMIT;

UPDATE #FNM_PoolDistribution SET Pct_HARPed = 100.0 WHERE marketTicker IN ('FNCQ30','FNCR') AND Pct_HARPed IS NULL;
COMMIT;

UPDATE #FNM_PoolDistribution SET Pct_HARPed = 0.0 WHERE marketTicker IN ('FNCK') AND Pct_HARPed IS NULL;
COMMIT;


-- Create AsOf Date HARPed Pct Estimates using FHL Pool Data
DROP TABLE IF EXISTS #FHL_AsOf_HARPedPctBuckets;
SELECT
    d.asOf,
    oltvBucket = case
                    when origLTV < 10 THEN 10
                    when origLTV >= 140 THEN 150
                    else convert(int, origLTV / 10) * 10 + 10
                    end,
	walaBucket = case 
                    when wala <= 1 THEN 1
                    when wala <= 2 THEN 2
                    when wala <= 3 THEN 3
                    when wala <= 4 THEN 4
                    when wala <= 5 THEN 5
                    when wala <= 6 THEN 6
                    when wala >= 190 THEN 200
                    else convert(int, wala / 10) * 10 + 10
                    end,
	ficoBucket = case 
                    when origFICO < 500 THEN 500
                    when origFICO >= 800 THEN 820
                    else convert(int, origFICO / 20) * 20 + 20
                    end,
    sum(percentHARPed * h.balance) / sum(h.balance) as Est_Pct_HARPed
INTO #FHL_AsOf_HARPedPctBuckets
FROM scale.FHL_PoolDistribution d
JOIN scale.FHL_PoolHist h
    ON h.issueId = d.issueId
    AND h.asof = d.asof
JOIN fhl.secFactor s
    ON s.issueId = d.issueId
    AND s.asof = d.asof
WHERE 1=1
    AND marketTicker = 'FGLMC'
    AND h.asof >= '2009-06-01'
    AND h.originationDate >= '2009-06-01'
GROUP BY d.asOf, oltvBucket, walaBucket, ficoBucket
ORDER BY d.asOf, oltvBucket, walaBucket, ficoBucket
;
COMMIT;


-- Update the HARPed Pct Estimates
UPDATE #FNM_PoolDistribution SET Est_Pct_HARPed = 0.0 WHERE asOf < '2009-06-01' AND Est_Pct_HARPed IS NULL;
COMMIT;

UPDATE #FNM_PoolDistribution SET Est_Pct_HARPed = 0.0 WHERE originationDate < '2009-06-01' AND Est_Pct_HARPed IS NULL;
COMMIT;

UPDATE #FNM_PoolDistribution SET Est_Pct_HARPed = 100.0 WHERE marketTicker IN ('FNCQ30','FNCR') AND Est_Pct_HARPed IS NULL;
COMMIT;

UPDATE #FNM_PoolDistribution SET Est_Pct_HARPed = 0.0 WHERE marketTicker IN ('FNCK') AND Est_Pct_HARPed IS NULL;
COMMIT;

-- Update the HARPed Pct Estimates
UPDATE #FNM_PoolDistribution pd SET 
    pd.Est_Pct_HARPed = b.Est_Pct_HARPed
FROM #FHL_AsOf_HARPedPctBuckets b
WHERE pd.asOf = b.asOf
    AND pd.oltvBucket = b.oltvBucket
    AND pd.walaBucket = b.walaBucket
    AND pd.ficoBucket = b.ficoBucket
    AND pd.Est_Pct_HARPed IS NULL
;
COMMIT;

-- Create AsOf Year HARPed Pct Estimates using FHL Pool Data
DROP TABLE IF EXISTS #FHL_Avg_HARPedPctBuckets;
SELECT
    year(d.asOf) as asOfYear,
    oltvBucket = case
                    when origLTV < 10 THEN 10
                    when origLTV >= 140 THEN 150
                    else convert(int, origLTV / 10) * 10 + 10
                    end,
	walaBucket = case 
                    when wala <= 1 THEN 1
                    when wala <= 2 THEN 2
                    when wala <= 3 THEN 3
                    when wala <= 4 THEN 4
                    when wala <= 5 THEN 5
                    when wala <= 6 THEN 6
                    when wala >= 190 THEN 200
                    else convert(int, wala / 10) * 10 + 10
                    end,
	ficoBucket = case 
                    when origFICO < 500 THEN 500
                    when origFICO >= 800 THEN 820
                    else convert(int, origFICO / 20) * 20 + 20
                    end,
    sum(percentHARPed * h.balance) / sum(h.balance) as Est_Pct_HARPed
INTO #FHL_Avg_HARPedPctBuckets
FROM scale.FHL_PoolDistribution d
JOIN scale.FHL_PoolHist h
    ON h.issueId = d.issueId
    AND h.asof = d.asof
JOIN fhl.secFactor s
    ON s.issueId = d.issueId
    AND s.asof = d.asof
WHERE 1=1
    AND marketTicker = 'FGLMC'
    AND h.asof >= '2009-06-01'
    AND h.originationDate >= '2009-06-01'
GROUP BY asOfYear, oltvBucket, walaBucket, ficoBucket
ORDER BY asOfYear, oltvBucket, walaBucket, ficoBucket
;
COMMIT;

-- Update the HARPed Pct Estimates (from Avg)
UPDATE #FNM_PoolDistribution pd SET 
    pd.Est_Pct_HARPed = b.Est_Pct_HARPed
FROM #FHL_Avg_HARPedPctBuckets b
WHERE year(pd.asOf) = asOfYear
    AND pd.oltvBucket = b.oltvBucket
    AND pd.walaBucket = b.walaBucket
    AND pd.ficoBucket = b.ficoBucket
    AND pd.Est_Pct_HARPed IS NULL
;
COMMIT;

-- Update the HARPed Pct Estimates from Simple Avg by Year
DROP TABLE IF EXISTS #FHL_Simple_Avg_HARPedPctBuckets;
SELECT
    year(d.asOf) as asOfYear,
    sum(percentHARPed * h.balance) / sum(h.balance) as Est_Pct_HARPed
INTO #FHL_Simple_Avg_HARPedPctBuckets
FROM scale.FHL_PoolDistribution d
JOIN scale.FHL_PoolHist h
    ON h.issueId = d.issueId
    AND h.asof = d.asof
JOIN fhl.secFactor s
    ON s.issueId = d.issueId
    AND s.asof = d.asof
WHERE 1=1
    AND marketTicker = 'FGLMC'
    AND h.asof >= '2009-06-01'
    AND h.originationDate >= '2009-06-01'
GROUP BY asOfYear
ORDER BY asOfYear
;
COMMIT;

-- Update the HARPed Pct Estimates (from Simple Avg)
UPDATE #FNM_PoolDistribution pd SET 
    pd.Est_Pct_HARPed = b.Est_Pct_HARPed
FROM #FHL_Simple_Avg_HARPedPctBuckets b
WHERE year(pd.asOf) = asOfYear
    AND pd.Est_Pct_HARPed IS NULL
;
COMMIT;


-- Percent Mortgage Insurance
-- TODO: Estimate from Freddie Pool Data if required

-- Occupancy Distribution
DROP TABLE IF EXISTS #FNM_Occ_Dist;
SELECT
    issueId,
    asOf,
    sum(Pct_OWNER) as Pct_OWNER,
    sum(Pct_2ND) as Pct_2ND,
    sum(Pct_INV) as Pct_INV,
    Pct_OWNER + Pct_2ND + Pct_INV as Pct_Total
INTO #FNM_Occ_Dist
FROM
(
SELECT
    p.issueId,
    p.asOf,
    CASE WHEN distributionType IN ('OWNER') THEN percentRpb ELSE 0.0 END as Pct_OWNER,
    CASE WHEN distributionType IN ('2ND','N/A') THEN percentRpb ELSE 0.0 END as Pct_2ND,
    CASE WHEN distributionType IN ('INV') THEN percentRpb ELSE 0.0 END as Pct_INV
FROM #FNM_PoolDistribution p
JOIN fnm.SecMaxAsOf s 
    ON p.issueID = s.issueID
    AND p.asOF = s.factorASOf
JOIN fnm.OccupancyDist occ
    ON p.issueId = occ.issueId
    AND s.occupancyAsOf = occ.asOf
--WHERE p.asOf >= '2003-07-01'
) t
GROUP BY issueId, asOf
;
COMMIT;

CREATE HG INDEX issueId_idx ON #FNM_Occ_Dist(issueId);
CREATE LF INDEX asOf_idx ON #FNM_Occ_Dist(asOf);
COMMIT;

UPDATE #FNM_PoolDistribution perf SET perf.Pct_OWNER = occ.Pct_OWNER, perf.Pct_2ND = occ.Pct_2ND, perf.Pct_INV = occ.Pct_INV
FROM #FNM_Occ_Dist occ
WHERE perf.issueId = occ.issueId 
    AND perf.asOf = occ.asOf
;
COMMIT;

DROP TABLE IF EXISTS #FNM_MinDate_OCC;
SELECT
    issueId,
    min(asOf) as asOf,
    cast(NULL as numeric(12, 2)) as Pct_OWNER,
    cast(NULL as numeric(12, 2)) as Pct_2ND,
    cast(NULL as numeric(12, 2)) as Pct_INV
INTO #FNM_MinDate_OCC
FROM #FNM_Occ_Dist p
WHERE p.Pct_OWNER IS NOT NULL 
GROUP BY issueId
;
COMMIT;

UPDATE #FNM_MinDate_OCC s SET s.Pct_OWNER = d.Pct_OWNER, s.Pct_2ND = d.Pct_2ND, s.Pct_INV = d.Pct_INV 
FROM #FNM_Occ_Dist d
WHERE s.issueId = d.issueId
    AND s.asOf = d.asOf
;

UPDATE #FNM_PoolDistribution perf SET perf.Pct_OWNER = s.Pct_OWNER, perf.Pct_2ND = s.Pct_2ND, perf.Pct_INV = s.Pct_INV
FROM #FNM_MinDate_OCC s
WHERE perf.issueId = s.issueId 
    AND perf.Pct_OWNER IS NULL
;

DROP TABLE IF EXISTS #FNM_OriginationDate_OCC;
SELECT
    year(originationDate) as origYear,
    sum(balance * Pct_OWNER) / sum(balance) as WAVG_OWNER,
    sum(balance * Pct_2ND) / sum(balance) as WAVG_2ND,
    sum(balance * Pct_INV) / sum(balance) as WAVG_INV,
    sum(balance) as sum_ls
INTO #FNM_OriginationDate_OCC
FROM #FNM_PoolDistribution
WHERE Pct_OWNER IS NOT NULL
GROUP BY origYear
--HAVING sum_ls > 100000000
;
COMMIT;

UPDATE #FNM_PoolDistribution perf SET perf.Pct_OWNER = occ.WAVG_OWNER, perf.Pct_2ND = occ.WAVG_2ND, perf.Pct_INV = occ.WAVG_INV
FROM #FNM_OriginationDate_OCC occ
WHERE year(perf.originationDate) = occ.origYear
    AND perf.Pct_OWNER IS NULL
;
COMMIT;

UPDATE #FNM_PoolDistribution SET Pct_OWNER = 100.0
WHERE Pct_OWNER > 100.0
;

UPDATE #FNM_PoolDistribution SET Pct_OWNER = 0.0
WHERE Pct_OWNER < 0.0
;

UPDATE #FNM_PoolDistribution SET Pct_2ND = Pct_2ND - ((Pct_OWNER + Pct_2ND + Pct_INV - 100.0) / 2.0), Pct_INV = Pct_INV - ((Pct_OWNER + Pct_2ND + Pct_INV - 100.0) / 2.0)
WHERE abs(Pct_OWNER + Pct_2ND + Pct_INV - 100.0) > 0.0
;

UPDATE #FNM_PoolDistribution SET Pct_OWNER = Pct_OWNER + Pct_2ND, Pct_2ND = 0.0
WHERE Pct_2ND < 0
;

UPDATE #FNM_PoolDistribution SET Pct_OWNER = Pct_OWNER + Pct_INV, Pct_INV = 0.0
WHERE Pct_INV < 0
;
COMMIT;

-- Loan Purpose Distribution
DROP TABLE IF EXISTS #FNM_Purpose_Dist;
SELECT
    issueId,
    asOf,
    sum(Pct_PURCH) as Pct_PURCH,
    sum(Pct_REFI) as Pct_REFI
INTO #FNM_Purpose_Dist
FROM
(
SELECT
    p.issueId,
    p.asOf,
    CASE WHEN distributionType IN ('PURCH') THEN percentRpb ELSE 0.0 END as Pct_PURCH,
    CASE WHEN distributionType IN ('RE-FI') THEN percentRpb ELSE 0.0 END as Pct_REFI
FROM #FNM_PoolDistribution p
JOIN fnm.PIV_LoanDist d
    ON p.issueId = d.issueId
    AND p.asof = d.asOf
    AND distributionName = 'LOANPURPOSE'
--    AND subtype in ('ALL', '1', '2')
) t
GROUP BY issueId, asOf
;
COMMIT;

CREATE HG INDEX issueId_idx ON #FNM_Purpose_Dist(issueId);
CREATE LF INDEX asOf_idx ON #FNM_Purpose_Dist(asOf);
COMMIT;

UPDATE #FNM_PoolDistribution perf SET perf.Pct_PURCH = purp.Pct_PURCH, perf.Pct_REFI = purp.Pct_REFI
FROM #FNM_Purpose_Dist purp
WHERE perf.issueId = purp.issueId 
    AND perf.asOf = purp.asOf
;
COMMIT;

DROP TABLE IF EXISTS #FNM_MinDate_PURP;
SELECT
    issueId,
    min(asOf) as asOf,
    cast(NULL as numeric(12, 2)) as Pct_PURCH,
    cast(NULL as numeric(12, 2)) as Pct_REFI
INTO #FNM_MinDate_PURP
FROM #FNM_Purpose_Dist p
WHERE p.Pct_PURCH IS NOT NULL AND p.Pct_REFI IS NOT NULL
GROUP BY issueId
;
COMMIT;

UPDATE #FNM_MinDate_PURP s SET s.Pct_PURCH = d.Pct_PURCH, s.Pct_REFI = d.Pct_REFI
FROM #FNM_Purpose_Dist d
WHERE s.issueId = d.issueId
    AND s.asOf = d.asOf
;

UPDATE #FNM_PoolDistribution perf SET perf.Pct_PURCH = s.Pct_PURCH, perf.Pct_REFI = s.Pct_REFI
FROM #FNM_MinDate_PURP s
WHERE perf.issueId = s.issueId 
    AND (perf.Pct_PURCH IS NULL OR perf.Pct_REFI IS NULL)
;

DROP TABLE IF EXISTS #FNM_OriginationDate_PURP;
SELECT
    year(originationDate) as origYear,
    sum(balance * Pct_PURCH) / sum(balance) as WAVG_PURCH,
    sum(balance * Pct_REFI) / sum(balance) as WAVG_REFI,
    sum(balance) as sum_ls
INTO #FNM_OriginationDate_PURP
FROM #FNM_PoolDistribution
WHERE Pct_PURCH IS NOT NULL AND Pct_REFI IS NOT NULL
GROUP BY origYear
--HAVING sum_ls > 100000000
;
COMMIT;

UPDATE #FNM_PoolDistribution perf SET perf.Pct_PURCH = purp.WAVG_PURCH, perf.Pct_REFI = purp.WAVG_REFI
FROM #FNM_OriginationDate_PURP purp
WHERE year(perf.originationDate) = purp.origYear
    AND (perf.Pct_PURCH IS NULL OR perf.Pct_REFI IS NULL)
;
COMMIT;

UPDATE #FNM_PoolDistribution SET Pct_PURCH = 100.0
WHERE Pct_PURCH > 100.0
;

UPDATE #FNM_PoolDistribution SET Pct_PURCH = 0.0
WHERE Pct_PURCH < 0.0
;

UPDATE #FNM_PoolDistribution SET Pct_REFI = 100.0
WHERE Pct_REFI > 100.0
;

UPDATE #FNM_PoolDistribution SET Pct_REFI = 0.0
WHERE Pct_REFI < 0.0
;

UPDATE #FNM_PoolDistribution SET Pct_PURCH = Pct_PURCH - ((Pct_PURCH + Pct_REFI - 100.0) / 2.0), Pct_REFI = Pct_REFI - ((Pct_PURCH + Pct_REFI - 100.0) / 2.0)
WHERE abs(Pct_PURCH + Pct_REFI - 100.0) > 0.0
;


-- Origination Channel Distribution
DROP TABLE IF EXISTS #FNM_Channel_Dist;
SELECT
    marketTicker,
    issueId,
    asOf,
    sum(Pct_RETAIL) as Pct_RETAIL,
    sum(Pct_BROKER) as Pct_BROKER,
    sum(Pct_CORRES) as Pct_CORRES,
    Pct_RETAIL + Pct_BROKER + Pct_CORRES as Pct_Total
INTO #FNM_Channel_Dist
FROM
(
SELECT
    p.marketTicker,
    p.issueId,
    p.asOf,
    CASE WHEN distributionType IN ('RETAIL') THEN percentRpb ELSE 0.0 END as Pct_RETAIL,
    CASE WHEN distributionType IN ('BROKER') THEN percentRpb ELSE 0.0 END as Pct_BROKER,
    CASE WHEN distributionType IN ('CORRES') THEN percentRpb ELSE 0.0 END as Pct_CORRES
FROM #FNM_PoolDistribution p
JOIN fnm.PIV_LoanDist d
    ON p.issueId = d.issueId
    AND p.asof = d.asOf
    AND distributionName = 'TPO'
--    AND subtype = 'ALL'
WHERE 1=1
    --AND originationDate >= '2008-08-01'
) t
GROUP BY marketTicker, issueId, asOf
;
COMMIT;

CREATE HG INDEX issueId_idx ON #FNM_Channel_Dist(issueId);
CREATE LF INDEX asOf_idx ON #FNM_Channel_Dist(asOf);
COMMIT;

UPDATE #FNM_Channel_Dist SET Pct_RETAIL = NULL, Pct_BROKER = NULL, Pct_CORRES = NULL WHERE abs(Pct_Total - 100.0) > 15.0;
COMMIT;

UPDATE #FNM_PoolDistribution perf SET perf.Pct_RETAIL = ch.Pct_RETAIL, perf.Pct_BROKER = ch.Pct_BROKER, perf.Pct_CORRES = ch.Pct_CORRES
FROM #FNM_Channel_Dist ch
WHERE perf.issueId = ch.issueId 
    AND perf.asOf = ch.asOf
;
COMMIT;

DROP TABLE IF EXISTS #FNM_OriginationDate_CHAN;
SELECT
    marketTicker,
    year(originationDate) as origYear,
    sum(balance * Pct_RETAIL) / sum(balance) as WAVG_RETAIL,
    sum(balance * Pct_BROKER) / sum(balance) as WAVG_BROKER,
    sum(balance * Pct_CORRES) / sum(balance) as WAVG_CORRES,
    sum(balance) as sum_ls
INTO #FNM_OriginationDate_CHAN
FROM #FNM_PoolDistribution
WHERE Pct_RETAIL IS NOT NULL AND Pct_BROKER IS NOT NULL AND Pct_CORRES IS NOT NULL
GROUP BY marketTicker, origYear
--HAVING sum_ls > 100000000
;
COMMIT;

UPDATE #FNM_PoolDistribution perf SET perf.Pct_RETAIL = chan.WAVG_RETAIL, perf.Pct_BROKER = chan.WAVG_BROKER, perf.Pct_CORRES = chan.WAVG_CORRES
FROM #FNM_OriginationDate_CHAN chan
WHERE 1=1
    AND year(perf.originationDate) = chan.origYear
    AND (perf.Pct_RETAIL IS NULL OR perf.Pct_BROKER IS NULL OR perf.Pct_CORRES IS NULL)
    --AND perf.originationDate >= '2008-08-01'
    AND perf.marketTicker = chan.marketTicker
    AND perf.marketTicker = 'FNCL';
;
COMMIT;

UPDATE #FNM_PoolDistribution SET Pct_RETAIL = 100.0
WHERE Pct_RETAIL > 100.0
;

UPDATE #FNM_PoolDistribution SET Pct_RETAIL = 0.0
WHERE Pct_RETAIL < 0.0
;

UPDATE #FNM_PoolDistribution SET Pct_BROKER = 100.0
WHERE Pct_BROKER > 100.0
;

UPDATE #FNM_PoolDistribution SET Pct_BROKER = 0.0
WHERE Pct_BROKER < 0.0
;

UPDATE #FNM_PoolDistribution SET Pct_CORRES = 100.0
WHERE Pct_CORRES > 100.0
;

UPDATE #FNM_PoolDistribution SET Pct_CORRES = 0.0
WHERE Pct_CORRES < 0.0
;
COMMIT;


-- Normalize to 100%
UPDATE #FNM_PoolDistribution SET Pct_RETAIL = Pct_RETAIL - ((Pct_RETAIL + Pct_BROKER + Pct_CORRES - 100.0) / 3.0), 
    Pct_BROKER = Pct_BROKER - ((Pct_RETAIL + Pct_BROKER + Pct_CORRES - 100.0) / 3.0), 
    Pct_CORRES = Pct_CORRES - ((Pct_RETAIL + Pct_BROKER + Pct_CORRES - 100.0) / 3.0)
WHERE abs(Pct_RETAIL + Pct_BROKER + Pct_CORRES - 100.0) > 0.01
;
COMMIT;


-- Number Units Distribution
DROP TABLE IF EXISTS #FNM_Unit_Dist;
SELECT
    issueId,
    asOf,
    sum(Pct_Single) as Pct_SINGLE_UNIT,
    sum(Pct_multiple) as Pct_MULTIPLE_UNIT
INTO #FNM_Unit_Dist
FROM
(
SELECT
    p.issueId,
    p.asOf,
    CASE WHEN distributionType IN ('1-UNIT') THEN percentRpb ELSE 0.0 END as Pct_Single,
    CASE WHEN distributionType IN ('2-4UN') THEN percentRpb ELSE 0.0 END as Pct_Multiple
FROM #FNM_PoolDistribution p
JOIN fnm.PIV_LoanDist d
    ON p.issueId = d.issueId
    AND p.asof = d.asOf
    AND distributionName = 'PROPERTY'
--    AND subtype in ('ALL', '1', '2')
) t
GROUP BY issueId, asOf
;
COMMIT;

CREATE HG INDEX issueId_idx ON #FNM_Unit_Dist(issueId);
CREATE LF INDEX asOf_idx ON #FNM_Unit_Dist(asOf);
COMMIT;

UPDATE #FNM_PoolDistribution perf SET perf.Pct_SINGLE_UNIT = un.Pct_SINGLE_UNIT, perf.Pct_MULTIPLE_UNIT = un.Pct_MULTIPLE_UNIT
FROM #FNM_Unit_Dist un
WHERE perf.issueId = un.issueId 
    AND perf.asOf = un.asOf
;
COMMIT;

DROP TABLE IF EXISTS #FNM_MinDate_UNIT;
SELECT
    issueId,
    min(asOf) as asOf,
    cast(NULL as numeric(12, 2)) as Pct_SINGLE_UNIT,
    cast(NULL as numeric(12, 2)) as Pct_MULTIPLE_UNIT
INTO #FNM_MinDate_UNIT
FROM #FNM_Unit_Dist p
WHERE p.Pct_SINGLE_UNIT IS NOT NULL AND p.Pct_MULTIPLE_UNIT IS NOT NULL
GROUP BY issueId
;
COMMIT;

UPDATE #FNM_MinDate_UNIT s SET s.Pct_SINGLE_UNIT = d.Pct_SINGLE_UNIT, s.Pct_MULTIPLE_UNIT = d.Pct_MULTIPLE_UNIT
FROM #FNM_Unit_Dist d
WHERE s.issueId = d.issueId
    AND s.asOf = d.asOf
;

UPDATE #FNM_PoolDistribution perf SET perf.Pct_SINGLE_UNIT = s.Pct_SINGLE_UNIT, perf.Pct_MULTIPLE_UNIT = s.Pct_MULTIPLE_UNIT
FROM #FNM_MinDate_UNIT s
WHERE perf.issueId = s.issueId 
    AND (perf.Pct_SINGLE_UNIT IS NULL OR perf.Pct_MULTIPLE_UNIT IS NULL)
;

DROP TABLE IF EXISTS #FNM_OriginationDate_UNIT;
SELECT
    year(originationDate) as origYear,
    sum(balance * Pct_SINGLE_UNIT) / sum(balance) as WAVG_Single,
    sum(balance * Pct_MULTIPLE_UNIT) / sum(balance) as WAVG_Multiple,
    sum(balance) as sum_ls
INTO #FNM_OriginationDate_UNIT
FROM #FNM_PoolDistribution
WHERE Pct_SINGLE_UNIT IS NOT NULL AND Pct_MULTIPLE_UNIT IS NOT NULL
GROUP BY origYear
--HAVING sum_ls > 100000000
;
COMMIT;

UPDATE #FNM_PoolDistribution perf SET perf.Pct_SINGLE_UNIT = unit.WAVG_Single, perf.Pct_MULTIPLE_UNIT = unit.WAVG_Multiple
FROM #FNM_OriginationDate_UNIT unit
WHERE year(perf.originationDate) = unit.origYear
    AND (perf.Pct_SINGLE_UNIT IS NULL OR perf.Pct_MULTIPLE_UNIT IS NULL)
;
COMMIT;

UPDATE #FNM_PoolDistribution SET Pct_SINGLE_UNIT = 100.0
WHERE Pct_SINGLE_UNIT > 100.0
;

UPDATE #FNM_PoolDistribution SET Pct_SINGLE_UNIT = 0.0
WHERE Pct_SINGLE_UNIT < 0.0
;

UPDATE #FNM_PoolDistribution SET Pct_MULTIPLE_UNIT = 100.0
WHERE Pct_MULTIPLE_UNIT > 100.0
;

UPDATE #FNM_PoolDistribution SET Pct_MULTIPLE_UNIT = 0.0
WHERE Pct_MULTIPLE_UNIT < 0.0
;

UPDATE #FNM_PoolDistribution SET Pct_SINGLE_UNIT = Pct_SINGLE_UNIT - ((Pct_SINGLE_UNIT + Pct_MULTIPLE_UNIT - 100.0) / 2.0), Pct_MULTIPLE_UNIT = Pct_MULTIPLE_UNIT - ((Pct_SINGLE_UNIT + Pct_MULTIPLE_UNIT - 100.0) / 2.0)
WHERE abs(Pct_SINGLE_UNIT + Pct_MULTIPLE_UNIT - 100.0) > 0.0
;
COMMIT;

-- Tests

-- Time Series Tests
-- History for: CLTV, HPA, HPA_2YR
--SELECT marketTicker, asOf, count(1), sum(balance), sum(balance * Pct_HARPed) / sum(balance) as wavg_pct_harp FROM #FNM_PoolDistribution GROUP BY marketTicker, asOf ORDER BY asOf
--SELECT marketTicker, originationDate, count(1), sum(balance), sum(balance * Pct_HARPed) / sum(balance) as wavg_pct_harp FROM #FNM_PoolDistribution GROUP BY marketTicker, originationDate ORDER BY originationDate

--SELECT marketTicker, asOf, count(1), sum(balance), sum(balance * Pct_MtgIns) / sum(balance) as wavg_mtg_ins FROM #FNM_PoolDistribution GROUP BY marketTicker, asOf ORDER BY asOf
--SELECT marketTicker, originationDate, count(1), sum(balance), sum(balance * Pct_MtgIns) / sum(balance) as wavg_mtg_ins FROM #FNM_PoolDistribution GROUP BY marketTicker, originationDate ORDER BY originationDate

--SELECT marketTicker, asOf, count(1), sum(balance), sum(balance * Pct_OWNER) / sum(balance) as wavg_owner FROM #FNM_PoolDistribution GROUP BY marketTicker, asOf ORDER BY asOf

--SELECT marketTicker, asOf, count(1), sum(balance), sum(balance * Pct_2ND) / sum(balance) as wavg_2nd FROM #FNM_PoolDistribution GROUP BY marketTicker, asOf ORDER BY asOf

--SELECT marketTicker, asOf, count(1), sum(balance), sum(balance * Pct_INV) / sum(balance) as wavg_inv FROM #FNM_PoolDistribution GROUP BY marketTicker, asOf ORDER BY asOf

--SELECT marketTicker, asOf, count(1), sum(balance), sum(balance * Pct_PURCH) / sum(balance) as wavg_purch FROM #FNM_PoolDistribution GROUP BY marketTicker, asOf ORDER BY asOf

--SELECT marketTicker, asOf, count(1), sum(balance), sum(balance * Pct_REFI) / sum(balance) as wavg_refi FROM #FNM_PoolDistribution GROUP BY marketTicker, asOf ORDER BY asOf

--SELECT marketTicker, asOf, count(1), sum(balance), sum(balance * Pct_RETAIL) / sum(CASE WHEN Pct_RETAIL IS NULL THEN 0.0 ELSE balance END) as wavg_retail FROM #FNM_PoolDistribution GROUP BY marketTicker, asOf ORDER BY asOf

--SELECT marketTicker, asOf, count(1), sum(balance), sum(balance * Pct_BROKER) / sum(CASE WHEN Pct_BROKER IS NULL THEN 0.0 ELSE balance END) as wavg_broker FROM #FNM_PoolDistribution GROUP BY marketTicker, asOf ORDER BY asOf

--SELECT marketTicker, asOf, count(1), sum(balance), sum(balance * Pct_CORRES) / sum(CASE WHEN Pct_CORRES IS NULL THEN 0.0 ELSE balance END) as wavg_corres FROM #FNM_PoolDistribution GROUP BY marketTicker, asOf ORDER BY asOf

--SELECT marketTicker, asOf, count(1), sum(balance), sum(balance * Pct_SINGLE_UNIT) / sum(balance) as wavg_single FROM #FNM_PoolDistribution GROUP BY marketTicker, asOf ORDER BY asOf

--SELECT marketTicker, asOf, count(1), sum(balance), sum(balance * Pct_MULTIPLE_UNIT) / sum(balance) as wavg_multiple FROM #FNM_PoolDistribution GROUP BY marketTicker, asOf ORDER BY asOf

----------------------------------------------------------------------------------------------
-- Check to see if Pools have Est_Pct_HARPed IS NULL OR Est_Pct_HARPed < 0.0 OR Est_Pct_HARPed > 100.0
----------------------------------------------------------------------------------------------
        declare   @cnt int
        SELECT
            @cnt =  count(1)
        FROM #FNM_PoolDistribution WHERE Est_Pct_HARPed IS NULL OR Est_Pct_HARPed < 0.0 OR Est_Pct_HARPed > 100.0

        if (@cnt > 200)
        BEGIN
            RAISERROR 99999 'FNM Pools with INVALID VALUE for Est_Pct_HARPed PoolCount : %1!', @cnt
            RETURN
        END
        
------------------------------------------------------------------------------------------------
---- Check to see if Pools have asOf > '2014-01-01' AND (Pct_HARPed IS NULL OR Pct_HARPed < 0.0 OR Pct_HARPed > 100.0)
------------------------------------------------------------------------------------------------

--        SELECT
--            @cnt =  count(1)
--        FROM #FNM_PoolDistribution WHERE asOf > '2014-01-01' AND (Pct_HARPed IS NULL OR Pct_HARPed < 0.0 OR Pct_HARPed > 100.0)

--        if (@cnt > 200)
--        BEGIN
--            RAISERROR 99999 'FNM Pools with INVALID VALUE for Pct_HARPed PoolCount : %1!', @cnt
--            RETURN
--        END

----------------------------------------------------------------------------------------------
-- Mtg Insurance is Not Populated for Fannie Pools Yet, hence no test
----------------------------------------------------------------------------------------------

--        SELECT
--            @cnt =  count(1)
--        FROM #FNM_PoolDistribution WHERE Pct_MtgIns IS NULL OR Pct_MtgIns < 0.0 OR Pct_MtgIns > 100.0

--        if (@cnt > 0)
--        BEGIN
--            RAISERROR 99999 'FNM Pools with INVALID VALUE for Pct_MtgIns PoolCount : %1!', @cnt
--            RETURN
--        END
        
----------------------------------------------------------------------------------------------
-- Check to see if Pools have originationDate >= '1994-01-01' AND (Pct_OWNER IS NULL OR Pct_OWNER < 0.0 OR Pct_OWNER > 100.0)
----------------------------------------------------------------------------------------------

        SELECT
            @cnt =  count(1)
        FROM #FNM_PoolDistribution WHERE originationDate >= '1994-01-01' AND (Pct_OWNER IS NULL OR Pct_OWNER < 0.0 OR Pct_OWNER > 100.0)

        if (@cnt > 0)
        BEGIN
            RAISERROR 99999 'FNM Pools with INVALID VALUE for Pct_OWNER PoolCount : %1!', @cnt
            RETURN
        END
        
----------------------------------------------------------------------------------------------
-- Check to see if Pools have originationDate >= '1994-01-01' AND (Pct_2ND IS NULL OR Pct_2ND < 0.0 OR Pct_2ND > 100.0)
----------------------------------------------------------------------------------------------

        SELECT
            @cnt =  count(1)
        FROM #FNM_PoolDistribution WHERE originationDate >= '1994-01-01' AND (Pct_2ND IS NULL OR Pct_2ND < 0.0 OR Pct_2ND > 100.0)

        if (@cnt > 0)
        BEGIN
            RAISERROR 99999 'FNM Pools with INVALID VALUE for Pct_2ND PoolCount : %1!', @cnt
            RETURN
        END
        
----------------------------------------------------------------------------------------------
-- Check to see if Pools have originationDate >= '1994-01-01' AND (Pct_INV IS NULL OR Pct_INV < 0.0 OR Pct_INV > 100.0)
----------------------------------------------------------------------------------------------

        SELECT
            @cnt =  count(1)
        FROM #FNM_PoolDistribution WHERE originationDate >= '1994-01-01' AND (Pct_INV IS NULL OR Pct_INV < 0.0 OR Pct_INV > 100.0)

        if (@cnt > 0)
        BEGIN
            RAISERROR 99999 'FNM Pools with INVALID VALUE for Pct_INV PoolCount : %1!', @cnt
            RETURN
        END

----------------------------------------------------------------------------------------------
-- Check to see if Pools have abs(Pct_OWNER + Pct_2ND + Pct_INV - 100.0) > 0.1
----------------------------------------------------------------------------------------------

        SELECT
            @cnt =  count(1)
        FROM #FNM_PoolDistribution WHERE abs(Pct_OWNER + Pct_2ND + Pct_INV - 100.0) > 0.1

        if (@cnt > 0)
        BEGIN
            RAISERROR 99999 'FNM Pools with Occupancy not summing to 100 PoolCount : %1!', @cnt
            RETURN
        END

----------------------------------------------------------------------------------------------
-- Check to see if Pools have originationDate >= '1994-01-01' AND (Pct_PURCH IS NULL OR Pct_PURCH < 0.0 OR Pct_PURCH > 100.0)
----------------------------------------------------------------------------------------------

        SELECT
            @cnt =  count(1)
        FROM #FNM_PoolDistribution WHERE originationDate >= '1994-01-01' AND (Pct_PURCH IS NULL OR Pct_PURCH < 0.0 OR Pct_PURCH > 100.0)

        if (@cnt > 0)
        BEGIN
            RAISERROR 99999 'FNM Pools with INVALID VALUE for Pct_PURCH PoolCount : %1!', @cnt
            RETURN
        END

----------------------------------------------------------------------------------------------
-- Check to see if Pools have originationDate >= '1994-01-01' AND (Pct_REFI IS NULL OR Pct_REFI < 0.0 OR Pct_REFI > 100.0)
----------------------------------------------------------------------------------------------

        SELECT
            @cnt =  count(1)
        FROM #FNM_PoolDistribution WHERE originationDate >= '1994-01-01' AND (Pct_REFI IS NULL OR Pct_REFI < 0.0 OR Pct_REFI > 100.0)

        if (@cnt > 0)
        BEGIN
            RAISERROR 99999 'FNM Pools with INVALID VALUE for Pct_REFI PoolCount : %1!', @cnt
            RETURN
        END

----------------------------------------------------------------------------------------------
-- Check to see if Pools have abs(Pct_PURCH + Pct_REFI - 100.0) > 0.1
----------------------------------------------------------------------------------------------

        SELECT
            @cnt =  count(1)
        FROM #FNM_PoolDistribution WHERE abs(Pct_PURCH + Pct_REFI - 100.0) > 0.1

        if (@cnt > 0)
        BEGIN
            RAISERROR 99999 'FNM Pools with Purpose not summing to 100 PoolCount : %1!', @cnt
            RETURN
        END

----------------------------------------------------------------------------------------------
-- Check to see if Pools have originationDate >= '1995-01-01' AND marketTicker = 'FGLMC' AND (Pct_RETAIL IS NULL OR Pct_RETAIL < 0.0 OR Pct_RETAIL > 100.0)
----------------------------------------------------------------------------------------------

        SELECT
            @cnt =  count(1)
        FROM #FNM_PoolDistribution WHERE originationDate >= '1995-01-01' AND marketTicker = 'FGLMC' AND (Pct_RETAIL IS NULL OR Pct_RETAIL < 0.0 OR Pct_RETAIL > 100.0)

        if (@cnt > 0)
        BEGIN
            RAISERROR 99999 'FNM Pools with INVALID VALUE for Pct_RETAIL PoolCount : %1!', @cnt
            RETURN
        END

----------------------------------------------------------------------------------------------
-- Check to see if Pools have originationDate >= '1995-01-01' AND marketTicker = 'FGLMC' AND (Pct_BROKER IS NULL OR Pct_BROKER < 0.0 OR Pct_BROKER > 100.0)
----------------------------------------------------------------------------------------------

        SELECT
            @cnt =  count(1)
        FROM #FNM_PoolDistribution WHERE originationDate >= '1995-01-01' AND marketTicker = 'FGLMC' AND (Pct_BROKER IS NULL OR Pct_BROKER < 0.0 OR Pct_BROKER > 100.0)

        if (@cnt > 0)
        BEGIN
            RAISERROR 99999 'FNM Pools with INVALID VALUE for Pct_BROKER PoolCount : %1!', @cnt
            RETURN
        END

----------------------------------------------------------------------------------------------
-- Check to see if Pools have originationDate >= '1995-01-01' AND marketTicker = 'FGLMC' AND (Pct_CORRES IS NULL OR Pct_CORRES < 0.0 OR Pct_CORRES > 100.0)
----------------------------------------------------------------------------------------------

        SELECT
            @cnt =  count(1)
        FROM #FNM_PoolDistribution WHERE originationDate >= '1995-01-01' AND marketTicker = 'FGLMC' AND (Pct_CORRES IS NULL OR Pct_CORRES < 0.0 OR Pct_CORRES > 100.0)

        if (@cnt > 0)
        BEGIN
            RAISERROR 99999 'FNM Pools with INVALID VALUE for Pct_CORRES PoolCount : %1!', @cnt
            RETURN
        END

----------------------------------------------------------------------------------------------
-- Check to see if Pools have abs(Pct_RETAIL + Pct_BROKER + Pct_CORRES - 100.0) > 0.1
----------------------------------------------------------------------------------------------

        SELECT
            @cnt =  count(1)
        FROM #FNM_PoolDistribution WHERE abs(Pct_RETAIL + Pct_BROKER + Pct_CORRES - 100.0) > 0.1

        if (@cnt > 0)
        BEGIN
            RAISERROR 99999 'FNM Pools with Channel not summing to 100 PoolCount : %1!', @cnt
            RETURN
        END

----------------------------------------------------------------------------------------------
-- Check to see if Pools have originationDate >= '1994-01-01' AND (Pct_SINGLE_UNIT IS NULL OR Pct_SINGLE_UNIT < 0.0 OR Pct_SINGLE_UNIT > 100.0)
----------------------------------------------------------------------------------------------

        SELECT
            @cnt =  count(1)
        FROM #FNM_PoolDistribution WHERE originationDate >= '1994-01-01' AND (Pct_SINGLE_UNIT IS NULL OR Pct_SINGLE_UNIT < 0.0 OR Pct_SINGLE_UNIT > 100.0)

        if (@cnt > 0)
        BEGIN
            RAISERROR 99999 'FNM Pools with INVALID VALUE for Pct_SINGLE_UNIT PoolCount : %1!', @cnt
            RETURN
        END

----------------------------------------------------------------------------------------------
-- Check to see if Pools have originationDate >= '1994-01-01' AND (Pct_MULTIPLE_UNIT IS NULL OR Pct_MULTIPLE_UNIT < 0.0 OR Pct_MULTIPLE_UNIT > 100.0)
----------------------------------------------------------------------------------------------

        SELECT
            @cnt =  count(1)
        FROM #FNM_PoolDistribution WHERE originationDate >= '1994-01-01' AND (Pct_MULTIPLE_UNIT IS NULL OR Pct_MULTIPLE_UNIT < 0.0 OR Pct_MULTIPLE_UNIT > 100.0)

        if (@cnt > 0)
        BEGIN
            RAISERROR 99999 'FNM Pools with INVALID VALUE for Pct_MULTIPLE_UNIT PoolCount : %1!', @cnt
            RETURN
        END

----------------------------------------------------------------------------------------------
-- Check to see if Pools have abs(Pct_SINGLE_UNIT + Pct_MULTIPLE_UNIT - 100.0) > 0.1
----------------------------------------------------------------------------------------------

        SELECT
            @cnt =  count(1)
        FROM #FNM_PoolDistribution WHERE abs(Pct_SINGLE_UNIT + Pct_MULTIPLE_UNIT - 100.0) > 0.1

        if (@cnt > 0)
        BEGIN
            RAISERROR 99999 'FNM Pools with Units not summing to 100 PoolCount : %1!', @cnt
            RETURN
        END
----------------------------------------------------------------------------------------------
-- Check to see if count of current month changes in a noticeable amount compare with previous month
----------------------------------------------------------------------------------------------
        declare   @cnt_previous int
        SELECT
            @cnt =  count(1)
        FROM #FNM_PoolDistribution WHERE asof = (SELECT asOf FROM #tmp_asOf)

        SELECT
            @cnt_previous =  count(1)
        FROM scale.FNM_PoolDistribution WHERE asof = (SELECT dateadd(month, -1, asOf) FROM #tmp_asOf)
        
        if (@cnt - @cnt_previous > 0.1 * @cnt_previous OR @cnt_previous - @cnt > 0.1 * @cnt_previous)
        BEGIN
            RAISERROR 99999 'FNM PoolDistribution with INVALID COUNT compare with previous month. Currnt: %1!; Previous: %2!', @cnt, @cnt_previous
            RETURN
        END 
-- End Tests



-- Load Data into Scale Tables
DELETE FROM scale.FNM_PoolDistribution
FROM scale.FNM_PoolDistribution spd, #FNM_PoolDistribution pd
WHERE 1=1
    AND spd.issueId = pd.issueId
    AND spd.asOf = pd.asOf
    AND pd.marketTicker IN (SELECT tickerName FROM #ticker)
    AND spd.asOf >= (SELECT asOf from #tmp_asOf)
;

INSERT INTO scale.FNM_PoolDistribution (issueId, asOf, percentHARPed, Est_Pct_HARPed, percentMtgIns, percentOCC_OWN, percentOCC_INV, percentOCC_2ND, percentPURP_PURCH, percentPURP_REFI, percentCHANNEL_RETAIL, 
    percentCHANNEL_BROKER, percentCHANNEL_CORRES, percentUNIT_SINGLE, percentUNIT_MULTIPLE)
SELECT
    issueId, 
    asOf, 
    Pct_HARPed, 
    Est_Pct_HARPed,
    Pct_MtgIns, 
    Pct_OWNER, 
    Pct_INV, 
    Pct_2ND, 
    Pct_PURCH, 
    Pct_REFI, 
    Pct_RETAIL, 
    Pct_BROKER, 
    Pct_CORRES, 
    Pct_SINGLE_UNIT, 
    Pct_MULTIPLE_UNIT
FROM #FNM_PoolDistribution
WHERE marketTicker IN (SELECT tickerName FROM #ticker)
    AND asOf >= (SELECT asOf from #tmp_asOf)
;
