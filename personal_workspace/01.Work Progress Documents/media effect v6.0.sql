------------- PMMS weekly survey 1-point rate --------------------
DROP TABLE IF EXISTS #GNMSpread;
select AsOfDate, 
    d.SeriesNumvalue as spread
into #GNMSpread
from report.TimeSeriesMeta M
join report.TimeSeries D on M.TimeSeriesMetaId = D.TimeSeriesMetaId
and M.Source = 'PIV'
and M.TickerName  ='GINNIE_30YR'
and M.SeriesType in ('WAC_SPREAD')
and ModelType = 'ScaleMtgRateModel v4.0'
--and AsOfDate = '20180601'
;


DROP TABLE IF EXISTS #mtgRate;
select --top 2
    D.AsOfDate,
    convert(date, year(D.asOfDate) || '-' || month(D.asOfDate) || '-01') as AsOf,
    convert(date, dateadd(month, -1, AsOf)) as lastmonth,
    ConvRate = sum(case when M.SeriesType = 'Points_US' then (1.0 - d.SeriesNumvalue)/-4.0 else d.SeriesNumvalue end),
    GNMRate = ConvRate + spread
into #mtgRate
from report.TimeSeriesMeta M
join report.TimeSeries D on M.TimeSeriesMetaId = D.TimeSeriesMetaId
and M.Source = 'Freddie'
and M.TickerName  ='PMMS_FRM_30YR'
and M.SeriesType in ('Points_US','Rate_US')
join #GNMSpread gs on gs.AsOfDate = lastmonth
group by D.AsOfDate, spread
order by D.AsOfDate DESC;
Commit;

------------------------- main select for the loan/pool combined version model -------------------------------
DROP TABLE IF EXISTS #refiUniverse;
SELECT 
    asOfDate,
    refinanceable = sum(case when (origNoteRate + origPMI/100) - (ConvRate + currLLPA/400 + currPMI/100) - fixed_cost/100 >= 0.25 then currentRpb 
                             when (origNoteRate + origPMI/100) - (GNMRate + currMIP/100) - fixed_cost/100 >= 0.25 then currentRpb 
                             else 0 end)/sum(case when currentRpb is not NULL THEN currentRpb ELSE 0.000001 END) 
INTO #refiUniverse
FROM scale.FHL_LoanIncentive sli 
JOIN #mtgRate mtg on mtg.lastmonth = sli.asOf
JOIN scale.FHL_Loan_Dev sl on sli.loanSeqNum = sl.loanSeqNum and sl.version = '9.98'--(SELECT originationVersion_LL FROM scale.ModelVersionConfig WHERE appType = 'PROD' AND agency = 'FHL' AND tickerName = 'FGLMC')
JOIN fhl.PIV_loanHist clh on sli.loanSeqNum = clh.loanSeqNum and sli.asof = clh.asof
WHERE sli.version = '9.98'--(SELECT IncentiveVersion_LL FROM scale.ModelVersionConfig WHERE appType = 'PROD' AND agency = 'FHL' AND tickerName = 'FGLMC')
AND marketTicker in ('FGLMC')
group by asOfDate

SELECT asofdate, refinanceable FROM #refiUniverse;