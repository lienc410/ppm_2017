-- Freddie Conventional
-- Pool Level
-- Part 4 of 6
-- Script to update the eligibility metrics
-- Updates HARP_eligible, conventional_eligible and fha_eligible

-- Before execute the script, need to set the dates to run for
DROP TABLE IF EXISTS #tmp_asOf;
--SELECT CAST('#####ASOF#####' AS DATE) asOf INTO #tmp_asOf
SELECT CAST ('1994-02-01' AS DATE) asOf INTO #tmp_asOf
;

-- Before execute the script, need to set the tickers
DROP TABLE IF EXISTS #ticker;
CREATE TABLE #ticker(
    tickerName varchar(20),
    mtgRateSeries varchar(30)
)
;
INSERT #ticker SELECT 'FGLMC', 'CONVENTIONAL_30YR';   --Conventional Freddie
INSERT #ticker SELECT 'FGT6', 'JUMBO_30YR';           --Jumbo Freddie
INSERT #ticker SELECT 'FGU6', 'CONVENTIONAL_30YR';    --CQ Freddie High LTV[105-125]
INSERT #ticker SELECT 'FGU9', 'CONVENTIONAL_30YR';    --CR Freddie High LTV[125-150]
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

UPDATE #FHL_PoolEligibility pe SET pe.conventional_eligible = mhe.earliest_HARP_eligible
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


----------------------------------------------------------------------------------------------------------




select sum(CASE WHEN origFICO > 620 then p.balance else 0.0 end) / sum(p.balance) as refi_elig_pct
select * 
select sum(p.conventional_eligible * ph.balance) / sum(ph.balance) as refi_elig_pct
FROM #FHL_Loan_ConventionalEligibility p
join scale.fhl_poolHist ph on p.issueId = ph.issueId and p.asof = ph.asof
where 1=1
and p.asof >= '2009-06-01'
and ph.cltv >= 30
and ph.cltv < 40



select *
select sum(CASE WHEN p.conventional_eligible <= p.fha_eligible THEN p.fha_eligible ELSE p.conventional_eligible END * p.balance) / sum(p.balance) as refi_elig_pct
select sum(CASE WHEN origFICO > 620 then p.balance else 0.0 end) / sum(p.balance) as refi_elig_pct
FROM #FHL_PoolEligibility p
join scale.fhl_poolHist ph on p.issueId = ph.issueId and p.asof = ph.asof
where 1=1
and p.asof >= '2009-06-01'
and ph.cltv >= 30
and ph.cltv < 40
and conventional_eligible IS NOT NULL
and p.conventional_eligible < 100
and p.fha_eligible < 100




SELECT
--    pe.issueId,
--    pe.asOf,
--    sum(sle.conventional_eligible * slh.balance) / sum(slh.balance) as HARP_eligible
FROM #FHL_PoolEligibility pe
JOIN fhl.PIV_Loan cl
    ON pe.issueId = cl.issueId
JOIN scale.fhl_LoanHist slh
    ON cl.loanSeqNum = slh.loanSeqNum
    AND pe.asOf = slh.asOf
JOIN scale.FHL_LoanEligibility sle
    ON slh.loanSeqNum = sle.loanSeqNum
    AND slh.asOf = sle.asOf
JOIN scale.fhl_poolHist ph on pe.issueId = ph.issueId and pe.asof = ph.asof
WHERE 1=1
    AND sle.HARP_eligible IS NOT NULL
    AND pe.asof >= '2009-06-01'
    and slh.cltv >= 30
    and slh.cltv < 40
--GROUP BY pe.issueId, pe.asOf
;

SELECT
    cltvBucket = (case
                  when ph.cltv < 10 THEN '10'
                  when ph.cltv < 20 THEN '20'
                  when ph.cltv < 30 THEN '30'
                  when ph.cltv < 40 THEN '40'
                  when ph.cltv < 50 THEN '50'
                  when ph.cltv < 60 THEN '60'
                  when ph.cltv < 70 THEN '70'
                  when ph.cltv < 80 THEN '80'
                  when ph.cltv < 90 THEN '90'
                  when ph.cltv < 100 THEN '100'
                  when ph.cltv < 110 THEN '110'
                  when ph.cltv < 120 THEN '120'
                  when ph.cltv < 130 THEN '130'
                  when ph.cltv < 140 THEN '140'
                  else '150' end),
    convert(numeric(6,2), sum(ph.cltv * pe.balance) / sum(pe.balance)) as cltv,
    sum(CASE WHEN sle.conventional_eligible <= sle.fha_eligible THEN sle.fha_eligible ELSE sle.conventional_eligible END * pe.balance) / sum(pe.balance) as refi_elig_pct
FROM #FHL_PoolEligibility pe
JOIN fhl.PIV_Loan cl
    ON pe.issueId = cl.issueId
JOIN scale.fhl_LoanHist slh
    ON cl.loanSeqNum = slh.loanSeqNum
    AND pe.asOf = slh.asOf
JOIN scale.FHL_LoanEligibility sle
    ON slh.loanSeqNum = sle.loanSeqNum
    AND slh.asOf = sle.asOf
JOIN scale.fhl_poolHist ph on pe.issueId = ph.issueId and pe.asof = ph.asof
WHERE 1=1
    AND sle.HARP_eligible IS NOT NULL
    AND pe.asof >= '2009-06-01'
GROUP BY cltvBucket

select * from scale.fhl_poolHist pe