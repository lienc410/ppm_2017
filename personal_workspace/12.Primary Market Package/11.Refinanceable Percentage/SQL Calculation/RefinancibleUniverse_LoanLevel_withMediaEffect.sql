
-----------------------------------------------------------------------
------------------procedure for the loan level model with Media Effect
--- (1) Check if the loan is 50bps in the money and
--- (2) If (1) holds; look back at the history of mortgage rates over the life of the loan and count the number of weeks where you can 
--- find a rate at or below prevailing rates. If this count is less than 12 weeks then count the loan as part of the "Media Effect" index.
------------------------------------------------------------------------
--alter procedure Lien_Test (@asof Date) 
alter procedure RefinancibleUniverse_LoanLevel_withMediaEffect( @asof date ) 
as
begin
  ----------------------------------------------------
  -------- Low Rate Matrix - Media Effect---------------
  --------------------------------------------------
  --------PMMS 1-Point Rate
  drop table if exists #surveyRates
  select AsOfDate,
    AsOfMonth=convert(date,year(asOfDate) || '-' || month(asOfDate) || '-01'),
    datebucket=convert(date,(case when asOfDate <= '2013-12-16' then '2011-09-22'
    when asOfDate <= '2014-01-08' then '2013-12-16'
    when asOfDate <= '2015-01-07' then '2014-01-08'
    else '2015-01-07'end)),SeriesNumValue=sum(case when M.SeriesType = 'Points_US' then(1.0-d.SeriesNumvalue)/-4.0 else d.SeriesNumvalue end)
    into #surveyRates
    from report.TimeSeriesMeta as M,report.TimeSeries as D
    where M.TimeSeriesMetaId = D.TimeSeriesMetaId
    and M.Source = 'Freddie'
    and M.TickerName = 'PMMS_FRM_30YR'
    and M.SeriesType in( 'Points_US','Rate_US' ) 
    group by AsOfDate
    order by AsOfDate desc
  commit work
  --------construct time period
  drop table if exists #NumberOfWeeks
  select StartDate=m1.asOfdate,EndDate=m2.asofdate,StartMonth=m1.AsOfMonth,EndMonth=m2.AsOfMonth,NumberOfWeeks=convert(numeric(10,5),null)
    into #NumberOfWeeks
    from #surveyRates as m1,#surveyRates as m2
    where EndDate >= StartDate
    --and StartDate = '2001-01-05'
    group by StartDate,StartMonth,EndDate,EndMonth
  ---------Get lowest rate in the time period
  update #NumberOfWeeks as r
    set NumberOfWeeks = t.NumberOfWeeks from
    (select r.StartDate,r.EndDate,NumberOfWeeks=sum(case when m.SeriesNumValue <= s.SeriesNumValue then 1 else 0 end)
      from #NumberOfWeeks as r,#surveyRates as m,#surveyRates as s
      where m.AsOfDate >= r.StartDate and m.AsOfDate < r.EndDate
      and s.AsOfDate = r.EndDate
      group by r.StartDate,r.EndDate) as t
    where t.StartDate = r.StartDate
    and t.endDate = r.EndDate
  commit work
  ---------Keep only the first update date as startDate, last Thursday as EndDate
  drop table if exists #NumberOfWeeks_MonthlyTable
  select *
    into #NumberOfWeeks_MonthlyTable
    from #NumberOfWeeks as t
    where startdate = (select min(startdate) from #NumberOfWeeks where startmonth = t.startmonth)
  --and enddate = (select max(enddate) from #lowestRate where endmonth = t.endmonth)
  ------------ The PMI that Borrowers currently paying ------------------
  drop table if exists report.#tempCurrentPayingPMI
  select *
    into #tempCurrentPayingPMI
    from PMI
    where Asofdate >= '20140101'
    and LoanPurpose = 'REFI'
  commit work
  ------------ PMI table -------------
  drop table if exists report.#tempPMI
  select *
    into #tempPMI
    from PMI
    where Asofdate >= '20140101'
    and LoanPurpose = 'REFI'
  commit work
  --PMI using MGIC "Monthly premiums for all states (except WA)", Fixed Rate 30-YEAR + Rate-and-Term Refinance
  ------------- PMMS weekly survey 1-point rate --------------------
DROP TABLE IF EXISTS #tempone
select 
    AsOfDate,
    convert(date, year(asOfDate) || '-' || month(asOfDate) || '-01') as AsOf,
    datebucket = convert(date, (case when asOfDate <= '2013-12-16' then '2011-09-22'
                when asOfDate <= '2014-01-08' then '2013-12-16'
                when asOfDate <= '2015-01-07' then '2014-01-08'
				when asOfDate < '2015-09-01' then '2015-01-07'
                else '2015-09-01' end)),
    lastmonth = dateadd(month, -1, AsOf),
    SeriesNumValue = sum(case when M.SeriesType = 'Points_US' then (1.0 - d.SeriesNumvalue)/-4.0 else d.SeriesNumvalue end)
into #tempone
from report.TimeSeriesMeta M, report.TimeSeries D
where M.TimeSeriesMetaId = D.TimeSeriesMetaId
and M.Source = 'Freddie'
and M.TickerName  ='PMMS_FRM_30YR'
and M.SeriesType in ('Points_US','Rate_US')
group by AsOfDate
order by AsOfDate DESC

  commit work
  ------------------- Pre2005 Pool level adjestment table ---------------------------
  drop table if exists report.#Pre2005
  select t.asOfDate,
    refinancible=sum(case when f.wac-t.SeriesNumValue >= .5 then f.currentBalance else 0 end)/sum(f.currentBalance),
    --refinancible_satoAdj = sum(case when f.wac - t.SeriesNumValue -s.SATO/100.0 >= 0.5 then f.currentBalance else 0 end)/sum(f.currentBalance)
    ITMBalance=sum(case when f.wac-t.SeriesNumValue >= .5 then f.currentBalance else 0 end),
    currBalance=sum(f.currentBalance)
    into #Pre2005
    from fhl.sec as p,fhl.secFactor as f,#tempone as t,fhl.secSupp as s
    where p.issueId = f.issueId
    and p.issueId = s.issueId
    and f.asOf = s.asOf
    and p.collateralType = 'LOAN'
    and p.marketTicker in( 'FGLMC' ) 
    and t.lastmonth = f.asOf
    --and year(t.asOfDate) * 100 + month(t.asOfDate) = year(f.asOf)* 100 + month(f.asOf)
    and t.asOfDate >= '20110101'
    and p.issueDate <= '20051201'
    --and f.CalcOrigMonth > 200906
    group by t.asOfDate
    order by t.asOfDate asc
  commit work
  ----------- create index for temp table, increase execute speed ----------
  create index idx_temp_asofdate on report.#tempone(AsOfDate)
  create index idx_temp_asof on report.#tempone(AsOf)
  create index idx_temp_datebucket on report.#tempone(datebucket)
  commit work
  ---------- Combine LLPA matrix ------------------
  drop table if exists report.#tempLLPA
  select f.asofdate,f.FicoStart,f.FicoEnd,f.LtvStart,f.LtvEnd,o.occtype,u.numUnits,BaseLLTV=(case when f.LLPA is null then 999 else f.LLPA end),
    AMDC1=a.LLPA,AMDC2=aa.LLPA,AMDC=(case when AMDC1 is null then AMDC2 else AMDC1 end),
    HighLTV=(case when l.llpa is null then 999 else l.llpa end),
    Occp=(case when o.llpa is null then 999 else o.llpa end),
    UnitL=(case when u.llpa is null then 999 else u.llpa end),
    totalLLPA=(BaseLLTV+AMDC+HighLTV+Occp+UnitL)/100
    into #tempLLPA
    from report.LLPAFicoLTV as f
      left outer join report.LLPAAMDC as a
      on f.FicoStart = a.FicoStart
      and f.FicoEnd = a.FicoEnd
      and f.LtvStart = a.LtvStart
      and f.LtvEnd = a.LtvEnd
      and a.asofdate = f.asofdate
      join report.LLPAAMDC as aa
      on f.FicoStart = aa.FicoStart
      and f.FicoEnd = aa.FicoEnd
      and f.LtvStart = aa.LtvStart
      and f.LtvEnd = aa.LtvEnd
      and aa.asofdate = '2014-01-08'
      join report.LLPAHighLtv as l
      on f.FicoStart = l.FicoStart
      and f.FicoEnd = l.FicoEnd
      and f.LtvStart = l.LtvStart
      and f.LtvEnd = l.LtvEnd
      join report.LLPAOCCLTV as o
      on f.LtvStart = o.LtvStart
      and f.LtvEnd = o.LtvEnd
      join report.LLPAUNITLTV as u
      on f.LtvStart = u.LtvStart
      and f.LtvEnd = u.LtvEnd
    where l.asofdate = '2013-12-16'
    and o.asofdate = '2013-11-14'
    and u.asofdate = '2013-11-14'
  commit work
  create index idx_templla_asof on report.#tempLLPA(AsOfDate)
  create index idx_templla_occType on report.#tempLLPA(occType)
  create index idx_templla_numUnits on report.#tempLLPA(numUnits)
  commit work
  ------------------------- main select for the loan level model --------------------------------
  select t.asOfDate,
    refinanceible=sum(case when r.NumberOfWeeks <= 12 then
      (case when l.OrigNoteRate
      +(case when l.PctMtgIns > 0 then tcp.PMI/100 else 0 end)
      -t.SeriesNumValue
      -(case when l.calcorigmonth_LL <= 200906 then(case when tl.totalLLPA > .75 then .75 else tl.totalLLPA end) else tl.totalLLPA end)/4
      -(case when l.calcorigmonth_LL <= 200906 then 0 else tp.PMI/100 end) >= .5 then
        (case when lh.currentRpb > 0 then lh.currentRpb+pre.ITMBalance else .000001 end) else 0 end)
    else 0
    end)/sum(case when lh.currentRpb > 0 then lh.currentRpb+pre.currBalance else .000001 end)
    from fhl.sec as p,fhl.PIV_Loan as l,fhl.PIV_LoanHist as lh,#tempone as t,#tempLLPA as tl,#tempPMI as tp,#tempCurrentPayingPMI as tcp,#Pre2005 as pre,#NumberOfWeeks_MonthlyTable as r
    where p.issueId = l.issueId
    and l.issueId = lh.issueId
    and l.loanSeqNum = lh.loanSeqNum
    and p.collateralType = 'LOAN'
    and l.marketTicker in( 'FGLMC' ) 
    and l.marketTicker = p.marketTicker
    and t.lastmonth = lh.asOf
    --and t.asOf = lh.asOf
    --and lh.asOf >= '2011-01-01'
    and l.occType = tl.occType
    and l.cs >= tl.FicoStart and l.cs < tl.FicoEnd
    and lh.CLTV > tl.ltvStart and lh.CLTV <= tl.LtvEnd
    and l.cs >= tp.FICObucketStart and l.cs < tp.FICObucketEnd
    and lh.CLTV > tp.LTVBucketStart and lh.CLTV <= tp.LTVBucketEnd
    and l.cs >= tcp.FICObucketStart and l.cs < tcp.FICObucketEnd
    and l.OrigLTV > tcp.LTVBucketStart and l.OrigLTV <= tcp.LTVBucketEnd
    and l.numUnits = tl.numUnits
    and t.datebucket = tl.asofdate
    and pre.asOfdate = t.asOfDate
    and startmonth = l.firstPaymtDt
    and enddate = t.asOfDate
    and t.asOfDate = @asof
    --and t.asOfDate <= '2015-06-11'
    group by t.asOfDate
    order by t.asOfDate asc
end