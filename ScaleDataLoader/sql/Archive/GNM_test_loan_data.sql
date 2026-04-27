-- Count Tests (should have same count1 for all asOf tables)
COMMIT;

SELECT count(1) FROM scale.GNM_Loan;
SELECT count(distinct loanSeqNum) FROM scale.GNM_Loan;
SELECT marketTicker, count(1) FROM scale.GNM_Loan GROUP BY marketTicker;

SELECT count(distinct loanSeqNum) FROM scale.GNM_Loan;
SELECT count(distinct loanSeqNum) FROM scale.GNM_LoanHist;
SELECT count(distinct loanSeqNum) FROM scale.GNM_LoanEligibility;
SELECT count(distinct loanSeqNum) FROM scale.GNM_LoanIncentive WHERE version = '2.00';
SELECT count(distinct loanSeqNum) FROM scale.GNM_LoanBurnout WHERE version = '2.00';


SELECT count(1) FROM scale.GNM_LoanHist;
SELECT count(1) FROM scale.GNM_LoanEligibility;
SELECT count(1) FROM scale.GNM_LoanIncentive WHERE version = '2.00';
SELECT count(1) FROM scale.GNM_LoanBurnout WHERE version = '2.00';

SELECT version, count(1) FROM scale.GNM_LoanIncentive GROUP BY version;
SELECT version, count(1) FROM scale.GNM_LoanBurnout GROUP BY version;


-- Uniqueness Tests (Should all be 0 rows)

SELECT loanSeqNum, asOf, count(1) as cnt FROM scale.GNM_LoanHist GROUP BY loanSeqNum, asOf HAVING cnt > 1;
SELECT loanSeqNum, asOf, count(1) as cnt FROM scale.GNM_LoanEligibility GROUP BY loanSeqNum, asOf HAVING cnt > 1;
SELECT loanSeqNum, asOf, count(1) as cnt FROM scale.GNM_LoanIncentive WHERE version = '2.00' GROUP BY loanSeqNum, asOf HAVING cnt > 1;
SELECT loanSeqNum, asOf, count(1) as cnt FROM scale.GNM_LoanBurnout WHERE version = '2.00' GROUP BY loanSeqNum, asOf HAVING cnt > 1;


-- Null and Data Validity Tests (Should all be 0 counts)

SELECT count(1) FROM scale.GNM_Loan WHERE origLoanSize IS NULL OR origLoanSize <= 0.0 OR origLoanSize > 10000000
SELECT count(1) FROM scale.GNM_Loan WHERE numberUnits IS NULL OR numberUnits <= 0 OR numberUnits > 10
SELECT count(1) FROM scale.GNM_Loan WHERE origFICO IS NULL OR origFICO <= 0.0 OR origFICO > 900
SELECT count(1) FROM scale.GNM_Loan WHERE origLTV IS NULL OR origLTV <= 0.0 OR origLTV > 1000
SELECT count(1) FROM scale.GNM_Loan WHERE dti IS NULL OR dti < 0.0 OR dti > 65
SELECT count(1) FROM scale.GNM_Loan WHERE origNoteRate IS NULL OR origNoteRate <= 0.0 OR origNoteRate > 20
SELECT count(1) FROM scale.GNM_Loan WHERE HPI_orig IS NULL OR HPI_orig < 0.0 OR HPI_orig > 1000
SELECT count(1) FROM scale.GNM_LoanHist WHERE cltv IS NULL OR cltv <= 0.0 OR cltv > 1000
SELECT count(1) FROM scale.GNM_LoanHist WHERE hpa IS NULL OR hpa < 0.5 OR hpa > 10

SELECT count(1) FROM scale.GNM_Loan WHERE origMIP IS NULL
SELECT count(1) FROM scale.GNM_Loan WHERE origMIP < 0.0 OR origMIP > 500.0

SELECT count(1) FROM scale.GNM_LoanEligibility WHERE conventional_eligible IS NULL
SELECT count(1) FROM scale.GNM_LoanEligibility WHERE conventional_eligible < 0.0 OR conventional_eligible > 1.0

SELECT count(1) FROM scale.GNM_LoanIncentive WHERE conventional_refi_incentive IS NULL
SELECT count(1) FROM scale.GNM_LoanIncentive WHERE fha_refi_incentive IS NULL
SELECT count(1) FROM scale.GNM_LoanIncentive WHERE refi_incentive_eligible IS NULL
SELECT count(1) FROM scale.GNM_LoanIncentive WHERE currLLPA IS NULL
SELECT count(1) FROM scale.GNM_LoanIncentive WHERE currPMI IS NULL
SELECT count(1) FROM scale.GNM_LoanIncentive WHERE currMIP IS NULL
SELECT count(1) FROM scale.GNM_LoanIncentive WHERE conventional_refi_incentive < -2000.0 OR conventional_refi_incentive > 2000.0
SELECT count(1) FROM scale.GNM_LoanIncentive WHERE fha_refi_incentive < -2000.0 OR fha_refi_incentive > 2000.0
SELECT count(1) FROM scale.GNM_LoanIncentive WHERE refi_incentive_eligible < -2000.0 OR refi_incentive_eligible > 2000.0
SELECT count(1) FROM scale.GNM_LoanIncentive WHERE currLLPA < -100 OR currLLPA > 2000.0
SELECT count(1) FROM scale.GNM_LoanIncentive WHERE currPMI < 0 OR currPMI > 500.0
SELECT count(1) FROM scale.GNM_LoanIncentive WHERE currMIP < 0 OR currMIP > 500.0

SELECT count(1) FROM scale.GNM_LoanBurnout WHERE burnout IS NULL
SELECT count(1) FROM scale.GNM_LoanBurnout WHERE burnout < 0.0 OR burnout > 30000


-- Time Series Tests

SELECT marketTicker, originationDate, count(1), sum(origLoanSize), avg(origLoanSize) as avg_ols FROM scale.GNM_Loan GROUP BY marketTicker, originationDate HAVING count(1) > 10 ORDER BY originationDate
SELECT l.marketTicker, asOf, count(1), sum(balance), sum(balance * origLoanSize) / sum(balance) as wavg_ols FROM scale.GNM_Loan l JOIN scale.GNM_LoanHist lh ON l.loanSeqNum = lh.loanSeqNum GROUP BY l.marketTicker, asOf HAVING count(1) > 10 ORDER BY asOf

SELECT marketTicker, originationDate, count(1), sum(origLoanSize), sum(origLoanSize * numberUnits) / sum(origLoanSize) as wavg_units FROM scale.GNM_Loan GROUP BY marketTicker, originationDate HAVING count(1) > 10 ORDER BY originationDate
SELECT l.marketTicker, asOf, count(1), sum(balance), sum(balance * numberUnits) / sum(balance) as wavg_units FROM scale.GNM_Loan l JOIN scale.GNM_LoanHist lh ON l.loanSeqNum = lh.loanSeqNum GROUP BY l.marketTicker, asOf HAVING count(1) > 10 ORDER BY asOf

SELECT marketTicker, originationDate, count(1), sum(origLoanSize), sum(origLoanSize * origFICO) / sum(origLoanSize) as wavg_fico FROM scale.GNM_Loan GROUP BY marketTicker, originationDate HAVING count(1) > 10 ORDER BY originationDate
SELECT l.marketTicker, asOf, count(1), sum(balance), sum(balance * origFICO) / sum(balance) as wavg_fico FROM scale.GNM_Loan l JOIN scale.GNM_LoanHist lh ON l.loanSeqNum = lh.loanSeqNum GROUP BY l.marketTicker, asOf HAVING count(1) > 10 ORDER BY asOf

SELECT marketTicker, originationDate, count(1), sum(origLoanSize), sum(origLoanSize * origLTV) / sum(origLoanSize) as wavg_oltv FROM scale.GNM_Loan GROUP BY marketTicker, originationDate HAVING count(1) > 10 ORDER BY originationDate
SELECT l.marketTicker, asOf, count(1), sum(balance), sum(balance * origLTV) / sum(balance) as wavg_oltv FROM scale.GNM_Loan l JOIN scale.GNM_LoanHist lh ON l.loanSeqNum = lh.loanSeqNum GROUP BY l.marketTicker, asOf HAVING count(1) > 10 ORDER BY asOf

SELECT marketTicker, originationDate, count(1), sum(origLoanSize), sum(origLoanSize * dti) / sum(origLoanSize) as wavg_dti FROM scale.GNM_Loan GROUP BY marketTicker, originationDate HAVING count(1) > 10 ORDER BY originationDate
SELECT l.marketTicker, asOf, count(1), sum(balance), sum(balance * dti) / sum(balance) as wavg_dti FROM scale.GNM_Loan l JOIN scale.GNM_LoanHist lh ON l.loanSeqNum = lh.loanSeqNum GROUP BY l.marketTicker, asOf HAVING count(1) > 10 ORDER BY asOf

SELECT marketTicker, originationDate, count(1), sum(origLoanSize), sum(origLoanSize * origNoteRate) / sum(origLoanSize) as wavg_note_rate FROM scale.GNM_Loan GROUP BY marketTicker, originationDate HAVING count(1) > 10 ORDER BY originationDate
SELECT l.marketTicker, asOf, count(1), sum(balance), sum(balance * origNoteRate) / sum(balance) as wavg_note_rate FROM scale.GNM_Loan l JOIN scale.GNM_LoanHist lh ON l.loanSeqNum = lh.loanSeqNum GROUP BY l.marketTicker, asOf HAVING count(1) > 10 ORDER BY asOf

SELECT marketTicker, originationDate, count(1), sum(origLoanSize), sum(origLoanSize * miLevel) / sum(origLoanSize) as wavg_mi_level FROM scale.GNM_Loan GROUP BY marketTicker, originationDate HAVING count(1) > 10 ORDER BY originationDate
SELECT l.marketTicker, asOf, count(1), sum(balance), sum(balance * miLevel) / sum(balance) as wavg_mi_level FROM scale.GNM_Loan l JOIN scale.GNM_LoanHist lh ON l.loanSeqNum = lh.loanSeqNum GROUP BY l.marketTicker, asOf HAVING count(1) > 10 ORDER BY asOf

SELECT marketTicker, originationDate, count(1), sum(origLoanSize), sum(origLoanSize * HPI_orig) / sum(origLoanSize) as wavg_orig_hpi FROM scale.GNM_Loan GROUP BY marketTicker, originationDate HAVING count(1) > 10 ORDER BY originationDate
SELECT l.marketTicker, asOf, count(1), sum(balance), sum(balance * HPI_orig) / sum(balance) as wavg_orig_hpi FROM scale.GNM_Loan l JOIN scale.GNM_LoanHist lh ON l.loanSeqNum = lh.loanSeqNum GROUP BY l.marketTicker, asOf HAVING count(1) > 10 ORDER BY asOf

SELECT l.marketTicker, originationDate, count(1), sum(balance), sum(balance * lh.cltv) / sum(balance) as wavg_cltv FROM scale.GNM_Loan l JOIN scale.GNM_LoanHist lh ON l.loanSeqNum = lh.loanSeqNum GROUP BY l.marketTicker, originationDate HAVING count(1) > 10 ORDER BY originationDate
SELECT marketTicker, lh.asOf, count(1), sum(balance), sum(balance * lh.cltv) / sum(balance) as wavg_cltv FROM scale.GNM_Loan l JOIN scale.GNM_LoanHist lh ON l.loanSeqNum = lh.loanSeqNum GROUP BY marketTicker, lh.asOf ORDER BY lh.asOf

SELECT l.marketTicker, originationDate, count(1), sum(balance), sum(balance * lh.hpa) / sum(balance) as wavg_hpa FROM scale.GNM_Loan l JOIN scale.GNM_LoanHist lh ON l.loanSeqNum = lh.loanSeqNum GROUP BY l.marketTicker, originationDate HAVING count(1) > 10 ORDER BY originationDate
SELECT marketTicker, lh.asOf, count(1), sum(balance), sum(balance * lh.hpa) / sum(balance) as wavg_hpa FROM scale.GNM_Loan l JOIN scale.GNM_LoanHist lh ON l.loanSeqNum = lh.loanSeqNum GROUP BY marketTicker, lh.asOf ORDER BY lh.asOf



SELECT marketTicker, originationDate, count(1), sum(origLoanSize), sum(origLoanSize * origMIP) / sum(origLoanSize) as wavg_orig_mip FROM scale.GNM_Loan GROUP BY marketTicker, originationDate HAVING count(1) > 10 ORDER BY originationDate
SELECT l.marketTicker, asOf, count(1), sum(balance), sum(balance * origMIP) / sum(balance) as wavg_orig_mip FROM scale.GNM_Loan l JOIN scale.GNM_LoanHist lh ON l.loanSeqNum = lh.loanSeqNum GROUP BY l.marketTicker, asOf HAVING count(1) > 10 ORDER BY asOf

SELECT sl.marketTicker, sl.originationDate, count(1), sum(origLoanSize), sum(origLoanSize * conventional_eligible) / sum(CASE WHEN conventional_eligible IS NULL THEN 0.0 ELSE origLoanSize END) as wavg_pct_conventional_eligible FROM scale.GNM_Loan sl JOIN scale.GNM_LoanEligibility sle ON sl.loanSeqNum = sle.loanSeqNum GROUP BY sl.marketTicker, sl.originationDate ORDER BY sl.originationDate
SELECT sl.marketTicker, sle.asOf, count(1), sum(balance), sum(balance * conventional_eligible) / sum(CASE WHEN conventional_eligible IS NULL THEN 0.0 ELSE balance END) as wavg_pct_conventional_eligible FROM scale.GNM_Loan sl JOIN scale.GNM_LoanEligibility sle ON sl.loanSeqNum = sle.loanSeqNum JOIN scale.GNM_LoanHist slh ON sle.loanSeqNum = slh.loanSeqNum AND sle.asOf = slh.asOf GROUP BY sl.marketTicker, sle.asOf ORDER BY sle.asOf



SELECT sl.marketTicker, sl.originationDate, count(1), sum(balance), sum(balance * conventional_refi_incentive) / sum(CASE WHEN conventional_refi_incentive IS NULL THEN 0.0 ELSE balance END) as wavg_conv_incentive FROM scale.GNM_Loan sl JOIN scale.GNM_LoanIncentive sli ON sl.loanSeqNum = sli.loanSeqNum JOIN scale.GNM_LoanHist slh ON slh.loanSeqNum = sli.loanSeqNum AND slh.asOf = sli.asOf WHERE version = '2.00' GROUP BY sl.marketTicker, sl.originationDate ORDER BY sl.originationDate
SELECT sl.marketTicker, slh.asOf, count(1), sum(balance), sum(balance * conventional_refi_incentive) / sum(CASE WHEN conventional_refi_incentive IS NULL THEN 0.0 ELSE balance END) as wavg_conv_incentive FROM scale.GNM_Loan sl JOIN scale.GNM_LoanIncentive sli ON sl.loanSeqNum = sli.loanSeqNum JOIN scale.GNM_LoanHist slh ON slh.loanSeqNum = sli.loanSeqNum AND slh.asOf = sli.asOf WHERE version = '2.00' GROUP BY sl.marketTicker, slh.asOf ORDER BY slh.asOf

SELECT sl.marketTicker, sl.originationDate, count(1), sum(balance), sum(balance * fha_refi_incentive) / sum(CASE WHEN fha_refi_incentive IS NULL THEN 0.0 ELSE balance END) as wavg_fha_incentive FROM scale.GNM_Loan sl JOIN scale.GNM_LoanIncentive sli ON sl.loanSeqNum = sli.loanSeqNum JOIN scale.GNM_LoanHist slh ON slh.loanSeqNum = sli.loanSeqNum AND slh.asOf = sli.asOf WHERE version = '2.00' GROUP BY sl.marketTicker, sl.originationDate ORDER BY sl.originationDate
SELECT sl.marketTicker, slh.asOf, count(1), sum(balance), sum(balance * fha_refi_incentive) / sum(CASE WHEN fha_refi_incentive IS NULL THEN 0.0 ELSE balance END) as wavg_fha_incentive FROM scale.GNM_Loan sl JOIN scale.GNM_LoanIncentive sli ON sl.loanSeqNum = sli.loanSeqNum JOIN scale.GNM_LoanHist slh ON slh.loanSeqNum = sli.loanSeqNum AND slh.asOf = sli.asOf WHERE version = '2.00' GROUP BY sl.marketTicker, slh.asOf ORDER BY slh.asOf

SELECT sl.marketTicker, sl.originationDate, count(1), sum(balance), sum(balance * refi_incentive_eligible) / sum(CASE WHEN refi_incentive_eligible IS NULL THEN 0.0 ELSE balance END) as wavg_refi_incentive_eligible FROM scale.GNM_Loan sl JOIN scale.GNM_LoanIncentive sli ON sl.loanSeqNum = sli.loanSeqNum JOIN scale.GNM_LoanHist slh ON slh.loanSeqNum = sli.loanSeqNum AND slh.asOf = sli.asOf WHERE version = '2.00' GROUP BY sl.marketTicker, sl.originationDate ORDER BY sl.originationDate
SELECT sl.marketTicker, slh.asOf, count(1), sum(balance), sum(balance * refi_incentive_eligible) / sum(CASE WHEN refi_incentive_eligible IS NULL THEN 0.0 ELSE balance END) as wavg_refi_incentive_eligible FROM scale.GNM_Loan sl JOIN scale.GNM_LoanIncentive sli ON sl.loanSeqNum = sli.loanSeqNum JOIN scale.GNM_LoanHist slh ON slh.loanSeqNum = sli.loanSeqNum AND slh.asOf = sli.asOf WHERE version = '2.00' GROUP BY sl.marketTicker, slh.asOf ORDER BY slh.asOf

SELECT sl.marketTicker, sl.originationDate, count(1), sum(balance), sum(balance * currLLPA) / sum(CASE WHEN currLLPA IS NULL THEN 0.0 ELSE balance END) as wavg_llpa FROM scale.GNM_Loan sl JOIN scale.GNM_LoanIncentive sli ON sl.loanSeqNum = sli.loanSeqNum JOIN scale.GNM_LoanHist slh ON slh.loanSeqNum = sli.loanSeqNum AND slh.asOf = sli.asOf WHERE version = '2.00' GROUP BY sl.marketTicker, sl.originationDate ORDER BY sl.originationDate
SELECT sl.marketTicker, slh.asOf, count(1), sum(balance), sum(balance * currLLPA) / sum(CASE WHEN currLLPA IS NULL THEN 0.0 ELSE balance END) as wavg_llpa FROM scale.GNM_Loan sl JOIN scale.GNM_LoanIncentive sli ON sl.loanSeqNum = sli.loanSeqNum JOIN scale.GNM_LoanHist slh ON slh.loanSeqNum = sli.loanSeqNum AND slh.asOf = sli.asOf WHERE version = '2.00' GROUP BY sl.marketTicker, slh.asOf ORDER BY slh.asOf

SELECT sl.marketTicker, sl.originationDate, count(1), sum(balance), sum(balance * currPMI) / sum(CASE WHEN currPMI IS NULL THEN 0.0 ELSE balance END) as wavg_pmi FROM scale.GNM_Loan sl JOIN scale.GNM_LoanIncentive sli ON sl.loanSeqNum = sli.loanSeqNum JOIN scale.GNM_LoanHist slh ON slh.loanSeqNum = sli.loanSeqNum AND slh.asOf = sli.asOf WHERE version = '2.00' GROUP BY sl.marketTicker, sl.originationDate ORDER BY sl.originationDate
SELECT sl.marketTicker, slh.asOf, count(1), sum(balance), sum(balance * currPMI) / sum(CASE WHEN currPMI IS NULL THEN 0.0 ELSE balance END) as wavg_pmi FROM scale.GNM_Loan sl JOIN scale.GNM_LoanIncentive sli ON sl.loanSeqNum = sli.loanSeqNum JOIN scale.GNM_LoanHist slh ON slh.loanSeqNum = sli.loanSeqNum AND slh.asOf = sli.asOf WHERE version = '2.00' GROUP BY sl.marketTicker, slh.asOf ORDER BY slh.asOf

SELECT sl.marketTicker, sl.originationDate, count(1), sum(balance), sum(balance * currMIP) / sum(CASE WHEN currMIP IS NULL THEN 0.0 ELSE balance END) as wavg_mip FROM scale.GNM_Loan sl JOIN scale.GNM_LoanIncentive sli ON sl.loanSeqNum = sli.loanSeqNum JOIN scale.GNM_LoanHist slh ON slh.loanSeqNum = sli.loanSeqNum AND slh.asOf = sli.asOf WHERE version = '2.00' GROUP BY sl.marketTicker, sl.originationDate ORDER BY sl.originationDate
SELECT sl.marketTicker, slh.asOf, count(1), sum(balance), sum(balance * currMIP) / sum(CASE WHEN currMIP IS NULL THEN 0.0 ELSE balance END) as wavg_mip FROM scale.GNM_Loan sl JOIN scale.GNM_LoanIncentive sli ON sl.loanSeqNum = sli.loanSeqNum JOIN scale.GNM_LoanHist slh ON slh.loanSeqNum = sli.loanSeqNum AND slh.asOf = sli.asOf WHERE version = '2.00' GROUP BY sl.marketTicker, slh.asOf ORDER BY slh.asOf



--SELECT sl.marketTicker, sl.originationDate, count(1), sum(balance), sum(balance * burnout) / sum(CASE WHEN burnout IS NULL THEN 0.0 ELSE balance END) as wavg_burnout FROM scale.GNM_Loan sl JOIN scale.GNM_LoanBurnout sli ON sl.loanSeqNum = sli.loanSeqNum JOIN scale.GNM_LoanHist slh ON slh.loanSeqNum = sli.loanSeqNum AND slh.asOf = sli.asOf WHERE version = '2.10' GROUP BY sl.marketTicker, sl.originationDate ORDER BY sl.originationDate
--SELECT sl.marketTicker, slh.asOf, count(1), sum(balance), sum(balance * burnout) / sum(CASE WHEN burnout IS NULL THEN 0.0 ELSE balance END) as wavg_burnout FROM scale.GNM_Loan sl JOIN scale.GNM_LoanBurnout sli ON sl.loanSeqNum = sli.loanSeqNum JOIN scale.GNM_LoanHist slh ON slh.loanSeqNum = sli.loanSeqNum AND slh.asOf = sli.asOf WHERE version = '2.10' GROUP BY sl.marketTicker, slh.asOf ORDER BY slh.asOf

SELECT sl.marketTicker, sl.originationDate, count(1), sum(balance), sum(balance * burnout) / sum(CASE WHEN burnout IS NULL THEN 0.0 ELSE balance END) as wavg_burnout FROM scale.GNM_Loan sl JOIN scale.GNM_LoanBurnout sli ON sl.loanSeqNum = sli.loanSeqNum JOIN scale.GNM_LoanHist slh ON slh.loanSeqNum = sli.loanSeqNum AND slh.asOf = sli.asOf WHERE version = '2.00' GROUP BY sl.marketTicker, sl.originationDate ORDER BY sl.originationDate
SELECT sl.marketTicker, slh.asOf, count(1), sum(balance), sum(balance * burnout) / sum(CASE WHEN burnout IS NULL THEN 0.0 ELSE balance END) as wavg_burnout FROM scale.GNM_Loan sl JOIN scale.GNM_LoanBurnout sli ON sl.loanSeqNum = sli.loanSeqNum JOIN scale.GNM_LoanHist slh ON slh.loanSeqNum = sli.loanSeqNum AND slh.asOf = sli.asOf WHERE version = '2.00' GROUP BY sl.marketTicker, slh.asOf ORDER BY slh.asOf

SELECT sl.marketTicker, sl.originationDate, count(1), sum(balance), sum(balance * burnout) / sum(CASE WHEN burnout IS NULL THEN 0.0 ELSE balance END) as wavg_burnout FROM scale.GNM_Loan sl JOIN scale.GNM_LoanBurnout sli ON sl.loanSeqNum = sli.loanSeqNum JOIN scale.GNM_LoanHist slh ON slh.loanSeqNum = sli.loanSeqNum AND slh.asOf = sli.asOf WHERE version = '1.00' GROUP BY sl.marketTicker, sl.originationDate ORDER BY sl.originationDate
SELECT sl.marketTicker, slh.asOf, count(1), sum(balance), sum(balance * burnout) / sum(CASE WHEN burnout IS NULL THEN 0.0 ELSE balance END) as wavg_burnout FROM scale.GNM_Loan sl JOIN scale.GNM_LoanBurnout sli ON sl.loanSeqNum = sli.loanSeqNum JOIN scale.GNM_LoanHist slh ON slh.loanSeqNum = sli.loanSeqNum AND slh.asOf = sli.asOf WHERE version = '1.00' GROUP BY sl.marketTicker, slh.asOf ORDER BY slh.asOf

