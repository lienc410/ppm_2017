-- Fannie Conventional
-- Loan Level
-- Part 5 of 7
-- Script to update the refinance incentive metric
-- Updates refi_incentive, currLLPA and currPMI

-- Before execute the script, need to set the dates to run for
DROP TABLE IF EXISTS #tmp_asOf;
SELECT 
CAST('#####ASOF#####' AS DATE) asOf, 
CAST('#####LAST#####' AS DATE) asOf_last,
CAST('2014-01-01' AS DATE) asOf_start
INTO #tmp_asOf
--SELECT CAST ('2012-01-01' AS DATE) asOf INTO #tmp_asOf
;

-- Before execute the script, need to set the appType to run for
DROP TABLE IF EXISTS #tmp_appType;
SELECT '#####APPTYPE#####' AS appType INTO #tmp_appType
--SELECT '4.20' AS appType INTO #tmp_appType
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
--INSERT #ticker SELECT 'FNCT', 'CONVENTIONAL_20YR';    --20 Yr Conventional Fannie
--INSERT #ticker SELECT 'FNCI', 'CONVENTIONAL_15YR';    --15 Yr Conventional Fannie
COMMIT;

CREATE LF INDEX loan_tickerName_idx ON #ticker(tickerName);
COMMIT;

-- Before execute the script, need to set the version to run for
DROP TABLE IF EXISTS #tmp_version;
SELECT mvc.tickerName, mvc.appType, mvc.incentiveVersion_LL as incentiveVersion, mvc.originationVersion_LL as originationVersion 
INTO #tmp_version
FROM scale.ModelVersionConfig mvc
JOIN #tmp_appType tat
     ON mvc.appType = tat.appType
JOIN #ticker tk
     ON mvc.tickerName = tk.tickerName
;
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
	AND ModelType = 'ScaleMtgRateModel v4.0'
    AND asOf_lag2 >= (select asOf_start from #tmp_asOf)
;
COMMIT;

DROP TABLE IF EXISTS #Mtg30YrRates_monthly_refi;
-- one and half month lagged
SELECT
lag1.SeriesName,
asof = lag1.asOf_lag1,
MtgRate = lag1.MtgRate * 0.5 + lag2.MtgRate * 0.5
INTO #Mtg30YrRates_monthly_refi
FROM #Mtg30YrRates_monthly lag1
JOIN #Mtg30YrRates_monthly lag2 ON lag1.asOf_lag1 = lag2.asOf_lag2 AND lag1.SeriesName = lag2.SeriesName
;
COMMIT;

CREATE LF INDEX series_idx ON #Mtg30YrRates_monthly_refi(SeriesName);
CREATE LF INDEX asOf_idx ON #Mtg30YrRates_monthly_refi(asOf);
COMMIT;


-- Save Loan Data
DROP TABLE IF EXISTS #FNM_LoanIncentive1;
SELECT
    cl.loanSeqNum ,
    cl.marketTicker,
	cl.state,
    clh.asOf,
	clh.currentRPB as currentBalance,
	
 --    slh.balance,
    cast(NULL as numeric(12, 2)) as balance,
	
    sl.originationDate,
    sl.numberUnits,
    sl.origFICO,
    sl.origNoteRate,
    sl.miLevel,
    cl.origTerm,
    cl.occType as occupancyStatus,
    cl.loanPurposeType,
    sl.origPMI,
	tk.mtgRateSeries,
	
 --    slh.cltv,
    cast(NULL as numeric(7, 2)) as cltv,
	cast(50 as numeric(7, 2)) as cltv_fake,
	cast(NULL as varchar(10)) as MICancelFlag_lagged,
	
 --   sle.HARP_eligible,
 --   sle.conventional_eligible,
 --   sle.fha_eligible,
    cast(NULL as numeric(6, 2)) as HARP_eligible,
    cast(NULL as numeric(6, 2)) as conventional_eligible,
    cast(NULL as numeric(6, 2)) as fha_eligible,
 --   mr.MtgRate,
 --   mr_gn.MtgRate as MtgRate_GNMA,
    cast(NULL as double) as MtgRate,
	cast(NULL as double) as MtgRate_GNMA,
	tpv.incentiveVersion,

    cast(NULL as numeric(8, 4)) as pmi_base,
    cast(NULL as numeric(8, 4)) as pmi_occ,
    cast(NULL as numeric(8, 4)) as pmi_size,

    cast(NULL as numeric(8, 4)) as pmi_base_cltv50,
    cast(NULL as numeric(8, 4)) as pmi_occ_cltv50,
    cast(NULL as numeric(8, 4)) as pmi_size_cltv50,
    cast(NULL as numeric(8, 4)) as llpa_base,
    cast(NULL as numeric(8, 4)) as llpa_admc,
    cast(NULL as numeric(8, 4)) as llpa_occ,
    cast(NULL as numeric(8, 4)) as llpa_unit,
    cast(NULL as numeric(8, 4)) as llpa_ltv,
    cast(NULL as numeric(8, 4)) as llpa_loansize,

    cast(NULL as numeric(8, 4)) as llpa_base_cltv50,
    cast(NULL as numeric(8, 4)) as llpa_occ_cltv50,
    cast(NULL as numeric(8, 4)) as llpa_unit_cltv50,
    cast(NULL as numeric(8, 4)) as llpa_ltv_cltv50,
    cast(NULL as numeric(8, 4)) as llpa_loansize_cltv50,
    cast(NULL as numeric(8, 4)) as pmi,
    cast(NULL as numeric(8, 4)) as llpa,
    cast(NULL as numeric(8, 4)) as mip,

	cast(NULL as numeric(8, 4)) as pmi_cltv50,
    cast(NULL as numeric(8, 4)) as llpa_cltv50,
    cast(NULL as numeric(8, 4)) as mip_cltv50,
	cast(NULL as numeric(8, 4)) as fixed_cost,
	cast(NULL as numeric(6, 2)) as mortgage_tax,
	
    cast(NULL as numeric(8, 4)) as conv_incentive,
    cast(NULL as numeric(8, 4)) as fha_incentive,
    cast(NULL as numeric(8, 4)) as refi_incentive,
    cast(NULL as numeric(8, 4)) as refi_incentive_eligible,

	cast(NULL as numeric(8, 4)) as conv_incentive_cltv50,
    cast(NULL as numeric(8, 4)) as fha_incentive_cltv50,
    cast(NULL as numeric(8, 4)) as refi_incentive_cltv50,
    cast(NULL as numeric(8, 4)) as conv_incentive_fc,
    cast(NULL as numeric(8, 4)) as fha_incentive_fc,
    cast(NULL as numeric(8, 4)) as refi_incentive_fc,
    cast(NULL as numeric(8, 4)) as refi_incentive_eligible_fc,

	cast(NULL as numeric(8, 4)) as conv_incentive_fc_cltv50,
    cast(NULL as numeric(8, 4)) as fha_incentive_fc_cltv50,
    cast(NULL as numeric(8, 4)) as refi_incentive_fc_cltv50
INTO #FNM_LoanIncentive
FROM scale.FNM_RefreshLoans srl
JOIN fnm.PIV_Loan cl
    ON srl.loanSeqNum = cl.loanSeqNum
JOIN #ticker tk
    ON cl.marketTicker = tk.tickerName
JOIN #tmp_version tpv
    ON cl.marketTicker = tpv.tickerName
JOIN scale.FNM_Loan_Dev sl
    ON cl.loanSeqNum = sl.loanSeqNum
JOIN
(
    SELECT loanSeqNum, asOf, schambalance, currentRPB FROM fnm.PIV_LoanHist WHERE asOf >= '20140101'
    
    UNION ALL
    
    SELECT loanSeqNum, asOf, schambalance, amortBalance as currentRPB FROM fnm.PIV_Derived_LoanHist
) clh
    ON cl.loanSeqNum = clh.loanSeqNum
-- JOIN scale.FNM_LoanHist slh
--     ON clh.loanSeqNum = slh.loanSeqNum
--    AND clh.asOf = slh.asOf
-- JOIN scale.FNM_LoanEligibility sle
--    ON slh.loanSeqNum = sle.loanSeqNum
--    AND slh.asOf = sle.asOf
-- JOIN #Mtg30YrRates_monthly_refi mr
--   ON mr.asOf = clh.asOf
--    AND mr.SeriesName = tk.mtgRateSeries
-- JOIN #Mtg30YrRates_monthly_refi mr_gn
--    ON mr_gn.asOf = clh.asOf
--    AND mr_gn.SeriesName = 'GINNIE_30YR'
WHERE 1=1
    AND clh.asOf >= (select asOf_start from #tmp_asOf)
	AND clh.asOf <= (select asOf_last from #tmp_asOf)
	AND sl.version in (select  originationVersion from #tmp_version)
;

DROP TABLE IF EXISTS #FNM_LoanIncentive;
SELECT
    cl.loanSeqNum ,
    cl.marketTicker,
	cl.state,
    clh.asOf,
	clh.currentRPB as currentBalance,
	
 --    slh.balance,
    cast(NULL as numeric(12, 2)) as balance,
	
    sl.originationDate,
    sl.numberUnits,
    sl.origFICO,
    sl.origNoteRate,
    sl.miLevel,
    cl.origTerm,
    cl.occType as occupancyStatus,
    cl.loanPurposeType,
    sl.origPMI,
	tk.mtgRateSeries,
	
 --    slh.cltv,
    cast(NULL as numeric(7, 2)) as cltv,
	cast(50 as numeric(7, 2)) as cltv_fake,
	cast(NULL as varchar(10)) as MICancelFlag_lagged,
	
 --   sle.HARP_eligible,
 --   sle.conventional_eligible,
 --   sle.fha_eligible,
    cast(NULL as numeric(6, 2)) as HARP_eligible,
    cast(NULL as numeric(6, 2)) as conventional_eligible,
    cast(NULL as numeric(6, 2)) as fha_eligible,
 --   mr.MtgRate,
 --   mr_gn.MtgRate as MtgRate_GNMA,
    cast(NULL as double) as MtgRate,
	cast(NULL as double) as MtgRate_GNMA,
	tpv.incentiveVersion,

    cast(NULL as numeric(8, 4)) as pmi_base,
    cast(NULL as numeric(8, 4)) as pmi_occ,
    cast(NULL as numeric(8, 4)) as pmi_size,

    cast(NULL as numeric(8, 4)) as pmi_base_cltv50,
    cast(NULL as numeric(8, 4)) as pmi_occ_cltv50,
    cast(NULL as numeric(8, 4)) as pmi_size_cltv50,
    cast(NULL as numeric(8, 4)) as llpa_base,
    cast(NULL as numeric(8, 4)) as llpa_admc,
    cast(NULL as numeric(8, 4)) as llpa_occ,
    cast(NULL as numeric(8, 4)) as llpa_unit,
    cast(NULL as numeric(8, 4)) as llpa_ltv,
    cast(NULL as numeric(8, 4)) as llpa_loansize,

    cast(NULL as numeric(8, 4)) as llpa_base_cltv50,
    cast(NULL as numeric(8, 4)) as llpa_occ_cltv50,
    cast(NULL as numeric(8, 4)) as llpa_unit_cltv50,
    cast(NULL as numeric(8, 4)) as llpa_ltv_cltv50,
    cast(NULL as numeric(8, 4)) as llpa_loansize_cltv50,
    cast(NULL as numeric(8, 4)) as pmi,
    cast(NULL as numeric(8, 4)) as llpa,
    cast(NULL as numeric(8, 4)) as mip,

	cast(NULL as numeric(8, 4)) as pmi_cltv50,
    cast(NULL as numeric(8, 4)) as llpa_cltv50,
    cast(NULL as numeric(8, 4)) as mip_cltv50,
	cast(NULL as numeric(8, 4)) as fixed_cost,
	cast(NULL as numeric(6, 2)) as mortgage_tax,
	
    cast(NULL as numeric(8, 4)) as conv_incentive,
    cast(NULL as numeric(8, 4)) as fha_incentive,
    cast(NULL as numeric(8, 4)) as refi_incentive,
    cast(NULL as numeric(8, 4)) as refi_incentive_eligible,

	cast(NULL as numeric(8, 4)) as conv_incentive_cltv50,
    cast(NULL as numeric(8, 4)) as fha_incentive_cltv50,
    cast(NULL as numeric(8, 4)) as refi_incentive_cltv50,
    cast(NULL as numeric(8, 4)) as conv_incentive_fc,
    cast(NULL as numeric(8, 4)) as fha_incentive_fc,
    cast(NULL as numeric(8, 4)) as refi_incentive_fc,
    cast(NULL as numeric(8, 4)) as refi_incentive_eligible_fc,

	cast(NULL as numeric(8, 4)) as conv_incentive_fc_cltv50,
    cast(NULL as numeric(8, 4)) as fha_incentive_fc_cltv50,
    cast(NULL as numeric(8, 4)) as refi_incentive_fc_cltv50
INTO #FNM_LoanIncentive
FROM fnm.PIV_Loan cl
JOIN #ticker tk
    ON cl.marketTicker = tk.tickerName
JOIN #tmp_version tpv
    ON cl.marketTicker = tpv.tickerName
JOIN scale.FNM_Loan_Dev sl
    ON cl.loanSeqNum = sl.loanSeqNum
JOIN
(
    SELECT loanSeqNum, asOf, schambalance, currentRPB FROM fnm.PIV_LoanHist WHERE asOf >= '20140101'
    
    UNION ALL
    
    SELECT loanSeqNum, asOf, schambalance, amortBalance as currentRPB FROM fnm.PIV_Derived_LoanHist
) clh
    ON cl.loanSeqNum = clh.loanSeqNum
-- JOIN scale.FNM_LoanHist slh
--     ON clh.loanSeqNum = slh.loanSeqNum
--    AND clh.asOf = slh.asOf
-- JOIN scale.FNM_LoanEligibility sle
--    ON slh.loanSeqNum = sle.loanSeqNum
--    AND slh.asOf = sle.asOf
-- JOIN #Mtg30YrRates_monthly_refi mr
--   ON mr.asOf = clh.asOf
--    AND mr.SeriesName = tk.mtgRateSeries
-- JOIN #Mtg30YrRates_monthly_refi mr_gn
--    ON mr_gn.asOf = clh.asOf
--    AND mr_gn.SeriesName = 'GINNIE_30YR'
WHERE 1=1
    AND clh.asOf >= (select asOf from #tmp_asOf)
	AND clh.asOf <= (select asOf_last from #tmp_asOf)
	AND sl.version in (select  originationVersion from #tmp_version)
;

--Removing refresh loans to avoid duplicates.
DELETE FROM #FNM_LoanIncentive
FROM #FNM_LoanIncentive li
JOIN #FNM_LoanIncentive1 li1
ON li.loanSeqNum = li1.loanSeqNum
AND li.asOf = li1.asOf;

--Inserting entire data for refresh loans.
INSERT INTO #FNM_LoanIncentive
SELECT * FROM #FNM_LoanIncentive1;

COMMIT;
CREATE HG INDEX loan_id_idx ON #FNM_LoanIncentive(loanSeqNum);
CREATE LF INDEX asof_date_idx ON #FNM_LoanIncentive(asOf);
CREATE LF INDEX ticker_idx ON #FNM_LoanIncentive(marketTicker);
CREATE LF INDEX origination_date_idx ON #FNM_LoanIncentive(originationDate);
CREATE LF INDEX occ_idx ON #FNM_LoanIncentive(occupancyStatus);
CREATE LF INDEX units_idx ON #FNM_LoanIncentive(numberUnits);
CREATE LF INDEX fico_idx ON #FNM_LoanIncentive(origFICO);
COMMIT;

--Mortgage Rate Interpolation Factor
DROP TABLE IF EXISTS #FNM_Mortgage_Interpolation_Factor;
SELECT 
inc.loanSeqNum,
inc.asOf,
CASE
    WHEN inc.currentBalance <= cll.LoanSize_limit THEN CAST(0 as float)
    WHEN inc.currentBalance > (cll.LoanSize_limit + 25000) THEN CAST(1 as float)
    ELSE cast(((inc.currentBalance - cll.LoanSize_limit)/25000) as float)
END as InterPolation_Factor
INTO #FNM_Mortgage_Interpolation_Factor
FROM #FNM_LoanIncentive inc,report.conforming_loansize_limit cll
where inc.asOf > cll.startDate
AND inc.asOf < cll.endDate;
COMMIT;

--Update Mortgage Rate
UPDATE #FNM_LoanIncentive inc
SET MtgRate = (1-InterPolation_Factor)*mr1.MtgRate + InterPolation_Factor * mr2.MtgRate
FROM #Mtg30YrRates_monthly_refi mr1
INNER JOIN #FNM_Mortgage_Interpolation_Factor mif
    ON mif.asOf = mr1.asOf
    AND mr1.SeriesName = 'CONVENTIONAL_30YR'
INNER JOIN #Mtg30YrRates_monthly_refi mr2
    ON mif.asOf = mr2.asOf
    AND mr2.SeriesName = 'JUMBO_30YR'
WHERE inc.loanSeqNum = mif.loanSeqNum
AND inc.asOf = mif.asOf;
COMMIT;

UPDATE #FNM_LoanIncentive inc
SET MtgRate = mr.MtgRate
FROM #Mtg30YrRates_monthly_refi mr
  WHERE mr.asOf = inc.asOf
  AND mr.SeriesName = 'CONVENTIONAL_30YR'
  AND inc.MtgRate is NULL;
COMMIT;

UPDATE #FNM_LoanIncentive inc
SET MtgRate_GNMA = mr_gn.MtgRate
FROM #Mtg30YrRates_monthly_refi mr_gn
    WHERE mr_gn.asOf = inc.asOf
    AND mr_gn.SeriesName = 'GINNIE_30YR'
;
COMMIT;

-- Update cltv and balance
UPDATE #FNM_LoanIncentive inc
SET balance = slh.balance,
    cltv = slh.cltv,
	MICancelFlag_lagged=slh.MICancelFlag_lagged
FROM scale.FNM_LoanHist slh
    WHERE inc.loanSeqNum = slh.loanSeqNum
    AND inc.asOf = slh.asOf
COMMIT;


-- Update refi eligibility
UPDATE #FNM_LoanIncentive inc
SET HARP_eligible = sle.HARP_eligible,
    conventional_eligible = sle.conventional_eligible,
    fha_eligible = sle.fha_eligible
FROM scale.FNM_LoanEligibility sle
    WHERE inc.loanSeqNum = sle.loanSeqNum
    AND inc.asOf = sle.asOf
;
COMMIT;

delete from #FNM_LoanIncentive where HARP_eligible is NULL;

-- Original PMI Cancellation, if flag='Y' then cancel
UPDATE #FNM_LoanIncentive i SET i.origPMI=0
WHERE MICancelFlag_lagged='Y';
COMMIT;

-- Original PMI haircut
UPDATE #FNM_LoanIncentive i SET i.origPMI=0.85*i.origPMI
WHERE i.loanseqnum in (select loanseqnum from scale.fnm_mi_haircut);
COMMIT;

-- Update pmi_base
UPDATE #FNM_LoanIncentive inc 
SET inc.pmi_base = (PMI_LL_FL * (LTV_H - CLTV) * (FICO_H - origFICO) + PMI_LH_FL * (CLTV - LTV_L) * (FICO_H - origFICO) 
      + PMI_LL_FH * (LTV_H - CLTV) * (origFICO - FICO_L) + PMI_LH_FH * (CLTV - LTV_L) * (origFICO - FICO_L)
      ) / ((LTV_H - LTV_L) * (FICO_H - FICO_L)) 
FROM report.PIV_PMI_Base_Bilinear_Interpolation_v2 pmi
WHERE 1=1
    AND LoanPurpose = 'REFI'
    AND inc.asOf >= pmi.startDate and inc.asOf < pmi.endDate 
    AND CLTV > pmi.LTV_L AND CLTV <= pmi.LTV_H 
    AND origFICO > pmi.FICO_L AND origFICO <= pmi.FICO_H
	AND pmi.RateType = 'Fixed'
    AND inc.origTerm > pmi.TermBucketStart AND inc.origTerm <= pmi.TermBucketEnd
;
UPDATE #FNM_LoanIncentive inc SET inc.pmi_base = 0 WHERE inc.pmi_base IS NULL;

-- Update pmi_base_cltv50
UPDATE #FNM_LoanIncentive inc 
SET inc.pmi_base_cltv50 = (PMI_LL_FL * (LTV_H - cltv_fake) * (FICO_H - origFICO) + PMI_LH_FL * (cltv_fake - LTV_L) * (FICO_H - origFICO) 
      + PMI_LL_FH * (LTV_H - cltv_fake) * (origFICO - FICO_L) + PMI_LH_FH * (cltv_fake - LTV_L) * (origFICO - FICO_L)
      ) / ((LTV_H - LTV_L) * (FICO_H - FICO_L)) 
FROM report.PIV_PMI_Base_Bilinear_Interpolation_v2 pmi
WHERE 1=1
    AND LoanPurpose = 'REFI'
    AND inc.asOf >= pmi.startDate and inc.asOf < pmi.endDate 
    AND cltv_fake > pmi.LTV_L AND cltv_fake <= pmi.LTV_H 
    AND origFICO > pmi.FICO_L AND origFICO <= pmi.FICO_H
	AND pmi.RateType = 'Fixed'
    AND inc.origTerm > pmi.TermBucketStart AND inc.origTerm <= pmi.TermBucketEnd
;
UPDATE #FNM_LoanIncentive inc SET inc.pmi_base_cltv50 = 0 WHERE inc.pmi_base_cltv50 IS NULL;
-- Update pmi_occ
UPDATE #FNM_LoanIncentive inc 
SET inc.pmi_occ = (PMI_LL_FL * (LTV_H - CLTV) * (FICO_H - origFICO) + PMI_LH_FL * (CLTV - LTV_L) * (FICO_H - origFICO) 
      + PMI_LL_FH * (LTV_H - CLTV) * (origFICO - FICO_L) + PMI_LH_FH * (CLTV - LTV_L) * (origFICO - FICO_L)
      ) / ((LTV_H - LTV_L) * (FICO_H - FICO_L)) 
FROM report.PIV_PMI_Occupancy_Bilinear_Interpolation pmi
WHERE 1=1
    AND inc.occupancyStatus = pmi.OccType
    AND inc.asOf >= pmi.startDate and inc.asOf < pmi.endDate 
    AND CLTV > pmi.LTV_L AND CLTV <= pmi.LTV_H 
    AND origFICO > pmi.FICO_L AND origFICO <= pmi.FICO_H
;
UPDATE #FNM_LoanIncentive inc SET inc.pmi_occ = 0 WHERE inc.pmi_occ IS NULL;

-- Update pmi_occ_cltv50
UPDATE #FNM_LoanIncentive inc 
SET inc.pmi_occ_cltv50 = (PMI_LL_FL * (LTV_H - cltv_fake) * (FICO_H - origFICO) + PMI_LH_FL * (cltv_fake - LTV_L) * (FICO_H - origFICO) 
      + PMI_LL_FH * (LTV_H - cltv_fake) * (origFICO - FICO_L) + PMI_LH_FH * (cltv_fake - LTV_L) * (origFICO - FICO_L)
      ) / ((LTV_H - LTV_L) * (FICO_H - FICO_L)) 
FROM report.PIV_PMI_Occupancy_Bilinear_Interpolation pmi
WHERE 1=1
    AND inc.occupancyStatus = pmi.OccType
    AND inc.asOf >= pmi.startDate and inc.asOf < pmi.endDate 
    AND cltv_fake > pmi.LTV_L AND cltv_fake <= pmi.LTV_H 
    AND origFICO > pmi.FICO_L AND origFICO <= pmi.FICO_H
;
UPDATE #FNM_LoanIncentive inc SET inc.pmi_occ_cltv50 = 0 WHERE inc.pmi_occ_cltv50 IS NULL;
-- Update pmi_size: step 1. bilinear interpolation for LTV and FICO
UPDATE #FNM_LoanIncentive inc 
SET inc.pmi_size = (PMI_LL_FL * (LTV_H - CLTV) * (FICO_H - origFICO) + PMI_LH_FL * (CLTV - LTV_L) * (FICO_H - origFICO) 
      + PMI_LL_FH * (LTV_H - CLTV) * (origFICO - FICO_L) + PMI_LH_FH * (CLTV - LTV_L) * (origFICO - FICO_L)
      ) / ((LTV_H - LTV_L) * (FICO_H - FICO_L)) 
FROM report.PIV_PMI_LoanSize_Bilinear_Interpolation_25k pmi
WHERE 1=1
    AND inc.balance > pmi.LoanSize_L and inc.balance <= LoanSize_H
    AND inc.asOf >= pmi.startDate and inc.asOf < pmi.endDate 
    AND CLTV > pmi.LTV_L AND CLTV <= pmi.LTV_H 
    AND origFICO > pmi.FICO_L AND origFICO <= pmi.FICO_H
;
-- Update pmi_size: step 2. linear interpolation for loan size after step 1
UPDATE #FNM_LoanIncentive inc 
SET inc.pmi_size = (balance - LoanSize_L) / (LoanSize_H - LoanSize_L) * (inc.pmi_size - 0.0)
FROM report.PIV_PMI_LoanSize_Bilinear_Interpolation_25k pmi
WHERE 1=1
    AND inc.balance > pmi.LoanSize_L and inc.balance <= LoanSize_H
    AND inc.asOf >= pmi.startDate and inc.asOf < pmi.endDate 
    AND CLTV > pmi.LTV_L AND CLTV <= pmi.LTV_H 
    AND origFICO > pmi.FICO_L AND origFICO <= pmi.FICO_H
    AND needExtraInterp = 1
;
UPDATE #FNM_LoanIncentive inc SET inc.pmi_size = 0 WHERE inc.pmi_size IS NULL;

-- Update pmi_size_cltv50: step 1. bilinear interpolation for LTV and FICO
UPDATE #FNM_LoanIncentive inc 
SET inc.pmi_size_cltv50 = (PMI_LL_FL * (LTV_H - cltv_fake) * (FICO_H - origFICO) + PMI_LH_FL * (cltv_fake - LTV_L) * (FICO_H - origFICO) 
      + PMI_LL_FH * (LTV_H - cltv_fake) * (origFICO - FICO_L) + PMI_LH_FH * (cltv_fake - LTV_L) * (origFICO - FICO_L)
      ) / ((LTV_H - LTV_L) * (FICO_H - FICO_L)) 
FROM report.PIV_PMI_LoanSize_Bilinear_Interpolation_25k pmi
WHERE 1=1
    AND inc.balance > pmi.LoanSize_L and inc.balance <= LoanSize_H
    AND inc.asOf >= pmi.startDate and inc.asOf < pmi.endDate 
    AND cltv_fake > pmi.LTV_L AND cltv_fake <= pmi.LTV_H 
    AND origFICO > pmi.FICO_L AND origFICO <= pmi.FICO_H
;
-- Update pmi_size_cltv50: step 2. linear interpolation for loan size after step 1
UPDATE #FNM_LoanIncentive inc 
SET inc.pmi_size_cltv50 = (balance - LoanSize_L) / (LoanSize_H - LoanSize_L) * (inc.pmi_size_cltv50 - 0.0)
FROM report.PIV_PMI_LoanSize_Bilinear_Interpolation_25k pmi
WHERE 1=1
    AND inc.balance > pmi.LoanSize_L and inc.balance <= LoanSize_H
    AND inc.asOf >= pmi.startDate and inc.asOf < pmi.endDate 
    AND cltv_fake > pmi.LTV_L AND cltv_fake <= pmi.LTV_H 
    AND origFICO > pmi.FICO_L AND origFICO <= pmi.FICO_H
    AND needExtraInterp = 1
;
UPDATE #FNM_LoanIncentive inc SET inc.pmi_size_cltv50 = 0 WHERE inc.pmi_size_cltv50 IS NULL;

-- Update Base LLPA
UPDATE #FNM_LoanIncentive inc 
SET inc.llpa_base = (LLPA_LL_FL * (LTV_H - CLTV) * (FICO_H - origFICO) + LLPA_LH_FL * (CLTV - LTV_L) * (FICO_H - origFICO) 
      + LLPA_LL_FH * (LTV_H - CLTV) * (origFICO - FICO_L) + LLPA_LH_FH * (CLTV - LTV_L) * (origFICO - FICO_L)
      ) / ((LTV_H - LTV_L) * (FICO_H - FICO_L)) 
FROM report.PIV_LLPA_Base_Bilinear_Interpolation llpa
WHERE 1=1
    AND CLTV > llpa.LTV_L 
    AND CLTV <= llpa.LTV_H 
    AND origFICO > llpa.FICO_L 
    AND origFICO <= llpa.FICO_H
    AND inc.asOf >= llpa.startDate and inc.asOf < llpa.endDate
;
UPDATE #FNM_LoanIncentive inc SET inc.llpa_base = 0 WHERE inc.llpa_base IS NULL;

-- Update Base LLPA CLTV50
UPDATE #FNM_LoanIncentive inc 
SET inc.llpa_base_cltv50 = (LLPA_LL_FL * (LTV_H - cltv_fake) * (FICO_H - origFICO) + LLPA_LH_FL * (cltv_fake - LTV_L) * (FICO_H - origFICO) 
      + LLPA_LL_FH * (LTV_H - cltv_fake) * (origFICO - FICO_L) + LLPA_LH_FH * (cltv_fake - LTV_L) * (origFICO - FICO_L)
      ) / ((LTV_H - LTV_L) * (FICO_H - FICO_L)) 
FROM report.PIV_LLPA_Base_Bilinear_Interpolation llpa
WHERE 1=1
    AND cltv_fake > llpa.LTV_L 
    AND cltv_fake <= llpa.LTV_H 
    AND origFICO > llpa.FICO_L 
    AND origFICO <= llpa.FICO_H
    AND inc.asOf >= llpa.startDate and inc.asOf < llpa.endDate
;
UPDATE #FNM_LoanIncentive inc SET inc.llpa_base_cltv50 = 0 WHERE inc.llpa_base_cltv50 IS NULL;
-- Update ADMC LLPA
UPDATE #FNM_LoanIncentive inc SET inc.llpa_admc = llpa.LLPA
FROM report.PIV_LLPA_ADMC llpa
WHERE 1=1
    AND inc.asOf >= llpa.startDate and inc.asOf < llpa.endDate 
;
UPDATE #FNM_LoanIncentive inc SET inc.llpa_admc = 0 WHERE inc.llpa_admc IS NULL;

-- Update Occupancy LLPA
UPDATE #FNM_LoanIncentive inc 
SET inc.llpa_occ = (CLTV - LTV_L) / (LTV_H - LTV_L) * (LLPA_LH - LLPA_LL) + LLPA_LL
FROM report.PIV_LLPA_Occupancy_Linear_Interpolation llpa
WHERE 1=1
    AND inc.occupancyStatus = llpa.OccType
    AND inc.asOf >= llpa.startDate AND inc.asOf < llpa.endDate 
    AND inc.CLTV > llpa.LTV_L AND inc.CLTV <= llpa.LTV_H 
;
UPDATE #FNM_LoanIncentive inc SET inc.llpa_occ = 0 WHERE inc.llpa_occ IS NULL;

-- Update Occupancy LLPA CLTV50
UPDATE #FNM_LoanIncentive inc 
SET inc.llpa_occ_cltv50 = (cltv_fake - LTV_L) / (LTV_H - LTV_L) * (LLPA_LH - LLPA_LL) + LLPA_LL
FROM report.PIV_LLPA_Occupancy_Linear_Interpolation llpa
WHERE 1=1
    AND inc.occupancyStatus = llpa.OccType
    AND inc.asOf >= llpa.startDate AND inc.asOf < llpa.endDate 
    AND inc.cltv_fake > llpa.LTV_L AND inc.cltv_fake <= llpa.LTV_H 
;
UPDATE #FNM_LoanIncentive inc SET inc.llpa_occ_cltv50 = 0 WHERE inc.llpa_occ_cltv50 IS NULL;
-- Update Units LLPA
UPDATE #FNM_LoanIncentive inc 
SET inc.llpa_unit = (CLTV - LTV_L) / (LTV_H - LTV_L) * (LLPA_LH - LLPA_LL) + LLPA_LL
FROM report.PIV_LLPA_Units_Linear_Interpolation llpa
WHERE 1=1
    AND inc.numberUnits >= llpa.numUnitsStart AND inc.numberUnits < llpa.numUnitsEnd
    AND inc.asOf >= llpa.startDate AND inc.asOf < llpa.endDate 
    AND inc.CLTV > llpa.LTV_L AND inc.CLTV <= llpa.LTV_H 
;
UPDATE #FNM_LoanIncentive inc SET inc.llpa_unit = 0 WHERE inc.llpa_unit IS NULL;

-- Update Units LLPA CLTV50
UPDATE #FNM_LoanIncentive inc 
SET inc.llpa_unit_cltv50 = (cltv_fake - LTV_L) / (LTV_H - LTV_L) * (LLPA_LH - LLPA_LL) + LLPA_LL
FROM report.PIV_LLPA_Units_Linear_Interpolation llpa
WHERE 1=1
    AND inc.numberUnits >= llpa.numUnitsStart AND inc.numberUnits < llpa.numUnitsEnd
    AND inc.asOf >= llpa.startDate AND inc.asOf < llpa.endDate 
    AND inc.cltv_fake > llpa.LTV_L AND inc.cltv_fake <= llpa.LTV_H 
;
UPDATE #FNM_LoanIncentive inc SET inc.llpa_unit_cltv50 = 0 WHERE inc.llpa_unit_cltv50 IS NULL;
-- Update LTV LLPA
UPDATE #FNM_LoanIncentive inc SET inc.llpa_ltv = llpa.LLPA
FROM report.PIV_LLPA_LTV llpa
WHERE 1=1
    AND inc.asOf >= llpa.startDate and inc.asOf < llpa.endDate 
    AND inc.cltv > llpa.LTVBucketStart and inc.cltv <= llpa.LTVBucketEnd
;
UPDATE #FNM_LoanIncentive inc SET inc.llpa_ltv = 0 WHERE inc.llpa_ltv IS NULL;

-- Update LTV LLPA CLTV50
UPDATE #FNM_LoanIncentive inc SET inc.llpa_ltv_cltv50 = llpa.LLPA
FROM report.PIV_LLPA_LTV llpa
WHERE 1=1
    AND inc.asOf >= llpa.startDate and inc.asOf < llpa.endDate 
    AND inc.cltv_fake > llpa.LTVBucketStart and inc.cltv_fake <= llpa.LTVBucketEnd
;
UPDATE #FNM_LoanIncentive inc SET inc.llpa_ltv_cltv50 = 0 WHERE inc.llpa_ltv_cltv50 IS NULL;
-- Update Loan Size
UPDATE #FNM_LoanIncentive inc 
SET inc.llpa_loansize = (balance - LoanSize_L) / (LoanSize_H - LoanSize_L) * (LLPA_LH - LLPA_LL) + LLPA_LL
FROM report.PIV_LLPA_LoanSize_Interpolation_25k llpa
WHERE 1=1
    AND inc.asOf >= llpa.startDate and inc.asOf < llpa.endDate 
    AND inc.balance > llpa.LoanSize_L and inc.balance <= llpa.LoanSize_H
    AND inc.cltv > llpa.LTVBucketStart and inc.cltv <= llpa.LTVBucketEnd
;
UPDATE #FNM_LoanIncentive inc SET inc.llpa_loansize = 0 WHERE inc.llpa_loansize IS NULL;

-- Update Loan Size CLTV50
UPDATE #FNM_LoanIncentive inc 
SET inc.llpa_loansize_cltv50 = (balance - LoanSize_L) / (LoanSize_H - LoanSize_L) * (LLPA_LH - LLPA_LL) + LLPA_LL
FROM report.PIV_LLPA_LoanSize_Interpolation_25k llpa
WHERE 1=1
    AND inc.asOf >= llpa.startDate and inc.asOf < llpa.endDate 
    AND inc.balance > llpa.LoanSize_L and inc.balance <= llpa.LoanSize_H
    AND inc.cltv_fake > llpa.LTVBucketStart and inc.cltv_fake <= llpa.LTVBucketEnd
;
UPDATE #FNM_LoanIncentive inc SET inc.llpa_loansize_cltv50 = 0 WHERE inc.llpa_loansize_cltv50 IS NULL;
-- Update Base MIP
UPDATE #FNM_LoanIncentive inc 
SET inc.mip = (AnnualMIPPoints_LL_SL * (LTV_H - CLTV) * (LoanSize_H - balance) + AnnualMIPPoints_LH_SL * (CLTV - LTV_L) * (LoanSize_H - balance) 
                + AnnualMIPPoints_LL_SH * (LTV_H - CLTV) * (balance - LoanSize_L) + AnnualMIPPoints_LH_SH * (CLTV - LTV_L) * (balance - LoanSize_L)
                ) / ((LTV_H - LTV_L) * (LoanSize_H - LoanSize_L))
            + mip_base.UpfrontMIPPoints / 12.0
FROM report.PIV_MIP_Base_Bilinear_Interpolation_25k mip_base
WHERE 1=1
    AND inc.origTerm             >  mip_base.TermBucketStart
	AND inc.origTerm             <= mip_base.TermBucketEnd
	AND inc.cltv                 >  mip_base.LTV_L
	AND inc.cltv                 <= mip_base.LTV_H
	AND inc.balance              >= mip_base.LoanSize_L
	AND inc.balance              <= mip_base.LoanSize_H
    AND inc.originationDate      >  mip_base.OriginationStartDate
	AND inc.originationDate      <= mip_base.OriginationEndDate
	AND inc.asOf                 >  mip_base.StartDate
	AND inc.asOf                 <= mip_base.EndDate
;
UPDATE #FNM_LoanIncentive SET mip = 0.0 WHERE mip IS NULL;
COMMIT;

-- Update Base MIP CLTV50
UPDATE #FNM_LoanIncentive inc 
SET inc.mip_cltv50 = (AnnualMIPPoints_LL_SL * (LTV_H - cltv_fake) * (LoanSize_H - balance) + AnnualMIPPoints_LH_SL * (cltv_fake - LTV_L) * (LoanSize_H - balance) 
                + AnnualMIPPoints_LL_SH * (LTV_H - cltv_fake) * (balance - LoanSize_L) + AnnualMIPPoints_LH_SH * (cltv_fake - LTV_L) * (balance - LoanSize_L)
                ) / ((LTV_H - LTV_L) * (LoanSize_H - LoanSize_L))
            + mip_base.UpfrontMIPPoints / 12.0
FROM report.PIV_MIP_Base_Bilinear_Interpolation_25k mip_base
WHERE 1=1
    AND inc.origTerm             >  mip_base.TermBucketStart
	AND inc.origTerm             <= mip_base.TermBucketEnd
	AND inc.cltv_fake                 >  mip_base.LTV_L
	AND inc.cltv_fake                 <= mip_base.LTV_H
	AND inc.balance              >= mip_base.LoanSize_L
	AND inc.balance              <= mip_base.LoanSize_H
    AND inc.originationDate      >  mip_base.OriginationStartDate
	AND inc.originationDate      <= mip_base.OriginationEndDate
	AND inc.asOf                 >  mip_base.StartDate
	AND inc.asOf                 <= mip_base.EndDate
;
UPDATE #FNM_LoanIncentive SET mip_cltv50 = 0.0 WHERE mip_cltv50 IS NULL;
COMMIT;
-- Update PMI and LLPA Incentive
UPDATE #FNM_LoanIncentive inc SET
pmi = (CASE 
                WHEN HARP_eligible = 1 THEN 0 
                ELSE (pmi_base + pmi_occ + pmi_size) / 100.0 
            END),
llpa = (CASE 
                WHEN HARP_eligible = 1 THEN 
                    (CASE 
                        WHEN (llpa_base + llpa_admc + llpa_occ + llpa_unit + llpa_ltv + llpa_loansize) / 100.0 > 0.75 THEN 0.75 
                        ELSE (llpa_base + llpa_admc + llpa_occ + llpa_unit + llpa_ltv + llpa_loansize) / 100.0
                    END) 
                ELSE (llpa_base + llpa_admc + llpa_occ + llpa_unit + llpa_ltv + llpa_loansize) / 100.0
            END),
mip = mip / 100.0
;

-- Update PMI and LLPA Incentive CLTV50
UPDATE #FNM_LoanIncentive inc SET
pmi_cltv50 = (CASE 
                WHEN HARP_eligible = 1 THEN 0 
                ELSE (pmi_base_cltv50 + pmi_occ_cltv50 + pmi_size_cltv50) / 100.0 
            END),
llpa_cltv50 = (CASE 
                WHEN HARP_eligible = 1 THEN 
                    (CASE 
                        WHEN (llpa_base_cltv50 + llpa_admc + llpa_occ_cltv50 + llpa_unit_cltv50 + llpa_ltv_cltv50 + llpa_loansize_cltv50) / 100.0 > 0.75 THEN 0.75 
                        ELSE (llpa_base_cltv50 + llpa_admc + llpa_occ_cltv50 + llpa_unit_cltv50 + llpa_ltv_cltv50 + llpa_loansize_cltv50) / 100.0
                    END) 
                ELSE (llpa_base_cltv50 + llpa_admc + llpa_occ_cltv50 + llpa_unit_cltv50 + llpa_ltv_cltv50 + llpa_loansize_cltv50) / 100.0
            END),
mip_cltv50 = mip_cltv50 / 100.0
;

-- Update fixed cost adjustment
UPDATE #FNM_LoanIncentive inc 
SET inc.fixed_cost=CASE WHEN currentBalance <= 40000 THEN 1.0
									 ELSE (2000.0/currentBalance)*20.0 END;
COMMIT;

-- Update mortgage tax adjustment
UPDATE #FNM_LoanIncentive inc 
SET inc.mortgage_tax=CASE WHEN inc.state in ('NY') THEN 0.5 ELSE 0.0 END;
COMMIT;
-- Update LLPA for 15 Year Loans
UPDATE #FNM_LoanIncentive inc SET inc.llpa = 0 WHERE inc.marketTicker = 'FNCI';
COMMIT;

-- Update LLPA CLTV50 for 15 Year Loans
UPDATE #FNM_LoanIncentive inc SET inc.llpa_cltv50 = 0 WHERE inc.marketTicker = 'FNCI';
COMMIT;
-- Update Conventional Refinance Incentive
UPDATE #FNM_LoanIncentive inc 
SET conv_incentive = CASE WHEN inc.marketTicker = 'FNCT' THEN origNoteRate + (origPMI / 100.0) - MtgRate - (llpa / 3.5) - pmi - mortgage_tax
                                ELSE origNoteRate + (origPMI / 100.0) - MtgRate - (llpa / 4.0) - pmi - mortgage_tax END;
DELETE from #FNM_LoanIncentive where conv_incentive is NULL;

UPDATE #FNM_LoanIncentive inc 
SET conv_incentive_fc = CASE WHEN inc.marketTicker = 'FNCT' THEN origNoteRate + (origPMI / 100.0) - MtgRate - (llpa / 3.5) - pmi - fixed_cost - mortgage_tax
                                     ELSE origNoteRate + (origPMI / 100.0) - MtgRate - (llpa / 4.0) - pmi - fixed_cost - mortgage_tax END;
delete from #FNM_LoanIncentive where conv_incentive_fc is NULL;

-- Update Conventional Refinance Incentive CLTV50
UPDATE #FNM_LoanIncentive inc 
SET conv_incentive_cltv50 = CASE WHEN inc.marketTicker = 'FNCT' THEN origNoteRate + (origPMI / 100.0) - MtgRate - (llpa_cltv50 / 3.5) - pmi_cltv50 - mortgage_tax
                                ELSE origNoteRate + (origPMI / 100.0) - MtgRate - (llpa_cltv50 / 4.0) - pmi_cltv50 - mortgage_tax END;
DELETE from #FNM_LoanIncentive where conv_incentive_cltv50 is NULL;

UPDATE #FNM_LoanIncentive inc 
SET conv_incentive_fc_cltv50 = CASE WHEN inc.marketTicker = 'FNCT' THEN origNoteRate + (origPMI / 100.0) - MtgRate - (llpa_cltv50 / 3.5) - pmi_cltv50 - fixed_cost - mortgage_tax
                                     ELSE origNoteRate + (origPMI / 100.0) - MtgRate - (llpa_cltv50 / 4.0) - pmi_cltv50 - fixed_cost - mortgage_tax END;
delete from #FNM_LoanIncentive where conv_incentive_fc_cltv50 is NULL;

-- Update FHA Refinance Incentive
UPDATE #FNM_LoanIncentive inc SET fha_incentive = origNoteRate + (origPMI / 100.0) - MtgRate_GNMA - mip - mortgage_tax;
UPDATE #FNM_LoanIncentive inc SET fha_incentive = 0 WHERE fha_incentive is NULL;

UPDATE #FNM_LoanIncentive inc SET fha_incentive_fc = origNoteRate + (origPMI / 100.0) - MtgRate_GNMA - mip - fixed_cost - mortgage_tax;
UPDATE #FNM_LoanIncentive inc SET fha_incentive_fc = 0 WHERE fha_incentive_fc is NULL;

-- Update FHA Refinance Incentive CLTV50
UPDATE #FNM_LoanIncentive inc SET fha_incentive_cltv50 = origNoteRate + (origPMI / 100.0) - MtgRate_GNMA - mip_cltv50 - mortgage_tax;
UPDATE #FNM_LoanIncentive inc SET fha_incentive_cltv50 = 0 WHERE fha_incentive_cltv50 is NULL;

UPDATE #FNM_LoanIncentive inc SET fha_incentive_fc_cltv50 = origNoteRate + (origPMI / 100.0) - MtgRate_GNMA - mip_cltv50 - fixed_cost - mortgage_tax;
UPDATE #FNM_LoanIncentive inc SET fha_incentive_fc_cltv50 = 0 WHERE fha_incentive_fc_cltv50 is NULL;

-- Ignore the conventional to FHA incentive for 15/20 year loans
UPDATE #FNM_LoanIncentive inc SET fha_incentive = NULL WHERE inc.marketTicker in ('FNCI', 'FNCT');
UPDATE #FNM_LoanIncentive inc SET fha_incentive_fc = NULL WHERE inc.marketTicker in ('FNCI', 'FNCT');

-- Ignore the conventional to FHA incentive CLTV50 for 15/20 year loans
UPDATE #FNM_LoanIncentive inc SET fha_incentive = NULL WHERE inc.marketTicker in ('FNCI', 'FNCT');
UPDATE #FNM_LoanIncentive inc SET fha_incentive_fc = NULL WHERE inc.marketTicker in ('FNCI', 'FNCT');

-- Update Refinance Incentive
UPDATE #FNM_LoanIncentive inc 
SET refi_incentive = CASE WHEN fha_incentive IS NULL THEN conv_incentive
                        ELSE CASE WHEN conv_incentive >= fha_incentive THEN conv_incentive ELSE fha_incentive END END;
						
UPDATE #FNM_LoanIncentive inc 
SET refi_incentive_fc = CASE WHEN fha_incentive_fc IS NULL THEN conv_incentive_fc
                        ELSE CASE WHEN conv_incentive_fc >= fha_incentive_fc THEN conv_incentive_fc ELSE fha_incentive_fc END END;

-- Update Refinance Incentive CLTV50
UPDATE #FNM_LoanIncentive inc 
SET refi_incentive_cltv50 = CASE WHEN fha_incentive_cltv50 IS NULL THEN conv_incentive_cltv50
                        ELSE CASE WHEN conv_incentive_cltv50 >= fha_incentive_cltv50 THEN conv_incentive_cltv50 ELSE fha_incentive_cltv50 END END;
						
UPDATE #FNM_LoanIncentive inc 
SET refi_incentive_fc_cltv50 = CASE WHEN fha_incentive_fc_cltv50 IS NULL THEN conv_incentive_fc_cltv50
                        ELSE CASE WHEN conv_incentive_fc_cltv50 >= fha_incentive_fc_cltv50 THEN conv_incentive_fc_cltv50 ELSE fha_incentive_fc_cltv50 END END;
-- Update Refinance Incentive for Eligible Loans
UPDATE #FNM_LoanIncentive inc SET refi_incentive_eligible = CASE 
        WHEN HARP_eligible = 0 AND conventional_eligible = 0 AND fha_eligible = 0 THEN NULL
        WHEN HARP_eligible = 0 AND conventional_eligible = 0 AND fha_eligible = 1 THEN fha_incentive
        WHEN (HARP_eligible = 1 OR conventional_eligible = 1) AND fha_eligible = 0 THEN conv_incentive
        WHEN (HARP_eligible = 1 OR conventional_eligible = 1) AND fha_eligible = 1 THEN refi_incentive
        ELSE NULL 
    END;
COMMIT;

UPDATE #FNM_LoanIncentive inc SET refi_incentive_eligible_fc = CASE 
        WHEN HARP_eligible = 0 AND conventional_eligible = 0 AND fha_eligible = 0 THEN NULL
        WHEN HARP_eligible = 0 AND conventional_eligible = 0 AND fha_eligible = 1 THEN fha_incentive_fc
        WHEN (HARP_eligible = 1 OR conventional_eligible = 1) AND fha_eligible = 0 THEN conv_incentive_fc
        WHEN (HARP_eligible = 1 OR conventional_eligible = 1) AND fha_eligible = 1 THEN refi_incentive_fc
        ELSE NULL 
    END;
COMMIT;



-- Tests

--SELECT l.marketTicker, sl.originationDate, count(1), sum(balance), sum(balance * conv_incentive) / sum(CASE WHEN conv_incentive IS NULL THEN 0.0 ELSE balance END) as wavg_conv_incentive FROM #FNM_LoanIncentive l JOIN #FNM_LoanHist lh ON l.loanSeqNum = lh.loanSeqNum AND l.asOf = lh.asOf JOIN scale.FNM_Loan sl ON sl.loanSeqNum = lh.loanSeqNum GROUP BY l.marketTicker, sl.originationDate ORDER BY sl.originationDate

--SELECT l.marketTicker, l.asOf, count(1), sum(balance), sum(balance * conv_incentive*100) / sum(CASE WHEN conv_incentive IS NULL THEN 0.0 ELSE balance END) as wavg_conv_incentive_dev FROM #FNM_LoanIncentive l GROUP BY l.marketTicker, l.asOf ORDER BY l.asOf
--SELECT l.marketTicker, l.asOf, count(1), sum(balance), sum(balance * lh.conventional_refi_incentive) / sum(CASE WHEN conv_incentive IS NULL THEN 0.0 ELSE balance END) as wavg_conv_incentive_prod FROM #FNM_LoanIncentive l JOIN scale.FNM_LoanIncentive lh ON l.loanSeqNum = lh.loanSeqNum AND l.asOf = lh.asOf AND lh.version='2.41' GROUP BY l.marketTicker, l.asOf ORDER BY l.asOf

--SELECT l.marketTicker, sl.originationDate, count(1), sum(balance), sum(balance * fha_incentive) / sum(CASE WHEN fha_incentive IS NULL THEN 0.0 ELSE balance END) as wavg_fha_incentive FROM #FNM_LoanIncentive l JOIN #FNM_LoanHist lh ON l.loanSeqNum = lh.loanSeqNum AND l.asOf = lh.asOf JOIN scale.FNM_Loan sl ON sl.loanSeqNum = lh.loanSeqNum GROUP BY l.marketTicker, sl.originationDate ORDER BY sl.originationDate
--SELECT l.marketTicker, l.asOf, count(1), sum(balance), sum(balance * fha_incentive) / sum(CASE WHEN fha_incentive IS NULL THEN 0.0 ELSE balance END) as wavg_fha_incentive FROM #FNM_LoanIncentive l JOIN #FNM_LoanHist lh ON l.loanSeqNum = lh.loanSeqNum AND l.asOf = lh.asOf GROUP BY l.marketTicker, l.asOf ORDER BY l.asOf

--SELECT l.marketTicker, sl.originationDate, count(1), sum(balance), sum(balance * refi_incentive_eligible) / sum(CASE WHEN refi_incentive_eligible IS NULL THEN 0.0 ELSE balance END) as wavg_refi_incentive_eligible FROM #FNM_LoanIncentive l JOIN #FNM_LoanHist lh ON l.loanSeqNum = lh.loanSeqNum AND l.asOf = lh.asOf JOIN scale.FNM_Loan sl ON sl.loanSeqNum = lh.loanSeqNum GROUP BY l.marketTicker, sl.originationDate ORDER BY sl.originationDate
--SELECT l.marketTicker, l.asOf, count(1), sum(balance), sum(balance * refi_incentive_eligible) / sum(CASE WHEN refi_incentive_eligible IS NULL THEN 0.0 ELSE balance END) as wavg_refi_incentive_eligible FROM #FNM_LoanIncentive l JOIN #FNM_LoanHist lh ON l.loanSeqNum = lh.loanSeqNum AND l.asOf = lh.asOf GROUP BY l.marketTicker, l.asOf ORDER BY l.asOf

--SELECT l.marketTicker, sl.originationDate, count(1), sum(balance), sum(balance * llpa) / sum(CASE WHEN llpa IS NULL THEN 0.0 ELSE balance END) as wavg_llpa FROM #FNM_LoanIncentive l JOIN #FNM_LoanHist lh ON l.loanSeqNum = lh.loanSeqNum AND l.asOf = lh.asOf JOIN scale.FNM_Loan sl ON sl.loanSeqNum = lh.loanSeqNum GROUP BY l.marketTicker, sl.originationDate ORDER BY sl.originationDate
--SELECT l.marketTicker, l.asOf, count(1), sum(balance), sum(balance * llpa) / sum(CASE WHEN llpa IS NULL THEN 0.0 ELSE balance END) as wavg_llpa FROM #FNM_LoanIncentive l JOIN #FNM_LoanHist lh ON l.loanSeqNum = lh.loanSeqNum AND l.asOf = lh.asOf GROUP BY l.marketTicker, l.asOf ORDER BY l.asOf

--SELECT l.marketTicker, sl.originationDate, count(1), sum(balance), sum(balance * pmi) / sum(CASE WHEN pmi IS NULL THEN 0.0 ELSE balance END) as wavg_pmi FROM #FNM_LoanIncentive l JOIN #FNM_LoanHist lh ON l.loanSeqNum = lh.loanSeqNum AND l.asOf = lh.asOf JOIN scale.FNM_Loan sl ON sl.loanSeqNum = lh.loanSeqNum GROUP BY l.marketTicker, sl.originationDate ORDER BY sl.originationDate
--SELECT l.marketTicker, l.asOf, count(1), sum(balance), sum(balance * pmi) / sum(CASE WHEN pmi IS NULL THEN 0.0 ELSE balance END) as wavg_pmi FROM #FNM_LoanIncentive l JOIN #FNM_LoanHist lh ON l.loanSeqNum = lh.loanSeqNum AND l.asOf = lh.asOf GROUP BY l.marketTicker, l.asOf ORDER BY l.asOf

--SELECT l.marketTicker, sl.originationDate, count(1), sum(balance), sum(balance * mip) / sum(CASE WHEN mip IS NULL THEN 0.0 ELSE balance END) as wavg_mip FROM #FNM_LoanIncentive l JOIN #FNM_LoanHist lh ON l.loanSeqNum = lh.loanSeqNum AND l.asOf = lh.asOf JOIN scale.FNM_Loan sl ON sl.loanSeqNum = lh.loanSeqNum GROUP BY l.marketTicker, sl.originationDate ORDER BY sl.originationDate
--SELECT l.marketTicker, l.asOf, count(1), sum(balance), sum(balance * mip) / sum(CASE WHEN mip IS NULL THEN 0.0 ELSE balance END) as wavg_mip FROM #FNM_LoanIncentive l JOIN #FNM_LoanHist lh ON l.loanSeqNum = lh.loanSeqNum AND l.asOf = lh.asOf GROUP BY l.marketTicker, l.asOf ORDER BY l.asOf

----------------------------------------------------------------------------------------------
-- Check to see if Loans have conv_incentive populated
----------------------------------------------------------------------------------------------
        declare   @cnt int
        SELECT
            @cnt =  count(1)
        FROM #FNM_LoanIncentive WHERE conv_incentive IS NULL

        if (@cnt > 0)
        BEGIN
            RAISERROR 99999 'Number of FNM Loans with NULL Value for conventional incentive: %1!', @cnt
            RETURN
        END
----------------------------------------------------------------------------------------------
-- Check to see if Loans have fha_incentive populated
----------------------------------------------------------------------------------------------
--       SELECT
--          @cnt =  count(1)
--       FROM #FNM_LoanIncentive WHERE fha_incentive IS NULL

--       if (@cnt > 0)
--       BEGIN
--           RAISERROR 99999 'Number of FNM Loans with NULL Value for fha incentive: %1!', @cnt
--           RETURN
--       END
----------------------------------------------------------------------------------------------
-- Check to see if Loans have llpa populated
----------------------------------------------------------------------------------------------
        SELECT
            @cnt =  count(1)
        FROM #FNM_LoanIncentive WHERE llpa IS NULL

        if (@cnt > 0)
        BEGIN
            RAISERROR 99999 'Number of FNM Loans with NULL Value for llpa: %1!', @cnt
            RETURN
        END
----------------------------------------------------------------------------------------------
-- Check to see if Loans have pmi populated
----------------------------------------------------------------------------------------------
        SELECT
            @cnt =  count(1)
        FROM #FNM_LoanIncentive WHERE pmi IS NULL

        if (@cnt > 0)
        BEGIN
            RAISERROR 99999 'Number of FNM Loans with NULL Value for pmi: %1!', @cnt
            RETURN
        END
----------------------------------------------------------------------------------------------
-- Check to see if Loans have mip populated
----------------------------------------------------------------------------------------------
--       SELECT
--            @cnt =  count(1)
--       FROM #FNM_LoanIncentive WHERE mip IS NULL

--       if (@cnt > 0)
--       BEGIN
--           RAISERROR 99999 'Number of FNM Loans with NULL Value for mip: %1!', @cnt
--           RETURN
--       END
----------------------------------------------------------------------------------------------
-- Check to see if conv_incentive is in valid range
----------------------------------------------------------------------------------------------
        SELECT
            @cnt =  count(1)
        FROM
            #FNM_LoanIncentive
        WHERE
            conv_incentive < -20.0 OR conv_incentive > 20.0

        if (@cnt > 0)
        BEGIN
            RAISERROR 99999 'Number of FNM Loans with INVALID Value for conventional incentive: %1!', @cnt
            RETURN
        END
----------------------------------------------------------------------------------------------
-- Check to see if fha_incentive is in valid range
----------------------------------------------------------------------------------------------
        SELECT
            @cnt =  count(1)
        FROM
            #FNM_LoanIncentive
        WHERE
            fha_incentive < -20.0 OR fha_incentive > 20.0

        if (@cnt > 0)
        BEGIN
            RAISERROR 99999 'Number of FNM Loans with INVALID Value for fha incentive: %1!', @cnt
            RETURN
        END
----------------------------------------------------------------------------------------------
-- Check to see if llpa is in valid range
----------------------------------------------------------------------------------------------
        SELECT
            @cnt =  count(1)
        FROM
            #FNM_LoanIncentive
        WHERE
            llpa < -1 OR llpa > 20.0

        if (@cnt > 0)
        BEGIN
            RAISERROR 99999 'Number of FNM Loans with INVALID Value for llpa: %1!', @cnt
            RETURN
        END
----------------------------------------------------------------------------------------------
-- Check to see if pmi is in valid range
----------------------------------------------------------------------------------------------
        SELECT
            @cnt =  count(1)
        FROM
            #FNM_LoanIncentive
        WHERE
            pmi < 0 OR pmi > 10.0

        if (@cnt > 0)
        BEGIN
            RAISERROR 99999 'Number of FNM Loans with INVALID Value for pmi: %1!', @cnt
            RETURN
        END
----------------------------------------------------------------------------------------------
-- Check to see if mip is in valid range
----------------------------------------------------------------------------------------------
        SELECT
            @cnt =  count(1)
        FROM
            #FNM_LoanIncentive
        WHERE
            mip < 0 OR mip > 5.0

        if (@cnt > 0)
        BEGIN
            RAISERROR 99999 'Number of FNM Loans with INVALID Value for mip: %1!', @cnt
            RETURN
        END

		
----------------------------------------------------------------------------------------------
-- Check to see if new loans are loaded into database (need to be commented unless load new data)
----------------------------------------------------------------------------------------------
--   declare @count_previous int
--	 SELECT @count_previous = count(distinct(loanSeqNum))
--   FROM scale.FNM_LoanIncentive
--	 WHERE version IN (SELECT incentiveVersion FROM #tmp_version)

--	 declare @count_current int
--	 SELECT @count_current = count(distinct(loanSeqNum))
--	 FROM #FNM_LoanIncentive
	 
--	 if (@count_current - @count_previous <= 0 )
--        BEGIN
--           RAISERROR 99999 'There is no new loan loading into database for incentive table. Previous loan count: %1!; Current loan count: %2!', @count_previous, @count_current
--           RETURN
 --      END 

-- End Tests



-- Load Data into Scale Incentive Table
DELETE FROM scale.FNM_LoanIncentive sli
FROM  scale.FNM_LoanIncentive sli, #FNM_LoanIncentive li
WHERE 1=1
    AND sli.loanSeqNum = li.loanSeqNum
    AND sli.asOf = li.asOf
    AND li.marketTicker IN (SELECT tickerName FROM #ticker)
    AND sli.asOf >= (select asOf_start from #tmp_asOf)
	AND sli.asOf <= (select asOf_last from #tmp_asOf)
    AND version in (select incentiveVersion from #tmp_version)
;
COMMIT;

INSERT INTO scale.FNM_LoanIncentive (
	loanSeqNum, 
	asOf, 
	version, 
	conventional_refi_incentive, 
	fha_refi_incentive, 
	refi_incentive_eligible,
	conventional_refi_incentive_fixed_cost, 
	fha_refi_incentive_fixed_cost, 
	refi_incentive_eligible_fixed_cost, 
	currLLPA, 
	currPMI, 
	currMIP,
	fixed_cost)
SELECT
    loanSeqNum,
    asOf,
    incentiveVersion AS version,
    conv_incentive * 100.0,
    fha_incentive * 100.0,
    refi_incentive_eligible * 100.0,
	conv_incentive_fc * 100.0,
    fha_incentive_fc * 100.0,
    refi_incentive_eligible_fc * 100.0,
    llpa * 100.0,
    pmi * 100.0,
    mip * 100.0,
	fixed_cost * 100.0
FROM #FNM_LoanIncentive
WHERE marketTicker IN (SELECT tickerName FROM #ticker)
    AND asOf >= (select asOf_start from #tmp_asOf)
	AND asOf <= (select asOf_last from #tmp_asOf)
;
COMMIT;

-- Load Data into Scale Incentive Table CLTV50
DELETE FROM scale.FNM_LoanIncentive_cltv50 sli
FROM  scale.FNM_LoanIncentive_cltv50 sli, #FNM_LoanIncentive li
WHERE 1=1
    AND sli.loanSeqNum = li.loanSeqNum
    AND sli.asOf = li.asOf
    AND li.marketTicker IN (SELECT tickerName FROM #ticker)
    AND sli.asOf >= (select asOf_start from #tmp_asOf)
	AND sli.asOf <= (select asOf_last from #tmp_asOf)
    AND version in (select incentiveVersion from #tmp_version)
;


INSERT INTO scale.FNM_LoanIncentive_cltv50 (
	loanSeqNum, 
	asOf, 
	version, 
	conventional_refi_incentive, 
	fha_refi_incentive,
	conventional_refi_incentive_fixed_cost, 
	fha_refi_incentive_fixed_cost, 
	currLLPA, 
	currPMI, 
	currMIP,
	fixed_cost)
SELECT
    loanSeqNum,
    asOf,
    incentiveVersion AS version,
    conv_incentive_cltv50 * 100.0,
    fha_incentive_cltv50 * 100.0,
    conv_incentive_fc_cltv50 * 100.0,
    fha_incentive_fc_cltv50 * 100.0,
    llpa_cltv50 * 100.0,
    pmi_cltv50 * 100.0,
    mip_cltv50 * 100.0,
	fixed_cost * 100.0
FROM #FNM_LoanIncentive
WHERE marketTicker IN (SELECT tickerName FROM #ticker)
    AND asOf >= (select asOf_start from #tmp_asOf)
	AND asOf <= (select asOf_last from #tmp_asOf)
;
COMMIT;