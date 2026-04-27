select d.AsOfDate, m.TickerName, d.SeriesNumValue
 from TimeSeriesMeta as m,TimeSeries as d
               where m.TimeSeriesMetaId = d.TimeSeriesMetaId
               and d.AsOfDate >= '20150311'
				and m.source = 'PIV' 
				and m.TickerName like'FN_CMM_30%'
				and m.category = 'MTG' 
				order by d.AsOfDate


select TickerName,Source,SeriesType,Category,AsOfDate,SeriesNumValue
from TimeSeriesMeta m, TimeSeries t
where TickerName IN ('30YrConformingFHA','30YrConformingConventional','30YrJumboConforming','30YrJumboNonConforming')
and m.timeseriesmetaId = t.timeseriesmetaId
and outTime='2099-01-01'
and Category='MTG'
AND AsOfDate='20150303'
order by TickerName,Source,SeriesType,AsOfDate




insert into TimeSeriesMeta(TickerName)

exec AddTimeSeries 'Wells Fargo','30YrConformingConventional','Closing Cost' ,'MTG'  ,NULL , '20150303', 6529, NULL ,NULL
exec AddTimeSeries 'Wells Fargo','30YrConformingConventional','Loan Amount' ,'MTG'  ,NULL , '20150303', 200000, NULL ,NULL

exec AddTimeSeries 'Wells Fargo','30YrJumboConforming','Closing Cost' ,'MTG'  ,NULL , '20150303', 3602, NULL ,NULL
exec AddTimeSeries 'Wells Fargo','30YrJumboConforming','Loan Amount' ,'MTG'  ,NULL , '20150303', 500000, NULL ,NULL

exec AddTimeSeries 'Wells Fargo','30YrJumboNonConforming','Closing Cost' ,'MTG'  ,NULL , '20150303', 1262, NULL ,NULL
exec AddTimeSeries 'Wells Fargo','30YrJumboNonConforming','Loan Amount' ,'MTG'  ,NULL , '20150303', 750000, NULL ,NULL