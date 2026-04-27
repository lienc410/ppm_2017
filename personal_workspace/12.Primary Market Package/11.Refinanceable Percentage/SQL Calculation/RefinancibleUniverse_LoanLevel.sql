------------------------------------------------------------------------
------------------procedure for the loan level model
------------------------------------------------------------------------
--alter procedure Lien_Test (@asof Date) 
create procedure RefinancibleUniverse_LoanLevel (@asof Date) 
as
begin

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

COMMIT


------------------- Pre2005 Pool level adjestment table ---------------------------
DROP TABLE IF EXISTS #Pre2005
select t.asOfDate, 
refinancible = sum(case when f.wac - t.SeriesNumValue >= 0.5 then f.currentBalance else 0 end)/sum(f.currentBalance),  
--refinancible_satoAdj = sum(case when f.wac - t.SeriesNumValue -s.SATO/100.0 >= 0.5 then f.currentBalance else 0 end)/sum(f.currentBalance)
ITMBalance = sum(case when f.wac - t.SeriesNumValue >= 0.5 then f.currentBalance else 0 end),
currBalance = sum(f.currentBalance)
into #Pre2005
from fhl.sec p, fhl.secFactor f,  #tempone t, fhl.secSupp s
where p.issueId = f.issueId
and p.issueId = s.issueId
and f.asOf = s.asOf
and p.collateralType = 'LOAN' 
and p.marketTicker in ('FGLMC')
--and year(t.asOfDate) * 100 + month(t.asOfDate) = year(f.asOf)* 100 + month(f.asOf)
and t.lastmonth = f.asOf
and t.asOfDate >= '20110101'
and p.issueDate <= '20051201'
--and f.CalcOrigMonth > 200906
group by t.asOfDate
order by t.asOfDate

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
select t.asOfDate,
       refinanceible = sum(case when l.OrigNoteRate 
					+ (case when l.PctMtgIns > 0 then tcp.PMI/100 else 0 end) 
					- t.SeriesNumValue 
					- (case when l.calcorigmonth_LL <= 200906 then (case when tl.totalLLPA > 0.75 then 0.75 else tl.totalLLPA end) else tl.totalLLPA end)/4 
					- (case when l.calcorigmonth_LL <= 200906 then 0 else tp.PMI/100 end) >= 0.5 
					then (case when lh.currentRpb > 0 then lh.currentRpb  + pre.ITMBalance else 0.000001 end) else 0 end)
				/sum(case when lh.currentRpb > 0 then lh.currentRpb + pre.currBalance else 0.000001 end)
from fhl.sec p, fhl.PIV_Loan l, fhl.PIV_LoanHist lh, #tempone t, #tempLLPA tl, #tempPMI tp, #tempCurrentPayingPMI tcp, #Pre2005 pre
where p.issueId = l.issueId
and l.issueId = lh.issueId
and l.loanSeqNum = lh.loanSeqNum
and p.collateralType = 'LOAN' 
and l.marketTicker in ('FGLMC')
and l.marketTicker = p.marketTicker
--and t.asOf = lh.asOf
--and lh.asOf >= '2011-01-01'
and t.lastmonth = lh.asOf
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
--and DATEDIFF(day, t.datebucket, tl.asofdate) = 0
--and l.calcorigmonth_LL <= 200906
and t.asOfDate = @asof
group by t.asOfDate
order by t.asOfDate

end


