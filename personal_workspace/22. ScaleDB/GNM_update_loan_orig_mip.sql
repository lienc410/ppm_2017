-- Ginnie
-- Loan Level
-- Part 2 of 6
-- Script to update origination MIP
-- Updates origMIP

INSERT INTO scale.jobstatus(StartTime,JobName,JobStatus)
VALUES (getdate(),'GNM_Loan_Step 2_Update_Origination_MIP','START');
COMMIT;

-- Before execute the script, need to set the appType to run for
DROP TABLE IF EXISTS #tmp_appType;
SELECT '#####APPTYPE#####' AS appType INTO #tmp_appType
--SELECT '9.99' AS appType INTO #tmp_appType
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

-- Create Loan Origination Data
DROP TABLE IF EXISTS #GNM_OrigMIP;
SELECT
    sl.loanSeqNum,
    sl.loanType,
    sl.marketTicker,
    CASE WHEN cl.origTerm IS NULL THEN 360 ELSE cl.origTerm END as origTerm,
    sl.originationDate,
    sl.origLoanSize,
    sl.origLTV,
	cl.ANNMIPPoints as PIV_mip,
    cast(NULL as numeric(8, 4)) as mip_begin
INTO #GNM_OrigMIP
FROM scale.GNM_Loan_DEV sl
JOIN #ticker tk
    ON sl.marketTicker = tk.tickerName
JOIN gnm.PIV_Loan cl
    ON cl.loanSeqNum = sl.loanSeqNum
WHERE 1 =1 
    AND sl.version in (select originationVersion from #tmp_version)
;
COMMIT;
CREATE HG INDEX loan_id_idx ON #GNM_OrigMIP(loanSeqNum);
CREATE LF INDEX origination_date_idx ON #GNM_OrigMIP(originationDate);
CREATE HG INDEX bal_idx ON #GNM_OrigMIP(origLoanSize);
CREATE LF INDEX ltv_idx ON #GNM_OrigMIP(origLTV);
COMMIT;

-- Update Base MIP for grandfather loans
UPDATE #GNM_OrigMIP inc 
SET inc.mip_begin = inc.PIV_mip WHERE inc.PIV_mip in (50.0, 55.0) AND inc.loanType = 'FHA';
COMMIT;

-- Update Base MIP for the rest
UPDATE #GNM_OrigMIP inc 
SET inc.mip_begin = (AnnualMIPPoints_LL_SL * (LTV_H - origLTV) * (LoanSize_H - origLoanSize) + AnnualMIPPoints_LH_SL * (origLTV - LTV_L) * (LoanSize_H - origLoanSize) 
                + AnnualMIPPoints_LL_SH * (LTV_H - origLTV) * (origLoanSize - LoanSize_L) + AnnualMIPPoints_LH_SH * (origLTV - LTV_L) * (origLoanSize - LoanSize_L)
                ) / ((LTV_H - LTV_L) * (LoanSize_H - LoanSize_L))
FROM report.PIV_MIP_Base_Bilinear_Interpolation_25k mip_base
WHERE 1=1
    AND inc.origTerm              >  mip_base.TermBucketStart
	AND inc.origTerm              <= mip_base.TermBucketEnd
	AND inc.origLTV               >  mip_base.LTV_L
	AND inc.origLTV               <= mip_base.LTV_H
	AND inc.origLoanSize          >= mip_base.LoanSize_L
	AND inc.origLoanSize          <= mip_base.LoanSize_H
    AND inc.originationDate       >  mip_base.OriginationStartDate
	AND inc.originationDate       <= mip_base.OriginationEndDate
	AND inc.originationDate       >  mip_base.StartDate
	AND inc.originationDate       <= mip_base.EndDate
    AND inc.loanType = 'FHA'
    AND inc.mip_begin IS NULL;
;
COMMIT;

-- Update MIP for none-FHA loans
--  ignore the amount of orig MIP for VA, PIH and RHS
UPDATE #GNM_OrigMIP l SET l.mip_begin = 0.0
WHERE l.loanType != 'FHA'
;

-- Tests

--SELECT marketTicker, originationDate, count(1), sum(origLoanSize), sum(origLoanSize * mip_begin) / sum(origLoanSize) as wavg_orig_mip FROM #GNM_OrigMIP GROUP BY marketTicker, originationDate HAVING count(1) > 10 ORDER BY originationDate
--SELECT l.marketTicker, asOf, count(1), sum(balance), sum(balance * mip_begin) / sum(balance) as wavg_orig_mip FROM #GNM_OrigMIP l JOIN scale.GNM_LoanHist lh ON l.loanSeqNum = lh.loanSeqNum GROUP BY l.marketTicker, asOf HAVING count(1) > 10 ORDER BY asOf

----------------------------------------------------------------------------------------------
-- Check to see if Loans have  mip_begin IS NULL
----------------------------------------------------------------------------------------------
        declare   @cnt int
        SELECT
            @cnt =  count(1)
        FROM #GNM_OrigMIP  WHERE mip_begin IS NULL

        if (@cnt > 0)
        BEGIN
            RAISERROR 99999 'Number of GNM Loans with NULL VALUE for beginning mip: %1!', @cnt
            RETURN
        END
        
----------------------------------------------------------------------------------------------
-- Check to see if mip_begin is in valid range
----------------------------------------------------------------------------------------------
		SELECT
            @cnt =  count(1)
        FROM #GNM_OrigMIP WHERE mip_begin < 0.0 OR mip_begin > 500

        if (@cnt > 0)
        BEGIN
            RAISERROR 99999 'Number of GNM Loans with INVALID VALUE for beginning mip: %1!', @cnt
            RETURN
        END

-- End Tests


-- Update Scale Loan Table
UPDATE scale.GNM_Loan_Dev
SET origMIP = NULL
WHERE marketTicker IN (SELECT tickerName FROM #ticker)
    AND version IN (SELECT originationVersion from #tmp_version)
;

UPDATE scale.GNM_Loan_Dev l
SET l.origMIP = i.mip_begin
FROM #GNM_OrigMIP i
WHERE i.marketTicker IN (SELECT tickerName FROM #ticker)
    AND l.loanSeqNum = i.loanSeqNum
    AND version IN (SELECT originationVersion from #tmp_version)
;

declare @count_previous int
   
    SELECT @count_previous = count(1)
    FROM scale.GNM_Loan_dev 
	WHERE marketTicker IN (SELECT tickerName FROM #ticker)
	AND version IN (SELECT originationVersion FROM #tmp_version)

declare @count_current int
	 
	 SELECT @count_current = count(1)
	 FROM #GNM_OrigMIP
	 
	 
INSERT INTO scale.JobStatus (EndTime, JobName, JobStatus, #LoansBeforeProcess, #LoansUpdated, #LoansAfterProcess)
    SELECT
     getdate(),
    'GNM_Loan_Step 2_Update_Origination_MIP', 
    'SUCCESS', 
    @count_previous,
    @count_current,
	CASE WHEN(@count_previous>@count_current) THEN @count_previous ELSE @count_current END
;
COMMIT;

