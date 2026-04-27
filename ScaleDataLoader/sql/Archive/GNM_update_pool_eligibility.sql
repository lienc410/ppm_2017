-- Ginnie
-- Pool Level
-- Part 4 of 6
-- Script to update the eligibility metrics
-- Updates conventional_eligible

-- Before execute the script, need to set the dates to run for
DROP TABLE IF EXISTS #tmp_asOf;
SELECT CAST('#####ASOF#####' AS DATE) asOf INTO #tmp_asOf
--SELECT CAST ('2017-06-01' AS DATE) asOf INTO #tmp_asOf
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

CREATE INDEX loan_tickerName_idx ON #ticker(tickerName);
COMMIT;


-- Create Pool Historical Data
DROP TABLE IF EXISTS #GNM_PoolEligibility;
SELECT
    ph.marketTicker,
    ph.issueId,
    ph.asOf,
    ph.originationDate,
    ph.balance,
    cast(NULL as numeric(6, 3)) as conventional_eligible
INTO #GNM_PoolEligibility
FROM scale.GNM_PoolHist ph
JOIN #ticker tk
    ON ph.marketTicker = tk.tickerName
WHERE 1=1
    AND ph.asOf >= (select asOf from #tmp_asOf)
;
COMMIT;

CREATE INDEX issueId_idx ON #GNM_PoolEligibility(issueId);
CREATE INDEX asOf_idx ON #GNM_PoolEligibility(asOf);
COMMIT;


-- Create Conventional Eligibility from Loan Data
DROP TABLE IF EXISTS #GNM_Loan_ConventionalEligibility;
SELECT
    pe.issueId,
    pe.asOf,
    sum(sle.conventional_eligible * slh.schamBalance) / sum(slh.schamBalance) as conventional_eligible
INTO #GNM_Loan_ConventionalEligibility
FROM #GNM_PoolEligibility pe
JOIN gnm.PIV_Loan cl
    ON pe.issueId = cl.issueId
JOIN scale.GNM_LoanHist slh
    ON cl.loanSeqNum = slh.loanSeqNum
    AND pe.asOf = slh.asOf
JOIN scale.GNM_LoanEligibility sle
    ON slh.loanSeqNum = sle.loanSeqNum
    AND slh.asOf = sle.asOf
WHERE 1=1
    AND sle.conventional_eligible IS NOT NULL
GROUP BY pe.issueId, pe.asOf
HAVING sum(slh.schamBalance) > 0.01
;
COMMIT;

UPDATE #GNM_PoolEligibility pe SET pe.conventional_eligible = 100.0 * ce.conventional_eligible
FROM #GNM_Loan_ConventionalEligibility ce
WHERE pe.issueId = ce.issueId
    AND pe.asOf = ce.asOf
;
COMMIT;

DROP TABLE IF EXISTS #GNM_MIN_ConventionalEligibility;
SELECT
    issueId,
    min(asOf) as min_asOf,
    cast(NULL as numeric(6, 3)) as earliest_conventional_eligible
INTO #GNM_MIN_ConventionalEligibility
FROM #GNM_PoolEligibility
WHERE 1=1
    AND conventional_eligible IS NOT NULL
    AND issueId in (SELECT distinct issueId from #GNM_Loan_ConventionalEligibility)
GROUP BY issueId
;
COMMIT;

UPDATE #GNM_MIN_ConventionalEligibility mce SET mce.earliest_conventional_eligible = pe.conventional_eligible
FROM #GNM_PoolEligibility pe
WHERE mce.issueId = pe.issueId
    AND mce.min_asOf = pe.asOf
;

UPDATE #GNM_PoolEligibility pe SET pe.conventional_eligible = mce.earliest_conventional_eligible
FROM #GNM_MIN_ConventionalEligibility mce
WHERE pe.issueId = mce.issueId
    AND pe.conventional_eligible IS NULL
    AND pe.asOf <= mce.min_asOf
;
COMMIT;

--UPDATE #GNM_PoolEligibility SET conventional_eligible = NULL WHERE asOf < '2006-09-01';
--COMMIT;


-- Update Conventional Eligibility from Pool Data

  -- Step 1: Update OLTV Quartile to CLTV Quartile
DROP TABLE IF EXISTS #GNM_Pool_WACLTVquartile;
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
INTO #GNM_Pool_WACLTVquartile
FROM #GNM_PoolEligibility pe
JOIN scale.GNM_PoolHist sph
    ON pe.issueId = sph.issueId
    AND pe.asOf = sph.asOf
LEFT JOIN gnm.WAOLTVquartile qt
    ON sph.issueId = qt.issueId
    AND sph.asOf = qt.asOf
    AND qt.quartileType = 'OLTV'
;

DROP TABLE IF EXISTS #GNM_MIN_WACLTVquartile;
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
INTO #GNM_MIN_WACLTVquartile
FROM #GNM_Pool_WACLTVquartile
WHERE q1Min IS NOT NULL
GROUP BY issueId
;

UPDATE #GNM_MIN_WACLTVquartile mqt SET
    mqt.earliest_q1Min = qt.q1Min,
    mqt.earliest_q1Max = qt.q1Max,
    mqt.earliest_q2Min = qt.q2Min,
    mqt.earliest_q2Max = qt.q2Max,
    mqt.earliest_q3Min = qt.q3Min,
    mqt.earliest_q3Max = qt.q3Max,
    mqt.earliest_q4Min = qt.q4Min,
    mqt.earliest_q4Max = qt.q4Max
FROM #GNM_Pool_WACLTVquartile qt
WHERE mqt.issueId = qt.issueId
    AND mqt.min_asOf = qt.asOf
;

UPDATE #GNM_Pool_WACLTVquartile qt SET 
    qt.min_asOf = mqt.min_asOf,
    qt.q1Min = mqt.earliest_q1Min,
    qt.q1Max = mqt.earliest_q1Max,
    qt.q2Min = mqt.earliest_q2Min,
    qt.q2Max = mqt.earliest_q2Max,
    qt.q3Min = mqt.earliest_q3Min,
    qt.q3Max = mqt.earliest_q3Max,
    qt.q4Min = mqt.earliest_q4Min,
    qt.q4Max = mqt.earliest_q4Max
FROM #GNM_MIN_WACLTVquartile mqt
WHERE qt.issueId = mqt.issueId
    AND qt.q1Min IS NULL
;

UPDATE #GNM_Pool_WACLTVquartile SET
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

  -- Step 1b: Update FICO Quartile farther back in time
DROP TABLE IF EXISTS #GNM_Pool_WAFICOquartile;
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
INTO #GNM_Pool_WAFICOquartile
FROM #GNM_PoolEligibility pe
JOIN scale.GNM_PoolHist sph
    ON pe.issueId = sph.issueId
    AND pe.asOf = sph.asOf
LEFT JOIN gnm.WAOCSquartile qt
    ON sph.issueId = qt.issueId
    AND sph.asOf = qt.asOf
    AND qt.quartileType = 'OCS'
;

DROP TABLE IF EXISTS #GNM_MIN_WAFICOquartile;
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
INTO #GNM_MIN_WAFICOquartile
FROM #GNM_Pool_WAFICOquartile
WHERE q1Min IS NOT NULL
GROUP BY issueId
;

UPDATE #GNM_MIN_WAFICOquartile mqt SET
    mqt.earliest_waocs = qt.waocs,
    mqt.earliest_q1Min = qt.q1Min,
    mqt.earliest_q1Max = qt.q1Max,
    mqt.earliest_q2Min = qt.q2Min,
    mqt.earliest_q2Max = qt.q2Max,
    mqt.earliest_q3Min = qt.q3Min,
    mqt.earliest_q3Max = qt.q3Max,
    mqt.earliest_q4Min = qt.q4Min,
    mqt.earliest_q4Max = qt.q4Max
FROM #GNM_Pool_WAFICOquartile qt
WHERE mqt.issueId = qt.issueId
    AND mqt.min_asOf = qt.asOf
;

UPDATE #GNM_Pool_WAFICOquartile qt SET
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
FROM #GNM_MIN_WAFICOquartile mqt
WHERE qt.issueId = mqt.issueId
    AND qt.q1Min IS NULL
;

UPDATE #GNM_Pool_WAFICOquartile SET
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

  -- Step 2: Estimate Percent of Pool > 97 CLTV or < 620 FICO
DROP TABLE IF EXISTS #GNM_FICO_Eligible;
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
INTO #GNM_FICO_Eligible
FROM #GNM_Pool_WAFICOquartile qf
JOIN #GNM_PoolEligibility pe
    ON qf.issueId = pe.issueId
    AND qf.asOf = pe.asOf
WHERE 1=1
    AND pe.conventional_eligible IS NULL
;

DROP TABLE IF EXISTS #GNM_CLTV_Eligible;
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
INTO #GNM_CLTV_Eligible
FROM #GNM_Pool_WACLTVquartile ql
JOIN #GNM_PoolEligibility pe
    ON ql.issueId = pe.issueId
    AND ql.asOf = pe.asOf
WHERE 1=1
    AND pe.conventional_eligible IS NULL
;

  -- Step 3: Combine FICO and CLTV percent not eligible
UPDATE #GNM_PoolEligibility pe SET pe.conventional_eligible = 100.0 - (IFNULL(percent_not_eligible_fico, 0.0, percent_not_eligible_fico) + percent_not_eligible_ltv - (100.0 * (IFNULL(percent_not_eligible_fico, 0.0, percent_not_eligible_fico) / 100.0) * (percent_not_eligible_ltv / 100.0)))
FROM #GNM_FICO_Eligible fe, #GNM_CLTV_Eligible ce
WHERE 1=1
    AND pe.issueId = fe.issueId
    AND pe.issueId = ce.issueId
    AND pe.asOf = fe.asOf
    AND pe.asOf = ce.asOf
    AND ce.percent_not_eligible_ltv IS NOT NULL
    AND pe.conventional_eligible IS NULL
;

UPDATE #GNM_PoolEligibility pe SET pe.conventional_eligible = CASE WHEN conventional_eligible > 100 THEN 100.0 WHEN conventional_eligible < 0.0 THEN 0.0 ELSE conventional_eligible END;
COMMIT;

  -- Step 4: Update Pools with no Eligibility Information based on Origination Year
DROP TABLE IF EXISTS #GNM_ORIG_CONV_ELIG;
SELECT 
    year(originationDate) as origYear,
    year(asOf) as asOfYear,
    sum(conventional_eligible * balance) / sum(balance) as wavg_conv_elig
INTO #GNM_ORIG_CONV_ELIG
FROM #GNM_PoolEligibility
WHERE conventional_eligible IS NOT NULL
GROUP BY origYear, asOfYear
;

UPDATE #GNM_PoolEligibility pe SET pe.conventional_eligible = wavg_conv_elig
FROM #GNM_ORIG_CONV_ELIG oce
WHERE 1=1
    AND year(pe.originationDate) = oce.origYear
    AND year(pe.asOf) = oce.asOfYear
    AND pe.conventional_eligible IS NULL
;

UPDATE #GNM_PoolEligibility pe SET pe.conventional_eligible = t.wavg_conv_elig
FROM (SELECT avg(conventional_eligible) as wavg_conv_elig FROM #GNM_PoolEligibility WHERE year(originationDate) <= 1972) t
WHERE pe.conventional_eligible IS NULL
;
COMMIT;



-- Tests

-- Time Series Tests
-- History for: CLTV, HPA, HPA_2YR
--SELECT marketTicker, asOf, count(1), sum(balance), sum(balance * conventional_eligible) / sum(CASE WHEN conventional_eligible IS NULL THEN 0.0 ELSE schamBalance END) as wavg_pct_conventional_eligible FROM #GNM_PoolEligibility GROUP BY marketTicker, asOf ORDER BY asOf
--SELECT marketTicker, originationDate, count(1), sum(balance), sum(balance * conventional_eligible) / sum(CASE WHEN conventional_eligible IS NULL THEN 0.0 ELSE schamBalance END) as wavg_pct_conventional_eligible FROM #GNM_PoolEligibility GROUP BY marketTicker, originationDate ORDER BY originationDate

----------------------------------------------------------------------------------------------
-- Check to see if Pools have conventional_eligible IS NULL OR conventional_eligible < 0.0 OR conventional_eligible > 100.0
----------------------------------------------------------------------------------------------
        declare   @cnt int
        SELECT
            @cnt =  count(1)
        FROM #GNM_PoolEligibility WHERE conventional_eligible IS NULL OR conventional_eligible < 0.0 OR conventional_eligible > 100.0

        if (@cnt > 0)
        BEGIN
            RAISERROR 99999 'GNM Pools with INVALID VALUE for conventional_eligible PoolCount : %1!', @cnt
            RETURN
        END

-- End Tests



-- Load Data into Scale Eligibility Table
DELETE FROM scale.GNM_PoolEligibility
FROM scale.GNM_PoolEligibility spd, #GNM_PoolEligibility pd
WHERE 1=1
    AND spd.issueId = pd.issueId
    AND spd.asOf = pd.asOf
    AND pd.marketTicker IN (SELECT tickerName FROM #ticker)
    AND spd.asOf >= (SELECT asOf from #tmp_asOf)
;

INSERT INTO scale.GNM_PoolEligibility (issueId, asOf, conventional_eligible)
SELECT
    issueId,
    asOf,
    conventional_eligible
FROM #GNM_PoolEligibility
WHERE marketTicker IN (SELECT tickerName FROM #ticker)
    AND asOf >= (SELECT asOf from #tmp_asOf)
;

