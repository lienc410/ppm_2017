-- Ginnie
-- Pool Level
-- Part 6 of 6
-- Script to update the burnout metrics
-- Updates Burnout

-- Before execute the script, need to set the dates to run for
DROP TABLE IF EXISTS #tmp_asOf;
--SELECT CAST('#####ASOF#####' AS DATE) asOf INTO #tmp_asOf
SELECT CAST ('1994-02-01' AS DATE) asOf INTO #tmp_asOf
;

-- Before execute the script, need to set the version to run for
DROP TABLE IF EXISTS #tmp_version;
SELECT CAST ('2.42' AS varchar(5)) version INTO #tmp_version
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

-- Create history of asOf dates
DROP TABLE IF EXISTS #unique_dates;
SELECT convert(date,dateadd(month, -num, mn.asOf)) as asOf
INTO #unique_dates
FROM report.nums,
(SELECT convert(date, dateadd(day, -datepart(day, getdate()) + 1, getdate())) asOf) mn
;
COMMIT;

-- Create Pool Historical Data
DROP TABLE IF EXISTS #GNM_PoolBurnout;
SELECT
    ph.marketTicker,
    ph.issueId,
    spi.loanType,
    ph.asOf,
    cast(0 as tinyint) as has_loan_data,
    spi.refi_incentive_eligible,
    cast(NULL as NUMERIC(10,4)) as burnout
INTO #GNM_PoolBurnout
FROM scale.GNM_PoolHist ph
JOIN #ticker tk
    ON ph.marketTicker = tk.tickerName
JOIN gnm.sec p
    ON ph.issueId = p.issueId
JOIN gnm.Prefix x
    ON p.prefix = x.prefix
    AND p.product = x.product
JOIN scale.GNM_PoolIncentive_V2_00 spi
    ON ph.issueId = spi.issueId
    AND ph.asOf = spi.asOf
WHERE 1=1
    AND ph.asOf >= (select asOf from #tmp_asOf)
    AND spi.version = (select version from #tmp_version)
;
COMMIT;

CREATE INDEX issueId_idx ON #GNM_PoolBurnout(issueId);
CREATE INDEX asOf_idx ON #GNM_PoolBurnout(asOf);
COMMIT;

---------------------------------------------------------
-- Update Incenitve for Pools w/ no burnout from loans
---------------------------------------------------------
DROP TABLE IF EXISTS #GNM_PoolIncentive;
SELECT 
    pb.asof,
    pb.issueId,
    pb.loanType,
    CASE WHEN refi_incentive_eligible > 200 THEN 200 ELSE refi_incentive_eligible END AS incentive
INTO #GNM_PoolIncentive
FROM #GNM_PoolBurnout pb
WHERE 1=1
    AND pb.burnout IS NULL
;
COMMIT;

CREATE HG INDEX issueId_idx ON #GNM_PoolIncentive(issueId);
CREATE LF INDEX asOf_idx ON #GNM_PoolIncentive(asOf);
COMMIT;

-----------------------------------------------------------
---- Step 3: Update Missing Burnout Data (Latest Date)
-----------------------------------------------------------
--DROP TABLE IF EXISTS #GNM_LoanLatestBurnout;
--SELECT
--    pb.issueId,
--    o.max_asOf,
--    pb.burnout as max_burnout
--INTO #GNM_LoanLatestBurnout
--FROM #GNM_PoolBurnout pb
--JOIN (
--        SELECT
--            issueId,
--            max(asOf) as max_asOf
--        FROM #GNM_PoolBurnout
--        WHERE has_loan_data = 1
--            AND burnout IS NOT NULL
--        GROUP BY issueId
--    ) o
--    ON pb.issueId = o.issueId
--    AND pb.asOf = o.max_asOf
--;

--DROP TABLE IF EXISTS #GNM_PoolLastDate;
--SELECT
--    issueId,
--    max(asOf) as max_asOf
--INTO #GNM_PoolLastDate
--FROM #GNM_PoolBurnout 
--WHERE has_loan_data = 1
--GROUP BY issueId
--;

--UPDATE #GNM_PoolBurnout pb SET burnout = llb.max_burnout + (CASE WHEN incentive <= 0.0 THEN 0.0 ELSE incentive END)
--FROM #GNM_LoanLatestBurnout llb, #GNM_PoolLastDate pld, #GNM_PoolIncentive_LoanSize pils
--WHERE 1=1
--    AND llb.issueId = pld.issueId
--    AND pb.issueId = llb.issueId
--    AND pb.issueId = pils.issueId
--    AND pb.asOf = pld.max_asOf
--    AND llb.max_asOf != pld.max_asOf
--    AND pb.asOf = pils.asOf
--    AND pb.has_loan_data = 1
--    AND pb.burnout IS NULL
--;
--COMMIT;

---------------------------------------------------------------
-- Step 4: Update Missing Burnout Data (Earliest Dates)
---------------------------------------------------------------

-- Calculate Burnout from Relative Incentive
DROP TABLE IF EXISTS #GNM_Burnout;
SELECT  
    t0.issueId,
    t0.loanType,
    t0.asOf as asOf,
    sum(CASE 
                    WHEN t1.incentive <= 0.0 THEN 0.0
                    ELSE t1.incentive
                END) as burnout
INTO #GNM_Burnout
FROM #GNM_PoolIncentive t0
JOIN #GNM_PoolIncentive t1
    ON t0.issueId = t1.issueId
    AND t0.loanType = t1.loanType
    AND t0.asOf > t1.asOf
WHERE t0.asOf >= (select asOf from #tmp_asOf)
GROUP BY t0.issueId, t0.loanType, t0.asOf
;
COMMIT;

-- Update Pool Burnout with Earliest Loan Burnout
UPDATE #GNM_PoolBurnout pb SET
    pb.burnout = elb.burnout
FROM #GNM_Burnout elb
WHERE pb.issueId = elb.issueId
    AND pb.asOf = elb.asOf
    AND pb.loanType = elb.loanType
    AND pb.burnout IS NULL
;
COMMIT;

-- Update GNM_PoolBurnout Table for empty cells
UPDATE #GNM_PoolBurnout pb SET pb.burnout = 0.0
WHERE pb.burnout IS NULL
;
COMMIT;



-- Tests

-- Bad Data Tests
-- No nulls for: burnout
SELECT count(1) FROM #FHL_PoolBurnout WHERE burnout IS NULL OR burnout < 0.0 OR burnout > 25000;

-- Time Series Tests
-- History for: burnout
SELECT marketTicker, originationDate, count(1), sum(balance), sum(balance * burnout) / sum(CASE WHEN burnout IS NULL THEN 0.0 ELSE balance END) as wavg_burnout FROM #FHL_PoolBurnout GROUP BY marketTicker, originationDate ORDER BY originationDate
SELECT marketTicker, asOf, count(1), sum(balance), sum(balance * burnout) / sum(CASE WHEN burnout IS NULL THEN 0.0 ELSE balance END) as wavg_burnout FROM #FHL_PoolBurnout GROUP BY marketTicker, asOf ORDER BY asOf



-- Load Data into Scale Burnout Table
DELETE FROM scale.GNM_PoolBurnout_v2_00
FROM scale.GNM_PoolBurnout_v2_00 spb, #GNM_PoolBurnout pb
WHERE 1=1
    AND spb.issueId = pb.issueId
    AND spb.asOf = pb.asOf
    AND pb.marketTicker IN (SELECT tickerName FROM #ticker)
    AND version = (SELECT version from #tmp_version)
;

DECLARE @version varchar(5)
SELECT @version = (select * from #tmp_version)

INSERT INTO scale.GNM_PoolBurnout_v2_00 (issueId, loanType, asOf, version, burnout)
SELECT
    issueId,
    loanType,
    asOf,
    @version,
    burnout
FROM #GNM_PoolBurnout
WHERE marketTicker IN (SELECT tickerName FROM #ticker)
; 

commit;
