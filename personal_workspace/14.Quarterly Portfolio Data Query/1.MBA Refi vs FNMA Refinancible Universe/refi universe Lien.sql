 
---Point adjusted 1 point morrgage rates

select AsOfDate, SeriesNumValue = sum(case when M.SeriesType = 'Points_US' then (1.0 - d.SeriesNumvalue)/-4.0 else d.SeriesNumvalue end)
into #tempone
from report.TimeSeriesMeta M, report.TimeSeries D
where M.TimeSeriesMetaId = D.TimeSeriesMetaId
and M.Source = 'Freddie'
and M.TickerName  ='PMMS_FRM_30YR'
and M.SeriesType in ('Points_US','Rate_US')
group by AsOfDate
order by AsOfDate DESC

select * from #tempone  -------working at of 2/18/2015
drop table #tempone


------------------Refinancible using one point rate Latest as of 2/18/2015
select t.asOfDate, 
refinancible = sum(case when f.wac - t.SeriesNumValue >= 0.5 then f.currentBalance else 0 end)/sum(f.currentBalance),  
----------------We assume 50 bp incentive for 1 pt and given the avg survey is about 0.7 pt, this is equivalent to 42.5 bp of inc
refinancible_satoAdj = sum(case when f.wac - t.SeriesNumValue -s.SATO/100.0 >= 0.5 then f.currentBalance else 0 end)/sum(f.currentBalance)
from fnm.sec p, fnm.secFactor f,  #tempone t, fnm.secSupp s
where p.issueId = f.issueId
and p.issueId = s.issueId
and f.asOf = s.asOf
and p.collateralType = 'LOAN' 
and p.marketTicker in ('FNCL')
--and f.calcOrigMonth >= 200906
--and t.productionMonth = year(f.asOf)* 100 + month(f.asOf)
and year(t.asOfDate) * 100 + month(t.asOfDate) = year(f.asOf)* 100 + month(f.asOf)
and t.asOfDate >= '20150101'
group by t.asOfDate
order by t.asOfDate


---projection
select   
refinancible1 = sum(case when f.wac - 3.95 >= 0.5 then f.currentBalance else 0 end)/sum(f.currentBalance),
refinancible2 = sum(case when f.wac - 3.85 >= 0.5 then f.currentBalance else 0 end)/sum(f.currentBalance),
refinancible3 = sum(case when f.wac - 3.75 >= 0.5 then f.currentBalance else 0 end)/sum(f.currentBalance),
refinancible4 = sum(case when f.wac - 3.65 >= 0.5 then f.currentBalance else 0 end)/sum(f.currentBalance),
refinancible5 = sum(case when f.wac - 3.55 >= 0.5 then f.currentBalance else 0 end)/sum(f.currentBalance),
refinancible6 = sum(case when f.wac - 3.45 >= 0.5 then f.currentBalance else 0 end)/sum(f.currentBalance),
refinancible7 = sum(case when f.wac - 3.35 >= 0.5 then f.currentBalance else 0 end)/sum(f.currentBalance),
refinancible8 = sum(case when f.wac - 3.25 >= 0.5 then f.currentBalance else 0 end)/sum(f.currentBalance),
refinancible9 = sum(case when f.wac - 3.15 >= 0.5 then f.currentBalance else 0 end)/sum(f.currentBalance),
refinancible10 = sum(case when f.wac - 3.05 >= 0.5 then f.currentBalance else 0 end)/sum(f.currentBalance),
refinancible11 = sum(case when f.wac - 2.95 >= 0.5 then f.currentBalance else 0 end)/sum(f.currentBalance),
refinancible12 = sum(case when f.wac - 2.85 >= 0.5 then f.currentBalance else 0 end)/sum(f.currentBalance)
from fnm.sec p, fnm.secFactor f 
where p.issueId = f.issueId
and p.collateralType = 'LOAN' 
and p.marketTicker in ('FNCL')
and f.asOf = '20150401' ---- update to the latest factor date



 
