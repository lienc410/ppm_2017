-- Freddie Conventional
-- Loan Level
-- Part 4 of 7
-- Script to update the eligibility metrics
-- Updates HARP_eligible, conventional_eligible and fha_eligible

-- Before execute the script, need to set the dates to run for
DROP TABLE IF EXISTS #tmp_asOf;
SELECT CAST('#####ASOF#####' AS DATE) asOf, CAST('#####LAST#####' AS DATE) asOf_last INTO #tmp_asOf
--SELECT CAST ('2000-03-01' AS DATE) asOf INTO #tmp_asOf
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
INSERT #ticker SELECT 'FGLMC', 'CONVENTIONAL_30YR';   --30 Yr Conventional Freddie
INSERT #ticker SELECT 'FGT6', 'JUMBO_30YR';           --30 Yr Jumbo Freddie
INSERT #ticker SELECT 'FGU6', 'CONVENTIONAL_30YR';    --30 Yr CQ Freddie High LTV[105-125]
INSERT #ticker SELECT 'FGU9', 'CONVENTIONAL_30YR';    --30 Yr CR Freddie High LTV[125-150]
--INSERT #ticker SELECT 'FGTW', 'CONVENTIONAL_20YR';    --20 Yr Conventional Freddie
--INSERT #ticker SELECT 'FGCI', 'CONVENTIONAL_15YR';    --15 Yr Conventional Freddie
COMMIT;

CREATE LF INDEX loan_tickerName_idx ON #ticker(tickerName);
COMMIT;

-- Before execute the script, need to set the version to run for
DROP TABLE IF EXISTS #tmp_version;
SELECT mvc.tickerName, mvc.appType, mvc.originationVersion_LL as originationVersion
INTO #tmp_version
FROM scale.ModelVersionConfig mvc
JOIN #tmp_appType tat
     ON mvc.appType = tat.appType
JOIN #ticker tk
     ON mvc.tickerName = tk.tickerName
;
COMMIT;


-- Update HARP Eligibility
DROP TABLE IF EXISTS #FHL_harp_eligibility;
SELECT
    sl.marketTicker,
    sl.loanSeqNum,
    slh.asOf,
    CASE
        WHEN sl.percentHARPed = 100.0 THEN 0
        WHEN sl.originationDate > '2009-06-01' THEN 0
        WHEN slh.asOf < '2009-06-01' THEN 0
        ELSE 1
    END as HARP_eligible
INTO #FHL_harp_eligibility
FROM scale.FHL_Loan_Dev sl
JOIN #ticker tk
    ON sl.marketTicker = tk.tickerName
JOIN scale.FHL_LoanHist slh
    ON sl.loanSeqNum = slh.loanSeqNum
WHERE 1=1
    AND slh.asOf >= (select asOf from #tmp_asOf)
	AND slh.asOf <= (select asOf_last from #tmp_asOf)
    AND sl.version IN (select  originationVersion from #tmp_version)
;
COMMIT;
CREATE HG INDEX loan_id_idx ON #FHL_harp_eligibility(loanSeqNum);
CREATE LF INDEX asof_date_idx ON #FHL_harp_eligibility(asOf);
CREATE LF INDEX ticker_idx ON #FHL_harp_eligibility(marketTicker);
COMMIT;

-- Update Conventional Eligibility
DROP TABLE IF EXISTS #FHL_conventional_eligibility;
SELECT distinct
    sl.marketTicker,
    sl.loanSeqNum,
    slh.asOf,
	cl.occType,
	sl.origFICO,
	slh.cltv,
	clh.currentRPB,
	sl.numberUnits,
	cl.origTerm,
	
	cast (NULL as numeric(3,0)) as base_PMI,
	cast (NULL as numeric(3,0)) as occ_PMI,
	cast (NULL as numeric(3,0)) as size_PMI,
	
	cast (NULL as numeric(10,4)) as base_LLPA,
	cast (NULL as numeric(10,4)) as ltv_LLPA,
	cast (NULL as numeric(10,4)) as admc_LLPA,
	cast (NULL as numeric(10,4)) as occ_LLPA,
	cast (NULL as numeric(10,4)) as unit_LLPA,
	cast (NULL as numeric(10,4)) as size_LLPA,
	
	cast (NULL as numeric(10,4)) as ConvCost,
	cast (NULL as char(3)) as ConvCostValidility,
	cast (NULL as numeric(1,0)) as conventional_eligible
--   ConvCost = pmi_base.PMI + pmi_occ.PMI + pmi_size.PMI + llpa_base.LLPA + llpa_ltv.LLPA + llpa_admc.LLPA + llpa_occ.LLPA + llpa_unit.LLPA + llpa_size.LLPA ,
--   ConvCostValidility = CASE WHEN sl.origFICO IS NULL OR slh.cltv IS NULL OR cl.occType IS NULL OR sl.numberUnits IS NULL OR clh.currentRPB IS NULL THEN 'N' ELSE 'Y' END ,
--    CASE 
--        WHEN ConvCostValidility = 'Y' THEN 
--            CASE 
--                WHEN ConvCost IS NULL THEN 0
--                ELSE 1
--            END
--        ELSE NULL 
--    END as conventional_eligible
INTO #FHL_conventional_eligibility
FROM fhl.PIV_Loan cl
JOIN scale.FHL_Loan_Dev sl
    ON cl.loanSeqNum = sl.loanSeqNum
JOIN #ticker tk
    ON sl.marketTicker = tk.tickerName
JOIN fhl.PIV_LoanHist clh
    ON cl.loanSeqNum = clh.loanSeqNum
JOIN scale.FHL_LoanHist slh
    ON clh.loanSeqNum = slh.loanSeqNum
    AND clh.asOf = slh.asOf
    
-- LLPAs
-- LEFT OUTER JOIN report.PIV_LLPA_Base_Raw llpa_base
--            ON slh.asOf >= llpa_base.startDate AND slh.asOf < llpa_base.endDate
--            AND sl.origFICO >= llpa_base.FicoStart AND sl.origFICO < llpa_base.FicoEnd
--            AND slh.cltv > llpa_base.LtvStart AND slh.cltv <= llpa_base.LtvEnd
-- LEFT OUTER JOIN report.PIV_LLPA_LTV_Raw llpa_ltv 
--            ON slh.asOf >= llpa_ltv.startDate AND slh.asOf < llpa_ltv.endDate
--            AND slh.cltv > llpa_ltv.LtvStart AND slh.cltv <= llpa_ltv.LtvEnd
-- LEFT OUTER JOIN report.PIV_LLPA_ADMC_Raw llpa_admc
--            ON slh.asOf >= llpa_admc.startDate AND slh.asOf < llpa_admc.endDate
-- LEFT OUTER JOIN report.PIV_LLPA_Occupancy_Raw llpa_occ
--            ON slh.asOf >= llpa_occ.startDate AND slh.asOf < llpa_occ.endDate
--            AND cl.occType = llpa_occ.occType
--            AND slh.cltv > llpa_occ.LtvStart AND slh.cltv <= llpa_occ.LtvEnd
-- LEFT OUTER JOIN report.PIV_LLPA_Units_Raw llpa_unit
--            ON slh.asOf >= llpa_unit.startDate AND slh.asOf < llpa_unit.endDate
--            AND sl.numberUnits = llpa_unit.numUnits
--            AND slh.cltv > llpa_unit.LtvStart AND slh.cltv <= llpa_unit.LtvEnd
-- LEFT OUTER JOIN report.PIV_LLPA_LoanSize_Raw llpa_size
--            ON slh.asOf >= llpa_size.startDate AND slh.asOf < llpa_size.endDate
--            AND clh.currentRPB >= llpa_size.LoanSizeStart AND clh.currentRPB < llpa_size.LoanSizeEnd
--            AND slh.cltv > llpa_size.LtvStart AND slh.cltv <= llpa_size.LtvEnd
            
-- PMIs
-- LEFT OUTER JOIN report.PIV_PMI_Base_Raw pmi_base
--            ON slh.asOf >= pmi_base.startDate AND slh.asOf < pmi_base.endDate
--            AND sl.origFICO >= pmi_base.FICOBucketStart AND sl.origFICO < pmi_base.FICOBucketEnd
--            AND slh.cltv > pmi_base.LTVBucketStart AND slh.cltv <= pmi_base.LTVBucketEnd	
--            AND pmi_base.LoanPurpose = 'REFI'	
-- LEFT OUTER JOIN report.PIV_PMI_Occupancy_Raw pmi_occ
--            ON slh.asOf >= pmi_occ.startDate AND slh.asOf < pmi_occ.endDate
--            AND cl.occType = pmi_occ.occType
--            AND sl.origFICO >= pmi_occ.FICOBucketStart AND sl.origFICO < pmi_occ.FICOBucketEnd
--            AND slh.cltv > pmi_occ.LTVStart AND slh.cltv <= pmi_occ.LTVEnd	
-- LEFT OUTER JOIN report.PIV_PMI_LoanSize_Raw pmi_size
--            ON slh.asOf >= pmi_size.startDate AND slh.asOf < pmi_size.endDate
--            AND sl.origFICO >= pmi_size.FICOBucketStart AND sl.origFICO < pmi_size.FICOBucketEnd
--            AND slh.cltv > pmi_size.LTVStart AND slh.cltv <= pmi_size.LTVEnd	
--            AND clh.currentRPB >= pmi_size.LoanSizeStart AND clh.currentRPB < pmi_size.LoanSizeEnd
 WHERE 1=1
    AND slh.asOf >= (select asOf from #tmp_asOf)
 	AND slh.asOf <= (select asOf_last from #tmp_asOf)
    AND sl.version IN (select originationVersion from #tmp_version)
;
COMMIT;
CREATE HG INDEX loan_id_idx ON #FHL_conventional_eligibility(loanSeqNum);
CREATE LF INDEX asof_date_idx ON #FHL_conventional_eligibility(asOf);
COMMIT;

-- Update PMI
UPDATE #FHL_conventional_eligibility ce
SET occ_PMI = pmi_occ.PMI
FROM report.PIV_PMI_Occupancy_Raw pmi_occ
    WHERE ce.asOf >= pmi_occ.startDate AND ce.asOf < pmi_occ.endDate
            AND ce.occType = pmi_occ.occType
            AND ce.origFICO >= pmi_occ.FICOBucketStart AND ce.origFICO < pmi_occ.FICOBucketEnd
            AND ce.cltv > pmi_occ.LTVStart AND ce.cltv <= pmi_occ.LTVEnd	
;
COMMIT;

UPDATE #FHL_conventional_eligibility ce
SET base_PMI = pmi_base.PMI
FROM report.PIV_PMI_Base_Raw_v2 pmi_base
    WHERE ce.asOf >= pmi_base.startDate AND ce.asOf < pmi_base.endDate
           AND ce.origFICO >= pmi_base.FICOBucketStart AND ce.origFICO < pmi_base.FICOBucketEnd
           AND ce.cltv > pmi_base.LTVBucketStart AND ce.cltv <= pmi_base.LTVBucketEnd	
           AND pmi_base.LoanPurpose = 'REFI'	
		   AND pmi_base.RateType = 'Fixed'
           AND ce.origTerm > pmi_base.TermBucketStart AND ce.origTerm <= pmi_base.TermBucketEnd
;
COMMIT;

UPDATE #FHL_conventional_eligibility ce
SET size_PMI = pmi_size.PMI
FROM report.PIV_PMI_LoanSize_Raw pmi_size
    WHERE ce.asOf >= pmi_size.startDate AND ce.asOf < pmi_size.endDate
            AND ce.origFICO >= pmi_size.FICOBucketStart AND ce.origFICO < pmi_size.FICOBucketEnd
            AND ce.cltv > pmi_size.LTVStart AND ce.cltv <= pmi_size.LTVEnd	
            AND ce.currentRPB >= pmi_size.LoanSizeStart AND ce.currentRPB < pmi_size.LoanSizeEnd
;
COMMIT;

-- Update LLPA
UPDATE #FHL_conventional_eligibility ce
SET base_LLPA = llpa_base.LLPA
FROM report.PIV_LLPA_Base_Raw llpa_base
    WHERE ce.asOf >= llpa_base.startDate AND ce.asOf < llpa_base.endDate
            AND ce.origFICO >= llpa_base.FicoStart AND ce.origFICO < llpa_base.FicoEnd
            AND ce.cltv > llpa_base.LtvStart AND ce.cltv <= llpa_base.LtvEnd
;
COMMIT;

UPDATE #FHL_conventional_eligibility ce
SET ltv_LLPA = llpa_ltv.LLPA
FROM report.PIV_LLPA_LTV_Raw llpa_ltv 
    WHERE ce.asOf >= llpa_ltv.startDate AND ce.asOf < llpa_ltv.endDate
           AND ce.cltv > llpa_ltv.LtvStart AND ce.cltv <= llpa_ltv.LtvEnd
;
COMMIT;

UPDATE #FHL_conventional_eligibility ce
SET admc_LLPA = llpa_admc.LLPA
FROM report.PIV_LLPA_ADMC_Raw llpa_admc
    WHERE ce.asOf >= llpa_admc.startDate AND ce.asOf < llpa_admc.endDate
;
COMMIT;

UPDATE #FHL_conventional_eligibility ce
SET occ_LLPA = llpa_occ.LLPA
FROM report.PIV_LLPA_Occupancy_Raw llpa_occ
    WHERE ce.asOf >= llpa_occ.startDate AND ce.asOf < llpa_occ.endDate
            AND ce.occType = llpa_occ.occType
            AND ce.cltv > llpa_occ.LtvStart AND ce.cltv <= llpa_occ.LtvEnd
;
COMMIT;

UPDATE #FHL_conventional_eligibility ce
SET unit_LLPA = llpa_unit.LLPA
FROM report.PIV_LLPA_Units_Raw llpa_unit
    WHERE ce.asOf >= llpa_unit.startDate AND ce.asOf < llpa_unit.endDate
            AND ce.numberUnits = llpa_unit.numUnits
            AND ce.cltv > llpa_unit.LtvStart AND ce.cltv <= llpa_unit.LtvEnd
;
COMMIT;

UPDATE #FHL_conventional_eligibility ce
SET size_LLPA = llpa_size.LLPA
FROM report.PIV_LLPA_LoanSize_Raw llpa_size
    WHERE ce.asOf >= llpa_size.startDate AND ce.asOf < llpa_size.endDate
            AND ce.currentRPB >= llpa_size.LoanSizeStart AND ce.currentRPB < llpa_size.LoanSizeEnd
            AND ce.cltv > llpa_size.LtvStart AND ce.cltv <= llpa_size.LtvEnd
;
COMMIT;

-- Update Conventional Eligibility
UPDATE #FHL_conventional_eligibility ce
SET ConvCost = base_PMI +occ_PMI + size_PMI + base_LLPA + ltv_LLPA + admc_LLPA + occ_LLPA + unit_LLPA + size_LLPA,
       ConvCostValidility = CASE WHEN ce.origFICO IS NULL OR ce.cltv IS NULL OR ce.occType IS NULL OR ce.numberUnits IS NULL OR ce.currentRPB IS NULL THEN 'N' ELSE 'Y' END;
COMMIT;


UPDATE #FHL_conventional_eligibility ce
SET conventional_eligible = CASE 
                                             WHEN ConvCostValidility = 'Y' THEN 
                                               CASE 
                                                 WHEN ConvCost IS NULL THEN 0
                                                 ELSE 1
                                               END
                                             ELSE NULL 
                                         END;
COMMIT;


-- Update FHA Eligibility
DROP TABLE IF EXISTS #FHL_fha_eligibility;
SELECT
    sl.marketTicker,
    sl.loanSeqNum,
    slh.asOf,
    CASE 
        WHEN sl.origFICO < 500 THEN 0
        WHEN slh.cltv > 97.75 THEN 0
        WHEN sl.origFICO >= 580 AND slh.cltv <= 97.75 THEN 1
        WHEN sl.origFICO >= 500 AND slh.cltv <= 90.0 THEN 1
        ELSE 0
    END as fha_eligible
INTO #FHL_fha_eligibility
FROM scale.FHL_Loan_Dev sl
JOIN #ticker tk
    ON sl.marketTicker = tk.tickerName
JOIN scale.FHL_LoanHist slh
    ON sl.loanSeqNum = slh.loanSeqNum
WHERE 1=1
    AND slh.asOf >= (select asOf from #tmp_asOf)
	AND slh.asOf <= (select asOf_last from #tmp_asOf)
    AND sl.version IN (select originationVersion from #tmp_version)
;
COMMIT;
CREATE HG INDEX loan_id_idx ON #FHL_fha_eligibility(loanSeqNum);
CREATE LF INDEX asof_date_idx ON #FHL_fha_eligibility(asOf);
COMMIT;

    -- update INVESTOR / 2ND as not eligible from conventional to FHA
UPDATE #FHL_fha_eligibility e SET fha_eligible = 0
FROM #FHL_fha_eligibility e, fhl.PIV_Loan cl
WHERE e.loanSeqNum = cl.loanSeqNum
AND cl.occType in ('2ND', 'INV')
;
COMMIT;

--Update REFIEligibleCLTVThreshold
DROP TABLE IF EXISTS #FHL_refi_eligibility_threshold;
SELECT
    sl.loanSeqNum,
    sl.origFICO,
    sl.numberUnits,
    cl.occType,
	CASE
	    WHEN occType in ('2ND','INV') THEN CAST(0 as numeric(7,2))
		ELSE CASE
            WHEN sl.origFICO < 500 THEN CAST (0 as numeric(7,2))
            WHEN sl.origFICO < 580 THEN CAST (90 as numeric(7,2))
            ELSE CAST (97.75 as numeric(7,2))
		END
    END as FHAEligibleCLTV,
    CASE
	    WHEN sl.origFICO < 620 THEN CAST (0 as numeric(7,2))
        WHEN cl.occType = 'INV' and sl.numberUnits = 1  THEN CAST (85 as numeric(7,2))
        WHEN sl.numberUnits = 1  THEN CAST (97 as numeric(7,2))
        WHEN sl.numberUnits = 2  THEN CAST (85 as numeric(7,2))
        ELSE CAST (75 as numeric(7,2))
    END as ConventionalEligibleCLTV,
    CAST (NULL as numeric(7,2)) as REFIEligibleCLTVThreshold
INTO #FHL_refi_eligibility_threshold
FROM fhl.PIV_Loan cl
JOIN scale.FHL_Loan_Dev sl
    ON cl.loanSeqNum = sl.loanSeqNum
JOIN #ticker tk
    ON sl.marketTicker = tk.tickerName
    AND sl.version IN (select originationVersion from #tmp_version)
    --If the rows are less then it deletes records from scale.FHL_LoanEligibility
    --AND sl.originationDate > '2009-06-01'
;
COMMIT;

Update #FHL_refi_eligibility_threshold Set REFIEligibleCLTVThreshold = Case
    WHEN ConventionalEligibleCLTV > FHAEligibleCLTV THEN ConventionalEligibleCLTV
    ELSE FHAEligibleCLTV
END;
COMMIT;

Update #FHL_refi_eligibility_threshold ret
Set REFIEligibleCLTVThreshold = 999
From scale.FHL_Loan_Dev sl
Where ret.loanSeqNum = sl.loanSeqNum 
AND sl.version IN (select originationVersion from #tmp_version)
and sl.originationDate <= '2009-06-01';
COMMIT;

-- Tests

--SELECT l.marketTicker, sl.originationDate, count(1), sum(balance), sum(balance * HARP_eligible) / sum(CASE WHEN HARP_eligible IS NULL THEN 0.0 ELSE balance END) as wavg_pct_harp_eligible FROM #FHL_harp_eligibility l JOIN #FHL_LoanHist lh ON l.loanSeqNum = lh.loanSeqNum AND l.asOf = lh.asOf JOIN scale.FHL_Loan sl ON sl.loanSeqNum = lh.loanSeqNum GROUP BY l.marketTicker, sl.originationDate ORDER BY sl.originationDate
--SELECT l.marketTicker, l.asOf, count(1), sum(balance), sum(balance * HARP_eligible) / sum(CASE WHEN HARP_eligible IS NULL THEN 0.0 ELSE balance END) as wavg_pct_harp_eligible FROM #FHL_harp_eligibility l JOIN #FHL_LoanHist lh ON l.loanSeqNum = lh.loanSeqNum AND l.asOf = lh.asOf GROUP BY l.marketTicker, l.asOf ORDER BY l.asOf

--SELECT l.marketTicker, sl.originationDate, count(1), sum(balance), sum(balance * conventional_eligible) / sum(CASE WHEN conventional_eligible IS NULL THEN 0.0 ELSE balance END) as wavg_pct_conv_eligible FROM #FHL_conventional_eligibility l JOIN #FHL_LoanHist lh ON l.loanSeqNum = lh.loanSeqNum AND l.asOf = lh.asOf JOIN scale.FHL_Loan sl ON sl.loanSeqNum = lh.loanSeqNum GROUP BY l.marketTicker, sl.originationDate ORDER BY sl.originationDate
--SELECT l.marketTicker, l.asOf, count(1), sum(balance), sum(balance * conventional_eligible) / sum(CASE WHEN conventional_eligible IS NULL THEN 0.0 ELSE balance END) as wavg_pct_conv_eligible FROM #FHL_conventional_eligibility l JOIN #FHL_LoanHist lh ON l.loanSeqNum = lh.loanSeqNum AND l.asOf = lh.asOf GROUP BY l.marketTicker, l.asOf ORDER BY l.asOf

--SELECT l.marketTicker, sl.originationDate, count(1), sum(balance), sum(balance * fha_eligible) / sum(CASE WHEN fha_eligible IS NULL THEN 0.0 ELSE balance END) as wavg_pct_fha_eligible FROM #FHL_fha_eligibility l JOIN #FHL_LoanHist lh ON l.loanSeqNum = lh.loanSeqNum AND l.asOf = lh.asOf JOIN scale.FHL_Loan sl ON sl.loanSeqNum = lh.loanSeqNum GROUP BY l.marketTicker, sl.originationDate ORDER BY sl.originationDate
--SELECT l.marketTicker, l.asOf, count(1), sum(balance), sum(balance * fha_eligible) / sum(CASE WHEN fha_eligible IS NULL THEN 0.0 ELSE balance END) as wavg_pct_fha_eligible FROM #FHL_fha_eligibility l JOIN #FHL_LoanHist lh ON l.loanSeqNum = lh.loanSeqNum AND l.asOf = lh.asOf GROUP BY l.marketTicker, l.asOf ORDER BY l.asOf


----------------------------------------------------------------------------------------------
-- Check to see if Loans have HARP Eligibility populated
----------------------------------------------------------------------------------------------
        declare   @cnt int 
        SELECT
            @cnt =  count(1)
        FROM #FHL_harp_eligibility  WHERE HARP_eligible IS NULL 

        if (@cnt > 0)  
        BEGIN
            RAISERROR 99999 'Number of FHL Loans with NULL Value for HARP Eligibility: %1!', @cnt
            RETURN
        END  
----------------------------------------------------------------------------------------------
-- Check to see if Loans have Conventional Eligibility populated
----------------------------------------------------------------------------------------------
        SELECT
            @cnt =  count(1)
        FROM #FHL_conventional_eligibility  WHERE conventional_eligible IS NULL

        if (@cnt > 0)  
        BEGIN
            RAISERROR 99999 'Number of FHL Loans with NULL Value for conventional Eligibility: %1!', @cnt
            RETURN
        END  
----------------------------------------------------------------------------------------------
-- Check to see if Loans have FHA Eligibility populated
----------------------------------------------------------------------------------------------
        SELECT
            @cnt =  count(1)
        FROM #FHL_fha_eligibility  WHERE fha_eligible IS NULL

        if (@cnt > 0)  
        BEGIN
            RAISERROR 99999 'Number of FHL Loans with NULL Value for fha Eligibility: %1!', @cnt
            RETURN
		END  
        
----------------------------------------------------------------------------------------------
-- Check to see if FHA Eligible is updated for INVESTOR / 2ND
----------------------------------------------------------------------------------------------
        SELECT
            @cnt =  count(1)
        FROM
            #FHL_fha_eligibility e
        JOIN 
            fhl.PIV_Loan cl ON e.loanSeqNum = cl.loanSeqNum
        WHERE
            fha_eligible > 0.0
        AND
            cl.occType in ('2ND', 'INV')

        if (@cnt > 0)  
        BEGIN
            RAISERROR 99999 'Number of FHL Loans with INVALID FHA Eligible value updated for INVESTOR / 2ND loans: %1!', @cnt
            RETURN
        END 
        
----------------------------------------------------------------------------------------------
-- Check to see if HARP Eligible is in valid range
----------------------------------------------------------------------------------------------
        SELECT
            @cnt =  count(1)
        FROM
            #FHL_harp_eligibility
        WHERE
            HARP_eligible < 0.0 OR HARP_eligible > 1

        if (@cnt > 0)
        BEGIN
            RAISERROR 99999 'Number of FHL Loans with INVALID Value for HARP Eligibility: %1!', @cnt
            RETURN
        END  

----------------------------------------------------------------------------------------------
-- Check to see if Conventional Eligible is in valid range
----------------------------------------------------------------------------------------------
        SELECT
            @cnt =  count(1)
        FROM
            #FHL_conventional_eligibility
        WHERE
            conventional_eligible < 0.0 OR conventional_eligible > 1

        if (@cnt > 0) 
        BEGIN
            RAISERROR 99999 'Number of FHL Loans with INVALID Value for conventional Eligibility: %1!', @cnt
            RETURN
        END 
        
----------------------------------------------------------------------------------------------
-- Check to see if FHA Eligible is in valid range
----------------------------------------------------------------------------------------------
        SELECT
            @cnt =  count(1)
        FROM
            #FHL_fha_eligibility e
        WHERE
            fha_eligible < 0.0 OR fha_eligible > 1

        if (@cnt > 0) 
        BEGIN
            RAISERROR 99999 'Number of FHL Loans with INVALID Value for fha Eligibility: %1!', @cnt
            RETURN
        END 
        
----------------------------------------------------------------------------------------------
-- Check no duplicates
----------------------------------------------------------------------------------------------
        SELECT
            @cnt =  count(1)
        FROM
            (SELECT loanSeqnum, asOf, count(1) as cnt FROM #FHL_conventional_eligibility GROUP BY loanSeqnum, asOf HAVING count(1) > 1) t

        if (@cnt > 0) 
        BEGIN
            RAISERROR 99999 'Number of duplicates for FHL Loans in Loan Eligibility Table: %1!', @cnt
            RETURN
        END 
       

----------------------------------------------------------------------------------------------
-- Check to see if new loans are loaded into database (need to be commented unless load new data)
----------------------------------------------------------------------------------------------
--     declare @count_previous int
--	 SELECT @count_previous = count(distinct(loanSeqNum))
--	 FROM #FHL_harp_eligibility
	

--	 declare @count_current int
--	 SELECT @count_current = count(distinct(loanSeqNum))
--	 FROM #FHL_harp_eligibility
	 
--	 if (@count_current - @count_previous < 0 )
--        BEGIN
--           RAISERROR 99999 'There is no new loan loading into database for eligibility table. Previous loan count: %1!; Current loan count: %2!', @count_previous, @count_current
 --          RETURN
 --      END 
	   
-- End Tests


-- Load Data into Scale Incentive Table
DELETE FROM scale.FHL_LoanEligibility
FROM scale.FHL_LoanEligibility sle, #FHL_harp_eligibility he
WHERE 1=1
    AND sle.loanSeqNum = he.loanSeqNum
    AND sle.asOf = he.asOf
    AND he.marketTicker IN (SELECT tickerName FROM #ticker)
    AND sle.asOf >=  (select asOf from #tmp_asOf)
	AND sle.asOf <=  (select asOf_last from #tmp_asOf)
 ;

INSERT INTO scale.FHL_LoanEligibility (loanSeqNum, asOf, HARP_eligible, conventional_eligible, fha_eligible, REFIEligibleCLTVThreshold)
SELECT
    he.loanSeqNum,
    he.asOf,
    he.HARP_eligible,
    ce.conventional_eligible,
    fe.fha_eligible,
	ret.REFIEligibleCLTVThreshold
FROM #FHL_harp_eligibility he
JOIN #FHL_conventional_eligibility ce
    ON he.loanSeqNum = ce.loanSeqNum
    AND he.asOf = ce.asOf
JOIN #FHL_fha_eligibility fe
    ON fe.loanSeqNum = ce.loanSeqNum
    AND fe.asOf = ce.asOf
JOIN #FHL_refi_eligibility_threshold ret
    ON fe.loanSeqNum =ret.loanSeqNum
WHERE he.marketTicker IN (SELECT tickerName FROM #ticker)
    AND he.asOf >=  (select asOf from #tmp_asOf)
	AND he.asOf <=  (select asOf_last from #tmp_asOf)
;
COMMIT;