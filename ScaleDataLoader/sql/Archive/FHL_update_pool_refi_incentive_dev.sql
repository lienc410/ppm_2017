-- Freddie Conventional
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
SELECT CAST ('2.50' AS varchar(5)) version INTO #tmp_version
;

-- Before execute the script, need to set the tickers
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

CREATE LF INDEX loan_tickerName_idx ON #ticker(tickerName);
COMMIT;


-- Creates the 30 YR FRM Rate (point adjusted)
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
	AND ModelType = 'ScaleMtgRateModel v1.0'
;
COMMIT;

CREATE LF INDEX series_idx ON #Mtg30YrRates_monthly(SeriesName);
CREATE LF INDEX asOf_idx ON #Mtg30YrRates_monthly(asOf);
CREATE LF INDEX asOf_lag1_idx ON #Mtg30YrRates_monthly(asOf_lag1);
CREATE LF INDEX asOf_lag2_idx ON #Mtg30YrRates_monthly(asOf_lag2);

COMMIT;


-- Create Pool Historical Data
DROP TABLE IF EXISTS #FHL_PoolIncentive;
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
    x.originalTerm as origTerm,
    pd.percentOCC_OWN as Pct_OWNER,
    pd.percentOCC_2ND as Pct_2ND,
    pd.percentOCC_INV as Pct_INV,
    pe.HARP_eligible,
    pe.refi_eligible,
    mr.MtgRate,
    mr_gn.MtgRate as MtgRate_GNMA,
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
    
INTO #FHL_PoolIncentive
FROM scale.FHL_PoolHist ph
JOIN #ticker tk
    ON ph.marketTicker = tk.tickerName
JOIN fhl.sec p
    ON ph.issueId = p.issueId
JOIN fhl.Prefix x
    ON p.prefix = x.prefix
    AND p.product = x.product
JOIN scale.FHL_PoolDistribution pd
    ON ph.issueId = pd.issueId
    AND ph.asOf = pd.asOf
JOIN scale.FHL_PoolEligibility pe
    ON ph.issueId = pe.issueId
    AND ph.asOf = pe.asOf
JOIN #Mtg30YrRates_monthly mr
    ON mr.asOf_lag1 = ph.asOf
    AND mr.SeriesName = tk.mtgRateSeries
JOIN #Mtg30YrRates_monthly mr_gn
    ON mr_gn.asOf_lag1 = mr.asOf_lag1
    AND mr_gn.SeriesName = 'GINNIE_30YR'
WHERE 1=1
    AND ph.asOf >= (select asOf from #tmp_asOf)
--    AND ph.issueId =1482236
;
COMMIT;

CREATE HG INDEX issueId_idx ON #FHL_PoolIncentive(issueId);
CREATE LF INDEX asOf_idx ON #FHL_PoolIncentive(asOf);
CREATE LF INDEX ticker_idx ON #FHL_PoolIncentive(marketTicker);
COMMIT;


------------------------------------------------------------
-- Step 1: Compute all metrics using Loan Data
------------------------------------------------------------
DROP TABLE IF EXISTS #FHL_LoanBasedIncentive;
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
INTO #FHL_LoanBasedIncentive
FROM #FHL_PoolIncentive pi
JOIN fhl.PIV_Loan cl
    ON pi.issueId = cl.issueId
JOIN scale.FHL_Loan_Dev sl
    ON cl.loanSeqNum = sl.loanSeqNum
JOIN scale.fhl_LoanHist slh
    ON cl.loanSeqNum = slh.loanSeqNum
    AND pi.asOf = slh.asOf
JOIN scale.FHL_LoanIncentive sli
    ON slh.loanSeqNum = sli.loanSeqNum
    AND slh.asOf = sli.asOf
WHERE 1=1
    AND sli.conventional_refi_incentive IS NOT NULL
    AND sli.version = (SELECT version from #tmp_version)
    AND sl.version = (SELECT version from #tmp_version)
GROUP BY pi.issueId, pi.asOf
;
COMMIT;

UPDATE #FHL_PoolIncentive pi SET
    pi.has_loan_data = 1,
    pi.pmi_begin = lbi.pmi_begin, 
    pi.pmi = lbi.pmi, 
    pi.llpa = lbi.llpa,
    pi.mip = lbi.mip,
    pi.conventional_refi_incentive = lbi.conventional_refi_incentive,
    pi.fha_refi_incentive = lbi.fha_refi_incentive,
    pi.refi_incentive = lbi.refi_incentive,
    pi.refi_incentive_eligible = lbi.refi_incentive_eligible
FROM #FHL_LoanBasedIncentive lbi
WHERE pi.issueId = lbi.issueId
    AND pi.asOf = lbi.asOf
;
COMMIT;

DROP TABLE IF EXISTS #FHL_MIN_Incentive;
SELECT
    issueId,
    min(asOf) as min_asOf,
    cast(NULL as date) as first_record,
    cast(NULL as numeric(8, 4)) as earliest_MtgRate,
    cast(NULL as numeric(8, 4)) as earliest_MtgRate_GNMA,
    cast(NULL as numeric(8, 4)) as earliest_pmi_begin,
    cast(NULL as numeric(8, 4)) as earliest_pmi,
    cast(NULL as numeric(8, 4)) as earliest_llpa,
    cast(NULL as numeric(8, 4)) as earliest_mip, 
    cast(NULL as numeric(10, 4)) as earliest_conventional_refi_incentive,
    cast(NULL as numeric(10, 4)) as earliest_fha_refi_incentive,
    cast(NULL as numeric(10, 4)) as earliest_refi_incentive,
    cast(NULL as numeric(10, 4)) as earliest_refi_incentive_eligible
INTO #FHL_MIN_Incentive
FROM #FHL_PoolIncentive
WHERE 1=1
    AND refi_incentive IS NOT NULL
    AND issueId in (SELECT distinct issueId from #FHL_LoanBasedIncentive)
GROUP BY issueId
;
COMMIT;

UPDATE #FHL_MIN_Incentive mi SET 
    mi.earliest_MtgRate = pi.MtgRate,
    mi.earliest_MtgRate_GNMA = pi.MtgRate_GNMA,
    mi.earliest_pmi_begin = pi.pmi_begin,
    mi.earliest_pmi = pi.pmi,
    mi.earliest_llpa = pi.llpa,
    mi.earliest_mip = pi.mip,
    mi.earliest_conventional_refi_incentive = pi.conventional_refi_incentive,
    mi.earliest_fha_refi_incentive = pi.fha_refi_incentive,
    mi.earliest_refi_incentive = pi.refi_incentive,
    mi.earliest_refi_incentive_eligible = pi.refi_incentive_eligible
FROM #FHL_PoolIncentive pi
WHERE mi.issueId = pi.issueId
    AND mi.min_asOf = pi.asOf
;

DROP TABLE IF EXISTS #FHL_First_Record;
SELECT
    issueId,
    min(asOf) as min_asOf
INTO #FHL_First_Record
FROM #FHL_PoolIncentive
WHERE 1=1
    AND issueId in (SELECT distinct issueId from #FHL_LoanBasedIncentive)
GROUP BY issueId
;
COMMIT;

UPDATE #FHL_MIN_Incentive mi SET 
    mi.first_record = fr.min_asOf
FROM #FHL_First_Record fr
WHERE fr.issueId = mi.issueId
;
COMMIT;

UPDATE #FHL_PoolIncentive pi SET 
    pi.pmi_begin = mi.earliest_pmi_begin,
    pi.pmi = mi.earliest_pmi, 
    pi.llpa = mi.earliest_llpa,
    pi.mip = mi.earliest_mip,
    pi.conventional_refi_incentive = (mi.earliest_MtgRate - pi.MtgRate) * 100 + mi.earliest_conventional_refi_incentive,
    pi.fha_refi_incentive = (mi.earliest_MtgRate_GNMA - pi.MtgRate) * 100 + mi.earliest_fha_refi_incentive,
    pi.refi_incentive = CASE WHEN (mi.earliest_MtgRate - pi.MtgRate) * 100 + mi.earliest_conventional_refi_incentive >= (mi.earliest_MtgRate_GNMA - pi.MtgRate) * 100 + mi.earliest_fha_refi_incentive 
                                THEN (mi.earliest_MtgRate - pi.MtgRate) * 100 + mi.earliest_conventional_refi_incentive 
                                ELSE (mi.earliest_MtgRate_GNMA - pi.MtgRate) * 100 + mi.earliest_fha_refi_incentive END,
    pi.refi_incentive_eligible = (mi.earliest_MtgRate - pi.MtgRate) * 100 + mi.earliest_refi_incentive_eligible
FROM #FHL_MIN_Incentive mi
WHERE pi.issueId = mi.issueId
    AND pi.refi_incentive IS NULL
    AND DATEDIFF(month, mi.first_record, mi.min_asOf) <= 3
;

------------------------------------------------------------
-- Step 2: Compute all metrics using Pool Data
------------------------------------------------------------
DROP TABLE IF EXISTS #FHL_PoolBasedIncentive;
SELECT * 
INTO #FHL_PoolBasedIncentive
FROM #FHL_PoolIncentive
WHERE 1=1
--    AND issueId NOT IN (SELECT distinct issueId from #FHL_LoanBasedIncentive) -- remove to fix the case that only LL snapshot is available
    AND refi_incentive IS NULL
;
COMMIT;

-- Update pmi_begin_base
UPDATE #FHL_PoolBasedIncentive inc 
SET inc.pmi_begin_base = (PMI_LL_FL * (LTV_H - inc.waoltv) * (FICO_H - inc.waocs) + PMI_LH_FL * (inc.waoltv - LTV_L) * (FICO_H - inc.waocs) 
      + PMI_LL_FH * (LTV_H - inc.waoltv) * (inc.waocs - FICO_L) + PMI_LH_FH * (inc.waoltv - LTV_L) * (inc.waocs - FICO_L)
      ) / ((LTV_H - LTV_L) * (FICO_H - FICO_L)) 
FROM report.PIV_PMI_Base_Bilinear_Interpolation pmi
WHERE 1=1
    AND LoanPurpose = 'REFI'
    AND inc.originationDate >= pmi.startDate and inc.originationDate < pmi.endDate 
    AND inc.waoltv > pmi.LTV_L AND inc.waoltv <= pmi.LTV_H 
    AND inc.waocs > pmi.FICO_L AND inc.waocs <= pmi.FICO_H
;
UPDATE #FHL_PoolBasedIncentive inc SET inc.pmi_begin_base = 0 WHERE inc.pmi_begin_base IS NULL;

-- Update pmi_begin_occ
UPDATE #FHL_PoolBasedIncentive inc 
SET inc.pmi_begin_occ = ((pmi_owner.PMI_LL_FL * (pmi_owner.LTV_H - inc.waoltv) * (pmi_owner.FICO_H - inc.waocs) + pmi_owner.PMI_LH_FL * (inc.waoltv - pmi_owner.LTV_L) * (pmi_owner.FICO_H - inc.waocs) 
                              + pmi_owner.PMI_LL_FH * (pmi_owner.LTV_H - inc.waoltv) * (inc.waocs - pmi_owner.FICO_L) + pmi_owner.PMI_LH_FH * (inc.waoltv - pmi_owner.LTV_L) * (inc.waocs - pmi_owner.FICO_L)
                              ) / ((pmi_owner.LTV_H - pmi_owner.LTV_L) * (pmi_owner.FICO_H - pmi_owner.FICO_L)) * inc.Pct_OWNER 
                        + (pmi_2nd.PMI_LL_FL * (pmi_2nd.LTV_H - inc.waoltv) * (pmi_2nd.FICO_H - inc.waocs) + pmi_2nd.PMI_LH_FL * (inc.waoltv - pmi_2nd.LTV_L) * (pmi_2nd.FICO_H - inc.waocs) 
                              + pmi_2nd.PMI_LL_FH * (pmi_2nd.LTV_H - inc.waoltv) * (inc.waocs - pmi_2nd.FICO_L) + pmi_2nd.PMI_LH_FH * (inc.waoltv - pmi_2nd.LTV_L) * (inc.waocs - pmi_2nd.FICO_L)
                              ) / ((pmi_2nd.LTV_H - pmi_2nd.LTV_L) * (pmi_2nd.FICO_H - pmi_2nd.FICO_L)) * inc.Pct_2ND 
                        + (pmi_inv.PMI_LL_FL * (pmi_inv.LTV_H - inc.waoltv) * (pmi_inv.FICO_H - inc.waocs) + pmi_inv.PMI_LH_FL * (inc.waoltv - pmi_inv.LTV_L) * (pmi_inv.FICO_H - inc.waocs) 
                          + pmi_inv.PMI_LL_FH * (pmi_inv.LTV_H - inc.waoltv) * (inc.waocs - pmi_inv.FICO_L) + pmi_inv.PMI_LH_FH * (inc.waoltv - pmi_inv.LTV_L) * (inc.waocs - pmi_inv.FICO_L)
                          ) / ((pmi_inv.LTV_H - pmi_inv.LTV_L) * (pmi_inv.FICO_H - pmi_inv.FICO_L)) * inc.Pct_INV) / 100.0
FROM report.PIV_PMI_Occupancy_Bilinear_Interpolation pmi_owner, report.PIV_PMI_Occupancy_Bilinear_Interpolation pmi_2nd, report.PIV_PMI_Occupancy_Bilinear_Interpolation pmi_inv
WHERE 1=1
    AND pmi_owner.OccType = 'OWNER'
    AND inc.originationDate >= pmi_owner.startDate and inc.originationDate < pmi_owner.endDate 
    AND inc.waoltv > pmi_owner.LTV_L AND inc.waoltv <= pmi_owner.LTV_H 
    AND inc.waocs > pmi_owner.FICO_L AND inc.waocs <= pmi_owner.FICO_H
   
    AND pmi_2nd.OccType = '2ND'
    AND inc.originationDate >= pmi_2nd.startDate and inc.originationDate < pmi_2nd.endDate 
    AND inc.waoltv > pmi_2nd.LTV_L AND inc.waoltv <= pmi_2nd.LTV_H 
    AND inc.waocs > pmi_2nd.FICO_L AND inc.waocs <= pmi_2nd.FICO_H
    
    AND pmi_inv.OccType = 'INV'
    AND inc.originationDate >= pmi_inv.startDate and inc.originationDate < pmi_inv.endDate 
    AND inc.waoltv > pmi_inv.LTV_L AND inc.waoltv <= pmi_inv.LTV_H 
    AND inc.waocs > pmi_inv.FICO_L AND inc.waocs <= pmi_inv.FICO_H
;
UPDATE #FHL_PoolBasedIncentive inc SET inc.pmi_begin_occ = 0 WHERE inc.pmi_begin_occ IS NULL;

-- Update pmi_begin_loansize
UPDATE #FHL_PoolBasedIncentive inc 
SET inc.pmi_begin_loansize = (PMI_LL_FL * (LTV_H - inc.waoltv) * (FICO_H - inc.waocs) + PMI_LH_FL * (inc.waoltv - LTV_L) * (FICO_H - inc.waocs) 
      + PMI_LL_FH * (LTV_H - inc.waoltv) * (inc.waocs - FICO_L) + PMI_LH_FH * (inc.waoltv - LTV_L) * (inc.waocs - FICO_L)
      ) / ((LTV_H - LTV_L) * (FICO_H - FICO_L))
FROM report.PIV_PMI_LoanSize_Bilinear_Interpolation pmi
WHERE 1=1
    AND inc.originationDate >= pmi.startDate and inc.originationDate < pmi.endDate 
    AND inc.waocs >= pmi.FICO_L and inc.waocs < pmi.FICO_H
    AND inc.waoltv > pmi.LTV_L and inc.waoltv <= pmi.LTV_H
    AND inc.waolSize > pmi.LoanSize_L and inc.waolSize <= LoanSize_H
;

UPDATE #FHL_PoolBasedIncentive inc 
SET inc.pmi_begin_loansize = (inc.waolSize - LoanSize_L) / (LoanSize_H - LoanSize_L) * (inc.pmi_begin_loansize - 0.0)
FROM report.PIV_PMI_LoanSize_Bilinear_Interpolation pmi
WHERE 1=1
    AND inc.waolSize > pmi.LoanSize_L and inc.waolSize <= LoanSize_H
    AND inc.originationDate >= pmi.startDate and inc.originationDate < pmi.endDate 
    AND inc.waoltv > pmi.LTV_L and inc.waoltv <= pmi.LTV_H
    AND inc.waolSize > pmi.LoanSize_L and inc.waolSize <= LoanSize_H
    AND needExtraInterp = 1
;
UPDATE #FHL_PoolBasedIncentive inc SET inc.pmi_begin_loansize = 0 WHERE inc.pmi_begin_loansize IS NULL;


-- Update pmi_end_base
UPDATE #FHL_PoolBasedIncentive inc 
SET inc.pmi_end_base = (PMI_LL_FL * (LTV_H - waCLTV) * (FICO_H - waocs) + PMI_LH_FL * (waCLTV - LTV_L) * (FICO_H - waocs) 
      + PMI_LL_FH * (LTV_H - waCLTV) * (waocs - FICO_L) + PMI_LH_FH * (waCLTV - LTV_L) * (waocs - FICO_L)
      ) / ((LTV_H - LTV_L) * (FICO_H - FICO_L)) 
FROM report.PIV_PMI_Base_Bilinear_Interpolation pmi
WHERE 1=1
    AND LoanPurpose = 'REFI'
    AND inc.asOf >= pmi.startDate and inc.asOf < pmi.endDate 
    AND waCLTV > pmi.LTV_L AND waCLTV <= pmi.LTV_H 
    AND waocs > pmi.FICO_L AND waocs <= pmi.FICO_H
;
UPDATE #FHL_PoolBasedIncentive inc SET inc.pmi_end_base = 0 WHERE inc.pmi_end_base IS NULL;

-- Update pmi_end_occ
UPDATE #FHL_PoolBasedIncentive inc 
SET inc.pmi_end_occ = ((pmi_owner.PMI_LL_FL * (pmi_owner.LTV_H - inc.waCLTV) * (pmi_owner.FICO_H - inc.waocs) + pmi_owner.PMI_LH_FL * (inc.waCLTV - pmi_owner.LTV_L) * (pmi_owner.FICO_H - inc.waocs) 
                              + pmi_owner.PMI_LL_FH * (pmi_owner.LTV_H - inc.waCLTV) * (inc.waocs - pmi_owner.FICO_L) + pmi_owner.PMI_LH_FH * (inc.waCLTV - pmi_owner.LTV_L) * (inc.waocs - pmi_owner.FICO_L)
                              ) / ((pmi_owner.LTV_H - pmi_owner.LTV_L) * (pmi_owner.FICO_H - pmi_owner.FICO_L)) * inc.Pct_OWNER 
                        + (pmi_2nd.PMI_LL_FL * (pmi_2nd.LTV_H - inc.waCLTV) * (pmi_2nd.FICO_H - inc.waocs) + pmi_2nd.PMI_LH_FL * (inc.waCLTV - pmi_2nd.LTV_L) * (pmi_2nd.FICO_H - inc.waocs) 
                              + pmi_2nd.PMI_LL_FH * (pmi_2nd.LTV_H - inc.waCLTV) * (inc.waocs - pmi_2nd.FICO_L) + pmi_2nd.PMI_LH_FH * (inc.waCLTV - pmi_2nd.LTV_L) * (inc.waocs - pmi_2nd.FICO_L)
                              ) / ((pmi_2nd.LTV_H - pmi_2nd.LTV_L) * (pmi_2nd.FICO_H - pmi_2nd.FICO_L)) * inc.Pct_2ND 
                        + (pmi_inv.PMI_LL_FL * (pmi_inv.LTV_H - inc.waCLTV) * (pmi_inv.FICO_H - inc.waocs) + pmi_inv.PMI_LH_FL * (inc.waCLTV - pmi_inv.LTV_L) * (pmi_inv.FICO_H - inc.waocs) 
                          + pmi_inv.PMI_LL_FH * (pmi_inv.LTV_H - inc.waCLTV) * (inc.waocs - pmi_inv.FICO_L) + pmi_inv.PMI_LH_FH * (inc.waCLTV - pmi_inv.LTV_L) * (inc.waocs - pmi_inv.FICO_L)
                          ) / ((pmi_inv.LTV_H - pmi_inv.LTV_L) * (pmi_inv.FICO_H - pmi_inv.FICO_L)) * inc.Pct_INV) / 100.0
FROM report.PIV_PMI_Occupancy_Bilinear_Interpolation pmi_owner, report.PIV_PMI_Occupancy_Bilinear_Interpolation pmi_2nd, report.PIV_PMI_Occupancy_Bilinear_Interpolation pmi_inv
WHERE 1=1
    AND pmi_owner.OccType = 'OWNER'
    AND inc.asOf >= pmi_owner.startDate and inc.asOf < pmi_owner.endDate 
    AND inc.waCLTV > pmi_owner.LTV_L AND inc.waCLTV <= pmi_owner.LTV_H 
    AND inc.waocs > pmi_owner.FICO_L AND inc.waocs <= pmi_owner.FICO_H
   
    AND pmi_2nd.OccType = '2ND'
    AND inc.asOf >= pmi_2nd.startDate and inc.asOf < pmi_2nd.endDate 
    AND inc.waCLTV > pmi_2nd.LTV_L AND inc.waCLTV <= pmi_2nd.LTV_H 
    AND inc.waocs > pmi_2nd.FICO_L AND inc.waocs <= pmi_2nd.FICO_H
    
    AND pmi_inv.OccType = 'INV'
    AND inc.asOf >= pmi_inv.startDate and inc.asOf < pmi_inv.endDate 
    AND inc.waCLTV > pmi_inv.LTV_L AND inc.waCLTV <= pmi_inv.LTV_H 
    AND inc.waocs > pmi_inv.FICO_L AND inc.waocs <= pmi_inv.FICO_H
;

UPDATE #FHL_PoolBasedIncentive inc SET inc.pmi_end_occ = 0 WHERE inc.pmi_end_occ IS NULL;


-- Update pmi_end_loansize
UPDATE #FHL_PoolBasedIncentive inc 
SET inc.pmi_end_loansize = (PMI_LL_FL * (LTV_H - inc.waCLTV) * (FICO_H - inc.waocs) + PMI_LH_FL * (inc.waCLTV - LTV_L) * (FICO_H - inc.waocs) 
                          + PMI_LL_FH * (LTV_H - inc.waCLTV) * (inc.waocs - FICO_L) + PMI_LH_FH * (inc.waCLTV - LTV_L) * (inc.waocs - FICO_L)
                          ) / ((LTV_H - LTV_L) * (FICO_H - FICO_L))
FROM report.PIV_PMI_LoanSize_Bilinear_Interpolation pmi
WHERE 1=1
    AND inc.asOf >= pmi.startDate and inc.asOf < pmi.endDate 
    AND inc.waocs >= pmi.FICO_L and inc.waocs < pmi.FICO_H
    AND inc.waCLTV > pmi.LTV_L and inc.waCLTV <= pmi.LTV_H
    AND inc.waclSize > pmi.LoanSize_L and inc.waclSize <= LoanSize_H
;

UPDATE #FHL_PoolBasedIncentive inc 
SET inc.pmi_end_loansize = (inc.waclSize - LoanSize_L) / (LoanSize_H - LoanSize_L) * (inc.pmi_end_loansize - 0.0)
FROM report.PIV_PMI_LoanSize_Bilinear_Interpolation pmi
WHERE 1=1
    AND inc.waclSize > pmi.LoanSize_L and inc.waclSize <= LoanSize_H
    AND inc.asOf >= pmi.startDate and inc.asOf < pmi.endDate 
    AND inc.waCLTV > pmi.LTV_L and inc.waCLTV <= pmi.LTV_H
    AND inc.waclSize > pmi.LoanSize_L and inc.waclSize <= LoanSize_H
    AND needExtraInterp = 1
;

UPDATE #FHL_PoolBasedIncentive inc SET inc.pmi_end_loansize = 0 WHERE inc.pmi_end_loansize IS NULL;


-- Update Base LLPA
UPDATE #FHL_PoolBasedIncentive inc 
SET inc.llpa_base = (LLPA_LL_FL * (LTV_H - waCLTV) * (FICO_H - waocs) + LLPA_LH_FL * (waCLTV - LTV_L) * (FICO_H - waocs) 
                  + LLPA_LL_FH * (LTV_H - waCLTV) * (waocs - FICO_L) + LLPA_LH_FH * (waCLTV - LTV_L) * (waocs - FICO_L)
                  ) / ((LTV_H - LTV_L) * (FICO_H - FICO_L)) 
FROM report.PIV_LLPA_Base_Bilinear_Interpolation llpa
WHERE 1=1
    AND waCLTV > llpa.LTV_L 
    AND waCLTV <= llpa.LTV_H 
    AND waocs > llpa.FICO_L 
    AND waocs <= llpa.FICO_H
    AND inc.asOf >= llpa.startDate and inc.asOf < llpa.endDate 
;
UPDATE #FHL_PoolBasedIncentive inc SET inc.llpa_base = 0 WHERE inc.llpa_base IS NULL;

-- Update ADMC LLPA
UPDATE #FHL_PoolBasedIncentive inc SET inc.llpa_admc = llpa.LLPA
FROM report.PIV_LLPA_ADMC llpa
WHERE 1=1
    AND inc.asOf >= llpa.startDate and inc.asOf < llpa.endDate 
;

UPDATE #FHL_PoolBasedIncentive inc SET inc.llpa_admc = 0 WHERE inc.llpa_admc IS NULL;

-- Update Occupancy LLPA
UPDATE #FHL_PoolBasedIncentive inc 
SET inc.llpa_occ = (((waCLTV - llpa_owner.LTV_L) / (llpa_owner.LTV_H - llpa_owner.LTV_L) * (llpa_owner.LLPA_LH - llpa_owner.LLPA_LL) + llpa_owner.LLPA_LL) * inc.Pct_OWNER 
                    + ((waCLTV - llpa_2nd.LTV_L) / (llpa_2nd.LTV_H - llpa_2nd.LTV_L) * (llpa_2nd.LLPA_LH - llpa_2nd.LLPA_LL) + llpa_2nd.LLPA_LL) * inc.Pct_2ND 
                    + ((waCLTV - llpa_inv.LTV_L) / (llpa_inv.LTV_H - llpa_inv.LTV_L) * (llpa_inv.LLPA_LH - llpa_inv.LLPA_LL) + llpa_inv.LLPA_LL) * inc.Pct_INV) / 100.0
FROM report.PIV_LLPA_Occupancy_Linear_Interpolation llpa_owner, report.PIV_LLPA_Occupancy_Linear_Interpolation llpa_2nd, report.PIV_LLPA_Occupancy_Linear_Interpolation llpa_inv
WHERE 1=1
    AND llpa_owner.OccType = 'OWNER'
    AND inc.asOf >= llpa_owner.startDate and inc.asOf < llpa_owner.endDate 
    AND inc.waCLTV > llpa_owner.LTV_L and inc.waCLTV <= llpa_owner.LTV_H
    
    AND llpa_2nd.OccType = '2ND'
    AND inc.asOf >= llpa_2nd.startDate and inc.asOf < llpa_2nd.endDate 
    AND inc.waCLTV > llpa_2nd.LTV_L and inc.waCLTV <= llpa_2nd.LTV_H
    
    AND llpa_inv.OccType = 'INV'
    AND inc.asOf >= llpa_inv.startDate and inc.asOf < llpa_inv.endDate 
    AND inc.waCLTV > llpa_inv.LTV_L and inc.waCLTV <= llpa_inv.LTV_H
;

UPDATE #FHL_PoolBasedIncentive inc SET inc.llpa_occ = 0 WHERE inc.llpa_occ IS NULL;

-- Update LTV LLPA
UPDATE #FHL_PoolBasedIncentive inc SET inc.llpa_ltv = llpa.LLPA
FROM report.PIV_LLPA_LTV llpa
WHERE 1=1
    AND inc.asOf >= llpa.startDate and inc.asOf < llpa.endDate 
    AND inc.waCLTV > llpa.LTVBucketStart and inc.waCLTV <= llpa.LTVBucketEnd
;

UPDATE #FHL_PoolBasedIncentive inc SET inc.llpa_ltv = 0 WHERE inc.llpa_ltv IS NULL;

-- Update Loan Size
UPDATE #FHL_PoolBasedIncentive inc 
SET inc.llpa_loansize = (inc.waclSize - LoanSize_L) / (LoanSize_H - LoanSize_L) * (LLPA_LH - LLPA_LL) + LLPA_LL
FROM report.PIV_LLPA_LoanSize_Interpolation llpa
WHERE 1=1
    AND inc.asOf >= llpa.startDate and inc.asOf < llpa.endDate 
    AND inc.waclSize > llpa.LoanSize_L and inc.waclSize <= llpa.LoanSize_H
    AND inc.waCLTV > llpa.LTVBucketStart and inc.waCLTV <= llpa.LTVBucketEnd
;

UPDATE #FHL_PoolBasedIncentive inc SET inc.llpa_loansize = 0 WHERE inc.llpa_loansize IS NULL;

-- Update PMI and LLPA Incentive
UPDATE #FHL_PoolBasedIncentive inc SET
    pmi_begin = (pmi_begin_base + pmi_begin_loansize + pmi_begin_occ)
WHERE pmi_begin IS NULL
;

UPDATE #FHL_PoolBasedIncentive inc SET
    pmi = ((100.0 - HARP_eligible) / 100.0) * (pmi_end_base + pmi_end_loansize + pmi_end_occ)
WHERE pmi IS NULL
;

UPDATE #FHL_PoolBasedIncentive inc SET
    llpa = ((HARP_eligible * (CASE WHEN llpa_base + llpa_admc + llpa_occ + llpa_ltv + llpa_loansize > 75.0 THEN 75.0 ELSE llpa_base + llpa_admc + llpa_occ + llpa_ltv + llpa_loansize END)) 
        + (100.0 - HARP_eligible) * (llpa_base + llpa_admc + llpa_occ + llpa_ltv + llpa_loansize)) / 100.0
WHERE llpa IS NULL
;

-- Update MIP
--UPDATE #FHL_PoolBasedIncentive inc SET inc.mip = CASE WHEN inc.waCLTV <= 78.0 THEN 0.0 ELSE 55.0 + 1.0 / 12.0 END
--WHERE inc.asOf > '2012-06-01'
--    AND inc.originationDate <= '2009-05-01'
--;
UPDATE #FHL_PoolBasedIncentive inc 
SET inc.mip = (AnnualMIPPoints_LL_SL * (LTV_H - waCLTV) * (LoanSize_H - waclSize) + AnnualMIPPoints_LH_SL * (waCLTV - LTV_L) * (LoanSize_H - waclSize) 
                + AnnualMIPPoints_LL_SH * (LTV_H - waCLTV) * (waclSize - LoanSize_L) + AnnualMIPPoints_LH_SH * (waCLTV - LTV_L) * (waclSize - LoanSize_L)
                ) / ((LTV_H - LTV_L) * (LoanSize_H - LoanSize_L)) 
            + mip_base.UpfrontMIPPoints / 12.0
FROM report.PIV_MIP_Base_Bilinear_Interpolation mip_base
WHERE 1=1
    AND inc.origTerm           >   	mip_base.TermBucketStart
	AND inc.origTerm           <=	mip_base.TermBucketEnd
	AND inc.waCLTV             >   	mip_base.LTV_L
	AND inc.waCLTV             <= 	mip_base.LTV_H
	AND inc.waclSize           >=   mip_base.LoanSize_L
	AND inc.waclSize           <= 	mip_base.LoanSize_H
    AND inc.originationDate    >   	mip_base.OriginationStartDate
	AND inc.originationDate    <= 	mip_base.OriginationEndDate
	AND inc.asOf               >   	mip_base.StartDate
	AND inc.asOf               <= 	mip_base.EndDate
    AND inc.mip IS NULL
;
COMMIT;

-- Update Refinance Incentive
UPDATE #FHL_PoolBasedIncentive inc SET
    conventional_refi_incentive = 100.0 * (wac + (pmi_begin / 100.0) - MtgRate - (llpa / 400.0) - (pmi / 100.0)),
    fha_refi_incentive = 100.0 * (wac + (pmi_begin / 100.0) - MtgRate_GNMA - (mip / 100.0))
WHERE inc.refi_incentive IS NULL
;

UPDATE #FHL_PoolBasedIncentive inc SET
    refi_incentive = CASE WHEN conventional_refi_incentive >= fha_refi_incentive THEN conventional_refi_incentive ELSE fha_refi_incentive END
WHERE inc.refi_incentive IS NULL
;

-- Update Refinance Incentive Eligible
DROP TABLE IF EXISTS #FHL_IncentiveBias;
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
INTO #FHL_IncentiveBias
FROM #FHL_LoanBasedIncentive
WHERE 1=1
    AND refi_incentive_eligible IS NOT NULL
    AND refi_incentive IS NOT NULL
GROUP BY refi_bucket
ORDER BY refi_bucket
;

DROP TABLE IF EXISTS #FHL_Buckets;
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
INTO #FHL_Buckets
FROM #FHL_PoolBasedIncentive
;

UPDATE #FHL_PoolBasedIncentive inc SET
    inc.refi_incentive_eligible = inc.refi_incentive + ib.avg_diff
FROM #FHL_IncentiveBias ib, #FHL_Buckets bu
WHERE 1=1
    AND inc.issueId = bu.issueId
    AND inc.asOf = bu.asOf
    AND ib.refi_bucket = bu.refi_bucket
;
COMMIT;

-- Update FHL_PoolIncentive
UPDATE #FHL_PoolIncentive pi SET
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
FROM #FHL_PoolBasedIncentive pbi
WHERE pi.issueId = pbi.issueId
    AND pi.asOf = pbi.asOf
;
COMMIT;
--select version, count(1) from scale.FHL_LoanIncentive group by version
-- Tests

-- Time Series Tests
-- History for: conventional_refi_incentive, fha_refi_incentive, refi_incentive, refi_incentive_eligible, origPMI, currLLPA, currPMI, currMIP
--SELECT marketTicker, asOf, count(1), sum(balance), sum(balance * conventional_refi_incentive) / sum(CASE WHEN conventional_refi_incentive IS NULL THEN 0.0 ELSE balance END) as wavg_conventional_refi_incentive FROM #FHL_PoolIncentive GROUP BY marketTicker, asOf ORDER BY asOf;

--SELECT marketTicker, asOf, count(1), sum(balance), sum(balance * fha_refi_incentive) / sum(CASE WHEN fha_refi_incentive IS NULL THEN 0.0 ELSE balance END) as wavg_fha_refi_incentive FROM #FHL_PoolIncentive GROUP BY marketTicker, asOf ORDER BY asOf;

--SELECT marketTicker, asOf, count(1), sum(balance), sum(balance * refi_incentive) / sum(CASE WHEN refi_incentive IS NULL THEN 0.0 ELSE balance END) as wavg_refi_incentive FROM #FHL_PoolIncentive GROUP BY marketTicker, asOf ORDER BY asOf;

--SELECT marketTicker, asOf, count(1), sum(balance), sum(balance * refi_incentive_eligible) / sum(CASE WHEN refi_incentive_eligible IS NULL THEN 0.0 ELSE balance END) as wavg_refi_incentive_eligible FROM #FHL_PoolIncentive GROUP BY marketTicker, asOf ORDER BY asOf;

--SELECT marketTicker, asOf, count(1), sum(balance), sum(balance * pmi_begin) / sum(CASE WHEN pmi_begin IS NULL THEN 0.0 ELSE balance END) as wavg_orig_pmi FROM #FHL_PoolIncentive GROUP BY marketTicker, asOf ORDER BY asOf;

--SELECT marketTicker, asOf, count(1), sum(balance), sum(balance * llpa) / sum(CASE WHEN llpa IS NULL THEN 0.0 ELSE balance END) as wavg_llpa FROM #FHL_PoolIncentive GROUP BY marketTicker, asOf ORDER BY asOf;

--SELECT marketTicker, asOf, count(1), sum(balance), sum(balance * pmi) / sum(CASE WHEN pmi IS NULL THEN 0.0 ELSE balance END) as wavg_pmi FROM #FHL_PoolIncentive GROUP BY marketTicker, asOf ORDER BY asOf;

--SELECT marketTicker, asOf, count(1), sum(balance), sum(balance * mip) / sum(CASE WHEN mip IS NULL THEN 0.0 ELSE balance END) as wavg_mip FROM #FHL_PoolIncentive GROUP BY marketTicker, asOf ORDER BY asOf;

----------------------------------------------------------------------------------------------
-- Check to see if Pools have conventional_refi_incentive IS NULL OR conventional_refi_incentive < -1000.0 OR conventional_refi_incentive > 2000.0
----------------------------------------------------------------------------------------------
        declare   @cnt int
        SELECT
            @cnt =  count(1)
        FROM #FHL_PoolIncentive WHERE conventional_refi_incentive IS NULL OR conventional_refi_incentive < -1000.0 OR conventional_refi_incentive > 2000.0

        if (@cnt > 0)
        BEGIN
            RAISERROR 99999 'FHL Pools with INVALID VALUE for conventional_refi_incentive PoolCount : %1!', @cnt
            RETURN
        END

----------------------------------------------------------------------------------------------
-- Check to see if Pools have fha_refi_incentive IS NULL OR fha_refi_incentive < -1000.0 OR fha_refi_incentive > 2000.0
----------------------------------------------------------------------------------------------
        SELECT
            @cnt =  count(1)
        FROM #FHL_PoolIncentive WHERE fha_refi_incentive IS NULL OR fha_refi_incentive < -1000.0 OR fha_refi_incentive > 2000.0

        if (@cnt > 0)
        BEGIN
            RAISERROR 99999 'FHL Pools with INVALID VALUE for fha_refi_incentive PoolCount : %1!', @cnt
            RETURN
        END

----------------------------------------------------------------------------------------------
-- Check to see if Pools have refi_incentive IS NULL OR refi_incentive < -1000.0 OR refi_incentive > 2000.0
----------------------------------------------------------------------------------------------
        SELECT
            @cnt =  count(1)
        FROM #FHL_PoolIncentive WHERE refi_incentive IS NULL OR refi_incentive < -1000.0 OR refi_incentive > 2000.0

        if (@cnt > 0)
        BEGIN
            RAISERROR 99999 'FHL Pools with INVALID VALUE for refi_incentive PoolCount : %1!', @cnt
            RETURN
        END
        
----------------------------------------------------------------------------------------------
-- Check to see if Pools have refi_incentive_eligible < -1000.0 OR refi_incentive_eligible > 2000.0
----------------------------------------------------------------------------------------------
        SELECT
            @cnt =  count(1)
        FROM #FHL_PoolIncentive WHERE refi_incentive_eligible < -1000.0 OR refi_incentive_eligible > 2000.0

        if (@cnt > 0)
        BEGIN
            RAISERROR 99999 'FHL Pools with INVALID VALUE for refi_incentive_eligible PoolCount : %1!', @cnt
            RETURN
        END
        
----------------------------------------------------------------------------------------------
-- Check to see if Pools have pmi_begin IS NULL OR pmi_begin < 0.0 OR pmi_begin > 300
----------------------------------------------------------------------------------------------
        SELECT
            @cnt =  count(1)
        FROM #FHL_PoolIncentive WHERE pmi_begin IS NULL OR pmi_begin < 0.0 OR pmi_begin > 300

        if (@cnt > 0)
        BEGIN
            RAISERROR 99999 'FHL Pools with INVALID VALUE for pmi_begin PoolCount : %1!', @cnt
            RETURN
        END

----------------------------------------------------------------------------------------------
-- Check to see if Pools have llpa IS NULL OR llpa < -25.0 OR llpa > 1000.0
----------------------------------------------------------------------------------------------
        SELECT
            @cnt =  count(1)
        FROM #FHL_PoolIncentive WHERE llpa IS NULL OR llpa < -25.0 OR llpa > 1000.0

        if (@cnt > 0)
        BEGIN
            RAISERROR 99999 'FHL Pools with INVALID VALUE for llpa PoolCount : %1!', @cnt
            RETURN
        END

----------------------------------------------------------------------------------------------
-- Check to see if Pools have pmi IS NULL OR pmi < 0.0 OR pmi > 500
----------------------------------------------------------------------------------------------
        SELECT
            @cnt =  count(1)
        FROM #FHL_PoolIncentive WHERE pmi IS NULL OR pmi < 0.0 OR pmi > 500

        if (@cnt > 0)
        BEGIN
            RAISERROR 99999 'FHL Pools with INVALID VALUE for pmi PoolCount : %1!', @cnt
            RETURN
        END

----------------------------------------------------------------------------------------------
-- Check to see if Pools have mip IS NULL OR mip < 0.0 OR mip > 300
----------------------------------------------------------------------------------------------
        SELECT
            @cnt =  count(1)
        FROM #FHL_PoolIncentive WHERE mip IS NULL OR mip < 0.0 OR mip > 300

        if (@cnt > 0)
        BEGIN
            RAISERROR 99999 'FHL Pools with INVALID VALUE for mip PoolCount : %1!', @cnt
            RETURN
        END
----------------------------------------------------------------------------------------------
-- Check to see if count of current month changes in a noticeable amount compare with previous month
----------------------------------------------------------------------------------------------
        declare   @cnt_previous int
        SELECT
            @cnt =  count(1)
        FROM #FHL_PoolIncentive WHERE asof = (SELECT asOf FROM #tmp_asOf)

        SELECT
            @cnt_previous =  count(1)
        FROM scale.FHL_PoolIncentive WHERE asof = (SELECT dateadd(month, -1, asOf) FROM #tmp_asOf) AND version = (select  version from #tmp_version)
        
        if (@cnt - @cnt_previous > 0.1 * @cnt_previous OR @cnt_previous - @cnt > 0.1 * @cnt_previous)
        BEGIN
            RAISERROR 99999 'FHL PoolIncentive with INVALID COUNT compare with previous month. Current: %1!; Previous: %2!', @cnt, @cnt_previous
            RETURN
        END        
-- End Tests



-- Load Data into Scale Incentive Table
DELETE FROM scale.FHL_PoolIncentive
FROM scale.FHL_PoolIncentive spi, #FHL_PoolIncentive pi
WHERE 1=1
    AND spi.issueId = pi.issueId
    AND spi.asOf = pi.asOf
    AND pi.marketTicker IN (SELECT tickerName FROM #ticker)
    AND spi.asOf >= (SELECT asOf from #tmp_asOf)
    AND version = (SELECT version from #tmp_version)
;

DECLARE @version varchar(5)
SELECT @version = (select * from #tmp_version)

INSERT INTO scale.FHL_PoolIncentive (issueId, asOf, version, conventional_refi_incentive, fha_refi_incentive, refi_incentive, refi_incentive_eligible, origPMI, currLLPA, currPMI, currMIP)
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
FROM #FHL_PoolIncentive
WHERE marketTicker IN (SELECT tickerName FROM #ticker)
    AND asOf >= (SELECT asOf from #tmp_asOf)
;