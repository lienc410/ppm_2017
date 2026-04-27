-- Fannie Conventional
-- Pool Level
-- Part 5 of 6
-- Script to update the refinance incentive metrics
-- Updates conventional_refi_incentive, fha_refi_incentive, refi_incentive, origPMI, currLLPA, currPMI and currMIP

-- Before execute the script, need to set the dates to run for
DROP TABLE IF EXISTS #tmp_asOf;
--SELECT CAST('#####ASOF#####' AS DATE) asOf INTO #tmp_asOf
SELECT CAST ('1994-02-01' AS DATE) asOf INTO #tmp_asOf
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

--CREATE LF INDEX series_idx ON #Mtg30YrRates_monthly(SeriesName);
--CREATE LF INDEX asOf_idx ON #Mtg30YrRates_monthly(asOf);
--CREATE LF INDEX asOf_lag1_idx ON #Mtg30YrRates_monthly(asOf_lag1);
--CREATE LF INDEX asOf_lag2_idx ON #Mtg30YrRates_monthly(asOf_lag2);

--COMMIT;


-- Create Pool Historical Data
DROP TABLE IF EXISTS #FNM_PoolIncentive;
SELECT
    ph.marketTicker,
    ph.issueId,
    ph.asOf,
    ph.originationDate,
    ph.schambalance,
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

select count(1) from #FNM_PoolIncentive where pmi_begin is NULL
------------------------------------------------------------
-- Step 1: Compute all metrics using Loan Data
------------------------------------------------------------
DROP TABLE IF EXISTS #FNM_LoanBasedIncentive;
SELECT
    pi.issueId,
    pi.asOf,
    sum(sl.origPMI * clh.schambalance) / sum(CASE WHEN sl.origPMI IS NULL THEN 0.0 ELSE clh.schambalance END) as pmi_begin,
    sum(sli.currPMI * clh.schambalance) / sum(CASE WHEN sli.currPMI IS NULL THEN 0.0 ELSE clh.schambalance END) as pmi,
    sum(sli.currLLPA * clh.schambalance) / sum(CASE WHEN sli.currLLPA IS NULL THEN 0.0 ELSE clh.schambalance END) as llpa,
    sum(sli.currMIP * clh.schambalance) / sum(CASE WHEN sli.currMIP IS NULL THEN 0.0 ELSE clh.schambalance END) as mip,
    sum(sli.conventional_refi_incentive * clh.schambalance) / sum(CASE WHEN sli.conventional_refi_incentive IS NULL THEN 0.0 ELSE clh.schambalance END) as conventional_refi_incentive,
    sum(sli.fha_refi_incentive * clh.schambalance) / sum(CASE WHEN sli.fha_refi_incentive IS NULL THEN 0.0 ELSE clh.schambalance END) as fha_refi_incentive,
    sum((CASE WHEN sli.conventional_refi_incentive > sli.fha_refi_incentive THEN sli.conventional_refi_incentive ELSE sli.fha_refi_incentive END) * clh.schambalance) / sum(clh.schambalance) as refi_incentive,
    sum(sli.refi_incentive_eligible * clh.schambalance) / sum(CASE WHEN sli.refi_incentive_eligible IS NULL THEN 0.0 ELSE clh.schambalance END) as refi_incentive_eligible
INTO #FNM_LoanBasedIncentive
FROM #FNM_PoolIncentive pi
JOIN fnm.PIV_Loan cl
    ON pi.issueId = cl.issueId
JOIN scale.FNM_Loan sl
    ON cl.loanSeqNum = sl.loanSeqNum
JOIN fnm.PIV_LoanHist clh
    ON cl.loanSeqNum = clh.loanSeqNum
    AND pi.asOf = clh.asOf
JOIN scale.FNM_LoanIncentive sli
    ON clh.loanSeqNum = sli.loanSeqNum
    AND clh.asOf = sli.asOf
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
    AND issueId NOT IN (SELECT distinct issueId from #FNM_LoanBasedIncentive)
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



select * from scale.FNM_PoolHist






-- Update origPMI based on HARP Percent
UPDATE #FHL_OrigPMI
SET pmi_begin = CASE 
                        WHEN percentHARPed IS NULL THEN 0.0
                        WHEN percentHARPed = 0.0 THEN pmi_begin
                        WHEN percentHARPed = 100.0 THEN m.PMI
                    END
FROM report.PIV_PMI_HARP_MtgIns_Map m
WHERE 1=1
    AND miLevel > pctMtgInsLow
    AND miLevel <= pctMtgInsHigh
;
COMMIT;


SELECT marketTicker, p.asOf, count(1), sum(schamBalance), sum(schamBalance * origPMI) / sum(schamBalance) as origPMI FROM scale.FNM_PoolHist p JOIN scale.FNM_PoolIncentive d ON p.issueId = d.issueId AND p.asOf = d.asOf WHERE p.marketTicker = 'FNCR' AND version = '2.00' GROUP BY p.marketTicker, p.asOf HAVING count(1) > 10 ORDER BY p.asOf


