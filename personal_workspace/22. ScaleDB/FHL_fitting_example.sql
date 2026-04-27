--set temporary option REVERT_TO_V15_OPTIMIZER = 'on'; 

-- Baton Fitting Data
-- Freddie Conventional
-- Pool Level
-- Script to pull data from Scale tables for Fitting process in R


-- Before execute the script, need to set the dates to run for
DROP TABLE IF EXISTS #tmp_asOf;
SELECT CAST ('1994-02-01' AS DATE) asOf INTO #tmp_asOf
;
COMMIT;
CREATE LF INDEX asof_idx ON #tmp_asOf(asOf);
COMMIT;

-- Before execute the script, need to set the version to run for
DROP TABLE IF EXISTS #tmp_version;
SELECT CAST ('2.00' AS varchar(5)) version INTO #tmp_version
;
COMMIT;
CREATE LF INDEX version_idx ON #tmp_version(version);
COMMIT;

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

CREATE LF INDEX pool_tickerName_idx ON #ticker(tickerName);
COMMIT;

-- Before execute the script, create Sample of Pools (Optional)
DROP TABLE IF EXISTS #PoolIssueId;
SELECT issueId, NEWID() as IDX, marketTicker
INTO #PoolIssueId
FROM (
    SELECT distinct issueId, marketTicker FROM fhl.sec p WHERE p.collateralType = 'LOAN'
) o
WHERE o.marketTicker IN (SELECT tickerName FROM #ticker)
;
COMMIT;

DROP TABLE IF EXISTS #PoolIDSample;
SELECT top 1000 issueId -- subset of total
-- SELECT issueId -- all pools
INTO #PoolIDSample FROM #PoolIssueId 
ORDER BY IDX;
COMMIT;

CREATE HG INDEX issueId_idx ON #PoolIDSample(issueId);
COMMIT;


-----------------------------------------------------------
-- Create Media Effect Series

-- Combined Loan and Pool Percent Refinanceable Percent
-- Lag of 1 Month is Assumed
-----------------------------------------------------------
DROP TABLE IF EXISTS #MediaEffect;
SELECT
    convert(date, dateadd(month, +1, AsOfDate)) as asOf,
    convert(numeric(6,2), 100.0 * SeriesNumValue) as media_effect
INTO #MediaEffect
FROM report.TimeSeries
WHERE 1=1
    AND TimeSeriesMetaId = (SELECT TimeSeriesMetaId FROM report.TimeSeriesMeta WHERE Source = 'PIV' AND TickerName = 'CONVENTIONAL_30YR_COMBINED' AND SeriesType = 'MONTHLY_PCT_REFI' AND ModelType = 'ScaleMediaEffectModel v3.0')
ORDER BY asOf
;
COMMIT;

CREATE LF INDEX asOf_idx ON #MediaEffect(asOf);
COMMIT;

-----------------------------------------------------------
-- Create Mortgage Credit Availability Series

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

CREATE LF INDEX asOf_idx ON #CreditAvailability(asOf);
COMMIT;


--------------------------------------------------------------------------------
-- Create Monthly HPI data for Symphony Tracking

-- Requires Extending the Time Series to the latest factor date using an 
-- Assumes of 3% HPA for missing periods
--------------------------------------------------------------------------------
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
    ts.SeriesNumValue * power(1.0 + 3.0 / 100.0, t.projected_month / 12.0) as HPIndex -- assume 3% annual appreciation for missing periods
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

CREATE LF INDEX asOf_idx ON #HPA_MA(asOf);
COMMIT;

DELETE FROM #HPA_MA WHERE HPA_1YR IS NULL;
COMMIT;

DELETE FROM #HPA_MA WHERE HPA_2YR IS NULL;
COMMIT;


-----------------------------------------------------------
-- Store all pools with pertinent data
-----------------------------------------------------------
DROP TABLE IF EXISTS #FHL_fitting_pools;
SELECT
    sph.issueId,
    sph.marketTicker,
    sph.asOf,
    sf.wala,
    sf.schamBalance,
    sf.currentBalance,
    sf.inVoluntaryAmount,
    sph.originationDate,
    sph.origLoanSize,
    sph.origFICO,
    sph.origLTV,
    sph.origNoteRate,
    sph.currLoanSize,
    sph.cltv,
    sph.hpa,
    spd.percentHARPed,
    spd.percentMtgIns,
    spd.percentOCC_OWN,
    spd.percentOCC_INV,
    spd.percentOCC_2ND,
    spd.percentPURP_PURCH,
    spd.percentPURP_REFI,
    spd.percentCHANNEL_RETAIL,
    spd.percentCHANNEL_BROKER,
    spd.percentCHANNEL_CORRES,
    spd.percentUNIT_SINGLE,
    spd.percentUNIT_MULTIPLE,
    CASE WHEN spd.percentCURRENT IS NULL THEN spd.Est_Pct_CURRENT ELSE spd.percentCURRENT END as percentCURRENT,
    CASE WHEN spd.percentDELQ30plus IS NULL THEN spd.Est_Pct_DELQ30p ELSE spd.percentDELQ30plus END as percentDELQ30plus,
    CASE WHEN spd.percentDELQ60plus IS NULL THEN spd.Est_Pct_DELQ60p ELSE spd.percentDELQ60plus END as percentDELQ60plus,
    CASE WHEN spd.percentDELQ90plus IS NULL THEN spd.Est_Pct_DELQ90p ELSE spd.percentDELQ90plus END as percentDELQ90plus,
    CASE WHEN spd.percentDELQ30plus IS NULL THEN spd.Est_Pct_DELQ30plus - spd.Est_Pct_DELQ90plus ELSE spd.percentDELQ30plus END as percentDELQ,
    spe.HARP_eligible,
    spe.conventional_eligible,
    spe.fha_eligible,
    spe.refi_eligible,
    spi.conventional_refi_incentive,
    spi.fha_refi_incentive,
    spi.refi_incentive,
    spi.refi_incentive_eligible,
    spi.origPMI,
    spi.currLLPA,
    spi.currPMI,
    spi.currMIP,
    spb.burnout,
    me.media_effect,
    ssp.sato,
    ca.mca_18mo as credit_availability,
    100.0 * hpi.HPA_2YR as HPA_2YR,
    convert(decimal(10,6), CASE WHEN 1.0 - sf.currentBalance / sf.schamBalance < 0 THEN 0.0 ELSE 1.0 - sf.currentBalance / sf.schamBalance END) as smm,
    convert(decimal(10,6), IFNULL(sf.inVoluntaryAmount, 0.0, CASE WHEN 1.0 - sf.inVoluntaryAmount / sf.schamBalance < 0 THEN 0.0 ELSE 1.0 - sf.inVoluntaryAmount / sf.schamBalance END)) as mdr
INTO #FHL_fitting_pools
FROM fhl.sec s
JOIN scale.FHL_PoolHist sph
    ON s.issueId = sph.issueId
JOIN #ticker tk
    ON sph.marketTicker = tk.tickerName
JOIN fhl.secFactor sf
    ON sph.issueId = sf.issueId
    AND sph.asOf = dateadd(month, -1, sf.asOf)
JOIN fhl.secsupp  ssp
    ON sph.issueId = ssp.issueId
    AND sph.asOf = ssp.asOf
JOIN scale.FHL_PoolDistribution spd
    ON sph.issueId = spd.issueId
    AND sph.asOf = spd.asOf
JOIN scale.FHL_PoolEligibility spe
    ON sph.issueId = spe.issueId
    AND sph.asOf = spe.asOf
JOIN scale.FHL_PoolIncentive spi
    ON sph.issueId = spi.issueId
    AND sph.asOf = spi.asOf
JOIN scale.FHL_PoolBurnout spb
    ON sph.issueId = spb.issueId
    AND sph.asOf = spb.asOf
JOIN #PoolIDSample sam
    ON sph.issueId = sam.issueId
JOIN #MediaEffect me
    ON sph.asOf = me.asOf
JOIN #CreditAvailability ca
    ON sph.asOf = ca.asOf
JOIN #HPA_MA hpi
    ON sph.asOf = hpi.asOf
WHERE 1=1
    AND spi.version = (select version from #tmp_version)
    AND spb.version = (select version from #tmp_version)
    AND sph.asOf >= '1994-02-01' --(select asOf from #tmp_asOf)
    AND sf.schamBalance > 0.01
;
COMMIT;

