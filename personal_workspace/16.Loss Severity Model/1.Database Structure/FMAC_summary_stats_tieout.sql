-- Acquisition File
SELECT
    --YEAR(originationDate) as Vintage,
    --YEAR(firstPaymtDt) as Vintage,
    CASE WHEN substring(LoanId, 3, 2) = '99' THEN 1999 ELSE convert(INTEGER, '20' || substring(LoanId, 3, 2)) END as Vintage,
    count(1) as LoanCnt,
    sum(originalLoanAmount) / 1000000000.0 as 'OrigUPB(BB)',
    avg(originalLoanAmount) as WavgUPB,
    sum(originalLoanAmount * FICO) / sum(CASE WHEN FICO IS NULL THEN 0.0 ELSE originalLoanAmount END) as WavgFICO,
    sum(originalLoanAmount * cltv) / sum(CASE WHEN cltv IS NULL THEN 0.0 ELSE originalLoanAmount END) as WavgCLTV,
    sum(originalLoanAmount * origLTV) / sum(CASE WHEN origLTV IS NULL THEN 0.0 ELSE originalLoanAmount END) as WavgLTV,
    sum(originalLoanAmount * dti) / sum(CASE WHEN dti IS NULL THEN 0.0 ELSE originalLoanAmount END) as WavgDTI,
    sum(originalLoanAmount * coupon) / sum(CASE WHEN coupon IS NULL THEN 0.0 ELSE originalLoanAmount END) as WavgCPN
FROM fhl.LoanLevelHistOriginationData
GROUP BY Vintage
;

-- Performance File (Active Loans)
SELECT 
    --YEAR(originationDate) as Vintage,
    --YEAR(firstPaymtDt) as Vintage,
    CASE WHEN substring(s.LoanId, 3, 2) = '99' THEN 1999 ELSE convert(INTEGER, '20' || substring(s.LoanId, 3, 2)) END as Vintage,
    count(1) as ActiveLoanCnt
FROM fhl.LoanLevelHistOriginationData s
JOIN fhl.LoanLevelHistMonthlyPerformData d
    ON s.LoanId = d.LoanId
    AND d.asOf = '2014-09-01'
GROUP BY Vintage
ORDER BY Vintage
;

-- Performance File (Transition Data)
SELECT
    --YEAR(originationDate) as Vintage,
    --YEAR(firstPaymtDt) as Vintage,
    CASE WHEN substring(s.LoanId, 3, 2) = '99' THEN 1999 ELSE convert(INTEGER, '20' || substring(s.LoanId, 3, 2)) END as Vintage,
    sum(CASE WHEN zeroBalanceCode IN (1, 6) THEN 1.0 ELSE 0.0 END) as Prepaid,
    sum(CASE WHEN zeroBalanceCode IN (3, 9) THEN 1.0 ELSE 0.0 END) as `Default`,
    --sum(CASE WHEN zeroBalanceCode IS NULL THEN 1.0 ELSE 0.0 END) as `Active`,
    sum(CASE WHEN zeroBalanceCode IN (3, 9) AND repurchaseFlag = 'Y' THEN 1.0 ELSE 0.0 END) as Repo_Post_DF,
    sum(CASE WHEN delinqStatus IN ('9', 'R') THEN 1.0 ELSE 0.0 END) as Ever_D180,
    sum(CASE WHEN delinqStatus IN ('9', 'R') OR zeroBalanceCode IN (3, 9) THEN 1.0 ELSE 0.0 END) as D180_DF,
    sum(CASE WHEN loanModFlag = 'Y' THEN 1.0 ELSE 0.0 END) as Mods
FROM fhl.LoanLevelHistOriginationData s
JOIN fhl.LoanLevelHistMonthlyPerformData d
    ON s.LoanId = d.LoanId
GROUP BY Vintage
;

-- Performance File (D180 Loans)
SELECT
    --YEAR(originationDate) as Vintage,
    CASE WHEN substring(s.LoanId, 3, 2) = '99' THEN 1999 ELSE convert(INTEGER, '20' || substring(s.LoanId, 3, 2)) END as Vintage,
    count(distinct s.LoanId) as D180_Cnt
FROM fhl.LoanLevelHistOriginationData s
JOIN fhl.LoanLevelHistMonthlyPerformData d
    ON s.LoanId = d.LoanId
WHERE delinqStatus IN ('9','R')
GROUP BY Vintage
;

-- Performance File (D180 Loans)
SELECT
    --YEAR(originationDate) as Vintage,
    CASE WHEN substring(s.LoanId, 3, 2) = '99' THEN 1999 ELSE convert(INTEGER, '20' || substring(s.LoanId, 3, 2)) END as Vintage,
    count(distinct s.LoanId) as D180_Cnt
FROM fhl.LoanLevelHistOriginationData s
JOIN fhl.LoanLevelHistMonthlyPerformData d
    ON s.LoanId = d.LoanId
WHERE zeroBalanceCode IN (3, 9) AND delinqStatus NOT IN ('9','R')
GROUP BY Vintage
;



