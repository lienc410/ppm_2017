-- Symphony Tracking Data
-- Freddie Conventional
-- Pool Level
-- Script to pull data from Scale tables for Symphony Tracking


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
--    spd.percentOCC_OWN,
--    spd.percentOCC_2ND,
--    spd.percentOCC_INV,
    spd.Est_Pct_CURRENT as percentCURRENT,
    spd.Est_Pct_DELQ30plus as percentDELQ30plus,
    spi.refi_incentive,
    spb.burnout,
    sf.wala,
    sph.currLoanSize,
    sph.cltv,
    sph.origFICO,
    sph.origNoteRate,
    spd.percentPURP_REFI,
    spe.conventional_eligible,
--    CASE WHEN spd.percentHARPed IS NULL THEN spd.Est_Pct_HARPed ELSE spd.percentHARPed END as percentHARPed,
    spd.percentCHANNEL_BROKER,
    spd.percentCHANNEL_CORRES
--    spe.HARP_eligible
INTO #Symphony_pools
FROM GNM.sec s
JOIN scale.GNM_PoolHist sph
    ON s.issueId = sph.issueId
JOIN #ticker tk
    ON sph.marketTicker = tk.tickerName
JOIN GNM.secFactor sf
    ON sph.issueId = sf.issueId
    AND sph.asOf = sf.asOf
JOIN scale.GNM_PoolDistribution spd
    ON sph.issueId = spd.issueId
    AND sph.asOf = spd.asOf
JOIN scale.GNM_PoolEligibility spe
    ON sph.issueId = spe.issueId
    AND sph.asOf = spe.asOf
JOIN scale.GNM_PoolIncentive spi
    ON sph.issueId = spi.issueId
    AND sph.asOf = spi.asOf
JOIN scale.GNM_PoolBurnout spb
    ON sph.issueId = spb.issueId
    AND sph.asOf = spb.asOf
WHERE 1=1
    AND spi.version = '2.00'
    AND spb.version = '1.00'
    @ASOF_WHERE@
    AND sf.schamBalance > 0.01
;
COMMIT;
