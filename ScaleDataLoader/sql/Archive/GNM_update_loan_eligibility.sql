-- Ginnie
-- Loan Level
-- Part 4 of 6
-- Script to update the eligibility metrics
-- Updates conventional_eligible

-- Before execute the script, need to set the dates to run for
DROP TABLE IF EXISTS #tmp_asOf;
SELECT CAST('#####ASOF#####' AS DATE) asOf INTO #tmp_asOf
--SELECT CAST ('1979-05-01' AS DATE) asOf INTO #tmp_asOf
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
INSERT #ticker SELECT 'GNSF', 'GINNIE_30YR';   -- Ginnie 1
INSERT #ticker SELECT 'G2SF', 'GINNIE_30YR';   -- Ginnie 2
INSERT #ticker SELECT 'G2SF-JM', 'GINNIE_30YR';-- Ginnie Jumbo
COMMIT;

CREATE LF INDEX loan_tickerName_idx ON #ticker(tickerName);
COMMIT;

-- Update Conventional Eligibility
DROP TABLE IF EXISTS #GNM_conventional_eligibility;
SELECT distinct
    sl.marketTicker,
    sl.loanSeqNum,
    slh.asOf,
    CASE WHEN cl.numUnits IS NULL OR cl.numUnits = -999 THEN 1 ELSE cl.numUnits END as numberOfUnits,
    ConvCost = pmi_base.PMI + pmi_occ.PMI + pmi_size.PMI + llpa_base.LLPA + llpa_ltv.LLPA + llpa_admc.LLPA + llpa_occ.LLPA + llpa_unit.LLPA + llpa_size.LLPA,
    ConvCostValidility = CASE WHEN sl.origFICO IS NULL OR slh.cltv IS NULL OR numberOfUnits IS NULL OR slh.currentBalance IS NULL THEN 'N' ELSE 'Y' END,
    CASE 
        WHEN ConvCostValidility = 'Y' THEN 
            CASE 
                WHEN ConvCost IS NULL THEN 0
                ELSE 1
            END
        ELSE NULL 
    END as conventional_eligible
INTO #GNM_conventional_eligibility
FROM scale.GNM_Loan_DEV sl
JOIN gnm.PIV_Loan cl ON cl.loanSeqNum = sl.loanSeqNum
JOIN #ticker tk
    ON sl.marketTicker = tk.tickerName
JOIN scale.GNM_LoanHist slh
    ON sl.loanSeqNum = slh.loanSeqNum
    
-- LLPAs
LEFT OUTER JOIN report.PIV_LLPA_Base_Raw llpa_base
            ON slh.asOf >= llpa_base.startDate AND slh.asOf < llpa_base.endDate
            AND sl.origFICO >= llpa_base.FicoStart AND sl.origFICO < llpa_base.FicoEnd
            AND slh.cltv > llpa_base.LtvStart AND slh.cltv <= llpa_base.LtvEnd
LEFT OUTER JOIN report.PIV_LLPA_LTV_Raw llpa_ltv 
            ON slh.asOf >= llpa_ltv.startDate AND slh.asOf < llpa_ltv.endDate
            AND slh.cltv > llpa_ltv.LtvStart AND slh.cltv <= llpa_ltv.LtvEnd
LEFT OUTER JOIN report.PIV_LLPA_ADMC_Raw llpa_admc
            ON slh.asOf >= llpa_admc.startDate AND slh.asOf < llpa_admc.endDate
LEFT OUTER JOIN report.PIV_LLPA_Occupancy_Raw llpa_occ
            ON slh.asOf >= llpa_occ.startDate AND slh.asOf < llpa_occ.endDate
            AND 'OWNER' = llpa_occ.occType
            AND slh.cltv > llpa_occ.LtvStart AND slh.cltv <= llpa_occ.LtvEnd
LEFT OUTER JOIN report.PIV_LLPA_Units_Raw llpa_unit
            ON slh.asOf >= llpa_unit.startDate AND slh.asOf < llpa_unit.endDate
            AND numberOfUnits = llpa_unit.numUnits
            AND slh.cltv > llpa_unit.LtvStart AND slh.cltv <= llpa_unit.LtvEnd
LEFT OUTER JOIN report.PIV_LLPA_LoanSize_Raw llpa_size
            ON slh.asOf >= llpa_size.startDate AND slh.asOf < llpa_size.endDate
            AND slh.currentBalance >= llpa_size.LoanSizeStart AND slh.currentBalance < llpa_size.LoanSizeEnd
            AND slh.cltv > llpa_size.LtvStart AND slh.cltv <= llpa_size.LtvEnd
            
-- PMIs
LEFT OUTER JOIN report.PIV_PMI_Base_Raw pmi_base
            ON slh.asOf >= pmi_base.startDate AND slh.asOf < pmi_base.endDate
            AND sl.origFICO >= pmi_base.FICOBucketStart AND sl.origFICO < pmi_base.FICOBucketEnd
            AND slh.cltv > pmi_base.LTVBucketStart AND slh.cltv <= pmi_base.LTVBucketEnd	
            AND pmi_base.LoanPurpose = 'REFI'	
LEFT OUTER JOIN report.PIV_PMI_Occupancy_Raw pmi_occ
            ON slh.asOf >= pmi_occ.startDate AND slh.asOf < pmi_occ.endDate
            AND 'OWNER' = pmi_occ.occType
            AND sl.origFICO >= pmi_occ.FICOBucketStart AND sl.origFICO < pmi_occ.FICOBucketEnd
            AND slh.cltv > pmi_occ.LTVStart AND slh.cltv <= pmi_occ.LTVEnd	
LEFT OUTER JOIN report.PIV_PMI_LoanSize_Raw pmi_size
            ON slh.asOf >= pmi_size.startDate AND slh.asOf < pmi_size.endDate
            AND sl.origFICO >= pmi_size.FICOBucketStart AND sl.origFICO < pmi_size.FICOBucketEnd
            AND slh.cltv > pmi_size.LTVStart AND slh.cltv <= pmi_size.LTVEnd	
            AND slh.currentBalance >= pmi_size.LoanSizeStart AND slh.currentBalance < pmi_size.LoanSizeEnd
WHERE 1=1
    AND slh.asOf >= (select asOf from #tmp_asOf)
	AND sl.version = (select version from #tmp_version)
;
COMMIT;

CREATE HG INDEX loan_id_idx ON #GNM_conventional_eligibility(loanSeqNum);
CREATE LF INDEX asof_date_idx ON #GNM_conventional_eligibility(asOf);
CREATE LF INDEX ticker_idx ON #GNM_conventional_eligibility(marketTicker);
COMMIT;

-- Tests

--SELECT l.marketTicker, sl.originationDate, count(1), sum(currentBalance), sum(currentBalance * conventional_eligible) / sum(CASE WHEN conventional_eligible IS NULL THEN 0.0 ELSE currentBalance END) as wavg_pct_conv_eligible FROM #GNM_conventional_eligibility l JOIN scale.GNM_LoanHist lh ON l.loanSeqNum = lh.loanSeqNum AND l.asOf = lh.asOf JOIN scale.GNM_Loan sl ON sl.loanSeqNum = lh.loanSeqNum GROUP BY l.marketTicker, sl.originationDate ORDER BY sl.originationDate
--SELECT l.marketTicker, l.asOf, count(1), sum(currentBalance), sum(currentBalance * conventional_eligible) / sum(CASE WHEN conventional_eligible IS NULL THEN 0.0 ELSE currentBalance END) as wavg_pct_conv_eligible FROM #GNM_conventional_eligibility l JOIN scale.GNM_LoanHist lh ON l.loanSeqNum = lh.loanSeqNum AND l.asOf = lh.asOf GROUP BY l.marketTicker, l.asOf ORDER BY l.asOf

----------------------------------------------------------------------------------------------
-- Check to see if Loans have Conventional Eligibility populated
----------------------------------------------------------------------------------------------
        declare   @cnt int
        SELECT
            @cnt =  count(1)
        FROM #GNM_conventional_eligibility  WHERE conventional_eligible IS NULL

        if (@cnt > 0)  
        BEGIN
            RAISERROR 99999 'GNM Loans with NULL Conventional Eligibility LoanCount : %1!', @cnt
            RETURN
        END 
        
----------------------------------------------------------------------------------------------
-- Check to see if Conventional Eligible is in valid range
----------------------------------------------------------------------------------------------
        SELECT
            @cnt =  count(1)
        FROM
            #GNM_conventional_eligibility
        WHERE
            conventional_eligible < 0.0 OR conventional_eligible > 1

        if (@cnt > 0)  
        BEGIN
            RAISERROR 99999 'GNM Loans with Invalid Conventional Eligibile Range LoanCount : %1!', @cnt
            RETURN
        END 
----------------------------------------------------------------------------------------------
-- Check no duplicates
----------------------------------------------------------------------------------------------
        SELECT
            @cnt =  count(1)
        FROM
            (SELECT loanSeqnum, asOf, count(1) as cnt FROM #GNM_conventional_eligibility GROUP BY loanSeqnum, asOf HAVING count(1) > 1) t

        if (@cnt > 0) 
        BEGIN
            RAISERROR 99999 'FHL Loans with Invalid FHA Eligibile Range LoanCount : %1!', @cnt
            RETURN
        END 
----------------------------------------------------------------------------------------------
-- Check to see if count of current month changes in a noticeable amount compare with previous month
----------------------------------------------------------------------------------------------
        declare   @cnt_previous int
        SELECT
            @cnt =  count(1)
        FROM #GNM_conventional_eligibility WHERE asof = (SELECT asOf FROM #tmp_asOf)

        SELECT
            @cnt_previous =  count(1)
        FROM scale.GNM_LoanEligibility WHERE asof = (SELECT dateadd(month, -1, asOf) FROM #tmp_asOf)
        
        if (@cnt - @cnt_previous > 0.1 * @cnt_previous OR @cnt_previous - @cnt > 0.1 * @cnt_previous)
        BEGIN
            RAISERROR 99999 'GNM_LoanEligibility with INVALID COUNT compare with previous month. Currnt: %1!; Previous: %2!', @cnt, @cnt_previous
            RETURN
        END 
-- End Tests



-- Load Data into Scale Incentive Table
DELETE FROM scale.GNM_LoanEligibility
FROM scale.GNM_LoanEligibility sle, #GNM_conventional_eligibility ce
WHERE 1=1
    AND sle.loanSeqNum = ce.loanSeqNum
    AND sle.asOf = ce.asOf
    AND ce.marketTicker IN (SELECT tickerName FROM #ticker)
    AND sle.asOf >=  (select asOf from #tmp_asOf)
;

INSERT INTO scale.GNM_LoanEligibility (loanSeqNum, asOf, conventional_eligible)
SELECT
    loanSeqNum,
    asOf,
    conventional_eligible
FROM #GNM_conventional_eligibility
WHERE marketTicker IN (SELECT tickerName FROM #ticker)
    AND asOf >=  (select asOf from #tmp_asOf)
;