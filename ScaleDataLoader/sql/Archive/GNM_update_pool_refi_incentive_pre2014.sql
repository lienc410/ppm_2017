-- Ginnie
-- Pool Level
-- Part 5 of 6
-- Script to update the refinance incentive metrics
-- Updates conventional_refi_incentive, fha_refi_incentive, refi_incentive, origPMI, currLLPA, currPMI and currMIP

-- Before execute the script, need to set the dates to run for
DROP TABLE IF EXISTS #tmp_asOf;
--SELECT CAST('#####ASOF#####' AS DATE) asOf INTO #tmp_asOf
SELECT CAST ('1994-01-01' AS DATE) asOf INTO #tmp_asOf
;

-- Before execute the script, need to set the version to run for
DROP TABLE IF EXISTS #tmp_version;
SELECT CAST ('2.42' AS varchar(5)) version INTO #tmp_version
;

-- Before execute the script, need to set the tickers
DROP TABLE IF EXISTS #ticker;
CREATE TABLE #ticker(
    tickerName varchar(20),
    mtgRateSeries varchar(30)
)
;
INSERT #ticker SELECT 'GNSF', 'GINNIE_30YR';   -- Ginnie 1
INSERT #ticker SELECT 'G2SF', 'GINNIE_30YR';   -- Ginnie 2
INSERT #ticker SELECT 'G2SF-JM', 'GINNIE_30YR';-- Ginnie Jumbo
COMMIT;

CREATE INDEX loan_tickerName_idx ON #ticker(tickerName);
COMMIT;

-- Differenciate incentive by loan type
DROP TABLE IF EXISTS #loanType;
CREATE TABLE #loanType(
    loanType varchar(12)
)
;
INSERT #loanType SELECT 'FHA'; 
INSERT #loanType SELECT 'VA';
INSERT #loanType SELECT 'RHS';
INSERT #loanType SELECT 'PIH';
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

CREATE INDEX series_idx ON #Mtg30YrRates_monthly(SeriesName);
CREATE INDEX asOf_idx ON #Mtg30YrRates_monthly(asOf);
CREATE INDEX asOf_lag1_idx ON #Mtg30YrRates_monthly(asOf_lag1);
CREATE INDEX asOf_lag2_idx ON #Mtg30YrRates_monthly(asOf_lag2);

COMMIT;


-- Create Pool Historical Data
DROP TABLE IF EXISTS #GNM_PoolIncentive;
SELECT
    ph.marketTicker,
    ph.issueId,
    lt.loanType as loanType,
    ph.asOf,
    ph.originationDate,
    ph.balance,
    ph.origNoteRate as wac, 
    ph.origLTV as waoltv,
    ph.currLoanSize as waclSize,
    ph.origLoanSize as waolSize,
    ph.origFICO as waocs,
    ph.cltv as waCLTV,
    pd.percentTYPE_FHA as pctFHA,
    x.originalTerm as origTerm,
    pe.conventional_eligible,
    mr.MtgRate,
    mr_conv.MtgRate as MtgRate_Conv,
    
    cast(0 as tinyint) as has_loan_data,
    
    cast(NULL as numeric(8, 4)) as pmi_end_base,
    cast(NULL as numeric(8, 4)) as pmi_end_loansize,
    cast(NULL as numeric(8, 4)) as pmi_end_occ,
    
    cast(NULL as numeric(8, 4)) as llpa_base,
    cast(NULL as numeric(8, 4)) as llpa_admc,
    cast(NULL as numeric(8, 4)) as llpa_occ,
    cast(NULL as numeric(8, 4)) as llpa_ltv,
    cast(NULL as numeric(8, 4)) as llpa_loansize,
    
    cast(NULL as numeric(8, 4)) as mip_begin,
    cast(NULL as numeric(8, 4)) as pmi,
    cast(NULL as numeric(8, 4)) as llpa,
    cast(NULL as numeric(8, 4)) as mip,
    
    cast(NULL as numeric(10, 4)) as conventional_refi_incentive,
    cast(NULL as numeric(10, 4)) as fha_refi_incentive,
    cast(NULL as numeric(10, 4)) as refi_incentive,
    cast(NULL as numeric(10, 4)) as refi_incentive_eligible
INTO #GNM_PoolIncentive
FROM scale.GNM_PoolHist ph
JOIN #ticker tk
    ON ph.marketTicker = tk.tickerName
JOIN gnm.sec p
    ON ph.issueId = p.issueId
JOIN gnm.Prefix x
    ON p.prefix = x.prefix
    AND p.product = x.product
JOIN scale.GNM_PoolDistribution pd
    ON ph.issueId = pd.issueId
    AND ph.asOf = pd.asOf
JOIN scale.GNM_PoolEligibility pe
    ON ph.issueId = pe.issueId
    AND ph.asOf = pe.asOf
JOIN #Mtg30YrRates_monthly mr
    ON mr.asOf_lag1 = ph.asOf
    AND mr.SeriesName = tk.mtgRateSeries
JOIN #Mtg30YrRates_monthly mr_conv
    ON mr_conv.asOf_lag1 = mr.asOf_lag1
    AND mr_conv.SeriesName = 'CONVENTIONAL_30YR'
RIGHT JOIN #loanType lt ON 1=1
WHERE 1=1
    AND ph.asOf >= (select asOf from #tmp_asOf)
--and ph.issueId = 3003056
--and ph.asof ='19940201'
;
COMMIT;

CREATE INDEX issueId_idx ON #GNM_PoolIncentive(issueId);
CREATE INDEX asOf_idx ON #GNM_PoolIncentive(asOf);
COMMIT;

------------------------------------------------------------
-- Compute all metrics using Pool Data
------------------------------------------------------------
DROP TABLE IF EXISTS #GNM_PoolBasedIncentive;
SELECT * 
INTO #GNM_PoolBasedIncentive
FROM #GNM_PoolIncentive
WHERE 1=1
    AND conventional_refi_incentive IS NULL
;
COMMIT;

-- Update mip_begin
UPDATE #GNM_PoolBasedIncentive inc SET inc.mip_begin = mip_base.AnnualMIPPoints + mip_base.UpfrontMIPPoints / 12.0
FROM report.PIV_MIP_Base mip_base
WHERE 1=1
    AND inc.origTerm           >  mip_base.TermBucketStart
	AND inc.origTerm           <= mip_base.TermBucketEnd
	AND inc.waoltv             >  mip_base.LTVBucketStart
	AND inc.waoltv             <= mip_base.LTVBucketEnd
	AND inc.waolSize           >= mip_base.LoanSizeBucketStart
	AND inc.waolSize           <= mip_base.LoanSizeBucketEnd
    AND inc.originationDate    >  mip_base.OriginationStartDate
	AND inc.originationDate    <= mip_base.OriginationEndDate
	AND inc.originationDate    >  mip_base.StartDate
	AND inc.originationDate    <= mip_base.EndDate
;
UPDATE #GNM_PoolBasedIncentive inc SET inc.mip_begin = 0.0 WHERE inc.mip_begin IS NULL;

-- Adjust mip_begin for Non-FHA
UPDATE #GNM_PoolBasedIncentive inc SET inc.mip_begin = 0.0
WHERE loanType NOT IN ('FHA')
COMMIT;
select * from #GNM_PoolBasedIncentive
-- Update pmi_end_base
UPDATE #GNM_PoolBasedIncentive inc SET inc.pmi_end_base = pmi.PMI
FROM report.PIV_PMI_Base pmi
WHERE 1=1
    AND LoanPurpose = 'REFI'
    AND inc.asOf >= pmi.startDate and inc.asOf < pmi.endDate 
    AND inc.waocs >= pmi.FICObucketStart and inc.waocs < pmi.FICObucketEnd
    AND inc.waCLTV > pmi.LTVBucketStart and inc.waCLTV <= pmi.LTVBucketEnd
;

UPDATE #GNM_PoolBasedIncentive inc SET inc.pmi_end_base = pmi.PMI
FROM report.PIV_PMI_Base pmi
WHERE 1=1
    AND LoanPurpose = 'REFI'
    AND inc.asOf >= pmi.startDate and inc.asOf < pmi.endDate 
    AND 700 >= pmi.FICObucketStart and 700 < pmi.FICObucketEnd
    AND inc.waCLTV > pmi.LTVBucketStart and inc.waCLTV <= pmi.LTVBucketEnd
    AND inc.pmi_end_base IS NULL
;

UPDATE #GNM_PoolBasedIncentive inc SET inc.pmi_end_base = 0 WHERE inc.pmi_end_base IS NULL;

-- Update pmi_end_loansize
UPDATE #GNM_PoolBasedIncentive inc SET inc.pmi_end_loansize = pmi.PMI
FROM report.PIV_PMI_LoanSize pmi
WHERE 1=1
    AND inc.asOf >= pmi.startDate and inc.asOf < pmi.endDate 
    AND inc.waocs >= pmi.FICObucketStart and inc.waocs < pmi.FICObucketEnd
    AND inc.waCLTV > pmi.LTVBucketStart and inc.waCLTV <= pmi.LTVBucketEnd
    AND inc.waclSize > pmi.LoanSizeStart and inc.waclSize <= pmi.LoanSizeEnd
;

UPDATE #GNM_PoolBasedIncentive inc SET inc.pmi_end_loansize = pmi.PMI
FROM report.PIV_PMI_LoanSize pmi
WHERE 1=1
    AND inc.asOf >= pmi.startDate and inc.asOf < pmi.endDate 
    AND 700 >= pmi.FICObucketStart and 700 < pmi.FICObucketEnd
    AND inc.waCLTV > pmi.LTVBucketStart and inc.waCLTV <= pmi.LTVBucketEnd
    AND inc.waclSize > pmi.LoanSizeStart and inc.waclSize <= pmi.LoanSizeEnd
    AND inc.pmi_end_loansize IS NULL
;

UPDATE #GNM_PoolBasedIncentive inc SET inc.pmi_end_loansize = 0 WHERE inc.pmi_end_loansize IS NULL;

-- Update pmi_end_occ
UPDATE #GNM_PoolBasedIncentive inc SET inc.pmi_end_occ = pmi_owner.PMI
FROM report.PIV_PMI_Occupancy pmi_owner
WHERE 1=1
    AND pmi_owner.OccType = 'OWNER'
    AND inc.asOf >= pmi_owner.startDate and inc.asOf < pmi_owner.endDate 
    AND inc.waocs >= pmi_owner.FICObucketStart and inc.waocs < pmi_owner.FICObucketEnd
    AND inc.waCLTV > pmi_owner.LTVBucketStart and inc.waCLTV <= pmi_owner.LTVBucketEnd
;

UPDATE #GNM_PoolBasedIncentive inc SET inc.pmi_end_occ = 0 WHERE inc.pmi_end_occ IS NULL;

-- Update Base LLPA
UPDATE #GNM_PoolBasedIncentive inc SET inc.llpa_base = llpa.LLPA
FROM report.PIV_LLPA_Base llpa
WHERE 1=1
    AND inc.asOf >= llpa.startDate and inc.asOf < llpa.endDate 
    AND inc.waocs >= llpa.FICObucketStart and inc.waocs < llpa.FICObucketEnd
    AND inc.waCLTV > llpa.LTVBucketStart and inc.waCLTV <= llpa.LTVBucketEnd
;

UPDATE #GNM_PoolBasedIncentive inc SET inc.llpa_base = llpa.LLPA
FROM report.PIV_LLPA_Base llpa
WHERE 1=1
    AND inc.asOf >= llpa.startDate and inc.asOf < llpa.endDate 
    AND 700 >= llpa.FICObucketStart and 700 < llpa.FICObucketEnd
    AND inc.waCLTV > llpa.LTVBucketStart and inc.waCLTV <= llpa.LTVBucketEnd
    AND inc.llpa_base IS NULL
;

UPDATE #GNM_PoolBasedIncentive inc SET inc.llpa_base = 0 WHERE inc.llpa_base IS NULL;

-- Update ADMC LLPA
UPDATE #GNM_PoolBasedIncentive inc SET inc.llpa_admc = llpa.LLPA
FROM report.PIV_LLPA_ADMC llpa
WHERE 1=1
    AND inc.asOf >= llpa.startDate and inc.asOf < llpa.endDate 
;

UPDATE #GNM_PoolBasedIncentive inc SET inc.llpa_admc = 0 WHERE inc.llpa_admc IS NULL;

-- Update Occupancy LLPA
UPDATE #GNM_PoolBasedIncentive inc SET inc.llpa_occ = llpa_owner.LLPA
FROM report.PIV_LLPA_Occupancy llpa_owner
WHERE 1=1
    AND llpa_owner.OccType = 'OWNER'
    AND inc.asOf >= llpa_owner.startDate and inc.asOf < llpa_owner.endDate 
    AND inc.waCLTV > llpa_owner.LTVBucketStart and inc.waCLTV <= llpa_owner.LTVBucketEnd
;

UPDATE #GNM_PoolBasedIncentive inc SET inc.llpa_occ = 0 WHERE inc.llpa_occ IS NULL;

-- Update LTV LLPA
UPDATE #GNM_PoolBasedIncentive inc SET inc.llpa_ltv = llpa.LLPA
FROM report.PIV_LLPA_LTV llpa
WHERE 1=1
    AND inc.asOf >= llpa.startDate and inc.asOf < llpa.endDate 
    AND inc.waCLTV > llpa.LTVBucketStart and inc.waCLTV <= llpa.LTVBucketEnd
;

UPDATE #GNM_PoolBasedIncentive inc SET inc.llpa_ltv = 0 WHERE inc.llpa_ltv IS NULL;

-- Update Loan Size
UPDATE #GNM_PoolBasedIncentive inc SET inc.llpa_loansize = llpa.LLPA
FROM report.PIV_LLPA_LoanSize llpa
WHERE 1=1
    AND inc.asOf >= llpa.startDate and inc.asOf < llpa.endDate 
    AND inc.waclSize > llpa.LoanSizeBucketStart and inc.waclSize <= llpa.LoanSizeBucketEnd
    AND inc.waCLTV > llpa.LTVBucketStart and inc.waCLTV <= llpa.LTVBucketEnd
;

UPDATE #GNM_PoolBasedIncentive inc SET inc.llpa_loansize = 0 WHERE inc.llpa_loansize IS NULL;

-- Update PMI and LLPA Incentive
UPDATE #GNM_PoolBasedIncentive inc SET
    pmi = (pmi_end_base + pmi_end_loansize + pmi_end_occ),
    llpa = (llpa_base + llpa_admc + llpa_occ + llpa_ltv + llpa_loansize)
;

-- Update MIP
--UPDATE #GNM_PoolBasedIncentive inc SET inc.mip = CASE WHEN inc.waCLTV <= 78.0 THEN 0.0 ELSE 55.0 + 1.0 / 12.0 END
--WHERE inc.asOf > '2012-06-01'
--    AND inc.originationDate <= '2009-05-01'
--;
UPDATE #GNM_PoolBasedIncentive inc SET inc.mip = mip_base.AnnualMIPPoints + mip_base.UpfrontMIPPoints / 12.0
FROM (Select * from report.PIV_MIP_Base UNION Select * from report.PIV_MIP_Grandfather) mip_base
WHERE 1=1
    AND inc.origTerm           >  mip_base.TermBucketStart
	AND inc.origTerm           <= mip_base.TermBucketEnd
	AND inc.waCLTV             >  mip_base.LTVBucketStart
	AND inc.waCLTV             <= mip_base.LTVBucketEnd
	AND inc.waclSize           >= mip_base.LoanSizeBucketStart
	AND inc.waclSize           <= mip_base.LoanSizeBucketEnd
    AND inc.originationDate    >  mip_base.OriginationStartDate
	AND inc.originationDate    <= mip_base.OriginationEndDate
	AND inc.asOf               >  mip_base.StartDate
	AND inc.asOf               <= mip_base.EndDate
    AND inc.mip IS NULL
;
COMMIT;

-- Adjust mip for Non-FHA
UPDATE #GNM_PoolBasedIncentive inc SET inc.mip = 0.0
WHERE loanType NOT IN ('FHA')
COMMIT;

-- Update Refinance Incentive
UPDATE #GNM_PoolBasedIncentive inc SET
    conventional_refi_incentive = 100.0 * (wac + (mip_begin / 100.0) - MtgRate_Conv - (llpa / 400.0) - (pmi / 100.0)),
    fha_refi_incentive = 100.0 * (wac + (mip_begin / 100.0) - MtgRate - (mip / 100.0))
;

UPDATE #GNM_PoolBasedIncentive inc SET
    refi_incentive = CASE WHEN conventional_refi_incentive >= fha_refi_incentive THEN conventional_refi_incentive ELSE fha_refi_incentive END
;

-- Update Refinance Incentive Eligible
UPDATE #GNM_PoolBasedIncentive inc SET
    refi_incentive_eligible = CASE WHEN conventional_refi_incentive * conventional_eligible / 100.0 >= fha_refi_incentive THEN conventional_refi_incentive * conventional_eligible / 100.0 ELSE fha_refi_incentive END
;

-- Update GNM_PoolIncentive
UPDATE #GNM_PoolIncentive pi SET
    pi.pmi_end_base = pbi.pmi_end_base,
    pi.pmi_end_loansize = pbi.pmi_end_loansize,
    pi.pmi_end_occ = pbi.pmi_end_occ,
    pi.llpa_base = pbi.llpa_base,
    pi.llpa_admc = pbi.llpa_admc,
    pi.llpa_occ = pbi.llpa_occ,
    pi.llpa_ltv = pbi.llpa_ltv,
    pi.llpa_loansize = pbi.llpa_loansize,
    pi.mip_begin = pbi.mip_begin,
    pi.pmi = pbi.pmi, 
    pi.llpa = pbi.llpa,
    pi.mip = pbi.mip,
    pi.conventional_refi_incentive = pbi.conventional_refi_incentive,
    pi.fha_refi_incentive = pbi.fha_refi_incentive,
    pi.refi_incentive = pbi.refi_incentive,
    pi.refi_incentive_eligible = pbi.refi_incentive_eligible
FROM #GNM_PoolBasedIncentive pbi
WHERE pi.issueId = pbi.issueId
    AND pi.asOf = pbi.asOf
    AND pi.loanType = pbi.loanType
;
COMMIT;



-- Tests

-- Time Series Tests
-- History for: conventional_refi_incentive, fha_refi_incentive, refi_incentive, refi_incentive_eligible, origPMI, currLLPA, currPMI, currMIP
--SELECT marketTicker, asOf, count(1), sum(balance), sum(balance * conventional_refi_incentive) / sum(CASE WHEN conventional_refi_incentive IS NULL THEN 0.0 ELSE balance END) as wavg_conventional_refi_incentive FROM #GNM_PoolIncentive GROUP BY marketTicker, asOf ORDER BY asOf

--SELECT marketTicker, asOf, count(1), sum(balance), sum(balance * fha_refi_incentive) / sum(CASE WHEN fha_refi_incentive IS NULL THEN 0.0 ELSE balance END) as wavg_fha_refi_incentive FROM #GNM_PoolIncentive GROUP BY marketTicker, asOf ORDER BY asOf

--SELECT marketTicker, asOf, count(1), sum(balance), sum(balance * refi_incentive) / sum(CASE WHEN refi_incentive IS NULL THEN 0.0 ELSE balance END) as wavg_refi_incentive FROM #GNM_PoolIncentive GROUP BY marketTicker, asOf ORDER BY asOf

--SELECT marketTicker, asOf, count(1), sum(balance), sum(balance * refi_incentive_eligible) / sum(CASE WHEN refi_incentive_eligible IS NULL THEN 0.0 ELSE balance END) as wavg_refi_incentive_eligible FROM #GNM_PoolIncentive GROUP BY marketTicker, asOf ORDER BY asOf

--SELECT marketTicker, asOf, count(1), sum(balance), sum(balance * mip_begin) / sum(CASE WHEN mip_begin IS NULL THEN 0.0 ELSE balance END) as wavg_orig_mip FROM #GNM_PoolIncentive GROUP BY marketTicker, asOf ORDER BY asOf

--SELECT marketTicker, asOf, count(1), sum(balance), sum(balance * llpa) / sum(CASE WHEN llpa IS NULL THEN 0.0 ELSE balance END) as wavg_llpa FROM #GNM_PoolIncentive GROUP BY marketTicker, asOf ORDER BY asOf

--SELECT marketTicker, asOf, count(1), sum(balance), sum(balance * pmi) / sum(CASE WHEN pmi IS NULL THEN 0.0 ELSE balance END) as wavg_pmi FROM #GNM_PoolIncentive GROUP BY marketTicker, asOf ORDER BY asOf

--SELECT marketTicker, asOf, count(1), sum(balance), sum(balance * mip) / sum(CASE WHEN mip IS NULL THEN 0.0 ELSE balance END) as wavg_mip FROM #GNM_PoolIncentive GROUP BY marketTicker, asOf ORDER BY asOf

----------------------------------------------------------------------------------------------
-- Check to see if Pools have conventional_refi_incentive IS NULL OR conventional_refi_incentive < -1000.0 OR conventional_refi_incentive > 2000.0
----------------------------------------------------------------------------------------------
        declare   @cnt int
        SELECT
            @cnt =  count(1)
        FROM #GNM_PoolIncentive WHERE conventional_refi_incentive IS NULL OR conventional_refi_incentive < -1000.0 OR conventional_refi_incentive > 2000.0

        if (@cnt > 0)
        BEGIN
            RAISERROR 99999 'GNM Pools with INVALID VALUE for conventional_refi_incentive PoolCount : %1!', @cnt
            RETURN
        END

----------------------------------------------------------------------------------------------
-- Check to see if Pools have fha_refi_incentive IS NULL OR fha_refi_incentive < -1000.0 OR fha_refi_incentive > 2000.0
----------------------------------------------------------------------------------------------
        SELECT
            @cnt =  count(1)
        FROM #GNM_PoolIncentive WHERE fha_refi_incentive IS NULL OR fha_refi_incentive < -1000.0 OR fha_refi_incentive > 2000.0

        if (@cnt > 0)
        BEGIN
            RAISERROR 99999 'GNM Pools with INVALID VALUE for fha_refi_incentive PoolCount : %1!', @cnt
            RETURN
        END

----------------------------------------------------------------------------------------------
-- Check to see if Pools have refi_incentive IS NULL OR refi_incentive < -1000.0 OR refi_incentive > 2000.0
----------------------------------------------------------------------------------------------
        SELECT
            @cnt =  count(1)
        FROM #GNM_PoolIncentive WHERE refi_incentive IS NULL OR refi_incentive < -1000.0 OR refi_incentive > 2000.0

        if (@cnt > 0)
        BEGIN
            RAISERROR 99999 'GNM Pools with INVALID VALUE for refi_incentive PoolCount : %1!', @cnt
            RETURN
        END
        
----------------------------------------------------------------------------------------------
-- Check to see if Pools have refi_incentive_eligible < -1000.0 OR refi_incentive_eligible > 2000.0
----------------------------------------------------------------------------------------------
        SELECT
            @cnt =  count(1)
        FROM #GNM_PoolIncentive WHERE refi_incentive_eligible < -1000.0 OR refi_incentive_eligible > 2000.0

        if (@cnt > 0)
        BEGIN
            RAISERROR 99999 'GNM Pools with INVALID VALUE for refi_incentive_eligible PoolCount : %1!', @cnt
            RETURN
        END
        
----------------------------------------------------------------------------------------------
-- Check to see if Pools have mip_begin IS NULL OR mip_begin < 0.0 OR mip_begin > 300
----------------------------------------------------------------------------------------------
        SELECT
            @cnt =  count(1)
        FROM #GNM_PoolIncentive WHERE mip_begin IS NULL OR mip_begin < 0.0 OR mip_begin > 300

        if (@cnt > 0)
        BEGIN
            RAISERROR 99999 'GNM Pools with INVALID VALUE for pmi_begin PoolCount : %1!', @cnt
            RETURN
        END

----------------------------------------------------------------------------------------------
-- Check to see if Pools have llpa IS NULL OR llpa < -25.0 OR llpa > 1000.0
----------------------------------------------------------------------------------------------
        SELECT
            @cnt =  count(1)
        FROM #GNM_PoolIncentive WHERE llpa IS NULL OR llpa < -25.0 OR llpa > 1000.0

        if (@cnt > 0)
        BEGIN
            RAISERROR 99999 'GNM Pools with INVALID VALUE for llpa PoolCount : %1!', @cnt
            RETURN
        END

----------------------------------------------------------------------------------------------
-- Check to see if Pools have pmi IS NULL OR pmi < 0.0 OR pmi > 500
----------------------------------------------------------------------------------------------
        SELECT
            @cnt =  count(1)
        FROM #GNM_PoolIncentive WHERE pmi IS NULL OR pmi < 0.0 OR pmi > 500

        if (@cnt > 0)
        BEGIN
            RAISERROR 99999 'GNM Pools with INVALID VALUE for pmi PoolCount : %1!', @cnt
            RETURN
        END

----------------------------------------------------------------------------------------------
-- Check to see if Pools have mip IS NULL OR mip < 0.0 OR mip > 300
----------------------------------------------------------------------------------------------
        SELECT
            @cnt =  count(1)
        FROM #GNM_PoolIncentive WHERE mip IS NULL OR mip < 0.0 OR mip > 300

        if (@cnt > 0)
        BEGIN
            RAISERROR 99999 'GNM Pools with INVALID VALUE for mip PoolCount : %1!', @cnt
            RETURN
        END
        
-- End Tests



-- Load Data into Scale Incentive Table
DELETE FROM scale.GNM_PoolIncentive_v2_00
FROM scale.GNM_PoolIncentive_v2_00 spi, #GNM_PoolIncentive pi
WHERE 1=1
    AND spi.issueId = pi.issueId
    AND spi.asOf = pi.asOf
    AND pi.marketTicker IN (SELECT tickerName FROM #ticker)
    AND spi.asOf >= (SELECT asOf from #tmp_asOf)
    AND version = (SELECT version from #tmp_version)
;

DECLARE @version varchar(5)
SELECT @version = (select * from #tmp_version)

INSERT INTO scale.GNM_PoolIncentive_v2_00 (issueId, loanType, asOf, version, conventional_refi_incentive, fha_refi_incentive, refi_incentive, refi_incentive_eligible, origMIP, currLLPA, currPMI, currMIP)
SELECT
    issueId,
    loanType,
    asOf,
    @version,
    conventional_refi_incentive,
    fha_refi_incentive,
    refi_incentive,
    refi_incentive_eligible,
    mip_begin,
    llpa,
    pmi,
    mip
FROM #GNM_PoolIncentive
WHERE marketTicker IN (SELECT tickerName FROM #ticker)
    AND asOf >= (SELECT asOf from #tmp_asOf)
;
