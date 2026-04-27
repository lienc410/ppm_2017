-- Create Media Effect Series for  for Symphony Tracking

-- Combined Loan and Pool Percent Refinanceable Percent
-- Lag of 1 Month is Assumed
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

CREATE INDEX asOf_idx ON #MediaEffect(asOf);
COMMIT;

