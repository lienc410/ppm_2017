-- Create Monthly HPI data for Symphony Tracking

-- Requires Extending the Time Series to the latest factor date using an 
-- Assumes of 3% HPA for missing periods
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
WHERE TimeSeriesMetaId = (SELECT TimeSeriesMetaId FROM report.TimeSeriesMeta WHERE Source = 'PIV' AND TickerName = 'HPI_USA_ALL_TRANSACTIONS' AND Category = 'HPI' AND SeriesType = 'HPIndex' AND ModelType = 'ScaleHPIModel v2.0')
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

CREATE INDEX asOf_idx ON #HPA_MA(asOf);
COMMIT;

DELETE FROM #HPA_MA WHERE HPA_1YR IS NULL;
COMMIT;

DELETE FROM #HPA_MA WHERE HPA_2YR IS NULL;
COMMIT;

