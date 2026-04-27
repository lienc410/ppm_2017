-- Symphony Tracking Data
-- Freddie Conventional
-- Loan Level
-- Script to pull data from Scale tables for Symphony Tracking


-----------------------------------------------------------
-- Store all pools with pertinent data
-----------------------------------------------------------
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
    clh.schamBalance as schamBalance,
    CASE WHEN cl.occType='OWNER' THEN 100 ELSE 0 END as percentOCC_OWN,
    CASE WHEN cl.occType='2ND' THEN 100 ELSE 0 END as percentOCC_2ND,
    CASE WHEN cl.occType='INV' THEN 100 ELSE 0 END as percentOCC_INV,
    spd.Est_Pct_CURRENT as percentCURRENT,
    spd.Est_Pct_DELQ30plus as percentDELQ30plus,
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
    CASE WHEN cl.tpoType='BROKER' THEN 100 ELSE 0 END as percentCHANNEL_BROKER,
    CASE WHEN cl.tpoType='CORRES' THEN 100 ELSE 0 END as percentCHANNEL_CORRES,
    (sle.HARP_eligible * 100) as HARP_eligible,
    clh.SATO,
	
	CASE WHEN clh.loanAge > 0 THEN
			CASE WHEN (clh.cltv=0 or slh.cltv=0.01) THEN 0.0
			WHEN (clh.calcScham IS NOT NULL and clh.cltv>0) THEN (power((clh.calcScham / clh.cltv) / (cl.originalLoanAmount / cl.origLTV), 12.0 / clh.loanAge) - 1.0) * 100 
			ELSE (power((clh.currentRPB / slh.cltv) / (cl.originalLoanAmount / cl.origLTV), 12.0 / clh.loanAge) - 1.0) * 100 END
	ELSE 0.0 END as hpa_annual,
	
	CASE WHEN (clh.cltv=0 or slh.cltv=0.01) THEN 0.0
	ELSE 
		CASE WHEN clh.calcScham IS NOT NULL THEN ((clh.calcScham / clh.cltv) / (cl.originalLoanAmount / cl.origLTV) - 1) * 100 
		ELSE ((clh.currentRPB / slh.cltv) / (cl.originalLoanAmount / cl.origLTV) - 1) * 100 END 
	END as hpa_cum,
	
	CASE WHEN cl.loanPurposeType = 'PURCH' THEN 100.0 ELSE 0.0 END AS pct_purchase,
	CASE WHEN cl.origCombLTV > cl.origLTV THEN 100 ELSE 0 END AS pct_second_lien,
	CASE WHEN sli.conventional_refi_incentive_fixed_cost >= sli.fha_refi_incentive_fixed_cost THEN sli.conventional_refi_incentive_fixed_cost ELSE sli.fha_refi_incentive_fixed_cost END as refinance_incentive,
    sfl.origLTV as oltv
INTO #Symphony_loans
FROM fnm.PIV_loan cl
--@SAMPLE_JOIN@
JOIN scale.fnm_loan_dev sfl
    ON cl.loanSeqNum = sfl.loanSeqNum
JOIN scale.fnm_loanhist slh
    ON sfl.loanSeqNum = slh.loanSeqNum
JOIN 
(
    SELECT loanSeqNum, asOf, currentRpb, loanAge, schamBalance, calcScham, SATO, remTerm, cltv FROM fnm.PIV_Derived_LoanHist
    UNION ALL
    SELECT loanSeqNum, asOf, currentRpb, loanAge, schamBalance, calcScham, SATO, remTerm, cltv FROM fnm.PIV_LoanHist WHERE asOf >= '20140101'
   
) clh
    ON cl.loanSeqNum = clh.loanSeqNum
	AND slh.asOf = clh.asOf
JOIN #ticker tk
    ON sfl.marketTicker = tk.tickerName
JOIN scale.fnm_PoolDistribution spd
    ON cl.issueId = spd.issueId
    AND slh.asOf = spd.asOf
JOIN scale.fnm_loaneligibility sle
    ON sfl.loanSeqNum = sle.loanSeqNum
    AND slh.asOf = sle.asOf
JOIN scale.fnm_loanincentive sli
    ON sfl.loanSeqNum = sli.loanSeqNum
    AND slh.asOf = sli.asOf
JOIN scale.fnm_loanburnout slb
    ON sfl.loanSeqNum = slb.loanSeqNum
    AND slh.asOf = slb.asOf
WHERE 1=1
    AND sfl.version = (SELECT originationVersion_LL FROM scale.ModelVersionConfig WHERE appType = '@DATABASE@' AND agency = 'FNM' and tickerName = 'FNCL')
    AND sli.version = (SELECT IncentiveVersion_LL FROM scale.ModelVersionConfig WHERE appType = '@DATABASE@' AND agency = 'FNM' and tickerName = 'FNCL')
    AND slb.version = (SELECT burnoutVersion_LL FROM scale.ModelVersionConfig WHERE appType = '@DATABASE@' AND agency = 'FNM' and tickerName = 'FNCL')
    @ASOF_WHERE@
	AND sfl.originationDate >= '2009-06-01'
    AND clh.calcScham > 0.01
	AND clh.currentRPB > 0.01
;
COMMIT;

