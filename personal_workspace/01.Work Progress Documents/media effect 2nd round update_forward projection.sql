-- Creates the 30 YR FRM Rate (point ajdusted)
DROP TABLE IF EXISTS #Mtg30YrRates_monthly;
SELECT
    TickerName as SeriesName,
    AsOfDate as asOf, 
    convert(date, dateadd(month, -1, AsOfDate)) as lastmonth,
    SeriesNumValue as MtgRate,
    wacBucket = case 
                when MtgRate <= 3.25 THEN 3.25
                when MtgRate >= 7.875 THEN 7.875
                else convert(int, MtgRate / 0.125) * 0.125 + 0.125
                end - 0.125
INTO #Mtg30YrRates_monthly
FROM report.TimeSeries ts
JOIN report.TimeSeriesMeta tsm
    ON ts.TimeSeriesMetaId = tsm.TimeSeriesMetaId
WHERE 1=1
    AND SeriesType = 'MONTHLY_MTG_RATE'
	AND ModelType = 'ScaleMtgRateModel v2.0'
    AND seriesName = 'CONVENTIONAL_30YR'
    AND asof >= '2006-12-01'
;
COMMIT;


DROP TABLE IF EXISTS #replines;
select 
s.asof,
wacBucket = case 
            when wac_with_cost <= 3.25 THEN 3.25
            when wac_with_cost >= 7.875 THEN 7.875
            else convert(int, wac_with_cost / 0.125) * 0.125 + 0.125
            end - 0.125,
wac_ = sum(wac * currentBalance) / sum(case when currentBalance > 0.0 THEN currentBalance ELSE 0.000001 END), 
wac_with_cost_ = sum(s.wac_with_cost * currentBalance) / sum(case when currentBalance > 0.0 THEN currentBalance ELSE 0.000001 END),
origPMI = sum(s.origPMI * currentBalance) / sum(case when currentBalance > 0.0 THEN currentBalance ELSE 0.000001 END), 
currentPMI = sum(s.currPMI * currentBalance) / sum(case when currentBalance > 0.0 THEN currentBalance ELSE 0.000001 END), 
currentLLPA = sum(s.currLLPA * currentBalance) / sum(case when currentBalance > 0.0 THEN currentBalance ELSE 0.000001 END), 
incentive_PL = sum(s.incentive_PL * currentBalance) / sum(case when currentBalance > 0.0 THEN currentBalance ELSE 0.000001 END) * 100, 
balance = sum(currentBalance),
media_balance_PL = sum(case when s.incentive_PL >= 0.5 then currentBalance else 0.0 end),
prepay_balance = cast(sum(prepayBalance) as numeric(20,2))
--prepay_balance = 0
into #replines
from
(
    select mtg.asOf, sf.wac, calcSchamBalance, currentBalance, origPMI, currLLPA, currPMI, 
            (sf.wac + origPMI/100.0 - mtg.MtgRate - currLLPA/400.0 - currPMI/100.0) as incentive_PL,
            (sf.wac + origPMI/100.0 - currLLPA/400.0 - currPMI/100.0) as wac_with_cost,
            pp.smmTotal,
            prepayBalance = currentBalance * pp.smmTotal
    from fhl.Sec b
    join fhl.SecFactor sf on b.secid = sf.secId and sf.couponType='FIX' and b.collateraltype='LOAN'
    join scale.fhl_poolIncentive spi on b.issueId = spi.issueId and sf.asof = spi.asof
    join #Mtg30YrRates_monthly mtg on sf.asof = mtg.lastmonth
    join scale.PoolPrepayTracking pp on pp.asof = sf.asof and pp.issueId = b.issueId 
    where b.marketTicker = 'FGLMC'
    and spi.version = '2.41'
    and pp.modelId = '2.43'
    
    UNION
    
    select mtg.asOf, sf.wac, calcSchamBalance, currentBalance, origPMI, currLLPA, currPMI, 
            (sf.wac + origPMI/100.0 - mtg.MtgRate - currLLPA/400.0 - currPMI/100.0) as incentive_PL,
            (sf.wac + origPMI/100.0 - currLLPA/400.0 - currPMI/100.0) as wac_with_cost,
            pp.smmTotal,
            prepayBalance = currentBalance * pp.smmTotal
    from fnm.Sec b
    join fnm.SecFactor sf on b.secid = sf.secId and sf.couponType='FIX' and b.collateraltype='LOAN'
    join scale.fnm_poolIncentive spi on b.issueId = spi.issueId and sf.asof = spi.asof
    join #Mtg30YrRates_monthly mtg on sf.asof = mtg.lastmonth
    join scale.PoolPrepayTracking pp on pp.asof = sf.asof and pp.issueId = b.issueId 
    where b.marketTicker = 'FNCL'
    and spi.version = '2.41'
    and pp.modelId = '2.43'
) s
where s.asof = '2016-04-01'
--where s.asof >= '2006-12-01'
group by s.asof, wacBucket;


DROP TABLE IF EXISTS #total_refi_balance;
select s.asof,
total_prepay = sum(prepay_balance)
into #total_refi_balance
from #replines s
group by s.asof
order by s.asof;

DROP TABLE IF EXISTS #replines_est;
select s.*,
asof_est = dateadd(month, +1, s.asof),
balance_est = balance - prepay_balance
into #replines_est
from #replines s
order by s.asof, s.wacBucket
;

UPDATE #replines_est s SET balance_est = balance_est + total_prepay
FROM #total_refi_balance rb
JOIN #Mtg30YrRates_monthly mtg on rb.asof = mtg.asof
WHERE mtg.wacBucket = s.wacBucket
AND rb.asof = s.asof
;


DROP TABLE IF EXISTS #media_balance;
select s.*,
media_balance_repline = case when s.wacBucket - MtgRate >= 0.50 then balance 
                when s.wacBucket + 0.125 - MtgRate >= 0.50 then balance * (s.wacBucket + 0.125 - (MtgRate + 0.5)) / (s.wacBucket + 0.125 - s.wacBucket)
                else 0.0 end
into #media_balance
from #replines_est s
join #Mtg30YrRates_monthly mtg on mtg.asof = s.asof --on mtg.asof_lag1 = s.asof;
order by s.asof, s.wacBucket
;


DROP TABLE IF EXISTS #mtm;
select 
    asof,
    media_effect_PL = sum(media_balance_PL) / sum(balance) * 100,
    media_effect_repline = sum(media_balance_repline) / sum(balance) * 100,
    mtm_adj = media_effect_PL - media_effect_repline
into #mtm
from #media_balance
group by asof
order by asof;


DROP TABLE IF EXISTS #media_balance_1m_proj;
select s.*,
media_balance_repline = case when s.wacBucket - MtgRate >= 0.50 then balance_est 
                when s.wacBucket + 0.125 - MtgRate >= 0.50 then balance_est * (s.wacBucket + 0.125 - (MtgRate + 0.5)) / (s.wacBucket + 0.125 - s.wacBucket)
                else 0.0 end
into #media_balance_1m_proj
from #replines_est s
join #Mtg30YrRates_monthly mtg on mtg.asof = s.asof_est --on mtg.asof_lag1 = s.asof;
order by s.asof, s.wacBucket
;



select 
    m.asof,
    media_effect_PL = sum(m.media_balance_PL) / sum(m.balance) * 100,
    media_effect_repline = sum(pj.media_balance_repline) / sum(pj.balance_est) * 100-- + mtm_adj
from #media_balance_1m_proj pj
join #media_balance m on m.asof = pj.asof_est
join #mtm mtm on mtm.asof = m.asof
group by m.asof, mtm_adj
order by m.asof;





select 
    m.asof,
    total_balance = sum(m.balance),
    media_effect_PL = sum(m.media_balance_PL) / sum(m.balance) * 100,
    media_effect_repline = sum(pj.media_balance_repline) / sum(pj.balance_est) * 100-- + mtm_adj
from #media_balance_1m_proj pj
join #media_balance m on m.asof = pj.asof_est
join #mtm mtm on mtm.asof = m.asof
group by m.asof, mtm_adj
order by m.asof;
