-- Count Tests (should have same count1 for all asOf tables)
COMMIT;

SELECT count(distinct issueId) FROM scale.GNM_PoolHist;
SELECT count(distinct issueId) FROM scale.GNM_PoolDistribution;
SELECT count(distinct issueId) FROM scale.GNM_PoolEligibility;
SELECT count(distinct issueId) FROM scale.GNM_PoolIncentive WHERE version = '2.00';
SELECT count(distinct issueId) FROM scale.GNM_PoolBurnout WHERE version = '2.00';

SELECT count(1) FROM scale.GNM_PoolHist;
SELECT count(1) FROM scale.GNM_PoolDistribution;
SELECT count(1) FROM scale.GNM_PoolEligibility;
SELECT count(1) FROM scale.GNM_PoolIncentive WHERE version = '2.00';
SELECT count(1) FROM scale.GNM_PoolBurnout WHERE version = '2.00';

SELECT version, count(1) FROM scale.GNM_PoolIncentive GROUP BY version;
SELECT version, count(1) FROM scale.GNM_PoolBurnout GROUP BY version;


-- Uniqueness Tests (Should all be 0 rows)

SELECT issueId, asOf, count(1) as cnt FROM scale.GNM_PoolHist GROUP BY issueId, asOf HAVING cnt > 1;
SELECT issueId, asOf, count(1) as cnt FROM scale.GNM_PoolDistribution GROUP BY issueId, asOf HAVING cnt > 1;
SELECT issueId, asOf, count(1) as cnt FROM scale.GNM_PoolEligibility GROUP BY issueId, asOf HAVING cnt > 1;
SELECT issueId, asOf, count(1) as cnt FROM scale.GNM_PoolIncentive WHERE version = '2.00' GROUP BY issueId, asOf HAVING cnt > 1;
SELECT issueId, asOf, count(1) as cnt FROM scale.GNM_PoolBurnout WHERE version = '2.00' GROUP BY issueId, asOf HAVING cnt > 1;


-- Null and Data Validity Tests (Should all be 0 counts)

SELECT count(1) FROM scale.GNM_PoolHist WHERE originationDate IS NULL OR originationDate <= '1950-01-01'
SELECT count(1) FROM scale.GNM_PoolHist WHERE origLoanSize IS NULL OR origLoanSize <= 0.0 OR origLoanSize > 1500000
SELECT count(1) FROM scale.GNM_PoolHist WHERE origFICO IS NULL OR origFICO <= 0.0 OR origFICO > 1000
SELECT count(1) FROM scale.GNM_PoolHist WHERE origLTV IS NULL OR origLTV <= 0.0 OR origLTV > 1000
SELECT count(1) FROM scale.GNM_PoolHist WHERE origNoteRate IS NULL OR origNoteRate <= 0.0 OR origNoteRate > 20
SELECT count(1) FROM scale.GNM_PoolHist WHERE currLoanSize IS NULL OR currLoanSize <= 0.0 OR currLoanSize > 1500000
SELECT count(1) FROM scale.GNM_PoolHist WHERE cltv IS NULL OR cltv <= 0.0 OR cltv > 1000
SELECT count(1) FROM scale.GNM_PoolHist WHERE HPA IS NULL OR HPA < 0.5 OR HPA > 10

SELECT count(1) FROM scale.GNM_PoolDistribution spd JOIN scale.GNM_PoolHist sph ON spd.issueId = sph.issueId AND spd.asOf = sph.asOf WHERE (percentPURP_PURCH IS NULL OR percentPURP_PURCH < 0.0 OR percentPURP_PURCH > 100.0) AND originationDate >= '1994-01-01'
SELECT count(1) FROM scale.GNM_PoolDistribution spd JOIN scale.GNM_PoolHist sph ON spd.issueId = sph.issueId AND spd.asOf = sph.asOf WHERE (percentPURP_REFI IS NULL OR percentPURP_REFI < 0.0 OR percentPURP_REFI > 100.0) AND originationDate >= '1994-01-01'
SELECT count(1) FROM scale.GNM_PoolDistribution WHERE abs(percentPURP_PURCH + percentPURP_REFI - 100.0) > 0.1
SELECT count(1) FROM scale.GNM_PoolDistribution spd JOIN scale.GNM_PoolHist sph ON spd.issueId = sph.issueId AND spd.asOf = sph.asOf WHERE sph.asOf >= '2005-12-01' AND (percentCURRENT IS NULL OR percentCURRENT < 0.0 OR percentCURRENT > 100.0)
SELECT count(1) FROM scale.GNM_PoolDistribution spd JOIN scale.GNM_PoolHist sph ON spd.issueId = sph.issueId AND spd.asOf = sph.asOf WHERE sph.asOf >= '2005-12-01' AND (percentDELQ30plus IS NULL OR percentDELQ30plus < 0.0 OR percentDELQ30plus > 100.0)
SELECT count(1) FROM scale.GNM_PoolDistribution spd JOIN scale.GNM_PoolHist sph ON spd.issueId = sph.issueId AND spd.asOf = sph.asOf WHERE sph.asOf >= '2005-12-01' AND (percentDELQ60plus IS NULL OR percentDELQ60plus < 0.0 OR percentDELQ60plus > 100.0)
SELECT count(1) FROM scale.GNM_PoolDistribution spd JOIN scale.GNM_PoolHist sph ON spd.issueId = sph.issueId AND spd.asOf = sph.asOf WHERE sph.asOf >= '2005-12-01' AND (percentDELQ90plus IS NULL OR percentDELQ90plus < 0.0 OR percentDELQ90plus > 100.0)
SELECT count(1) FROM scale.GNM_PoolDistribution WHERE abs(percentCURRENT + percentDELQ30plus - 100.0) > 0.1
SELECT count(1) FROM scale.GNM_PoolDistribution spd JOIN scale.GNM_PoolHist sph ON spd.issueId = sph.issueId AND spd.asOf = sph.asOf WHERE (percentCHANNEL_RETAIL IS NULL OR percentCHANNEL_RETAIL < 0.0 OR percentCHANNEL_RETAIL > 100.0) AND originationDate >= '2008-01-01'
SELECT count(1) FROM scale.GNM_PoolDistribution spd JOIN scale.GNM_PoolHist sph ON spd.issueId = sph.issueId AND spd.asOf = sph.asOf WHERE (percentCHANNEL_BROKER IS NULL OR percentCHANNEL_BROKER < 0.0 OR percentCHANNEL_BROKER > 100.0) AND originationDate >= '2008-01-01'
SELECT count(1) FROM scale.GNM_PoolDistribution spd JOIN scale.GNM_PoolHist sph ON spd.issueId = sph.issueId AND spd.asOf = sph.asOf WHERE (percentCHANNEL_CORRES IS NULL OR percentCHANNEL_CORRES < 0.0 OR percentCHANNEL_CORRES > 100.0) AND originationDate >= '2008-01-01'
SELECT count(1) FROM scale.GNM_PoolDistribution WHERE abs(percentCHANNEL_RETAIL + percentCHANNEL_BROKER + percentCHANNEL_CORRES - 100.0) > 0.1
SELECT count(1) FROM scale.GNM_PoolDistribution spd JOIN scale.GNM_PoolHist sph ON spd.issueId = sph.issueId AND spd.asOf = sph.asOf WHERE (percentUNIT_SINGLE IS NULL OR percentUNIT_SINGLE < 0.0 OR percentUNIT_SINGLE > 100.0) AND originationDate >= '1994-01-01'
SELECT count(1) FROM scale.GNM_PoolDistribution spd JOIN scale.GNM_PoolHist sph ON spd.issueId = sph.issueId AND spd.asOf = sph.asOf WHERE (percentUNIT_MULTIPLE IS NULL OR percentUNIT_MULTIPLE < 0.0 OR percentUNIT_MULTIPLE > 100.0) AND originationDate >= '1994-01-01'
SELECT count(1) FROM scale.GNM_PoolDistribution WHERE abs(percentUNIT_SINGLE + percentUNIT_MULTIPLE -100.0) > 0.1
SELECT count(1) FROM scale.GNM_PoolDistribution spd JOIN scale.GNM_PoolHist sph ON spd.issueId = sph.issueId AND spd.asOf = sph.asOf WHERE (percentTYPE_FHA IS NULL OR percentTYPE_FHA < 0.0 OR percentTYPE_FHA > 100.0) AND originationDate >= '2008-01-01'
SELECT count(1) FROM scale.GNM_PoolDistribution spd JOIN scale.GNM_PoolHist sph ON spd.issueId = sph.issueId AND spd.asOf = sph.asOf WHERE (percentTYPE_VA IS NULL OR percentTYPE_VA < 0.0 OR percentTYPE_VA > 100.0) AND originationDate >= '2008-01-01'
SELECT count(1) FROM scale.GNM_PoolDistribution spd JOIN scale.GNM_PoolHist sph ON spd.issueId = sph.issueId AND spd.asOf = sph.asOf WHERE (percentTYPE_OTHER IS NULL OR percentTYPE_OTHER < 0.0 OR percentTYPE_OTHER > 100.0) AND originationDate >= '2008-01-01'
SELECT count(1) FROM scale.GNM_PoolDistribution WHERE abs(percentTYPE_FHA + percentTYPE_VA + percentTYPE_OTHER - 100.0) > 0.1

SELECT count(1) FROM scale.GNM_PoolEligibility WHERE conventional_eligible IS NULL OR conventional_eligible < 0.0 OR conventional_eligible > 100

SELECT count(1) FROM scale.GNM_PoolIncentive WHERE conventional_refi_incentive IS NULL
SELECT count(1) FROM scale.GNM_PoolIncentive WHERE fha_refi_incentive IS NULL
SELECT count(1) FROM scale.GNM_PoolIncentive WHERE origMIP IS NULL
SELECT count(1) FROM scale.GNM_PoolIncentive WHERE currLLPA IS NULL
SELECT count(1) FROM scale.GNM_PoolIncentive WHERE currPMI IS NULL
SELECT count(1) FROM scale.GNM_PoolIncentive WHERE currMIP IS NULL
SELECT count(1) FROM scale.GNM_PoolIncentive WHERE conventional_refi_incentive < -2000.0 OR conventional_refi_incentive > 2000.0
SELECT count(1) FROM scale.GNM_PoolIncentive WHERE fha_refi_incentive < -2000.0 OR fha_refi_incentive > 2000.0
SELECT count(1) FROM scale.GNM_PoolIncentive WHERE origMIP < 0.0 OR origMIP > 500.0
SELECT count(1) FROM scale.GNM_PoolIncentive WHERE currLLPA < -100 OR currLLPA > 2000.0
SELECT count(1) FROM scale.GNM_PoolIncentive WHERE currPMI < 0 OR currPMI > 1000.0
SELECT count(1) FROM scale.GNM_PoolIncentive WHERE currMIP < 0 OR currMIP > 500.0

SELECT count(1) FROM scale.GNM_PoolBurnout WHERE burnout IS NULL
SELECT count(1) FROM scale.GNM_PoolBurnout WHERE burnout < 0.0 OR burnout > 30000


-- Time Series Tests

SELECT marketTicker, originationDate, count(1), sum(origLoanSize), avg(origLoanSize) as avg_ols FROM scale.GNM_Pool GROUP BY marketTicker, originationDate HAVING count(1) > 10 ORDER BY originationDate
SELECT l.marketTicker, asOf, count(1), sum(schamBalance), sum(schamBalance * origLoanSize) / sum(schamBalance) as wavg_ols FROM scale.GNM_Pool l JOIN scale.GNM_PoolHist lh ON l.loanSeqNum = lh.loanSeqNum GROUP BY l.marketTicker, asOf HAVING count(1) > 10 ORDER BY asOf

SELECT marketTicker, originationDate, count(1), sum(origLoanSize), sum(origLoanSize * numberUnits) / sum(origLoanSize) as wavg_units FROM scale.GNM_Pool GROUP BY marketTicker, originationDate HAVING count(1) > 10 ORDER BY originationDate
SELECT l.marketTicker, asOf, count(1), sum(schamBalance), sum(schamBalance * numberUnits) / sum(schamBalance) as wavg_units FROM scale.GNM_Pool l JOIN scale.GNM_PoolHist lh ON l.loanSeqNum = lh.loanSeqNum GROUP BY l.marketTicker, asOf HAVING count(1) > 10 ORDER BY asOf

SELECT marketTicker, originationDate, count(1), sum(origLoanSize), sum(origLoanSize * origFICO) / sum(origLoanSize) as wavg_fico FROM scale.GNM_Pool GROUP BY marketTicker, originationDate HAVING count(1) > 10 ORDER BY originationDate
SELECT l.marketTicker, asOf, count(1), sum(schamBalance), sum(schamBalance * origFICO) / sum(schamBalance) as wavg_fico FROM scale.GNM_Pool l JOIN scale.GNM_PoolHist lh ON l.loanSeqNum = lh.loanSeqNum GROUP BY l.marketTicker, asOf HAVING count(1) > 10 ORDER BY asOf

SELECT marketTicker, originationDate, count(1), sum(origLoanSize), sum(origLoanSize * origLTV) / sum(origLoanSize) as wavg_oltv FROM scale.GNM_Pool GROUP BY marketTicker, originationDate HAVING count(1) > 10 ORDER BY originationDate
SELECT l.marketTicker, asOf, count(1), sum(schamBalance), sum(schamBalance * origLTV) / sum(schamBalance) as wavg_oltv FROM scale.GNM_Pool l JOIN scale.GNM_PoolHist lh ON l.loanSeqNum = lh.loanSeqNum GROUP BY l.marketTicker, asOf HAVING count(1) > 10 ORDER BY asOf

SELECT marketTicker, originationDate, count(1), sum(origLoanSize), sum(origLoanSize * dti) / sum(origLoanSize) as wavg_dti FROM scale.GNM_Pool GROUP BY marketTicker, originationDate HAVING count(1) > 10 ORDER BY originationDate
SELECT l.marketTicker, asOf, count(1), sum(schamBalance), sum(schamBalance * dti) / sum(schamBalance) as wavg_dti FROM scale.GNM_Pool l JOIN scale.GNM_PoolHist lh ON l.loanSeqNum = lh.loanSeqNum GROUP BY l.marketTicker, asOf HAVING count(1) > 10 ORDER BY asOf

SELECT marketTicker, originationDate, count(1), sum(origLoanSize), sum(origLoanSize * origNoteRate) / sum(origLoanSize) as wavg_note_rate FROM scale.GNM_Pool GROUP BY marketTicker, originationDate HAVING count(1) > 10 ORDER BY originationDate
SELECT l.marketTicker, asOf, count(1), sum(schamBalance), sum(schamBalance * origNoteRate) / sum(schamBalance) as wavg_note_rate FROM scale.GNM_Pool l JOIN scale.GNM_PoolHist lh ON l.loanSeqNum = lh.loanSeqNum GROUP BY l.marketTicker, asOf HAVING count(1) > 10 ORDER BY asOf

SELECT marketTicker, originationDate, count(1), sum(origLoanSize), sum(origLoanSize * miLevel) / sum(origLoanSize) as wavg_mi_level FROM scale.GNM_Pool GROUP BY marketTicker, originationDate HAVING count(1) > 10 ORDER BY originationDate
SELECT l.marketTicker, asOf, count(1), sum(schamBalance), sum(schamBalance * miLevel) / sum(schamBalance) as wavg_mi_level FROM scale.GNM_Pool l JOIN scale.GNM_PoolHist lh ON l.loanSeqNum = lh.loanSeqNum GROUP BY l.marketTicker, asOf HAVING count(1) > 10 ORDER BY asOf

SELECT marketTicker, originationDate, count(1), sum(origLoanSize), sum(origLoanSize * HPI_orig) / sum(origLoanSize) as wavg_orig_hpi FROM scale.GNM_Pool GROUP BY marketTicker, originationDate HAVING count(1) > 10 ORDER BY originationDate
SELECT l.marketTicker, asOf, count(1), sum(schamBalance), sum(schamBalance * HPI_orig) / sum(schamBalance) as wavg_orig_hpi FROM scale.GNM_Pool l JOIN scale.GNM_PoolHist lh ON l.loanSeqNum = lh.loanSeqNum GROUP BY l.marketTicker, asOf HAVING count(1) > 10 ORDER BY asOf

SELECT l.marketTicker, originationDate, count(1), sum(schamBalance), sum(schamBalance * lh.cltv) / sum(schamBalance) as wavg_cltv FROM scale.GNM_Pool l JOIN scale.GNM_PoolHist lh ON l.loanSeqNum = lh.loanSeqNum GROUP BY l.marketTicker, originationDate HAVING count(1) > 10 ORDER BY originationDate
SELECT marketTicker, lh.asOf, count(1), sum(schamBalance), sum(schamBalance * lh.cltv) / sum(schamBalance) as wavg_cltv FROM scale.GNM_Pool l JOIN scale.GNM_PoolHist lh ON l.loanSeqNum = lh.loanSeqNum GROUP BY marketTicker, lh.asOf ORDER BY lh.asOf

SELECT l.marketTicker, originationDate, count(1), sum(schamBalance), sum(schamBalance * lh.hpa) / sum(schamBalance) as wavg_hpa FROM scale.GNM_Pool l JOIN scale.GNM_PoolHist lh ON l.loanSeqNum = lh.loanSeqNum GROUP BY l.marketTicker, originationDate HAVING count(1) > 10 ORDER BY originationDate
SELECT marketTicker, lh.asOf, count(1), sum(schamBalance), sum(schamBalance * lh.hpa) / sum(schamBalance) as wavg_hpa FROM scale.GNM_Pool l JOIN scale.GNM_PoolHist lh ON l.loanSeqNum = lh.loanSeqNum GROUP BY marketTicker, lh.asOf ORDER BY lh.asOf



SELECT marketTicker, originationDate, count(1), sum(origLoanSize), sum(origLoanSize * origPMI) / sum(origLoanSize) as wavg_orig_pmi FROM scale.GNM_Pool GROUP BY marketTicker, originationDate HAVING count(1) > 10 ORDER BY originationDate
SELECT l.marketTicker, asOf, count(1), sum(schamBalance), sum(schamBalance * origPMI) / sum(schamBalance) as wavg_orig_pmi FROM scale.GNM_Pool l JOIN scale.GNM_PoolHist lh ON l.loanSeqNum = lh.loanSeqNum GROUP BY l.marketTicker, asOf HAVING count(1) > 10 ORDER BY asOf

SELECT marketTicker, originationDate, count(1), sum(origLoanSize), sum(origLoanSize * percentHARPed) / sum(origLoanSize) as wavg_pct_harped FROM scale.GNM_Pool GROUP BY marketTicker, originationDate HAVING count(1) > 10 ORDER BY originationDate
SELECT l.marketTicker, asOf, count(1), sum(schamBalance), sum(schamBalance * percentHARPed) / sum(schamBalance) as wavg_pct_harped FROM scale.GNM_Pool l JOIN scale.GNM_PoolHist lh ON l.loanSeqNum = lh.loanSeqNum GROUP BY l.marketTicker, asOf HAVING count(1) > 10 ORDER BY asOf



SELECT sl.marketTicker, sl.originationDate, count(1), sum(schamBalance), sum(schamBalance * HARP_eligible) / sum(CASE WHEN HARP_eligible IS NULL THEN 0.0 ELSE schamBalance END) as wavg_pct_harp_eligible FROM scale.GNM_Pool sl JOIN scale.GNM_PoolEligibility sle ON sl.loanSeqNum = sle.loanSeqNum JOIN scale.GNM_PoolHist slh ON sle.loanSeqNum = slh.loanSeqNum AND sle.asOf = slh.asOf GROUP BY sl.marketTicker, sl.originationDate ORDER BY sl.originationDate
SELECT sl.marketTicker, sle.asOf, count(1), sum(schamBalance), sum(schamBalance * HARP_eligible) / sum(CASE WHEN HARP_eligible IS NULL THEN 0.0 ELSE schamBalance END) as wavg_pct_harp_eligible FROM scale.GNM_Pool sl JOIN scale.GNM_PoolEligibility sle ON sl.loanSeqNum = sle.loanSeqNum JOIN scale.GNM_PoolHist slh ON sle.loanSeqNum = slh.loanSeqNum AND sle.asOf = slh.asOf GROUP BY sl.marketTicker, sle.asOf ORDER BY sle.asOf

SELECT sl.marketTicker, sl.originationDate, count(1), sum(schamBalance), sum(schamBalance * conventional_eligible) / sum(CASE WHEN conventional_eligible IS NULL THEN 0.0 ELSE schamBalance END) as wavg_pct_conventional_eligible FROM scale.GNM_Pool sl JOIN scale.GNM_PoolEligibility sle ON sl.loanSeqNum = sle.loanSeqNum JOIN scale.GNM_PoolHist slh ON sle.loanSeqNum = slh.loanSeqNum AND sle.asOf = slh.asOf GROUP BY sl.marketTicker, sl.originationDate ORDER BY sl.originationDate
SELECT sl.marketTicker, sle.asOf, count(1), sum(schamBalance), sum(schamBalance * conventional_eligible) / sum(CASE WHEN conventional_eligible IS NULL THEN 0.0 ELSE schamBalance END) as wavg_pct_conventional_eligible FROM scale.GNM_Pool sl JOIN scale.GNM_PoolEligibility sle ON sl.loanSeqNum = sle.loanSeqNum JOIN scale.GNM_PoolHist slh ON sle.loanSeqNum = slh.loanSeqNum AND sle.asOf = slh.asOf GROUP BY sl.marketTicker, sle.asOf ORDER BY sle.asOf

SELECT sl.marketTicker, sl.originationDate, count(1), sum(schamBalance), sum(schamBalance * fha_eligible) / sum(CASE WHEN fha_eligible IS NULL THEN 0.0 ELSE schamBalance END) as wavg_pct_fha_eligible FROM scale.GNM_Pool sl JOIN scale.GNM_PoolEligibility sle ON sl.loanSeqNum = sle.loanSeqNum JOIN scale.GNM_PoolHist slh ON sle.loanSeqNum = slh.loanSeqNum AND sle.asOf = slh.asOf GROUP BY sl.marketTicker, sl.originationDate ORDER BY sl.originationDate
SELECT sl.marketTicker, sle.asOf, count(1), sum(schamBalance), sum(schamBalance * fha_eligible) / sum(CASE WHEN fha_eligible IS NULL THEN 0.0 ELSE schamBalance END) as wavg_pct_fha_eligible FROM scale.GNM_Pool sl JOIN scale.GNM_PoolEligibility sle ON sl.loanSeqNum = sle.loanSeqNum JOIN scale.GNM_PoolHist slh ON sle.loanSeqNum = slh.loanSeqNum AND sle.asOf = slh.asOf GROUP BY sl.marketTicker, sle.asOf ORDER BY sle.asOf



SELECT sl.marketTicker, sl.originationDate, count(1), sum(schamBalance), sum(schamBalance * conventional_refi_incentive) / sum(CASE WHEN conventional_refi_incentive IS NULL THEN 0.0 ELSE schamBalance END) as wavg_conv_incentive FROM scale.GNM_Pool sl JOIN scale.GNM_PoolIncentive sli ON sl.loanSeqNum = sli.loanSeqNum JOIN scale.GNM_PoolHist slh ON slh.loanSeqNum = sli.loanSeqNum AND slh.asOf = sli.asOf WHERE version = '2.00' GROUP BY sl.marketTicker, sl.originationDate ORDER BY sl.originationDate
SELECT sl.marketTicker, slh.asOf, count(1), sum(schamBalance), sum(schamBalance * conventional_refi_incentive) / sum(CASE WHEN conventional_refi_incentive IS NULL THEN 0.0 ELSE schamBalance END) as wavg_conv_incentive FROM scale.GNM_Pool sl JOIN scale.GNM_PoolIncentive sli ON sl.loanSeqNum = sli.loanSeqNum JOIN scale.GNM_PoolHist slh ON slh.loanSeqNum = sli.loanSeqNum AND slh.asOf = sli.asOf WHERE version = '2.00' GROUP BY sl.marketTicker, slh.asOf ORDER BY slh.asOf

SELECT sl.marketTicker, sl.originationDate, count(1), sum(schamBalance), sum(schamBalance * fha_incentive) / sum(CASE WHEN fha_incentive IS NULL THEN 0.0 ELSE schamBalance END) as wavg_fha_incentive FROM scale.GNM_Pool sl JOIN scale.GNM_PoolIncentive sli ON sl.loanSeqNum = sli.loanSeqNum JOIN scale.GNM_PoolHist slh ON slh.loanSeqNum = sli.loanSeqNum AND slh.asOf = sli.asOf WHERE version = '2.00' GROUP BY sl.marketTicker, sl.originationDate ORDER BY sl.originationDate
SELECT sl.marketTicker, slh.asOf, count(1), sum(schamBalance), sum(schamBalance * fha_incentive) / sum(CASE WHEN fha_incentive IS NULL THEN 0.0 ELSE schamBalance END) as wavg_fha_incentive FROM scale.GNM_Pool sl JOIN scale.GNM_PoolIncentive sli ON sl.loanSeqNum = sli.loanSeqNum JOIN scale.GNM_PoolHist slh ON slh.loanSeqNum = sli.loanSeqNum AND slh.asOf = sli.asOf WHERE version = '2.00' GROUP BY sl.marketTicker, slh.asOf ORDER BY slh.asOf

SELECT sl.marketTicker, sl.originationDate, count(1), sum(schamBalance), sum(schamBalance * currLLPA) / sum(CASE WHEN currLLPA IS NULL THEN 0.0 ELSE schamBalance END) as wavg_llpa FROM scale.GNM_Pool sl JOIN scale.GNM_PoolIncentive sli ON sl.loanSeqNum = sli.loanSeqNum JOIN scale.GNM_PoolHist slh ON slh.loanSeqNum = sli.loanSeqNum AND slh.asOf = sli.asOf WHERE version = '2.00' GROUP BY sl.marketTicker, sl.originationDate ORDER BY sl.originationDate
SELECT sl.marketTicker, slh.asOf, count(1), sum(schamBalance), sum(schamBalance * currLLPA) / sum(CASE WHEN currLLPA IS NULL THEN 0.0 ELSE schamBalance END) as wavg_llpa FROM scale.GNM_Pool sl JOIN scale.GNM_PoolIncentive sli ON sl.loanSeqNum = sli.loanSeqNum JOIN scale.GNM_PoolHist slh ON slh.loanSeqNum = sli.loanSeqNum AND slh.asOf = sli.asOf WHERE version = '2.00' GROUP BY sl.marketTicker, slh.asOf ORDER BY slh.asOf

SELECT sl.marketTicker, sl.originationDate, count(1), sum(schamBalance), sum(schamBalance * currPMI) / sum(CASE WHEN currPMI IS NULL THEN 0.0 ELSE schamBalance END) as wavg_pmi FROM scale.GNM_Pool sl JOIN scale.GNM_PoolIncentive sli ON sl.loanSeqNum = sli.loanSeqNum JOIN scale.GNM_PoolHist slh ON slh.loanSeqNum = sli.loanSeqNum AND slh.asOf = sli.asOf WHERE version = '2.00' GROUP BY sl.marketTicker, sl.originationDate ORDER BY sl.originationDate
SELECT sl.marketTicker, slh.asOf, count(1), sum(schamBalance), sum(schamBalance * currPMI) / sum(CASE WHEN currPMI IS NULL THEN 0.0 ELSE schamBalance END) as wavg_pmi FROM scale.GNM_Pool sl JOIN scale.GNM_PoolIncentive sli ON sl.loanSeqNum = sli.loanSeqNum JOIN scale.GNM_PoolHist slh ON slh.loanSeqNum = sli.loanSeqNum AND slh.asOf = sli.asOf WHERE version = '2.00' GROUP BY sl.marketTicker, slh.asOf ORDER BY slh.asOf

SELECT sl.marketTicker, sl.originationDate, count(1), sum(schamBalance), sum(schamBalance * currMIP) / sum(CASE WHEN currMIP IS NULL THEN 0.0 ELSE schamBalance END) as wavg_mip FROM scale.GNM_Pool sl JOIN scale.GNM_PoolIncentive sli ON sl.loanSeqNum = sli.loanSeqNum JOIN scale.GNM_PoolHist slh ON slh.loanSeqNum = sli.loanSeqNum AND slh.asOf = sli.asOf WHERE version = '2.00' GROUP BY sl.marketTicker, sl.originationDate ORDER BY sl.originationDate
SELECT sl.marketTicker, slh.asOf, count(1), sum(schamBalance), sum(schamBalance * currMIP) / sum(CASE WHEN currMIP IS NULL THEN 0.0 ELSE schamBalance END) as wavg_mip FROM scale.GNM_Pool sl JOIN scale.GNM_PoolIncentive sli ON sl.loanSeqNum = sli.loanSeqNum JOIN scale.GNM_PoolHist slh ON slh.loanSeqNum = sli.loanSeqNum AND slh.asOf = sli.asOf WHERE version = '2.00' GROUP BY sl.marketTicker, slh.asOf ORDER BY slh.asOf



SELECT sl.marketTicker, sl.originationDate, count(1), sum(schamBalance), sum(schamBalance * burnout) / sum(CASE WHEN burnout IS NULL THEN 0.0 ELSE schamBalance END) as wavg_burnout FROM scale.GNM_Pool sl JOIN scale.GNM_PoolBurnout sli ON sl.loanSeqNum = sli.loanSeqNum JOIN scale.GNM_PoolHist slh ON slh.loanSeqNum = sli.loanSeqNum AND slh.asOf = sli.asOf WHERE version = '2.00' GROUP BY sl.marketTicker, sl.originationDate ORDER BY sl.originationDate
SELECT sph.marketTicker, sph.asOf, count(1), sum(schamBalance), sum(schamBalance * burnout) / sum(CASE WHEN burnout IS NULL THEN 0.0 ELSE schamBalance END) as wavg_burnout 
FROM scale.GNM_PoolHist sph JOIN scale.GNM_PoolBurnout spb ON sph.issueId = spb.issueId AND sph.asOf = spb.asOf WHERE version = '2.00' GROUP BY sph.marketTicker, sph.asOf ORDER BY sph.asOf


