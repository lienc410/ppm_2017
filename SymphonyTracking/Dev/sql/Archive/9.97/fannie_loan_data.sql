-- Symphony Tracking Data
-- Freddie Conventional
-- Loan Level
-- Script to pull data from Scale tables for Symphony Tracking


-----------------------------------------------------------
-- Store all pools with pertinent data
-----------------------------------------------------------
DROP TABLE if EXISTS #SATO_RATE;
SELECT
marketTicker,originationDate, sum(origLoanSize*origNoteRate)/sum(origLoanSize) as rate
INTO #SATO_RATE
FROM scale.fnm_loan_dev sfl
WHERE sfl.version = (SELECT originationVersion_LL FROM scale.ModelVersionConfig WHERE appType = '@DATABASE@' AND agency = 'FNM' and tickerName = 'FNCL')
GROUP BY marketTicker, originationDate;
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
    spd.Est_Pct_CURRENT as percentCURRENT,
    spd.Est_Pct_DELQ30plus as percentDELQ30plus,
    CASE WHEN sli.conventional_refi_incentive >= sli.fha_refi_incentive THEN sli.conventional_refi_incentive ELSE sli.fha_refi_incentive END as refi_incentive,
    slb.burnout,
    clh.loanAge as wala,
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
    convert(smallmoney,(sfl.origNoteRate - sr.rate) * 100) as SATO
INTO #Symphony_loans
FROM fnm.PIV_loan cl
--@SAMPLE_JOIN@
JOIN scale.fnm_loan_dev sfl
    ON cl.loanSeqNum = sfl.loanSeqNum
JOIN scale.fnm_loanhist slh
    ON sfl.loanSeqNum = slh.loanSeqNum
JOIN 
(
    SELECT loanSeqNum, asOf, currentRpb, loanAge FROM fnm.PIV_Derived_LoanHist
    UNION ALL
    SELECT loanSeqNum, asOf, currentRpb, loanAge FROM fnm.PIV_LoanHist WHERE asOf >= '20140101'
   
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
JOIN #SATO_RATE sr
    ON sfl.marketTicker = sr.marketTicker 
    AND sfl.originationDate = sr.originationDate
WHERE 1=1
    AND sfl.version = (SELECT originationVersion_LL FROM scale.ModelVersionConfig WHERE appType = '@DATABASE@' AND agency = 'FNM' and tickerName = 'FNCL')
    AND sli.version = (SELECT IncentiveVersion_LL FROM scale.ModelVersionConfig WHERE appType = '@DATABASE@' AND agency = 'FNM' and tickerName = 'FNCL')
    AND slb.version = (SELECT burnoutVersion_LL FROM scale.ModelVersionConfig WHERE appType = '@DATABASE@' AND agency = 'FNM' and tickerName = 'FNCL')
    @ASOF_WHERE@
	AND sfl.originationDate >= '2009-06-01'
    AND clh.calcScham > 0.01
;
COMMIT;

