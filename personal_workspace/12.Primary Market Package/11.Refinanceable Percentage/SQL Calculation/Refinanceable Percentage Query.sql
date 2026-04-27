------------------------------------using in excel-----------------------
------------------------------------pool level FNMA-----------------------
DROP TABLE IF EXISTS #tempone;
select AsOfDate, SeriesNumValue = sum(case when M.SeriesType = 'Points_US' then (1.0 - d.SeriesNumvalue)/-4.0 else d.SeriesNumvalue end)
--into #tempone
from report.TimeSeriesMeta M, report.TimeSeries D
where M.TimeSeriesMetaId = D.TimeSeriesMetaId
and M.Source = 'Freddie'
and M.TickerName  ='PMMS_FRM_30YR'
and M.SeriesType in ('Points_US','Rate_US')
group by AsOfDate
order by AsOfDate DESC

select t.asOfDate, 
refinancible = sum(case when f.wac - t.SeriesNumValue >= 0.5 then f.currentBalance else 0 end)/sum(f.currentBalance),  
--refinancible_satoAdj = sum(case when f.wac - t.SeriesNumValue -s.SATO/100.0 >= 0.5 then f.currentBalance else 0 end)/sum(f.currentBalance)
ITMBalance = sum(case when f.wac - t.SeriesNumValue >= 0.5 then f.currentBalance else 0 end),
currBalance = sum(f.currentBalance)
from fnm.sec p, fnm.secFactor f,  #tempone t, fnm.secSupp s
where p.issueId = f.issueId
and p.issueId = s.issueId
and f.asOf = s.asOf
and p.collateralType = 'LOAN' 
and p.marketTicker in ('FNCL')
and year(t.asOfDate) * 100 + month(t.asOfDate) = year(f.asOf)* 100 + month(f.asOf)
and t.asOfDate >= '20150101'
group by t.asOfDate
order by t.asOfDate

------------------------------------pool level FHL-----------------------
select t.asOfDate, 
refinancible = sum(case when f.wac - t.SeriesNumValue >= 0.5 then f.currentBalance else 0 end)/sum(f.currentBalance),  
--refinancible_satoAdj = sum(case when f.wac - t.SeriesNumValue -s.SATO/100.0 >= 0.5 then f.currentBalance else 0 end)/sum(f.currentBalance)
ITMBalance = sum(case when f.wac - t.SeriesNumValue >= 0.5 then f.currentBalance else 0 end),
currBalance = sum(f.currentBalance)
from fhl.sec p, fhl.secFactor f,  #tempone t, fhl.secSupp s
where p.issueId = f.issueId
and p.issueId = s.issueId
and f.asOf = s.asOf
and p.collateralType = 'LOAN' 
and p.marketTicker in ('FGLMC')
and year(t.asOfDate) * 100 + month(t.asOfDate) = year(f.asOf)* 100 + month(f.asOf)
and t.asOfDate >= '20110101'
--and f.CalcOrigMonth > 200906
group by t.asOfDate
order by t.asOfDate



------------------------------------loan level  Freddie-----------------------
select AsOfDate, SeriesNumValue = sum(case when M.SeriesType = 'Points_US' then (1.0 - d.SeriesNumvalue)/-4.0 else d.SeriesNumvalue end)
into #tempone
from report.TimeSeriesMeta M, report.TimeSeries D
where M.TimeSeriesMetaId = D.TimeSeriesMetaId
and M.Source = 'Freddie'
and M.TickerName  ='PMMS_FRM_30YR'
and M.SeriesType in ('Points_US','Rate_US')
group by AsOfDate
order by AsOfDate DESC

select t.asOfDate,
refinanceible = sum(case when l.OrigNoteRate - t.SeriesNumValue >= 0.5 then (case when lh.currentRpb > 0 then lh.currentRpb else 0.000001 end) else 0 end)/sum(case when lh.currentRpb > 0 then lh.currentRpb else 0.000001 end),
ITMBalance = sum(case when l.OrigNoteRate - t.SeriesNumValue >= 0.5 then (case when lh.currentRpb > 0 then lh.currentRpb else 0.000001 end) else 0 end),
currBalance = sum(case when lh.currentRpb > 0 then lh.currentRpb else 0.000001 end)
from fhl.sec p, fhl.PIV_Loan l, fhl.PIV_LoanHist lh, #tempone t
where p.issueId = l.issueId
and l.issueId = lh.issueId
and l.loanSeqNum = lh.loanSeqNum
and p.collateralType = 'LOAN' 
and l.marketTicker in ('FGLMC')
and l.marketTicker = p.marketTicker
and year(t.asOfDate) * 100 + month(t.asOfDate) = year(lh.asOf)* 100 + month(lh.asOf)
and t.asOfDate >= '20150301'
group by t.asOfDate
order by t.asOfDate

------------------------------------loan level  Fannie-----------------------
select t.asOfDate,
refinanceible = sum(case when l.OrigNoteRate - t.SeriesNumValue >= 0.5 then (case when lh.currentRpb > 0 then lh.currentRpb else 0.000001 end) else 0 end)/sum(case when lh.currentRpb > 0 then lh.currentRpb else 0.000001 end),
ITMBalance = sum(case when l.OrigNoteRate - t.SeriesNumValue >= 0.5 then (case when lh.currentRpb > 0 then lh.currentRpb else 0.000001 end) else 0 end),
currBalance = sum(case when lh.currentRpb > 0 then lh.currentRpb else 0.000001 end)
from fnm.sec p, fnm.PIV_Loan l, fnm.PIV_LoanHist lh, #tempone t
where p.issueId = l.issueId
and l.issueId = lh.issueId
and l.loanSeqNum = lh.loanSeqNum
and p.collateralType = 'LOAN' 
and l.marketTicker in ('FNCL')
and l.marketTicker = p.marketTicker
and year(t.asOfDate) * 100 + month(t.asOfDate) = year(lh.asOf)* 100 + month(lh.asOf)
and t.asOfDate >= '20150301'
group by t.asOfDate
order by t.asOfDate


----------------------------------LLPA----------------------------------------
select * from report.LLPAUNITLTV    ----------------Units
select * from report.LLPAFicoLTV    --y--------------Base 
select * from report.LLPAOCCLTV     --y--------------Occupency
select * from report.LLPAHighLtv    --y-------------HighLtv
select * from report.LLPAAMDC       --y--------------AMDC

select * from fhl.PIV_loanhist

-------------------------------Combine LLPA tables---------------------------
DROP TABLE IF EXISTS #tempLLPA;
select f.FicoStart, f.FicoEnd, f.LtvStart, f.LtvEnd, o.occtype, u.numUnits, f.LLPA as BaseLLTV, a.LLPA as AMDC, HighLTV = (case when l.llpa is null then 999 else l.llpa end), 
        Occp = (case when o.llpa is null then 999 else o.llpa end), UnitL = (case when u.llpa is null then 999 else u.llpa end),
        totalLLPA = (BaseLLTV + AMDC + HighLTV + Occp + UnitL)/100
into #tempLLPA
from report.LLPAFicoLTV f
join report.LLPAAMDC a 
on f.FicoStart = a.FicoStart 
and f.FicoEnd = a.FicoEnd 
and f.LtvStart = a.LtvStart
and f.LtvEnd = a.LtvEnd
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
where f.AsofDate = '2015-01-07'
and a.AsofDate = '2014-01-08'
and l.asofdate = '2013-12-16'
and o.asofdate = '2013-11-14'
and u.asofdate = '2013-11-14'

select * from #tempLLPA
drop table #tempLLPA


----------------------------------Loan with LLPA---------------------------------------
DROP TABLE IF EXISTS #tempLLPA;
select f.FicoStart, f.FicoEnd, f.LtvStart, f.LtvEnd, o.occtype, u.numUnits, f.LLPA as BaseLLTV, a.LLPA as AMDC, HighLTV = (case when l.llpa is null then 999 else l.llpa end), 
        Occp = (case when o.llpa is null then 999 else o.llpa end), UnitL = (case when u.llpa is null then 999 else u.llpa end),
        totalLLPA = (BaseLLTV + AMDC + HighLTV + Occp + UnitL)/100
into #tempLLPA
from report.LLPAFicoLTV f
join report.LLPAAMDC a 
on f.FicoStart = a.FicoStart 
and f.FicoEnd = a.FicoEnd 
and f.LtvStart = a.LtvStart
and f.LtvEnd = a.LtvEnd
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
where f.AsofDate = '2015-01-07'
and a.AsofDate = '2014-01-08'
and l.asofdate = '2013-12-16'
and o.asofdate = '2013-11-14'
and u.asofdate = '2013-11-14'
;
COMMIT;

CREATE INDEX idx_templla_occType ON #tempLLPA(occType);
CREATE INDEX idx_templla_numUnits ON #tempLLPA(numUnits);
COMMIT;

DROP TABLE IF EXISTS #tempone;
select 
    AsOfDate,
    convert(date, year(asOfDate) || '-' || month(asOfDate) || '-01') as AsOf,
    SeriesNumValue = sum(case when M.SeriesType = 'Points_US' then (1.0 - d.SeriesNumvalue)/-4.0 else d.SeriesNumvalue end)
into #tempone
from report.TimeSeriesMeta M, report.TimeSeries D
where M.TimeSeriesMetaId = D.TimeSeriesMetaId
and M.Source = 'Freddie'
and M.TickerName  ='PMMS_FRM_30YR'
and M.SeriesType in ('Points_US','Rate_US')
group by AsOfDate
order by AsOfDate DESC
;
COMMIT;

CREATE INDEX idx_temp_asofdate ON #tempone(AsOfDate);
CREATE INDEX idx_temp_asof ON #tempone(AsOf);
COMMIT;


select * from PMI

select t.asOfDate,
refinanceible = sum(case when l.OrigNoteRate - t.SeriesNumValue - tl.totalLLPA/4 >= 0.5 
                    then (case when lh.currentRpb > 0 then lh.currentRpb else 0.000001 end) else 0 end)/sum(case when lh.currentRpb > 0 then lh.currentRpb else 0.000001 end)
--ITMBalance = sum(case when l.OrigNoteRate - t.SeriesNumValue - tl.totalLLPA/4 >= 0.5 then (case when lh.currentRpb > 0 then lh.currentRpb else 0.000001 end) else 0 end),
--currBalance = sum(case when lh.currentRpb > 0 then lh.currentRpb else 0.000001 end)
from fhl.sec p, fhl.PIV_Loan l, fhl.PIV_LoanHist lh, #tempone t, #tempLLPA tl
where p.issueId = l.issueId
and l.issueId = lh.issueId
and l.loanSeqNum = lh.loanSeqNum
and p.collateralType = 'LOAN' 
and l.marketTicker in ('FGLMC')
and l.marketTicker = p.marketTicker
and t.asOf = lh.asOf
and lh.asOf >= '2011-01-01'
--and lh.asOf < '2011-03-01'
and l.occType = tl.occType
and l.cs >= tl.FicoStart and l.cs < tl.FicoEnd
and lh.CLTV > tl.ltvStart and lh.CLTV <= tl.LtvEnd
and l.numUnits = tl.numUnits
--and l.calcorigmonth_LL > 200906
group by t.asOfDate
order by t.asOfDate

-------------------------------Combine LLPA tables--------Time dependent-------------------
DROP TABLE IF EXISTS #tempLLPA;
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
;
COMMIT;

CREATE INDEX idx_templla_asof ON #tempLLPA(AsOfDate);
CREATE INDEX idx_templla_occType ON #tempLLPA(occType);
CREATE INDEX idx_templla_numUnits ON #tempLLPA(numUnits);
COMMIT;

select * from #tempLLPA
-------------------------------Loan with LLPA Time Dependent---------------------------
DROP TABLE IF EXISTS #tempone;
select 
    AsOfDate,
    convert(date, year(asOfDate) || '-' || month(asOfDate) || '-01') as AsOf,
    datebucket = convert(date, (case when asOfDate <= '2013-12-16' then '2011-09-22'
                when asOfDate <= '2014-01-08' then '2013-12-16'
                when asOfDate <= '2015-01-07' then '2014-01-08'
                else '2015-01-07' end)),
    SeriesNumValue = sum(case when M.SeriesType = 'Points_US' then (1.0 - d.SeriesNumvalue)/-4.0 else d.SeriesNumvalue end)
into #tempone
from report.TimeSeriesMeta M, report.TimeSeries D
where M.TimeSeriesMetaId = D.TimeSeriesMetaId
and M.Source = 'Freddie'
and M.TickerName  ='PMMS_FRM_30YR'
and M.SeriesType in ('Points_US','Rate_US')
group by AsOfDate
order by AsOfDate DESC
;
COMMIT;

CREATE INDEX idx_temp_asofdate ON #tempone(AsOfDate);
CREATE INDEX idx_temp_asof ON #tempone(AsOf);
CREATE INDEX idx_temp_datebucket ON #tempone(datebucket);
COMMIT;

SELECT * FROM #tempone;
SELECT * FROM #tempLLPA;
SELECT count(1) FROM fhl.PIV_LoanHist;

select t.asOfDate,
--t.datebucket,
--tl.totalLLPA, tl.asofdate,
refinanceible = sum(case when l.OrigNoteRate - t.SeriesNumValue - tl.totalLLPA/4 >= 0.5 then (case when lh.currentRpb > 0 then lh.currentRpb else 0.000001 end) else 0 end)/sum(case when lh.currentRpb > 0 then lh.currentRpb else 0.000001 end)
--ITMBalance = sum(case when l.OrigNoteRate - t.SeriesNumValue - tl.totalLLPA/4 >= 0.5 then (case when lh.currentRpb > 0 then lh.currentRpb else 0.000001 end) else 0 end),
--currBalance = sum(case when lh.currentRpb > 0 then lh.currentRpb else 0.000001 end)
from fhl.sec p, fhl.PIV_Loan l, fhl.PIV_LoanHist lh, #tempone t, #tempLLPA tl
where p.issueId = l.issueId
and l.issueId = lh.issueId
and l.loanSeqNum = lh.loanSeqNum
and p.collateralType = 'LOAN' 
and l.marketTicker in ('FGLMC')
and l.marketTicker = p.marketTicker
and t.asOf = lh.asOf
and lh.asOf >= '2011-01-01'
and l.occType = tl.occType
and l.cs >= tl.FicoStart and l.cs < tl.FicoEnd
and lh.CLTV > tl.ltvStart and lh.CLTV <= tl.LtvEnd
and l.numUnits = tl.numUnits
and t.datebucket = tl.asofdate
--and DATEDIFF(day, t.datebucket, tl.asofdate) = 0
--and l.calcorigmonth_LL > 200906
group by t.asOfDate
order by t.asOfDate
;



----------------------------------Loan level with PMI---------------------------------------
DROP TABLE IF EXISTS #tempPMI;
select * 
into #tempPMI
from PMI
where Asofdate >= '20140101'
and LoanPurpose = 'REFI'
;
COMMIT;



DROP TABLE IF EXISTS #tempone;
select 
    AsOfDate,
    convert(date, year(asOfDate) || '-' || month(asOfDate) || '-01') as AsOf,
    datebucket = convert(date, (case when asOfDate <= '2013-12-16' then '2011-09-22'
                when asOfDate <= '2014-01-08' then '2013-12-16'
                when asOfDate <= '2015-01-07' then '2014-01-08'
                else '2015-01-07' end)),
    SeriesNumValue = sum(case when M.SeriesType = 'Points_US' then (1.0 - d.SeriesNumvalue)/-4.0 else d.SeriesNumvalue end)
into #tempone
from report.TimeSeriesMeta M, report.TimeSeries D
where M.TimeSeriesMetaId = D.TimeSeriesMetaId
and M.Source = 'Freddie'
and M.TickerName  ='PMMS_FRM_30YR'
and M.SeriesType in ('Points_US','Rate_US')
group by AsOfDate
order by AsOfDate DESC
;
COMMIT;

CREATE INDEX idx_temp_asofdate ON #tempone(AsOfDate);
CREATE INDEX idx_temp_asof ON #tempone(AsOf);
CREATE INDEX idx_temp_datebucket ON #tempone(datebucket);
COMMIT;


DROP TABLE IF EXISTS #tempLLPA;
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
;
COMMIT;

CREATE INDEX idx_templla_asof ON #tempLLPA(AsOfDate);
CREATE INDEX idx_templla_occType ON #tempLLPA(occType);
CREATE INDEX idx_templla_numUnits ON #tempLLPA(numUnits);
COMMIT;



select t.asOfDate,
--t.datebucket,
--tl.totalLLPA, tl.asofdate,
refinanceible = sum(case when l.OrigNoteRate - t.SeriesNumValue - tl.totalLLPA/4 - tp.PMI/100 >= 0.5 
                then (case when lh.currentRpb > 0 then lh.currentRpb else 0.000001 end) else 0 end)/sum(case when lh.currentRpb > 0 then lh.currentRpb else 0.000001 end),
--ITMBalance = sum(case when l.OrigNoteRate - t.SeriesNumValue - tl.totalLLPA/4 >= 0.5 then (case when lh.currentRpb > 0 then lh.currentRpb else 0.000001 end) else 0 end),
currBalance = sum(case when lh.currentRpb > 0 then lh.currentRpb else 0.000001 end)
from fhl.sec p, fhl.PIV_Loan l, fhl.PIV_LoanHist lh, #tempone t, #tempLLPA tl, #tempPMI tp
where p.issueId = l.issueId
and l.issueId = lh.issueId
and l.loanSeqNum = lh.loanSeqNum
and p.collateralType = 'LOAN' 
and l.marketTicker in ('FGLMC')
and l.marketTicker = p.marketTicker
and t.asOf = lh.asOf
and lh.asOf >= '2011-01-01'
and l.occType = tl.occType
and l.cs >= tl.FicoStart and l.cs < tl.FicoEnd
and lh.CLTV > tl.ltvStart and lh.CLTV <= tl.LtvEnd
and l.cs >= tp.FICObucketStart and l.cs < tp.FICObucketEnd
and lh.CLTV > tp.LTVBucketStart and lh.CLTV <= tp.LTVBucketEnd
and l.numUnits = tl.numUnits
and t.datebucket = tl.asofdate
--and DATEDIFF(day, t.datebucket, tl.asofdate) = 0
--and l.calcorigmonth_LL <= 200906
group by t.asOfDate
order by t.asOfDate
;



----------------------------------Loan level with HARP---------------------------------------
DROP TABLE IF EXISTS #tempPMI;
select * 
into #tempPMI
from PMI
where Asofdate >= '20140101'
and LoanPurpose = 'REFI'
;
COMMIT;
--PMI using MGIC "Monthly premiums for all states (except WA)", Fixed Rate 30-YEAR + Rate-and-Term Refinance


DROP TABLE IF EXISTS #tempone;
select 
    AsOfDate,
    convert(date, year(asOfDate) || '-' || month(asOfDate) || '-01') as AsOf,
    datebucket = convert(date, (case when asOfDate <= '2013-12-16' then '2011-09-22'
                when asOfDate <= '2014-01-08' then '2013-12-16'
                when asOfDate <= '2015-01-07' then '2014-01-08'
                else '2015-01-07' end)),
    SeriesNumValue = sum(case when M.SeriesType = 'Points_US' then (1.0 - d.SeriesNumvalue)/-4.0 else d.SeriesNumvalue end)
into #tempone
from report.TimeSeriesMeta M, report.TimeSeries D
where M.TimeSeriesMetaId = D.TimeSeriesMetaId
and M.Source = 'Freddie'
and M.TickerName  ='PMMS_FRM_30YR'
and M.SeriesType in ('Points_US','Rate_US')
group by AsOfDate
order by AsOfDate DESC
;
COMMIT;

CREATE INDEX idx_temp_asofdate ON #tempone(AsOfDate);
CREATE INDEX idx_temp_asof ON #tempone(AsOf);
CREATE INDEX idx_temp_datebucket ON #tempone(datebucket);
COMMIT;


DROP TABLE IF EXISTS #tempLLPA;
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
;
COMMIT;

CREATE INDEX idx_templla_asof ON #tempLLPA(AsOfDate);
CREATE INDEX idx_templla_occType ON #tempLLPA(occType);
CREATE INDEX idx_templla_numUnits ON #tempLLPA(numUnits);
COMMIT;



select t.asOfDate,
--t.datebucket,
--tl.totalLLPA, tl.asofdate,
refinanceible = sum(case when l.OrigNoteRate - t.SeriesNumValue - (case when l.calcorigmonth_LL <= 200906 then (case when tl.totalLLPA > 0.75 then 0.75 else tl.totalLLPA end) else tl.totalLLPA end)/4 
                - (case when l.calcorigmonth_LL <= 200906 then 0 else tp.PMI/100 end) >= 0.5 
                then (case when lh.currentRpb > 0 then lh.currentRpb else 0.000001 end) else 0 end)/sum(case when lh.currentRpb > 0 then lh.currentRpb else 0.000001 end)
--ITMBalance = sum(case when l.OrigNoteRate - t.SeriesNumValue - tl.totalLLPA/4 >= 0.5 then (case when lh.currentRpb > 0 then lh.currentRpb else 0.000001 end) else 0 end),
--currBalance = sum(case when lh.currentRpb > 0 then lh.currentRpb else 0.000001 end)
from fhl.sec p, fhl.PIV_Loan l, fhl.PIV_LoanHist lh, #tempone t, #tempLLPA tl, #tempPMI tp
where p.issueId = l.issueId
and l.issueId = lh.issueId
and l.loanSeqNum = lh.loanSeqNum
and p.collateralType = 'LOAN' 
and l.marketTicker in ('FGLMC')
and l.marketTicker = p.marketTicker
and t.asOf = lh.asOf
and lh.asOf >= '2011-01-01'
and l.occType = tl.occType
and l.cs >= tl.FicoStart and l.cs < tl.FicoEnd
and lh.CLTV > tl.ltvStart and lh.CLTV <= tl.LtvEnd
and l.cs >= tp.FICObucketStart and l.cs < tp.FICObucketEnd
and lh.CLTV > tp.LTVBucketStart and lh.CLTV <= tp.LTVBucketEnd
and l.numUnits = tl.numUnits
and t.datebucket = tl.asofdate
--and DATEDIFF(day, t.datebucket, tl.asofdate) = 0
--and l.calcorigmonth_LL <= 200906
group by t.asOfDate
order by t.asOfDate
;

----------------------------------Loan level with borrower's current PMI---------------------------------------
DROP TABLE IF EXISTS #tempCurrentPayingPMI;
select * 
into #tempCurrentPayingPMI
from PMI
where Asofdate >= '20140101'
and LoanPurpose = 'REFI'
;
COMMIT;

DROP TABLE IF EXISTS #tempPMI;
select * 
into #tempPMI
from PMI
where Asofdate >= '20140101'
and LoanPurpose = 'REFI'
;
COMMIT;
--PMI using MGIC "Monthly premiums for all states (except WA)", Fixed Rate 30-YEAR + Rate-and-Term Refinance


DROP TABLE IF EXISTS #tempone;
select 
    AsOfDate,
    convert(date, year(asOfDate) || '-' || month(asOfDate) || '-01') as AsOf,
    datebucket = convert(date, (case when asOfDate <= '2013-12-16' then '2011-09-22'
                when asOfDate <= '2014-01-08' then '2013-12-16'
                when asOfDate <= '2015-01-07' then '2014-01-08'
                else '2015-01-07' end)),
    SeriesNumValue = sum(case when M.SeriesType = 'Points_US' then (1.0 - d.SeriesNumvalue)/-4.0 else d.SeriesNumvalue end)
into #tempone
from report.TimeSeriesMeta M, report.TimeSeries D
where M.TimeSeriesMetaId = D.TimeSeriesMetaId
and M.Source = 'Freddie'
and M.TickerName  ='PMMS_FRM_30YR'
and M.SeriesType in ('Points_US','Rate_US')
group by AsOfDate
order by AsOfDate DESC
;
COMMIT;

CREATE INDEX idx_temp_asofdate ON #tempone(AsOfDate);
CREATE INDEX idx_temp_asof ON #tempone(AsOf);
CREATE INDEX idx_temp_datebucket ON #tempone(datebucket);
COMMIT;


DROP TABLE IF EXISTS #tempLLPA;
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
;
COMMIT;

CREATE INDEX idx_templla_asof ON #tempLLPA(AsOfDate);
CREATE INDEX idx_templla_occType ON #tempLLPA(occType);
CREATE INDEX idx_templla_numUnits ON #tempLLPA(numUnits);
COMMIT;


select t.asOfDate,
       refinanceible = sum(case when l.OrigNoteRate 
					+ (case when l.PctMtgIns > 0 then tcp.PMI/100 else 0 end) 
					- t.SeriesNumValue 
					- (case when l.calcorigmonth_LL <= 200906 then (case when tl.totalLLPA > 0.75 then 0.75 else tl.totalLLPA end) else tl.totalLLPA end)/4 
					- (case when l.calcorigmonth_LL <= 200906 then 0 else tp.PMI/100 end) >= 0.5 
					then (case when lh.currentRpb > 0 then lh.currentRpb else 0.000001 end) else 0 end)
				/sum(case when lh.currentRpb > 0 then lh.currentRpb else 0.000001 end)				
from fhl.sec p, fhl.PIV_Loan l, fhl.PIV_LoanHist lh, #tempone t, #tempLLPA tl, #tempPMI tp, #tempCurrentPayingPMI tcp
where p.issueId = l.issueId
and l.issueId = lh.issueId
and l.loanSeqNum = lh.loanSeqNum
and p.collateralType = 'LOAN' 
and l.marketTicker in ('FGLMC')
and l.marketTicker = p.marketTicker
and t.asOf = lh.asOf
and lh.asOf >= '2011-01-01'
and l.occType = tl.occType
and l.cs >= tl.FicoStart and l.cs < tl.FicoEnd
and lh.CLTV > tl.ltvStart and lh.CLTV <= tl.LtvEnd
and l.cs >= tp.FICObucketStart and l.cs < tp.FICObucketEnd
and lh.CLTV > tp.LTVBucketStart and lh.CLTV <= tp.LTVBucketEnd
and l.cs >= tcp.FICObucketStart and l.cs < tcp.FICObucketEnd
and l.OrigLTV > tcp.LTVBucketStart and l.OrigLTV <= tcp.LTVBucketEnd
and l.numUnits = tl.numUnits
and t.datebucket = tl.asofdate
--and DATEDIFF(day, t.datebucket, tl.asofdate) = 0
--and l.calcorigmonth_LL <= 200906
group by t.asOfDate
order by t.asOfDate
;



----------------------------------Loan level with Pre 2005 Adj---------------------------------------
DROP TABLE IF EXISTS #Pre2005;
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
and year(t.asOfDate) * 100 + month(t.asOfDate) = year(f.asOf)* 100 + month(f.asOf)
and t.asOfDate >= '20110101'
and p.issueDate <= '20051201'
--and f.CalcOrigMonth > 200906
group by t.asOfDate
order by t.asOfDate
;
COMMIT;


DROP TABLE IF EXISTS #tempCurrentPayingPMI;
select * 
into #tempCurrentPayingPMI
from PMI
where Asofdate >= '20140101'
and LoanPurpose = 'REFI'
;
COMMIT;

DROP TABLE IF EXISTS #tempPMI;
select * 
into #tempPMI
from PMI
where Asofdate >= '20140101'
and LoanPurpose = 'REFI'
;
COMMIT;
--PMI using MGIC "Monthly premiums for all states (except WA)", Fixed Rate 30-YEAR + Rate-and-Term Refinance


DROP TABLE IF EXISTS #tempone;
select 
    AsOfDate,
    convert(date, year(asOfDate) || '-' || month(asOfDate) || '-01') as AsOf,
    datebucket = convert(date, (case when asOfDate <= '2013-12-16' then '2011-09-22'
                when asOfDate <= '2014-01-08' then '2013-12-16'
                when asOfDate <= '2015-01-07' then '2014-01-08'
                else '2015-01-07' end)),
    SeriesNumValue = sum(case when M.SeriesType = 'Points_US' then (1.0 - d.SeriesNumvalue)/-4.0 else d.SeriesNumvalue end)
into #tempone
from report.TimeSeriesMeta M, report.TimeSeries D
where M.TimeSeriesMetaId = D.TimeSeriesMetaId
and M.Source = 'Freddie'
and M.TickerName  ='PMMS_FRM_30YR'
and M.SeriesType in ('Points_US','Rate_US')
group by AsOfDate
order by AsOfDate DESC
;
COMMIT;

CREATE INDEX idx_temp_asofdate ON #tempone(AsOfDate);
CREATE INDEX idx_temp_asof ON #tempone(AsOf);
CREATE INDEX idx_temp_datebucket ON #tempone(datebucket);
COMMIT;


DROP TABLE IF EXISTS #tempLLPA;
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
;
COMMIT;

CREATE INDEX idx_templla_asof ON #tempLLPA(AsOfDate);
CREATE INDEX idx_templla_occType ON #tempLLPA(occType);
CREATE INDEX idx_templla_numUnits ON #tempLLPA(numUnits);
COMMIT;


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
and t.asOf = lh.asOf
and lh.asOf >= '2011-01-01'
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
group by t.asOfDate
order by t.asOfDate
;




----------------------------------------------------
-------- Low Rate Matrix---------------
--------------------------------------------------
--------PMMS 1-Point Rate
drop table if exists #surveyRates;
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
;
commit;

--------construct time period
drop table if exists #lowestRate;
select m1.asOfdate StartDate, m2.asofdate EndDate, m1.AsOfMonth StartMonth, m2.AsOfMonth EndMonth, cast ( NULL as numeric(10,5)) as minSurveyRate
into #lowestRate
from #surveyRates m1, #surveyRates m2 
where  EndDate >= StartDate
--and StartDate = '2001-01-05'
group by StartDate,StartMonth, EndDate, EndMonth
;

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
;
commit;

---------Keep only the first update date as startDate, last Thursday as EndDate
drop table if exists #lowestRate_MonthlyTable;
select * 
into #lowestRate_MonthlyTable
from #lowestRate t
where startdate = (select min(startdate) from #lowestRate where startmonth = t.startmonth)
--and enddate = (select max(enddate) from #lowestRate where endmonth = t.endmonth)
;


--------------Select part
select lh.asof, r.* 
from #lowestRate_MonthlyTable r, fhl.PIV_loanhist lh, fhl.PIV_loan l
where l.loanSeqNum =lh.loanseqNum
    and marketTicker = 'FGLMC'
    and lh.loanSeqNum = 'A56672000005'
    and startmonth = l.firstPaymtDt
    and endmonth = lh.asof
order by lh.asof, startdate, EndDate desc

select * 
from #lowestRate_MonthlyTable
where startmonth = '2014-05-01'





----------------------------------Loan level with First-time Low---------------------------------------
DROP TABLE IF EXISTS #tempone;
select 
    AsOfDate,
    convert(date, year(asOfDate) || '-' || month(asOfDate) || '-01') as AsOf,
    datebucket = convert(date, (case when asOfDate <= '2013-12-16' then '2011-09-22'
                when asOfDate <= '2014-01-08' then '2013-12-16'
                when asOfDate <= '2015-01-07' then '2014-01-08'
                else '2015-01-07' end)),
    SeriesNumValue = sum(case when M.SeriesType = 'Points_US' then (1.0 - d.SeriesNumvalue)/-4.0 else d.SeriesNumvalue end)
into #tempone
from report.TimeSeriesMeta M, report.TimeSeries D
where M.TimeSeriesMetaId = D.TimeSeriesMetaId
and M.Source = 'Freddie'
and M.TickerName  ='PMMS_FRM_30YR'
and M.SeriesType in ('Points_US','Rate_US')
group by AsOfDate
order by AsOfDate DESC
;
COMMIT;

DROP TABLE IF EXISTS #Pre2005;
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
and year(t.asOfDate) * 100 + month(t.asOfDate) = year(f.asOf)* 100 + month(f.asOf)
and t.asOfDate >= '20110101'
and p.issueDate <= '20051201'
--and f.CalcOrigMonth > 200906
group by t.asOfDate
order by t.asOfDate
;
COMMIT;


DROP TABLE IF EXISTS #tempCurrentPayingPMI;
select * 
into #tempCurrentPayingPMI
from PMI
where Asofdate >= '20140101'
and LoanPurpose = 'REFI'
;
COMMIT;

DROP TABLE IF EXISTS #tempPMI;
select * 
into #tempPMI
from PMI
where Asofdate >= '20140101'
and LoanPurpose = 'REFI'
;
COMMIT;
--PMI using MGIC "Monthly premiums for all states (except WA)", Fixed Rate 30-YEAR + Rate-and-Term Refinance


CREATE INDEX idx_temp_asofdate ON #tempone(AsOfDate);
CREATE INDEX idx_temp_asof ON #tempone(AsOf);
CREATE INDEX idx_temp_datebucket ON #tempone(datebucket);
COMMIT;


DROP TABLE IF EXISTS #tempLLPA;
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
;
COMMIT;

CREATE INDEX idx_templla_asof ON #tempLLPA(AsOfDate);
CREATE INDEX idx_templla_occType ON #tempLLPA(occType);
CREATE INDEX idx_templla_numUnits ON #tempLLPA(numUnits);
COMMIT;


select t.asOfDate,
       refinanceible = sum(case when t.SeriesNumValue <= r.minSurveyRate then(
					case when l.OrigNoteRate 
					+ (case when l.PctMtgIns > 0 then tcp.PMI/100 else 0 end) 
					- t.SeriesNumValue 
					- (case when l.calcorigmonth_LL <= 200906 then (case when tl.totalLLPA > 0.75 then 0.75 else tl.totalLLPA end) else tl.totalLLPA end)/4 
					- (case when l.calcorigmonth_LL <= 200906 then 0 else tp.PMI/100 end) >= 0.5 
					then (case when lh.currentRpb > 0 then lh.currentRpb  + pre.ITMBalance else 0.000001 end) else 0 end) else 0 end)
				/sum(case when lh.currentRpb > 0 then lh.currentRpb + pre.currBalance else 0.000001 end)
from fhl.sec p, fhl.PIV_Loan l, fhl.PIV_LoanHist lh, #tempone t, #tempLLPA tl, #tempPMI tp, #tempCurrentPayingPMI tcp, #Pre2005 pre, #lowestRate_MonthlyTable r
where p.issueId = l.issueId
and l.issueId = lh.issueId
and l.loanSeqNum = lh.loanSeqNum
and p.collateralType = 'LOAN' 
and l.marketTicker in ('FGLMC')
and l.marketTicker = p.marketTicker
and t.asOf = lh.asOf
and lh.asOf >= '2011-01-01'
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
    and startmonth = l.firstPaymtDt
    and enddate = t.asOfDate
--and t.asOfDate = '2013-07-03'
group by t.asOfDate
order by t.asOfDate
;


