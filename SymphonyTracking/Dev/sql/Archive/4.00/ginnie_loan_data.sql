-- Symphony Tracking Data
-- Freddie Conventional
-- Pool Level
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
    slh.schamBalance,
    slh.currentBalance as wacls,
    sl.origFICO as fico,
    CASE WHEN loanPurposeType like 'RE-FI%' THEN 100.0 ELSE 0.0 END as pct_refi,
    slh.cltv,
    CASE WHEN slh.delMonths > 0 THEN 100.0 ELSE 0.0 END as pct_dq,
    sli.refi_incentive_eligible as incentive,
    slb.burnout as burnout,
    me.media_effect,
    ca.mca_18mo as cai,
    100.0 * hpi.HPA_2YR as hpa2yr
INTO #Symphony_loans
FROM scale.GNM_LoanHist slh
JOIN scale.GNM_Loan_dev sl ON slh.loanSeqNum = sl.loanSeqNum
JOIN scale.GNM_LoanIncentive sli
    ON slh.loanSeqNum = sli.loanSeqNum
    AND slh.asOf = sli.asOf
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
    AND sl.version = (SELECT IncentiveVersion_LL FROM scale.ModelVersionConfig WHERE appType = '3.10' AND agency = 'GNM' and tickerName = 'G2SF')
    AND sli.version = (SELECT IncentiveVersion_LL FROM scale.ModelVersionConfig WHERE appType = '3.10' AND agency = 'GNM' and tickerName = 'G2SF')
    AND slb.version = (SELECT BurnoutVersion_LL FROM scale.ModelVersionConfig WHERE appType = '3.10' AND agency = 'GNM' and tickerName = 'G2SF')
    AND slh.asOf >= '2013-08-01' -- All PIV estimated numbers before 2013-08
    AND slh.schamBalance > 0.01
    @ASOF_WHERE@
;
COMMIT;
