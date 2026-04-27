-- Ginnie
-- Loan Level
-- Part 5 of 6
-- Script to update the refinance incentive metric
-- Updates refi_incentive, currLLPA and currPMI

-- Before execute the script, need to set the dates to run for
DROP TABLE IF EXISTS #tmp_asOf;
SELECT CAST('#####ASOF#####' AS DATE) asOf, CAST('#####LAST#####' AS DATE) asOf_last INTO #tmp_asOf
--SELECT CAST ('2018-03-01' AS DATE) asOf INTO #tmp_asOf
;

-- Before execute the script, need to set the appType to run for
DROP TABLE IF EXISTS #tmp_appType;
SELECT '#####APPTYPE#####' AS appType INTO #tmp_appType
--SELECT '4.50' AS appType INTO #tmp_appType
;

-- Before execute the script, need to set the tickers
DROP TABLE IF EXISTS #ticker;
CREATE TABLE #ticker(
    tickerName varchar(20),
    mtgRateSeries varchar(30)
)
;
INSERT #ticker SELECT 'GNSF', 'GINNIE_30YR';   --Ginnie
INSERT #ticker SELECT 'G2SF', 'GINNIE_30YR';   --Ginnie
INSERT #ticker SELECT 'G2SF-JM', 'GINNIE_30YR';-- Ginnie Jumbo
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
    AND asOf_lag2 >= (select asOf from #tmp_asOf)
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
DROP TABLE IF EXISTS #GNM_LoanIncentive;
SELECT
    cl.loanSeqNum,
    cl.loanType,
    cl.marketTicker,
    slh.asOf,
	cl.originalLoanAmount,
	slh.currentBalance,
    slh.schamBalance as balance,
    sl.originationDate,
    cl.numUnits as numberUnits,
    sl.origFICO,
    sl.origNoteRate,
	tk.mtgRateSeries,
    CASE WHEN cl.origTerm IS NULL THEN datediff(month, sl.originationDate, cl.matDt) ELSE cl.origTerm END as origTerm,
    'OWNER' as occupancyStatus,
    cl.loanPurposeType,
    sl.origMIP,
    slh.cltv,
    CAST(50 as numeric(7,2)) as cltv_fake,
	sl.origLTV,
	cast(NULL as numeric(6, 2)) as conventional_eligible,
--    sle.conventional_eligible,
--    mr.MtgRate,
--    mr_conv.MtgRate as MtgRate_Conv,
	cast(NULL as double) as MtgRate,
	cast(NULL as double) as MtgRate_Conv,
	tpv.incentiveVersion AS version,

    cast(NULL as numeric(4, 1)) as pmi_base,
    cast(NULL as numeric(4, 1)) as pmi_occ,
    cast(NULL as numeric(4, 1)) as pmi_size,
    
    cast(NULL as numeric(4, 1)) as pmi_base_cltv50,
    cast(NULL as numeric(4, 1)) as pmi_occ_cltv50,
    cast(NULL as numeric(4, 1)) as pmi_size_cltv50,

    cast(NULL as numeric(4, 1)) as llpa_base,
    cast(NULL as numeric(4, 1)) as llpa_admc,
    cast(NULL as numeric(4, 1)) as llpa_occ,
    cast(NULL as numeric(4, 1)) as llpa_unit,
    cast(NULL as numeric(4, 1)) as llpa_ltv,
    cast(NULL as numeric(4, 1)) as llpa_loansize,
    
    cast(NULL as numeric(4, 1)) as llpa_base_cltv50,
    cast(NULL as numeric(4, 1)) as llpa_occ_cltv50,
    cast(NULL as numeric(4, 1)) as llpa_unit_cltv50,
    cast(NULL as numeric(4, 1)) as llpa_ltv_cltv50,
    cast(NULL as numeric(4, 1)) as llpa_loansize_cltv50,

    cast(NULL as numeric(6, 3)) as pmi,
    cast(NULL as numeric(6, 3)) as llpa,
    cast(NULL as numeric(7, 4)) as mip,
    cast(NULL as numeric(7, 4)) as fixed_cost,
    
    cast(NULL as numeric(6, 3)) as pmi_cltv50,
    cast(NULL as numeric(6, 3)) as llpa_cltv50,
    cast(NULL as numeric(7, 4)) as mip_cltv50,

    cast(NULL as numeric(7, 4)) as conv_incentive,
    cast(NULL as numeric(7, 4)) as fha_incentive,
    cast(NULL as numeric(7, 4)) as refi_incentive,
    cast(NULL as numeric(7, 4)) as refi_incentive_eligible,
    
    cast(NULL as numeric(7, 4)) as conv_incentive_cltv50,
    cast(NULL as numeric(7, 4)) as fha_incentive_cltv50,
    cast(NULL as numeric(7, 4)) as refi_incentive_cltv50,

    cast(NULL as numeric(7, 4)) as conv_incentive_fc,
    cast(NULL as numeric(7, 4)) as fha_incentive_fc,
    cast(NULL as numeric(7, 4)) as refi_incentive_fc,
    cast(NULL as numeric(7, 4)) as refi_incentive_eligible_fc,
    
    cast(NULL as numeric(7, 4)) as conv_incentive_fc_cltv50,
    cast(NULL as numeric(7, 4)) as fha_incentive_fc_cltv50,
    cast(NULL as numeric(7, 4)) as refi_incentive_fc_cltv50
INTO #GNM_LoanIncentive
FROM gnm.PIV_Loan cl
JOIN #ticker tk
    ON cl.marketTicker = tk.tickerName
JOIN #tmp_version tpv
    ON cl.marketTicker = tpv.tickerName
JOIN scale.GNM_Loan_dev sl
    ON cl.loanSeqNum = sl.loanSeqNum
JOIN scale.GNM_LoanHist slh
    ON sl.loanSeqNum = slh.loanSeqNum
--JOIN scale.GNM_LoanEligibility sle
--    ON slh.loanSeqNum = sle.loanSeqNum
--    AND slh.asOf = sle.asOf
--JOIN #Mtg30YrRates_monthly_refi mr
--    ON mr.asOf = slh.asOf
--    AND mr.SeriesName = tk.mtgRateSeries
--JOIN #Mtg30YrRates_monthly_refi mr_conv
--    ON mr_conv.asOf = mr.asOf
--    AND mr_conv.SeriesName = 'CONVENTIONAL_30YR'
WHERE 1=1
    AND slh.asOf >= (select asOf from #tmp_asOf)
	AND slh.asOf <= (select asOf_last from #tmp_asOf)
	AND sl.version in (select  originationVersion from #tmp_version)
;
COMMIT;

CREATE HG INDEX loan_id_idx ON #GNM_LoanIncentive(loanSeqNum);
CREATE LF INDEX asof_date_idx ON #GNM_LoanIncentive(asOf);
CREATE LF INDEX ticker_idx ON #GNM_LoanIncentive(marketTicker);
CREATE LF INDEX origination_date_idx ON #GNM_LoanIncentive(originationDate);
CREATE LF INDEX occ_idx ON #GNM_LoanIncentive(occupancyStatus);
CREATE LF INDEX units_idx ON #GNM_LoanIncentive(numberUnits);
CREATE LF INDEX fico_idx ON #GNM_LoanIncentive(origFICO);
COMMIT;

--Mortgage Rate Interpolation Factor
DROP TABLE IF EXISTS #Mortgage_Interpolation_Factor;
SELECT 
inc.loanSeqNum,
inc.asOf,
CASE
    WHEN inc.currentBalance <= cll.LoanSize_limit THEN CAST(0 as float)
    WHEN inc.currentBalance > (cll.LoanSize_limit + 25000) THEN CAST(1 as float)
    ELSE cast(((inc.currentBalance - cll.LoanSize_limit)/25000) as float)
END as InterPolation_Factor
INTO #Mortgage_Interpolation_Factor
FROM #GNM_LoanIncentive inc,report.conforming_loansize_limit cll
where inc.asOf > cll.startDate
AND inc.asOf < cll.endDate;
COMMIT;

--Update Mortgage Rate
UPDATE #GNM_LoanIncentive inc
SET MtgRate_Conv = (1-InterPolation_Factor)*mr1.MtgRate + InterPolation_Factor * mr2.MtgRate
FROM #Mtg30YrRates_monthly_refi mr1
INNER JOIN #Mortgage_Interpolation_Factor mif
    ON mif.asOf = mr1.asOf
    AND mr1.SeriesName = 'CONVENTIONAL_30YR'
INNER JOIN #Mtg30YrRates_monthly_refi mr2
    ON mif.asOf = mr2.asOf
    AND mr2.SeriesName = 'JUMBO_30YR'
WHERE inc.loanSeqNum = mif.loanSeqNum
AND inc.asOf = mif.asOf;
COMMIT;

UPDATE #GNM_LoanIncentive inc
SET MtgRate_Conv = mr_conv.MtgRate
FROM #Mtg30YrRates_monthly_refi mr_conv
    WHERE mr_conv.asOf = inc.asOf
    AND mr_conv.SeriesName = 'CONVENTIONAL_30YR'
	AND inc.MtgRate_Conv is NULL
;
COMMIT;

UPDATE #GNM_LoanIncentive inc
SET MtgRate = mr.MtgRate
FROM #Mtg30YrRates_monthly_refi mr
   WHERE mr.asOf = inc.asOf
   AND mr.SeriesName = inc.mtgRateSeries
;
COMMIT;

-- Update Eligibility
UPDATE #GNM_LoanIncentive inc
SET conventional_eligible = sle.conventional_eligible
FROM scale.GNM_LoanEligibility sle
    WHERE inc.loanSeqNum = sle.loanSeqNum
         AND inc.asOf = sle.asOf
;
COMMIT;

-- Update pmi_base
UPDATE #GNM_LoanIncentive inc 
SET inc.pmi_base = (PMI_LL_FL * (LTV_H - CLTV) * (FICO_H - origFICO) + PMI_LH_FL * (CLTV - LTV_L) * (FICO_H - origFICO) 
      + PMI_LL_FH * (LTV_H - CLTV) * (origFICO - FICO_L) + PMI_LH_FH * (CLTV - LTV_L) * (origFICO - FICO_L)
      ) / ((LTV_H - LTV_L) * (FICO_H - FICO_L)) 
FROM report.PIV_PMI_Base_Bilinear_Interpolation pmi
WHERE 1=1
    AND LoanPurpose = 'REFI'
    AND inc.asOf >= pmi.startDate and inc.asOf < pmi.endDate 
    AND CLTV > pmi.LTV_L AND CLTV <= pmi.LTV_H 
    AND origFICO > pmi.FICO_L AND origFICO <= pmi.FICO_H
;
UPDATE #GNM_LoanIncentive inc SET inc.pmi_base = 0 WHERE inc.pmi_base IS NULL;

-- Update pmi_base_cltv50
UPDATE #GNM_LoanIncentive inc 
SET inc.pmi_base_cltv50 = (PMI_LL_FL * (LTV_H - CLTV_fake) * (FICO_H - origFICO) + PMI_LH_FL * (CLTV_fake - LTV_L) * (FICO_H - origFICO) 
      + PMI_LL_FH * (LTV_H - CLTV_fake) * (origFICO - FICO_L) + PMI_LH_FH * (CLTV_fake - LTV_L) * (origFICO - FICO_L)
      ) / ((LTV_H - LTV_L) * (FICO_H - FICO_L)) 
FROM report.PIV_PMI_Base_Bilinear_Interpolation pmi
WHERE 1=1
    AND LoanPurpose = 'REFI'
    AND inc.asOf >= pmi.startDate and inc.asOf < pmi.endDate 
    AND CLTV_fake > pmi.LTV_L AND CLTV_fake <= pmi.LTV_H 
    AND origFICO > pmi.FICO_L AND origFICO <= pmi.FICO_H
;
UPDATE #GNM_LoanIncentive inc SET inc.pmi_base_cltv50 = 0 WHERE inc.pmi_base_cltv50 IS NULL;

-- Update pmi_occ
UPDATE #GNM_LoanIncentive inc 
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
UPDATE #GNM_LoanIncentive inc SET inc.pmi_occ = 0 WHERE inc.pmi_occ IS NULL;

-- Update pmi_occ_cltv50
UPDATE #GNM_LoanIncentive inc 
SET inc.pmi_occ_cltv50 = (PMI_LL_FL * (LTV_H - CLTV_fake) * (FICO_H - origFICO) + PMI_LH_FL * (CLTV_fake - LTV_L) * (FICO_H - origFICO) 
      + PMI_LL_FH * (LTV_H - CLTV_fake) * (origFICO - FICO_L) + PMI_LH_FH * (CLTV_fake - LTV_L) * (origFICO - FICO_L)
      ) / ((LTV_H - LTV_L) * (FICO_H - FICO_L)) 
FROM report.PIV_PMI_Occupancy_Bilinear_Interpolation pmi
WHERE 1=1
    AND inc.occupancyStatus = pmi.OccType
    AND inc.asOf >= pmi.startDate and inc.asOf < pmi.endDate 
    AND CLTV_fake > pmi.LTV_L AND CLTV_fake <= pmi.LTV_H 
    AND origFICO > pmi.FICO_L AND origFICO <= pmi.FICO_H
;
UPDATE #GNM_LoanIncentive inc SET inc.pmi_occ_cltv50 = 0 WHERE inc.pmi_occ_cltv50 IS NULL;

-- Update pmi_size
UPDATE #GNM_LoanIncentive inc 
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
UPDATE #GNM_LoanIncentive inc 
SET inc.pmi_size = (balance - LoanSize_L) / (LoanSize_H - LoanSize_L) * (inc.pmi_size - 0.0)
FROM report.PIV_PMI_LoanSize_Bilinear_Interpolation_25k pmi
WHERE 1=1
    AND inc.balance > pmi.LoanSize_L and inc.balance <= LoanSize_H
    AND inc.asOf >= pmi.startDate and inc.asOf < pmi.endDate 
    AND CLTV > pmi.LTV_L AND CLTV <= pmi.LTV_H 
    AND origFICO > pmi.FICO_L AND origFICO <= pmi.FICO_H
    AND needExtraInterp = 1
;
UPDATE #GNM_LoanIncentive inc SET inc.pmi_size = 0 WHERE inc.pmi_size IS NULL;

-- Update pmi_size_cltv50
UPDATE #GNM_LoanIncentive inc 
SET inc.pmi_size_cltv50 = (PMI_LL_FL * (LTV_H - CLTV_fake) * (FICO_H - origFICO) + PMI_LH_FL * (CLTV_fake - LTV_L) * (FICO_H - origFICO) 
      + PMI_LL_FH * (LTV_H - CLTV_fake) * (origFICO - FICO_L) + PMI_LH_FH * (CLTV_fake - LTV_L) * (origFICO - FICO_L)
      ) / ((LTV_H - LTV_L) * (FICO_H - FICO_L)) 
FROM report.PIV_PMI_LoanSize_Bilinear_Interpolation_25k pmi
WHERE 1=1
    AND inc.balance > pmi.LoanSize_L and inc.balance <= LoanSize_H
    AND inc.asOf >= pmi.startDate and inc.asOf < pmi.endDate 
    AND CLTV_fake > pmi.LTV_L AND CLTV_fake <= pmi.LTV_H 
    AND origFICO > pmi.FICO_L AND origFICO <= pmi.FICO_H
;
-- Update pmi_size_cltv50: step 2. linear interpolation for loan size after step 1
UPDATE #GNM_LoanIncentive inc 
SET inc.pmi_size_cltv50 = (balance - LoanSize_L) / (LoanSize_H - LoanSize_L) * (inc.pmi_size_cltv50 - 0.0)
FROM report.PIV_PMI_LoanSize_Bilinear_Interpolation_25k pmi
WHERE 1=1
    AND inc.balance > pmi.LoanSize_L and inc.balance <= LoanSize_H
    AND inc.asOf >= pmi.startDate and inc.asOf < pmi.endDate 
    AND CLTV_fake > pmi.LTV_L AND CLTV_fake <= pmi.LTV_H 
    AND origFICO > pmi.FICO_L AND origFICO <= pmi.FICO_H
    AND needExtraInterp = 1
;
UPDATE #GNM_LoanIncentive inc SET inc.pmi_size_cltv50 = 0 WHERE inc.pmi_size_cltv50 IS NULL;

-- Update Base LLPA
UPDATE #GNM_LoanIncentive inc 
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
UPDATE #GNM_LoanIncentive inc SET inc.llpa_base = 0 WHERE inc.llpa_base IS NULL;

-- Update Base LLPA CLTV50
UPDATE #GNM_LoanIncentive inc 
SET inc.llpa_base_cltv50 = (LLPA_LL_FL * (LTV_H - CLTV_fake) * (FICO_H - origFICO) + LLPA_LH_FL * (CLTV_fake - LTV_L) * (FICO_H - origFICO) 
      + LLPA_LL_FH * (LTV_H - CLTV_fake) * (origFICO - FICO_L) + LLPA_LH_FH * (CLTV_fake - LTV_L) * (origFICO - FICO_L)
      ) / ((LTV_H - LTV_L) * (FICO_H - FICO_L)) 
FROM report.PIV_LLPA_Base_Bilinear_Interpolation llpa
WHERE 1=1
    AND CLTV_fake > llpa.LTV_L 
    AND CLTV_fake <= llpa.LTV_H 
    AND origFICO > llpa.FICO_L 
    AND origFICO <= llpa.FICO_H
    AND inc.asOf >= llpa.startDate and inc.asOf < llpa.endDate 
;
UPDATE #GNM_LoanIncentive inc SET inc.llpa_base_cltv50 = 0 WHERE inc.llpa_base_cltv50 IS NULL;

-- Update ADMC LLPA
UPDATE #GNM_LoanIncentive inc SET inc.llpa_admc = llpa.LLPA
FROM report.PIV_LLPA_ADMC llpa
WHERE 1=1
    AND inc.asOf >= llpa.startDate and inc.asOf < llpa.endDate 
;
UPDATE #GNM_LoanIncentive inc SET inc.llpa_admc = 0 WHERE inc.llpa_admc IS NULL;

-- Update Occupancy LLPA
UPDATE #GNM_LoanIncentive inc 
SET inc.llpa_occ = (CLTV - LTV_L) / (LTV_H - LTV_L) * (LLPA_LH - LLPA_LL) + LLPA_LL
FROM report.PIV_LLPA_Occupancy_Linear_Interpolation llpa
WHERE 1=1
    AND inc.occupancyStatus = llpa.OccType
    AND inc.asOf >= llpa.startDate AND inc.asOf < llpa.endDate 
    AND inc.CLTV > llpa.LTV_L AND inc.CLTV <= llpa.LTV_H 
;
UPDATE #GNM_LoanIncentive inc SET inc.llpa_occ = 0 WHERE inc.llpa_occ IS NULL;

-- Update Occupancy LLPA CLTV50
UPDATE #GNM_LoanIncentive inc 
SET inc.llpa_occ_cltv50 = (CLTV_fake - LTV_L) / (LTV_H - LTV_L) * (LLPA_LH - LLPA_LL) + LLPA_LL
FROM report.PIV_LLPA_Occupancy_Linear_Interpolation llpa
WHERE 1=1
    AND inc.occupancyStatus = llpa.OccType
    AND inc.asOf >= llpa.startDate AND inc.asOf < llpa.endDate 
    AND inc.CLTV_fake > llpa.LTV_L AND inc.CLTV_fake <= llpa.LTV_H 
;
UPDATE #GNM_LoanIncentive inc SET inc.llpa_occ_cltv50 = 0 WHERE inc.llpa_occ_cltv50 IS NULL;

-- Update Units LLPA
UPDATE #GNM_LoanIncentive inc 
SET inc.llpa_unit = (CLTV - LTV_L) / (LTV_H - LTV_L) * (LLPA_LH - LLPA_LL) + LLPA_LL
FROM report.PIV_LLPA_Units_Linear_Interpolation llpa
WHERE 1=1
    AND inc.numberUnits >= llpa.numUnitsStart AND inc.numberUnits < llpa.numUnitsEnd
    AND inc.asOf >= llpa.startDate AND inc.asOf < llpa.endDate 
    AND inc.CLTV > llpa.LTV_L AND inc.CLTV <= llpa.LTV_H 
;
UPDATE #GNM_LoanIncentive inc SET inc.llpa_unit = 0 WHERE inc.llpa_unit IS NULL;

-- Update Units LLPA CLTV50
UPDATE #GNM_LoanIncentive inc 
SET inc.llpa_unit_cltv50 = (CLTV_fake - LTV_L) / (LTV_H - LTV_L) * (LLPA_LH - LLPA_LL) + LLPA_LL
FROM report.PIV_LLPA_Units_Linear_Interpolation llpa
WHERE 1=1
    AND inc.numberUnits >= llpa.numUnitsStart AND inc.numberUnits < llpa.numUnitsEnd
    AND inc.asOf >= llpa.startDate AND inc.asOf < llpa.endDate 
    AND inc.CLTV_fake > llpa.LTV_L AND inc.CLTV_fake <= llpa.LTV_H 
;
UPDATE #GNM_LoanIncentive inc SET inc.llpa_unit_cltv50 = 0 WHERE inc.llpa_unit_cltv50 IS NULL;

-- Update LTV LLPA
UPDATE #GNM_LoanIncentive inc SET inc.llpa_ltv = llpa.LLPA
FROM report.PIV_LLPA_LTV llpa
WHERE 1=1
    AND inc.asOf >= llpa.startDate and inc.asOf < llpa.endDate 
    AND inc.cltv > llpa.LTVBucketStart and inc.cltv <= llpa.LTVBucketEnd
;
UPDATE #GNM_LoanIncentive inc SET inc.llpa_ltv = 0 WHERE inc.llpa_ltv IS NULL;

-- Update LTV LLPA CLTV50
UPDATE #GNM_LoanIncentive inc SET inc.llpa_ltv_cltv50 = llpa.LLPA
FROM report.PIV_LLPA_LTV llpa
WHERE 1=1
    AND inc.asOf >= llpa.startDate and inc.asOf < llpa.endDate 
    AND inc.cltv_fake > llpa.LTVBucketStart and inc.cltv_fake <= llpa.LTVBucketEnd
;
UPDATE #GNM_LoanIncentive inc SET inc.llpa_ltv_cltv50 = 0 WHERE inc.llpa_ltv_cltv50 IS NULL;

-- Update LLPA Loan Size
UPDATE #GNM_LoanIncentive inc 
SET inc.llpa_loansize = (balance - LoanSize_L) / (LoanSize_H - LoanSize_L) * (LLPA_LH - LLPA_LL) + LLPA_LL
FROM report.PIV_LLPA_LoanSize_Interpolation_25k llpa
WHERE 1=1
    AND inc.asOf >= llpa.startDate and inc.asOf < llpa.endDate 
    AND inc.balance > llpa.LoanSize_L and inc.balance <= llpa.LoanSize_H
    AND inc.cltv > llpa.LTVBucketStart and inc.cltv <= llpa.LTVBucketEnd
;
UPDATE #GNM_LoanIncentive inc SET inc.llpa_loansize = 0 WHERE inc.llpa_loansize IS NULL;

-- Update LLPA Loan Size CLTV50
UPDATE #GNM_LoanIncentive inc 
SET inc.llpa_loansize_cltv50 = (balance - LoanSize_L) / (LoanSize_H - LoanSize_L) * (LLPA_LH - LLPA_LL) + LLPA_LL
FROM report.PIV_LLPA_LoanSize_Interpolation_25k llpa
WHERE 1=1
    AND inc.asOf >= llpa.startDate and inc.asOf < llpa.endDate 
    AND inc.balance > llpa.LoanSize_L and inc.balance <= llpa.LoanSize_H
    AND inc.cltv_fake > llpa.LTVBucketStart and inc.cltv_fake <= llpa.LTVBucketEnd
;
UPDATE #GNM_LoanIncentive inc SET inc.llpa_loansize_cltv50 = 0 WHERE inc.llpa_loansize_cltv50 IS NULL;

-- Update Base MIP
UPDATE #GNM_LoanIncentive inc 
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
    --AND inc.mip IS NULL
;
COMMIT;

-- Update Base MIP CLTV50
UPDATE #GNM_LoanIncentive inc 
SET inc.mip_cltv50 = (AnnualMIPPoints_LL_SL * (LTV_H - CLTV_fake) * (LoanSize_H - balance) + AnnualMIPPoints_LH_SL * (CLTV_fake - LTV_L) * (LoanSize_H - balance) 
                + AnnualMIPPoints_LL_SH * (LTV_H - CLTV_fake) * (balance - LoanSize_L) + AnnualMIPPoints_LH_SH * (CLTV_fake - LTV_L) * (balance - LoanSize_L)
                ) / ((LTV_H - LTV_L) * (LoanSize_H - LoanSize_L))
            + mip_base.UpfrontMIPPoints / 12.0
FROM report.PIV_MIP_Base_Bilinear_Interpolation_25k mip_base
WHERE 1=1
    AND inc.origTerm             >  mip_base.TermBucketStart
	AND inc.origTerm             <= mip_base.TermBucketEnd
	AND inc.CLTV_fake                 >  mip_base.LTV_L
	AND inc.CLTV_fake                 <= mip_base.LTV_H
	AND inc.balance              >= mip_base.LoanSize_L
	AND inc.balance              <= mip_base.LoanSize_H
    AND inc.originationDate      >  mip_base.OriginationStartDate
	AND inc.originationDate      <= mip_base.OriginationEndDate
	AND inc.asOf                 >  mip_base.StartDate
	AND inc.asOf                 <= mip_base.EndDate
    --AND inc.mip_cltv50 IS NULL
;
COMMIT;

-- Update PMI and LLPA Incentive
UPDATE #GNM_LoanIncentive inc SET
pmi = (pmi_base + pmi_occ + pmi_size) / 100.0,
llpa = (llpa_base + llpa_admc + llpa_occ + llpa_unit + llpa_ltv + llpa_loansize) / 100.0,
mip = (CASE WHEN loanType = 'FHA' THEN mip ELSE 0.0 END) / 100.0
;

-- Update PMI and LLPA Incentive CLTV50
UPDATE #GNM_LoanIncentive inc SET
pmi_cltv50 = (pmi_base_cltv50 + pmi_occ_cltv50 + pmi_size_cltv50) / 100.0,
llpa_cltv50 = (llpa_base_cltv50 + llpa_admc + llpa_occ_cltv50 + llpa_unit_cltv50 + llpa_ltv_cltv50 + llpa_loansize_cltv50) / 100.0,
mip_cltv50 = (CASE WHEN loanType = 'FHA' THEN mip_cltv50 ELSE 0.0 END) / 100.0
;

--Update fixed cost adjustment
UPDATE #GNM_LoanIncentive inc 
SET inc.fixed_cost=CASE WHEN currentBalance <= 40000 THEN 1.0
									 ELSE (2000.0/currentBalance)*20.0 END;
COMMIT;

--origMIP cancellation
DROP TABLE IF EXISTS #GNM_MIP_Cancellation;
Select
loanSeqNum,
asOf,
originationDate,
origLTV,
cast(((currentBalance * origLTV)/originalLoanAmount) as numeric(7,4)) as amortLTV,
CASE
    WHEN originationDate <= '2013-08-01' Then 'Old'
	ELSE 'New'
END as Rule,
CASE
    WHEN Rule = 'Old' THEN CASE
	    WHEN origLTV <= 78 THEN Dateadd(year,5,originationDate)
		ELSE NULL
	END
	ELSE CASE
	    WHEN origLTV <= 90 THEN Dateadd(year,11,originationDate)
		ELSE NULL
	END
END as Cancellation_Date,
origMIP
INTO #GNM_MIP_Cancellation
FROM #GNM_LoanIncentive;
COMMIT;

DROP TABLE IF EXISTS #GNM_MIP_OLD;
SELECT
loanSeqNum,
origLTV,
cast(NULL as numeric(14,2)) as originalLoanAmount,
cast(NULL as numeric(12,2)) as balance_threshold,
originationDate,
cast(NULL as Date) as LoanHist_Date,
Cancellation_Date
INTO #GNM_MIP_OLD
FROM #GNM_MIP_Cancellation
where Rule = 'Old'
AND amortLTV <= 78
AND origLTV > 78
group by loanSeqNum,origLTV,originationDate,Cancellation_Date;
COMMIT;

UPDATE #GNM_MIP_OLD gm
SET originalLoanAmount =cl.originalLoanAmount
FROM GNM.PIV_Loan cl
WHERE gm.loanSeqNum = cl.loanSeqNum;
COMMIT;

UPDATE #GNM_MIP_OLD gm
SET balance_threshold = (78 * originalLoanAmount / origLTV);
COMMIT;

UPDATE #GNM_MIP_OLD gm
SET LoanHist_Date = x.LoanHist_Date
FROM 
(Select lh.loanSeqNum, Dateadd(month,1,max(asOf)) as LoanHist_Date from #GNM_MIP_OLD gm INNER JOIN scale.GNM_LoanHist lh ON gm.loanSeqNum = lh.loanSeqNum  where gm.balance_threshold < lh.currentBalance group by lh.loanSeqNum) x
WHERE gm.loanSeqNum = x.loanSeqNum;
COMMIT;

UPDATE #GNM_MIP_OLD gm
SET Cancellation_Date = CASE
    WHEN LoanHist_Date > Dateadd(year,5,originationDate) THEN LoanHist_Date
	ELSE Dateadd(year,5,originationDate)
END;
COMMIT;

UPDATE #GNM_MIP_Cancellation
SET Cancellation_Date = x.Cancellation_Date
FROM #GNM_MIP_OLD x
INNER JOIN #GNM_MIP_Cancellation y
on x.loanSeqNum = y.loanSeqNum;
COMMIT;

UPDATE #GNM_MIP_Cancellation
SET origMIP = 0
WHERE Cancellation_Date is not NULL
AND asof > Cancellation_Date;
COMMIT;

DELETE scale.GNM_MIP_Cancellation
FROM scale.GNM_MIP_Cancellation gmc
INNER JOIN #GNM_MIP_Cancellation t
ON gmc.loanSeqNum = t.loanSeqNum
AND gmc.asOf = t.asOf;
COMMIT;

INSERT INTO scale.GNM_MIP_Cancellation
SELECT * FROM #GNM_MIP_Cancellation;
COMMIT;

UPDATE #GNM_LoanIncentive
SET origMIP = y.origMIP
FROM #GNM_LoanIncentive x
INNER JOIN scale.GNM_MIP_Cancellation y
ON x.loanSeqNum = y.loanSeqNum
AND x.asOf = y.asOf
COMMIT;

-- Update Conventional Refinance Incentive
UPDATE #GNM_LoanIncentive inc SET conv_incentive = origNoteRate + (origMIP / 100.0) - MtgRate_Conv - (llpa / 4.0) - pmi;
UPDATE #GNM_LoanIncentive inc SET conv_incentive_fc = origNoteRate + (origMIP / 100.0) - MtgRate_Conv - (llpa / 4.0) - pmi - fixed_cost;

-- Update Conventional Refinance Incentive CLTV50
UPDATE #GNM_LoanIncentive inc SET conv_incentive_cltv50 = origNoteRate + (origMIP / 100.0) - MtgRate_Conv - (llpa_cltv50 / 4.0) - pmi_cltv50;
UPDATE #GNM_LoanIncentive inc SET conv_incentive_fc_cltv50 = origNoteRate + (origMIP / 100.0) - MtgRate_Conv - (llpa_cltv50 / 4.0) - pmi_cltv50 - fixed_cost;

-- Update FHA Refinance Incentive
UPDATE #GNM_LoanIncentive inc SET fha_incentive = origNoteRate + (origMIP / 100.0) - MtgRate - mip WHERE loanType = 'FHA';
UPDATE #GNM_LoanIncentive inc SET fha_incentive_fc = origNoteRate + (origMIP / 100.0) - MtgRate - mip - fixed_cost WHERE loanType = 'FHA';

-- Update FHA Refinance Incentive CLTV50
UPDATE #GNM_LoanIncentive inc SET fha_incentive_cltv50 = origNoteRate + (origMIP / 100.0) - MtgRate - mip_cltv50 WHERE loanType = 'FHA';
UPDATE #GNM_LoanIncentive inc SET fha_incentive_fc_cltv50 = origNoteRate + (origMIP / 100.0) - MtgRate - mip_cltv50 - fixed_cost WHERE loanType = 'FHA';

-- Update FHA Refinance Incentive for Non FHA
UPDATE #GNM_LoanIncentive inc SET fha_incentive = origNoteRate - MtgRate WHERE loanType != 'FHA';
UPDATE #GNM_LoanIncentive inc SET fha_incentive_fc = origNoteRate - MtgRate - fixed_cost WHERE loanType != 'FHA';

-- Update FHA Refinance Incentive CLTV50 for Non FHA
UPDATE #GNM_LoanIncentive inc SET fha_incentive_cltv50 = origNoteRate - MtgRate WHERE loanType != 'FHA';
UPDATE #GNM_LoanIncentive inc SET fha_incentive_fc_cltv50 = origNoteRate - MtgRate - fixed_cost WHERE loanType != 'FHA';

-- Update Refinance Incentive
UPDATE #GNM_LoanIncentive inc SET
    refi_incentive = CASE WHEN conv_incentive >= fha_incentive THEN conv_incentive ELSE fha_incentive END
UPDATE #GNM_LoanIncentive inc SET
    refi_incentive_fc = CASE WHEN conv_incentive_fc >= fha_incentive_fc THEN conv_incentive_fc ELSE fha_incentive_fc END
COMMIT;

-- Update Refinance Incentive CLTV50
UPDATE #GNM_LoanIncentive inc SET
    refi_incentive_cltv50 = CASE WHEN conv_incentive_cltv50 >= fha_incentive_cltv50 THEN conv_incentive_cltv50 ELSE fha_incentive_cltv50 END
UPDATE #GNM_LoanIncentive inc SET
    refi_incentive_fc_cltv50 = CASE WHEN conv_incentive_fc_cltv50 >= fha_incentive_fc_cltv50 THEN conv_incentive_fc_cltv50 ELSE fha_incentive_fc_cltv50 END
COMMIT;

-- Update Refinance Incentive for Eligible Loans
UPDATE #GNM_LoanIncentive inc SET
    refi_incentive_eligible = CASE 
        WHEN conventional_eligible = 0 THEN fha_incentive
        ELSE 
            CASE WHEN conv_incentive >= fha_incentive THEN conv_incentive ELSE fha_incentive END
        END;

UPDATE #GNM_LoanIncentive inc SET
    refi_incentive_eligible_fc = CASE 
        WHEN conventional_eligible = 0 THEN fha_incentive_fc
        ELSE 
            CASE WHEN conv_incentive_fc >= fha_incentive_fc THEN conv_incentive_fc ELSE fha_incentive_fc END
        END;
COMMIT;


-- Tests

--SELECT marketTicker, originationDate, count(1), sum(balance), sum(balance * conv_incentive) / sum(CASE WHEN conv_incentive IS NULL THEN 0.0 ELSE balance END) as wavg_conv_incentive FROM #GNM_LoanIncentive GROUP BY marketTicker, originationDate ORDER BY originationDate
--SELECT marketTicker, asOf, count(1), sum(balance), sum(balance * conv_incentive) / sum(CASE WHEN conv_incentive IS NULL THEN 0.0 ELSE balance END) as wavg_conv_incentive FROM #GNM_LoanIncentive GROUP BY marketTicker, asOf ORDER BY asOf

--SELECT marketTicker, originationDate, count(1), sum(balance), sum(balance * fha_incentive) / sum(CASE WHEN fha_incentive IS NULL THEN 0.0 ELSE balance END) as wavg_fha_incentive FROM #GNM_LoanIncentive GROUP BY marketTicker, originationDate ORDER BY originationDate
--SELECT marketTicker, asOf, count(1), sum(balance), sum(balance * fha_incentive) / sum(CASE WHEN fha_incentive IS NULL THEN 0.0 ELSE balance END) as wavg_fha_incentive FROM #GNM_LoanIncentive GROUP BY marketTicker, asOf ORDER BY asOf

--SELECT marketTicker, originationDate, count(1), sum(balance), sum(balance * refi_incentive_eligible) / sum(CASE WHEN refi_incentive_eligible IS NULL THEN 0.0 ELSE balance END) as wavg_refi_elig_incentive FROM #GNM_LoanIncentive GROUP BY marketTicker, originationDate ORDER BY originationDate
--SELECT marketTicker, asOf, count(1), sum(balance), sum(balance * refi_incentive_eligible) / sum(CASE WHEN refi_incentive_eligible IS NULL THEN 0.0 ELSE balance END) as wavg_refi_elig_incentive FROM #GNM_LoanIncentive GROUP BY marketTicker, asOf ORDER BY asOf

--SELECT marketTicker, originationDate, count(1), sum(balance), sum(balance * llpa) / sum(CASE WHEN llpa IS NULL THEN 0.0 ELSE balance END) as wavg_llpa FROM #GNM_LoanIncentive GROUP BY marketTicker, originationDate ORDER BY originationDate
--SELECT marketTicker, asOf, count(1), sum(balance), sum(balance * llpa) / sum(CASE WHEN llpa IS NULL THEN 0.0 ELSE balance END) as wavg_llpa FROM #GNM_LoanIncentive GROUP BY marketTicker, asOf ORDER BY asOf

--SELECT marketTicker, originationDate, count(1), sum(balance), sum(balance * pmi) / sum(CASE WHEN pmi IS NULL THEN 0.0 ELSE balance END) as wavg_pmi FROM #GNM_LoanIncentive GROUP BY marketTicker, originationDate ORDER BY originationDate
--SELECT marketTicker, asOf, count(1), sum(balance), sum(balance * pmi) / sum(CASE WHEN pmi IS NULL THEN 0.0 ELSE balance END) as wavg_pmi FROM #GNM_LoanIncentive GROUP BY marketTicker, asOf ORDER BY asOf

--SELECT marketTicker, originationDate, count(1), sum(balance), sum(balance * mip) / sum(CASE WHEN mip IS NULL THEN 0.0 ELSE balance END) as wavg_mip FROM #GNM_LoanIncentive GROUP BY marketTicker, originationDate ORDER BY originationDate
--SELECT marketTicker, asOf, count(1), sum(balance), sum(balance * mip) / sum(CASE WHEN mip IS NULL THEN 0.0 ELSE balance END) as wavg_mip FROM #GNM_LoanIncentive GROUP BY marketTicker, asOf ORDER BY asOf


----------------------------------------------------------------------------------------------
-- Check to see if Loans have conv_incentive populated
----------------------------------------------------------------------------------------------
        declare   @cnt int
 --        SELECT
 --            @cnt =  count(1)
 --        FROM #GNM_LoanIncentive WHERE conv_incentive IS NULL

 --        if (@cnt > 0)
 --        BEGIN
 --            RAISERROR 99999 'Number of GNM Loans with NULL Value for conventional incentive : %1!', @cnt
 --            RETURN
 --        END
----------------------------------------------------------------------------------------------
-- Check to see if Loans have fha_incentive populated
----------------------------------------------------------------------------------------------
 --        SELECT
 --            @cnt =  count(1)
  --       FROM #GNM_LoanIncentive WHERE fha_incentive IS NULL

  --       if (@cnt > 0)
  --       BEGIN
   --          RAISERROR 99999 'Number of GNM Loans with NULL Value for fha incentive: %1!', @cnt
  --           RETURN
   --      END
----------------------------------------------------------------------------------------------
-- Check to see if Loans have refi_incentive_eligible populated
----------------------------------------------------------------------------------------------
  --       SELECT
   --          @cnt =  count(1)
   --      FROM #GNM_LoanIncentive WHERE refi_incentive_eligible IS NULL

 --        if (@cnt > 0)
  --       BEGIN
   --          RAISERROR 99999 'Number of GNM Loans with NULL Value for refinance incentive eligibility: %1!', @cnt
  --           RETURN
   --      END
----------------------------------------------------------------------------------------------
-- Check to see if Loans have llpa populated
----------------------------------------------------------------------------------------------
  --       SELECT
   --          @cnt =  count(1)
  --       FROM #GNM_LoanIncentive WHERE llpa IS NULL

 --        if (@cnt > 0)
  --       BEGIN
  --           RAISERROR 99999 'Number of GNM Loans with NULL Value for llpa: %1!', @cnt
   --          RETURN
   --      END
----------------------------------------------------------------------------------------------
-- Check to see if Loans have pmi populated
----------------------------------------------------------------------------------------------
   --      SELECT
    --         @cnt =  count(1)
    --     FROM #GNM_LoanIncentive WHERE pmi IS NULL

   --      if (@cnt > 0)
   --      BEGIN
   --          RAISERROR 99999 'Number of GNM Loans with NULL Value for pmi: %1!', @cnt
   --          RETURN
   --      END
----------------------------------------------------------------------------------------------
-- Check to see if Loans have mip populated
----------------------------------------------------------------------------------------------
    --     SELECT
    --         @cnt =  count(1)
    --     FROM #GNM_LoanIncentive WHERE mip IS NULL

    --     if (@cnt > 0)
    --     BEGIN
    --         RAISERROR 99999 'Number of GNM Loans with NULL Value for mip: %1!', @cnt
    --         RETURN
    --     END
----------------------------------------------------------------------------------------------
-- Check to see if conv_incentive is in valid range
----------------------------------------------------------------------------------------------
        SELECT
            @cnt =  count(1)
        FROM
            #GNM_LoanIncentive
        WHERE
            conv_incentive < -20.0 OR conv_incentive > 20.0

        if (@cnt > 0)
        BEGIN
            RAISERROR 99999 'Number of GNM Loans with INVALID Value for conventional incentive: %1!', @cnt
            RETURN
        END
----------------------------------------------------------------------------------------------
-- Check to see if fha_incentive is in valid range
----------------------------------------------------------------------------------------------
        SELECT
            @cnt =  count(1)
        FROM
            #GNM_LoanIncentive
        WHERE
            fha_incentive < -20.0 OR fha_incentive > 20.0

        if (@cnt > 0)
        BEGIN
            RAISERROR 99999 'Number of GNM Loans with INVALID Value for fha incentive: %1!', @cnt
            RETURN
        END
----------------------------------------------------------------------------------------------
-- Check to see if refi_incentive_eligible is in valid range
----------------------------------------------------------------------------------------------
        SELECT
            @cnt =  count(1)
        FROM
            #GNM_LoanIncentive
        WHERE
            refi_incentive_eligible < -20.0 OR refi_incentive_eligible > 20.0

        if (@cnt > 0)
        BEGIN
            RAISERROR 99999 'Number of GNM Loans with INVALID Value for refinance incentive eligibility: %1!', @cnt
            RETURN
        END
----------------------------------------------------------------------------------------------
-- Check to see if llpa is in valid range
----------------------------------------------------------------------------------------------
        SELECT
            @cnt =  count(1)
        FROM
            #GNM_LoanIncentive
        WHERE
            llpa < -1 OR llpa > 20.0

        if (@cnt > 0)
        BEGIN
            RAISERROR 99999 'Number of GNM Loans with INVALID Value for llpa: %1!', @cnt
            RETURN
        END
----------------------------------------------------------------------------------------------
-- Check to see if pmi is in valid range
----------------------------------------------------------------------------------------------
        SELECT
            @cnt =  count(1)
        FROM
            #GNM_LoanIncentive
        WHERE
            pmi < 0 OR pmi > 10.0

        if (@cnt > 0)
        BEGIN
            RAISERROR 99999 'Number of GNM Loans with INVALID Value for pmi: %1!', @cnt
            RETURN
        END
----------------------------------------------------------------------------------------------
-- Check to see if mip is in valid range
----------------------------------------------------------------------------------------------
        SELECT
            @cnt =  count(1)
        FROM
            #GNM_LoanIncentive
        WHERE
            mip < 0 OR mip > 5.0

        if (@cnt > 0)
        BEGIN
            RAISERROR 99999 'Number of GNM Loans with INVALID Value for mip: %1!', @cnt
            RETURN
        END


 ----------------------------------------------------------------------------------------------
-- Check to see if new loans are loaded into database (need to be commented unless load new data)
----------------------------------------------------------------------------------------------
--     declare @count_previous int
--	 SELECT @count_previous = count(distinct(loanSeqNum))
--	 FROM scale.GNM_LoanIncentive
--  WHERE version IN (SELECT incentiveVersion FROM #tmp_version)

--	 declare @count_current int
--	 SELECT @count_current = count(distinct(loanSeqNum))
--	 FROM #GNM_LoanIncentive
	 
--	 if (@count_current - @count_previous <= 0 )
--        BEGIN
--           RAISERROR 99999 'There is no new loan loading into database for incentive table. Previous loan count: %1!; Current loan count: %2!', @count_previous, @count_current
--           RETURN
 --      END 
 
 
 
-- End Tests





-- Load Data into Scale Incentive Table

DELETE FROM scale.GNM_LoanIncentive
FROM scale.GNM_LoanIncentive sli, #GNM_LoanIncentive li
WHERE 1=1
    AND sli.loanSeqNum = li.loanSeqNum
    AND sli.asOf = li.asOf
    AND li.marketTicker IN (SELECT tickerName FROM #ticker)
    AND sli.asOf >= (select asOf from #tmp_asOf)
	AND sli.asOf <= (select asOf_last from #tmp_asOf)
    AND sli.version in (select incentiveVersion from #tmp_version)
;

INSERT INTO scale.GNM_LoanIncentive (
	loanSeqNum, 
	asOf, 
	version, 
	conventional_refi_incentive, 
	fha_refi_incentive, 
	refi_incentive, 
	refi_incentive_eligible,
	conventional_refi_incentive_fixed_cost, 
	fha_refi_incentive_fixed_cost, 
	refi_incentive_eligible_fixed_cost, 
	currLLPA, 
	currPMI, 
	currMIP,
	fixed_cost,
	origMIP_Cancel)
SELECT
    loanSeqNum,
    asOf,
    version,
    conv_incentive * 100.0,
    fha_incentive * 100.0,
    refi_incentive * 100.0,
    refi_incentive_eligible * 100.0,
    conv_incentive_fc * 100.0,
    fha_incentive_fc * 100.0,
    refi_incentive_eligible_fc * 100.0,
    llpa * 100.0,
    pmi * 100.0,
    mip * 100.0,
    fixed_cost * 100.0,
	origMIP
FROM #GNM_LoanIncentive gli
WHERE gli.marketTicker IN (SELECT tickerName FROM #ticker)
    AND gli.asOf >= (select asOf from #tmp_asOf)
	AND gli.asOf <= (select asOf_last from #tmp_asOf)
;
COMMIT;

-- Load Data into Scale Incentive CLTV50 Table

DELETE FROM scale.GNM_LoanIncentive_CLTV50
FROM scale.GNM_LoanIncentive_CLTV50 sli, #GNM_LoanIncentive li
WHERE 1=1
    AND sli.loanSeqNum = li.loanSeqNum
    AND sli.asOf = li.asOf
    AND li.marketTicker IN (SELECT tickerName FROM #ticker)
    AND sli.asOf >= (select asOf from #tmp_asOf)
	AND sli.asOf <= (select asOf_last from #tmp_asOf)
    AND sli.version in (select incentiveVersion from #tmp_version)
;

INSERT INTO scale.GNM_LoanIncentive_CLTV50 (
	loanSeqNum, 
	asOf, 
	version, 
	conventional_refi_incentive, 
	fha_refi_incentive, 
	refi_incentive, 
	conventional_refi_incentive_fixed_cost, 
	fha_refi_incentive_fixed_cost,  
	currLLPA, 
	currPMI, 
	currMIP,
	fixed_cost,
	origMIP_Cancel)
SELECT
    loanSeqNum,
    asOf,
    version,
    conv_incentive_cltv50 * 100.0,
    fha_incentive_cltv50 * 100.0,
    refi_incentive_cltv50 * 100.0,
    conv_incentive_fc_cltv50 * 100.0,
    fha_incentive_fc_cltv50 * 100.0,
    llpa_cltv50 * 100.0,
    pmi_cltv50 * 100.0,
    mip_cltv50 * 100.0,
    fixed_cost * 100.0,
	origMIP
FROM #GNM_LoanIncentive gli
WHERE gli.marketTicker IN (SELECT tickerName FROM #ticker)
    AND gli.asOf >= (select asOf from #tmp_asOf)
	AND gli.asOf <= (select asOf_last from #tmp_asOf)
;
COMMIT;

declare @count_previous int
   
    SELECT @count_previous = count(distinct(loanSeqNum))
    FROM scale.GNM_LoanIncentive
	WHERE version IN (SELECT incentiveVersion FROM #tmp_version)
	
declare @count_current int
	 
	 SELECT @count_current = count(distinct(loanSeqNum))
	 FROM #GNM_LoanIncentive
COMMIT;