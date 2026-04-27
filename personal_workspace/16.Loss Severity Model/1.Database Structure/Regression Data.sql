------------------------------------------------------
--  Two Year Moving Average on HPA index
--  States level index is available
------------------------------------------------------

-- Create Monthly HPI data from raw FHFA data
DROP TABLE IF EXISTS #t;
CREATE TABLE #t(
    monthInQuarter int
)
;    
INSERT #t SELECT 1;
INSERT #t SELECT 2;
INSERT #t SELECT 3;
COMMIT;

DROP TABLE IF EXISTS #HomePriceIndex_temp1;
SELECT
    RegionType,
    Region,
    MSACode,
    Year,
    Quarter,
    convert(date, convert(char(8), Year * 10000 + (3 * Quarter) * 100 + 1)) as asOf,
    NSAIndex as HPIndex
INTO #HomePriceIndex_temp1
FROM hpi.HomePriceIndex
WHERE TransactionType = 'ALL_TRANSACTIONS' --'PURCHASE_ONLY' --
    AND loadQuarter = (SELECT max(loadQuarter) FROM hpi.HomePriceIndex)
    AND RegionType IN ('STATE','US_AND_CENSUS','USA')
    --AND RegionType IN ('MSA','STATE','STATE_NONMSA','US_AND_CENSUS')
;
COMMIT;

-- Extend Time Series for several months after end
DROP TABLE IF EXISTS #HomePriceIndex_1Q;
SELECT
    RegionType,
    Region,
    MSACode,
    year(nextAsOf) as Year,
    quarter(nextAsOf) as Quarter,
    dateadd(month,3,AsOf) as nextAsOf,
    HPIndex
INTO #HomePriceIndex_1Q
FROM #HomePriceIndex_temp1
WHERE asOf = (SELECT max(asOf) FROM #HomePriceIndex_temp1)
;
COMMIT;

DROP TABLE IF EXISTS #HomePriceIndex_2Q;
SELECT
    RegionType,
    Region,
    MSACode,
    year(nextAsOf) as Year,
    quarter(nextAsOf) as Quarter,
    dateadd(month,6,AsOf) as nextAsOf,
    HPIndex
INTO #HomePriceIndex_2Q
FROM #HomePriceIndex_temp1
WHERE asOf = (SELECT max(asOf) FROM #HomePriceIndex_temp1)
;
COMMIT;

INSERT INTO #HomePriceIndex_temp1 SELECT * FROM #HomePriceIndex_1Q;
INSERT INTO #HomePriceIndex_temp1 SELECT * FROM #HomePriceIndex_2Q;

DROP TABLE IF EXISTS #HomePriceIndex_norm;
SELECT
    t1.RegionType,
    t1.Region,
    t1.MSACode,
    t1.asOf as beginDate,
    t2.asOf as endDate,
    t1.HPIndex as from_Idx,
    t2.HPIndex as to_Idx,
    t1.HPIndex + (t2.HPIndex - t1.HPIndex) / 3.0 as interp1,
    t1.HPIndex + 2 * (t2.HPIndex - t1.HPIndex) / 3.0 as interp2
INTO #HomePriceIndex_norm
FROM #HomePriceIndex_temp1 t1
JOIN #HomePriceIndex_temp1 t2
    ON t1.asOf = dateadd(month,-3,t2.AsOf)
    AND t1.RegionType = t2.RegionType
    AND (t1.Region = t2.Region OR t1.MSACode = t2.MSACode)
;
COMMIT;

DROP TABLE IF EXISTS #HomePriceIndex_monthly;
SELECT
    t1.RegionType as RegionType,
    t1.Region as Region,
    t1.MSACode as MSACode,
    t1.Year as Year,
    t1.Quarter as Quarter,
    convert(date, convert(char(8), Year * 10000 + (3 * (Quarter - 1) + t.monthInQuarter) * 100 + 1)) as asOf,
    CASE 
        WHEN t.monthInQuarter = 1 THEN norm.interp1 
        WHEN t.monthInQuarter = 2 THEN norm.interp2 
        ELSE t1.HPIndex 
    END as HPIndex
INTO #HomePriceIndex_monthly
FROM #HomePriceIndex_temp1 t1
CROSS JOIN #t t
LEFT JOIN #HomePriceIndex_norm norm
    ON t1.asOf = norm.endDate
    AND t1.RegionType = norm.RegionType
    AND (t1.Region = norm.Region OR t1.MSACode = norm.MSACode)
;
COMMIT;

CREATE INDEX loan_asOf_idx ON #HomePriceIndex_monthly(asOf);
COMMIT;

  -- Creates a X YR Moving HPA
DROP TABLE IF EXISTS #HPA_MA;
SELECT
    t1.RegionType,
    t1.Region,
    t1.MSACode,
    t1.asOf,
    t1.HPIndex as HPIndex,
    t3.HPIndex as HPIndex_2YR,
    CASE WHEN t3.HPIndex IS NULL THEN NULL ELSE t1.HPIndex / t3.HPIndex END as HPA_2YR
INTO #HPA_MA
FROM #HomePriceIndex_monthly t1
LEFT JOIN #HomePriceIndex_monthly t3
    ON t1.RegionType = t3.RegionType
    AND t1.Region = t3.Region
    AND (t1.MSACode = t3.MSACode OR t1.MSACode IS NULL AND t3.MSACode IS NULL)
    AND t1.asOf = dateadd(month, 24, t3.asOf)
;
COMMIT;

CREATE INDEX asOf_idx ON #HPA_MA(asOf);
COMMIT;

--DELETE FROM #HPA_MA WHERE HPA_1YR IS NULL;
--COMMIT;

DELETE FROM #HPA_MA WHERE HPA_2YR IS NULL;
COMMIT;





-------------------------- Haircut Regression using normalized table (also used for expenses regression) ------------------
SELECT 
    orig.loanID,
    --year(loss.begindate) as year,
    loss.lossDate,
    perf.beginLoanAge,
    orig.JudicialFlag,
    orig.origbalance,
    orig.loanpurpose,
    orig.occupancyStatus,
    orig.propertyType,
    orig.miLevel,
    loss.miRecoveries,
    loss.nonMIRecoveries,
    perf.beginCoupon,
    currentValue = convert(decimal(16,2),round(orig.origValue * perf.HPA,2)),
    perf.beginBalance UPB,
    loss.expenses,
    netSaleProceeds = cast(loss.netSaleProceeds as double),
    timeDQ = datediff(month, loss.lastPaymentDate, perf.beginDate),
    DiscountPct = convert(decimal(16,2),round(cast(loss.netSaleProceeds as double) / (orig.origValue * perf.HPA)*100,2)),
    ActuralLoss = convert(decimal(16,2),round(perf.beginBalance - cast(loss.netSaleProceeds as double) - loss.expenses + (timeDQ * perf.beginBalance * 30/360 * (perf.begincoupon - 0.25)/100) - loss.MIRecoveries - loss.nonMIRecoveries,2)),
    ActuralLossBEI = convert(decimal(16,2),round(perf.beginBalance - cast(loss.netSaleProceeds as double) - loss.expenses + (timeDQ * perf.beginBalance * 30/360 * (perf.begincoupon - 0.25)/100),2)),
    ActuralLossBEIM = convert(decimal(16,2),round(perf.beginBalance - cast(loss.netSaleProceeds as double) - loss.expenses + (timeDQ * perf.beginBalance * 30/360 * (perf.begincoupon - 0.25)/100) - loss.MIRecoveries,2)),
    ActuralSeverity = convert(decimal(16,2),round(ActuralLoss / UPB,2)),
    perf.HPA,
    perf1.zeroBalanceCode,
--    hpiold.Delta as NSAIndex,
    hpi.HPA_2YR as HPA2Yr,
    orig.state as state
--FROM fhl.PIV_CreditOrigination orig
--LEFT JOIN fhl.PIV_CreditLossHist loss
FROM fnm.PIV_CreditOrigination orig
LEFT JOIN fnm.PIV_CreditLossHist loss
    ON orig.loanID = loss.loanID
--JOIN fhl.PIV_CreditPerformanceHist perf
JOIN fnm.PIV_CreditPerformanceHist perf
    ON orig.loanID = perf.loanID
    and loss.lossDate = perf.begindate
--JOIN fhl.LoanLevelHistMonthlyPerformData perf1
JOIN fnm.LoanLevelHistMonthlyPerformData perf1
    ON orig.loanID = perf1.loanID
    and loss.lossDate = perf1.asof
--    AND perf1.zeroBalanceCode IN (3,9)
    AND perf1.zeroBalanceCode IN ('03','09')
JOIN #HPA_MA hpi
    ON loss.lossDate = hpi.asof
    and orig.state = hpi.Region

--JOIN #HomePriceGrowthIndex_monthly hpiold
--    ON loss.lossDate = hpiold.asof

--where ActuralSeverity > 0
--    and ActuralSeverity < 1.05






