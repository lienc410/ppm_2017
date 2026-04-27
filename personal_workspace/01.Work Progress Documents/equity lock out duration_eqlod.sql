-- Fixing a loan, eqlod is incremented by +1 whenever CLTV > 100 and decremented by 1 if CLTV <= 100 subject to a floor of zero.
DROP TABLE IF EXISTS #fhl_pooleqlod_step1;
SELECT 
issueId,
asOf,
cltv,
CASE WHEN cltv >= 100.0 THEN 1.0 ELSE -1.0 END AS eqlod_increment
INTO #fhl_pooleqlod_step1
FROM scale.fhl_poolhist t0
WHERE issueId = 1506042
ORDER BY asOf
;
COMMIT;

-- first round of accumulating
DROP TABLE IF EXISTS #fhl_pooleqlod_step2;
SELECT 
t0.issueId,
t0.asOf,
t0.cltv,
t0.eqlod_increment,
sum(t1.eqlod_increment) AS eqlod
INTO #fhl_pooleqlod_step2
FROM #fhl_pooleqlod_step1 t0
JOIN #fhl_pooleqlod_step1 t1
ON t0.issueId = t1.issueId AND t0.asOf >= t1.asOf
WHERE t0.issueId = 1506042
GROUP BY t0.issueId, t0.asOf, t0.cltv, t0.eqlod_increment
ORDER BY t0.asOf
;
COMMIT;

-- stop decreasing when eqlod reach 0.0
UPDATE #fhl_pooleqlod_step2 SET eqlod_increment = 0.0
WHERE eqlod < 0.0 and cltv < 100.0
;

-- second round of accumulating
--DROP TABLE IF EXISTS #fhl_pooleqlod_step3;
SELECT 
t0.issueId,
t0.asOf,
t0.cltv,
t0.eqlod_increment,
sum(t1.eqlod_increment) AS eqlod
--INTO #fhl_pooleqlod_step3
FROM #fhl_pooleqlod_step2 t0
JOIN #fhl_pooleqlod_step2 t1
ON t0.issueId = t1.issueId AND t0.asOf >= t1.asOf
WHERE t0.issueId = 1506042
GROUP BY t0.issueId, t0.asOf, t0.cltv, t0.eqlod_increment
ORDER BY t0.asOf
;
COMMIT;
