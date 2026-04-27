select AsOfDate, SeriesNumValue
from TimeSeriesMeta M, TimeSeries D
where M.SeriesType = 'Rate_US'
and M.TimeSeriesMetaId = D.TimeSeriesMetaId
and TickerName = 'PMMS_FRM_30YR'
order by asOfDate DESC