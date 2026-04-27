-- Symphony Tracking Data
-- Freddie Conventional
-- Pool Level
-- Script to pull data from Scale tables for Symphony Tracking


-- Before execute the script, create Sample of Pools (Optional)
--SELECT issueId, NEWID() as IDX, marketTicker
--INTO #PoolIssueId
--FROM (
--    SELECT distinct issueId, marketTicker FROM fhl.sec p WHERE p.collateralType = 'LOAN'
--) o
--WHERE o.marketTicker IN (SELECT tickerName FROM #ticker)
--;
--COMMIT;

--DROP TABLE IF EXISTS #PoolIDSample;
--SELECT top 10000 issueId -- subset of total
---- SELECT issueId -- all pools
--INTO #PoolIDSample FROM #PoolIssueId 
--ORDER BY IDX;
--COMMIT;

--CREATE INDEX issueId_idx ON #PoolIDSample(issueId);
--COMMIT;


-----------------------------------------------------------
-- Store all pools with pertinent data
-----------------------------------------------------------
DROP TABLE IF EXISTS #Symphony_pools;
SELECT
    year(s.issueDate) as vintage,
    sph.issueId,
    sph.asOf,
    monthBucket = (case 
        		    when month(sph.asOf) = 1  then 'Jan'
        		    when month(sph.asOf) = 2  then 'Feb'
        		    when month(sph.asOf) = 3  then 'Mar'
        		    when month(sph.asOf) = 4  then 'Apr'
        		    when month(sph.asOf) = 5  then 'May'
        		    when month(sph.asOf) = 6  then 'Jun'
        		    when month(sph.asOf) = 7  then 'Jul'
        		    when month(sph.asOf) = 8  then 'Aug'
         		    when month(sph.asOf) = 9  then 'Sep'
        		    when month(sph.asOf) = 10 then 'Oct'
                    when month(sph.asOf) = 11 then 'Nov'
                    when month(sph.asOf) = 12 then 'Dec'
        		    end),
    sf.schamBalance,
    spd.percentOCC_OWN,
    spd.percentOCC_2ND,
    spd.percentOCC_INV,
    CASE WHEN spd.percentCURRENT IS NULL THEN spd.Est_Pct_CURRENT ELSE spd.percentCURRENT END as percentCURRENT,
    CASE WHEN spd.percentDELQ30plus IS NULL THEN spd.Est_Pct_DELQ30plus ELSE spd.percentDELQ30plus END as percentDELQ30plus,
    spi.refi_incentive,
    spb.burnout,
    sf.wala,
    sph.currLoanSize,
    sph.cltv,
    sph.origFICO,
    sph.origNoteRate,
    spd.percentPURP_REFI,
    spe.conventional_eligible,
    spd.percentHARPed,
    spd.percentCHANNEL_BROKER,
    spd.percentCHANNEL_CORRES,
    spe.HARP_eligible
INTO #Symphony_pools
FROM fhl.sec s
JOIN scale.FHL_PoolHist sph
    ON s.issueId = sph.issueId
JOIN #ticker tk
    ON sph.marketTicker = tk.tickerName
JOIN fhl.secFactor sf
    ON sph.issueId = sf.issueId
    AND sph.asOf = sf.asOf
JOIN scale.FHL_PoolDistribution spd
    ON sph.issueId = spd.issueId
    AND sph.asOf = spd.asOf
JOIN scale.FHL_PoolEligibility spe
    ON sph.issueId = spe.issueId
    AND sph.asOf = spe.asOf
JOIN scale.FHL_PoolIncentive spi
    ON sph.issueId = spi.issueId
    AND sph.asOf = spi.asOf
JOIN scale.FHL_PoolBurnout spb
    ON sph.issueId = spb.issueId
    AND sph.asOf = spb.asOf
--JOIN #PoolIDSample sam
--    ON sph.issueId = sam.issueId
WHERE 1=1
    AND spi.version = '2.00'
    AND spb.version = '2.00'
    @ASOF_WHERE@
    AND sf.schamBalance > 0.01
;
COMMIT;

