COMMIT;

-- Count Tests (should have same count1 for all asOf tables)

SELECT count(distinct issueId) FROM scale.FNM_PoolHist;
SELECT count(distinct issueId) FROM scale.FNM_PoolDistribution;
SELECT count(distinct issueId) FROM scale.FNM_PoolEligibility;
SELECT count(distinct issueId) FROM scale.FNM_PoolIncentive WHERE version = '2.00';
SELECT count(distinct issueId) FROM scale.FNM_PoolBurnout WHERE version = '2.00';

SELECT count(1) FROM scale.FNM_PoolHist;
SELECT count(1) FROM scale.FNM_PoolDistribution;
SELECT count(1) FROM scale.FNM_PoolEligibility;
SELECT count(1) FROM scale.FNM_PoolIncentive WHERE version = '2.00';
SELECT count(1) FROM scale.FNM_PoolBurnout WHERE version = '2.00';

SELECT version, count(1) FROM scale.FNM_PoolIncentive GROUP BY version;
SELECT version, count(1) FROM scale.FNM_PoolBurnout GROUP BY version;


-- Uniqueness Tests (Should all be 0 rows)

SELECT issueId, asOf, count(1) as cnt FROM scale.FNM_PoolHist GROUP BY issueId, asOf HAVING cnt > 1;
SELECT issueId, asOf, count(1) as cnt FROM scale.FNM_PoolDistribution GROUP BY issueId, asOf HAVING cnt > 1;
SELECT issueId, asOf, count(1) as cnt FROM scale.FNM_PoolEligibility GROUP BY issueId, asOf HAVING cnt > 1;
SELECT issueId, asOf, count(1) as cnt FROM scale.FNM_PoolIncentive WHERE version = '2.00' GROUP BY issueId, asOf HAVING cnt > 1;
SELECT issueId, asOf, count(1) as cnt FROM scale.FNM_PoolBurnout WHERE version = '2.00' GROUP BY issueId, asOf HAVING cnt > 1;


-- Null and Data Validity Tests (Should all be 0 counts)

SELECT count(1) FROM scale.FNM_PoolHist WHERE originationDate IS NULL OR originationDate <= '1950-01-01'
SELECT count(1) FROM scale.FNM_PoolHist WHERE origLoanSize IS NULL OR origLoanSize <= 0.0 OR origLoanSize > 1500000
SELECT count(1) FROM scale.FNM_PoolHist WHERE origFICO IS NULL OR origFICO <= 300.0 OR origFICO > 950
SELECT count(1) FROM scale.FNM_PoolHist WHERE origLTV IS NULL OR origLTV <= 0.0 OR origLTV > 400
SELECT count(1) FROM scale.FNM_PoolHist WHERE origNoteRate IS NULL OR origNoteRate <= 0.0 OR origNoteRate > 20
SELECT count(1) FROM scale.FNM_PoolHist WHERE currLoanSize IS NULL OR currLoanSize <= 0.0 OR currLoanSize > 6500000
SELECT count(1) FROM scale.FNM_PoolHist WHERE cltv IS NULL OR cltv <= 0.0 OR cltv > 1000
SELECT count(1) FROM scale.FNM_PoolHist WHERE HPA IS NULL OR HPA < 0.5 OR HPA > 10

SELECT count(1) FROM scale.FNM_PoolDistribution WHERE Est_Pct_HARPed IS NULL OR Est_Pct_HARPed < 0.0 OR Est_Pct_HARPed > 100
SELECT count(1) FROM scale.FNM_PoolDistribution spd JOIN scale.FNM_PoolHist sph ON spd.issueId = sph.issueId AND spd.asOf = sph.asOf WHERE originationDate >= '1994-01-01' AND (percentOCC_OWN IS NULL OR percentOCC_OWN < 0.0 OR percentOCC_OWN > 100.0)
SELECT count(1) FROM scale.FNM_PoolDistribution spd JOIN scale.FNM_PoolHist sph ON spd.issueId = sph.issueId AND spd.asOf = sph.asOf WHERE originationDate >= '1994-01-01' AND (percentOCC_2ND IS NULL OR percentOCC_2ND < 0.0 OR percentOCC_2ND > 100.0)
SELECT count(1) FROM scale.FNM_PoolDistribution spd JOIN scale.FNM_PoolHist sph ON spd.issueId = sph.issueId AND spd.asOf = sph.asOf WHERE originationDate >= '1994-01-01' AND (percentOCC_INV IS NULL OR percentOCC_INV < 0.0 OR percentOCC_INV > 100.0)
SELECT count(1) FROM scale.FNM_PoolDistribution WHERE abs(percentOCC_OWN + percentOCC_2ND + percentOCC_INV - 100.0) > 0.1
SELECT count(1) FROM scale.FNM_PoolDistribution spd JOIN scale.FNM_PoolHist sph ON spd.issueId = sph.issueId AND spd.asOf = sph.asOf WHERE originationDate >= '1994-01-01' AND (percentPURP_PURCH IS NULL OR percentPURP_PURCH < 0.0 OR percentPURP_PURCH > 100.0)
SELECT count(1) FROM scale.FNM_PoolDistribution spd JOIN scale.FNM_PoolHist sph ON spd.issueId = sph.issueId AND spd.asOf = sph.asOf WHERE originationDate >= '1994-01-01' AND (percentPURP_REFI IS NULL OR percentPURP_REFI < 0.0 OR percentPURP_REFI > 100.0)
SELECT count(1) FROM scale.FNM_PoolDistribution WHERE abs(percentPURP_PURCH + percentPURP_REFI - 100.0) > 0.1
SELECT count(1) FROM scale.FNM_PoolDistribution spd JOIN scale.FNM_PoolHist sph ON spd.issueId = sph.issueId AND spd.asOf = sph.asOf WHERE est_pct_CURRENT IS NULL OR est_pct_CURRENT < 0.0 OR est_pct_CURRENT > 100.0
SELECT count(1) FROM scale.FNM_PoolDistribution spd JOIN scale.FNM_PoolHist sph ON spd.issueId = sph.issueId AND spd.asOf = sph.asOf WHERE est_pct_DELQ30plus IS NULL OR est_pct_DELQ30plus < 0.0 OR est_pct_DELQ30plus > 100.0
SELECT count(1) FROM scale.FNM_PoolDistribution spd JOIN scale.FNM_PoolHist sph ON spd.issueId = sph.issueId AND spd.asOf = sph.asOf WHERE est_pct_DELQ60plus IS NULL OR est_pct_DELQ60plus < 0.0 OR est_pct_DELQ60plus > 100.0
SELECT count(1) FROM scale.FNM_PoolDistribution spd JOIN scale.FNM_PoolHist sph ON spd.issueId = sph.issueId AND spd.asOf = sph.asOf WHERE est_pct_DELQ90plus IS NULL OR est_pct_DELQ90plus < 0.0 OR est_pct_DELQ90plus > 100.0
SELECT count(1) FROM scale.FNM_PoolDistribution WHERE abs(est_pct_CURRENT + est_pct_DELQ30plus - 100.0) > 0.1
SELECT count(1) FROM scale.FNM_PoolDistribution spd JOIN scale.FNM_PoolHist sph ON spd.issueId = sph.issueId AND spd.asOf = sph.asOf WHERE originationDate >= '1995-01-01' AND marketTicker = 'FNCL' AND (percentCHANNEL_RETAIL IS NULL OR percentCHANNEL_RETAIL < 0.0 OR percentCHANNEL_RETAIL > 100.0)
SELECT count(1) FROM scale.FNM_PoolDistribution spd JOIN scale.FNM_PoolHist sph ON spd.issueId = sph.issueId AND spd.asOf = sph.asOf WHERE originationDate >= '1995-01-01' AND marketTicker = 'FNCL' AND (percentCHANNEL_BROKER IS NULL OR percentCHANNEL_BROKER < 0.0 OR percentCHANNEL_BROKER > 100.0)
SELECT count(1) FROM scale.FNM_PoolDistribution spd JOIN scale.FNM_PoolHist sph ON spd.issueId = sph.issueId AND spd.asOf = sph.asOf WHERE originationDate >= '1995-01-01' AND marketTicker = 'FNCL' AND (percentCHANNEL_CORRES IS NULL OR percentCHANNEL_CORRES < 0.0 OR percentCHANNEL_CORRES > 100.0)
SELECT count(1) FROM scale.FNM_PoolDistribution WHERE abs(percentCHANNEL_RETAIL + percentCHANNEL_BROKER + percentCHANNEL_CORRES - 100.0) > 0.1
SELECT count(1) FROM scale.FNM_PoolDistribution spd JOIN scale.FNM_PoolHist sph ON spd.issueId = sph.issueId AND spd.asOf = sph.asOf WHERE originationDate >= '1994-01-01' AND (percentUNIT_SINGLE IS NULL OR percentUNIT_SINGLE < 0.0 OR percentUNIT_SINGLE > 100.0)
SELECT count(1) FROM scale.FNM_PoolDistribution spd JOIN scale.FNM_PoolHist sph ON spd.issueId = sph.issueId AND spd.asOf = sph.asOf WHERE originationDate >= '1994-01-01' AND (percentUNIT_MULTIPLE IS NULL OR percentUNIT_MULTIPLE < 0.0 OR percentUNIT_MULTIPLE > 100.0)
SELECT count(1) FROM scale.FNM_PoolDistribution WHERE abs(percentUNIT_SINGLE + percentUNIT_MULTIPLE -100.0) > 0.1

SELECT count(1) FROM scale.FNM_PoolEligibility WHERE HARP_eligible IS NULL OR HARP_eligible < 0.0 OR HARP_eligible > 100
SELECT count(1) FROM scale.FNM_LoanEligibility WHERE conventional_eligible IS NULL OR conventional_eligible < 0.0 OR conventional_eligible > 100
SELECT count(1) FROM scale.FNM_LoanEligibility WHERE fha_eligible IS NULL OR fha_eligible < 0.0 OR fha_eligible > 100

SELECT count(1) FROM scale.FNM_PoolIncentive WHERE conventional_refi_incentive IS NULL
SELECT count(1) FROM scale.FNM_PoolIncentive WHERE fha_refi_incentive IS NULL
SELECT count(1) FROM scale.FNM_PoolIncentive WHERE origPMI IS NULL
SELECT count(1) FROM scale.FNM_PoolIncentive WHERE currLLPA IS NULL
SELECT count(1) FROM scale.FNM_PoolIncentive WHERE currPMI IS NULL
SELECT count(1) FROM scale.FNM_PoolIncentive WHERE currMIP IS NULL
SELECT count(1) FROM scale.FNM_PoolIncentive WHERE conventional_refi_incentive < -2000.0 OR conventional_refi_incentive > 2000.0
SELECT count(1) FROM scale.FNM_PoolIncentive WHERE fha_refi_incentive < -2000.0 OR fha_refi_incentive > 2000.0
SELECT count(1) FROM scale.FNM_PoolIncentive WHERE origPMI < 0.0 OR origPMI > 500.0
SELECT count(1) FROM scale.FNM_PoolIncentive WHERE currLLPA < -100 OR currLLPA > 2000.0
SELECT count(1) FROM scale.FNM_PoolIncentive WHERE currPMI < 0 OR currPMI > 1000.0
SELECT count(1) FROM scale.FNM_PoolIncentive WHERE currMIP < 0 OR currMIP > 500.0

SELECT count(1) FROM scale.FNM_LoanBurnout WHERE burnout IS NULL
SELECT count(1) FROM scale.FNM_LoanBurnout WHERE burnout < 0.0 OR burnout > 30000


-- Time Series Tests

SELECT marketTicker, originationDate, count(1), sum(origLoanSize), avg(origLoanSize) as avg_ols FROM scale.FNM_PoolHist GROUP BY marketTicker, originationDate HAVING count(1) > 10 ORDER BY originationDate
SELECT marketTicker, asOf, count(1), sum(schamBalance), sum(schamBalance * origLoanSize) / sum(schamBalance) as wavg_ols FROM scale.FNM_PoolHist p GROUP BY marketTicker, asOf HAVING count(1) > 10 ORDER BY asOf

--SELECT marketTicker, originationDate, count(1), sum(origLoanSize), sum(origLoanSize * numberUnits) / sum(origLoanSize) as wavg_units FROM scale.FNM_PoolHist GROUP BY marketTicker, originationDate HAVING count(1) > 10 ORDER BY originationDate
--SELECT marketTicker, asOf, count(1), sum(schamBalance), sum(schamBalance * numberUnits) / sum(schamBalance) as wavg_units FROM scale.FNM_PoolHist p GROUP BY marketTicker, asOf HAVING count(1) > 10 ORDER BY asOf

SELECT marketTicker, originationDate, count(1), sum(origLoanSize), sum(origLoanSize * origFICO) / sum(origLoanSize) as wavg_fico FROM scale.FNM_PoolHist GROUP BY marketTicker, originationDate HAVING count(1) > 10 ORDER BY originationDate
SELECT marketTicker, asOf, count(1), sum(schamBalance), sum(schamBalance * origFICO) / sum(schamBalance) as wavg_fico FROM scale.FNM_PoolHist p GROUP BY marketTicker, asOf HAVING count(1) > 10 ORDER BY asOf

SELECT marketTicker, originationDate, count(1), sum(origLoanSize), sum(origLoanSize * origLTV) / sum(origLoanSize) as wavg_oltv FROM scale.FNM_PoolHist GROUP BY marketTicker, originationDate HAVING count(1) > 10 ORDER BY originationDate
SELECT marketTicker, asOf, count(1), sum(schamBalance), sum(schamBalance * origLTV) / sum(schamBalance) as wavg_oltv FROM scale.FNM_PoolHist p GROUP BY marketTicker, asOf HAVING count(1) > 10 ORDER BY asOf

--SELECT marketTicker, originationDate, count(1), sum(origLoanSize), sum(origLoanSize * dti) / sum(origLoanSize) as wavg_dti FROM scale.FNM_Loan GROUP BY marketTicker, originationDate HAVING count(1) > 10 ORDER BY originationDate
--SELECT marketTicker, asOf, count(1), sum(schamBalance), sum(schamBalance * dti) / sum(schamBalance) as wavg_dti FROM scale.FNM_PoolHist p GROUP BY marketTicker, asOf HAVING count(1) > 10 ORDER BY asOf

SELECT marketTicker, originationDate, count(1), sum(origLoanSize), sum(origLoanSize * origNoteRate) / sum(origLoanSize) as wavg_note_rate FROM scale.FNM_PoolHist GROUP BY marketTicker, originationDate HAVING count(1) > 10 ORDER BY originationDate
SELECT marketTicker, asOf, count(1), sum(schamBalance), sum(schamBalance * origNoteRate) / sum(schamBalance) as wavg_note_rate FROM scale.FNM_PoolHist p GROUP BY marketTicker, asOf HAVING count(1) > 10 ORDER BY asOf

SELECT marketTicker, originationDate, count(1), sum(origLoanSize), sum(origLoanSize * miLevel) / sum(origLoanSize) as wavg_mi_level FROM scale.FNM_PoolHist GROUP BY marketTicker, originationDate HAVING count(1) > 10  ORDER BY originationDate
SELECT marketTicker, originationDate, count(1), sum(origLoanSize), sum(origLoanSize * miLevel) / sum(origLoanSize) as wavg_mi_level FROM scale.FNM_Loan GROUP BY marketTicker, originationDate HAVING count(1) > 10 ORDER BY originationDate
SELECT marketTicker, originationDate, count(1), sum(origLoanSize), sum(origLoanSize * miLevel) / sum(origLoanSize) as wavg_mi_level FROM scale.FHL_Loan GROUP BY marketTicker, originationDate HAVING count(1) > 10 ORDER BY originationDate
SELECT marketTicker, asOf, count(1), sum(schamBalance), sum(schamBalance * miLevel) / sum(schamBalance) as wavg_mi_level FROM scale.FNM_PoolHist p GROUP BY marketTicker, asOf HAVING count(1) > 10 ORDER BY asOf


--SELECT marketTicker, originationDate, count(1), sum(origLoanSize), sum(origLoanSize * HPI_orig) / sum(origLoanSize) as wavg_orig_hpi FROM scale.FNM_PoolHist GROUP BY marketTicker, originationDate HAVING count(1) > 10 ORDER BY originationDate
--SELECT marketTicker, asOf, count(1), sum(schamBalance), sum(schamBalance * HPI_orig) / sum(schamBalance) as wavg_orig_hpi FROM scale.FNM_PoolHist p GROUP BY marketTicker, asOf HAVING count(1) > 10 ORDER BY asOf

SELECT marketTicker, originationDate, count(1), sum(schamBalance), sum(schamBalance * cltv) / sum(schamBalance) as wavg_cltv FROM scale.FNM_PoolHist GROUP BY marketTicker, originationDate HAVING count(1) > 10 ORDER BY originationDate
SELECT marketTicker, asOf, count(1), sum(schamBalance), sum(schamBalance * cltv) / sum(schamBalance) as wavg_cltv FROM scale.FNM_PoolHist p GROUP BY marketTicker, asOf HAVING count(1) > 10 ORDER BY asOf

SELECT marketTicker, originationDate, count(1), sum(schamBalance), sum(schamBalance * hpa) / sum(schamBalance) as wavg_hpa FROM scale.FNM_PoolHist GROUP BY marketTicker, originationDate HAVING count(1) > 10 ORDER BY originationDate
SELECT marketTicker, asOf, count(1), sum(schamBalance), sum(schamBalance * hpa) / sum(schamBalance) as wavg_hpa FROM scale.FNM_PoolHist p GROUP BY marketTicker, asOf HAVING count(1) > 10 ORDER BY asOf


--SELECT marketTicker, originationDate, count(1), sum(origLoanSize), sum(origLoanSize * origPMI) / sum(origLoanSize) as wavg_orig_pmi FROM scale.FNM_Loan GROUP BY marketTicker, originationDate HAVING count(1) > 10 ORDER BY originationDate
--SELECT marketTicker, asOf, count(1), sum(schamBalance), sum(schamBalance * origPMI) / sum(schamBalance) as wavg_orig_pmi FROM scale.FNM_PoolHist GROUP BY marketTicker, asOf HAVING count(1) > 10 ORDER BY asOf

SELECT marketTicker, originationDate, count(1), sum(origLoanSize), sum(origLoanSize * percentHARPed) / sum(origLoanSize) as wavg_pct_harped FROM scale.FNM_PoolHist p JOIN scale.FNM_PoolDistribution d ON p.issueId = d.issueId AND p.asOf = d.asOf GROUP BY marketTicker, originationDate HAVING count(1) > 10 ORDER BY originationDate
SELECT marketTicker, p.asOf, count(1), sum(schamBalance), sum(schamBalance * CASE WHEN percentHARPed IS NULL THEN Est_Pct_HARPed ELSE percentHARPed END) / sum(schamBalance) as wavg_pct_harped FROM scale.FNM_PoolHist p JOIN scale.FNM_PoolDistribution d ON p.issueId = d.issueId AND p.asOf = d.asOf GROUP BY p.marketTicker, p.asOf HAVING count(1) > 10 ORDER BY p.asOf

SELECT marketTicker, p.asOf, count(1), sum(schamBalance), sum(schamBalance * est_pct_DELQ30plus) / sum(schamBalance) as wavg_est_pct_DELQ FROM scale.FNM_PoolHist p JOIN scale.FNM_PoolDistribution d ON p.issueId = d.issueId AND p.asOf = d.asOf GROUP BY p.marketTicker, p.asOf HAVING count(1) > 10 ORDER BY p.asOf

SELECT marketTicker, originationDate, count(1), sum(schamBalance), sum(schamBalance * HARP_eligible) / sum(CASE WHEN HARP_eligible IS NULL THEN 0.0 ELSE schamBalance END) as wavg_pct_harp_eligible FROM scale.FNM_PoolHist p JOIN FNM_PoolEligibility d ON p.issueId = d.issueId AND p.asOf = d.asOf GROUP BY marketTicker, originationDate ORDER BY originationDate
SELECT marketTicker, p.asOf, count(1), sum(schamBalance), sum(schamBalance * HARP_eligible) / sum(CASE WHEN HARP_eligible IS NULL THEN 0.0 ELSE schamBalance END) as wavg_pct_harp_eligible FROM scale.FNM_PoolHist p JOIN FNM_PoolEligibility d ON p.issueId = d.issueId AND p.asOf = d.asOf GROUP BY marketTicker, p.asOf ORDER BY p.asOf

SELECT marketTicker, originationDate, count(1), sum(schamBalance), sum(schamBalance * conventional_eligible) / sum(CASE WHEN conventional_eligible IS NULL THEN 0.0 ELSE schamBalance END) as wavg_pct_conventional_eligible FROM scale.FNM_PoolHist p JOIN FNM_PoolEligibility d ON p.issueId = d.issueId AND p.asOf = d.asOf GROUP BY marketTicker, originationDate ORDER BY originationDate
SELECT marketTicker, p.asOf, count(1), sum(schamBalance), sum(schamBalance * conventional_eligible) / sum(CASE WHEN conventional_eligible IS NULL THEN 0.0 ELSE schamBalance END) as wavg_pct_conventional_eligible FROM scale.FNM_PoolHist p JOIN FNM_PoolEligibility d ON p.issueId = d.issueId AND p.asOf = d.asOf GROUP BY marketTicker, p.asOf ORDER BY p.asOf

SELECT marketTicker, originationDate, count(1), sum(schamBalance), sum(schamBalance * fha_eligible) / sum(CASE WHEN fha_eligible IS NULL THEN 0.0 ELSE schamBalance END) as wavg_pct_fha_eligible FROM scale.FNM_PoolHist p JOIN FNM_PoolEligibility d ON p.issueId = d.issueId AND p.asOf = d.asOf GROUP BY marketTicker, originationDate ORDER BY originationDate
SELECT marketTicker, p.asOf, count(1), sum(schamBalance), sum(schamBalance * fha_eligible) / sum(CASE WHEN fha_eligible IS NULL THEN 0.0 ELSE schamBalance END) as wavg_pct_fha_eligible FROM scale.FNM_PoolHist p JOIN FNM_PoolEligibility d ON p.issueId = d.issueId AND p.asOf = d.asOf GROUP BY marketTicker, p.asOf ORDER BY p.asOf



SELECT marketTicker, originationDate, count(1), sum(schamBalance), sum(schamBalance * conventional_refi_incentive) / sum(CASE WHEN conventional_refi_incentive IS NULL THEN 0.0 ELSE schamBalance END) as wavg_conv_incentive FROM scale.FNM_PoolHist p JOIN scale.FNM_PoolIncentive d ON p.issueId = d.issueId AND p.asOf = d.asOf WHERE version = '2.00' GROUP BY marketTicker, originationDate ORDER BY originationDate
SELECT marketTicker, p.asOf, count(1), sum(schamBalance), sum(schamBalance * conventional_refi_incentive) / sum(CASE WHEN conventional_refi_incentive IS NULL THEN 0.0 ELSE schamBalance END) as wavg_conv_incentive FROM scale.FNM_PoolHist p JOIN scale.FNM_PoolIncentive d ON p.issueId = d.issueId AND p.asOf = d.asOf WHERE version = '2.00' GROUP BY marketTicker, p.asOf ORDER BY p.asOf

SELECT marketTicker, originationDate, count(1), sum(schamBalance), sum(schamBalance * fha_refi_incentive) / sum(CASE WHEN fha_refi_incentive IS NULL THEN 0.0 ELSE schamBalance END) as wavg_fha_incentive FROM scale.FNM_PoolHist p JOIN scale.FNM_PoolIncentive d ON p.issueId = d.issueId AND p.asOf = d.asOf WHERE version = '2.00' GROUP BY marketTicker, originationDate ORDER BY originationDate
SELECT marketTicker, p.asOf, count(1), sum(schamBalance), sum(schamBalance * fha_refi_incentive) / sum(CASE WHEN fha_refi_incentive IS NULL THEN 0.0 ELSE schamBalance END) as wavg_fha_incentive FROM scale.FNM_PoolHist p JOIN scale.FNM_PoolIncentive d ON p.issueId = d.issueId AND p.asOf = d.asOf WHERE version = '2.00' GROUP BY marketTicker, p.asOf ORDER BY p.asOf

SELECT marketTicker, originationDate, count(1), sum(schamBalance), sum(schamBalance * refi_incentive) / sum(CASE WHEN refi_incentive IS NULL THEN 0.0 ELSE schamBalance END) as refi_incentive FROM scale.FNM_PoolHist p JOIN scale.FNM_PoolIncentive d ON p.issueId = d.issueId AND p.asOf = d.asOf WHERE version = '2.00' GROUP BY marketTicker, originationDate ORDER BY originationDate
SELECT marketTicker, p.asOf, count(1), sum(schamBalance), sum(schamBalance * refi_incentive) / sum(CASE WHEN refi_incentive IS NULL THEN 0.0 ELSE schamBalance END) as refi_incentive FROM scale.FNM_PoolHist p JOIN scale.FNM_PoolIncentive d ON p.issueId = d.issueId AND p.asOf = d.asOf WHERE version = '2.00' GROUP BY marketTicker, p.asOf ORDER BY p.asOf



SELECT marketTicker, originationDate, count(1), sum(schamBalance), sum(schamBalance * burnout) / sum(CASE WHEN burnout IS NULL THEN 0.0 ELSE schamBalance END) as burnout FROM scale.FNM_PoolHist p JOIN scale.FNM_PoolBurnout d ON p.issueId = d.issueId AND p.asOf = d.asOf WHERE version = '2.00' GROUP BY marketTicker, originationDate ORDER BY originationDate
SELECT marketTicker, p.asOf, count(1), sum(schamBalance), sum(schamBalance * burnout) / sum(CASE WHEN burnout IS NULL THEN 0.0 ELSE schamBalance END) as burnout FROM scale.FNM_PoolHist p JOIN scale.FNM_PoolBurnout d ON p.issueId = d.issueId AND p.asOf = d.asOf WHERE version = '2.00' GROUP BY marketTicker, p.asOf ORDER BY p.asOf

SELECT marketTicker, p.asOf, count(1), sum(schamBalance), sum(schamBalance * burnout) / sum(CASE WHEN burnout IS NULL THEN 0.0 ELSE schamBalance END) as burnout FROM scale.FNM_PoolHist p JOIN scale.FNM_PoolBurnout d ON p.issueId = d.issueId AND p.asOf = d.asOf WHERE version = '2.30' GROUP BY marketTicker, p.asOf ORDER BY p.asOf

commit;


-- FHL / FNM compare
SELECT marketTicker, p.asOf, count(1), sum(balance), sum(balance * refi_incentive) / sum(CASE WHEN refi_incentive IS NULL THEN 0.0 ELSE balance END) as refi_incentive FROM scale.FNM_PoolHist p JOIN scale.FNM_PoolIncentive d ON p.issueId = d.issueId AND p.asOf = d.asOf WHERE version = '2.00' GROUP BY marketTicker, p.asOf ORDER BY p.asOf
SELECT marketTicker, p.asOf, count(1), sum(balance), sum(balance * refi_incentive) / sum(CASE WHEN refi_incentive IS NULL THEN 0.0 ELSE balance END) as refi_incentive FROM scale.FHL_PoolHist p JOIN scale.FHL_PoolIncentive d ON p.issueId = d.issueId AND p.asOf = d.asOf WHERE version = '2.00' GROUP BY marketTicker, p.asOf ORDER BY p.asOf


SELECT marketTicker, p.asOf, count(1), sum(balance), sum(balance * fha_eligible) / sum(CASE WHEN fha_eligible IS NULL THEN 0.0 ELSE balance END) as wavg_pct_fha_eligible FROM scale.FNM_PoolHist p JOIN FNM_PoolEligibility d ON p.issueId = d.issueId AND p.asOf = d.asOf  WHERE marketTicker = 'FNCQ30' GROUP BY marketTicker, p.asOf ORDER BY p.asOf
SELECT marketTicker, p.asOf, count(1), sum(balance), sum(balance * fha_eligible) / sum(CASE WHEN fha_eligible IS NULL THEN 0.0 ELSE balance END) as wavg_pct_fha_eligible FROM scale.FHL_PoolHist p JOIN FHL_PoolEligibility d ON p.issueId = d.issueId AND p.asOf = d.asOf GROUP BY marketTicker, p.asOf ORDER BY p.asOf

SELECT marketTicker, p.asOf, count(1), sum(balance), sum(balance * conventional_eligible) / sum(CASE WHEN conventional_eligible IS NULL THEN 0.0 ELSE balance END) as wavg_pct_conventional_eligible FROM scale.FNM_PoolHist p JOIN FNM_PoolEligibility d ON p.issueId = d.issueId AND p.asOf = d.asOf WHERE marketTicker = 'FNCQ30' GROUP BY marketTicker, p.asOf ORDER BY p.asOf
SELECT marketTicker, p.asOf, count(1), sum(balance), sum(balance * conventional_eligible) / sum(CASE WHEN conventional_eligible IS NULL THEN 0.0 ELSE balance END) as wavg_pct_conventional_eligible FROM scale.FHL_PoolHist p JOIN FHL_PoolEligibility d ON p.issueId = d.issueId AND p.asOf = d.asOf GROUP BY marketTicker, p.asOf ORDER BY p.asOf

SELECT marketTicker, p.asOf, count(1), sum(balance), sum(balance * HARP_eligible) / sum(CASE WHEN HARP_eligible IS NULL THEN 0.0 ELSE balance END) as wavg_pct_HARP_eligible FROM scale.FNM_PoolHist p JOIN FNM_PoolEligibility d ON p.issueId = d.issueId AND p.asOf = d.asOf WHERE marketTicker = 'FNCQ30' GROUP BY marketTicker, p.asOf ORDER BY p.asOf
SELECT marketTicker, p.asOf, count(1), sum(balance), sum(balance * HARP_eligible) / sum(CASE WHEN HARP_eligible IS NULL THEN 0.0 ELSE balance END) as wavg_pct_HARP_eligible FROM scale.FHL_PoolHist p JOIN FHL_PoolEligibility d ON p.issueId = d.issueId AND p.asOf = d.asOf GROUP BY marketTicker, p.asOf ORDER BY p.asOf


SELECT marketTicker, p.asOf, count(1), sum(balance), sum(balance * refi_eligible) / sum(CASE WHEN refi_eligible IS NULL THEN 0.0 ELSE balance END) as wavg_pct_refi_eligible FROM scale.FNM_PoolHist p JOIN FNM_PoolEligibility d ON p.issueId = d.issueId AND p.asOf = d.asOf GROUP BY marketTicker, p.asOf ORDER BY p.asOf
SELECT marketTicker, p.asOf, count(1), sum(balance), sum(balance * refi_eligible) / sum(CASE WHEN refi_eligible IS NULL THEN 0.0 ELSE balance END) as wavg_pct_refi_eligible FROM scale.FHL_PoolHist p JOIN FHL_PoolEligibility d ON p.issueId = d.issueId AND p.asOf = d.asOf GROUP BY marketTicker, p.asOf ORDER BY p.asOf


SELECT marketTicker, p.asOf, count(1), sum(balance), sum(balance * burnout) / sum(CASE WHEN burnout IS NULL THEN 0.0 ELSE balance END) as burnout FROM scale.FNM_PoolHist p JOIN scale.FNM_PoolBurnout d ON p.issueId = d.issueId AND p.asOf = d.asOf WHERE version = '2.40' GROUP BY marketTicker, p.asOf ORDER BY p.asOf
SELECT marketTicker, p.asOf, count(1), sum(balance), sum(balance * burnout) / sum(CASE WHEN burnout IS NULL THEN 0.0 ELSE balance END) as burnout FROM scale.FHL_PoolHist p JOIN scale.FHL_PoolBurnout d ON p.issueId = d.issueId AND p.asOf = d.asOf WHERE version = '2.40' GROUP BY marketTicker, p.asOf ORDER BY p.asOf
