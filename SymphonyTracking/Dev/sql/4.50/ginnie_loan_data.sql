-- Symphony Tracking Data
-- Ginnie Conventional
-- Loan Level
-- Script to pull data from Scale tables for Symphony Tracking

-----------------------------------------------------------
-- Store all loans with pertinent data
-----------------------------------------------------------
DROP TABLE IF EXISTS #Symphony_loans;
SELECT
    year(sl.originationDate) as vintage,
    sl.originationDate as originationDate,
    slh.loanSeqNum,
    sl.marketTicker,
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
    sl.loanType,
    slh.loanAge as wala,
    (case when slh.remTerm < 0 then 0 else slh.remTerm end) as wam,
    slh.schamBalance,
    (slh.currentBalance/1000.0) as wacls,
    (slh.currentBalance/1000.0) as acls,
    sl.origFICO as fico,
    CASE WHEN cl.loanPurposeType like 'RE-FI%' THEN 100.0 ELSE 0.0 END as pct_refi,
    CASE WHEN cl.loanPurposeType like 'PURCH' THEN 100.0 ELSE 0.0 END as pct_purchase,
    slh.cltv,
    CASE WHEN slh.delMonths > 0 THEN 100.0 ELSE 0.0 END as pct_dq,
    CASE WHEN sli.conventional_refi_incentive >= sli.fha_refi_incentive THEN sli.conventional_refi_incentive ELSE sli.fha_refi_incentive END as turnover_incentive,
    CASE WHEN sli.conventional_refi_incentive_fixed_cost >= sli.fha_refi_incentive_fixed_cost THEN sli.conventional_refi_incentive_fixed_cost ELSE sli.fha_refi_incentive_fixed_cost END as refinance_incentive,
    slb.burnout_fixed_cost as burnout,
    me.media_effect,
    ca.mca_18mo as cai,
    CASE WHEN cl.tpoType='TPO' THEN 100 ELSE 0 END as percentCHANNEL_TPO,
    CASE WHEN cl.tpoType='BROKER' THEN 100 ELSE 0 END as percentCHANNEL_BROKER,
    CASE WHEN cl.tpoType='CORRES' THEN 100 ELSE 0 END as percentCHANNEL_CORRES,
    CASE WHEN cl.tpoType in ('BROKER', 'CORRES', 'TPO') THEN 100 ELSE 0 END as percentCHANNEL_NonRETAIL,
    (100 - percentCHANNEL_NonRETAIL) as percentCHANNEL_RETAIL,
    0.0 as percent_CashWindow,
    100.0 * hpi.HPA_2YR as hpa2yr,
 	CASE WHEN slh.loanAge > 0 THEN 
			CASE WHEN slh.currentBalance IS NOT NULL THEN (power((slh.currentBalance / (case when slh.cltv<=0 then 0.01 else slh.cltv end)) / (cl.originalLoanAmount / cl.origLTV), 12.0 / slh.loanAge) - 1.0) * 100 
				ELSE (power((slh.SchamBalance / (case when slh.cltv<=0 then 0.01 else slh.cltv end)) / (cl.originalLoanAmount / cl.origLTV), 12.0 / slh.loanAge) - 1.0) * 100 END
		ELSE 0.0 END as hpa_annual,
    CASE WHEN slh.currentBalance IS NOT NULL THEN ((slh.currentBalance / (case when slh.cltv<=0 then 0.01 else slh.cltv end)) / (cl.originalLoanAmount / cl.origLTV) - 1) * 100 
         ELSE ((slh.SchamBalance / (case when slh.cltv<=0 then 0.01 else slh.cltv end)) / (cl.originalLoanAmount / cl.origLTV) - 1) * 100 END as hpa_cum,
    CASE WHEN cl.origCombLTV > cl.origLTV THEN 100 ELSE 0 END AS pct_second_lien,
    0.0 as pct_HARPed,
    0.0 as HARP_eligible,
    100.0 as refi_eligible,
    sl.origLTV as oltv,
    0.0 as pct_preHARP,
    CASE WHEN cl.state in ('NY') THEN 100 ELSE 0 END AS pct_NY,
    CASE WHEN cl.loanPurposeType = 'RE-FI-CO' THEN 100.0 ELSE 0.0 END AS pct_refi_co,
    (100.0 - pct_purchase - pct_refi_co) AS pct_refi_nco
INTO #Symphony_loans
FROM scale.GNM_LoanHist slh
JOIN scale.GNM_Loan_dev sl ON slh.loanSeqNum = sl.loanSeqNum
JOIN scale.GNM_LoanIncentive sli
    ON slh.loanSeqNum = sli.loanSeqNum
    AND slh.asOf = sli.asOf
JOIN scale.GNM_LoanHist slh2
    ON slh.loanSeqNum = slh2.loanSeqNum
    AND slh.asOf = dateadd(month, 1, slh2.asof)
JOIN GNM.PIV_Loan cl
    ON slh.loanseqnum=cl.loanseqnum
JOIN scale.GNM_LoanBurnout slb
    ON slh.loanSeqNum = slb.loanSeqNum
    AND slh.asOf = slb.asOf
JOIN #MediaEffect me
    ON slh.asOf = me.asOf
JOIN #CreditAvailability ca
    ON slh.asOf = ca.asOf
JOIN #HPA_MA hpi
    ON slh.asOf = hpi.asOf
    --@SAMPLE_JOIN@
WHERE 1=1
    AND sl.version = (SELECT originationVersion_LL FROM scale.ModelVersionConfig WHERE appType = '@DATABASE@' AND agency = 'GNM' and tickerName = 'G2SF')
    AND sli.version = (SELECT IncentiveVersion_LL FROM scale.ModelVersionConfig WHERE appType = '@DATABASE@' AND agency = 'GNM' and tickerName = 'G2SF')
    AND slb.version = (SELECT BurnoutVersion_LL FROM scale.ModelVersionConfig WHERE appType = '@DATABASE@' AND agency = 'GNM' and tickerName = 'G2SF')
    AND slh.asOf >= '2013-08-01' -- All PIV estimated numbers before 2013-08
    AND slh.schamBalance > 0.01
    AND sl.loanType in ('FHA')
    AND slh2.delMonths <= 2
    @ASOF_WHERE@
;
COMMIT;

DELETE FROM #Symphony_loans WHERE ((hpa_annual IS NULL) or (hpa_cum < -99));
Commit;
