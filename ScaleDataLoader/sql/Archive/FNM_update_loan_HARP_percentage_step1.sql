-- Fannie Conventional
-- Loan Level
-- Part 2 of 7
-- Script to update HARPed Percentage (Step 1)
-- Updates percentHARPed

-- Before execute the script, need to set the version to run for
DROP TABLE IF EXISTS #tmp_version;
SELECT CAST ('2.50' AS varchar(5)) version INTO #tmp_version
;
-- Before execute the script, need to set the tickers
DROP TABLE IF EXISTS #ticker;
CREATE TABLE #ticker(
    tickerName varchar(20)
)
;
INSERT #ticker SELECT 'FNCL';   --Conventional Fannie
INSERT #ticker SELECT 'FNCK';     --Jumbo Fannie
INSERT #ticker SELECT 'FNCQ30';     --CQ Fannie High LTV[105-125]
INSERT #ticker SELECT 'FNCR';     --CR Fannie High LTV[125-150]
COMMIT;

CREATE LF INDEX loan_tickerName_idx ON #ticker(tickerName);
COMMIT;

------------------------------------------------------
-- Assigning harp Pct of 100 for HARPed Loans
-- Assigning harp Pct of 0 for Non-HARPed Loans
-- NULL to Loans which are Unknown and have an MHA-ELIGIBLE Status
------------------------------------------------------
DROP TABLE IF EXISTS #FNM_HARPStatus;
SELECT
    loanSeqNum,
    marketTicker,
    CASE 
        WHEN ( ( HARPStatus = 'HARP')  OR  ( HARPStatus = 'Unknown' and MHAStatus = 'MHA-ELIGIBLE')) THEN 100.0
        WHEN ( HARPStatus IN ('< 2009-06', 'NON-HARP', 'N/A')) THEN 0.0
        ELSE NULL
    END as percentHARPed
INTO #FNM_HARPStatus
FROM fnm.PIV_Loan l
JOIN #ticker tk
    ON l.marketTicker = tk.tickerName
;

COMMIT;
CREATE HG INDEX loan_id_idx ON #FNM_HARPStatus(loanSeqNum);
CREATE LF INDEX ticker_idx ON #FNM_HARPStatus(marketTicker);
COMMIT;

-----------------------------------------------------------------------
-- Update PIV_Loan with percentHARPed for Jumbo and High-LTV
----------------------------------------------------------------------- 
UPDATE #FNM_HARPStatus l
SET percentHARPed = 0.0
WHERE marketTicker = 'FNCK'
;
UPDATE #FNM_HARPStatus l
SET percentHARPed = 100.0
WHERE marketTicker in ('FNCQ30','FNCR')
;
COMMIT;



-- Tests
----------------------------------------------------------------------------------------------
-- Check to see if Loans have  NULL percentHARPed
----------------------------------------------------------------------------------------------
        declare   @cnt int
        SELECT
            @cnt =  count(1)
        FROM #FNM_HARPStatus  WHERE percentHARPed IS NULL and marketTicker in ( 'FNCK','FNCQ30','FNCR')

        if (@cnt > 0)
        BEGIN
            RAISERROR 99999 'FNM Jumbo/HILTV Loans with NULL VALUE for  percentHARPed LoanCount : %1!', @cnt
            RETURN
        END
----------------------------------------------------------------------------------------------
-- Check to see if percentHARPed is in valid range
----------------------------------------------------------------------------------------------
        SELECT
            @cnt =  count(1)
        FROM #FNM_HARPStatus  WHERE percentHARPed < 0.0 OR percentHARPed > 100

        if (@cnt > 0)
        BEGIN
            RAISERROR 99999 'FNM Loans with INVALID RANGE VALUE for  percentHARPed LoanCount : %1!', @cnt
            RETURN
        END

-- End Tests



-- Update Scale Loan Table
UPDATE scale.FNM_Loan_Dev
SET percentHARPed = NULL
WHERE marketTicker IN (SELECT tickerName FROM #ticker)
    AND version = (select version from #tmp_version)
;

UPDATE scale.FNM_Loan_Dev l
SET l.percentHARPed = hs.percentHARPed
FROM #FNM_HARPStatus hs
WHERE hs.marketTicker IN (SELECT tickerName FROM #ticker)
    AND l.loanSeqNum = hs.loanSeqNum
    AND l.version = (select version from #tmp_version)
;

