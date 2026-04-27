-- Create Surge Index Series for  for Symphony Tracking

-- Creates the 30 YR FRM Rate (point adjusted)
DROP TABLE IF EXISTS #Mtg30YrRates_monthly;
SELECT
    TickerName as SeriesName,
    AsOfDate as asOf, 
    convert(date, dateadd(month, +1, AsOfDate)) as asOf_lag1,
    convert(date, dateadd(month, +2, AsOfDate)) as asOf_lag2,
    convert(date, dateadd(month, +3, AsOfDate)) as asOf_lag3,
    SeriesNumValue as MtgRate
INTO #Mtg30YrRates_monthly
FROM report.TimeSeries ts
JOIN report.TimeSeriesMeta tsm
    ON ts.TimeSeriesMetaId = tsm.TimeSeriesMetaId
WHERE 1=1
    AND Source = 'PIV'
    AND SeriesType = 'MONTHLY_MTG_RATE'
    AND ModelType = 'ScaleMtgRateModel v2.0'
;
COMMIT;

CREATE LF INDEX series_idx ON #Mtg30YrRates_monthly(SeriesName);
CREATE LF INDEX asOf_idx ON #Mtg30YrRates_monthly(asOf);
CREATE LF INDEX asOf_lag1_idx ON #Mtg30YrRates_monthly(asOf_lag1);
CREATE LF INDEX asOf_lag2_idx ON #Mtg30YrRates_monthly(asOf_lag2);
CREATE LF INDEX asOf_lag3_idx ON #Mtg30YrRates_monthly(asOf_lag3);

COMMIT;

-- Create the Surge Index
-- Assumes a 2 month Lag
DROP TABLE IF EXISTS #SurgeIndex;
SELECT
    t1.asOf,
    t1.MtgRate,
    min(t2.MtgRate) as min_rate,
    (min_rate - t1.MtgRate) * 100 / 30.0 as raw_surge,
    CASE WHEN raw_surge < 0 THEN 0.0 WHEN raw_surge > 1 THEN 1.0 ELSE raw_surge END as surge_index
INTO #SurgeIndex
FROM #Mtg30YrRates_monthly t1
JOIN #Mtg30YrRates_monthly t2
    ON t2.asOf <= dateadd(month, -2, t1.asOf)
    AND t2.asOf >= '2014-07-01'
WHERE 1=1
    AND t1.SeriesName = 'GNM_PL'
    AND t2.SeriesName = 'GNM_PL'
GROUP BY t1.asOf, t1.MtgRate
ORDER BY t1.asOf
;
COMMIT;

