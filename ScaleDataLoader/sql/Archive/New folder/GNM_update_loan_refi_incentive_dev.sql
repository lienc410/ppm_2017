-- Ginnie
-- Loan Level
-- Part 5 of 6
-- Script to update the refinance incentive metric
-- Updates refi_incentive, currLLPA and currPMI

-- Before execute the script, need to set the dates to run for
DROP TABLE IF EXISTS #tmp_asOf;
SELECT CAST('#####ASOF#####' AS DATE) asOf INTO #tmp_asOf
--SELECT CAST ('2014-01-01' AS DATE) asOf INTO #tmp_asOf
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
INSERT #ticker SELECT 'GNSF', 'GINNIE_30YR';   --Ginnie
INSERT #ticker SELECT 'G2SF', 'GINNIE_30YR';   --Ginnie
INSERT #ticker SELECT 'G2SF-JM', 'GINNIE_30YR';-- Ginnie Jumbo
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
	AND ModelType = 'ScaleMtgRateModel v2.0'
;
COMMIT;

CREATE LF INDEX series_idx ON #Mtg30YrRates_monthly(SeriesName);
CREATE LF INDEX asOf_idx ON #Mtg30YrRates_monthly(asOf);
CREATE LF INDEX asOf_lag1_idx ON #Mtg30YrRates_monthly(asOf_lag1);
CREATE LF INDEX asOf_lag2_idx ON #Mtg30YrRates_monthly(asOf_lag2);

COMMIT;


-- Save Loan Data
DROP TABLE IF EXISTS #GNM_LoanIncentive;
SELECT
    cl.loanSeqNum,
    cl.loanType,
    cl.marketTicker,
    slh.asOf,
    slh.currentBalance as balance,
    sl.originationDate,
    cl.numUnits as numberUnits,
    sl.origFICO,
    sl.origNoteRate,
    CASE WHEN cl.origTerm IS NULL THEN datediff(month, sl.originationDate, cl.matDt) ELSE cl.origTerm END as origTerm,
    'OWNER' as occupancyStatus,
    cl.loanPurposeType,
    sl.origMIP,
    slh.cltv,
    sle.conventional_eligible,
    mr.MtgRate,
    mr_conv.MtgRate as MtgRate_Conv,

    cast(NULL as numeric(4, 1)) as pmi_base,
    cast(NULL as numeric(4, 1)) as pmi_occ,
    cast(NULL as numeric(4, 1)) as pmi_size,

    cast(NULL as numeric(4, 1)) as llpa_base,
    cast(NULL as numeric(4, 1)) as llpa_admc,
    cast(NULL as numeric(4, 1)) as llpa_occ,
    cast(NULL as numeric(4, 1)) as llpa_unit,
    cast(NULL as numeric(4, 1)) as llpa_ltv,
    cast(NULL as numeric(4, 1)) as llpa_loansize,

    cast(NULL as numeric(6, 3)) as pmi,
    cast(NULL as numeric(6, 3)) as llpa,
    cast(NULL as numeric(7, 4)) as mip,
    cast(NULL as numeric(7, 4)) as conv_incentive,
    cast(NULL as numeric(7, 4)) as fha_incentive,
    cast(NULL as numeric(7, 4)) as refi_incentive,
    cast(NULL as numeric(7, 4)) as refi_incentive_eligible
INTO #GNM_LoanIncentive
FROM gnm.sec p
JOIN #ticker tk
    ON p.marketTicker = tk.tickerName
JOIN gnm.PIV_Loan cl
    ON p.issueId = cl.issueId
JOIN scale.GNM_Loan_dev sl
    ON cl.loanSeqNum = sl.loanSeqNum
JOIN scale.GNM_LoanHist slh
    ON sl.loanSeqNum = slh.loanSeqNum
JOIN scale.GNM_LoanEligibility sle
    ON slh.loanSeqNum = sle.loanSeqNum
    AND slh.asOf = sle.asOf
JOIN #Mtg30YrRates_monthly mr
    ON mr.asOf_lag1 = slh.asOf
    AND mr.SeriesName = tk.mtgRateSeries
JOIN #Mtg30YrRates_monthly mr_conv
    ON mr_conv.asOf_lag1 = mr.asOf_lag1
    AND mr_conv.SeriesName = 'CONVENTIONAL_30YR'
WHERE 1=1
    AND p.collateralType = 'LOAN'
    AND slh.asOf >= (select asOf from #tmp_asOf)
	AND sl.version = (select  version from #tmp_version)
--    AND slh.asOf <= '2014-01-01'              --Data set is too large, need to run it seperately when populate the full history
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

-- Update pmi_size
UPDATE #GNM_LoanIncentive inc 
SET inc.pmi_size = (PMI_LL_FL * (LTV_H - CLTV) * (FICO_H - origFICO) + PMI_LH_FL * (CLTV - LTV_L) * (FICO_H - origFICO) 
      + PMI_LL_FH * (LTV_H - CLTV) * (origFICO - FICO_L) + PMI_LH_FH * (CLTV - LTV_L) * (origFICO - FICO_L)
      ) / ((LTV_H - LTV_L) * (FICO_H - FICO_L)) 
FROM report.PIV_PMI_LoanSize_Bilinear_Interpolation pmi
WHERE 1=1
    AND inc.balance > pmi.LoanSize_L and inc.balance <= LoanSize_H
    AND inc.asOf >= pmi.startDate and inc.asOf < pmi.endDate 
    AND CLTV > pmi.LTV_L AND CLTV <= pmi.LTV_H 
    AND origFICO > pmi.FICO_L AND origFICO <= pmi.FICO_H
;
-- Update pmi_size: step 2. linear interpolation for loan size after step 1
UPDATE #GNM_LoanIncentive inc 
SET inc.pmi_size = (balance - LoanSize_L) / (LoanSize_H - LoanSize_L) * (inc.pmi_size - 0.0)
FROM report.PIV_PMI_LoanSize_Bilinear_Interpolation pmi
WHERE 1=1
    AND inc.balance > pmi.LoanSize_L and inc.balance <= LoanSize_H
    AND inc.asOf >= pmi.startDate and inc.asOf < pmi.endDate 
    AND CLTV > pmi.LTV_L AND CLTV <= pmi.LTV_H 
    AND origFICO > pmi.FICO_L AND origFICO <= pmi.FICO_H
    AND needExtraInterp = 1
;
UPDATE #GNM_LoanIncentive inc SET inc.pmi_size = 0 WHERE inc.pmi_size IS NULL;

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
;
UPDATE #GNM_LoanIncentive inc SET inc.llpa_base = 0 WHERE inc.llpa_base IS NULL;

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

-- Update LTV LLPA
UPDATE #GNM_LoanIncentive inc SET inc.llpa_ltv = llpa.LLPA
FROM report.PIV_LLPA_LTV llpa
WHERE 1=1
    AND inc.asOf >= llpa.startDate and inc.asOf < llpa.endDate 
    AND inc.cltv > llpa.LTVBucketStart and inc.cltv <= llpa.LTVBucketEnd
;
UPDATE #GNM_LoanIncentive inc SET inc.llpa_ltv = 0 WHERE inc.llpa_ltv IS NULL;

-- Update Loan Size
UPDATE #GNM_LoanIncentive inc 
SET inc.llpa_loansize = (balance - LoanSize_L) / (LoanSize_H - LoanSize_L) * (LLPA_LH - LLPA_LL) + LLPA_LL
FROM report.PIV_LLPA_LoanSize_Interpolation llpa
WHERE 1=1
    AND inc.asOf >= llpa.startDate and inc.asOf < llpa.endDate 
    AND inc.balance > llpa.LoanSize_L and inc.balance <= llpa.LoanSize_H
    AND inc.cltv > llpa.LTVBucketStart and inc.cltv <= llpa.LTVBucketEnd
;
UPDATE #GNM_LoanIncentive inc SET inc.llpa_loansize = 0 WHERE inc.llpa_loansize IS NULL;

-- Update Base MIP
UPDATE #GNM_LoanIncentive inc 
SET inc.mip = (AnnualMIPPoints_LL_SL * (LTV_H - CLTV) * (LoanSize_H - balance) + AnnualMIPPoints_LH_SL * (CLTV - LTV_L) * (LoanSize_H - balance) 
                + AnnualMIPPoints_LL_SH * (LTV_H - CLTV) * (balance - LoanSize_L) + AnnualMIPPoints_LH_SH * (CLTV - LTV_L) * (balance - LoanSize_L)
                ) / ((LTV_H - LTV_L) * (LoanSize_H - LoanSize_L))
            + mip_base.UpfrontMIPPoints / 12.0
FROM report.PIV_MIP_Base_Bilinear_Interpolation mip_base
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

-- Update PMI and LLPA Incentive
UPDATE #GNM_LoanIncentive inc SET
pmi = (pmi_base + pmi_occ + pmi_size) / 100.0,
llpa = (llpa_base + llpa_admc + llpa_occ + llpa_unit + llpa_ltv + llpa_loansize) / 100.0,
mip = (CASE WHEN loanType = 'FHA' THEN mip ELSE 0.0 END) / 100.0
;

-- Update Conventional Refinance Incentive
UPDATE #GNM_LoanIncentive inc SET conv_incentive = origNoteRate + (origMIP / 100.0) - MtgRate_Conv - (llpa / 4.0) - pmi;

-- Update FHA Refinance Incentive
UPDATE #GNM_LoanIncentive inc SET fha_incentive = origNoteRate + (origMIP / 100.0) - MtgRate - mip WHERE loanType = 'FHA';

-- Update FHA Refinance Incentive for Non FHA
UPDATE #GNM_LoanIncentive inc SET fha_incentive = origNoteRate + (origMIP / 100.0) - MtgRate WHERE loanType != 'FHA';

-- Update Refinance Incentive
UPDATE #GNM_LoanIncentive inc SET
    refi_incentive = CASE WHEN conv_incentive >= fha_incentive THEN conv_incentive ELSE fha_incentive END
COMMIT;

-- Update Refinance Incentive for Eligible Loans
UPDATE #GNM_LoanIncentive inc SET
    refi_incentive_eligible = CASE 
        WHEN conventional_eligible = 0 THEN fha_incentive
        ELSE 
            CASE WHEN conv_incentive >= fha_incentive THEN conv_incentive ELSE fha_incentive END
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


------------------------------------------------------------------------------------------------
---- Check to see if Loans have conv_incentive populated
------------------------------------------------------------------------------------------------
--        declare   @cnt int
--        SELECT
--            @cnt =  count(1)
--        FROM #GNM_LoanIncentive WHERE conv_incentive IS NULL

--        if (@cnt > 0)
--        BEGIN
--            RAISERROR 99999 'GNM Loans with NULL conv_incentive LoanCount : %1!', @cnt
--            RETURN
--        END
------------------------------------------------------------------------------------------------
---- Check to see if Loans have fha_incentive populated
------------------------------------------------------------------------------------------------
--        SELECT
--            @cnt =  count(1)
--        FROM #GNM_LoanIncentive WHERE fha_incentive IS NULL

--        if (@cnt > 0)
--        BEGIN
--            RAISERROR 99999 'GNM Loans with NULL fha_incentive LoanCount : %1!', @cnt
--            RETURN
--        END
------------------------------------------------------------------------------------------------
---- Check to see if Loans have refi_incentive_eligible populated
------------------------------------------------------------------------------------------------
--        SELECT
--            @cnt =  count(1)
--        FROM #GNM_LoanIncentive WHERE refi_incentive_eligible IS NULL

--        if (@cnt > 0)
--        BEGIN
--            RAISERROR 99999 'GNM Loans with NULL refi_incentive_eligible LoanCount : %1!', @cnt
--            RETURN
--        END
------------------------------------------------------------------------------------------------
---- Check to see if Loans have llpa populated
------------------------------------------------------------------------------------------------
--        SELECT
--            @cnt =  count(1)
--        FROM #GNM_LoanIncentive WHERE llpa IS NULL

--        if (@cnt > 0)
--        BEGIN
--            RAISERROR 99999 'GNM Loans with NULL llpa LoanCount : %1!', @cnt
--            RETURN
--        END
------------------------------------------------------------------------------------------------
---- Check to see if Loans have pmi populated
------------------------------------------------------------------------------------------------
--        SELECT
--            @cnt =  count(1)
--        FROM #GNM_LoanIncentive WHERE pmi IS NULL

--        if (@cnt > 0)
--        BEGIN
--            RAISERROR 99999 'GNM Loans with NULL pmi LoanCount : %1!', @cnt
--            RETURN
--        END
------------------------------------------------------------------------------------------------
---- Check to see if Loans have mip populated
------------------------------------------------------------------------------------------------
--        SELECT
--            @cnt =  count(1)
--        FROM #GNM_LoanIncentive WHERE mip IS NULL

--        if (@cnt > 0)
--        BEGIN
--            RAISERROR 99999 'GNM Loans with NULL mip LoanCount : %1!', @cnt
--            RETURN
--        END
------------------------------------------------------------------------------------------------
---- Check to see if conv_incentive is in valid range
------------------------------------------------------------------------------------------------
--        SELECT
--            @cnt =  count(1)
--        FROM
--            #GNM_LoanIncentive
--        WHERE
--            conv_incentive < -20.0 OR conv_incentive > 20.0

--        if (@cnt > 0)
--        BEGIN
--            RAISERROR 99999 'GNM Loans with Invalid conv_incentive Range LoanCount : %1!', @cnt
--            RETURN
--        END
------------------------------------------------------------------------------------------------
---- Check to see if fha_incentive is in valid range
------------------------------------------------------------------------------------------------
--        SELECT
--            @cnt =  count(1)
--        FROM
--            #GNM_LoanIncentive
--        WHERE
--            fha_incentive < -20.0 OR fha_incentive > 20.0

--        if (@cnt > 0)
--        BEGIN
--            RAISERROR 99999 'GNM Loans with Invalid fha_incentive Range LoanCount : %1!', @cnt
--            RETURN
--        END
------------------------------------------------------------------------------------------------
---- Check to see if refi_incentive_eligible is in valid range
------------------------------------------------------------------------------------------------
--        SELECT
--            @cnt =  count(1)
--        FROM
--            #GNM_LoanIncentive
--        WHERE
--            refi_incentive_eligible < -20.0 OR refi_incentive_eligible > 20.0

--        if (@cnt > 0)
--        BEGIN
--            RAISERROR 99999 'GNM Loans with Invalid refi_incentive_eligible Range LoanCount : %1!', @cnt
--            RETURN
--        END
------------------------------------------------------------------------------------------------
---- Check to see if llpa is in valid range
------------------------------------------------------------------------------------------------
--        SELECT
--            @cnt =  count(1)
--        FROM
--            #GNM_LoanIncentive
--        WHERE
--            llpa < -1 OR llpa > 20.0

--        if (@cnt > 0)
--        BEGIN
--            RAISERROR 99999 'GNM Loans with Invalid llpa Range LoanCount : %1!', @cnt
--            RETURN
--        END
------------------------------------------------------------------------------------------------
---- Check to see if pmi is in valid range
------------------------------------------------------------------------------------------------
--        SELECT
--            @cnt =  count(1)
--        FROM
--            #GNM_LoanIncentive
--        WHERE
--            pmi < 0 OR pmi > 10.0

--        if (@cnt > 0)
--        BEGIN
--            RAISERROR 99999 'GNM Loans with Invalid pmi Range LoanCount : %1!', @cnt
--            RETURN
--        END
------------------------------------------------------------------------------------------------
---- Check to see if mip is in valid range
------------------------------------------------------------------------------------------------
--        SELECT
--            @cnt =  count(1)
--        FROM
--            #GNM_LoanIncentive
--        WHERE
--            mip < 0 OR mip > 5.0

--        if (@cnt > 0)
--        BEGIN
--            RAISERROR 99999 'GNM Loans with Invalid mip Range LoanCount : %1!', @cnt
--            RETURN
--        END
------------------------------------------------------------------------------------------------
---- Check to see if count of current month changes in a noticeable amount compare with previous month
------------------------------------------------------------------------------------------------
--        declare   @cnt_previous int
--        SELECT
--            @cnt =  count(1)
--        FROM #GNM_LoanIncentive WHERE asof = (SELECT asOf FROM #tmp_asOf)

--        SELECT
--            @cnt_previous =  count(1)
--        FROM scale.GNM_LoanIncentive WHERE asof = (SELECT dateadd(month, -1, asOf) FROM #tmp_asOf) AND version = (select  version from #tmp_version)
        
--        if (@cnt - @cnt_previous > 0.1 * @cnt_previous OR @cnt_previous - @cnt > 0.1 * @cnt_previous)
--        BEGIN
--            RAISERROR 99999 'GNM_LoanIncentive with INVALID COUNT compare with previous month. Current: %1!; Previous: %2!', @cnt, @cnt_previous
--            RETURN
--        END 
---- End Tests



-- Load Data into Scale Incentive Table
DELETE FROM scale.GNM_LoanIncentive
FROM scale.GNM_LoanIncentive sli, #GNM_LoanIncentive li
WHERE 1=1
    AND sli.loanSeqNum = li.loanSeqNum
    AND sli.asOf = li.asOf
    AND li.marketTicker IN (SELECT tickerName FROM #ticker)
    AND sli.asOf >= (select asOf from #tmp_asOf)
    AND version = (select  version from #tmp_version)
;

DECLARE @version varchar(5)
SELECT @version = (select * from #tmp_version)

INSERT INTO scale.GNM_LoanIncentive (loanSeqNum, asOf, version, conventional_refi_incentive, fha_refi_incentive, refi_incentive, refi_incentive_eligible, currLLPA, currPMI, currMIP)
SELECT
    loanSeqNum,
    asOf,
    @version,
    conv_incentive * 100.0,
    fha_incentive * 100.0,
    refi_incentive * 100.0,
    refi_incentive_eligible * 100.0,
    llpa * 100.0,
    pmi * 100.0,
    mip * 100.0
FROM #GNM_LoanIncentive
WHERE marketTicker IN (SELECT tickerName FROM #ticker)
    AND asOf >= (select asOf from #tmp_asOf)
;