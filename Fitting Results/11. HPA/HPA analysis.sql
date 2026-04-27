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
--DROP TABLE IF EXISTS #HomePriceIndex_monthly;
--SELECT 
--    asOf,
--    Region as state,
--    NonSeasonAdjIndex as HPIndex
--INTO #HomePriceIndex_monthly
--FROM hpi.PIV_HomePriceIndexMonthly
--WHERE 1=1
--AND RegionType = 'STATE'
--;
--COMMIT;

--DROP TABLE IF EXISTS #HPA_MA;
--SELECT
--    t1.state,
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
--    AND t1.state = t2.state
--LEFT JOIN #HomePriceIndex_monthly t3
--    ON t1.asOf = dateadd(month, 24, t3.asOf)
--    AND t1.state = t3.state
--;
--COMMIT;

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
    CASE WHEN sli.conventional_refi_incentive > sli.fha_refi_incentive THEN sli.conventional_refi_incentive ELSE sli.fha_refi_incentive END as refi_incentive,
    CASE WHEN slb.burnout IS NULL THEN 0.0 ELSE slb.burnout END as burnout,
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
    ((clh.calcScham / clh.cltv) / (cl.originalLoanAmount / cl.origLTV) - 1) * 100 as HPA,
    CASE WHEN clh.loanAge > 0 THEN (power((clh.calcScham / clh.cltv) / (cl.originalLoanAmount / cl.origLTV), 12.0 / clh.loanAge) - 1.0) * 100 ELSE 0.0 END as HPA_annual,
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
    AND slb.version = '2.60'
JOIN #MediaEffect me
    ON slh.asOf = me.asOf
JOIN #CreditAvailability ca
    ON slh.asOf = ca.asOf
JOIN #HPA_MA hpi
    ON slh.asOf = hpi.asOf
--    AND cl.state = hpi.state
JOIN scale.FHL_poolDistribution spd
    ON cl.issueId = spd.issueId
    AND slh.asOf = spd.asOf
WHERE 1=1
    AND sl.version = '2.50'
    AND sli.version = '2.60'
    and clh_lag1.calcScham > 0.01
    and calcOrigMonth_LL >= 200907 and calcOrigMonth_LL <= 201805
    and cl.origLTV >= 0 and cl.origLTV<=80
--    and wam > 180
    and clh.loanAge >= 48 
--    and clh.loanAge < 36
    and refi_incentive <= -50
--    and occType in ('OWNER', '2ND')
--    and loanPurposeType = 'PURCH'
--    and cl.coupon = 4.5
--    and slh.asOf >= '20170301' and slh.asOf <= '20180401'
--    and sl.loanSeqNum = 'A87758000055'
    and originalLoanAmount > 175000 and originalLoanAmount <= 417000
    and cl.state not in ('NY','IL')
--    and clh.asof >= '20170301'
;
COMMIT;



select 
incentiveBucket = (case
                    when refi_incentive <= -300 then '-300'
                    when refi_incentive <= -250 then '-250'
                    when refi_incentive <= -200 then '-200'
                    when refi_incentive <= -175 then '-175'
                    when refi_incentive <= -150 then '-150'
                    when refi_incentive <= -125 then '-125'
                    when refi_incentive <= -100 then '-100'
                    when refi_incentive <= -75 then '-75'
                    when refi_incentive <= -50 then '-50'
                    when refi_incentive <= -25 then '-25'
                else '500' end),
hpaBucket = (case
                    when HPA_annual <= 3 then 3
                    when HPA_annual <= 5 then 5
                    when HPA_annual <= 7 then 7
                    when HPA_annual <= 9 then 9
                  else 11 end),
--hpaBucket = (case when HPA_annual <= -10 then -10
--                when HPA_annual > 20 then 20
--else convert(int, HPA_annual / 1) * 1 + 1 end),
sum(prepayAmount)/sum(lag1_calcScham) as smm,
100.0 * (1.0 - power((1.0-smm),12.0)) as cpr,
sum(HPA_annual * currentBalance) / sum(currentBalance) as hpa_,
sum(lag1_calcScham) as bal
from #FHL_fitting_loans
where  1=1
and schamBalance is not NULL
group by incentiveBucket,hpaBucket
;
