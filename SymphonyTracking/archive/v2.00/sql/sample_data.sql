-- Sample Pools
DROP TABLE IF EXISTS #sample_issueIds;
SELECT rp.issueId, NEWID() as IDX
INTO #sample_issueIds
FROM (
    SELECT distinct issueId FROM #refinance_pools
) rp
;
COMMIT;
DROP TABLE IF EXISTS #refinance_pools_sample;
SELECT top 1000 issueId INTO #refinance_pools_sample FROM #sample_issueIds ORDER BY IDX;
COMMIT;
