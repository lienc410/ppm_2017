-- Fannie Conventional
-- Pool Level
-- Part 5 of 6
-- Script to update the refinance incentive metrics
-- Updates conventional_refi_incentive, fha_refi_incentive, refi_incentive, origPMI, currLLPA, currPMI and currMIP

-- Before execute the script, need to set the dates to run for
DROP TABLE IF EXISTS #tmp_asOf;
SELECT CAST('#####ASOF#####' AS DATE) asOf INTO #tmp_asOf
--SELECT CAST ('1994-02-01' AS DATE) asOf INTO #tmp_asOf
;

-- Before execute the script, need to set the version to run for
DROP TABLE IF EXISTS #tmp_version;
SELECT CAST ('2.00' AS varchar(5)) version INTO #tmp_version
;

-- Before execute the script, need to set the tickers
DROP TABLE IF EXISTS #ticker;
CREATE TABLE #ticker(
    tickerName varchar(20),
    mtgRateSeries varchar(30)
)
;
INSERT #ticker SELECT 'FNCL', 'CONVENTIONAL_30YR';    --Conventional Fannie
INSERT #ticker SELECT 'FNCK', 'JUMBO_30YR';           --Jumbo Fannie
INSERT #ticker SELECT 'FNCQ30', 'CONVENTIONAL_30YR';  --CQ Fannie High LTV[105-125]
INSERT #ticker SELECT 'FNCR', 'CONVENTIONAL_30YR';    --CR Fannie High LTV[125-150]
COMMIT;

CREATE LF INDEX loan_tickerName_idx ON #ticker(tickerName);
COMMIT;


-- Creates the 30 YR FRM Rate (point ajdusted)
DROP TABLE IF EXISTS #Mtg30YrRates_monthly;
SELECT
    TickerName as SeriesName,
    AsOfDate as asOf, 
    convert(date, dateadd(month, +1, AsOfDate)) as asOf_lag1,
    convert(date, dateadd(month, +2, AsOfDate)) as asOf_lag2,
    SeriesNumValue as MtgRate
INTO #Mtg30YrRates_monthly
FROM report.TimeSeries ts
JOIN report.TimeSeriesMeta tsm
    ON ts.TimeSeriesMetaId = tsm.TimeSeriesMetaId
WHERE 1=1
    AND SeriesType = 'MONTHLY_MTG_RATE'
;
COMMIT;

CREATE LF INDEX series_idx ON #Mtg30YrRates_monthly(SeriesName);
CREATE LF INDEX asOf_idx ON #Mtg30YrRates_monthly(asOf);
CREATE LF INDEX asOf_lag1_idx ON #Mtg30YrRates_monthly(asOf_lag1);
CREATE LF INDEX asOf_lag2_idx ON #Mtg30YrRates_monthly(asOf_lag2);

COMMIT;


-- Create Pool Historical Data
DROP TABLE IF EXISTS #FNM_PoolIncentive;
SELECT
    ph.marketTicker,
    ph.issueId,
    ph.asOf,
    ph.originationDate,
    ph.balance,
    ph.origNoteRate as wac, 
    ph.origLTV as waoltv,
    ph.currLoanSize as waclSize,
    ph.origLoanSize as waolSize,
    ph.origFICO as waocs,
    ph.cltv as waCLTV,
    ph.miLevel,
    x.originalTerm as origTerm,
    pd.percentOCC_OWN as Pct_OWNER,
    pd.percentOCC_2ND as Pct_2ND,
    pd.percentOCC_INV as Pct_INV,
    pd.percentHARPed,
    pe.HARP_eligible,
    pe.refi_eligible,
    mr.MtgRate,
    
    cast(0 as tinyint) as has_loan_data,
    
    cast(NULL as numeric(8, 4)) as pmi_begin_base,
    cast(NULL as numeric(8, 4)) as pmi_begin_loansize,
    cast(NULL as numeric(8, 4)) as pmi_begin_occ,
    
    cast(NULL as numeric(8, 4)) as pmi_end_base,
    cast(NULL as numeric(8, 4)) as pmi_end_loansize,
    cast(NULL as numeric(8, 4)) as pmi_end_occ,
    
    cast(NULL as numeric(8, 4)) as llpa_base,
    cast(NULL as numeric(8, 4)) as llpa_admc,
    cast(NULL as numeric(8, 4)) as llpa_occ,
    cast(NULL as numeric(8, 4)) as llpa_ltv,
    cast(NULL as numeric(8, 4)) as llpa_loansize,
    
    cast(NULL as numeric(8, 4)) as pmi_begin,
    cast(NULL as numeric(8, 4)) as pmi,
    cast(NULL as numeric(8, 4)) as llpa,
    cast(NULL as numeric(8, 4)) as mip,
    
    cast(NULL as numeric(10, 4)) as conventional_refi_incentive,
    cast(NULL as numeric(10, 4)) as fha_refi_incentive,
    cast(NULL as numeric(10, 4)) as refi_incentive,
    cast(NULL as numeric(10, 4)) as refi_incentive_eligible
    
INTO #FNM_PoolIncentive
FROM scale.FNM_PoolHist ph
JOIN #ticker tk
    ON ph.marketTicker = tk.tickerName
JOIN fnm.sec p
    ON ph.issueId = p.issueId
JOIN fnm.Prefix x
    ON p.prefix = x.prefix
    AND p.product = x.product
JOIN scale.FNM_PoolDistribution pd
    ON ph.issueId = pd.issueId
    AND ph.asOf = pd.asOf
JOIN scale.FNM_PoolEligibility pe
    ON ph.issueId = pe.issueId
    AND ph.asOf = pe.asOf
JOIN #Mtg30YrRates_monthly mr
    ON mr.asOf_lag1 = ph.asOf
    AND mr.SeriesName = tk.mtgRateSeries
WHERE 1=1
    AND ph.asOf >= (select asOf from #tmp_asOf)
;
COMMIT;

CREATE HG INDEX issueId_idx ON #FNM_PoolIncentive(issueId);
CREATE LF INDEX asOf_idx ON #FNM_PoolIncentive(asOf);
CREATE LF INDEX ticker_idx ON #FNM_PoolIncentive(marketTicker);
COMMIT;


------------------------------------------------------------
-- Step 1: Compute all metrics using Loan Data
------------------------------------------------------------
DROP TABLE IF EXISTS #FNM_LoanBasedIncentive;
SELECT
    pi.issueId,
    pi.asOf,
    sum(sl.origPMI * slh.balance) / sum(CASE WHEN sl.origPMI IS NULL THEN 0.0 ELSE slh.balance END) as pmi_begin,
    sum(sli.currPMI * slh.balance) / sum(CASE WHEN sli.currPMI IS NULL THEN 0.0 ELSE slh.balance END) as pmi,
    sum(sli.currLLPA * slh.balance) / sum(CASE WHEN sli.currLLPA IS NULL THEN 0.0 ELSE slh.balance END) as llpa,
    sum(sli.currMIP * slh.balance) / sum(CASE WHEN sli.currMIP IS NULL THEN 0.0 ELSE slh.balance END) as mip,
    sum(sli.conventional_refi_incentive * slh.balance) / sum(CASE WHEN sli.conventional_refi_incentive IS NULL THEN 0.0 ELSE slh.balance END) as conventional_refi_incentive,
    sum(sli.fha_refi_incentive * slh.balance) / sum(CASE WHEN sli.fha_refi_incentive IS NULL THEN 0.0 ELSE slh.balance END) as fha_refi_incentive,
    sum((CASE WHEN sli.conventional_refi_incentive > sli.fha_refi_incentive THEN sli.conventional_refi_incentive ELSE sli.fha_refi_incentive END) * slh.balance) / sum(slh.balance) as refi_incentive,
    sum(sli.refi_incentive_eligible * slh.balance) / sum(CASE WHEN sli.refi_incentive_eligible IS NULL THEN 0.0 ELSE slh.balance END) as refi_incentive_eligible
INTO #FNM_LoanBasedIncentive
FROM #FNM_PoolIncentive pi
JOIN fnm.PIV_Loan cl
    ON pi.issueId = cl.issueId
JOIN scale.FNM_Loan sl
    ON cl.loanSeqNum = sl.loanSeqNum
JOIN scale.fnm_LoanHist slh
    ON cl.loanSeqNum = slh.loanSeqNum
    AND pi.asOf = slh.asOf
JOIN scale.FNM_LoanIncentive sli
    ON slh.loanSeqNum = sli.loanSeqNum
    AND slh.asOf = sli.asOf
WHERE 1=1
    AND sli.conventional_refi_incentive IS NOT NULL
GROUP BY pi.issueId, pi.asOf
;
COMMIT;

UPDATE #FNM_PoolIncentive pi SET
    pi.has_loan_data = 1,
    pi.pmi_begin = lbi.pmi_begin, 
    pi.pmi = lbi.pmi, 
    pi.llpa = lbi.llpa,
    pi.mip = lbi.mip,
    pi.conventional_refi_incentive = lbi.conventional_refi_incentive,
    pi.fha_refi_incentive = lbi.fha_refi_incentive,
    pi.refi_incentive = lbi.refi_incentive,
    pi.refi_incentive_eligible = lbi.refi_incentive_eligible
FROM #FNM_LoanBasedIncentive lbi
WHERE pi.issueId = lbi.issueId
    AND pi.asOf = lbi.asOf
;
COMMIT;

DROP TABLE IF EXISTS #FNM_MIN_Incentive;
SELECT
    issueId,
    min(asOf) as min_asOf,
    cast(NULL as numeric(8, 4)) as earliest_MtgRate,
    cast(NULL as numeric(8, 4)) as earliest_pmi_begin,
    cast(NULL as numeric(8, 4)) as earliest_pmi,
    cast(NULL as numeric(8, 4)) as earliest_llpa,
    cast(NULL as numeric(8, 4)) as earliest_mip, 
    cast(NULL as numeric(10, 4)) as earliest_conventional_refi_incentive,
    cast(NULL as numeric(10, 4)) as earliest_fha_refi_incentive,
    cast(NULL as numeric(10, 4)) as earliest_refi_incentive,
    cast(NULL as numeric(10, 4)) as earliest_refi_incentive_eligible
INTO #FNM_MIN_Incentive
FROM #FNM_PoolIncentive
WHERE 1=1
    AND refi_incentive IS NOT NULL
    AND issueId in (SELECT distinct issueId from #FNM_LoanBasedIncentive)
GROUP BY issueId
;
COMMIT;

UPDATE #FNM_MIN_Incentive mi SET 
    mi.earliest_MtgRate = pi.MtgRate,
    mi.earliest_pmi_begin = pi.pmi_begin,
    mi.earliest_pmi = pi.pmi,
    mi.earliest_llpa = pi.llpa,
    mi.earliest_mip = pi.mip,
    mi.earliest_conventional_refi_incentive = pi.conventional_refi_incentive,
    mi.earliest_fha_refi_incentive = pi.fha_refi_incentive,
    mi.earliest_refi_incentive = pi.refi_incentive,
    mi.earliest_refi_incentive_eligible = pi.refi_incentive_eligible
FROM #FNM_PoolIncentive pi
WHERE mi.issueId = pi.issueId
    AND mi.min_asOf = pi.asOf
;

UPDATE #FNM_PoolIncentive pi SET 
    pi.pmi_begin = mi.earliest_pmi_begin,
    pi.pmi = mi.earliest_pmi, 
    pi.llpa = mi.earliest_llpa,
    pi.mip = mi.earliest_mip,
    pi.conventional_refi_incentive = (mi.earliest_MtgRate - pi.MtgRate) + mi.earliest_conventional_refi_incentive,
    pi.fha_refi_incentive = (mi.earliest_MtgRate - pi.MtgRate) + mi.earliest_fha_refi_incentive,
    pi.refi_incentive = (mi.earliest_MtgRate - pi.MtgRate) + mi.earliest_refi_incentive,
    pi.refi_incentive_eligible = (mi.earliest_MtgRate - pi.MtgRate) + mi.earliest_refi_incentive_eligible
FROM #FNM_MIN_Incentive mi
WHERE pi.issueId = mi.issueId
    AND pi.refi_incentive IS NULL
;

------------------------------------------------------------
-- Step 2: Compute all metrics using Pool Data
------------------------------------------------------------
DROP TABLE IF EXISTS #FNM_PoolBasedIncentive;
SELECT * 
INTO #FNM_PoolBasedIncentive
FROM #FNM_PoolIncentive
WHERE 1=1
--    AND issueId NOT IN (SELECT distinct issueId from #FNM_LoanBasedIncentive)
;
COMMIT;

-- Update pmi_begin_base
UPDATE #FNM_PoolBasedIncentive inc SET inc.pmi_begin_base = pmi.PMI
FROM report.PIV_PMI_Base pmi
WHERE 1=1
    AND LoanPurpose = 'REFI'
    AND inc.originationDate >= pmi.startDate and inc.originationDate < pmi.endDate 
    AND inc.waocs >= pmi.FICObucketStart and inc.waocs < pmi.FICObucketEnd
    AND inc.waoltv > pmi.LTVBucketStart and inc.waoltv <= pmi.LTVBucketEnd
;

UPDATE #FNM_PoolBasedIncentive inc SET inc.pmi_begin_base = pmi.PMI
FROM report.PIV_PMI_Base pmi
WHERE 1=1
    AND LoanPurpose = 'REFI'
    AND inc.originationDate >= pmi.startDate and inc.originationDate < pmi.endDate 
    AND 700 >= pmi.FICObucketStart and 700 < pmi.FICObucketEnd
    AND inc.waoltv > pmi.LTVBucketStart and inc.waoltv <= pmi.LTVBucketEnd
    AND inc.pmi_begin_base IS NULL
;

UPDATE #FNM_PoolBasedIncentive inc SET inc.pmi_begin_base = 0 WHERE inc.pmi_begin_base IS NULL;

-- Update pmi_begin_loansize
UPDATE #FNM_PoolBasedIncentive inc SET inc.pmi_begin_loansize = pmi.PMI
FROM report.PIV_PMI_LoanSize pmi
WHERE 1=1
    AND inc.originationDate >= pmi.startDate and inc.originationDate < pmi.endDate 
    AND inc.waocs >= pmi.FICObucketStart and inc.waocs < pmi.FICObucketEnd
    AND inc.waoltv > pmi.LTVBucketStart and inc.waoltv <= pmi.LTVBucketEnd
    AND inc.waolSize > pmi.LoanSizeStart and inc.waolSize <= pmi.LoanSizeEnd
;
    
UPDATE #FNM_PoolBasedIncentive inc SET inc.pmi_begin_loansize = pmi.PMI
FROM report.PIV_PMI_LoanSize pmi
WHERE 1=1
    AND inc.originationDate >= pmi.startDate and inc.originationDate < pmi.endDate 
    AND 700 >= pmi.FICObucketStart and 700 < pmi.FICObucketEnd
    AND inc.waoltv > pmi.LTVBucketStart and inc.waoltv <= pmi.LTVBucketEnd
    AND inc.waolSize > pmi.LoanSizeStart and inc.waolSize <= pmi.LoanSizeEnd
    AND inc.pmi_begin_loansize IS NULL
;
    
UPDATE #FNM_PoolBasedIncentive inc SET inc.pmi_begin_loansize = 0 WHERE inc.pmi_begin_loansize IS NULL;

-- Update pmi_begin_occ
UPDATE #FNM_PoolBasedIncentive inc SET inc.pmi_begin_occ = (pmi_owner.PMI * inc.Pct_OWNER + pmi_2nd.PMI * inc.Pct_2ND + pmi_inv.PMI * inc.Pct_INV) / 100.0
FROM report.PIV_PMI_Occupancy pmi_owner, report.PIV_PMI_Occupancy pmi_2nd, report.PIV_PMI_Occupancy pmi_inv
WHERE 1=1
    AND pmi_owner.OccType = 'OWNER'
    AND inc.originationDate >= pmi_owner.startDate and inc.originationDate < pmi_owner.endDate 
    AND inc.waocs >= pmi_owner.FICObucketStart and inc.waocs < pmi_owner.FICObucketEnd
    AND inc.waoltv > pmi_owner.LTVBucketStart and inc.waoltv <= pmi_owner.LTVBucketEnd
   
    AND pmi_2nd.OccType = '2ND'
    AND inc.originationDate >= pmi_2nd.startDate and inc.originationDate < pmi_2nd.endDate 
    AND inc.waocs >= pmi_2nd.FICObucketStart and inc.waocs < pmi_2nd.FICObucketEnd
    AND inc.waoltv > pmi_2nd.LTVBucketStart and inc.waoltv <= pmi_2nd.LTVBucketEnd
    
    AND pmi_inv.OccType = 'INV'
    AND inc.originationDate >= pmi_inv.startDate and inc.originationDate < pmi_inv.endDate 
    AND inc.waocs >= pmi_inv.FICObucketStart and inc.waocs < pmi_inv.FICObucketEnd
    AND inc.waoltv > pmi_inv.LTVBucketStart and inc.waoltv <= pmi_inv.LTVBucketEnd
;

UPDATE #FNM_PoolBasedIncentive inc SET inc.pmi_begin_occ = 0 WHERE inc.pmi_begin_occ IS NULL;

--UPDATE #FNM_PoolBasedIncentive inc SET
--    pmi_begin = (pmi_begin_base + pmi_begin_loansize + pmi_begin_occ)
--;


---- Update origPMI based on HARP Percent
----  Olny apply on CQs/CRs
--UPDATE #FNM_PoolBasedIncentive inc
--SET inc.pmi_begin = percentHARPed / 100 * (100 * m.PMI) + (100 - percentHARPed) / 100 * inc.pmi_begin
--FROM report.PIV_PMI_HARP_MtgIns_Map m
--WHERE 1=1
--    AND miLevel > pctMtgInsLow
--    AND miLevel <= pctMtgInsHigh
--    AND inc.marketTicker IN ('FNCQ30', 'FNCR')
--;
--COMMIT;

-- Update pmi_end_base
UPDATE #FNM_PoolBasedIncentive inc SET inc.pmi_end_base = pmi.PMI
FROM report.PIV_PMI_Base pmi
WHERE 1=1
    AND LoanPurpose = 'REFI'
    AND inc.asOf >= pmi.startDate and inc.asOf < pmi.endDate 
    AND inc.waocs >= pmi.FICObucketStart and inc.waocs < pmi.FICObucketEnd
    AND inc.waCLTV > pmi.LTVBucketStart and inc.waCLTV <= pmi.LTVBucketEnd
;

UPDATE #FNM_PoolBasedIncentive inc SET inc.pmi_end_base = pmi.PMI
FROM report.PIV_PMI_Base pmi
WHERE 1=1
    AND LoanPurpose = 'REFI'
    AND inc.asOf >= pmi.startDate and inc.asOf < pmi.endDate 
    AND 700 >= pmi.FICObucketStart and 700 < pmi.FICObucketEnd
    AND inc.waCLTV > pmi.LTVBucketStart and inc.waCLTV <= pmi.LTVBucketEnd
    AND inc.pmi_end_base IS NULL
;

UPDATE #FNM_PoolBasedIncentive inc SET inc.pmi_end_base = 0 WHERE inc.pmi_end_base IS NULL;

-- Update pmi_end_loansize
UPDATE #FNM_PoolBasedIncentive inc SET inc.pmi_end_loansize = pmi.PMI
FROM report.PIV_PMI_LoanSize pmi
WHERE 1=1
    AND inc.asOf >= pmi.startDate and inc.asOf < pmi.endDate 
    AND inc.waocs >= pmi.FICObucketStart and inc.waocs < pmi.FICObucketEnd
    AND inc.waCLTV > pmi.LTVBucketStart and inc.waCLTV <= pmi.LTVBucketEnd
    AND inc.waclSize > pmi.LoanSizeStart and inc.waclSize <= pmi.LoanSizeEnd
;

UPDATE #FNM_PoolBasedIncentive inc SET inc.pmi_end_loansize = pmi.PMI
FROM report.PIV_PMI_LoanSize pmi
WHERE 1=1
    AND inc.asOf >= pmi.startDate and inc.asOf < pmi.endDate 
    AND 700 >= pmi.FICObucketStart and 700 < pmi.FICObucketEnd
    AND inc.waCLTV > pmi.LTVBucketStart and inc.waCLTV <= pmi.LTVBucketEnd
    AND inc.waclSize > pmi.LoanSizeStart and inc.waclSize <= pmi.LoanSizeEnd
    AND inc.pmi_end_loansize IS NULL
;

UPDATE #FNM_PoolBasedIncentive inc SET inc.pmi_end_loansize = 0 WHERE inc.pmi_end_loansize IS NULL;

-- Update pmi_end_occ
UPDATE #FNM_PoolBasedIncentive inc SET inc.pmi_end_occ = (pmi_owner.PMI * inc.Pct_OWNER + pmi_2nd.PMI * inc.Pct_2ND + pmi_inv.PMI * inc.Pct_INV) / 100.0
FROM report.PIV_PMI_Occupancy pmi_owner, report.PIV_PMI_Occupancy pmi_2nd, report.PIV_PMI_Occupancy pmi_inv
WHERE 1=1
    AND pmi_owner.OccType = 'OWNER'
    AND inc.asOf >= pmi_owner.startDate and inc.asOf < pmi_owner.endDate 
    AND inc.waocs >= pmi_owner.FICObucketStart and inc.waocs < pmi_owner.FICObucketEnd
    AND inc.waCLTV > pmi_owner.LTVBucketStart and inc.waCLTV <= pmi_owner.LTVBucketEnd
   
    AND pmi_2nd.OccType = '2ND'
    AND inc.asOf >= pmi_2nd.startDate and inc.asOf < pmi_2nd.endDate 
    AND inc.waocs >= pmi_2nd.FICObucketStart and inc.waocs < pmi_2nd.FICObucketEnd
    AND inc.waCLTV > pmi_2nd.LTVBucketStart and inc.waCLTV <= pmi_2nd.LTVBucketEnd
    
    AND pmi_inv.OccType = 'INV'
    AND inc.asOf >= pmi_inv.startDate and inc.asOf < pmi_inv.endDate 
    AND inc.waocs >= pmi_inv.FICObucketStart and inc.waocs < pmi_inv.FICObucketEnd
    AND inc.waCLTV > pmi_inv.LTVBucketStart and inc.waCLTV <= pmi_inv.LTVBucketEnd
;

UPDATE #FNM_PoolBasedIncentive inc SET inc.pmi_end_occ = 0 WHERE inc.pmi_end_occ IS NULL;

-- Update Base LLPA
UPDATE #FNM_PoolBasedIncentive inc SET inc.llpa_base = llpa.LLPA
FROM report.PIV_LLPA_Base llpa
WHERE 1=1
    AND inc.asOf >= llpa.startDate and inc.asOf < llpa.endDate 
    AND inc.waocs >= llpa.FICObucketStart and inc.waocs < llpa.FICObucketEnd
    AND inc.waCLTV > llpa.LTVBucketStart and inc.waCLTV <= llpa.LTVBucketEnd
;

UPDATE #FNM_PoolBasedIncentive inc SET inc.llpa_base = llpa.LLPA
FROM report.PIV_LLPA_Base llpa
WHERE 1=1
    AND inc.asOf >= llpa.startDate and inc.asOf < llpa.endDate 
    AND 700 >= llpa.FICObucketStart and 700 < llpa.FICObucketEnd
    AND inc.waCLTV > llpa.LTVBucketStart and inc.waCLTV <= llpa.LTVBucketEnd
    AND inc.llpa_base IS NULL
;

UPDATE #FNM_PoolBasedIncentive inc SET inc.llpa_base = 0 WHERE inc.llpa_base IS NULL;

-- Update ADMC LLPA
UPDATE #FNM_PoolBasedIncentive inc SET inc.llpa_admc = llpa.LLPA
FROM report.PIV_LLPA_ADMC llpa
WHERE 1=1
    AND inc.asOf >= llpa.startDate and inc.asOf < llpa.endDate 
;

UPDATE #FNM_PoolBasedIncentive inc SET inc.llpa_admc = 0 WHERE inc.llpa_admc IS NULL;

-- Update Occupancy LLPA
UPDATE #FNM_PoolBasedIncentive inc SET inc.llpa_occ = (llpa_owner.LLPA * inc.Pct_OWNER + llpa_2nd.LLPA * inc.Pct_2ND + llpa_inv.LLPA * inc.Pct_INV) / 100.0
FROM report.PIV_LLPA_Occupancy llpa_owner, report.PIV_LLPA_Occupancy llpa_2nd, report.PIV_LLPA_Occupancy llpa_inv
WHERE 1=1
    AND llpa_owner.OccType = 'OWNER'
    AND inc.asOf >= llpa_owner.startDate and inc.asOf < llpa_owner.endDate 
    AND inc.waCLTV > llpa_owner.LTVBucketStart and inc.waCLTV <= llpa_owner.LTVBucketEnd
    
    AND llpa_2nd.OccType = '2ND'
    AND inc.asOf >= llpa_2nd.startDate and inc.asOf < llpa_2nd.endDate 
    AND inc.waCLTV > llpa_2nd.LTVBucketStart and inc.waCLTV <= llpa_2nd.LTVBucketEnd
    
    AND llpa_inv.OccType = 'INV'
    AND inc.asOf >= llpa_inv.startDate and inc.asOf < llpa_inv.endDate 
    AND inc.waCLTV > llpa_inv.LTVBucketStart and inc.waCLTV <= llpa_inv.LTVBucketEnd
;

UPDATE #FNM_PoolBasedIncentive inc SET inc.llpa_occ = 0 WHERE inc.llpa_occ IS NULL;

-- Update LTV LLPA
UPDATE #FNM_PoolBasedIncentive inc SET inc.llpa_ltv = llpa.LLPA
FROM report.PIV_LLPA_LTV llpa
WHERE 1=1
    AND inc.asOf >= llpa.startDate and inc.asOf < llpa.endDate 
    AND inc.waCLTV > llpa.LTVBucketStart and inc.waCLTV <= llpa.LTVBucketEnd
;

UPDATE #FNM_PoolBasedIncentive inc SET inc.llpa_ltv = 0 WHERE inc.llpa_ltv IS NULL;

-- Update Loan Size
UPDATE #FNM_PoolBasedIncentive inc SET inc.llpa_loansize = llpa.LLPA
FROM report.PIV_LLPA_LoanSize llpa
WHERE 1=1
    AND inc.asOf >= llpa.startDate and inc.asOf < llpa.endDate 
    AND inc.waclSize > llpa.LoanSizeBucketStart and inc.waclSize <= llpa.LoanSizeBucketEnd
    AND inc.waCLTV > llpa.LTVBucketStart and inc.waCLTV <= llpa.LTVBucketEnd
;

UPDATE #FNM_PoolBasedIncentive inc SET inc.llpa_loansize = 0 WHERE inc.llpa_loansize IS NULL;

-- Update PMI and LLPA Incentive
UPDATE #FNM_PoolBasedIncentive inc SET
    pmi_begin = (pmi_begin_base + pmi_begin_loansize + pmi_begin_occ)
WHERE pmi_begin IS NULL
;

UPDATE #FNM_PoolBasedIncentive inc SET
    pmi = ((100.0 - HARP_eligible) / 100.0) * (pmi_end_base + pmi_end_loansize + pmi_end_occ)
WHERE pmi IS NULL
;

UPDATE #FNM_PoolBasedIncentive inc SET
    llpa = ((HARP_eligible * (CASE WHEN llpa_base + llpa_admc + llpa_occ + llpa_ltv + llpa_loansize > 75.0 THEN 75.0 ELSE llpa_base + llpa_admc + llpa_occ + llpa_ltv + llpa_loansize END)) 
        + (100.0 - HARP_eligible) * (llpa_base + llpa_admc + llpa_occ + llpa_ltv + llpa_loansize)) / 100.0
WHERE llpa IS NULL
;

-- Update MIP
--UPDATE #FNM_PoolBasedIncentive inc SET inc.mip = CASE WHEN inc.waCLTV <= 78.0 THEN 0.0 ELSE 55.0 + 1.0 / 12.0 END
--WHERE inc.asOf > '2012-06-01'
--    AND inc.originationDate <= '2009-05-01'
--;
UPDATE #FNM_PoolBasedIncentive inc SET inc.mip = mip_base.AnnualMIPPoints + mip_base.UpfrontMIPPoints / 12.0
FROM (Select * from report.PIV_MIP_Base UNION Select * from report.PIV_MIP_Grandfather) mip_base
WHERE 1=1
    AND inc.origTerm              >   mip_base.TermBucketStart
	AND inc.origTerm              <= mip_base.TermBucketEnd
	AND inc.waCLTV                    >   mip_base.LTVBucketStart
	AND inc.waCLTV                    <= mip_base.LTVBucketEnd
	AND inc.waclSize           >=   mip_base.LoanSizeBucketStart
	AND inc.waclSize           <= mip_base.LoanSizeBucketEnd
    AND inc.originationDate      >   mip_base.OriginationStartDate
	AND inc.originationDate      <= mip_base.OriginationEndDate
	AND inc.asOf                    >   mip_base.StartDate
	AND inc.asOf                    <= mip_base.EndDate
    AND inc.mip IS NULL
;
COMMIT;

-- Update Refinance Incentive
UPDATE #FNM_PoolBasedIncentive inc SET
    conventional_refi_incentive = 100.0 * (wac + (pmi_begin / 100.0) - MtgRate - (llpa / 400.0) - (pmi / 100.0)),
    fha_refi_incentive = 100.0 * (wac + (pmi_begin / 100.0) - MtgRate - (mip / 100.0))
;

UPDATE #FNM_PoolBasedIncentive inc SET
    refi_incentive = CASE WHEN conventional_refi_incentive >= fha_refi_incentive THEN conventional_refi_incentive ELSE fha_refi_incentive END
;

-- Update Refinance Incentive Eligible
DROP TABLE IF EXISTS #FNM_IncentiveBias;
SELECT
    CASE
        WHEN refi_incentive <= -100 THEN -100
        WHEN refi_incentive <= -90 THEN -90
        WHEN refi_incentive <= -80 THEN -80
        WHEN refi_incentive <= -70 THEN -70
        WHEN refi_incentive <= -60 THEN -60
        WHEN refi_incentive <= -50 THEN -50
        WHEN refi_incentive <= -40 THEN -40
        WHEN refi_incentive <= -20 THEN -20
        WHEN refi_incentive <= 0 THEN 0
        WHEN refi_incentive <= 25 THEN 25
        WHEN refi_incentive <= 50 THEN 50
        WHEN refi_incentive <= 75 THEN 75
        WHEN refi_incentive <= 100 THEN 100
        WHEN refi_incentive <= 125 THEN 125
        WHEN refi_incentive <= 150 THEN 150
        WHEN refi_incentive <= 175 THEN 175
        WHEN refi_incentive <= 200 THEN 200
        WHEN refi_incentive <= 250 THEN 250
        WHEN refi_incentive <= 300 THEN 300
        WHEN refi_incentive <= 350 THEN 350
        WHEN refi_incentive <= 400 THEN 400
        WHEN refi_incentive <= 450 THEN 450
        ELSE 500
    END as refi_bucket,
    count(1) as cnt,
    avg(refi_incentive_eligible - refi_incentive) as avg_diff
INTO #FNM_IncentiveBias
FROM #FNM_LoanBasedIncentive
WHERE 1=1
    AND refi_incentive_eligible IS NOT NULL
    AND refi_incentive IS NOT NULL
GROUP BY refi_bucket
ORDER BY refi_bucket
;

DROP TABLE IF EXISTS #FNM_Buckets;
SELECT
    issueId,
    asOf,
    CASE
        WHEN refi_incentive <= -100 THEN -100
        WHEN refi_incentive <= -90 THEN -90
        WHEN refi_incentive <= -80 THEN -80
        WHEN refi_incentive <= -70 THEN -70
        WHEN refi_incentive <= -60 THEN -60
        WHEN refi_incentive <= -50 THEN -50
        WHEN refi_incentive <= -40 THEN -40
        WHEN refi_incentive <= -20 THEN -20
        WHEN refi_incentive <= 0 THEN 0
        WHEN refi_incentive <= 25 THEN 25
        WHEN refi_incentive <= 50 THEN 50
        WHEN refi_incentive <= 75 THEN 75
        WHEN refi_incentive <= 100 THEN 100
        WHEN refi_incentive <= 125 THEN 125
        WHEN refi_incentive <= 150 THEN 150
        WHEN refi_incentive <= 175 THEN 175
        WHEN refi_incentive <= 200 THEN 200
        WHEN refi_incentive <= 250 THEN 250
        WHEN refi_incentive <= 300 THEN 300
        WHEN refi_incentive <= 350 THEN 350
        WHEN refi_incentive <= 400 THEN 400
        WHEN refi_incentive <= 450 THEN 450
        ELSE 500
    END as refi_bucket
INTO #FNM_Buckets
FROM #FNM_PoolBasedIncentive
;

UPDATE #FNM_PoolBasedIncentive inc SET
    inc.refi_incentive_eligible = inc.refi_incentive + ib.avg_diff
FROM #FNM_IncentiveBias ib, #FNM_Buckets bu
WHERE 1=1
    AND inc.issueId = bu.issueId
    AND inc.asOf = bu.asOf
    AND ib.refi_bucket = bu.refi_bucket
;
COMMIT;

-- Update FNM_PoolIncentive
UPDATE #FNM_PoolIncentive pi SET
    pi.pmi_begin_base = pbi.pmi_begin_base,
    pi.pmi_begin_loansize = pbi.pmi_begin_loansize,
    pi.pmi_begin_occ = pbi.pmi_begin_occ,
    pi.pmi_end_base = pbi.pmi_end_base,
    pi.pmi_end_loansize = pbi.pmi_end_loansize,
    pi.pmi_end_occ = pbi.pmi_end_occ,
    pi.llpa_base = pbi.llpa_base,
    pi.llpa_admc = pbi.llpa_admc,
    pi.llpa_occ = pbi.llpa_occ,
    pi.llpa_ltv = pbi.llpa_ltv,
    pi.llpa_loansize = pbi.llpa_loansize,
    pi.pmi_begin = pbi.pmi_begin, 
    pi.pmi = pbi.pmi, 
    pi.llpa = pbi.llpa,
    pi.mip = pbi.mip,
    pi.conventional_refi_incentive = pbi.conventional_refi_incentive,
    pi.fha_refi_incentive = pbi.fha_refi_incentive,
    pi.refi_incentive = pbi.refi_incentive,
    pi.refi_incentive_eligible = pbi.refi_incentive_eligible
FROM #FNM_PoolBasedIncentive pbi
WHERE pi.issueId = pbi.issueId
    AND pi.asOf = pbi.asOf
;
COMMIT;



-- Tests

-- Time Series Tests
-- History for: conventional_refi_incentive, fha_refi_incentive, refi_incentive, refi_incentive_eligible, origPMI, currLLPA, currPMI, currMIP
--SELECT marketTicker, asOf, count(1), sum(balance), sum(balance * conventional_refi_incentive) / sum(CASE WHEN conventional_refi_incentive IS NULL THEN 0.0 ELSE balance END) as wavg_conventional_refi_incentive FROM #FNM_PoolIncentive GROUP BY marketTicker, asOf ORDER BY asOf

--SELECT marketTicker, asOf, count(1), sum(balance), sum(balance * fha_refi_incentive) / sum(CASE WHEN fha_refi_incentive IS NULL THEN 0.0 ELSE balance END) as wavg_fha_refi_incentive FROM #FNM_PoolIncentive GROUP BY marketTicker, asOf ORDER BY asOf

--SELECT marketTicker, asOf, count(1), sum(balance), sum(balance * refi_incentive) / sum(CASE WHEN refi_incentive IS NULL THEN 0.0 ELSE balance END) as wavg_refi_incentive FROM #FNM_PoolIncentive GROUP BY marketTicker, asOf ORDER BY asOf

--SELECT marketTicker, asOf, count(1), sum(balance), sum(balance * refi_incentive_eligible) / sum(CASE WHEN refi_incentive_eligible IS NULL THEN 0.0 ELSE balance END) as wavg_refi_incentive_eligible FROM #FNM_PoolIncentive GROUP BY marketTicker, asOf ORDER BY asOf

--SELECT marketTicker, asOf, count(1), sum(balance), sum(balance * pmi_begin) / sum(CASE WHEN pmi_begin IS NULL THEN 0.0 ELSE balance END) as wavg_orig_pmi FROM #FNM_PoolIncentive GROUP BY marketTicker, asOf ORDER BY asOf

--SELECT marketTicker, asOf, count(1), sum(balance), sum(balance * llpa) / sum(CASE WHEN llpa IS NULL THEN 0.0 ELSE balance END) as wavg_llpa FROM #FNM_PoolIncentive GROUP BY marketTicker, asOf ORDER BY asOf

--SELECT marketTicker, asOf, count(1), sum(balance), sum(balance * pmi) / sum(CASE WHEN pmi IS NULL THEN 0.0 ELSE balance END) as wavg_pmi FROM #FNM_PoolIncentive GROUP BY marketTicker, asOf ORDER BY asOf

--SELECT marketTicker, asOf, count(1), sum(balance), sum(balance * mip) / sum(CASE WHEN mip IS NULL THEN 0.0 ELSE balance END) as wavg_mip FROM #FNM_PoolIncentive GROUP BY marketTicker, asOf ORDER BY asOf

----------------------------------------------------------------------------------------------
-- Check to see if Pools have conventional_refi_incentive IS NULL OR conventional_refi_incentive < -1000.0 OR conventional_refi_incentive > 2000.0
----------------------------------------------------------------------------------------------
        declare   @cnt int
        SELECT
            @cnt =  count(1)
        FROM #FNM_PoolIncentive WHERE conventional_refi_incentive IS NULL OR conventional_refi_incentive < -1000.0 OR conventional_refi_incentive > 2000.0

        if (@cnt > 0)
        BEGIN
            RAISERROR 99999 'FNM Pools with INVALID VALUE for conventional_refi_incentive PoolCount : %1!', @cnt
            RETURN
        END

----------------------------------------------------------------------------------------------
-- Check to see if Pools have fha_refi_incentive IS NULL OR fha_refi_incentive < -1000.0 OR fha_refi_incentive > 2000.0
----------------------------------------------------------------------------------------------
        SELECT
            @cnt =  count(1)
        FROM #FNM_PoolIncentive WHERE fha_refi_incentive IS NULL OR fha_refi_incentive < -1000.0 OR fha_refi_incentive > 2000.0

        if (@cnt > 0)
        BEGIN
            RAISERROR 99999 'FNM Pools with INVALID VALUE for fha_refi_incentive PoolCount : %1!', @cnt
            RETURN
        END

----------------------------------------------------------------------------------------------
-- Check to see if Pools have refi_incentive IS NULL OR refi_incentive < -1000.0 OR refi_incentive > 2000.0
----------------------------------------------------------------------------------------------
        SELECT
            @cnt =  count(1)
        FROM #FNM_PoolIncentive WHERE refi_incentive IS NULL OR refi_incentive < -1000.0 OR refi_incentive > 2000.0

        if (@cnt > 0)
        BEGIN
            RAISERROR 99999 'FNM Pools with INVALID VALUE for refi_incentive PoolCount : %1!', @cnt
            RETURN
        END

----------------------------------------------------------------------------------------------
-- Check to see if Pools have refi_incentive_eligible < -1000.0 OR refi_incentive_eligible > 2000.0
----------------------------------------------------------------------------------------------
        SELECT
            @cnt =  count(1)
        FROM #FNM_PoolIncentive WHERE refi_incentive_eligible < -1000.0 OR refi_incentive_eligible > 2000.0

        if (@cnt > 0)
        BEGIN
            RAISERROR 99999 'FNM Pools with INVALID VALUE for refi_incentive_eligible PoolCount : %1!', @cnt
            RETURN
        END
        
----------------------------------------------------------------------------------------------
-- Check to see if Pools have pmi_begin IS NULL OR pmi_begin < 0.0 OR pmi_begin > 300
----------------------------------------------------------------------------------------------
        SELECT
            @cnt =  count(1)
        FROM #FNM_PoolIncentive WHERE pmi_begin IS NULL OR pmi_begin < 0.0 OR pmi_begin > 300

        if (@cnt > 0)
        BEGIN
            RAISERROR 99999 'FNM Pools with INVALID VALUE for pmi_begin PoolCount : %1!', @cnt
            RETURN
        END

----------------------------------------------------------------------------------------------
-- Check to see if Pools have llpa IS NULL OR llpa < -25.0 OR llpa > 1000.0
----------------------------------------------------------------------------------------------
        SELECT
            @cnt =  count(1)
        FROM #FNM_PoolIncentive WHERE llpa IS NULL OR llpa < -25.0 OR llpa > 1000.0

        if (@cnt > 0)
        BEGIN
            RAISERROR 99999 'FNM Pools with INVALID VALUE for llpa PoolCount : %1!', @cnt
            RETURN
        END

----------------------------------------------------------------------------------------------
-- Check to see if Pools have pmi IS NULL OR pmi < 0.0 OR pmi > 500
----------------------------------------------------------------------------------------------
        SELECT
            @cnt =  count(1)
        FROM #FNM_PoolIncentive WHERE pmi IS NULL OR pmi < 0.0 OR pmi > 500

        if (@cnt > 0)
        BEGIN
            RAISERROR 99999 'FNM Pools with INVALID VALUE for pmi PoolCount : %1!', @cnt
            RETURN
        END

----------------------------------------------------------------------------------------------
-- Check to see if Pools have mip IS NULL OR mip < 0.0 OR mip > 300
----------------------------------------------------------------------------------------------
        SELECT
            @cnt =  count(1)
        FROM #FNM_PoolIncentive WHERE mip IS NULL OR mip < 0.0 OR mip > 300

        if (@cnt > 0)
        BEGIN
            RAISERROR 99999 'FNM Pools with INVALID VALUE for mip PoolCount : %1!', @cnt
            RETURN
        END
        
-- End Tests



-- Load Data into Scale Incentive Table
DELETE FROM scale.FNM_PoolIncentive
FROM scale.FNM_PoolIncentive spi, #FNM_PoolIncentive pi
WHERE 1=1
    AND spi.issueId = pi.issueId
    AND spi.asOf = pi.asOf
    AND pi.marketTicker IN (SELECT tickerName FROM #ticker)
    AND spi.asOf >= (SELECT asOf from #tmp_asOf)
    AND version = (SELECT version from #tmp_version)
;

DECLARE @version varchar(5)
SELECT @version = (select * from #tmp_version)

INSERT INTO scale.FNM_PoolIncentive (issueId, asOf, version, conventional_refi_incentive, fha_refi_incentive, refi_incentive, refi_incentive_eligible, origPMI, currLLPA, currPMI, currMIP)
SELECT
    issueId,
    asOf,
    @version,
    conventional_refi_incentive,
    fha_refi_incentive,
    refi_incentive,
    refi_incentive_eligible,
    pmi_begin,
    llpa,
    pmi,
    mip
FROM #FNM_PoolIncentive
WHERE marketTicker IN (SELECT tickerName FROM #ticker)
    AND asOf >= (SELECT asOf from #tmp_asOf)
;