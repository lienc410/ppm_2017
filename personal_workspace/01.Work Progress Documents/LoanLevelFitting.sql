DROP TABLE IF EXISTS #ticker;
CREATE TABLE #ticker(
    tickerName varchar(20),
    mtgRateSeries varchar(30)
)
;
INSERT #ticker SELECT 'FGLMC', 'CONVENTIONAL_30YR';   --Conventional Freddie
INSERT #ticker SELECT 'FGT6', 'JUMBO_30YR';           --Jumbo Freddie
INSERT #ticker SELECT 'FGU6', 'CONVENTIONAL_30YR';    --CQ Freddie High LTV[105-125]
INSERT #ticker SELECT 'FGU9', 'CONVENTIONAL_30YR';    --CR Freddie High LTV[125-150]
COMMIT;

CREATE INDEX pool_tickerName_idx ON #ticker(tickerName);
COMMIT;


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


DROP TABLE IF EXISTS #MediaEffect_Step1;
SELECT
    convert(date, dateadd(month, +1, AsOfDate)) as asOf_lag1,
    convert(date, dateadd(month, +2, AsOfDate)) as asOf_lag2,
    convert(numeric(6,2), 100.0 * SeriesNumValue) as media_effect
INTO #MediaEffect_Step1
FROM report.TimeSeries
WHERE 1=1
    AND TimeSeriesMetaId = (SELECT TimeSeriesMetaId FROM report.TimeSeriesMeta WHERE Source = 'PIV' AND TickerName = 'CONVENTIONAL_30YR_COMBINED' AND SeriesType = 'MONTHLY_PCT_REFI' AND ModelType = 'ScaleMediaEffectModel v5.0')
;
COMMIT;

DROP TABLE IF EXISTS #MediaEffect;
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

DROP TABLE IF EXISTS #Business_Day_Count;
SELECT
	AsOfDate as asOf, 
	convert(int, SeriesNumValue) as day_count
INTO #Business_Day_Count
FROM report.TimeSeriesMeta m 
JOIN report.timeseries d ON m.TimeSeriesMetaId = d.TimeSeriesMetaId 
WHERE Category = 'UTIL' AND SeriesType = 'DAY_COUNT';
COMMIT;

CREATE INDEX asOf_bd_idx ON #Business_Day_Count(asOf);
COMMIT;

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



DROP TABLE IF EXISTS #Symphony_loans;
SELECT
    year(sfl.originationDate) as vintage,
    cl.loanSeqNum,
    slh.asOf,
    monthBucket = (case 
        		    when month(slh.asOf) = 1  then 'Jan'
        		    when month(slh.asOf) = 2  then 'Feb'
        		    when month(slh.asOf) = 3  then 'Mar'
        		    when month(slh.asOf) = 4  then 'Apr'
        		    when month(slh.asOf) = 5  then 'May'
        		    when month(slh.asOf) = 6  then 'Jun'
        		    when month(slh.asOf) = 7  then 'Jul'
        		    when month(slh.asOf) = 8  then 'Aug'
         		    when month(slh.asOf) = 9  then 'Sep'
        		    when month(slh.asOf) = 10 then 'Oct'
                    when month(slh.asOf) = 11 then 'Nov'
                    when month(slh.asOf) = 12 then 'Dec'
        		    end),
    clh.calcScham as schamBalance,
    CASE WHEN cl.occType='OWNER' THEN 100 ELSE 0 END as percentOCC_OWN,
    CASE WHEN cl.occType='2ND' THEN 100 ELSE 0 END as percentOCC_2ND,
    CASE WHEN cl.occType='INV' THEN 100 ELSE 0 END as percentOCC_INV,
    CASE WHEN spd.percentCURRENT IS NULL THEN spd.Est_Pct_CURRENT ELSE spd.percentCURRENT END as percentCURRENT,
    CASE WHEN spd.percentDELQ30plus IS NULL THEN spd.Est_Pct_DELQ30plus ELSE spd.percentDELQ30plus END as percentDELQ30plus,
    CASE WHEN sli.conventional_refi_incentive >= sli.fha_refi_incentive THEN sli.conventional_refi_incentive ELSE sli.fha_refi_incentive END as refi_incentive,
    slb.burnout_fixed_cost as burnout,
    clh.loanAge as wala,
	clh.remTerm as wam,
    clh.currentRPB as currLoanSize,
    slh.cltv,
    sfl.origFICO,
    sfl.origNoteRate,
    CASE WHEN cl.loanPurposeType like 'RE-FI%' THEN 100 ELSE 0 END as percentPURP_REFI,
    (CASE 
       WHEN sle.conventional_eligible >= sle.fha_eligible AND sle.conventional_eligible >= sle.HARP_eligible THEN sle.conventional_eligible 
       WHEN sle.fha_eligible >= sle.conventional_eligible AND sle.fha_eligible >= sle.HARP_eligible THEN sle.fha_eligible 
       ELSE sle.HARP_eligible 
    END) * 100 as refi_eligible,
    sfl.percentHARPed,
    CASE WHEN cl.tpoType='TPO' THEN 100 ELSE 0 END as percentCHANNEL_TPO,
    CASE WHEN cl.tpoType='BROKER' THEN 100 ELSE 0 END as percentCHANNEL_BROKER,
    CASE WHEN cl.tpoType='CORRES' THEN 100 ELSE 0 END as percentCHANNEL_CORRES,
    CASE WHEN cl.tpoType in ('BROKER', 'CORRES', 'TPO') THEN 100 ELSE 0 END as percentCHANNEL_NonRETAIL,
    (100 - percentCHANNEL_NonRETAIL) as percentCHANNEL_RETAIL,
    CASE WHEN cl.isCashWindow = 'Y' THEN 100 ELSE 0 END as percent_CashWindow,
    (sle.HARP_eligible * 100) as HARP_eligible,
    clh.SATO,
	CASE WHEN clh.loanAge > 0 THEN 
			CASE WHEN clh.calcScham IS NOT NULL THEN (power((clh.calcScham / clh.cltv) / (cl.originalLoanAmount / cl.origLTV), 12.0 / clh.loanAge) - 1.0) * 100 
				ELSE (power((clh.currentRPB / slh.cltv) / (cl.originalLoanAmount / cl.origLTV), 12.0 / clh.loanAge) - 1.0) * 100 END
		ELSE 0.0 END as hpa_annual,
    CASE WHEN clh.calcScham IS NOT NULL THEN ((clh.calcScham / clh.cltv) / (cl.originalLoanAmount / cl.origLTV) - 1) * 100 
         ELSE ((clh.currentRPB / slh.cltv) / (cl.originalLoanAmount / cl.origLTV) - 1) * 100 END as hpa_cum,
	CASE WHEN cl.marketTicker not in ('FGU6','FGU9') and cl.loanPurposeType = 'PURCH' THEN 100.0 ELSE 0.0 END AS pct_purchase,
	CASE WHEN cl.origCombLTV > cl.origLTV THEN 100 ELSE 0 END AS pct_second_lien,
	CASE WHEN sli.conventional_refi_incentive_fixed_cost >= sli.fha_refi_incentive_fixed_cost THEN sli.conventional_refi_incentive_fixed_cost ELSE sli.fha_refi_incentive_fixed_cost END as refinance_incentive,
    sfl.origLTV as oltv,
    CASE WHEN sfl.originationDate <= '2009-06-01' THEN 100 ELSE 0 END AS pct_preHARP,
    CASE WHEN cl.state in ('NY') THEN 100 ELSE 0 END AS pct_NY,
    CASE WHEN clh_lag1.calcScham = 0.0 or clh_lag1.calcScham - clh_lag1.currentRPB < 0.0 THEN 0.0 ELSE (clh_lag1.calcScham - clh_lag1.currentRPB)/clh_lag1.calcScham END as smm
INTO #Symphony_loans
FROM fhl.PIV_loan cl
JOIN scale.fhl_loan_dev sfl
    ON cl.loanSeqNum = sfl.loanSeqNum
JOIN scale.fhl_loanhist slh
    ON sfl.loanSeqNum = slh.loanSeqNum
JOIN fhl.PIV_loanhist clh
    ON cl.loanSeqNum = clh.loanSeqNum
	AND slh.asOf = clh.asOf
JOIN fhl.PIV_LoanHist clh_lag1
    ON slh.loanSeqNum = clh_lag1.loanSeqNum
    AND slh.asOf = dateadd(month, -1, clh_lag1.asOf)
JOIN #ticker tk
    ON sfl.marketTicker = tk.tickerName
JOIN scale.FHL_PoolDistribution spd
    ON cl.issueId = spd.issueId
    AND slh.asOf = spd.asOf
JOIN scale.fhl_loaneligibility sle
    ON sfl.loanSeqNum = sle.loanSeqNum
    AND slh.asOf = sle.asOf
JOIN scale.fhl_loanincentive sli
    ON sfl.loanSeqNum = sli.loanSeqNum
    AND slh.asOf = sli.asOf
JOIN scale.fhl_loanburnout slb
    ON sfl.loanSeqNum = slb.loanSeqNum
    AND slh.asOf = slb.asOf
WHERE 1=1
	AND sfl.version = (SELECT originationVersion_LL FROM scale.ModelVersionConfig WHERE appType = '4.40' AND agency = 'FHL' and tickerName = 'FGLMC')
    AND sli.version = '9.98'
    AND slb.version = '9.98'
     AND slh.asOf <= '20181001' 
	AND slh.asof > '2009-06-01'
    AND clh.calcScham > 0.01
	AND clh.currentRPB > 0.01
    AND sfl.originationDate >= '2014-01-01'
    AND sfl.originationDate <= '2014-12-01'
;
COMMIT;


SELECT

    slh.loanseqnum,
    slh.asOf,
    slh.monthBucket,
	slh.schamBalance,
    slh.percentOCC_OWN,
    slh.percentOCC_2ND,
    slh.percentOCC_INV,
    slh.percentCURRENT,
    slh.percentDELQ30plus,
    slh.refi_incentive,
    slh.burnout,
    slh.wala,
    slh.currLoanSize / 1000.0 as wacls,
    slh.cltv,
    slh.origFICO,
    slh.origNoteRate,
    slh.percentPURP_REFI,
    slh.refi_eligible,
    slh.percentHARPed, 
    (slh.percentCHANNEL_BROKER + slh.percentCHANNEL_CORRES) as pct_TPO,
    slh.percentCHANNEL_BROKER as pct_BROKER,
    slh.percentCHANNEL_CORRES as pct_CORRES,
    slh.percentCHANNEL_TPO as pct_NonRETAIL,
    CASE WHEN slh.percentCHANNEL_RETAIL > slh.percent_CashWindow THEN slh.percent_CashWindow ELSE slh.percentCHANNEL_RETAIL END as pct_RETAIL_CashWindow,
    (slh.percentCHANNEL_RETAIL - pct_RETAIL_CashWindow) as pct_RETAIL_NonCashWindow,
    slh.HARP_eligible,
    slh.SATO as sato,
    0.0 as monthsSince,
    100.0 * hpi.HPA_2YR as HPA_2YR,
    ca.mca_18mo,
    me.media_effect,
	dc.day_count,
	slh.wam,
	slh.hpa_annual,
	slh.hpa_cum,
	slh.currLoanSize / 1000.0 as acls,
	slh.pct_purchase,
	slh.pct_second_lien,
	slh.refinance_incentive,
    slh.oltv,
    slh.pct_preHARP,
    slh.pct_NY,
    slh.smm
FROM #Symphony_loans slh
JOIN #HPA_MA hpi
    ON slh.asOf = hpi.asOf
JOIN #MediaEffect me
    ON slh.asOf = me.asOf
JOIN #CreditAvailability ca
    ON slh.asOf = ca.asOf
JOIN #Business_Day_Count dc
	ON slh.asOf = dc.asOf
WHERE 1=1
     AND vintage = 2014
     AND slh.asOf <= '20181001' 
    AND ABS(MOD(slh.schamBalance, 10)) = 7
;
