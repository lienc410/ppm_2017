-- Create Media Effect Series for  for Symphony Tracking

-- Combined Loan and Pool Percent Refinanceable Percent
-- Lag of 1 Month is Assumed
DROP TABLE IF EXISTS #MediaEffect;
-- one and half month lagged
SELECT
    convert(date, dateadd(month, +1, AsOfDate)) as asOf,
    convert(numeric(6,2), 100.0 * SeriesNumValue) as media_effect
INTO #MediaEffect
FROM report.TimeSeries
WHERE 1=1
    AND TimeSeriesMetaId = (SELECT TimeSeriesMetaId FROM report.TimeSeriesMeta WHERE Source = 'PIV' AND TickerName = 'CONVENTIONAL_30YR_COMBINED' AND SeriesType = 'TWO_MONTH_AVG_PCT_REFI' AND ModelType = 'ScaleMediaEffectModel v5.0')
    AND asOf <= (SELECT max(factorAsOf) FROM report.loadDates)
;
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
