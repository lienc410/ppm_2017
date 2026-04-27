-- Freddie Conventional
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
INSERT #ticker SELECT 'FGLMC';   --Conventional Freddie
INSERT #ticker SELECT 'FGT6';     --Jumbo Freddie
INSERT #ticker SELECT 'FGU6';     --CQ Freddie High LTV[105-125]
INSERT #ticker SELECT 'FGU9';     --CR Freddie High LTV[125-150]
COMMIT;

CREATE LF INDEX loan_tickerName_idx ON #ticker(tickerName);
COMMIT;

------------------------------------------------------
-- Assigning harp Pct of 100 for HARPed Loans
-- Assigning harp Pct of 0 for Non-HARPed Loans
-- NULL to Loans which are Unknown and have an MHA-ELIGIBLE Status
------------------------------------------------------
DROP TABLE IF EXISTS #FHL_HARPStatus;
SELECT
    loanSeqNum,
    marketTicker,
    CASE 
        WHEN ( ( HARPStatus = 'HARP')  OR  ( HARPStatus = 'Unknown' and MHAStatus = 'MHA-ELIGIBLE')) THEN 100.0
        WHEN ( HARPStatus IN ('< 2009-06', 'NON-HARP', 'N/A')) THEN 0.0
        ELSE NULL
    END as percentHARPed
INTO #FHL_HARPStatus
FROM fhl.PIV_Loan l
JOIN #ticker tk
    ON l.marketTicker = tk.tickerName
;

COMMIT;
CREATE HG INDEX loan_id_idx ON #FHL_HARPStatus(loanSeqNum);
CREATE LF INDEX ticker_idx ON #FHL_HARPStatus(marketTicker);
COMMIT;

-----------------------------------------------------------------------
-- Update PIV_Loan with percentHARPed for Jumbo and High-LTV
----------------------------------------------------------------------- 
UPDATE #FHL_HARPStatus l
SET percentHARPed = 0.0
WHERE marketTicker = 'FGT6'
;
UPDATE #FHL_HARPStatus l
SET percentHARPed = 100.0
WHERE marketTicker in ('FGU6','FGU9')
;
COMMIT;



-- Tests
----------------------------------------------------------------------------------------------
-- Check to see if Loans have  NULL percentHARPed
----------------------------------------------------------------------------------------------
        declare   @cnt int
        SELECT
            @cnt =  count(1)
        FROM #FHL_HARPStatus  WHERE percentHARPed IS NULL and marketTicker in ( 'FGT6','FGU6','FGU9')

        if (@cnt > 0)
        BEGIN
            RAISERROR 99999 'FHL Jumbo/HILTV Loans with NULL VALUE for  percentHARPed LoanCount : %1!', @cnt
            RETURN
        END
----------------------------------------------------------------------------------------------
-- Check to see if percentHARPed is in valid range
----------------------------------------------------------------------------------------------
        SELECT
            @cnt =  count(1)
        FROM #FHL_HARPStatus  WHERE percentHARPed < 0.0 OR percentHARPed > 100

        if (@cnt > 0)
        BEGIN
            RAISERROR 99999 'FHL Loans with INVALID RANGE VALUE for  percentHARPed LoanCount : %1!', @cnt
            RETURN
        END

-- End Tests



-- Update Scale Loan Table
UPDATE scale.FHL_Loan_Dev
SET percentHARPed = NULL
WHERE marketTicker IN (SELECT tickerName FROM #ticker)
AND version in (select version from  #tmp_version)
;

UPDATE scale.FHL_Loan_Dev l
SET l.percentHARPed = hs.percentHARPed
FROM #FHL_HARPStatus hs
WHERE hs.marketTicker IN (SELECT tickerName FROM #ticker)
    AND l.loanSeqNum = hs.loanSeqNum
    AND version in (select version from  #tmp_version)
;

