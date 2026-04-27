-- Symphony Tracking Data
-- Ginnie Project Loans
-- Pool Level
-- Script to pull data from Scale tables for Symphony Tracking

-----------------------------------------------------------
-- Calculate the Penalty Shift Adjustments
-----------------------------------------------------------
DROP TABLE IF EXISTS #penalty_shift;
SELECT 
    spi.loanNumber,
    spi.poolNumber, 
    spi.issueId, 
    spi.asOf, --factor date
    spi.penalty_adjusted_incentive,
    spi.max_penalty_adjusted_incentive,
    sph.penaltyRate,
    sph.penaltyCycle,
    CASE WHEN sph.canPrepay = 1 AND spi.penalty_adjusted_incentive > 0 THEN spi.penalty_adjusted_incentive ELSE 0.0 END as mod_incentive,
    CASE WHEN mod_incentive - ISNULL(spi.max_penalty_adjusted_incentive, 0.0) <= 0 THEN 0.0 ELSE mod_incentive - ISNULL(spi.max_penalty_adjusted_incentive, 0) END as exceed,
    CASE WHEN exceed < 0 THEN 0.0 WHEN exceed > 5 THEN 1.0 ELSE exceed / 5.0 END as min_max_exceed,
    CASE WHEN 2.0 * (mod_incentive - 20.0) < 0 THEN 0.0 WHEN 2.0 * (mod_incentive - 20.0) > 25 THEN 25.0 ELSE 2.0 * (mod_incentive - 20.0) END as exceed_adjustment_raw,
    exceed_adjustment_raw * min_max_exceed as exceed_adjustment,
    CASE 
        WHEN sph.penaltyRate = 6  THEN 7.5
        WHEN sph.penaltyRate = 7  THEN 7.5
        WHEN sph.penaltyRate = 8  THEN 32.5
        WHEN sph.penaltyRate = 9  THEN 27.5
        WHEN sph.penaltyRate = 10 THEN -19.0
        ELSE 0.0
    END as penalty_shift_raw,
    CASE 
        WHEN spi.penalty_adjusted_incentive >= 35.0 THEN 1.0
        WHEN spi.penalty_adjusted_incentive <= 10.0 THEN 0.0
        ELSE (spi.penalty_adjusted_incentive - 10.0) / 25.0
    END as penalty_shift_mult,
    penalty_shift_raw * penalty_shift_mult as penalty_adjustment, --penalty_shift,
    --CASE 
    --    WHEN 0.04 * (spi.penalty_adjusted_incentive - 10.0) <= 0.0 THEN 0.0 
    --    WHEN 0.04 * (spi.penalty_adjusted_incentive - 10.0) >= 1.0 THEN 1.0 
    --    ELSE 0.04 * (spi.penalty_adjusted_incentive - 10.0) 
    --END * penalty_shift as penalty_adjustment,
    CASE 
        WHEN sph.penaltyCycle = '0001'  THEN -10.0
        WHEN sph.penaltyCycle = '0011'  THEN -50.0
        WHEN sph.penaltyCycle = '1100'  THEN -22.5
        WHEN sph.penaltyCycle = '1000'  THEN 10.0
        ELSE 0.0
    END as penalty_cycle_shift_raw,
    CASE 
        WHEN spi.penalty_adjusted_incentive >= 35.0 THEN 1.0
        WHEN spi.penalty_adjusted_incentive <= -5.0 THEN 0.0
        ELSE (spi.penalty_adjusted_incentive + 5.0) / 40.0
    END as penalty_cycle_shift_mult,
    penalty_cycle_shift_raw * penalty_cycle_shift_mult as penalty_cycle_adjustment, --penalty_cycle_shift,
    --CASE 
    --    WHEN 0.025 * (spi.penalty_adjusted_incentive + 5.0) <= 0.0 THEN 0.0 
    --    WHEN 0.025 * (spi.penalty_adjusted_incentive + 5.0) >= 1.0 THEN 1.0 
    --    ELSE 0.025 * (spi.penalty_adjusted_incentive + 5.0) 
    --END * penalty_cycle_shift as penalty_cycle_adjustment,
    CASE 
        WHEN sph.penaltyCycle = '0001'  THEN 0.70
        WHEN sph.penaltyCycle = '0011'  THEN 0.11
        WHEN sph.penaltyCycle = '1100'  THEN 1.71
        WHEN sph.penaltyCycle = '1000'  THEN 1.29
        ELSE 1.0
    END as penalty_cycle_mult
INTO #penalty_shift
FROM scale.GPL_PoolHist_Intex sph
JOIN scale.GPL_PoolIncentive_Intex spi 
    ON sph.loanNumber = spi.loanNumber
    AND sph.poolNumber = spi.poolNumber
    AND sph.asOf = spi.asOf
WHERE 1=1
    AND spi.version = '1.30'
;
COMMIT;

-----------------------------------------------------------
-- Store all pools with pertinent data
-----------------------------------------------------------
DROP TABLE IF EXISTS #Symphony_pools;
SELECT
    year(s.issueDate) as vintage,
    sph.issueId,
    sph.asOf, -- factor date
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
    sfo.schamBalance,
    CASE WHEN sph.delinqStatus = 'C' OR sph.hasDelinqInfo = 0 THEN 100.0 ELSE 0.0 END as percentCURRENT,
    CASE WHEN sph.delinqStatus = '30' THEN 100.0 ELSE 0.0 END as percentDQ30,
    CASE WHEN sph.delinqStatus = '60' THEN 100.0 ELSE 0.0 END as percentDQ60,
    CASE WHEN sph.delinqStatus = '90' THEN 100.0 ELSE 0.0 END as percentDQ90,
    spi.penalty_adjusted_incentive as refi_incentive,
    spi.max_penalty_adjusted_incentive as max_refi_incentive,
    
    CASE WHEN sg.surge_index IS NULL THEN 0.0 ELSE sg.surge_index END as surge_index,
    spi.penalty_adjusted_incentive 
        + CASE WHEN ps.exceed_adjustment IS NULL THEN 0.0 ELSE ps.exceed_adjustment END 
        + CASE WHEN ps.penalty_adjustment IS NULL THEN 0.0 ELSE ps.penalty_adjustment END 
        + CASE WHEN ps.penalty_cycle_adjustment IS NULL THEN 0.0 ELSE ps.penalty_cycle_adjustment END 
        as adjusted_refi_incentive,
    ps.penalty_cycle_mult,
    
    spb.burnout,
    sph.wala,
    s.origIssueAmount as origLoanSize,
    sfo.schamBalance as currLoanSize,
    s.loanInterestRate as origNoteRate,
    CASE WHEN s.beganAsConstructionLoan = 'Y' THEN 100.0 ELSE 0.0 END as percentConstruction,
    CASE WHEN sph.canPrepay = 1 THEN 100.0 ELSE 0.0 END as percentCanPrepay,
    1.0 as monthSinceCurrent,
    sph.turnoverWALA,
    sph.monthsSinceLoanIssuance,
    sph.ignoreDelinq,
    CASE WHEN sppb.projectedAverageLoanSize IS NOT NULL THEN sppb.projectedAverageLoanSize ELSE s.origIssueAmount END as projected_origLoanSize,
    CASE WHEN sppb.projectedCurrentBalance IS NOT NULL THEN sppb.projectedCurrentBalance ELSE sfo.schamBalance END as projected_currLoanSize
INTO #Symphony_pools
FROM scale.GPL_Pool_Intex s
JOIN scale.GPL_PoolHist_Intex sph
    ON s.loanNumber = sph.loanNumber
JOIN #ticker tk
    ON s.marketTicker = tk.tickerName
JOIN scale.GPL_PoolIncentive_Intex spi
    ON sph.loanNumber = spi.loanNumber
    AND sph.asOf = spi.asOf
JOIN scale.GPL_PoolBurnout_Intex spb
    ON sph.loanNumber = spb.loanNumber
    AND sph.asOf = spb.asOf
JOIN project_loan.SecFactorPoolSummary sfo
    ON sph.poolNumber = sfo.poolNumber
    AND sph.asOf = sfo.asOf
--JOIN project_loan.SecFactorPoolSummary sfps
--    ON sph.poolNumber = sfps.poolNumber
--    AND sph.asOf = dateadd(month, -1, sfps.asOf)
JOIN #penalty_shift ps
    ON sph.loanNumber = ps.loanNumber
    AND sph.asOf = ps.asOf
LEFT OUTER JOIN scale.GPL_Pool_ProjectedBalance sppb
    ON sph.poolNumber = sppb.poolNumber
    AND sph.asOf = sppb.asOf
    AND sppb.version = (SELECT ProjectedBalance_PL FROM scale.ModelVersionConfig WHERE appType = '4.00' AND agency = 'GPL' and tickerName = 'GPL')
LEFT JOIN #SurgeIndex sg
    ON sph.asOf = dateadd(month, +2, sg.asOf) -- same lag as MtgRate
WHERE 1=1
    AND s.poolInDeal = 1
    AND spi.version = (SELECT IncentiveVersion_PL FROM scale.ModelVersionConfig WHERE appType = '4.00' AND agency = 'GPL' and tickerName = 'GPL')
    AND spb.version = (SELECT BurnoutVersion_PL FROM scale.ModelVersionConfig WHERE appType = '4.00' AND agency = 'GPL' and tickerName = 'GPL')
    @ASOF_WHERE@
    AND sfo.schamBalance > 0.01
    AND sph.wala >= 0
    AND s.poolIsUnique = 1
    AND s.poolType in ('PL','PN','LM', 'CL','CS')
    AND sph.asOf >= '2005-11-01'
;
COMMIT;

