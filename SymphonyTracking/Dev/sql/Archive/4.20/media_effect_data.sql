-- Create Media Effect Series for  for Symphony Tracking

-- Combined Loan and Pool Percent Refinanceable Percent
-- Lag of 1 Month is Assumed
DROP TABLE IF EXISTS #MediaEffect_Step1;
SELECT
    convert(date, dateadd(month, +1, AsOfDate)) as asOf_lag1,
    convert(date, dateadd(month, +2, AsOfDate)) as asOf_lag2,
    convert(numeric(6,2), 100.0 * SeriesNumValue) as media_effect
INTO #MediaEffect_Step1
FROM report.TimeSeries
WHERE 1=1
    AND TimeSeriesMetaId = (SELECT TimeSeriesMetaId FROM report.TimeSeriesMeta WHERE Source = 'PIV' AND TickerName = 'CONVENTIONAL_30YR_COMBINED' AND SeriesType = 'MONTHLY_PCT_REFI' AND ModelType = 'ScaleMediaEffectModel v5.0')
;
COMMIT;

DROP TABLE IF EXISTS #MediaEffect;
-- one and half month lagged
SELECT
asof = lag1.asOf_lag1,
media_effect = lag1.media_effect * 0.5 + lag2.media_effect * 0.5
INTO #MediaEffect
FROM #MediaEffect_Step1 lag1
JOIN #MediaEffect_Step1 lag2 ON lag1.asOf_lag1 = lag2.asOf_lag2
;
COMMIT;

CREATE INDEX asOf_idx ON #MediaEffect(asOf);
COMMIT;

-- Create Business Day Count Series for  for Symphony Tracking
DROP TABLE IF EXISTS #Business_Day_Count;
SELECT
	AsOfDate as asOf, 
	convert(int, SeriesNumValue) as day_count
INTO #Business_Day_Count
FROM report.TimeSeriesMeta m 
JOIN report.timeseries d ON m.TimeSeriesMetaId = d.TimeSeriesMetaId 
WHERE Category = 'UTIL' AND SeriesType = 'DAY_COUNT';
COMMIT;

CREATE INDEX asOf_bd_idx ON #Business_Day_Count(asOf);
COMMIT;
