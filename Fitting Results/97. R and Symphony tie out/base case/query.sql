-- Baton Fitting Data
-- Freddie Conventional
-- loan Level
-- Script to pull data from Scale tables for Fitting process in R


-- Before execute the script, need to set the dates to run for
DROP TABLE IF EXISTS #tmp_asOf;
SELECT CAST ('1994-02-01' AS DATE) asOf INTO #tmp_asOf
;

---- Before execute the script, need to set the version to run for
--DROP TABLE IF EXISTS #tmp_version;
--SELECT CAST ('2.41' AS varchar(5)) version INTO #tmp_version
--;

-- Before execute the script, need to set the tickers
DROP TABLE IF EXISTS #ticker;
CREATE TABLE #ticker(
    tickerName varchar(20),
    mtgRateSeries varchar(30)
)
;
INSERT #ticker SELECT 'FGLMC', 'CONVENTIONAL_30YR';   --Conventional Freddie
--INSERT #ticker SELECT 'FGT6', 'JUMBO_30YR';           --Jumbo Freddie
--INSERT #ticker SELECT 'FGU6', 'CONVENTIONAL_30YR';    --CQ Freddie High LTV[105-125]
--INSERT #ticker SELECT 'FGU9', 'CONVENTIONAL_30YR';    --CR Freddie High LTV[125-150]
COMMIT;

--CREATE INDEX loan_tickerName_idx ON #ticker(tickerName);
--COMMIT;

---- Before execute the script, create Sample of loans (Optional)
--DROP TABLE IF EXISTS #loanloanSeqNum;
--SELECT loanSeqNum, NEWID() as IDX, marketTicker
--INTO #loanloanSeqNum
--FROM (
--    SELECT distinct loanSeqNum, marketTicker FROM fhl.PIV_loan p
--) o
--WHERE o.marketTicker IN (SELECT tickerName FROM #ticker)
--;
--COMMIT;

--DROP TABLE IF EXISTS #loanIDSample;
----SELECT top 50000 loanSeqNum -- subset of total
--SELECT loanSeqNum -- all loans
--INTO #loanIDSample FROM #loanloanSeqNum 
--ORDER BY IDX;
--COMMIT;

--CREATE INDEX loanSeqNum_idx ON #loanIDSample(loanSeqNum);
--COMMIT;

-----------------------------------------------------------
-- Create Media Effect Series

-- Combined Loan and loan Percent Refinanceable Percent
-- Lag of 1.5 Month is Assumed
-----------------------------------------------------------
DROP TABLE IF EXISTS #MediaEffect_Step1;
SELECT
    convert(date, dateadd(month, +1, AsOfDate)) as asOf_lag1,
    convert(date, dateadd(month, +2, AsOfDate)) as asOf_lag2,
    convert(numeric(6,2), 100.0 * SeriesNumValue) as media_effect
INTO #MediaEffect_Step1
FROM report.TimeSeries
WHERE 1=1
    AND TimeSeriesMetaId = (SELECT TimeSeriesMetaId FROM report.TimeSeriesMeta WHERE Source = 'PIV' AND TickerName = 'CONVENTIONAL_30YR_COMBINED' AND SeriesType = 'MONTHLY_PCT_REFI' AND ModelType = 'ScaleMediaEffectModel v4.0')
;
COMMIT;



DROP TABLE IF EXISTS #MediaEffect;
-- one and half month lagged
SELECT
asof = lag1.asOf_lag1,
media_effect = lag1.media_effect * 0.5 + lag2.media_effect * 0.5
INTO #MediaEffect
FROM #MediaEffect_Step1 lag1
JOIN #MediaEffect_Step1 lag2 ON lag1.asOf_lag1 = lag2.asOf_lag2
;
COMMIT;

CREATE INDEX asOf_idx ON #MediaEffect(asOf);
COMMIT;

-----------------------------------------------------------
-- Create Mortgage Credit Availability Series

-- Raw Series from MBA
-----------------------------------------------------------
DROP TABLE IF EXISTS #CreditAvailability_mba;
SELECT
    AsOfDate as asOf,
    convert(numeric(6,2), SeriesNumValue) as mca_index
INTO #CreditAvailability_mba
FROM report.TimeSeries
WHERE 1=1
    AND TimeSeriesMetaId = (SELECT TimeSeriesMetaId FROM report.TimeSeriesMeta WHERE Source = 'PIV' AND TickerName = 'MBA_CAI_Composite' AND SeriesType = 'Index' AND ModelType = 'MCAI_v2.0')
ORDER BY asOf
;
COMMIT;

-- Extend Time Series for several months after end
DROP TABLE IF EXISTS #CreditAvailability_extended;
SELECT
    asOf,
    mca_index
INTO #CreditAvailability_extended
FROM #CreditAvailability_mba
;
COMMIT;

INSERT INTO #CreditAvailability_extended
SELECT dateadd(month,1,asOf), mca_index FROM #CreditAvailability_mba
WHERE asOf = (SELECT max(asOf) FROM #CreditAvailability_mba)
;

INSERT INTO #CreditAvailability_extended
SELECT dateadd(month,2,asOf), mca_index FROM #CreditAvailability_mba
WHERE asOf = (SELECT max(asOf) FROM #CreditAvailability_mba)
;

DROP TABLE IF EXISTS #CreditAvailability;
SELECT 
    t1.asOf, 
    avg(t2.mca_index) AS mca_18mo
INTO #CreditAvailability
FROM #CreditAvailability_extended t1, #CreditAvailability_extended t2
WHERE t2.asOf
BETWEEN (dateadd(month,-17,t1.AsOf)) AND t1.asOf -- 18 Month average, but 17 is used with the BETWEEN clause
GROUP BY t1.asOf
ORDER BY t1.asOf
;
COMMIT;

CREATE INDEX asOf_idx ON #CreditAvailability(asOf);
COMMIT;

--------------------------------------------------------------------------------
-- Create Monthly HPI data for Symphony Tracking
--------------------------------------------------------------------------------
DROP TABLE IF EXISTS #HomePriceIndex_monthly;
SELECT 
    asOf,
    Region as state,
    NonSeasonAdjIndex as HPIndex
INTO #HomePriceIndex_monthly
FROM hpi.PIV_HomePriceIndexMonthly
WHERE 1=1
AND RegionType = 'STATE'
;
COMMIT;

DROP TABLE IF EXISTS #HPA_MA;
SELECT
    t1.state,
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
    AND t1.state = t2.state
LEFT JOIN #HomePriceIndex_monthly t3
    ON t1.asOf = dateadd(month, 24, t3.asOf)
    AND t1.state = t3.state
;
COMMIT;

--DROP TABLE IF EXISTS #HomePriceIndex_monthly;
--SELECT asof, 
--    NonSeasonAdjIndex as HPIndex
--INTO #HomePriceIndex_monthly
--FROM hpi.PIV_HomePriceIndexMonthly
--WHERE transactionType = 'PURCHASE_ONLY'
--AND region = 'USA'
--;

--DROP TABLE IF EXISTS #HPA_MA;
--SELECT
--    'USA' as Region,
--    t1.asOf,
--    t1.HPIndex as HPIndex,
--    t2.HPIndex as HPIndex_1YR,
--    t3.HPIndex as HPIndex_2YR,
--    CASE WHEN t2.HPIndex IS NULL THEN NULL ELSE t1.HPIndex / t2.HPIndex END as HPA_1YR,
--    CASE WHEN t3.HPIndex IS NULL THEN NULL ELSE t1.HPIndex / t3.HPIndex END as HPA_2YR
--INTO #HPA_MA
--FROM #HomePriceIndex_monthly t1
--LEFT JOIN #HomePriceIndex_monthly t2
--    ON t1.asOf = dateadd(month, 12, t2.asOf)
--LEFT JOIN #HomePriceIndex_monthly t3
--    ON t1.asOf = dateadd(month, 24, t3.asOf)
--;
--COMMIT;

CREATE INDEX asOf_idx ON #HPA_MA(asOf);
COMMIT;

DELETE FROM #HPA_MA WHERE HPA_1YR IS NULL;
COMMIT;

DELETE FROM #HPA_MA WHERE HPA_2YR IS NULL;
COMMIT;




-----------------------------------------------------------
-- Store all loans with pertinent data
-----------------------------------------------------------
DROP TABLE IF EXISTS #fhl_fitting_loans;
SELECT
    slh.loanSeqNum,
    sl.marketTicker,
    slh.asOf,
    cl.coupon,
    sle.HARP_eligible,
    clh.schamBalance,
    clh_lag1.calcScham as lag1_calcScham,
    clh.currentRPB as currentBalance,
    cl.originalLoanAmount as ols,
    cl.occType,    
    cl.loanPurposeType,
    CASE WHEN spd.percentDELQ30plus IS NULL THEN spd.Est_Pct_DELQ30plus ELSE spd.percentDELQ30plus END as percentDELQ,
    CASE WHEN sli.conventional_refi_incentive > sli.fha_refi_incentive THEN sli.conventional_refi_incentive ELSE sli.fha_refi_incentive END as turn_incentive,
    CASE WHEN sli.conventional_refi_incentive_fixed_cost > sli.fha_refi_incentive_fixed_cost THEN sli.conventional_refi_incentive_fixed_cost ELSE sli.fha_refi_incentive_fixed_cost END as refi_incentive,
    CASE WHEN slb.burnout IS NULL THEN 0.0 ELSE slb.burnout_fixed_cost END as burnout,
    CASE WHEN (sle.conventional_eligible + HARP_eligible + fha_eligible > 0.0) THEN 1.0 ELSE 0.0 END as refi_eligible,
    CASE WHEN cl.origCombLTV > cl.origLTV THEN 1 ELSE 0 END AS secondLien,
    slh.cltv,
    sl.origLoanSize,
    clh.loanAge as wala,
    sl.origNoteRate,
    sl.origFICO,
    sl.percentHARPed,
    cl.tpoType,
    ca.mca_18mo as credit_availability,
    100.0 * hpi.HPA_2YR as HPA_2YR,
    me.media_effect,
    clh.SATO,
    clh.remTerm as wam,
    CASE WHEN clh.calcScham IS NOT NULL THEN ((clh.calcScham / clh.cltv) / (cl.originalLoanAmount / cl.origLTV) - 1) * 100 
         ELSE ((clh.currentRPB / slh.cltv) / (cl.originalLoanAmount / cl.origLTV) - 1) * 100 END as HPA_cum,
    CASE WHEN clh.loanAge > 0 THEN CASE WHEN clh.calcScham IS NOT NULL THEN (power((clh.calcScham / clh.cltv) / (cl.originalLoanAmount / cl.origLTV), 12.0 / clh.loanAge) - 1.0) * 100 
                                        ELSE (power((clh.currentRPB / slh.cltv) / (cl.originalLoanAmount / cl.origLTV), 12.0 / clh.loanAge) - 1.0) * 100 END
         ELSE 0.0 END as HPA_annual,
    CASE WHEN cl.origLTV > 80 THEN 1 ELSE 0 END AS highOLTV,
    CASE WHEN clh_lag1.calcScham - clh_lag1.currentRPB >= 0.0 THEN clh_lag1.calcScham - clh_lag1.currentRPB ELSE 0.0 END as prepayAmount
INTO #fhl_fitting_loans
FROM scale.fhl_LoanHist slh
JOIN scale.fhl_Loan_Dev sl ON slh.loanSeqNum = sl.loanSeqNum
JOIN fhl.PIV_Loan cl ON slh.loanSeqNum = cl.loanSeqNum
JOIN #ticker tk
    ON sl.marketTicker = tk.tickerName
JOIN fhl.PIV_LoanHist clh 
    ON slh.loanSeqNum = clh.loanSeqNum
    AND slh.asOf = clh.asOf
JOIN fhl.PIV_LoanHist clh_lag1
    ON slh.loanSeqNum = clh_lag1.loanSeqNum
    AND slh.asOf = dateadd(month, -1, clh_lag1.asOf)
JOIN scale.fhl_LoanEligibility sle
    ON slh.loanSeqNum = sle.loanSeqNum
    AND slh.asOf = sle.asOf
JOIN scale.fhl_LoanIncentive sli
    ON slh.loanSeqNum = sli.loanSeqNum
    AND slh.asOf = sli.asOf
FULL OUTER JOIN scale.fhl_LoanBurnout slb
    ON slh.loanSeqNum = slb.loanSeqNum
    AND slh.asOf = slb.asOf
    AND slb.version = '9.98'
JOIN #MediaEffect me
    ON slh.asOf = me.asOf
JOIN #CreditAvailability ca
    ON slh.asOf = ca.asOf
JOIN #HPA_MA hpi
    ON slh.asOf = hpi.asOf
    AND cl.state = hpi.state
JOIN scale.FHL_poolDistribution spd
    ON cl.issueId = spd.issueId
    AND slh.asOf = spd.asOf
WHERE 1=1
    AND sl.version = '9.98'
    AND sli.version = '9.98'
----    and clh_lag1.calcScham > 0.01
--    and calcOrigMonth_LL >= 200907 and calcOrigMonth_LL <= 201805
--    and cl.origLTV >= 0 and cl.origLTV<=80
--    and slh.cltv <= 80
----    and wam > 180
--    and clh.loanAge > 48 
----    and refi_incentive <= -50
--    and occType in ('OWNER', '2ND')
----    and loanPurposeType = 'PURCH'
----    and cl.coupon = 4.5
----    and slh.asOf >= '20170301' and slh.asOf <= '20180401'
----    and sl.loanSeqNum = 'Q05087000012'
--    and originalLoanAmount > 175000 and originalLoanAmount <= 417000
----    and cl.state not in ('NY','IL')
----    and clh.asof >= '20120101'
----    and clh.asof <= '20130601'
--    and clh.asof >= '20170901'
--    and clh.asof <= '20170901'
--    and sl.origFICO >= 740
--    and secondLien = 0
--    and turn_incentive > 50 and turn_incentive <= 75
------    and burnout < 2000
 and sl.loanseqnum = 'C03407004450'
;
COMMIT;


--select top 10 * from fhl_Fitting_Loan_temp
--select * from scale.fhl_loanIncentive where loanseqnum='V80095012052' and asOf>='20180101' and version = '2.60'
--select * from #HPA_MA 
---- remove later
--select count(1) from scale.FHL_loanEligibility where refi_eligible IS NULL
--select count(1) from scale.FNM_loanEligibility where HARP_eligible IS NULL
--select distinct(loanPurposeType) from #fhl_fitting_loans order by asof desc
--select * from #FHL_fitting_loans where loanSeqNum = 1506042 order by asof desc 

------------------------------------------------------------
-- REFINANCE MODEL SPECIFICATION
------------------------------------------------------------

-- Data Extraction Part 3 - All Period Data
DROP TABLE IF EXISTS #step3;
SELECT
    loanSeqNum,
    asOf,
    marketTicker,
    highOLTV,
    secondLien,
--    coupon,
    HARP_eligible * 100.0 as HARP_eligible,
    loanPurposeType,
    occType,
--	walaBucket = (case 
--                   when wala < 2 then '2'
--                   when wala < 4 then '4'
--                   when wala < 6 then '6'
--                   when wala < 10 then '10'
--    	     	   when wala < 20 then '20'
--    	           when wala < 30 then '30'
--    	           when wala < 40 then '40'
--    	           when wala < 50 then '50'
--    	           when wala < 60 then '60'
--    	           when wala < 70 then '70'
--    	           when wala < 80 then '80'
--    	           when wala < 90 then '90'
--    	           when wala < 100 then '100'
--    	           when wala < 120 then '120'
--    	           when wala < 140 then '140'
--    	           when wala < 160 then '160'
--    	           when wala < 180 then '180'
--    	           else '200' end),
--	monthBucket = (case 
--        		    when month(asOf) = 1  then 'Jan'
--        		    when month(asOf) = 2  then 'Feb'
--        		    when month(asOf) = 3  then 'Mar'
--        		    when month(asOf) = 4  then 'Apr'
--        		    when month(asOf) = 5  then 'May'
--        		    when month(asOf) = 6  then 'Jun'
--        		    when month(asOf) = 7  then 'Jul'
--        		    when month(asOf) = 8  then 'Aug'
--         		    when month(asOf) = 9  then 'Sep'
--        		    when month(asOf) = 10 then 'Oct'
--                    when month(asOf) = 11 then 'Nov'
--                    when month(asOf) = 12 then 'Dec'
--        		    end),
--    incentiveBucket = (case
--                    when refi_incentive <= -300 then '-300'
--                    when refi_incentive <= -250 then '-250'
--                    when refi_incentive <= -200 then '-200'
--                    when refi_incentive <= -175 then '-175'
--                    when refi_incentive <= -150 then '-150'
--                    when refi_incentive <= -125 then '-125'
--                    when refi_incentive <= -100 then '-100'
--                    when refi_incentive <= -75 then '-75'
--                    when refi_incentive <= -50 then '-50'
--                    when refi_incentive <= -25 then '-25'
--                    when refi_incentive <= 0.0 then '0'
--                    when refi_incentive <= 25 then '25'
--                    when refi_incentive <= 50 then '50'
--                    when refi_incentive <= 75 then '75'
--                    when refi_incentive <= 100 then '100'
--                    when refi_incentive <= 125 then '125'
--                    when refi_incentive <= 150 then '150'
--                    when refi_incentive <= 175 then '175'
--                    when refi_incentive <= 200 then '200'
--                    when refi_incentive <= 225 then '225'
--                    when refi_incentive <= 250 then '250'
--                    when refi_incentive <= 275 then '275'
--                    when refi_incentive <= 300 then '300'
--                    when refi_incentive <= 350 then '350'
--                    when refi_incentive <= 400 then '400'
--                    when refi_incentive <= 450 then '450'
--                else '500' end),
--    burnoutBucket = (case
--                  when burnout < 2000 THEN '2000'
--                  when burnout < 4000 THEN '4000'
--                  when burnout < 6000 THEN '6000'
--                  when burnout < 8000 THEN '8000'
--                  when burnout < 8000 THEN '10000'
--                  else '12000' end),
--    waclsBucket = (case
--                  when (currentBalance / 1000.0) < 50 THEN '50'
--                  when (currentBalance / 1000.0) < 85 THEN '85'
--                  when (currentBalance / 1000.0) < 110 THEN '110'
--                  when (currentBalance / 1000.0) < 150 THEN '150'
--                  when (currentBalance / 1000.0) < 200 THEN '200'
--                  when (currentBalance / 1000.0) < 300 THEN '300'
--                  when (currentBalance / 1000.0) < 400 THEN '400'
--                  when (currentBalance / 1000.0) < 500 THEN '500'
--                  when (currentBalance / 1000.0) < 600 THEN '600'
--                  when (currentBalance / 1000.0) < 700 THEN '700'
--                  else '800' end),
--    waolsBucket = (case
--                  when (ols / 1000.0) <= 85 THEN '85'
--                  when (ols / 1000.0) <= 110 THEN '110'
--                  when (ols / 1000.0) <= 150 THEN '150'
--                  when (ols / 1000.0) <= 175 THEN '175'
--                  when (ols / 1000.0) <= 417 THEN '417'
--                  else '800' end),
--    cltvBucket = (case
--                  when cltv < 10 THEN '10'
--                  when cltv < 20 THEN '20'
--                  when cltv < 30 THEN '30'
--                  when cltv < 40 THEN '40'
--                  when cltv < 50 THEN '50'
--                  when cltv < 60 THEN '60'
--                  when cltv < 70 THEN '70'
--                  when cltv < 80 THEN '80'
--                  when cltv < 90 THEN '90'
--                  when cltv < 100 THEN '100'
--                  when cltv < 110 THEN '110'
--                  when cltv < 120 THEN '120'
--                  when cltv < 130 THEN '130'
--                  when cltv < 140 THEN '140'
--                  else '150' end),
--    ficoBucket = (case
--                  when origFICO < 640 THEN '640'
--                  when origFICO < 680 THEN '680'
--                  when origFICO < 720 THEN '720'
--                  when origFICO < 760 THEN '760'
--                  else '800' end),
--    media_refiBucket = (case
--                  when media_effect < 10 THEN '10'
--                  when media_effect < 20 THEN '20'
--                  when media_effect < 30 THEN '30'
--                  when media_effect < 40 THEN '40'
--                  when media_effect < 50 THEN '50'
--                  when media_effect < 60 THEN '60'
--                  when media_effect < 70 THEN '70'
--                  when media_effect < 80 THEN '80'
--                  when media_effect < 90 THEN '90'
--                  else '100' end),
--    credit_availabilityBucket = (case
--                  when credit_availability < 100 THEN '100'
--                  when credit_availability < 150 THEN '150'
--                  when credit_availability < 200 THEN '200'
--                  when credit_availability < 250 THEN '250'
--                  when credit_availability < 300 THEN '300'
--                  when credit_availability < 400 THEN '400'
--                  when credit_availability < 500 THEN '500'
--                  when credit_availability < 600 THEN '600'
--                  when credit_availability < 700 THEN '700'
--                  else '800' end),
----    hpaBucket = (case
----                  when HPA < 2 then 2
----                  when HPA >= 30 then 40
----                  else convert(int, HPA / 10) * 10 + 10 end),
--    hpa_annualBucket = (case
--                  when HPA_annual < 5 then 5
--                  when HPA_annual < 8 then 8
--                  else 11 end),
--    hpa_cumBucket = (case
--                  when HPA_cum < 10 then 10
--                  when HPA_cum >= 30 then 30
--                  else convert(int, HPA_cum / 10) * 10 + 10 end),
----    satoBucket = (case
----                  when sato < -100 THEN '-100'
----                  when sato < -50  THEN '-50'
----                  when sato < 0    THEN '0'
----                  when sato < 50   THEN '50'
----                  else '100' end),
	sum(currentBalance) as bal,
    sum(CASE WHEN occType = 'INV' THEN 100.0 ELSE 0.0 END * currentBalance) / sum(currentBalance) as pct_inv,
    sum(CASE WHEN occType = '2ND' THEN 100.0 ELSE 0.0 END * currentBalance) / sum(currentBalance) as pct_2nd,
    sum(CASE WHEN occType = 'OWNER' THEN 100.0 ELSE 0.0 END * currentBalance) / sum(currentBalance) as pct_owner,
    sum(CASE WHEN loanPurposeType = 'PURCH' THEN 100.0 ELSE 0.0 END * currentBalance) / sum(currentBalance) as pct_purchase,
    sum(CASE WHEN loanPurposeType = 'RE-FI-NCO' THEN 100.0 ELSE 0.0 END * currentBalance) / sum(currentBalance) as pct_REFI_NCO,
    sum(CASE WHEN loanPurposeType = 'RE-FI-CO' THEN 100.0 ELSE 0.0 END * currentBalance) / sum(currentBalance) as pct_REFI_CO,
    sum(CASE WHEN loanPurposeType IN ('RE-FI-N/S', 'N/A') THEN 100.0 ELSE 0.0 END * currentBalance) / sum(currentBalance) as pct_REFI_Other,
    sum(CASE WHEN loanPurposeType like 'RE-FI%' THEN 100.0 ELSE 0.0 END * currentBalance) / sum(currentBalance) as pct_REFI,
    sum(percentDELQ * currentBalance) / sum(currentBalance) as pct_dq,
    sum(refi_incentive * currentBalance) / sum(currentBalance) as refi_incentive_,
    sum(turn_incentive * currentBalance) / sum(currentBalance) as incentive,
    sum(p.burnout * currentBalance) / sum(currentBalance) as burnout_,
    sum(refi_eligible * currentBalance) / sum(currentBalance) * 100.0 as refi_elig_pct,
	sum(cltv * currentBalance) / sum(currentBalance) as cltv_,
    sum((currentBalance / 1000.0) * currentBalance) / sum(currentBalance) as wacls_,
    avg(currentBalance) / 1000.0 as acls,
	sum(wala * currentBalance) / sum(currentBalance) as wala_,
    sum(wam * currentBalance) / sum(currentBalance) as wam,
	sum(origNoteRate * currentBalance) / sum(currentBalance) as wac,
	sum(origFICO * currentBalance) / sum(currentBalance) as fico,
    sum(HPA_2YR * currentBalance) / sum(currentBalance) as hpa2yr,
	sum(percentHARPed * currentBalance) / sum(currentBalance) as pct_HARPed,
    sum(CASE WHEN tpoType IN ('BROKER', 'CORRES') THEN 100.0 ELSE 0.0 END * currentBalance) / sum(currentBalance) as pct_tpo,
    sum(secondLien * currentBalance) / sum(currentBalance) * 100 as pct_second_lien,
    sum(credit_availability * currentBalance) / sum(currentBalance) as cai,
    sum(media_effect * currentBalance) / sum(currentBalance) as media_effect_,
    sum(sato * currentBalance)/sum(currentBalance) as sato_,
    sum(HPA_annual * currentBalance) / sum(currentBalance) as hpa_annual_,
    sum(HPA_cum * currentBalance) / sum(currentBalance) as hpa_cum_,
    sum(prepayAmount)/sum(p.lag1_calcScham) as smm
INTO #step3
FROM #FHL_fitting_loans p
WHERE 1=1
--AND percentDELQ IS NOT NULL
--and occType <> 'INV'
--GROUP BY asOf, marketTicker, highOLTV, occType,secondLien, HARP_eligible, loanPurposeType, walaBucket, monthBucket, incentiveBucket, media_refiBucket, credit_availabilityBucket, burnoutBucket, waclsBucket, waolsBucket, cltvBucket, ficoBucket, hpa_annualBucket, hpa_cumBucket
GROUP BY loanseqNum, asOf, marketTicker, highOLTV, occType,secondLien, HARP_eligible, loanPurposeType, monthBucket
ORDER BY asOf
;
COMMIT;


--select 
----loanSeqNum,
--asOf,
--year(asOf) as year,
--month(asOf) as month,
--day(asOf) as day,
--marketTicker,
--HARP_eligible,
----coupon,
--secondLien,
--highOLTV,
--loanPurposeType,
--occType,
--monthsSince = 0.0,
--ficoBucket,
--waolsBucket,
--hpa_annualBucket,
--hpa_cumBucket,
--convert(numeric(16, 1), bal),
--convert(numeric(4, 1), pct_owner),
--convert(numeric(4, 1), pct_inv),
--convert(numeric(4, 1), pct_2nd),
--convert(numeric(4, 1), pct_REFI) as pct_REFI,
--convert(numeric(4, 1), pct_purchase) as pct_purchase,
--convert(numeric(4, 1), pct_REFI_NCO) as pct_REFI_NCO,
--convert(numeric(4, 1), pct_REFI_CO) as pct_REFI_CO,
--convert(numeric(4, 1), pct_REFI_Other) as pct_REFI_Other,
--convert(numeric(4, 1), pct_second_lien) as pct_second_lien,
--convert(numeric(4, 1), pct_dq),
--convert(numeric(8, 1), incentive),
--convert(numeric(8, 1), refi_incentive_),
--convert(numeric(8, 1), burnout_) as burnout,
--convert(numeric(4, 1), refi_elig_pct) as refi_elig_pct,
--convert(numeric(4, 1), cltv_) as cltv,
--convert(numeric(5, 1), wacls_) as wacls,
--convert(numeric(5, 1), acls) as acls,
--convert(numeric(4, 1), wala_) as wala,
--convert(numeric(4, 1), wam) as wam,
--convert(numeric(4, 1), wac),
--convert(numeric(4, 1), fico) as fico,
--convert(numeric(4, 1), pct_HARPed) as pct_HARPed,
--convert(numeric(4, 1), pct_tpo) as pct_tpo,
--convert(numeric(4, 1), cai) as cai,
--convert(numeric(4, 1), hpa2yr),
--convert(numeric(4, 1), media_effect_) as media_effect,
--convert(numeric(4, 1), sato_) as sato,
--convert(numeric(10, 4), hpa_annual_) as hpa_annual,
--convert(numeric(10, 4), hpa_cum_) as hpa_cum,
--convert(numeric(7, 6), smm) as smm
--from #step3 
----where loanSeqNum = 'C03490002337'
--order by asof desc
--;
--select count(1) from #step3

--select 
--s.loanSeqNum,
--s.asOf,
--year(s.asOf) as year,
--month(s.asOf) as month,
--day(s.asOf) as day,
--marketTicker,
--HARP_eligible,
----coupon,
--secondLien,
--highOLTV,
--loanPurposeType,
--occType,
--monthsSince = 0.0,
----ficoBucket,
----waolsBucket,
----hpa_annualBucket,
----hpa_cumBucket,
--convert(numeric(16, 1), bal),
--convert(numeric(4, 1), pct_owner),
--convert(numeric(4, 1), pct_inv),
--convert(numeric(4, 1), pct_2nd),
--convert(numeric(4, 1), pct_REFI) as pct_REFI,
--convert(numeric(4, 1), pct_purchase) as pct_purchase,
--convert(numeric(4, 1), pct_REFI_NCO) as pct_REFI_NCO,
--convert(numeric(4, 1), pct_REFI_CO) as pct_REFI_CO,
--convert(numeric(4, 1), pct_REFI_Other) as pct_REFI_Other,
--convert(numeric(4, 1), pct_second_lien) as pct_second_lien,
--convert(numeric(4, 1), pct_dq),
--convert(numeric(8, 1), incentive),
--convert(numeric(8, 1), refi_incentive_),
--convert(numeric(8, 1), burnout_) as burnout,
--convert(numeric(4, 1), refi_elig_pct) as refi_elig_pct,
--convert(numeric(4, 1), cltv_) as cltv,
--convert(numeric(5, 1), wacls_) as wacls,
--convert(numeric(5, 1), acls) as acls,
--convert(numeric(4, 1), wala_) as wala,
--convert(numeric(4, 1), wam) as wam,
--convert(numeric(4, 1), wac),
--convert(numeric(4, 1), fico) as fico,
--convert(numeric(4, 1), pct_HARPed) as pct_HARPed,
--convert(numeric(4, 1), pct_tpo) as pct_tpo,
--convert(numeric(4, 1), cai) as cai,
--convert(numeric(4, 1), hpa2yr),
--convert(numeric(4, 1), media_effect_) as media_effect,
--convert(numeric(4, 1), sato_) as sato,
--convert(numeric(10, 4), hpa_annual_) as hpa_annual,
--convert(numeric(10, 4), hpa_cum_) as hpa_cum,
--convert(numeric(7, 6), smm) as smm,
--mdl.*
--from #step3 s
--join scale.LoanPrepayTracking mdl on s.loanseqnum = mdl.loanseqnum
----where loanSeqNum = 'C03490002337'
--where mdl.asof  = '20171001' and mdl.modelId = '4.20'
--;

-- Create Business Day Count Series for  for Symphony Tracking
DROP TABLE IF EXISTS #Business_Day_Count;
SELECT
	AsOfDate as asOf, 
	convert(int, SeriesNumValue) as day_count
INTO #Business_Day_Count
FROM report.TimeSeriesMeta m 
JOIN report.timeseries d ON m.TimeSeriesMetaId = d.TimeSeriesMetaId 
WHERE Category = 'UTIL' AND SeriesType = 'DAY_COUNT';
COMMIT;

SELECT
    sph.loanSeqNum,
    sph.asOf,
    sph.monthBucket as monthBucket,
	sph.bal as bal,
    pct_owner,
    pct_2nd,
    pct_inv,
    pct_current = 100 - pct_dq,
    pct_dq,
    incentive,
    burnout_ as burnout,
    wala_,
    wacls_,
    sph.cltv_,
    fico,
    wac,
    pct_REFI,
    refi_elig_pct,
    pct_HARPed, 
    pct_tpo,
    HARP_eligible,
    sato_,
    0.0 as monthsSince,
    hpa2yr,
    cai as cai,
    media_effect_ as media_effect,
    dc.day_count,
    sph.wam,
	sph.hpa_annual_,
	sph.hpa_cum_,
	acls,
	sph.pct_purchase,
	sph.pct_second_lien,
    sph.refi_incentive_ as refi_incentive
--    ,year(sph.asOf) as year
--    ,month(sph.asOf) as month
--    ,day(sph.asOf) as day
FROM #step3 sph
JOIN #Business_Day_Count dc
	ON sph.asOf = dc.asOf
--Where sph.loanSeqNum = 'A87478000027'
-- JOIN scale.SampleIssueIds si ON sph.loanSeqNum = si.loanSeqNum 
where sph.asof = '20110301'