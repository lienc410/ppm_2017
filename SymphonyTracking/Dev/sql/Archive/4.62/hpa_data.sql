-- Create Monthly HPI data for Symphony Tracking

-- Requires Extending the Time Series to the latest factor date using an 
-- Assumes of 3% HPA for missing periods
DROP TABLE IF EXISTS #HomePriceIndex_monthly;
SELECT asof, 
    NonSeasonAdjIndex as HPIndex
INTO #HomePriceIndex_monthly
FROM hpi.PIV_HomePriceIndexMonthly
WHERE transactionType = 'PURCHASE_ONLY'
AND region = 'USA'
;

DROP TABLE IF EXISTS #HPA_MA;
SELECT
    'USA' as Region,
    t1.asOf,
    t1.HPIndex as HPIndex,
    t2.HPIndex as HPIndex_1YR,
    t3.HPIndex as HPIndex_2YR,
    CASE WHEN t2.HPIndex IS NULL THEN NULL ELSE t1.HPIndex / t2.HPIndex END as HPA_1YR,
    CASE WHEN t3.HPIndex IS NULL THEN NULL ELSE t1.HPIndex / t3.HPIndex END as HPA_2YR
INTO #HPA_MA
FROM #HomePriceIndex_monthly t1
LEFT JOIN #HomePriceIndex_monthly t2
    ON t1.asOf = dateadd(month, 12, t2.asOf)
LEFT JOIN #HomePriceIndex_monthly t3
    ON t1.asOf = dateadd(month, 24, t3.asOf)
;
COMMIT;

CREATE INDEX asOf_idx ON #HPA_MA(asOf);
COMMIT;

DELETE FROM #HPA_MA WHERE HPA_1YR IS NULL;
COMMIT;

DELETE FROM #HPA_MA WHERE HPA_2YR IS NULL;
COMMIT;

------------------------------------------------------------
-- UNE TABLE
------------------------------------------------------------
drop table if exists #unemploymentRate;
select 
    b.state,
    date(dateadd(mm, 3, b.asof)) as asof,
    b.seasonallyAdjustedRate
into #unemploymentRate
from bls.UnemploymentRate b
;
commit;

drop table if exists #unemploymentRate_dflt;
select  
    sUNE.asof,
    sUne.state,
    laggedUnemployChangeSinceStatus = eUne.seasonallyAdjustedRate - sUne.seasonallyAdjustedRate
into #unemploymentRate_dflt    
from #unemploymentRate sUne, #unemploymentRate eUne
where 1=1
    and eUne.asof = dateadd(mm, 1, sUne.asof)
    and eUne.state = sUne.state
    and sUNE.asof >= '2009-07-01'
;
commit;

CREATE INDEX asOf_idx ON #unemploymentRate_dflt(asOf);
CREATE INDEX state_idx ON #unemploymentRate_dflt(state);
COMMIT;
------------------------------------------------------------
-- HPI TABLE
------------------------------------------------------------
drop table if exists #hpi;
select 
    h.region as state,
    date(dateadd(mm, 1, h.asof)) as asof,
    h.NonSeasonAdjIndex
into #hpi
from hpi.PIV_HomePriceIndexMonthly h
;
commit;

drop table if exists #hpi_dflt;
select  
    sHpi.asOf,
    sHpi.state,
    cumHPI = eHpi.NonSeasonAdjIndex / sHpi.NonSeasonAdjIndex - 1
into #hpi_dflt    
from #hpi sHpi, #hpi eHpi
where 1=1
    and dateadd(mm, 1, sHpi.asof) = eHpi.asof 
    and eHpi.state = sHpi.state
    and sHpi.asOf >= '2009-07-01'
;
commit;

CREATE INDEX asOf_idx ON #hpi_dflt(asOf);
CREATE INDEX state_idx ON #hpi_dflt(state);
COMMIT;
------------------------------------------------------------
-- CMM102 RATE
------------------------------------------------------------
drop table if exists #GNM_CMM102;
select 
    TickerName, 
    asOf = date(convert(datetime, convert(varchar, year(AsOfDate)*10000 + month(AsOfDate)*100 + 1))),  
    sum(SeriesNumValue)/sum(1) as monthlyCMM102Rate, 
    count = sum(1)
into #GNM_CMM102
from TimeSeriesMeta m join TimeSeries d on m.TimeSeriesMetaId = d.TimeSeriesMetaId
where 1 = 1
    and tickerName = 'G2_30Yr_CMM_102'
    and asOf >= '2009-07-01'
group by TickerName, asOf
order by TickerName, asOf desc
;
commit;

CREATE INDEX asOf_idx ON #GNM_CMM102(asOf);
COMMIT;
