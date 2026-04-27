-- Freddie Conventional
-- Pool Level
-- Part 4 of 6
-- Script to update the eligibility metrics
-- Updates HARP_eligible, conventional_eligible and fha_eligible

INSERT INTO scale.jobstatus(StartTime,JobName,JobStatus)
VALUES (getdate(),'FHL_Pool_Step 4_Create_Pool_Eligibility_Table','START');
COMMIT;

-- Before execute the script, need to set the dates to run for
DROP TABLE IF EXISTS #tmp_asOf;
SELECT CAST('#####ASOF#####' AS DATE) asOf, CAST('#####LAST#####' AS DATE) asOf_last INTO #tmp_asOf
--SELECT CAST ('1994-02-01' AS DATE) asOf, CAST('2018-04-01' AS DATE) asOf_last INTO #tmp_asOf
;

-- Before execute the script, need to set the tickers
DROP TABLE IF EXISTS #ticker;
CREATE TABLE #ticker(
    tickerName varchar(20),
    mtgRateSeries varchar(30)
)
;
INSERT #ticker SELECT 'FGLMC', 'CONVENTIONAL_30YR';   --30 Yr Conventional Freddie
INSERT #ticker SELECT 'FGT6', 'JUMBO_30YR';           --30 Yr Jumbo Freddie
INSERT #ticker SELECT 'FGU6', 'CONVENTIONAL_30YR';    --30 Yr CQ Freddie High LTV[105-125]
INSERT #ticker SELECT 'FGU9', 'CONVENTIONAL_30YR';    --30 Yr CR Freddie High LTV[125-150]
--INSERT #ticker SELECT 'FGTW', 'CONVENTIONAL_20YR';    --20 Yr Conventional Freddie
--INSERT #ticker SELECT 'FGCI', 'CONVENTIONAL_15YR';    --15 Yr Conventional Freddie
COMMIT;

CREATE LF INDEX loan_tickerName_idx ON #ticker(tickerName);
COMMIT;


-- Create Pool Historical Data
DROP TABLE IF EXISTS #FHL_PoolEligibility;
SELECT
    ph.marketTicker,
    ph.issueId,
    ph.asOf,
    ph.originationDate,
    ph.balance,
    cast(NULL as numeric(6, 3)) as HARP_eligible,
    cast(NULL as numeric(6, 3)) as conventional_eligible,
    cast(NULL as numeric(6, 3)) as fha_eligible,
    cast(NULL as numeric(6, 3)) as refi_eligible
INTO #FHL_PoolEligibility
FROM scale.FHL_PoolHist ph
JOIN #ticker tk
    ON ph.marketTicker = tk.tickerName
WHERE 1=1
    AND ph.asOf >= (select asOf from #tmp_asOf)
	AND ph.asOf <= (select asOf_last from #tmp_asOf)
;
COMMIT;

CREATE HG INDEX issueId_idx ON #FHL_PoolEligibility(issueId);
CREATE LF INDEX asOf_idx ON #FHL_PoolEligibility(asOf);
CREATE LF INDEX ticker_idx ON #FHL_PoolEligibility(marketTicker);
COMMIT;

-- Create HARP Eligibility from Loan Data
DROP TABLE IF EXISTS #FHL_Loan_HARPEligibility;
SELECT
    pe.issueId,
    pe.asOf,
    sum(sle.HARP_eligible * slh.balance) / sum(slh.balance) as HARP_eligible
INTO #FHL_Loan_HARPEligibility
FROM #FHL_PoolEligibility pe
JOIN fhl.PIV_Loan cl
    ON pe.issueId = cl.issueId
JOIN scale.fhl_LoanHist slh
    ON cl.loanSeqNum = slh.loanSeqNum
    AND pe.asOf = slh.asOf
JOIN scale.FHL_LoanEligibility sle
    ON slh.loanSeqNum = sle.loanSeqNum
    AND slh.asOf = sle.asOf
WHERE 1=1
    AND sle.HARP_eligible IS NOT NULL
GROUP BY pe.issueId, pe.asOf
;
COMMIT;

UPDATE #FHL_PoolEligibility pe SET pe.HARP_eligible = 100.0 * he.HARP_eligible
FROM #FHL_Loan_HARPEligibility he
WHERE pe.issueId = he.issueId
    AND pe.asOf = he.asOf
;

DROP TABLE IF EXISTS #FHL_MIN_HARPEligibility;
SELECT
    issueId,
    min(asOf) as min_asOf,
    cast(NULL as numeric(6, 3)) as earliest_HARP_eligible
INTO #FHL_MIN_HARPEligibility
FROM #FHL_PoolEligibility
WHERE 1=1
    AND HARP_eligible IS NOT NULL
    AND issueId in (SELECT distinct issueId from #FHL_Loan_HARPEligibility)
GROUP BY issueId
;
COMMIT;

UPDATE #FHL_MIN_HARPEligibility mhe SET mhe.earliest_HARP_eligible = pe.HARP_eligible
FROM #FHL_PoolEligibility pe
WHERE mhe.issueId = pe.issueId
    AND mhe.min_asOf = pe.asOf
;

UPDATE #FHL_PoolEligibility pe SET pe.HARP_eligible = mhe.earliest_HARP_eligible
FROM #FHL_MIN_HARPEligibility mhe
WHERE pe.issueId = mhe.issueId
    AND pe.HARP_eligible IS NULL
;
COMMIT;

-- Create HARP Eligibility from Pool Data
DROP TABLE IF EXISTS #FHL_Pool_HARPEligibility;
SELECT
    pe.issueId,
    pe.asOf,
    CASE
        WHEN pe.marketTicker in ('FGU6','FGU9') THEN 0.0
        WHEN pe.originationDate > '2009-06-01' THEN 0.0
        WHEN pe.asOf < '2009-06-01' THEN 0.0
        WHEN pe.asOf > '2017-09-01' THEN 0.0
        ELSE 1.0
    END as HARP_eligible
INTO #FHL_Pool_HARPEligibility
FROM #FHL_PoolEligibility pe
WHERE 1=1
    AND pe.HARP_eligible IS NULL
;
COMMIT;

UPDATE #FHL_PoolEligibility pe SET pe.HARP_eligible = 100.0 * he.HARP_eligible
FROM #FHL_Pool_HARPEligibility he
WHERE pe.issueId = he.issueId
    AND pe.asOf = he.asOf
;
COMMIT;


-- Create Conventional Eligibility from Loan Data
DROP TABLE IF EXISTS #FHL_Loan_ConventionalEligibility;
SELECT
    pe.issueId,
    pe.asOf,
    sum(sle.conventional_eligible * slh.balance) / sum(slh.balance) as conventional_eligible
INTO #FHL_Loan_ConventionalEligibility
FROM #FHL_PoolEligibility pe
JOIN fhl.PIV_Loan cl
    ON pe.issueId = cl.issueId
JOIN scale.fhl_LoanHist slh
    ON cl.loanSeqNum = slh.loanSeqNum
    AND pe.asOf = slh.asOf
JOIN scale.FHL_LoanEligibility sle
    ON slh.loanSeqNum = sle.loanSeqNum
    AND slh.asOf = sle.asOf
WHERE 1=1
    AND sle.conventional_eligible IS NOT NULL
GROUP BY pe.issueId, pe.asOf
;
COMMIT;

UPDATE #FHL_PoolEligibility pe SET pe.conventional_eligible = 100.0 * ce.conventional_eligible
FROM #FHL_Loan_ConventionalEligibility ce
WHERE pe.issueId = ce.issueId
    AND pe.asOf = ce.asOf
;
COMMIT;

DROP TABLE IF EXISTS #FHL_MIN_ConventionalEligibility;
SELECT
    issueId,
    min(asOf) as min_asOf,
    cast(NULL as numeric(6, 3)) as earliest_conventional_eligible
INTO #FHL_MIN_ConventionalEligibility
FROM #FHL_PoolEligibility
WHERE 1=1
    AND conventional_eligible IS NOT NULL
    AND issueId in (SELECT distinct issueId from #FHL_Loan_ConventionalEligibility)
GROUP BY issueId
;
COMMIT;

UPDATE #FHL_MIN_ConventionalEligibility mce SET mce.earliest_conventional_eligible = pe.conventional_eligible
FROM #FHL_PoolEligibility pe
WHERE mce.issueId = pe.issueId
    AND mce.min_asOf = pe.asOf
;

UPDATE #FHL_PoolEligibility pe SET pe.conventional_eligible = mce.earliest_conventional_eligible
FROM #FHL_MIN_ConventionalEligibility mce
WHERE pe.issueId = mce.issueId
    AND pe.conventional_eligible IS NULL
;
COMMIT;

UPDATE #FHL_PoolEligibility SET conventional_eligible = NULL WHERE asOf < '2006-09-01';
COMMIT;


-- Update Conventional Eligibility from Pool Data

  -- Step 1: Update OLTV Quartile to CLTV Quartile
DROP TABLE IF EXISTS #FHL_Pool_WACLTVquartile;
SELECT
    pe.issueId,
    pe.asOf,
    sph.origLTV,
    sph.cltv,
    cast(NULL as date) as min_asOf,
    q1Min,
    q1Max,
    q2Min,
    q2Max,
    q3Min,
    q3Max,
    q4Min,
    q4Max
INTO #FHL_Pool_WACLTVquartile
FROM #FHL_PoolEligibility pe
JOIN scale.FHL_PoolHist sph
    ON pe.issueId = sph.issueId
    AND pe.asOf = sph.asOf
LEFT JOIN fhl.WAOLTVquartile qt
    ON sph.issueId = qt.issueId
    AND sph.asOf = qt.asOf
    AND qt.quartileType = 'OLTV'
    AND q4Max > 0.0
;

DROP TABLE IF EXISTS #FHL_MIN_WACLTVquartile;
SELECT
    issueId,
    min(asOf) as min_asOf,
    cast(NULL as numeric(8, 3)) as earliest_q1Min,
    cast(NULL as numeric(8, 3)) as earliest_q1Max,
    cast(NULL as numeric(8, 3)) as earliest_q2Min,
    cast(NULL as numeric(8, 3)) as earliest_q2Max,
    cast(NULL as numeric(8, 3)) as earliest_q3Min,
    cast(NULL as numeric(8, 3)) as earliest_q3Max,
    cast(NULL as numeric(8, 3)) as earliest_q4Min,
    cast(NULL as numeric(8, 3)) as earliest_q4Max
INTO #FHL_MIN_WACLTVquartile
FROM #FHL_Pool_WACLTVquartile
WHERE q1Min IS NOT NULL
GROUP BY issueId
;

UPDATE #FHL_MIN_WACLTVquartile mqt SET
    mqt.earliest_q1Min = qt.q1Min,
    mqt.earliest_q1Max = qt.q1Max,
    mqt.earliest_q2Min = qt.q2Min,
    mqt.earliest_q2Max = qt.q2Max,
    mqt.earliest_q3Min = qt.q3Min,
    mqt.earliest_q3Max = qt.q3Max,
    mqt.earliest_q4Min = qt.q4Min,
    mqt.earliest_q4Max = qt.q4Max
FROM #FHL_Pool_WACLTVquartile qt
WHERE mqt.issueId = qt.issueId
    AND mqt.min_asOf = qt.asOf
;

UPDATE #FHL_Pool_WACLTVquartile qt SET 
    qt.min_asOf = mqt.min_asOf,
    qt.q1Min = mqt.earliest_q1Min,
    qt.q1Max = mqt.earliest_q1Max,
    qt.q2Min = mqt.earliest_q2Min,
    qt.q2Max = mqt.earliest_q2Max,
    qt.q3Min = mqt.earliest_q3Min,
    qt.q3Max = mqt.earliest_q3Max,
    qt.q4Min = mqt.earliest_q4Min,
    qt.q4Max = mqt.earliest_q4Max
FROM #FHL_MIN_WACLTVquartile mqt
WHERE qt.issueId = mqt.issueId
    AND qt.q1Min IS NULL
;

UPDATE #FHL_Pool_WACLTVquartile SET
    q1Min = CASE WHEN origLTV > 0.0 THEN (cltv / origLTV) * q1Min ELSE q1Min END,
    q1Max = CASE WHEN origLTV > 0.0 THEN (cltv / origLTV) * q1Max ELSE q1Max END,
    q2Min = CASE WHEN origLTV > 0.0 THEN (cltv / origLTV) * q2Min ELSE q2Min END,
    q2Max = CASE WHEN origLTV > 0.0 THEN (cltv / origLTV) * q2Max ELSE q2Max END,
    q3Min = CASE WHEN origLTV > 0.0 THEN (cltv / origLTV) * q3Min ELSE q3Min END,
    q3Max = CASE WHEN origLTV > 0.0 THEN (cltv / origLTV) * q3Max ELSE q3Max END,
    q4Min = CASE WHEN origLTV > 0.0 THEN (cltv / origLTV) * q4Min ELSE q4Min END,
    q4Max = CASE WHEN origLTV > 0.0 THEN (cltv / origLTV) * q4Max ELSE q4Max END
;
COMMIT;

DELETE FROM #FHL_Pool_WACLTVquartile
WHERE q4Max IS NULL;
COMMIT;

  -- Step 1b: Update FICO Quartile farther back in time
DROP TABLE IF EXISTS #FHL_Pool_WAFICOquartile;
SELECT
    pe.issueId,
    pe.asOf,
    sph.origFICO,
    wtdAvg as waocs,
    cast(NULL as date) as min_asOf,
    q1Min,
    q1Max,
    q2Min,
    q2Max,
    q3Min,
    q3Max,
    q4Min,
    q4Max
INTO #FHL_Pool_WAFICOquartile
FROM #FHL_PoolEligibility pe
JOIN scale.FHL_PoolHist sph
    ON pe.issueId = sph.issueId
    AND pe.asOf = sph.asOf
LEFT JOIN fhl.WAOCSquartile qt
    ON sph.issueId = qt.issueId
    AND sph.asOf = qt.asOf
    AND qt.quartileType = 'OCS'
    AND q4Max > 0.0
;

DROP TABLE IF EXISTS #FHL_MIN_WAFICOquartile;
SELECT
    issueId,
    min(asOf) as min_asOf,
    cast(NULL as numeric(8, 3)) as earliest_waocs,
    cast(NULL as numeric(8, 3)) as earliest_q1Min,
    cast(NULL as numeric(8, 3)) as earliest_q1Max,
    cast(NULL as numeric(8, 3)) as earliest_q2Min,
    cast(NULL as numeric(8, 3)) as earliest_q2Max,
    cast(NULL as numeric(8, 3)) as earliest_q3Min,
    cast(NULL as numeric(8, 3)) as earliest_q3Max,
    cast(NULL as numeric(8, 3)) as earliest_q4Min,
    cast(NULL as numeric(8, 3)) as earliest_q4Max
INTO #FHL_MIN_WAFICOquartile
FROM #FHL_Pool_WAFICOquartile
WHERE q1Min IS NOT NULL
GROUP BY issueId
;

UPDATE #FHL_MIN_WAFICOquartile mqt SET
    mqt.earliest_waocs = qt.waocs,
    mqt.earliest_q1Min = qt.q1Min,
    mqt.earliest_q1Max = qt.q1Max,
    mqt.earliest_q2Min = qt.q2Min,
    mqt.earliest_q2Max = qt.q2Max,
    mqt.earliest_q3Min = qt.q3Min,
    mqt.earliest_q3Max = qt.q3Max,
    mqt.earliest_q4Min = qt.q4Min,
    mqt.earliest_q4Max = qt.q4Max
FROM #FHL_Pool_WAFICOquartile qt
WHERE mqt.issueId = qt.issueId
    AND mqt.min_asOf = qt.asOf
;

UPDATE #FHL_Pool_WAFICOquartile qt SET
    qt.min_asOf = mqt.min_asOf,
    qt.waocs = mqt.earliest_waocs,
    qt.q1Min = mqt.earliest_q1Min,
    qt.q1Max = mqt.earliest_q1Max,
    qt.q2Min = mqt.earliest_q2Min,
    qt.q2Max = mqt.earliest_q2Max,
    qt.q3Min = mqt.earliest_q3Min,
    qt.q3Max = mqt.earliest_q3Max,
    qt.q4Min = mqt.earliest_q4Min,
    qt.q4Max = mqt.earliest_q4Max
FROM #FHL_MIN_WAFICOquartile mqt
WHERE qt.issueId = mqt.issueId
    AND qt.q1Min IS NULL
;

UPDATE #FHL_Pool_WAFICOquartile SET
    q1Min = CASE WHEN waocs > 0.0 THEN (origFICO / waocs) * q1Min ELSE q1Min END,
    q1Max = CASE WHEN waocs > 0.0 THEN (origFICO / waocs) * q1Max ELSE q1Max END,
    q2Min = CASE WHEN waocs > 0.0 THEN (origFICO / waocs) * q2Min ELSE q2Min END,
    q2Max = CASE WHEN waocs > 0.0 THEN (origFICO / waocs) * q2Max ELSE q2Max END,
    q3Min = CASE WHEN waocs > 0.0 THEN (origFICO / waocs) * q3Min ELSE q3Min END,
    q3Max = CASE WHEN waocs > 0.0 THEN (origFICO / waocs) * q3Max ELSE q3Max END,
    q4Min = CASE WHEN waocs > 0.0 THEN (origFICO / waocs) * q4Min ELSE q4Min END,
    q4Max = CASE WHEN waocs > 0.0 THEN (origFICO / waocs) * q4Max ELSE q4Max END
WHERE asOf < min_asOf
;
COMMIT;

DELETE FROM #FHL_Pool_WAFICOquartile
WHERE q4Max IS NULL;
COMMIT;

  -- Step 2: Estimate Percent of Pool > 97 CLTV or < 620 FICO
DROP TABLE IF EXISTS #FHL_FICO_Eligible;
SELECT
    qf.issueId,
    qf.asOf,
    CASE 
        WHEN 620 <= q1Min THEN 0.0
        WHEN 620 <= q2Min THEN 0.0  + ((620.0-q1Min)/(q2Min-q1Min)) * 25.0
        WHEN 620 <= q3Min THEN 25.0 + ((620.0-q2Min)/(q3Min-q2Min)) * 25.0
        WHEN 620 <= q4Min THEN 50.0 + ((620.0-q3Min)/(q4Min-q3Min)) * 25.0
        WHEN 620 <= q4Max THEN 75.0 + ((620.0-q4Min)/(q4Max-q4Min)) * 25.0
        WHEN 620 > q4Max THEN 100.0
        ELSE NULL
    END as percent_not_eligible_fico,
    100.0 - percent_not_eligible_fico as percent_eligible_fico
INTO #FHL_FICO_Eligible
FROM #FHL_Pool_WAFICOquartile qf
JOIN #FHL_PoolEligibility pe
    ON qf.issueId = pe.issueId
    AND qf.asOf = pe.asOf
WHERE 1=1
    AND pe.conventional_eligible IS NULL
;

DROP TABLE IF EXISTS #FHL_CLTV_Eligible;
SELECT
    ql.issueId,
    ql.asOf,
    CASE 
        WHEN q4Max <= 97.0 THEN 100.0
        WHEN q3Max <= 97.0 THEN 75.0 + ((97.0-q3Max)/(q4Max-q3Max)) * 25.0
        WHEN q2Max <= 97.0 THEN 50.0 + ((97.0-q2Max)/(q3Max-q2Max)) * 25.0
        WHEN q1Max <= 97.0 THEN 25.0 + ((97.0-q1Max)/(q2Max-q1Max)) * 25.0
        WHEN q1Min <= 97.0 THEN 0.0  + ((97.0-q1Min)/(q1Max-q1Min)) * 25.0
        WHEN q1Min > 97.0 THEN 0.0
        ELSE NULL
    END as percent_eligible_ltv,
    100.0 - percent_eligible_ltv as percent_not_eligible_ltv
INTO #FHL_CLTV_Eligible
FROM #FHL_Pool_WACLTVquartile ql
JOIN #FHL_PoolEligibility pe
    ON ql.issueId = pe.issueId
    AND ql.asOf = pe.asOf
WHERE 1=1
    AND pe.conventional_eligible IS NULL
;

  -- Step 3: Combine FICO and CLTV percent not eligible
UPDATE #FHL_PoolEligibility pe SET pe.conventional_eligible = 100.0 - (IFNULL(percent_not_eligible_fico, 0.0, percent_not_eligible_fico) + percent_not_eligible_ltv - (100.0 * (IFNULL(percent_not_eligible_fico, 0.0, percent_not_eligible_fico) / 100.0) * (percent_not_eligible_ltv / 100.0)))
FROM #FHL_FICO_Eligible fe, #FHL_CLTV_Eligible ce
WHERE 1=1
    AND pe.issueId = fe.issueId
    AND pe.issueId = ce.issueId
    AND pe.asOf = fe.asOf
    AND pe.asOf = ce.asOf
    AND ce.percent_not_eligible_ltv IS NOT NULL
    AND pe.conventional_eligible IS NULL
;

UPDATE #FHL_PoolEligibility pe SET pe.conventional_eligible = CASE WHEN conventional_eligible > 100 THEN 100.0 WHEN conventional_eligible < 0.0 THEN 0.0 ELSE conventional_eligible END;
COMMIT;

  -- Step 4: Update Pools with no Eligibility Information based on Origination Year
DROP TABLE IF EXISTS #FHL_ORIG_CONV_ELIG;
SELECT 
    year(originationDate) as origYear,
    year(asOf) as asOfYear,
    sum(conventional_eligible * balance) / sum(balance) as wavg_conv_elig
INTO #FHL_ORIG_CONV_ELIG
FROM #FHL_PoolEligibility
WHERE conventional_eligible IS NOT NULL
GROUP BY origYear, asOfYear
;

UPDATE #FHL_PoolEligibility pe SET pe.conventional_eligible = wavg_conv_elig
FROM #FHL_ORIG_CONV_ELIG oce
WHERE 1=1
    AND year(pe.originationDate) = oce.origYear
    AND year(pe.asOf) = oce.asOfYear
    AND pe.conventional_eligible IS NULL
;

UPDATE #FHL_PoolEligibility pe SET pe.conventional_eligible = t.wavg_conv_elig
FROM (SELECT avg(conventional_eligible) as wavg_conv_elig FROM #FHL_PoolEligibility WHERE year(originationDate) <= 1972) t
WHERE pe.conventional_eligible IS NULL
;
COMMIT;

UPDATE #FHL_PoolEligibility SET conventional_eligible = 0
WHERE conventional_eligible IS NULL
;

-- Update FHA Eligibility from Loan Data
DROP TABLE IF EXISTS #FHL_Loan_FHAEligibility;
SELECT
    pe.issueId,
    pe.asOf,
    sum(sle.fha_eligible * slh.balance) / sum(slh.balance) as fha_eligible
INTO #FHL_Loan_FHAEligibility
FROM #FHL_PoolEligibility pe
JOIN fhl.PIV_Loan cl
    ON pe.issueId = cl.issueId
JOIN scale.fhl_LoanHist slh
    ON cl.loanSeqNum = slh.loanSeqNum
    AND pe.asOf = slh.asOf
JOIN scale.FHL_LoanEligibility sle
    ON slh.loanSeqNum = sle.loanSeqNum
    AND slh.asOf = sle.asOf
WHERE 1=1
    AND sle.fha_eligible IS NOT NULL
GROUP BY pe.issueId, pe.asOf
;
COMMIT;

UPDATE #FHL_PoolEligibility pe SET pe.fha_eligible = 100.0 * ce.fha_eligible
FROM #FHL_Loan_FHAEligibility ce
WHERE pe.issueId = ce.issueId
    AND pe.asOf = ce.asOf
;
COMMIT;

DROP TABLE IF EXISTS #FHL_MIN_FHAEligibility;
SELECT
    issueId,
    min(asOf) as min_asOf,
    cast(NULL as numeric(6, 3)) as earliest_fha_eligible
INTO #FHL_MIN_FHAEligibility
FROM #FHL_PoolEligibility
WHERE 1=1
    AND fha_eligible IS NOT NULL
    AND issueId in (SELECT distinct issueId from #FHL_Loan_FHAEligibility)
GROUP BY issueId
;
COMMIT;

UPDATE #FHL_MIN_FHAEligibility mfe SET mfe.earliest_fha_eligible = pe.fha_eligible
FROM #FHL_PoolEligibility pe
WHERE mfe.issueId = pe.issueId
    AND mfe.min_asOf = pe.asOf
;

UPDATE #FHL_PoolEligibility pe SET pe.fha_eligible = mfe.earliest_fha_eligible
FROM #FHL_MIN_FHAEligibility mfe
WHERE pe.issueId = mfe.issueId
    AND pe.fha_eligible IS NULL
;
COMMIT;

-- Update FHA Eligibility from Pool Data

    -- Step 1: Update FICO and OLTV Quartile
DROP TABLE IF EXISTS #FHL_FHA_FICO_Eligible;
SELECT
    qf.issueId,
    qf.asOf,
    CASE 
        WHEN 500 <= q1Min THEN 0.0
        WHEN 500 <= q2Min THEN 0.0  + ((500.0-q1Min)/(q2Min-q1Min)) * 25.0
        WHEN 500 <= q3Min THEN 25.0 + ((500.0-q2Min)/(q3Min-q2Min)) * 25.0
        WHEN 500 <= q4Min THEN 50.0 + ((500.0-q3Min)/(q4Min-q3Min)) * 25.0
        WHEN 500 <= q4Max THEN 75.0 + ((500.0-q4Min)/(q4Max-q4Min)) * 25.0
        WHEN 500 > q4Max THEN 100.0
        ELSE NULL
    END as percent_not_eligible_fico,
    100.0 - percent_not_eligible_fico as percent_eligible_fico
INTO #FHL_FHA_FICO_Eligible
FROM #FHL_Pool_WAFICOquartile qf
JOIN #FHL_PoolEligibility pe
    ON qf.issueId = pe.issueId
    AND qf.asOf = pe.asOf
WHERE 1=1
    AND pe.fha_eligible IS NULL
;

DROP TABLE IF EXISTS #FHL_FHA_CLTV_Eligible;
SELECT
    ql.issueId,
    ql.asOf,
    CASE 
        WHEN q4Max <= 97.75 THEN 100.0
        WHEN q3Max <= 97.75 THEN 75.0 + ((97.75-q3Max)/(q4Max-q3Max)) * 25.0
        WHEN q2Max <= 97.75 THEN 50.0 + ((97.75-q2Max)/(q3Max-q2Max)) * 25.0
        WHEN q1Max <= 97.75 THEN 25.0 + ((97.75-q1Max)/(q2Max-q1Max)) * 25.0
        WHEN q1Min <= 97.75 THEN 0.0  + ((97.75-q1Min)/(q1Max-q1Min)) * 25.0
        WHEN q1Min > 97.75 THEN 0.0
        ELSE NULL
    END as percent_eligible_ltv,
    100.0 - percent_eligible_ltv as percent_not_eligible_ltv
INTO #FHL_FHA_CLTV_Eligible
FROM #FHL_Pool_WACLTVquartile ql
JOIN #FHL_PoolEligibility pe
    ON ql.issueId = pe.issueId
    AND ql.asOf = pe.asOf
WHERE 1=1
    AND pe.fha_eligible IS NULL
;

  -- Step 2: Combine FICO and CLTV percent not eligible
UPDATE #FHL_PoolEligibility pe SET pe.fha_eligible = 100.0 - (IFNULL(percent_not_eligible_fico, 0.0, percent_not_eligible_fico) + percent_not_eligible_ltv - ((IFNULL(percent_not_eligible_fico, 0.0, percent_not_eligible_fico) / 100.0) * (percent_not_eligible_ltv / 100.0)))
FROM #FHL_FHA_FICO_Eligible fe, #FHL_FHA_CLTV_Eligible ce
WHERE 1=1
    AND pe.issueId = fe.issueId
    AND pe.issueId = ce.issueId
    AND pe.asOf = fe.asOf
    AND pe.asOf = ce.asOf
    AND pe.fha_eligible IS NULL
;

  -- Step 3: Update the FHA elig for the INVESTOR / 2ND part
UPDATE #FHL_PoolEligibility pe SET pe.fha_eligible = pe.fha_eligible * pd.percentOCC_OWN / 100.0
FROM scale.FHL_PoolDistribution pd
WHERE pd.issueId = pe.issueId
AND pd.asof = pe.asof
;
COMMIT;


UPDATE #FHL_PoolEligibility pe SET pe.fha_eligible = CASE WHEN fha_eligible > 100 THEN 100.0 WHEN fha_eligible < 0.0 THEN 0.0 ELSE fha_eligible END;
COMMIT;

  -- Step 4: Update Pools with no Eligibility Information based on Origination Year
DROP TABLE IF EXISTS #FHL_ORIG_FHA_ELIG;
SELECT 
    year(originationDate) as origYear,
    year(asOf) as asOfYear,
    sum(fha_eligible * balance) / sum(balance) as wavg_fha_elig
INTO #FHL_ORIG_FHA_ELIG
FROM #FHL_PoolEligibility
WHERE fha_eligible IS NOT NULL
GROUP BY origYear, asOfYear
;

UPDATE #FHL_PoolEligibility pe SET pe.fha_eligible = wavg_fha_elig
FROM #FHL_ORIG_FHA_ELIG ofe
WHERE 1=1
    AND year(pe.originationDate) = ofe.origYear
    AND year(pe.asOf) = ofe.asOfYear
    AND pe.fha_eligible IS NULL
;

UPDATE #FHL_PoolEligibility pe SET pe.fha_eligible = t.wavg_fha_elig
FROM (SELECT avg(fha_eligible) as wavg_fha_elig FROM #FHL_PoolEligibility WHERE year(originationDate) <= 1972) t
WHERE pe.fha_eligible IS NULL
;
COMMIT;

UPDATE #FHL_PoolEligibility pe SET fha_eligible = 0
WHERE pe.fha_eligible IS NULL
;

-- Update Refi Eligibility from Loan Data
DROP TABLE IF EXISTS #FHL_Loan_RefiEligibility;
SELECT
    pe.issueId,
    pe.asOf,
    sum(CASE WHEN sle.HARP_eligible = 1 OR sle.conventional_eligible = 1 OR sle.fha_eligible = 1 THEN slh.balance ELSE 0.0 END) / sum(slh.balance) as refi_eligible
INTO #FHL_Loan_RefiEligibility
FROM #FHL_PoolEligibility pe
JOIN fhl.PIV_Loan cl
    ON pe.issueId = cl.issueId
JOIN scale.fhl_LoanHist slh
    ON cl.loanSeqNum = slh.loanSeqNum
    AND pe.asOf = slh.asOf
JOIN scale.FHL_LoanEligibility sle
    ON slh.loanSeqNum = sle.loanSeqNum
    AND slh.asOf = sle.asOf
WHERE 1=1
    AND (sle.HARP_eligible IS NOT NULL OR sle.conventional_eligible IS NOT NULL OR sle.fha_eligible IS NOT NULL)
GROUP BY pe.issueId, pe.asOf
;
COMMIT;

UPDATE #FHL_PoolEligibility pe SET pe.refi_eligible = 100.0 * re.refi_eligible
FROM #FHL_Loan_RefiEligibility re
WHERE pe.issueId = re.issueId
    AND pe.asOf = re.asOf
;
COMMIT;


-- Update Refi Eligibility for remaining pools
UPDATE #FHL_PoolEligibility SET refi_eligible = CASE 
    WHEN conventional_eligible >= fha_eligible AND conventional_eligible >= HARP_eligible THEN conventional_eligible 
    WHEN fha_eligible >= conventional_eligible AND fha_eligible >= HARP_eligible THEN fha_eligible 
    ELSE HARP_eligible 
END
WHERE 1=1
    AND refi_eligible IS NULL
    AND (conventional_eligible IS NOT NULL AND fha_eligible IS NOT NULL AND HARP_eligible IS NOT NULL)
;
COMMIT;



-- Tests

-- Time Series Tests
-- History for: CLTV, HPA, HPA_2YR
--SELECT marketTicker, asOf, count(1), sum(balance), sum(balance * HARP_eligible) / sum(CASE WHEN HARP_eligible IS NULL THEN 0.0 ELSE balance END) as wavg_pct_harp_eligible FROM #FHL_PoolEligibility GROUP BY marketTicker, asOf ORDER BY asOf

--SELECT marketTicker, asOf, count(1), sum(balance), sum(balance * conventional_eligible) / sum(CASE WHEN conventional_eligible IS NULL THEN 0.0 ELSE balance END) as wavg_pct_conventional_eligible FROM #FHL_PoolEligibility GROUP BY marketTicker, asOf ORDER BY asOf

--SELECT marketTicker, asOf, count(1), sum(balance), sum(balance * fha_eligible) / sum(CASE WHEN fha_eligible IS NULL THEN 0.0 ELSE balance END) as wavg_pct_fha_eligible FROM #FHL_PoolEligibility GROUP BY marketTicker, asOf ORDER BY asOf

--SELECT marketTicker, asOf, count(1), sum(balance), sum(balance * refi_eligible) / sum(CASE WHEN refi_eligible IS NULL THEN 0.0 ELSE balance END) as wavg_pct_refi_eligible FROM #FHL_PoolEligibility GROUP BY marketTicker, asOf ORDER BY asOf


----------------------------------------------------------------------------------------------
-- Check to see if Pools have HARP_eligible IS NULL OR HARP_eligible < 0.0 OR HARP_eligible > 100.0
----------------------------------------------------------------------------------------------
        declare   @cnt int
        SELECT
            @cnt =  count(1)
        FROM #FHL_PoolEligibility WHERE HARP_eligible IS NULL OR HARP_eligible < 0.0 OR HARP_eligible > 100.0

        if (@cnt > 0)
        BEGIN
            RAISERROR 99999 'Number of FHL Pools with WRONG VALUE for HARP_eligible: %1!', @cnt
            RETURN
        END

----------------------------------------------------------------------------------------------
-- Check to see if Pools have conventional_eligible IS NULL OR conventional_eligible < 0.0 OR conventional_eligible > 100.0
----------------------------------------------------------------------------------------------
        SELECT
            @cnt =  count(1)
        FROM #FHL_PoolEligibility WHERE conventional_eligible IS NULL OR conventional_eligible < 0.0 OR conventional_eligible > 100.0

        if (@cnt > 0)
        BEGIN
            RAISERROR 99999 'Number of FHL Pools with WRONG VALUE for conventional_eligible: %1!', @cnt
            RETURN
        END
        
----------------------------------------------------------------------------------------------
-- Check to see if Pools have fha_eligible IS NULL OR fha_eligible < 0.0 OR fha_eligible > 100.0
----------------------------------------------------------------------------------------------
        SELECT
            @cnt =  count(1)
        FROM #FHL_PoolEligibility WHERE fha_eligible IS NULL OR fha_eligible < 0.0 OR fha_eligible > 100.0

        if (@cnt > 0)
        BEGIN
            RAISERROR 99999 'Number of FHL Pools with WRONG VALUE for fha_eligible: %1!', @cnt
            RETURN
        END
        
----------------------------------------------------------------------------------------------
-- Check to see if Pools have refi_eligible IS NULL OR refi_eligible < 0.0 OR refi_eligible > 100.0
----------------------------------------------------------------------------------------------
        SELECT
            @cnt =  count(1)
        FROM #FHL_PoolEligibility WHERE refi_eligible IS NULL OR refi_eligible < 0.0 OR refi_eligible > 100.0

        if (@cnt > 0)
        BEGIN
            RAISERROR 99999 'Number of FHL Pools with WRONG VALUE for refi_eligible: %1!', @cnt
            RETURN
        END
		
----------------------------------------------------------------------------------------------
-- Check to see if new pools are loaded into database (need to be commented unless load new data)
----------------------------------------------------------------------------------------------
--     declare @count_previous int
--	 SELECT @count_previous = count(distinct(issueId))
--	 FROM scale.FHL_PoolEligibility
--	 WHERE asOf >= (SELECT asOf from #tmp_asOf)

--	 declare @count_current int
--	 SELECT @count_current = count(distinct(issueId))
--	 FROM #FHL_PoolEligibility
--   WHERE asOf >= (SELECT asOf from #tmp_asOf)
	 
--	 if (@count_current - @count_previous <= 0 )
--        BEGIN
--           RAISERROR 99999 'There is no new pool loading into database. Previous pool count: %1!; Current pool count: %2!', @count_previous, @count_current
--           RETURN
 --      END 

-- End Tests



-- Load Data into Scale Eligibility Table
DELETE FROM scale.FHL_PoolEligibility
FROM scale.FHL_PoolEligibility spd, #FHL_PoolEligibility pd
WHERE 1=1
    AND spd.issueId = pd.issueId
    AND spd.asOf = pd.asOf
    AND pd.marketTicker IN (SELECT tickerName FROM #ticker)
    AND spd.asOf >= (SELECT asOf from #tmp_asOf)
	AND spd.asOf<= (select asOf_last from #tmp_asOf)
;

INSERT INTO scale.FHL_PoolEligibility (issueId, asOf, HARP_eligible, conventional_eligible, fha_eligible, refi_eligible)
SELECT
    issueId,
    asOf,
    HARP_eligible,
    conventional_eligible,
    fha_eligible,
    refi_eligible
FROM #FHL_PoolEligibility
WHERE marketTicker IN (SELECT tickerName FROM #ticker)
    AND asOf >= (SELECT asOf from #tmp_asOf)
	AND asOf <= (select asOf_last from #tmp_asOf)
;

declare @count_previous int
   
    SELECT @count_previous = count(distinct(issueId))
    FROM scale.FHL_PoolEligibility
	WHERE  asOf >= (SELECT asOf from #tmp_asOf)
	
declare @count_current int
	 
	 SELECT @count_current = count(distinct(issueId))
	 FROM #FHL_PoolEligibility
	 WHERE asOf >= (SELECT asOf from #tmp_asOf)
	 AND asOf <= (select asOf_last from #tmp_asOf)
	 
INSERT INTO scale.JobStatus (EndTime, JobName, JobStatus, #LoansBeforeProcess, #LoansUpdated, #LoansAfterProcess)
    SELECT
     getdate(),
    'FHL_Pool_Step 4_Create_Pool_Eligibility_Table',
    'SUCCESS', 
    @count_previous,
    @count_current,
	CASE WHEN(@count_previous>@count_current) THEN @count_previous ELSE @count_current END
;
COMMIT;
