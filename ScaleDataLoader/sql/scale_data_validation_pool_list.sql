-- Testing Pool List
-- Freddie
-- Pool Level
-- Script to create a testing pool list based on Spec Pool



-- Spec pool with current balance
DROP TABLE IF EXISTS #spec_pool_balance;
SELECT 
    pl.PoolListName, 
    sum(sf.currentBalance) as TotalBalance,
    count(1) as PoolCount
INTO #spec_pool_balance
FROM CollateralAnalysis_PoolList pl
JOIN fhl.secFactor sf ON pl.issueId = sf.issueId
WHERE pl.PoolListName LIKE ('FHL30.%') -- Spec pool cohort only 
    AND sf.asof = '2017-02-01'
Group by pl.PoolListName
;
COMMIT;


-- Cohort with current balance > 1bb
DROP TABLE IF EXISTS #spec_pool_balance_sized;
SELECT *
INTO #spec_pool_balance_sized 
FROM #spec_pool_balance
WHERE TotalBalance >= 1000000000
;
COMMIT;

-- Complete pool list backing the Cohorts
DROP TABLE IF EXISTS #pool_list_sized;
SELECT 
    pls.PoolListName, 
    sf.issueId,
    sf.currentBalance
INTO #pool_list_sized
FROM #spec_pool_balance_sized pls
JOIN CollateralAnalysis_PoolList pl ON pl.PoolListName = pls.PoolListName
JOIN fhl.secFactor sf ON pl.issueId = sf.issueId
WHERE sf.asof = '2017-02-01'
ORDER BY pls.PoolListName, sf.currentBalance desc
;

-- Extract top 5 from each group
---- solution 1: too slow
--SELECT pls.* 
--FROM #pool_list_sized pls 
--WHERE 5 > (SELECT count(*) FROM #pool_list_sized WHERE PoolListName = pls.PoolListName AND currentBalance > pls.currentBalance ) 
--ORDER BY pls.PoolListName, pls.currentBalance 

-- solution 2:
-- Select the pools from each group one by one, starting from the one with largest balance
DROP TABLE IF EXISTS #pool_list_sized_1st_balance;
SELECT PoolListName, max(currentBalance) as currentBalance
INTO #pool_list_sized_1st_balance 
FROM #pool_list_sized pls 
GROUP BY PoolListName
;
COMMIT;

DROP TABLE IF EXISTS #pool_list_sized_1st;
SELECT pls.PoolListName,
    rank = 1,
    pls.issueId,
    pls.currentBalance
INTO #pool_list_sized_1st 
FROM #pool_list_sized pls 
JOIN #pool_list_sized_1st_balance plb ON pls.PoolListName = plb.PoolListName AND pls.currentBalance = plb.currentBalance
;
COMMIT;

-- 2nd largest
---- remove 1st largest issueId from the pool list
DELETE 
FROM #pool_list_sized pls
FROM #pool_list_sized pls, #pool_list_sized_1st pl1
WHERE pl1.PoolListName = pls.PoolListName AND pl1.issueId = pls.issueId

---- update the 2nd larget 
DROP TABLE IF EXISTS #pool_list_sized_2nd_balance;
SELECT PoolListName, max(currentBalance) as currentBalance
INTO #pool_list_sized_2nd_balance 
FROM #pool_list_sized pls 
GROUP BY PoolListName
;
COMMIT;

DROP TABLE IF EXISTS #pool_list_sized_2nd;
SELECT pls.PoolListName,
    rank = 2,
    pls.issueId,
    pls.currentBalance
INTO #pool_list_sized_2nd 
FROM #pool_list_sized pls 
JOIN #pool_list_sized_2nd_balance plb ON pls.PoolListName = plb.PoolListName AND pls.currentBalance = plb.currentBalance
;
COMMIT;


-- 3rd largest
---- remove 2nd largest issueId from the pool list
DELETE 
FROM #pool_list_sized pls
FROM #pool_list_sized pls, #pool_list_sized_2nd pl1
WHERE pl1.PoolListName = pls.PoolListName AND pl1.issueId = pls.issueId

---- update the 3rd larget 
DROP TABLE IF EXISTS #pool_list_sized_3rd_balance;
SELECT PoolListName, max(currentBalance) as currentBalance
INTO #pool_list_sized_3rd_balance 
FROM #pool_list_sized pls 
GROUP BY PoolListName
;
COMMIT;

DROP TABLE IF EXISTS #pool_list_sized_3rd;
SELECT pls.PoolListName,
    rank = 3,
    pls.issueId,
    pls.currentBalance
INTO #pool_list_sized_3rd 
FROM #pool_list_sized pls 
JOIN #pool_list_sized_3rd_balance plb ON pls.PoolListName = plb.PoolListName AND pls.currentBalance = plb.currentBalance
;
COMMIT;


-- 4th largest
---- remove 3rd largest issueId from the pool list
DELETE 
FROM #pool_list_sized pls
FROM #pool_list_sized pls, #pool_list_sized_3rd pl1
WHERE pl1.PoolListName = pls.PoolListName AND pl1.issueId = pls.issueId

---- update the 4th larget 
DROP TABLE IF EXISTS #pool_list_sized_4th_balance;
SELECT PoolListName, max(currentBalance) as currentBalance
INTO #pool_list_sized_4th_balance 
FROM #pool_list_sized pls 
GROUP BY PoolListName
;
COMMIT;

DROP TABLE IF EXISTS #pool_list_sized_4th;
SELECT pls.PoolListName,
    rank = 4,
    pls.issueId,
    pls.currentBalance
INTO #pool_list_sized_4th 
FROM #pool_list_sized pls 
JOIN #pool_list_sized_4th_balance plb ON pls.PoolListName = plb.PoolListName AND pls.currentBalance = plb.currentBalance
;
COMMIT;


-- 5th largest
---- remove 4th largest issueId from the pool list
DELETE 
FROM #pool_list_sized pls
FROM #pool_list_sized pls, #pool_list_sized_4th pl1
WHERE pl1.PoolListName = pls.PoolListName AND pl1.issueId = pls.issueId

---- update the 5th larget 
DROP TABLE IF EXISTS #pool_list_sized_5th_balance;
SELECT PoolListName, max(currentBalance) as currentBalance
INTO #pool_list_sized_5th_balance 
FROM #pool_list_sized pls 
GROUP BY PoolListName
;
COMMIT;

DROP TABLE IF EXISTS #pool_list_sized_5th;
SELECT pls.PoolListName,
    rank = 5,
    pls.issueId,
    pls.currentBalance
INTO #pool_list_sized_5th 
FROM #pool_list_sized pls 
JOIN #pool_list_sized_5th_balance plb ON pls.PoolListName = plb.PoolListName AND pls.currentBalance = plb.currentBalance
;
COMMIT;

-- Combine 1st to 5th Lagest into one table
DROP TABLE IF EXISTS #pool_list_top5;
SELECT * INTO #pool_list_top5
FROM #pool_list_sized_1st
;
COMMIT;

INSERT INTO #pool_list_top5 SELECT * FROM #pool_list_sized_2nd;
INSERT INTO #pool_list_top5 SELECT * FROM #pool_list_sized_3rd;
INSERT INTO #pool_list_top5 SELECT * FROM #pool_list_sized_4th;
INSERT INTO #pool_list_top5 SELECT * FROM #pool_list_sized_5th;
COMMIT;


-- Test
select * from #pool_list_top5 order by issueId poolListName, rank
select distinct(issueID) from #pool_list_top5
select count(distinct(issueID)) from #pool_list_top5