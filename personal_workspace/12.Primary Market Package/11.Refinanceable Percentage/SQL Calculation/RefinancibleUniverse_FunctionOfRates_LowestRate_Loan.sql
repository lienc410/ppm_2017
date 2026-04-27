------------------------------------------------------------------------
------------------procedure for the loan level model with lowest rate - As function of rates
------------------------------------------------------------------------
--alter procedure Lien_Test (@asof Date) 
alter procedure RefinancibleUniverse_FunctionOfRates_LowestRate_Loan (@rate double, @asofdate Date, @thisweek date) 
as
begin

-------- Low Rate Matrix---------------
--------------------------------------------------
--------PMMS 1-Point Rate
drop table if exists #surveyRates
select asOfDate,
       convert(date,DateAdd(month,1,convert(date, year(asOfDate) || '-' || month(asOfDate) || '-01'))) as AsOfMonth,
       SeriesNumValue = sum(case when M.SeriesType = 'Points_US' then (1.0 - d.SeriesNumvalue)/-4.0 else d.SeriesNumvalue end) 
into #surveyRates
from report.TimeSeriesMeta M, report.TimeSeries D
where 
       M.TimeSeriesMetaId = D.TimeSeriesMetaId
       and M.Source = 'Freddie'
       and M.TickerName  ='PMMS_FRM_30YR'
       and M.SeriesType in ('Rate_US', 'Points_US')
       group by AsOfDate
       order by Asofdate
commit

--------construct time period
drop table if exists #lowestRate
select m1.asOfdate StartDate, m2.asofdate EndDate, m1.AsOfMonth StartMonth, m2.AsOfMonth EndMonth, cast ( NULL as numeric(10,5)) as minSurveyRate
into #lowestRate
from #surveyRates m1, #surveyRates m2 
where  EndDate >= StartDate
and enddate = @thisweek
--and StartDate = '2001-01-05'
group by StartDate,StartMonth, EndDate, EndMonth


---------Get lowest rate in the time period
update #lowestRate r
set minSurveyRate = t.minSurveyRate
from 
    (select r.StartDate, r.EndDate, min(m.SeriesNumValue) minSurveyRate  
    from 
      #lowestRate r ,  #surveyRates m  
    where 
           m.AsOfDate >= r.StartDate and m.AsOfDate < r.EndDate 
    group by r.StartDate, r.EndDate
    )t
where
    t.StartDate = r.StartDate
    and  t.endDate = r.EndDate
commit

---------Keep only the first update date as startDate, last Thursday as EndDate
drop table if exists #lowestRate_MonthlyTable
select * 
into #lowestRate_MonthlyTable
from #lowestRate t
where startdate = (select min(startdate) from #lowestRate where startmonth = t.startmonth)
--and enddate = (select max(enddate) from #lowestRate where endmonth = t.endmonth)



------------ The PMI that Borrowers currently paying ------------------
DROP TABLE IF EXISTS #tempCurrentPayingPMI
select * 
into #tempCurrentPayingPMI
from PMI
where Asofdate >= '20140101'
and LoanPurpose = 'REFI'
COMMIT

------------ PMI table -------------
DROP TABLE IF EXISTS #tempPMI
select * 
into #tempPMI
from PMI
where Asofdate >= '20140101'
and LoanPurpose = 'REFI'

COMMIT
--PMI using MGIC "Monthly premiums for all states (except WA)", Fixed Rate 30-YEAR + Rate-and-Term Refinance


------------- PMMS weekly survey 1-point rate --------------------
DROP TABLE IF EXISTS #tempone
select 
    AsOfDate,
    convert(Date, year(asOfDate) || '-' || month(asOfDate) || '-01') as AsOf,
    datebucket = convert(date, (case when asOfDate <= '2013-12-16' then '2011-09-22'
                when asOfDate <= '2014-01-08' then '2013-12-16'
                when asOfDate <= '2015-01-07' then '2014-01-08'
				when asOfDate < '2015-09-01' then '2015-01-07'
                else '2015-09-01' end)),
    SeriesNumValue = sum(case when M.SeriesType = 'Points_US' then (1.0 - d.SeriesNumvalue)/-4.0 else d.SeriesNumvalue end)
into #tempone
from report.TimeSeriesMeta M, report.TimeSeries D
where M.TimeSeriesMetaId = D.TimeSeriesMetaId
and M.Source = 'Freddie'
and M.TickerName  ='PMMS_FRM_30YR'
and M.SeriesType in ('Points_US','Rate_US')
group by AsOfDate
order by AsOfDate DESC

COMMIT



------------------- Pre2005 Pool level adjestment table ---------------------------
DROP TABLE IF EXISTS #Pre2005
select top 1 f.asOf,
--refinancible = sum(case when f.wac - t.SeriesNumValue >= 0.5 then f.currentBalance else 0 end)/sum(f.currentBalance),  
--refinancible_satoAdj = sum(case when f.wac - t.SeriesNumValue -s.SATO/100.0 >= 0.5 then f.currentBalance else 0 end)/sum(f.currentBalance)
ITMBalance1 = sum(case when f.wac - (@rate-0.5) >= 0.5 then f.currentBalance else 0 end),
ITMBalance2 = sum(case when f.wac - (@rate-0.4) >= 0.5 then f.currentBalance else 0 end),
ITMBalance3 = sum(case when f.wac - (@rate-0.3) >= 0.5 then f.currentBalance else 0 end),
ITMBalance4 = sum(case when f.wac - (@rate-0.2) >= 0.5 then f.currentBalance else 0 end),
ITMBalance5 = sum(case when f.wac - (@rate-0.1) >= 0.5 then f.currentBalance else 0 end),
ITMBalance6 = sum(case when f.wac - @rate >= 0.5 then f.currentBalance else 0 end),
ITMBalance7 = sum(case when f.wac - (@rate+0.1) >= 0.5 then f.currentBalance else 0 end),
ITMBalance8 = sum(case when f.wac - (@rate+0.2) >= 0.5 then f.currentBalance else 0 end),
ITMBalance9 = sum(case when f.wac - (@rate+0.3) >= 0.5 then f.currentBalance else 0 end),
ITMBalance10 = sum(case when f.wac - (@rate+0.4) >= 0.5 then f.currentBalance else 0 end),
ITMBalance11 = sum(case when f.wac - (@rate+0.5) >= 0.5 then f.currentBalance else 0 end),
currBalance = sum(f.currentBalance)
into #Pre2005
from fhl.sec p, fhl.secFactor f, fhl.secSupp s
where p.issueId = f.issueId
and p.issueId = s.issueId
and f.asOf = s.asOf
and p.collateralType = 'LOAN' 
and p.marketTicker in ('FGLMC')
and f.asOf = @asofdate
and p.issueDate <= '20051201'
--and f.CalcOrigMonth > 200906
group by f.asOf
COMMIT


----------- create index for temp table, increase execute speed ----------
CREATE INDEX idx_temp_asofdate ON #tempone(AsOfDate)
CREATE INDEX idx_temp_asof ON #tempone(AsOf)
CREATE INDEX idx_temp_datebucket ON #tempone(datebucket)
COMMIT

---------- Combine LLPA matrix ------------------
DROP TABLE IF EXISTS #tempLLPA
select f.asofdate,f.FicoStart, f.FicoEnd, f.LtvStart, f.LtvEnd, o.occtype, u.numUnits, BaseLLTV = (case when f.LLPA is null then 999 else f.LLPA end),
        a.LLPA as AMDC1,  aa.LLPA as AMDC2, AMDC = (case when AMDC1 is null then AMDC2 else AMDC1 end),
        HighLTV = (case when l.llpa is null then 999 else l.llpa end), 
        Occp = (case when o.llpa is null then 999 else o.llpa end), 
        UnitL = (case when u.llpa is null then 999 else u.llpa end),
        totalLLPA = (BaseLLTV + AMDC + HighLTV + Occp + UnitL)/100
into #tempLLPA
from report.LLPAFicoLTV f
left join report.LLPAAMDC a 
on f.FicoStart = a.FicoStart 
and f.FicoEnd = a.FicoEnd 
and f.LtvStart = a.LtvStart
and f.LtvEnd = a.LtvEnd
and a.asofdate = f.asofdate
join report.LLPAAMDC aa 
on f.FicoStart = aa.FicoStart 
and f.FicoEnd = aa.FicoEnd 
and f.LtvStart = aa.LtvStart
and f.LtvEnd = aa.LtvEnd
and aa.asofdate = '2014-01-08'
join report.LLPAHighLtv l
on f.FicoStart = l.FicoStart 
and f.FicoEnd = l.FicoEnd 
and f.LtvStart = l.LtvStart
and f.LtvEnd = l.LtvEnd
join report.LLPAOCCLTV o
on f.LtvStart = o.LtvStart
and f.LtvEnd = o.LtvEnd
join report.LLPAUNITLTV u
on f.LtvStart = u.LtvStart
and f.LtvEnd = u.LtvEnd
where l.asofdate = '2013-12-16'
and o.asofdate = '2013-11-14'
and u.asofdate = '2013-11-14'

COMMIT

CREATE INDEX idx_templla_asof ON #tempLLPA(AsOfDate)
CREATE INDEX idx_templla_occType ON #tempLLPA(occType)
CREATE INDEX idx_templla_numUnits ON #tempLLPA(numUnits)
COMMIT


------------------------- main select for the loan level model --------------------------------
select 
       refinanceible1 = sum(case when (@rate-0.5) <= r.minSurveyRate then(case when l.OrigNoteRate 
					+ (case when l.PctMtgIns > 0 then tcp.PMI/100 else 0 end) 
					- (@rate-0.5) 
					- (case when l.calcorigmonth_LL <= 200906 then (case when tl.totalLLPA > 0.75 then 0.75 else tl.totalLLPA end) else tl.totalLLPA end)/4 
					- (case when l.calcorigmonth_LL <= 200906 then 0 else tp.PMI/100 end) >= 0.5 
					then (case when lh.currentRpb > 0 then lh.currentRpb  + pre.ITMBalance1 else 0.000001 end) else 0 end) else 0 end)
				/sum(case when lh.currentRpb > 0 then lh.currentRpb + pre.currBalance else 0.000001 end),
       refinanceible2 = sum(case when (@rate-0.4) <= r.minSurveyRate then(case when l.OrigNoteRate 
					+ (case when l.PctMtgIns > 0 then tcp.PMI/100 else 0 end) 
					- (@rate-0.4) 
					- (case when l.calcorigmonth_LL <= 200906 then (case when tl.totalLLPA > 0.75 then 0.75 else tl.totalLLPA end) else tl.totalLLPA end)/4 
					- (case when l.calcorigmonth_LL <= 200906 then 0 else tp.PMI/100 end) >= 0.5 
					then (case when lh.currentRpb > 0 then lh.currentRpb  + pre.ITMBalance2 else 0.000001 end) else 0 end) else 0 end)
				/sum(case when lh.currentRpb > 0 then lh.currentRpb + pre.currBalance else 0.000001 end),
       refinanceible3 = sum(case when (@rate-0.3) <= r.minSurveyRate then(case when l.OrigNoteRate 
					+ (case when l.PctMtgIns > 0 then tcp.PMI/100 else 0 end) 
					- (@rate-0.3) 
					- (case when l.calcorigmonth_LL <= 200906 then (case when tl.totalLLPA > 0.75 then 0.75 else tl.totalLLPA end) else tl.totalLLPA end)/4 
					- (case when l.calcorigmonth_LL <= 200906 then 0 else tp.PMI/100 end) >= 0.5 
					then (case when lh.currentRpb > 0 then lh.currentRpb  + pre.ITMBalance3 else 0.000001 end) else 0 end) else 0 end)
				/sum(case when lh.currentRpb > 0 then lh.currentRpb + pre.currBalance else 0.000001 end),
       refinanceible4 = sum(case when (@rate-0.2) <= r.minSurveyRate then(case when l.OrigNoteRate 
					+ (case when l.PctMtgIns > 0 then tcp.PMI/100 else 0 end) 
					- (@rate-0.2) 
					- (case when l.calcorigmonth_LL <= 200906 then (case when tl.totalLLPA > 0.75 then 0.75 else tl.totalLLPA end) else tl.totalLLPA end)/4 
					- (case when l.calcorigmonth_LL <= 200906 then 0 else tp.PMI/100 end) >= 0.5 
					then (case when lh.currentRpb > 0 then lh.currentRpb  + pre.ITMBalance4 else 0.000001 end) else 0 end) else 0 end)
				/sum(case when lh.currentRpb > 0 then lh.currentRpb + pre.currBalance else 0.000001 end),
       refinanceible5 = sum(case when (@rate-0.1) <= r.minSurveyRate then(case when l.OrigNoteRate 
					+ (case when l.PctMtgIns > 0 then tcp.PMI/100 else 0 end) 
					- (@rate-0.1) 
					- (case when l.calcorigmonth_LL <= 200906 then (case when tl.totalLLPA > 0.75 then 0.75 else tl.totalLLPA end) else tl.totalLLPA end)/4 
					- (case when l.calcorigmonth_LL <= 200906 then 0 else tp.PMI/100 end) >= 0.5 
					then (case when lh.currentRpb > 0 then lh.currentRpb  + pre.ITMBalance5 else 0.000001 end) else 0 end) else 0 end)
				/sum(case when lh.currentRpb > 0 then lh.currentRpb + pre.currBalance else 0.000001 end),
       refinanceible6 = sum(case when @rate <= r.minSurveyRate then(case when l.OrigNoteRate 
					+ (case when l.PctMtgIns > 0 then tcp.PMI/100 else 0 end) 
					- @rate
					- (case when l.calcorigmonth_LL <= 200906 then (case when tl.totalLLPA > 0.75 then 0.75 else tl.totalLLPA end) else tl.totalLLPA end)/4 
					- (case when l.calcorigmonth_LL <= 200906 then 0 else tp.PMI/100 end) >= 0.5 
					then (case when lh.currentRpb > 0 then lh.currentRpb  + pre.ITMBalance6 else 0.000001 end) else 0 end) else 0 end)
				/sum(case when lh.currentRpb > 0 then lh.currentRpb + pre.currBalance else 0.000001 end),
       refinanceible7 = sum(case when (@rate+0.1) <= r.minSurveyRate then(case when l.OrigNoteRate 
					+ (case when l.PctMtgIns > 0 then tcp.PMI/100 else 0 end) 
					- (@rate+0.1) 
					- (case when l.calcorigmonth_LL <= 200906 then (case when tl.totalLLPA > 0.75 then 0.75 else tl.totalLLPA end) else tl.totalLLPA end)/4 
					- (case when l.calcorigmonth_LL <= 200906 then 0 else tp.PMI/100 end) >= 0.5 
					then (case when lh.currentRpb > 0 then lh.currentRpb  + pre.ITMBalance7 else 0.000001 end) else 0 end) else 0 end)
				/sum(case when lh.currentRpb > 0 then lh.currentRpb + pre.currBalance else 0.000001 end),
       refinanceible8 = sum(case when (@rate+0.2) <= r.minSurveyRate then(case when l.OrigNoteRate 
					+ (case when l.PctMtgIns > 0 then tcp.PMI/100 else 0 end) 
					- (@rate+0.2) 
					- (case when l.calcorigmonth_LL <= 200906 then (case when tl.totalLLPA > 0.75 then 0.75 else tl.totalLLPA end) else tl.totalLLPA end)/4 
					- (case when l.calcorigmonth_LL <= 200906 then 0 else tp.PMI/100 end) >= 0.5 
					then (case when lh.currentRpb > 0 then lh.currentRpb  + pre.ITMBalance8 else 0.000001 end) else 0 end) else 0 end)
				/sum(case when lh.currentRpb > 0 then lh.currentRpb + pre.currBalance else 0.000001 end),
       refinanceible9 = sum(case when (@rate+0.3) <= r.minSurveyRate then(case when l.OrigNoteRate 
					+ (case when l.PctMtgIns > 0 then tcp.PMI/100 else 0 end) 
					- (@rate+0.3)
					- (case when l.calcorigmonth_LL <= 200906 then (case when tl.totalLLPA > 0.75 then 0.75 else tl.totalLLPA end) else tl.totalLLPA end)/4 
					- (case when l.calcorigmonth_LL <= 200906 then 0 else tp.PMI/100 end) >= 0.5 
					then (case when lh.currentRpb > 0 then lh.currentRpb  + pre.ITMBalance9 else 0.000001 end) else 0 end) else 0 end)
				/sum(case when lh.currentRpb > 0 then lh.currentRpb + pre.currBalance else 0.000001 end),
       refinanceible10 = sum(case when (@rate+0.4) <= r.minSurveyRate then(case when l.OrigNoteRate 
					+ (case when l.PctMtgIns > 0 then tcp.PMI/100 else 0 end) 
					- (@rate+0.4)
					- (case when l.calcorigmonth_LL <= 200906 then (case when tl.totalLLPA > 0.75 then 0.75 else tl.totalLLPA end) else tl.totalLLPA end)/4 
					- (case when l.calcorigmonth_LL <= 200906 then 0 else tp.PMI/100 end) >= 0.5 
					then (case when lh.currentRpb > 0 then lh.currentRpb  + pre.ITMBalance10 else 0.000001 end) else 0 end) else 0 end)
				/sum(case when lh.currentRpb > 0 then lh.currentRpb + pre.currBalance else 0.000001 end),
       refinanceible11 = sum(case when (@rate+0.5) <= r.minSurveyRate then(case when l.OrigNoteRate 
					+ (case when l.PctMtgIns > 0 then tcp.PMI/100 else 0 end) 
					- (@rate+0.5) 
					- (case when l.calcorigmonth_LL <= 200906 then (case when tl.totalLLPA > 0.75 then 0.75 else tl.totalLLPA end) else tl.totalLLPA end)/4 
					- (case when l.calcorigmonth_LL <= 200906 then 0 else tp.PMI/100 end) >= 0.5 
					then (case when lh.currentRpb > 0 then lh.currentRpb  + pre.ITMBalance11 else 0.000001 end) else 0 end) else 0 end)
				/sum(case when lh.currentRpb > 0 then lh.currentRpb + pre.currBalance else 0.000001 end)
from fhl.sec p, fhl.PIV_Loan l, fhl.PIV_LoanHist lh, #tempone t, #tempLLPA tl, #tempPMI tp, #tempCurrentPayingPMI tcp, #Pre2005 pre, #lowestRate_MonthlyTable r
where p.issueId = l.issueId
and l.issueId = lh.issueId
and l.loanSeqNum = lh.loanSeqNum
and p.collateralType = 'LOAN' 
and l.marketTicker in ('FGLMC')
and l.marketTicker = p.marketTicker
and t.asof = lh.asOf
and l.occType = tl.occType
and l.cs >= tl.FicoStart and l.cs < tl.FicoEnd
and lh.CLTV > tl.ltvStart and lh.CLTV <= tl.LtvEnd
and l.cs >= tp.FICObucketStart and l.cs < tp.FICObucketEnd
and lh.CLTV > tp.LTVBucketStart and lh.CLTV <= tp.LTVBucketEnd
and l.cs >= tcp.FICObucketStart and l.cs < tcp.FICObucketEnd
and l.OrigLTV > tcp.LTVBucketStart and l.OrigLTV <= tcp.LTVBucketEnd
and l.numUnits = tl.numUnits
and t.datebucket = tl.asofdate
and t.asof = pre.asof
--and t.asOf = @asofdate
    and startmonth = l.firstPaymtDt
    and enddate = @thisweek
group by t.asOf
order by t.asOf

end




exec RefinancibleUniverse_FunctionOfRates_LowestRate_Loan 3.98, '2015-06-01', '2015-06-25'