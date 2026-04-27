-- Create CMM 102 Series for  for Symphony Tracking

drop table if exists #GNM_CMM102;
select 
    TickerName, 
    asOf = year(AsOfDate)*100+month(AsOfDate), 
    sum(SeriesNumValue)/sum(1) as monthlyCMM102Rate, 
    count = sum(1)
into #GNM_CMM102
from TimeSeriesMeta m join TimeSeries d on m.TimeSeriesMetaId = d.TimeSeriesMetaId
where tickerName like 'G2_30Yr_CMM_102'
group by TickerName, asOf
order by TickerName, asOf desc

delete from #GNM_CMM102 where asof = year(getdate()) * 100 + month(getdate())