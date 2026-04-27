-- Symphony Tracking Data
-- Ginnie Conventional
-- Loan Level
-- Script to pull data from Scale tables for Symphony Tracking

-----------------------------------------------------------
-- Store all loans with pertinent data
-----------------------------------------------------------
DROP TABLE IF EXISTS #Symphony_loans_test;
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
    CASE WHEN (cl.loanPurposeType like 'PURCH' and cl.reperformingStatus='NONE') THEN 100.0 ELSE 0.0 END as pct_purchase,
    slh.cltv,
    CASE WHEN sli.conventional_refi_incentive >= sli.fha_refi_incentive THEN sli.conventional_refi_incentive ELSE sli.fha_refi_incentive END as turnover_incentive,
--    sli.fha_refi_incentive_fixed_cost as refinance_GNM_incentive,
--    CASE WHEN sli.conventional_refi_incentive_fixed_cost >= sli.fha_refi_incentive_fixed_cost THEN sli.conventional_refi_incentive_fixed_cost ELSE sli.fha_refi_incentive_fixed_cost END as refinance_incentive,    
    CASE WHEN sli.conventional_refi_incentive_fixed_cost >= sli.fha_refi_incentive_fixed_cost THEN sli.conventional_refi_incentive_fixed_cost ELSE sli.fha_refi_incentive_fixed_cost END as refinance_incentive,  
    slb.burnout_fixed_cost as burnout,
    me.media_effect,
    ca.mca_18mo as cai,
    CASE WHEN cl.tpoType='BROKER' THEN 100 ELSE 0 END as percentCHANNEL_BROKER,
    CASE WHEN cl.tpoType='CORRES' THEN 100 ELSE 0 END as percentCHANNEL_CORRES,
    CASE WHEN cl.tpoType='RETAIL' THEN 100 ELSE 0 END as percentCHANNEL_RETAIL,
    CASE WHEN cl.tpoType='N/A' THEN 100 ELSE 0 END as percentCHANNEL_NA,
 	CASE WHEN slh.loanAge > 0 THEN 
			CASE WHEN slh.currentBalance IS NOT NULL THEN (power((slh.currentBalance / (case when slh.cltv<=0 then 0.01 else slh.cltv end)) / (cl.originalLoanAmount / sl.origLTV), 12.0 / slh.loanAge) - 1.0) * 100 
				ELSE (power((slh.SchamBalance / (case when slh.cltv<=0 then 0.01 else slh.cltv end)) / (cl.originalLoanAmount / sl.origLTV), 12.0 / slh.loanAge) - 1.0) * 100 END
		ELSE 0.0 END as hpa_annual,
    CASE WHEN slh.currentBalance IS NOT NULL THEN ((slh.currentBalance / (case when slh.cltv<=0 then 0.01 else slh.cltv end)) / (cl.originalLoanAmount / sl.origLTV) - 1) * 100 
         ELSE ((slh.SchamBalance / (case when slh.cltv<=0 then 0.01 else slh.cltv end)) / (cl.originalLoanAmount / sl.origLTV) - 1) * 100 END as hpa_cum,
    sl.origLTV as oltv,
    CASE WHEN cl.state in ('NY') THEN 100 ELSE 0 END AS pct_NY,
    CASE WHEN (cl.loanPurposeType = 'RE-FI-CO' and cl.reperformingStatus='NONE') THEN 100.0 ELSE 0.0 END AS pct_refi_co,
    CASE WHEN (cl.loanpurposetype in ('RE-FI-STR','RE-FI-N/A','RE-FI-NSTR','N/A') and cl.reperformingStatus='NONE') THEN 100.0 ELSE 0.0 END AS pct_refi_nco,
    CASE WHEN cl.reperformingStatus = 'HMOD' THEN 100.0 ELSE 0.0 END AS pct_hmod,
    CASE WHEN cl.reperformingStatus = 'NHMOD' THEN 100.0 ELSE 0.0 END AS pct_nhmod,
    CASE WHEN cl.reperformingStatus = 'OTHER' THEN 100.0 ELSE 0.0 END AS pct_rp,  
    CASE WHEN cl.reperformingStatus = 'NONE' THEN 100.0 ELSE 0.0 END AS pct_none,     
    CASE WHEN cl.state in ('TX') THEN 100 ELSE 0 END AS pct_TX,
    CASE WHEN cl.state in ('PR') THEN 100 ELSE 0 END AS pct_PR,
    CASE WHEN (cl.UFMIPPoints = 1.0 AND cl.calcorigMonth_LL>=201206) THEN 100 ELSE 0 END AS pct_grandfather,
    slh.monthsSinceIssued,
    CASE WHEN slh.delMonths <= 2 THEN 1.0 ELSE 0.0 END AS delq_flag,
    cl.reperformingStatus as dbReperformingStatus,
    CASE WHEN slh.delMonths > 2 then 3 else slh.delMonths end as delMonths,
    CASE 
        WHEN cl.reperformingStatus = 'NONE' THEN CAST('none' AS varchar(10)) 
        WHEN cl.reperformingStatus = 'OTHER' THEN CAST('reperf' AS varchar(10)) 
        WHEN cl.reperformingStatus = 'HMOD' THEN CAST('hampMod' AS varchar(10)) 
        ELSE CAST('nonHampMod' AS varchar(10))  
    END AS reperformingStatus,
    cl.sato_orig as sato,
    cl.dti,
    cl.state,
    laggedUnemployChangeSinceStatus = cast(null as numeric(4, 2)),
    cumHPI = cast(null as numeric(6, 4)),
    (cl.coupon - c.monthlyCMM102Rate + 0.45) as buyoutIncentive,
    sbi.buyoutIndex as servicerBuyoutIndex,
    case when sli.fixedToARM_refi_incentive is null then 0 else sli.fixedToARM_refi_incentive end as FTAIncentive,
    100 * year(slh.asOf) + month(slh.asOf) as prepayMonth,
    CASE WHEN cl.cs = -999 THEN 0 ELSE 1 END as hasFICOFlag
INTO #Symphony_loans_test
FROM scale.GNM_LoanHist slh
JOIN scale.GNM_Loan_dev sl ON slh.loanSeqNum = sl.loanSeqNum
JOIN scale.GNM_LoanIncentive sli
    ON slh.loanSeqNum = sli.loanSeqNum
    AND slh.asOf = sli.asOf
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
JOIN #GNM_CMM102 c
    ON slh.asof = c.asof    
LEFT JOIN scale.servicerBuyoutIndex sbi
    ON sbi.loanType = cl.loanType
    AND sbi.reperformingStatus = dbReperformingStatus
    AND sbi.servicer = cl.currentIssuerName  
    AND sbi.version = '1.0' 
JOIN report.Martin_Loans_3 rml
    ON rml.loanSeqNum = cl.loanSeqNum    
WHERE 1=1
    AND sl.version = (SELECT originationVersion_LL FROM scale.ModelVersionConfig WHERE appType = '4.70' AND agency = 'GNM' and tickerName = 'G2SF')
    AND sli.version = (SELECT IncentiveVersion_LL FROM scale.ModelVersionConfig WHERE appType = '4.70' AND agency = 'GNM' and tickerName = 'G2SF')
    AND slb.version = (SELECT BurnoutVersion_LL FROM scale.ModelVersionConfig WHERE appType = '4.70' AND agency = 'GNM' and tickerName = 'G2SF')
    AND slh.asOf = '2019-02-01'
    AND slh.schamBalance > 0.01
--    AND sl.loanType in ('PIH', 'RHS')
    AND sl.loanType in ('FHA')
--    AND sl.loanseqnum='1509067016'
--    AND sl.loanType in ('VA')
    @ASOF_WHERE@
;
COMMIT;

DELETE FROM #Symphony_loans_test WHERE ((hpa_annual IS NULL) or (hpa_cum < -99));
Commit;
 
UPDATE #Symphony_loans_test
SET servicerBuyoutIndex = sbi.buyoutindex
FROM scale.servicerBuyoutIndex sbi, #Symphony_loans_test s
WHERE 1=1
    AND s.servicerBuyoutIndex is null
    AND sbi.reperformingStatus = s.dbReperformingStatus
    AND sbi.loanType = s.loanType
    AND sbi.servicer = 'OTHER'  
    AND sbi.version = '1.0'  
;
COMMIT;

UPDATE #Symphony_loans_test
SET s.laggedUnemployChangeSinceStatus = une.laggedUnemployChangeSinceStatus
FROM #Symphony_loans_test s, #unemploymentRate_dflt une
WHERE s.asof = une.asof AND s.state = une.state
;
COMMIT;

UPDATE #Symphony_loans_test
SET s.laggedUnemployChangeSinceStatus = une.laggedUnemployChangeSinceStatus
FROM #Symphony_loans_test s, #unemploymentRate_dflt une
WHERE s.asof = une.asof AND une.state = 'US' AND s.laggedUnemployChangeSinceStatus is NULL
;
COMMIT;

UPDATE #Symphony_loans_test
SET s.cumHPI = h.cumHPI * 100
FROM #Symphony_loans_test s, #hpi_dflt h
WHERE s.asof = h.asof AND s.state = h.state
;
COMMIT;

UPDATE #Symphony_loans_test
SET s.cumHPI = h.cumHPI * 100
FROM #Symphony_loans_test s, #hpi_dflt h
WHERE s.asof = h.asof AND h.state = 'USA' AND s.cumHPI is NULL
;
COMMIT;


