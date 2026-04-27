-- Fannie Conventional
-- Loan Level
-- Part 1 of 7
-- Script to update missing data
-- Updates CLTV, HPA, FICO, etc.


-- Before execute the script, need to set the dates to run for
DROP TABLE IF EXISTS #tmp_asOf;
SELECT CAST('#####ASOF#####' AS DATE) asOf, CAST('#####LAST#####' AS DATE) asOf_last INTO #tmp_asOf
--SELECT CAST ('2012-01-01' AS DATE) asOf,  CAST ('2099-01-01' AS DATE) asOf_last INTO #tmp_asOf
;

-- Before execute the script, need to set the appType to run for
DROP TABLE IF EXISTS #tmp_appType;
SELECT '#####APPTYPE#####' AS appType INTO #tmp_appType
--SELECT '9.98' AS appType INTO #tmp_appType
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
SELECT mvc.tickerName, mvc.appType, mvc.originationVersion_LL as originationVersion 
INTO #tmp_version
FROM scale.ModelVersionConfig mvc
JOIN #tmp_appType tat
     ON mvc.appType = tat.appType
JOIN #ticker tk
     ON mvc.tickerName = tk.tickerName
;
COMMIT;


-- Create Monthly HPI data
-- Requires Extending the Time Series to the latest factor date using an assumption of 3% HPA
DROP TABLE IF EXISTS #HomePriceIndex_monthly;
SELECT asof, 
    NonSeasonAdjIndex as HPIndex
INTO #HomePriceIndex_monthly
FROM hpi.PIV_HomePriceIndexMonthly
WHERE transactionType = 'PURCHASE_ONLY'
AND region = 'USA'
;
DROP TABLE IF EXISTS #HPA_MA;
SELECT
    'USA' as Region,
    t1.asOf,
    t1.HPIndex as HPIndex,
    t2.HPIndex as HPIndex_1YR,
    t3.HPIndex as HPIndex_2YR,
    CASE WHEN t2.HPIndex IS NULL THEN NULL ELSE t1.HPIndex / t2.HPIndex END as HPA_1YR,
    CASE WHEN t3.HPIndex IS NULL THEN NULL ELSE t1.HPIndex / t3.HPIndex END as HPA_2YR
INTO #HPA_MA
FROM #HomePriceIndex_monthly t1
LEFT JOIN #HomePriceIndex_monthly t2
    ON t1.asOf = dateadd(month, 12, t2.asOf)
LEFT JOIN #HomePriceIndex_monthly t3
    ON t1.asOf = dateadd(month, 24, t3.asOf)
;
COMMIT;

CREATE LF INDEX asOf_idx ON #HPA_MA(asOf);
COMMIT;

DELETE FROM #HPA_MA WHERE HPA_1YR IS NULL;
COMMIT;

DELETE FROM #HPA_MA WHERE HPA_2YR IS NULL;
COMMIT;

DROP TABLE IF EXISTS #HPI_Earliest;
SELECT
    min(asOf) as hpi_earliest_date,
    cast(NULL as numeric(8, 4)) as hpi_earliest_value
INTO #HPI_Earliest
FROM #HPA_MA
WHERE Region = 'USA'
;
COMMIT;

UPDATE #HPI_Earliest he SET he.hpi_earliest_value = hpi.HPIndex
FROM #HPA_MA hpi
WHERE he.hpi_earliest_date = hpi.asOf
    AND Region = 'USA'
;
COMMIT;


-- Create Loan Origination Data
DROP TABLE IF EXISTS #FNM_Loan;
SELECT
    l.loanSeqNum,
    l.marketTicker,
    convert(date, convert(char(8), calcOrigMonth_LL * 100 + 1)) as originationDate,
    CASE WHEN originalLoanAmount = -999 THEN NULL ELSE originalLoanAmount END as origLoanSize,
    CASE WHEN numUnits IS NULL OR numUnits = -999 THEN 1 ELSE numUnits END as numberUnits,
    CASE WHEN cs = -999 THEN NULL ELSE cs END as origFICO,
    CASE WHEN origLTV = -999  OR origLTV < 0 THEN NULL ELSE origLTV END as origLTV,
    CASE WHEN dti = -999 THEN NULL ELSE dti END as dti,
    CASE WHEN origNoteRate = -999 THEN NULL ELSE origNoteRate END as origNoteRate,
    CASE WHEN pctMtgIns IS NOT NULL AND pctMtgIns > 0 THEN pctMtgIns ELSE 0.0 END as miLevel,
    cast(NULL as numeric(10, 4)) as HPI_orig
INTO #FNM_Loan
FROM fnm.sec p
JOIN #ticker tk
    ON p.marketTicker = tk.tickerName
JOIN fnm.PIV_Loan l
    ON p.issueId = l.issueId
WHERE 1=1
    AND p.collateralType = 'LOAN'
    AND originalLoanAmount > 0.01
;

COMMIT;
CREATE HG INDEX loan_id_idx ON #FNM_Loan(loanSeqNum);
CREATE LF INDEX orig_date_idx ON #FNM_Loan(originationDate);
CREATE LF INDEX ticker_idx ON #FNM_Loan(marketTicker);
COMMIT;


-- Update HPI at Origination
UPDATE #FNM_Loan l SET l.HPI_orig = hpi.HPIndex
FROM #HPA_MA hpi
WHERE l.originationDate = hpi.asOf
    AND hpi.Region = 'USA'
;
UPDATE #FNM_Loan l SET l.HPI_orig = he.hpi_earliest_value * power(1 + 3.0 / 100.0, -(datediff(MONTH, l.originationDate, he.hpi_earliest_date) / 12.0))
FROM #HPI_Earliest he
WHERE l.HPI_orig IS NULL
;
COMMIT;


-- Create Loan Historical Data
DROP TABLE IF EXISTS #FNM_LoanHist;
SELECT
    l.loanSeqNum ,
    l.marketTicker,
    lh.asOf as asOf,
    CASE WHEN lh.schambalance IS NULL THEN lh.currentRpb ELSE lh.schambalance END as balance,
    1.0 - (POWER(1.0 + l.origNoteRate / 1200.0, lh.loanAge) - 1.0) / (POWER(1.0 + l.origNoteRate / 1200.0, 360) - 1.0) as factor,
    CASE WHEN cltv = -999 or cltv<0 THEN NULL ELSE cltv END as cltv,
    CASE WHEN sato = -999 THEN NULL ELSE sato END as sato,
    cast(NULL as numeric(10, 4)) as HPA,
    cast(NULL as numeric(10, 4)) as HPI,
    cast(NULL as numeric(10, 4)) as HPA_1YR,
    cast(NULL as numeric(10, 4)) as HPA_2YR
INTO #FNM_LoanHist
FROM #FNM_Loan l
JOIN 
(
    SELECT loanSeqNum, asOf, schamBalance, currentRpb, loanAge, cltv, sato FROM fnm.PIV_Derived_LoanHist
    UNION ALL
    SELECT loanSeqNum, asOf, schamBalance, currentRpb, loanAge, cltv_currentBalance AS cltv, sato FROM fnm.PIV_LoanHist WHERE asOf >= '20140101'
   
) lh
    ON l.loanSeqNum = lh.loanSeqNum
WHERE 1=1
    AND balance > 0.01
    AND year(lh.asOf) >= (select year(asOf) from #tmp_asOf)
	AND year(lh.asOf) <= (select year(asOf_last) from #tmp_asOf)
;
COMMIT;

CREATE HG INDEX loan_id_idx ON #FNM_LoanHist(loanSeqNum);
CREATE LF INDEX begin_date_idx ON #FNM_LoanHist(asOf);
CREATE LF INDEX ticker_idx ON #FNM_LoanHist(marketTicker);
COMMIT;



-- Update HPA_XYR and HPI
UPDATE #FNM_LoanHist perf SET perf.HPA_2YR = hpi.HPA_2YR, perf.HPA_1YR = hpi.HPA_1YR, perf.HPI = hpi.HPIndex
FROM #HPA_MA hpi
WHERE perf.asOf = hpi.asOf 
    AND hpi.Region = 'USA'
;


-- Update FICO, OLTV
-- Create unbiased estimates based on origination date
  
  -- FICO
DROP TABLE IF EXISTS #FNM_OrigDate_FICO;
SELECT
    year(originationDate) as origYear,
    sum(origLoanSize * origFICO) / sum(origLoanSize) as WAVG_FICO,
    sum(origLoanSize) as sum_ls
INTO #FNM_OrigDate_FICO
FROM #FNM_Loan p
WHERE origFICO IS NOT NULL
GROUP BY origYear
HAVING sum_ls > 10000000
;
COMMIT;

UPDATE #FNM_Loan l SET l.origFICO = o.WAVG_FICO
FROM #FNM_OrigDate_FICO o
WHERE year(l.originationDate) = o.origYear
    AND l.origFICO IS NULL 
;

UPDATE #FNM_Loan l SET l.origFICO = (
    SELECT sum(origLoanSize * origFICO) / sum(origLoanSize) as WAVG_FICO 
    FROM #FNM_Loan p
    WHERE origFICO IS NOT NULL
    )
WHERE l.origFICO IS NULL 
;

DELETE FROM #FNM_Loan WHERE origFICO IS NULL;
COMMIT;


-- OLTV
UPDATE #FNM_Loan SET origLTV = NULL
WHERE origLTV <= 0
;
COMMIT;

DROP TABLE IF EXISTS #FNM_OrigDate_OLTV;
SELECT
    year(originationDate) as origYear,
    sum(origLoanSize * origLTV) / sum(origLoanSize) as WAVG_OLTV,
    sum(origLoanSize) as sum_ls
INTO #FNM_OrigDate_OLTV
FROM #FNM_Loan p
WHERE origLTV IS NOT NULL
GROUP BY origYear
HAVING sum_ls > 10000000
;
COMMIT;

UPDATE #FNM_Loan l SET l.origLTV = o.WAVG_OLTV
FROM #FNM_OrigDate_OLTV o
WHERE year(l.originationDate) = o.origYear
    AND l.origLTV IS NULL 
;

UPDATE #FNM_Loan l SET l.origLTV = (
    SELECT sum(origLoanSize * origLTV) / sum(origLoanSize) as WAVG_OLTV 
    FROM #FNM_Loan p
    WHERE origLTV IS NOT NULL
    )
WHERE l.origLTV IS NULL 
;
COMMIT;

DELETE FROM #FNM_Loan WHERE origLTV IS NULL;
COMMIT;

-- Update HPA, CLTV
UPDATE #FNM_LoanHist lh SET lh.HPA = lh.HPI / l.HPI_orig
FROM #FNM_Loan l
WHERE lh.loanSeqNum = l.loanSeqNum 
;

DELETE FROM #FNM_LoanHist WHERE HPA is NULL;
COMMIT;

UPDATE #FNM_LoanHist lh SET lh.cltv = l.origLTV * lh.factor / lh.HPA
FROM #FNM_Loan l
WHERE lh.loanSeqNum = l.loanSeqNum 
    AND lh.cltv IS NULL 
;

DELETE FROM #FNM_LoanHist WHERE cltv is NULL;
COMMIT;

UPDATE #FNM_LoanHist lh SET lh.cltv = 0.01
WHERE lh.cltv <= 0
;
COMMIT;



-- Tests
--SELECT marketTicker, convert(date, convert(char(8), calcOrigMonth_LL * 100 + 1)) as originationDate, count(1), sum(originalLoanAmount), avg(originalLoanAmount) as avg_ols FROM fnm.PIV_Loan WHERE originalLoanAmount > 0 AND marketTicker in ('FGLMC', 'FGU6') GROUP BY marketTicker, originationDate HAVING count(1) > 10 ORDER BY originationDate

--SELECT marketTicker, originationDate, count(1), sum(origLoanSize), avg(origLoanSize) as avg_ols FROM #FNM_Loan GROUP BY marketTicker, originationDate HAVING count(1) > 10 ORDER BY originationDate
--SELECT l.marketTicker, asOf, count(1), sum(balance), sum(balance * origLoanSize) / sum(balance) as wavg_ols FROM #FNM_Loan l JOIN #FNM_LoanHist lh ON l.loanSeqNum = lh.loanSeqNum GROUP BY l.marketTicker, asOf HAVING count(1) > 10 ORDER BY asOf

--SELECT marketTicker, originationDate, count(1), sum(origLoanSize), sum(origLoanSize * numberUnits) / sum(origLoanSize) as wavg_units FROM #FNM_Loan GROUP BY marketTicker, originationDate HAVING count(1) > 10 ORDER BY originationDate
--SELECT l.marketTicker, asOf, count(1), sum(balance), sum(balance * numberUnits) / sum(balance) as wavg_units FROM #FNM_Loan l JOIN #FNM_LoanHist lh ON l.loanSeqNum = lh.loanSeqNum GROUP BY l.marketTicker, asOf HAVING count(1) > 10 ORDER BY asOf

--SELECT marketTicker, originationDate, count(1), sum(origLoanSize), sum(origLoanSize * origFICO) / sum(origLoanSize) as wavg_fico FROM #FNM_Loan GROUP BY marketTicker, originationDate HAVING count(1) > 10 ORDER BY originationDate
--SELECT l.marketTicker, asOf, count(1), sum(balance), sum(balance * origFICO) / sum(balance) as wavg_fico FROM #FNM_Loan l JOIN #FNM_LoanHist lh ON l.loanSeqNum = lh.loanSeqNum GROUP BY l.marketTicker, asOf HAVING count(1) > 10 ORDER BY asOf

--SELECT marketTicker, originationDate, count(1), sum(origLoanSize), sum(origLoanSize * origLTV) / sum(origLoanSize) as wavg_oltv FROM #FNM_Loan GROUP BY marketTicker, originationDate HAVING count(1) > 10 ORDER BY originationDate
--SELECT l.marketTicker, asOf, count(1), sum(balance), sum(balance * origLTV) / sum(balance) as wavg_oltv FROM #FNM_Loan l JOIN #FNM_LoanHist lh ON l.loanSeqNum = lh.loanSeqNum GROUP BY l.marketTicker, asOf HAVING count(1) > 10 ORDER BY asOf

--SELECT marketTicker, originationDate, count(1), sum(origLoanSize), sum(origLoanSize * dti) / sum(origLoanSize) as wavg_dti FROM #FNM_Loan GROUP BY marketTicker, originationDate HAVING count(1) > 10 ORDER BY originationDate
--SELECT l.marketTicker, asOf, count(1), sum(balance), sum(balance * dti) / sum(balance) as wavg_dti FROM #FNM_Loan l JOIN #FNM_LoanHist lh ON l.loanSeqNum = lh.loanSeqNum GROUP BY l.marketTicker, asOf HAVING count(1) > 10 ORDER BY asOf

--SELECT marketTicker, originationDate, count(1), sum(origLoanSize), sum(origLoanSize * origNoteRate) / sum(origLoanSize) as wavg_note_rate FROM #FNM_Loan GROUP BY marketTicker, originationDate HAVING count(1) > 10 ORDER BY originationDate
--SELECT l.marketTicker, asOf, count(1), sum(balance), sum(balance * origNoteRate) / sum(balance) as wavg_note_rate FROM #FNM_Loan l JOIN #FNM_LoanHist lh ON l.loanSeqNum = lh.loanSeqNum GROUP BY l.marketTicker, asOf HAVING count(1) > 10 ORDER BY asOf

--SELECT marketTicker, originationDate, count(1), sum(origLoanSize), sum(origLoanSize * miLevel) / sum(origLoanSize) as wavg_mi_level FROM #FNM_Loan GROUP BY marketTicker, originationDate HAVING count(1) > 10 ORDER BY originationDate
--SELECT l.marketTicker, asOf, count(1), sum(balance), sum(balance * miLevel) / sum(balance) as wavg_mi_level FROM #FNM_Loan l JOIN #FNM_LoanHist lh ON l.loanSeqNum = lh.loanSeqNum GROUP BY l.marketTicker, asOf HAVING count(1) > 10 ORDER BY asOf

--SELECT marketTicker, originationDate, count(1), sum(origLoanSize), sum(origLoanSize * HPI_orig) / sum(origLoanSize) as wavg_orig_hpi FROM #FNM_Loan GROUP BY marketTicker, originationDate HAVING count(1) > 10 ORDER BY originationDate
--SELECT l.marketTicker, asOf, count(1), sum(balance), sum(balance * HPI_orig) / sum(balance) as wavg_orig_hpi FROM #FNM_Loan l JOIN #FNM_LoanHist lh ON l.loanSeqNum = lh.loanSeqNum GROUP BY l.marketTicker, asOf HAVING count(1) > 10 ORDER BY asOf

--SELECT l.marketTicker, originationDate, count(1), sum(balance), sum(balance * cltv) / sum(balance) as wavg_cltv FROM #FNM_Loan l JOIN #FNM_LoanHist lh ON l.loanSeqNum = lh.loanSeqNum GROUP BY l.marketTicker, originationDate HAVING count(1) > 10 ORDER BY originationDate
--SELECT marketTicker, asOf, count(1), sum(balance), sum(balance * cltv) / sum(balance) as wavg_cltv FROM #FNM_LoanHist GROUP BY marketTicker, asOf ORDER BY asOf

--SELECT l.marketTicker, originationDate, count(1), sum(balance), sum(balance * hpa) / sum(balance) as wavg_hpa FROM #FNM_Loan l JOIN #FNM_LoanHist lh ON l.loanSeqNum = lh.loanSeqNum GROUP BY l.marketTicker, originationDate HAVING count(1) > 10 ORDER BY originationDate
--SELECT marketTicker, asOf, count(1), sum(balance), sum(balance * hpa) / sum(balance) as wavg_hpa FROM #FNM_LoanHist GROUP BY marketTicker, asOf ORDER BY asOf

----------------------------------------------------------------------------------------------
-- Check to see if Loans have  balance IS NULL OR balance < 0.0
----------------------------------------------------------------------------------------------
        declare   @cnt int
        SELECT
            @cnt =  count(1)
        FROM #FNM_LoanHist  WHERE balance IS NULL OR balance < 0.0

        if (@cnt > 0)
        BEGIN
            RAISERROR 99999 'FNM Loans with INVALID VALUE for Balance LoanCount : %1!', @cnt
            RETURN
        END

----------------------------------------------------------------------------------------------
-- Check to see if Loans have  cltv IS NULL OR cltv < 0.0 OR cltv > 1000
----------------------------------------------------------------------------------------------
        SELECT
            @cnt =  count(1)
        FROM #FNM_LoanHist  WHERE cltv IS NULL OR cltv < 0.0

        if (@cnt > 0)
        BEGIN
            RAISERROR 99999 'FNM Loans with INVALID VALUE for  CLTV LoanCount : %1!', @cnt
            RETURN
        END
----------------------------------------------------------------------------------------------
-- Check to see if Loans have  origLoanSize IS NULL OR origLoanSize <= 0.0 OR origLoanSize > 10000000
----------------------------------------------------------------------------------------------
        SELECT
            @cnt =  count(1)
        FROM #FNM_Loan  WHERE    origLoanSize IS NULL OR origLoanSize <= 0.0 OR origLoanSize > 10000000

        if (@cnt > 0)
        BEGIN
            RAISERROR 99999 'FNM Loans with INVALID VALUE for origLoanSize LoanCount : %1!', @cnt
            RETURN
        END
----------------------------------------------------------------------------------------------
-- Check to see if Loans have   numberUnits IS NULL OR numberUnits <= 0 OR numberUnits > 10
----------------------------------------------------------------------------------------------
        SELECT
            @cnt =  count(1)
        FROM #FNM_Loan  WHERE   numberUnits IS NULL OR numberUnits <= 0 OR numberUnits > 10

        if (@cnt > 0)
        BEGIN
            RAISERROR 99999 'FNM Loans with INVALID VALUE for numberUnits LoanCount : %1!', @cnt
            RETURN
        END
----------------------------------------------------------------------------------------------
-- Check to see if Loans have   origFICO IS NULL OR origFICO <= 0.0 OR origFICO > 950
----------------------------------------------------------------------------------------------
        SELECT
            @cnt =  count(1)
        FROM #FNM_Loan  WHERE   origFICO IS NULL OR origFICO <= 0.0 OR origFICO > 950

        if (@cnt > 0)
        BEGIN
            RAISERROR 99999 'FNM Loans with INVALID VALUE for origFICO LoanCount : %1!', @cnt
            RETURN
        END
----------------------------------------------------------------------------------------------
-- Check to see if Loans have   origLTV IS NULL OR origLTV <= 0.0 OR origLTV > 1000
----------------------------------------------------------------------------------------------
        SELECT
            @cnt =  count(1)
        FROM #FNM_Loan  WHERE   origLTV IS NULL OR origLTV <= 0.0 OR origLTV > 1000

        if (@cnt > 0)
        BEGIN
            RAISERROR 99999 'FNM Loans with INVALID VALUE for origLTV LoanCount : %1!', @cnt
            RETURN
        END
----------------------------------------------------------------------------------------------
-- Check to see if Loans have    origNoteRate IS NULL OR origNoteRate <= 0.0 OR origNoteRate > 20
----------------------------------------------------------------------------------------------
        SELECT
            @cnt =  count(1)
        FROM #FNM_Loan  WHERE    origNoteRate IS NULL OR origNoteRate <= 0.0 OR origNoteRate > 20

        if (@cnt > 0)
        BEGIN
            RAISERROR 99999 'FNM Loans with INVALID VALUE for origNoteRate LoanCount : %1!', @cnt
            RETURN
        END
----------------------------------------------------------------------------------------------
-- Check to see if Loans have   miLevel IS NULL OR miLevel < 0.0 OR miLevel > 100
----------------------------------------------------------------------------------------------
        SELECT
            @cnt =  count(1)
        FROM #FNM_Loan  WHERE   miLevel IS NULL OR miLevel < 0.0 OR miLevel > 100

        if (@cnt > 0)
        BEGIN
            RAISERROR 99999 'FNM Loans with INVALID VALUE for miLevel LoanCount : %1!', @cnt
            RETURN
        END

----------------------------------------------------------------------------------------------
-- Check to see if Loans have  HPI_orig IS NULL OR HPI_orig < 0.0 OR HPI_orig > 1000
----------------------------------------------------------------------------------------------
        SELECT
            @cnt =  count(1)
        FROM #FNM_Loan  WHERE  HPI_orig IS NULL OR HPI_orig < 0.0 OR HPI_orig > 1000

        if (@cnt > 0)
        BEGIN
            RAISERROR 99999 'FNM Loans with INVALID VALUE for HPI_orig LoanCount : %1!', @cnt
            RETURN
        END
----------------------------------------------------------------------------------------------
-- Check to see if Loans have  hpa IS NULL  OR hpa < 0.5 OR hpa > 10
----------------------------------------------------------------------------------------------
        SELECT
            @cnt =  count(1)
        FROM #FNM_LoanHist  WHERE  hpa IS NULL OR hpa < 0.5 OR hpa > 10

        if (@cnt > 0)
        BEGIN
            RAISERROR 99999 'FNM Loans with INVALID VALUE for  HPA LoanCount : %1!', @cnt
            RETURN
        END
----------------------------------------------------------------------------------------------
-- Check to see if Loans have  hpa_2yr IS NULL OR hpa_2yr < 0.50 OR hpa_2yr > 1.5
----------------------------------------------------------------------------------------------
        SELECT
            @cnt =  count(1)
        FROM #FNM_LoanHist  WHERE  hpa_2yr IS NULL OR hpa_2yr < 0.50 OR hpa_2yr > 1.5

        if (@cnt > 0)
        BEGIN
            RAISERROR 99999 'FNM Loans with INVALID VALUE for  HPA_2YR LoanCount : %1!', @cnt
            RETURN
        END

		
----------------------------------------------------------------------------------------------
-- Check to see if new loans are loaded into database (need to be commented unless load new data)
----------------------------------------------------------------------------------------------
--     declare @count_previous int
--	 SELECT @count_previous = count(1)
--	 FROM scale.FNM_Loan_Dev
--	 WHERE marketTicker IN (SELECT tickerName FROM #ticker)
--	 AND version IN (SELECT originationVersion FROM #tmp_version)

--	 declare @count_current int
--	 SELECT @count_current = count(1)
--	 FROM #FNM_Loan
	 
--	 if (@count_current - @count_previous <= 0 )
--        BEGIN
--           RAISERROR 99999 'There is no new loan loading into database. Previous loan count: %1!; Current loan count: %2!', @count_previous, @count_current
--           RETURN
 --      END 
-- End Tests



-- Load Data into Scale Tables

DELETE FROM scale.FNM_Loan_Dev
WHERE marketTicker IN (SELECT tickerName FROM #ticker)
    AND version in (select  originationVersion from #tmp_version)
;


INSERT INTO scale.FNM_Loan_Dev (loanSeqNum, marketTicker, originationDate, origLoanSize, numberUnits, origFICO, origLTV, dti, origNoteRate, miLevel, HPI_orig, version)
SELECT
    loanSeqNum,
    marketTicker,
    originationDate,
    origLoanSize,
    numberUnits,
    origFICO,
    origLTV,
    dti,
    origNoteRate,
    miLevel,
    HPI_orig,
    tpv.originationVersion AS version
FROM #FNM_Loan fl
JOIN #tmp_version tpv
   ON tpv.tickerName = fl.marketTicker
WHERE marketTicker IN (SELECT tickerName FROM #ticker)
;

DELETE FROM scale.FNM_LoanHist
FROM scale.FNM_LoanHist slh, #FNM_LoanHist lh
WHERE 1=1
    AND slh.loanSeqNum = lh.loanSeqNum
    AND slh.asOf = lh.asOf
    AND lh.marketTicker IN (SELECT tickerName FROM #ticker)
    AND slh.asOf >=  (SELECT asOf from #tmp_asOf)
	AND slh.asOf <=  (SELECT asOf_last from #tmp_asOf)
;

INSERT INTO scale.FNM_LoanHist (loanSeqNum, asOf,balance, cltv, hpa)
SELECT
    loanSeqNum,
    asOf,
    balance,
    cltv,
    hpa
FROM #FNM_LoanHist
WHERE marketTicker IN (SELECT tickerName FROM #ticker)
    AND asOf >=  (SELECT asOf from #tmp_asOf)
	AND asOf <=  (SELECT asOf_last from #tmp_asOf)
;
