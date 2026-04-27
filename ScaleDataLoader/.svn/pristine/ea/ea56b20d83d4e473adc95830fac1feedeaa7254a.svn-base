-- Count Tests (should have same count1 for all asOf tables)

SELECT count(1) FROM scale.FNM_Loan;
SELECT count(distinct loanSeqNum) FROM scale.FNM_Loan;

SELECT count(distinct loanSeqNum) FROM scale.FNM_LoanHist;
SELECT count(distinct loanSeqNum) FROM scale.FNM_LoanEligibility;
SELECT count(distinct loanSeqNum) FROM scale.FNM_LoanIncentive WHERE version = '2.00';
SELECT count(distinct loanSeqNum) FROM scale.FNM_LoanBurnout WHERE version = '2.00';

SELECT count(1) FROM scale.FNM_LoanHist;
SELECT count(1) FROM scale.FNM_LoanEligibility;
SELECT count(1) FROM scale.FNM_LoanIncentive WHERE version = '2.00';
SELECT count(1) FROM scale.FNM_LoanBurnout WHERE version = '2.00';

SELECT version, count(1) FROM scale.FNM_LoanIncentive GROUP BY version;
SELECT version, count(1) FROM scale.FNM_LoanBurnout GROUP BY version;


-- Uniqueness Tests (Should all be 0 rows)

SELECT loanSeqNum, asOf, count(1) as cnt FROM scale.FNM_LoanHist GROUP BY loanSeqNum, asOf HAVING cnt > 1;
SELECT loanSeqNum, asOf, count(1) as cnt FROM scale.FNM_LoanEligibility GROUP BY loanSeqNum, asOf HAVING cnt > 1;
SELECT loanSeqNum, asOf, count(1) as cnt FROM scale.FNM_LoanIncentive WHERE version = '2.00' GROUP BY loanSeqNum, asOf HAVING cnt > 1;
SELECT loanSeqNum, asOf, count(1) as cnt FROM scale.FNM_LoanBurnout WHERE version = '2.00' GROUP BY loanSeqNum, asOf HAVING cnt > 1;


-- Null and Data Validity Tests (Should all be 0 counts)

SELECT count(1) FROM scale.FNM_Loan WHERE origLoanSize IS NULL OR origLoanSize <= 0.0 OR origLoanSize > 10000000
SELECT count(1) FROM scale.FNM_Loan WHERE numberUnits IS NULL OR numberUnits <= 0 OR numberUnits > 10
SELECT count(1) FROM scale.FNM_Loan WHERE origFICO IS NULL OR origFICO <= 0.0 OR origFICO > 900
SELECT count(1) FROM scale.FNM_Loan WHERE origLTV IS NULL OR origLTV <= 0.0 OR origLTV > 1000
SELECT count(1) FROM scale.FNM_Loan WHERE origNoteRate IS NULL OR origNoteRate <= 0.0 OR origNoteRate > 20
SELECT count(1) FROM scale.FNM_Loan WHERE miLevel IS NULL OR miLevel < 0.0 OR miLevel > 80
SELECT count(1) FROM scale.FNM_Loan WHERE HPI_orig IS NULL OR HPI_orig < 0.0 OR HPI_orig > 1000
SELECT count(1) FROM scale.FNM_LoanHist WHERE cltv IS NULL OR cltv <= 0.0 OR cltv > 1000
SELECT count(1) FROM scale.FNM_LoanHist WHERE hpa IS NULL OR hpa < 0.5 OR hpa > 10

SELECT count(1) FROM scale.FNM_Loan WHERE origPMI IS NULL
SELECT count(1) FROM scale.FNM_Loan WHERE origPMI < 0.0 OR origPMI > 500.0

SELECT count(1) FROM scale.FNM_Loan WHERE percentHARPed IS NULL
SELECT count(1) FROM scale.FNM_Loan WHERE percentHARPed < 0.0 OR percentHARPed > 100

SELECT count(1) FROM scale.FNM_LoanEligibility WHERE HARP_eligible IS NULL 
SELECT count(1) FROM scale.FNM_LoanEligibility WHERE conventional_eligible IS NULL
SELECT count(1) FROM scale.FNM_LoanEligibility WHERE fha_eligible IS NULL
SELECT count(1) FROM scale.FNM_LoanEligibility WHERE HARP_eligible < 0.0 OR HARP_eligible > 1
SELECT count(1) FROM scale.FNM_LoanEligibility WHERE conventional_eligible < 0.0 OR conventional_eligible > 1
SELECT count(1) FROM scale.FNM_LoanEligibility WHERE fha_eligible < 0.0 OR fha_eligible > 1

SELECT count(1) FROM scale.FNM_LoanIncentive WHERE conventional_refi_incentive IS NULL
SELECT count(1) FROM scale.FNM_LoanIncentive WHERE fha_refi_incentive IS NULL
SELECT count(1) FROM scale.FNM_LoanIncentive WHERE currLLPA IS NULL
SELECT count(1) FROM scale.FNM_LoanIncentive WHERE currPMI IS NULL
SELECT count(1) FROM scale.FNM_LoanIncentive WHERE currMIP IS NULL
SELECT count(1) FROM scale.FNM_LoanIncentive WHERE conventional_refi_incentive < -2000.0 OR conventional_refi_incentive > 2000.0
SELECT count(1) FROM scale.FNM_LoanIncentive WHERE fha_refi_incentive < -2000.0 OR fha_refi_incentive > 2000.0
SELECT count(1) FROM scale.FNM_LoanIncentive WHERE currLLPA < -100 OR currLLPA > 2000.0
SELECT count(1) FROM scale.FNM_LoanIncentive WHERE currPMI < 0 OR currPMI > 1000.0
SELECT count(1) FROM scale.FNM_LoanIncentive WHERE currMIP < 0 OR currMIP > 500.0

SELECT count(1) FROM scale.FNM_LoanBurnout WHERE burnout IS NULL
SELECT count(1) FROM scale.FNM_LoanBurnout WHERE burnout < 0.0 OR burnout > 30000


-- Time Series Tests

SELECT marketTicker, originationDate, count(1), sum(origLoanSize), avg(origLoanSize) as avg_ols FROM scale.FNM_Loan GROUP BY marketTicker, originationDate HAVING count(1) > 10 ORDER BY originationDate
SELECT l.marketTicker, asOf, count(1), sum(schamBalance), sum(schamBalance * origLoanSize) / sum(schamBalance) as wavg_ols FROM scale.FNM_Loan l JOIN scale.FNM_LoanHist lh ON l.loanSeqNum = lh.loanSeqNum GROUP BY l.marketTicker, asOf HAVING count(1) > 10 ORDER BY asOf

SELECT marketTicker, originationDate, count(1), sum(origLoanSize), sum(origLoanSize * numberUnits) / sum(origLoanSize) as wavg_units FROM scale.FNM_Loan GROUP BY marketTicker, originationDate HAVING count(1) > 10 ORDER BY originationDate
SELECT l.marketTicker, asOf, count(1), sum(schamBalance), sum(schamBalance * numberUnits) / sum(schamBalance) as wavg_units FROM scale.FNM_Loan l JOIN scale.FNM_LoanHist lh ON l.loanSeqNum = lh.loanSeqNum GROUP BY l.marketTicker, asOf HAVING count(1) > 10 ORDER BY asOf

SELECT marketTicker, originationDate, count(1), sum(origLoanSize), sum(origLoanSize * origFICO) / sum(origLoanSize) as wavg_fico FROM scale.FNM_Loan GROUP BY marketTicker, originationDate HAVING count(1) > 10 ORDER BY originationDate
SELECT l.marketTicker, asOf, count(1), sum(schamBalance), sum(schamBalance * origFICO) / sum(schamBalance) as wavg_fico FROM scale.FNM_Loan l JOIN scale.FNM_LoanHist lh ON l.loanSeqNum = lh.loanSeqNum GROUP BY l.marketTicker, asOf HAVING count(1) > 10 ORDER BY asOf

SELECT marketTicker, originationDate, count(1), sum(origLoanSize), sum(origLoanSize * origLTV) / sum(origLoanSize) as wavg_oltv FROM scale.FNM_Loan GROUP BY marketTicker, originationDate HAVING count(1) > 10 ORDER BY originationDate
SELECT l.marketTicker, asOf, count(1), sum(schamBalance), sum(schamBalance * origLTV) / sum(schamBalance) as wavg_oltv FROM scale.FNM_Loan l JOIN scale.FNM_LoanHist lh ON l.loanSeqNum = lh.loanSeqNum GROUP BY l.marketTicker, asOf HAVING count(1) > 10 ORDER BY asOf

SELECT marketTicker, originationDate, count(1), sum(origLoanSize), sum(origLoanSize * dti) / sum(origLoanSize) as wavg_dti FROM scale.FNM_Loan GROUP BY marketTicker, originationDate HAVING count(1) > 10 ORDER BY originationDate
SELECT l.marketTicker, asOf, count(1), sum(schamBalance), sum(schamBalance * dti) / sum(schamBalance) as wavg_dti FROM scale.FNM_Loan l JOIN scale.FNM_LoanHist lh ON l.loanSeqNum = lh.loanSeqNum GROUP BY l.marketTicker, asOf HAVING count(1) > 10 ORDER BY asOf

SELECT marketTicker, originationDate, count(1), sum(origLoanSize), sum(origLoanSize * origNoteRate) / sum(origLoanSize) as wavg_note_rate FROM scale.FNM_Loan GROUP BY marketTicker, originationDate HAVING count(1) > 10 ORDER BY originationDate
SELECT l.marketTicker, asOf, count(1), sum(schamBalance), sum(schamBalance * origNoteRate) / sum(schamBalance) as wavg_note_rate FROM scale.FNM_Loan l JOIN scale.FNM_LoanHist lh ON l.loanSeqNum = lh.loanSeqNum GROUP BY l.marketTicker, asOf HAVING count(1) > 10 ORDER BY asOf

SELECT marketTicker, originationDate, count(1), sum(origLoanSize), sum(origLoanSize * miLevel) / sum(origLoanSize) as wavg_mi_level FROM scale.FNM_Loan GROUP BY marketTicker, originationDate HAVING count(1) > 10 ORDER BY originationDate
SELECT l.marketTicker, asOf, count(1), sum(schamBalance), sum(schamBalance * miLevel) / sum(schamBalance) as wavg_mi_level FROM scale.FNM_Loan l JOIN scale.FNM_LoanHist lh ON l.loanSeqNum = lh.loanSeqNum GROUP BY l.marketTicker, asOf HAVING count(1) > 10 ORDER BY asOf

SELECT marketTicker, originationDate, count(1), sum(origLoanSize), sum(origLoanSize * HPI_orig) / sum(origLoanSize) as wavg_orig_hpi FROM scale.FNM_Loan GROUP BY marketTicker, originationDate HAVING count(1) > 10 ORDER BY originationDate
SELECT l.marketTicker, asOf, count(1), sum(schamBalance), sum(schamBalance * HPI_orig) / sum(schamBalance) as wavg_orig_hpi FROM scale.FNM_Loan l JOIN scale.FNM_LoanHist lh ON l.loanSeqNum = lh.loanSeqNum GROUP BY l.marketTicker, asOf HAVING count(1) > 10 ORDER BY asOf

SELECT l.marketTicker, originationDate, count(1), sum(schamBalance), sum(schamBalance * lh.cltv) / sum(schamBalance) as wavg_cltv FROM scale.FNM_Loan l JOIN scale.FNM_LoanHist lh ON l.loanSeqNum = lh.loanSeqNum GROUP BY l.marketTicker, originationDate HAVING count(1) > 10 ORDER BY originationDate
SELECT marketTicker, lh.asOf, count(1), sum(schamBalance), sum(schamBalance * lh.cltv) / sum(schamBalance) as wavg_cltv FROM scale.FNM_Loan l JOIN scale.FNM_LoanHist lh ON l.loanSeqNum = lh.loanSeqNum GROUP BY marketTicker, lh.asOf ORDER BY lh.asOf

SELECT l.marketTicker, originationDate, count(1), sum(schamBalance), sum(schamBalance * lh.hpa) / sum(schamBalance) as wavg_hpa FROM scale.FNM_Loan l JOIN scale.FNM_LoanHist lh ON l.loanSeqNum = lh.loanSeqNum GROUP BY l.marketTicker, originationDate HAVING count(1) > 10 ORDER BY originationDate
SELECT marketTicker, lh.asOf, count(1), sum(schamBalance), sum(schamBalance * lh.hpa) / sum(schamBalance) as wavg_hpa FROM scale.FNM_Loan l JOIN scale.FNM_LoanHist lh ON l.loanSeqNum = lh.loanSeqNum GROUP BY marketTicker, lh.asOf ORDER BY lh.asOf



SELECT marketTicker, originationDate, count(1), sum(origLoanSize), sum(origLoanSize * origPMI) / sum(origLoanSize) as wavg_orig_pmi FROM scale.FNM_Loan GROUP BY marketTicker, originationDate HAVING count(1) > 10 ORDER BY originationDate
SELECT l.marketTicker, asOf, count(1), sum(schamBalance), sum(schamBalance * origPMI) / sum(schamBalance) as wavg_orig_pmi FROM scale.FNM_Loan l JOIN scale.FNM_LoanHist lh ON l.loanSeqNum = lh.loanSeqNum GROUP BY l.marketTicker, asOf HAVING count(1) > 10 ORDER BY asOf

SELECT marketTicker, originationDate, count(1), sum(origLoanSize), sum(origLoanSize * percentHARPed) / sum(origLoanSize) as wavg_pct_harped FROM scale.FNM_Loan GROUP BY marketTicker, originationDate HAVING count(1) > 10 ORDER BY originationDate
SELECT l.marketTicker, asOf, count(1), sum(schamBalance), sum(schamBalance * percentHARPed) / sum(schamBalance) as wavg_pct_harped FROM scale.FNM_Loan l JOIN scale.FNM_LoanHist lh ON l.loanSeqNum = lh.loanSeqNum GROUP BY l.marketTicker, asOf HAVING count(1) > 10 ORDER BY asOf



SELECT sl.marketTicker, sl.originationDate, count(1), sum(schamBalance), sum(schamBalance * HARP_eligible) / sum(CASE WHEN HARP_eligible IS NULL THEN 0.0 ELSE schamBalance END) as wavg_pct_harp_eligible FROM scale.FNM_Loan sl JOIN scale.FNM_LoanEligibility sle ON sl.loanSeqNum = sle.loanSeqNum JOIN scale.FNM_LoanHist slh ON sle.loanSeqNum = slh.loanSeqNum AND sle.asOf = slh.asOf GROUP BY sl.marketTicker, sl.originationDate ORDER BY sl.originationDate
SELECT sl.marketTicker, sle.asOf, count(1), sum(schamBalance), sum(schamBalance * HARP_eligible) / sum(CASE WHEN HARP_eligible IS NULL THEN 0.0 ELSE schamBalance END) as wavg_pct_harp_eligible FROM scale.FNM_Loan sl JOIN scale.FNM_LoanEligibility sle ON sl.loanSeqNum = sle.loanSeqNum JOIN scale.FNM_LoanHist slh ON sle.loanSeqNum = slh.loanSeqNum AND sle.asOf = slh.asOf GROUP BY sl.marketTicker, sle.asOf ORDER BY sle.asOf

SELECT sl.marketTicker, sl.originationDate, count(1), sum(schamBalance), sum(schamBalance * conventional_eligible) / sum(CASE WHEN conventional_eligible IS NULL THEN 0.0 ELSE schamBalance END) as wavg_pct_conventional_eligible FROM scale.FNM_Loan sl JOIN scale.FNM_LoanEligibility sle ON sl.loanSeqNum = sle.loanSeqNum JOIN scale.FNM_LoanHist slh ON sle.loanSeqNum = slh.loanSeqNum AND sle.asOf = slh.asOf GROUP BY sl.marketTicker, sl.originationDate ORDER BY sl.originationDate
SELECT sl.marketTicker, sle.asOf, count(1), sum(schamBalance), sum(schamBalance * conventional_eligible) / sum(CASE WHEN conventional_eligible IS NULL THEN 0.0 ELSE schamBalance END) as wavg_pct_conventional_eligible FROM scale.FNM_Loan sl JOIN scale.FNM_LoanEligibility sle ON sl.loanSeqNum = sle.loanSeqNum JOIN scale.FNM_LoanHist slh ON sle.loanSeqNum = slh.loanSeqNum AND sle.asOf = slh.asOf GROUP BY sl.marketTicker, sle.asOf ORDER BY sle.asOf

SELECT sl.marketTicker, sl.originationDate, count(1), sum(schamBalance), sum(schamBalance * fha_eligible) / sum(CASE WHEN fha_eligible IS NULL THEN 0.0 ELSE schamBalance END) as wavg_pct_fha_eligible FROM scale.FNM_Loan sl JOIN scale.FNM_LoanEligibility sle ON sl.loanSeqNum = sle.loanSeqNum JOIN scale.FNM_LoanHist slh ON sle.loanSeqNum = slh.loanSeqNum AND sle.asOf = slh.asOf GROUP BY sl.marketTicker, sl.originationDate ORDER BY sl.originationDate
SELECT sl.marketTicker, sle.asOf, count(1), sum(schamBalance), sum(schamBalance * fha_eligible) / sum(CASE WHEN fha_eligible IS NULL THEN 0.0 ELSE schamBalance END) as wavg_pct_fha_eligible FROM scale.FNM_Loan sl JOIN scale.FNM_LoanEligibility sle ON sl.loanSeqNum = sle.loanSeqNum JOIN scale.FNM_LoanHist slh ON sle.loanSeqNum = slh.loanSeqNum AND sle.asOf = slh.asOf GROUP BY sl.marketTicker, sle.asOf ORDER BY sle.asOf



SELECT sl.marketTicker, sl.originationDate, count(1), sum(schamBalance), sum(schamBalance * conventional_refi_incentive) / sum(CASE WHEN conventional_refi_incentive IS NULL THEN 0.0 ELSE schamBalance END) as wavg_conv_incentive FROM scale.FNM_Loan sl JOIN scale.FNM_LoanIncentive sli ON sl.loanSeqNum = sli.loanSeqNum JOIN scale.FNM_LoanHist slh ON slh.loanSeqNum = sli.loanSeqNum AND slh.asOf = sli.asOf WHERE version = '2.00' GROUP BY sl.marketTicker, sl.originationDate ORDER BY sl.originationDate
SELECT sl.marketTicker, slh.asOf, count(1), sum(schamBalance), sum(schamBalance * conventional_refi_incentive) / sum(CASE WHEN conventional_refi_incentive IS NULL THEN 0.0 ELSE schamBalance END) as wavg_conv_incentive FROM scale.FNM_Loan sl JOIN scale.FNM_LoanIncentive sli ON sl.loanSeqNum = sli.loanSeqNum JOIN scale.FNM_LoanHist slh ON slh.loanSeqNum = sli.loanSeqNum AND slh.asOf = sli.asOf WHERE version = '2.00' GROUP BY sl.marketTicker, slh.asOf ORDER BY slh.asOf

SELECT sl.marketTicker, sl.originationDate, count(1), sum(schamBalance), sum(schamBalance * fha_incentive) / sum(CASE WHEN fha_incentive IS NULL THEN 0.0 ELSE schamBalance END) as wavg_fha_incentive FROM scale.FNM_Loan sl JOIN scale.FNM_LoanIncentive sli ON sl.loanSeqNum = sli.loanSeqNum JOIN scale.FNM_LoanHist slh ON slh.loanSeqNum = sli.loanSeqNum AND slh.asOf = sli.asOf WHERE version = '2.00' GROUP BY sl.marketTicker, sl.originationDate ORDER BY sl.originationDate
SELECT sl.marketTicker, slh.asOf, count(1), sum(schamBalance), sum(schamBalance * fha_refi_incentive) / sum(CASE WHEN fha_refi_incentive IS NULL THEN 0.0 ELSE schamBalance END) as wavg_fha_incentive FROM scale.FNM_Loan sl JOIN scale.FNM_LoanIncentive sli ON sl.loanSeqNum = sli.loanSeqNum JOIN scale.FNM_LoanHist slh ON slh.loanSeqNum = sli.loanSeqNum AND slh.asOf = sli.asOf WHERE version = '2.00' GROUP BY sl.marketTicker, slh.asOf ORDER BY slh.asOf

SELECT sl.marketTicker, sl.originationDate, count(1), sum(schamBalance), sum(schamBalance * currLLPA) / sum(CASE WHEN currLLPA IS NULL THEN 0.0 ELSE schamBalance END) as wavg_llpa FROM scale.FNM_Loan sl JOIN scale.FNM_LoanIncentive sli ON sl.loanSeqNum = sli.loanSeqNum JOIN scale.FNM_LoanHist slh ON slh.loanSeqNum = sli.loanSeqNum AND slh.asOf = sli.asOf WHERE version = '2.00' GROUP BY sl.marketTicker, sl.originationDate ORDER BY sl.originationDate
SELECT sl.marketTicker, slh.asOf, count(1), sum(schamBalance), sum(schamBalance * currLLPA) / sum(CASE WHEN currLLPA IS NULL THEN 0.0 ELSE schamBalance END) as wavg_llpa FROM scale.FNM_Loan sl JOIN scale.FNM_LoanIncentive sli ON sl.loanSeqNum = sli.loanSeqNum JOIN scale.FNM_LoanHist slh ON slh.loanSeqNum = sli.loanSeqNum AND slh.asOf = sli.asOf WHERE version = '2.00' GROUP BY sl.marketTicker, slh.asOf ORDER BY slh.asOf

SELECT sl.marketTicker, sl.originationDate, count(1), sum(schamBalance), sum(schamBalance * currPMI) / sum(CASE WHEN currPMI IS NULL THEN 0.0 ELSE schamBalance END) as wavg_pmi FROM scale.FNM_Loan sl JOIN scale.FNM_LoanIncentive sli ON sl.loanSeqNum = sli.loanSeqNum JOIN scale.FNM_LoanHist slh ON slh.loanSeqNum = sli.loanSeqNum AND slh.asOf = sli.asOf WHERE version = '2.00' GROUP BY sl.marketTicker, sl.originationDate ORDER BY sl.originationDate
SELECT sl.marketTicker, slh.asOf, count(1), sum(schamBalance), sum(schamBalance * currPMI) / sum(CASE WHEN currPMI IS NULL THEN 0.0 ELSE schamBalance END) as wavg_pmi FROM scale.FNM_Loan sl JOIN scale.FNM_LoanIncentive sli ON sl.loanSeqNum = sli.loanSeqNum JOIN scale.FNM_LoanHist slh ON slh.loanSeqNum = sli.loanSeqNum AND slh.asOf = sli.asOf WHERE version = '2.00' GROUP BY sl.marketTicker, slh.asOf ORDER BY slh.asOf

SELECT sl.marketTicker, sl.originationDate, count(1), sum(schamBalance), sum(schamBalance * currMIP) / sum(CASE WHEN currMIP IS NULL THEN 0.0 ELSE schamBalance END) as wavg_mip FROM scale.FNM_Loan sl JOIN scale.FNM_LoanIncentive sli ON sl.loanSeqNum = sli.loanSeqNum JOIN scale.FNM_LoanHist slh ON slh.loanSeqNum = sli.loanSeqNum AND slh.asOf = sli.asOf WHERE version = '2.00' GROUP BY sl.marketTicker, sl.originationDate ORDER BY sl.originationDate
SELECT sl.marketTicker, slh.asOf, count(1), sum(schamBalance), sum(schamBalance * currMIP) / sum(CASE WHEN currMIP IS NULL THEN 0.0 ELSE schamBalance END) as wavg_mip FROM scale.FNM_Loan sl JOIN scale.FNM_LoanIncentive sli ON sl.loanSeqNum = sli.loanSeqNum JOIN scale.FNM_LoanHist slh ON slh.loanSeqNum = sli.loanSeqNum AND slh.asOf = sli.asOf WHERE version = '2.00' GROUP BY sl.marketTicker, slh.asOf ORDER BY slh.asOf

SELECT
    marketTicker, 
    originationDate, 
    count(1), 
    sum((CASE 
        WHEN HARP_eligible = 0 AND conventional_eligible = 0 THEN fha_eligible * fha_refi_incentive
        WHEN (HARP_eligible = 1 OR  conventional_eligible = 1) AND fha_eligible = 0 THEN conventional_refi_incentive
        WHEN (HARP_eligible = 1 OR  conventional_eligible = 1) AND fha_eligible = 1 THEN 
            CASE WHEN conventional_refi_incentive >= fha_refi_incentive THEN conventional_refi_incentive ELSE fha_refi_incentive END
        ELSE 0.0 END) * schambalance) / sum(CASE WHEN HARP_eligible > 0 OR conventional_eligible > 0 OR fha_eligible > 0 THEN schambalance ELSE 0.0 END) as refi_incentive_eligible
FROM scale.FNM_Loan sl
JOIN scale.FNM_LoanHist slh
    ON sl.loanSeqNum = slh.loanSeqNum
JOIN scale.FNM_LoanEligibility sle
    ON slh.loanSeqNum = sle.loanSeqNum
    AND slh.asOf = sle.asOf
JOIN scale.FNM_LoanIncentive sli
    ON slh.loanSeqNum = sli.loanSeqNum
    AND slh.asOf = sli.asOf
WHERE 1=1
GROUP BY sl.marketTicker, sl.originationDate
HAVING sum(CASE WHEN HARP_eligible > 0 OR conventional_eligible > 0 OR fha_eligible > 0 THEN schambalance ELSE 0.0 END) > 0.0
ORDER BY sl.marketTicker, sl.originationDate

SELECT
    marketTicker, 
    slh.asOf, 
    count(1), 
    sum((CASE 
        WHEN HARP_eligible = 0 AND conventional_eligible = 0 THEN fha_eligible * fha_refi_incentive
        WHEN (HARP_eligible = 1 OR  conventional_eligible = 1) AND fha_eligible = 0 THEN conventional_refi_incentive
        WHEN (HARP_eligible = 1 OR  conventional_eligible = 1) AND fha_eligible = 1 THEN 
            CASE WHEN conventional_refi_incentive >= fha_refi_incentive THEN conventional_refi_incentive ELSE fha_refi_incentive END
        ELSE 0.0 END) * schambalance) / sum(CASE WHEN HARP_eligible > 0 OR conventional_eligible > 0 OR fha_eligible > 0 THEN schambalance ELSE 0.0 END) as refi_incentive_eligible
FROM scale.FNM_Loan sl
JOIN scale.FNM_LoanHist slh
    ON sl.loanSeqNum = slh.loanSeqNum
JOIN scale.FNM_LoanEligibility sle
    ON slh.loanSeqNum = sle.loanSeqNum
    AND slh.asOf = sle.asOf
JOIN scale.FNM_LoanIncentive sli
    ON slh.loanSeqNum = sli.loanSeqNum
    AND slh.asOf = sli.asOf
WHERE 1=1
GROUP BY sl.marketTicker, slh.asOf
HAVING sum(CASE WHEN HARP_eligible > 0 OR conventional_eligible > 0 OR fha_eligible > 0 THEN schambalance ELSE 0.0 END) > 0.0
ORDER BY sl.marketTicker, slh.asOf



SELECT sl.marketTicker, sl.originationDate, count(1), sum(schamBalance), sum(schamBalance * burnout) / sum(CASE WHEN burnout IS NULL THEN 0.0 ELSE schamBalance END) as wavg_burnout FROM scale.FNM_Loan sl JOIN scale.FNM_LoanBurnout sli ON sl.loanSeqNum = sli.loanSeqNum JOIN scale.FNM_LoanHist slh ON slh.loanSeqNum = sli.loanSeqNum AND slh.asOf = sli.asOf WHERE version = '2.10' GROUP BY sl.marketTicker, sl.originationDate ORDER BY sl.originationDate
SELECT sl.marketTicker, slh.asOf, count(1), sum(schamBalance), sum(schamBalance * burnout) / sum(CASE WHEN burnout IS NULL THEN 0.0 ELSE schamBalance END) as wavg_burnout FROM scale.FNM_Loan sl JOIN scale.FNM_LoanBurnout sli ON sl.loanSeqNum = sli.loanSeqNum JOIN scale.FNM_LoanHist slh ON slh.loanSeqNum = sli.loanSeqNum AND slh.asOf = sli.asOf WHERE version = '2.10' GROUP BY sl.marketTicker, slh.asOf ORDER BY slh.asOf

SELECT sl.marketTicker, sl.originationDate, count(1), sum(schamBalance), sum(schamBalance * burnout) / sum(CASE WHEN burnout IS NULL THEN 0.0 ELSE schamBalance END) as wavg_burnout FROM scale.FNM_Loan sl JOIN scale.FNM_LoanBurnout sli ON sl.loanSeqNum = sli.loanSeqNum JOIN scale.FNM_LoanHist slh ON slh.loanSeqNum = sli.loanSeqNum AND slh.asOf = sli.asOf WHERE version = '2.00' GROUP BY sl.marketTicker, sl.originationDate ORDER BY sl.originationDate
SELECT sl.marketTicker, slh.asOf, count(1), sum(schamBalance), sum(schamBalance * burnout) / sum(CASE WHEN burnout IS NULL THEN 0.0 ELSE schamBalance END) as wavg_burnout FROM scale.FNM_Loan sl JOIN scale.FNM_LoanBurnout sli ON sl.loanSeqNum = sli.loanSeqNum JOIN scale.FNM_LoanHist slh ON slh.loanSeqNum = sli.loanSeqNum AND slh.asOf = sli.asOf WHERE version = '2.00' GROUP BY sl.marketTicker, slh.asOf ORDER BY slh.asOf

SELECT sl.marketTicker, sl.originationDate, count(1), sum(schamBalance), sum(schamBalance * burnout) / sum(CASE WHEN burnout IS NULL THEN 0.0 ELSE schamBalance END) as wavg_burnout FROM scale.FNM_Loan sl JOIN scale.FNM_LoanBurnout sli ON sl.loanSeqNum = sli.loanSeqNum JOIN scale.FNM_LoanHist slh ON slh.loanSeqNum = sli.loanSeqNum AND slh.asOf = sli.asOf WHERE version = '1.00' GROUP BY sl.marketTicker, sl.originationDate ORDER BY sl.originationDate
SELECT sl.marketTicker, slh.asOf, count(1), sum(schamBalance), sum(schamBalance * burnout) / sum(CASE WHEN burnout IS NULL THEN 0.0 ELSE schamBalance END) as wavg_burnout FROM scale.FNM_Loan sl JOIN scale.FNM_LoanBurnout sli ON sl.loanSeqNum = sli.loanSeqNum JOIN scale.FNM_LoanHist slh ON slh.loanSeqNum = sli.loanSeqNum AND slh.asOf = sli.asOf WHERE version = '1.00' GROUP BY sl.marketTicker, slh.asOf ORDER BY slh.asOf

SELECT version, slh.asOf, count(1), sum(schamBalance), sum(schamBalance * burnout) / sum(CASE WHEN burnout IS NULL THEN 0.0 ELSE schamBalance END) as wavg_burnout FROM scale.FNM_Loan sl JOIN scale.FNM_LoanBurnout sli ON sl.loanSeqNum = sli.loanSeqNum JOIN scale.FNM_LoanHist slh ON slh.loanSeqNum = sli.loanSeqNum AND slh.asOf = sli.asOf WHERE sl.marketTicker IN ('FGLMC') GROUP BY version, slh.asOf ORDER BY version, slh.asOf

SELECT sl.marketTicker, slh.asOf, count(1), sum(schamBalance), sum(schamBalance * burnout) / sum(CASE WHEN burnout IS NULL THEN 0.0 ELSE schamBalance END) as wavg_burnout FROM scale.FNM_Loan sl JOIN scale.FNM_LoanBurnout sli ON sl.loanSeqNum = sli.loanSeqNum JOIN scale.FNM_LoanHist slh ON slh.loanSeqNum = sli.loanSeqNum AND slh.asOf = sli.asOf WHERE version = '2.00' GROUP BY sl.marketTicker, slh.asOf ORDER BY slh.asOf
SELECT sl.marketTicker, slh.asOf, count(1), sum(schamBalance), sum(schamBalance * burnout) / sum(CASE WHEN burnout IS NULL THEN 0.0 ELSE schamBalance END) as wavg_burnout FROM scale.FNM_Loan sl JOIN scale.FNM_LoanBurnout sli ON sl.loanSeqNum = sli.loanSeqNum JOIN scale.FNM_LoanHist slh ON slh.loanSeqNum = sli.loanSeqNum AND slh.asOf = sli.asOf WHERE version = '2.30' GROUP BY sl.marketTicker, slh.asOf ORDER BY slh.asOf

            
SELECT sl.marketTicker, slh.asOf, count(1), sum(schamBalance), sum(schamBalance * burnout) / sum(CASE WHEN burnout IS NULL THEN 0.0 ELSE schamBalance END) as wavg_burnout FROM scale.FNM_Loan sl JOIN scale.FNM_LoanBurnout sli ON sl.loanSeqNum = sli.loanSeqNum JOIN scale.FNM_LoanHist slh ON slh.loanSeqNum = sli.loanSeqNum AND slh.asOf = sli.asOf WHERE version = '2.40' GROUP BY sl.marketTicker, slh.asOf ORDER BY slh.asOf
SELECT sl.marketTicker, slh.asOf, count(1), sum(schamBalance), sum(schamBalance * burnout) / sum(CASE WHEN burnout IS NULL THEN 0.0 ELSE schamBalance END) as wavg_burnout FROM scale.FHL_Loan sl JOIN scale.FHL_LoanBurnout sli ON sl.loanSeqNum = sli.loanSeqNum JOIN scale.FHL_LoanHist slh ON slh.loanSeqNum = sli.loanSeqNum AND slh.asOf = sli.asOf WHERE version = '2.40' GROUP BY sl.marketTicker, slh.asOf ORDER BY slh.asOf