-- Refinance Queries (Pool Level)


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
    HPIndex * power(1.0 + 3.0 / 100.0, 3.0 / 12.0)
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
    HPIndex * power(1.0 + 3.0 / 100.0, 3.0 / 12.0) * power(1.0 + 3.0 / 100.0, 3.0 / 12.0)
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
    t2.HPIndex as HPIndex_1YR,
    t3.HPIndex as HPIndex_2YR,
    CASE WHEN t2.HPIndex IS NULL THEN NULL ELSE t1.HPIndex / t2.HPIndex END as HPA_1YR,
    CASE WHEN t3.HPIndex IS NULL THEN NULL ELSE t1.HPIndex / t3.HPIndex END as HPA_2YR
INTO #HPA_MA
FROM #HomePriceIndex_monthly t1
LEFT JOIN #HomePriceIndex_monthly t2
    ON t1.RegionType = t2.RegionType
    AND t1.Region = t2.Region
    AND (t1.MSACode = t2.MSACode OR t1.MSACode IS NULL AND t2.MSACode IS NULL)
    AND t1.asOf = dateadd(month, 12, t2.asOf)
LEFT JOIN #HomePriceIndex_monthly t3
    ON t1.RegionType = t3.RegionType
    AND t1.Region = t3.Region
    AND (t1.MSACode = t3.MSACode OR t1.MSACode IS NULL AND t3.MSACode IS NULL)
    AND t1.asOf = dateadd(month, 24, t3.asOf)
;
COMMIT;

CREATE INDEX asOf_idx ON #HPA_MA(asOf);
COMMIT;

DELETE FROM #HPA_MA WHERE HPA_1YR IS NULL;
COMMIT;

DELETE FROM #HPA_MA WHERE HPA_2YR IS NULL;
COMMIT;


-- Get the Mortgage Rates from Time Series Database
DROP TABLE IF EXISTS #Mtg30YrRates_monthly;
SELECT
    TickerName as SeriesName,
    AsOfDate as asOf, 
    convert(date, dateadd(month, +1, AsOfDate)) as asOf_lag1,
    convert(date, dateadd(month, +2, AsOfDate)) as asOf_lag2,
    SeriesNumValue as MtgRate
INTO #Mtg30YrRates_monthly
FROM report.TimeSeries ts
JOIN report.TimeSeriesMeta tsm
    ON ts.TimeSeriesMetaId = tsm.TimeSeriesMetaId
WHERE 1=1
    AND SeriesType = 'MONTHLY_MTG_RATE'
;
COMMIT;

CREATE INDEX series_idx ON #Mtg30YrRates_monthly(SeriesName);
CREATE INDEX asOf_idx ON #Mtg30YrRates_monthly(asOf);
CREATE INDEX asOf_lag1_idx ON #Mtg30YrRates_monthly(asOf_lag1);
CREATE INDEX asOf_lag2_idx ON #Mtg30YrRates_monthly(asOf_lag2);
COMMIT;


-- Pool Ids and Dates

  -- GNMA
DROP TABLE IF EXISTS #GNMA_Pools;
SELECT
    p.marketTicker,
    p.issueId,
    p.OrigCoupon,
    f.asOf,
    p.issueDate,
    CASE WHEN f.calcOrigMonth IS NULL THEN p.issueDate ELSE convert(date, convert(char(8), f.calcOrigMonth * 100 + 1)) END as originationDate,
    x.originalTerm as origTerm,
    1.0 - ((1.0 + f.wac / 1200.0)^f.wala - 1.0) / ((1.0 + f.wac / 1200.0)^360 - 1.0) as factor,
    f.wala, 
    f2.schamBalance, -- offset by 1 so that our model projection for the factor date will match the prepay for that period
    f.wac, 
    CASE WHEN f.waoltv = -999 THEN NULL ELSE f.waoltv END as waoltv,
    CASE WHEN f.waclSize = -999 THEN NULL ELSE f.waclSize END as waclSize,
    CASE WHEN f.waolSize = -999 THEN NULL ELSE f.waolSize END as waolSize,
    CASE WHEN f.waocs = -999 THEN NULL ELSE f.waocs END as waocs, 
    f2.currentBalance, -- offset by 1 so that our model projection for the factor date will match the prepay for that period
    f2.inVoluntaryAmount,
    s.waCLTV,
    mr.MtgRate as MtgRate,

    cast(NULL as numeric(8, 4)) as mip_annual_begin,
    cast(NULL as numeric(8, 4)) as mip_annual,
    cast(NULL as numeric(8, 4)) as mip_upfront_begin,
    cast(NULL as numeric(8, 4)) as mip_upfront,
    cast(NULL as numeric(8, 4)) as mip_begin,
    cast(NULL as numeric(8, 4)) as mip,

    cast(NULL as numeric(8, 4)) as SATO,
    cast(NULL as numeric(8, 4)) as HPA,
    cast(NULL as numeric(8, 4)) as HPI,
    cast(NULL as numeric(8, 4)) as HPA_1YR,
    cast(NULL as numeric(8, 4)) as HPA_2YR,
    cast(100.0 as numeric(8, 2)) as Pct_OWNER,
    cast(0.0 as numeric(8, 2)) as Pct_2ND,
    cast(0.0 as numeric(8, 2)) as Pct_INV,
    cast(0.0 as numeric(8, 2)) as Pct_FHA,
    cast(0.0 as numeric(8, 2)) as Pct_NONFHA,
    cast(NULL as numeric(8, 2)) as Pct_CURRENT,
    cast(NULL as numeric(8, 2)) as Pct_DELQ,
    cast(NULL as numeric(8, 2)) as Pct_D30,
    cast(NULL as numeric(8, 2)) as Pct_D60,
    cast(NULL as numeric(8, 2)) as Pct_D90,
    cast(NULL as numeric(12, 4)) as burnout,
    cast(NULL as numeric(8, 4)) as incentive
INTO #GNMA_Pools
FROM gnm.sec p
JOIN gnm.Prefix x
    ON p.prefix = x.prefix
    AND p.product = x.product
JOIN #ticker tk
    ON p.marketTicker = tk.tickerName
JOIN gnm.secFactor f
    ON p.issueId = f.issueId
JOIN gnm.secFactor f2
    ON p.issueId = f2.issueId
    AND f.asOf = dateadd(month, -1, f2.asOf)
JOIN #Mtg30YrRates_monthly mr
    ON mr.asOf_lag1 = f.asOf
    AND mr.SeriesName = tk.mtgRateSeries
LEFT JOIN gnm.secSupp s
    ON p.issueId = s.issueId
    AND s.asOf = f.asOf
WHERE 1=1
    AND p.collateralType = 'LOAN'
    AND f.wala >= 1
    AND f.schamBalance > 0.01
    AND f2.schamBalance > 0.01
    AND f.wac > 0
;
COMMIT;

CREATE INDEX issueId_idx ON #GNMA_Pools(issueId);
CREATE INDEX issueDate_idx ON #GNMA_Pools(issueDate);
CREATE INDEX asOf_idx ON #GNMA_Pools(asOf);
COMMIT;

-- Update HPA_XYR and HPI
UPDATE #GNMA_Pools perf SET perf.HPA_2YR = hpi.HPA_2YR, perf.HPA_1YR = hpi.HPA_1YR, perf.HPI = hpi.HPIndex
FROM #HPA_MA hpi
WHERE perf.asOf = hpi.asOf 
    AND hpi.Region = 'USA'
;

-- Pool Origination Data (or Oldest data available)
DROP TABLE IF EXISTS #GNMA_MinDate_FICO;
SELECT
    marketTicker,
    issueId,
    issueDate,
    min(asOf) as asOf,
    cast(NULL as numeric(8, 4)) as waocs
INTO #GNMA_MinDate_FICO
FROM #GNMA_Pools p
WHERE p.waocs IS NOT NULL 
    AND p.waocs <> -999
GROUP BY marketTicker, issueId, issueDate
;
COMMIT;

UPDATE #GNMA_MinDate_FICO s SET s.waocs = d.waocs
FROM #GNMA_Pools d
WHERE s.issueId = d.issueId
    AND s.asOf = d.asOf
;

DROP TABLE IF EXISTS #GNMA_MinDate_AOLS;
SELECT
    marketTicker,
    issueId,
    issueDate,
    min(asOf) as asOf,
    cast(NULL as numeric(12, 2)) as waolSize
INTO #GNMA_MinDate_AOLS
FROM #GNMA_Pools p
WHERE p.waolSize IS NOT NULL
    AND p.waolSize <> -999
GROUP BY marketTicker, issueId, issueDate
;
COMMIT;

UPDATE #GNMA_MinDate_AOLS s SET s.waolSize = d.waolSize
FROM #GNMA_Pools d
WHERE s.issueId = d.issueId
    AND s.asOf = d.asOf
;

DROP TABLE IF EXISTS #GNMA_MinDate_OLTV;
SELECT
    marketTicker,
    issueId,
    issueDate,
    min(asOf) as asOf,
    cast(NULL as numeric(8, 4)) as waoltv
INTO #GNMA_MinDate_OLTV
FROM #GNMA_Pools p
WHERE p.waoltv IS NOT NULL
    AND p.waoltv <> -999
GROUP BY marketTicker, issueId, issueDate
;
COMMIT;

UPDATE #GNMA_MinDate_OLTV s SET s.waoltv = d.waoltv
FROM #GNMA_Pools d
WHERE s.issueId = d.issueId
    AND s.asOf = d.asOf
;

DROP TABLE IF EXISTS #GNMA_Origination;
SELECT
    marketTicker,
    issueId,
    cast(NULL as date) as originationDate,
    min(asOf) as asOf,
   cast(NULL as numeric(8, 4)) as HPI_orig
INTO #GNMA_Origination
FROM #GNMA_Pools p
GROUP BY marketTicker, issueId
;
COMMIT;

UPDATE #GNMA_Origination s SET s.originationDate = p.originationDate
FROM #GNMA_Pools p
WHERE p.issueId = s.issueId
    AND p.asOf = s.asOf
;
COMMIT;

UPDATE #GNMA_Origination s SET s.HPI_orig = hpi.HPIndex
FROM #HPA_MA hpi
WHERE s.originationDate = hpi.asOf
;
COMMIT;

-- Update FICO, OLTV, AOLS, HPA, CLTV

-- FICO is sparsely populated, so we want to use the Avg FICO for each issueDate to fill in the gaps
UPDATE #GNMA_Pools perf SET perf.waocs = s.waocs
FROM #GNMA_MinDate_FICO s
WHERE perf.issueId = s.issueId 
    AND perf.waocs IS NULL
;

DROP TABLE IF EXISTS #GNMA_IssueDate_FICO;
SELECT
    issueDate,
    sum(schambalance * waocs) / sum(schambalance) as WAVG_FICO
INTO #GNMA_IssueDate_FICO
FROM #GNMA_Pools p
WHERE waocs IS NOT NULL
GROUP BY issueDate
;
COMMIT;

UPDATE #GNMA_Pools perf SET perf.waocs = oc.WAVG_FICO
FROM #GNMA_IssueDate_FICO oc
WHERE perf.issueDate = oc.issueDate
    AND perf.waocs IS NULL 
;

-- OLTV
UPDATE #GNMA_Pools perf SET perf.waoltv = s.waoltv
FROM #GNMA_MinDate_OLTV s
WHERE perf.issueId = s.issueId 
    AND perf.waoltv IS NULL
;

DROP TABLE IF EXISTS #GNMA_IssueDate_OLTV;
SELECT
    issueDate,
    sum(schambalance * waoltv) / sum(schambalance) as WAVG_OLTV
INTO #GNMA_IssueDate_OLTV
FROM #GNMA_Pools p
WHERE waoltv IS NOT NULL
GROUP BY issueDate
;
COMMIT;

UPDATE #GNMA_Pools perf SET perf.waoltv = ltv.WAVG_OLTV
FROM #GNMA_IssueDate_OLTV ltv
WHERE perf.issueDate = ltv.issueDate
    AND perf.waoltv IS NULL 
;

-- AOLS
UPDATE #GNMA_Pools perf SET perf.waolSize = s.waolSize
FROM #GNMA_MinDate_AOLS s
WHERE perf.issueId = s.issueId 
    AND perf.waolSize IS NULL
;

DROP TABLE IF EXISTS #GNMA_IssueDate_AOLS;
SELECT
    issueDate,
    sum(schambalance * waolSize) / sum(schambalance) as WAVG_AOLS
INTO #GNMA_IssueDate_AOLS
FROM #GNMA_Pools p
WHERE waolSize IS NOT NULL
GROUP BY issueDate
;
COMMIT;

UPDATE #GNMA_Pools perf SET perf.waolSize = ols.WAVG_AOLS
FROM #GNMA_IssueDate_AOLS ols
WHERE perf.issueDate = ols.issueDate
    AND perf.waolSize IS NULL 
;

-- HPA / CLTV / ACLS
UPDATE #GNMA_Pools perf SET perf.HPA = perf.HPI / s.HPI_orig
FROM #GNMA_Origination s
WHERE perf.issueId = s.issueId 
;

UPDATE #GNMA_Pools perf SET perf.wacltv = perf.waoltv * perf.factor / perf.HPA
WHERE wacltv IS NULL 
    OR wacltv = -999
    OR wacltv = 999
;

UPDATE #GNMA_Pools perf SET perf.waclSize = perf.waolSize * perf.factor
WHERE waclSize IS NULL 
    OR waclSize = -999
    OR waclSize = 999
;

-- Pool Distributions

 -- Occupancy Not Needed for Ginnie Pools

 -- Update the Pools Tables with the FHA Distribution Info
UPDATE #GNMA_Pools perf SET perf.Pct_FHA = dist.percentRpb, perf.Pct_NonFHA = 100.0 - dist.percentRpb
FROM gnm.PIV_FhaVaDist dist
WHERE perf.issueId = dist.issueId 
    AND perf.asOf = dist.asOf
    AND state = 'FHA'
;

 -- Delinquency
DROP TABLE IF EXISTS #GNMA_DELQ_Dist;
SELECT
    p.issueId,
    p.asOf,
    sum(IFNULL(rpb_RPDEL , 0.0, rpb_RPDEL ) + IFNULL(rpb_FORECL , 0.0, rpb_FORECL ) + IFNULL(rpb_REPLMT , 0.0, rpb_REPLMT )) as default_bal,
    sum(CASE WHEN percentrpb_DEL30 = -999 THEN 0 ELSE IFNULL(percentrpb_DEL30, 0.0, percentrpb_DEL30) END) as Pct_DQ30,
    sum(CASE WHEN percentrpb_DEL60 = -999 THEN 0 ELSE IFNULL(percentrpb_DEL60, 0.0, percentrpb_DEL60) END) as Pct_DQ60,
    sum(CASE WHEN percentrpb_DEL90 = -999 THEN 0 ELSE IFNULL(percentrpb_DEL90, 0.0, percentrpb_DEL90) END) as Pct_DQ90
INTO #GNMA_DELQ_Dist
FROM #GNMA_Pools p
LEFT JOIN gnm.PivotedDelinqDist s 
    ON p.issueID = s.issueID
    AND p.asOF = s.asOf
GROUP BY p.issueId, p.asOf
;
COMMIT;

CREATE INDEX issueId_idx ON #GNMA_DELQ_Dist(issueId);
CREATE INDEX asOf_idx ON #GNMA_DELQ_Dist(asOf);
COMMIT;

-- Update the Pools Tables with the Delinquency Info
UPDATE #GNMA_Pools perf SET perf.Pct_DELQ = dist.Pct_DQ30 + dist.Pct_DQ60 + dist.Pct_DQ90, 
    perf.Pct_D30 = dist.Pct_DQ30, 
    perf.Pct_D60 = dist.Pct_DQ60, 
    perf.Pct_D90 = dist.Pct_DQ90
FROM #GNMA_DELQ_Dist dist
WHERE perf.issueId = dist.issueId 
    AND perf.asOf = dist.asOf
;
UPDATE #GNMA_Pools perf SET perf.Pct_CURRENT = 100.0 - perf.Pct_DELQ;


-- Fix Loan Size MIP Nulls
-- Nothing to do yet

    -- Update mip_annual_begin
UPDATE #GNMA_Pools inc SET inc.mip_annual_begin = mip.AnnualMIPPoints
FROM gnm.MIPRulesMatrix mip
WHERE 1=1   
    AND inc.origTerm         >  origTermLowBound  
	AND inc.origTerm         <= origTermHighBound 
	AND inc.waoltv           >  LTVLowBound  
	AND inc.waoltv           <= LTVHighBound 
	AND inc.waolSize         >  LoanOrigAmountLowBound 
	AND inc.waolSize         <= LoanOrigAmountHighBound
	AND inc.originationDate  >  LoanOrigDateLowBound
	AND inc.originationDate  <= LoanOrigDateHighBound
	AND inc.originationDate  >  CaseAssignDateLowBound
	AND inc.originationDate  <= CaseAssignDateHighBound
;
UPDATE #GNMA_Pools inc SET inc.mip_annual_begin = 50 WHERE inc.mip_annual_begin IS NULL;

    -- Update mip_annual
UPDATE #GNMA_Pools inc SET inc.mip_annual = mip.AnnualMIPPoints
FROM gnm.MIPRulesMatrix mip
WHERE 1=1    
    AND inc.origTerm         >  origTermLowBound  
	AND inc.origTerm         <= origTermHighBound 
	AND inc.waCLTV           >  LTVLowBound  
	AND inc.waCLTV           <= LTVHighBound 
	AND inc.waclSize         >  LoanOrigAmountLowBound 
	AND inc.waclSize         <= LoanOrigAmountHighBound
	AND inc.originationDate  >  LoanOrigDateLowBound
	AND inc.originationDate  <= LoanOrigDateHighBound
	AND inc.asOf             >  CaseAssignDateLowBound
	AND inc.asOf             <= CaseAssignDateHighBound
;
UPDATE #GNMA_Pools inc SET inc.mip_annual = 50 WHERE inc.mip_annual IS NULL;

    -- Update mip_upfront_begin
UPDATE #GNMA_Pools inc SET inc.mip_upfront_begin = mip.UpfrontMIPPoints
FROM gnm.MIPRulesMatrix mip
WHERE 1=1   
    AND inc.origTerm         >  origTermLowBound  
	AND inc.origTerm         <= origTermHighBound 
	AND inc.waoltv           >  LTVLowBound  
	AND inc.waoltv           <= LTVHighBound 
	AND inc.waolSize         >  LoanOrigAmountLowBound 
	AND inc.waolSize         <= LoanOrigAmountHighBound
	AND inc.originationDate  >  LoanOrigDateLowBound
	AND inc.originationDate  <= LoanOrigDateHighBound
	AND inc.originationDate  >  CaseAssignDateLowBound
	AND inc.originationDate  <= CaseAssignDateHighBound
;
UPDATE #GNMA_Pools inc SET inc.mip_upfront_begin = 0 WHERE inc.mip_upfront_begin IS NULL;

    -- Update mip_upfront
UPDATE #GNMA_Pools inc SET inc.mip_upfront = mip.UpfrontMIPPoints
FROM gnm.MIPRulesMatrix mip
WHERE 1=1    
    AND inc.origTerm         >  origTermLowBound  
	AND inc.origTerm         <= origTermHighBound 
	AND inc.waCLTV           >  LTVLowBound  
	AND inc.waCLTV           <= LTVHighBound 
	AND inc.waclSize         >  LoanOrigAmountLowBound 
	AND inc.waclSize         <= LoanOrigAmountHighBound
	AND inc.originationDate  >  LoanOrigDateLowBound
	AND inc.originationDate  <= LoanOrigDateHighBound
	AND inc.asOf             >  CaseAssignDateLowBound
	AND inc.asOf             <= CaseAssignDateHighBound
;
UPDATE #GNMA_Pools inc SET inc.mip_upfront = 0 WHERE inc.mip_upfront IS NULL;

    -- Update MIP
UPDATE #GNMA_Pools inc SET
    mip_begin = (mip_annual_begin + mip_upfront_begin / 12.0) / 100,
    mip = (mip_annual + mip_upfront / 12.0) / 100
;

    -- Update Refinance Incentive
UPDATE #GNMA_Pools inc SET incentive = wac + (Pct_FHA / 100.0) * (mip_begin - mip) - MtgRate;


-- Update burnout
DROP TABLE IF EXISTS #GNMA_Burnout;
SELECT 
    t0.issueId,
    t0.asOf as asOf,
    sum(log(CASE WHEN (t1.wac + (t1.Pct_FHA / 100.0) * t1.mip_begin) / (t1.MtgRate + (t1.Pct_FHA / 100.0) * t1.mip) <= 1 THEN 1 ELSE (t1.wac + (t1.Pct_FHA / 100.0) * t1.mip_begin) / (t1.MtgRate + (t1.Pct_FHA / 100.0) * t1.mip) END)) as burnout,
    sum(log(CASE WHEN t1.wac / t1.MtgRate <= 1 THEN 1 ELSE t1.wac / t1.MtgRate END)) as burnout_old
INTO #GNMA_Burnout
FROM #GNMA_Pools t0
JOIN #GNMA_Pools t1
    ON t0.issueId = t1.issueId
    AND t0.asOf >= t1.asOf
GROUP BY t0.issueId, t0.asOf
;

UPDATE #GNMA_Pools pl SET burnout = brn.burnout
FROM #GNMA_Burnout brn
WHERE pl.issueId = brn.issueId
    AND pl.asOf = brn.asOf
;


-- Update SATO
    

-- Store all pools with pertinent data
DROP TABLE IF EXISTS #refinance_pools;
SELECT
    issueId,
    year(issueDate) as vintage,
    OrigCoupon as origCoupon,
    asOf as asOfDate,
	monthBucket = (case 
        		    when month(asOf) = 1  then 'Jan'
        		    when month(asOf) = 2  then 'Feb'
        		    when month(asOf) = 3  then 'Mar'
        		    when month(asOf) = 4  then 'Apr'
        		    when month(asOf) = 5  then 'May'
        		    when month(asOf) = 6  then 'Jun'
        		    when month(asOf) = 7  then 'Jul'
        		    when month(asOf) = 8  then 'Aug'
         		    when month(asOf) = 9  then 'Sep'
        		    when month(asOf) = 10 then 'Oct'
                    when month(asOf) = 11 then 'Nov'
                    when month(asOf) = 12 then 'Dec'
        		    end),

	currentBalance as cbal,
	schamBalance as bbal,
    CASE WHEN Pct_OWNER IS NULL THEN 100.0 ELSE Pct_OWNER END as ppct_OWNER,
    CASE WHEN Pct_2ND IS NULL THEN 0.0 ELSE Pct_2ND END as ppct_2ND,
    CASE WHEN Pct_INV IS NULL THEN 0.0 ELSE Pct_INV END as ppct_INV,
    Pct_FHA as ppct_FHA,
    Pct_NONFHA as ppct_NONFHA,
    CASE WHEN Pct_CURRENT IS NULL THEN 100.0 ELSE Pct_CURRENT END as ppct_CURRENT,
    CASE WHEN Pct_DELQ IS NULL THEN 0.0 ELSE Pct_DELQ END as ppct_DELQ,
    CASE WHEN Pct_D30 IS NULL THEN 0.0 ELSE Pct_D30 END as ppct_D30,
    CASE WHEN Pct_D60 IS NULL THEN 0.0 ELSE Pct_D60 END as ppct_D60,
    CASE WHEN Pct_D90 IS NULL THEN 0.0 ELSE Pct_D90 END as ppct_D90,
    100.0 * incentive as iincentive,
    100.0 * mip_begin as origMIP,
    100.0 * mip as currMIP,
    MtgRate,
    100.0 * burnout as bburnout,
	SATO as ssato,
	wacltv as ccltv,
    CASE WHEN waclSize = -999 THEN NULL ELSE waclSize END as wwacls,
	waoltv as wwaoltv,
	wala as wwala,
	wac as wwac,
	waocs as ffico,
    100 * HPA_1YR as hhpa1yr,
    100 * HPA_2YR as hhpa2yr,
    convert(decimal(10,6), CASE WHEN 1.0 - currentBalance / schamBalance < 0 THEN 0.0 ELSE 1.0 - currentBalance / schamBalance END) as smm,
    convert(decimal(10,6), IFNULL(inVoluntaryAmount, 0.0, CASE WHEN 1.0 - inVoluntaryAmount / schamBalance < 0 THEN 0.0 ELSE 1.0 - inVoluntaryAmount / schamBalance END)) as mdr
INTO #refinance_pools
FROM #GNMA_Pools p
WHERE 1=1
    AND p.wala >= 1
;
COMMIT;


-- Supplement Burnout data with missing periods
DROP TABLE IF EXISTS #refinance_pools_origination;
SELECT
    rp.issueId,
    rp.asOfDate,
    dateadd(month, -(rp.wwala), rp.asOfDate) as originationDate,
    rp.wwala,
    rp.wwac,
    cast(NULL as numeric(8, 4)) as burnout
INTO #refinance_pools_origination
FROM #refinance_pools rp
JOIN (
        SELECT
            issueId,
            min(asOfDate) as first_asOf
        FROM #refinance_pools
        GROUP BY issueId
    ) orp
    ON rp.issueId = orp.issueId
    AND rp.asOfDate = orp.first_asOf
;

DROP TABLE IF EXISTS #unique_dates;
select convert(date,dateadd(month, -num, mn.asOf)) as asOf
INTO #unique_dates
FROM report.nums,
(select convert(date,dateadd(day, -datepart(day,getdate())+1 ,getdate())) asOf)mn
;

DROP TABLE IF EXISTS #refinance_pools_hist;
SELECT
    r.issueId, 
    t.asOf, 
    r.wwac,
    cast(NULL as numeric(8, 4)) as MtgRate
INTO #refinance_pools_hist
FROM #refinance_pools_origination r
JOIN #unique_dates t 
    ON t.asOf > r.originationDate 
    AND t.asOf <= r.asOfDate
;
COMMIT;

UPDATE #refinance_pools_hist inc SET inc.MtgRate = r.MtgRate
FROM #Mtg30YrRates_monthly r
WHERE 1=1
    AND r.asOf_lag1 = inc.asOf
    AND r.SeriesName = 'CONVENTIONAL_30YR'
;

UPDATE #refinance_pools_hist inc SET inc.MtgRate = r.MtgRate
FROM #Mtg30YrRates_monthly r
WHERE r.asOf_lag1 = (SELECT min(asOf_lag1) FROM #Mtg30YrRates_monthly WHERE SeriesName = 'CONVENTIONAL_30YR')
    AND inc.MtgRate IS NULL
;

  -- Calculate Burnout on old data
DROP TABLE IF EXISTS #Hist_Burnout;
SELECT 
    t0.issueId,
    t0.asOf as asOf,
    sum(log(CASE WHEN t1.wwac / t1.MtgRate <= 1 THEN 1 ELSE t1.wwac / t1.MtgRate END)) as burnout
INTO #Hist_Burnout
FROM #refinance_pools_hist t0
JOIN #refinance_pools_hist t1
    ON t0.issueId = t1.issueId
    AND t0.asOf >= t1.asOf
GROUP BY t0.issueId, t0.asOf
;

UPDATE #refinance_pools_origination pl SET burnout = brn.burnout
FROM #Hist_Burnout brn
WHERE pl.issueId = brn.issueId
    AND pl.asOfDate = brn.asOf
;

UPDATE #refinance_pools inc SET inc.bburnout = inc.bburnout + 100.0 * brn.burnout
FROM #refinance_pools_origination brn
WHERE inc.issueId = brn.issueId
;


  -- All Conventional Conforming Pools (FGLMC and FNCL)
DROP TABLE IF EXISTS #refinanceable;
SELECT
    asOfDate,
    100.0 * sum(CASE WHEN refi_incentive >= 50.0 THEN currentBalance ELSE 0.0 END) / sum(currentBalance) as pct_refinancible_pool
INTO #refinanceable
FROM (
    SELECT s.asOf as asOfDate, refi_incentive, currentBalance
    FROM fhl.sec p
    JOIN fhl.secFactor f
        ON p.issueId = f.issueId
        AND p.marketTicker in ('FGLMC')
    LEFT JOIN fhl.secSupp s
        ON p.issueId = s.issueId
        AND s.asOf = f.asOf
    WHERE 1=1
        AND p.collateralType = 'LOAN'
    
    UNION ALL
    
    SELECT s.asOf as asOfDate, refi_incentive, currentBalance
    FROM fnm.sec p
    JOIN fnm.secFactor f
        ON p.issueId = f.issueId
        AND p.marketTicker in ('FNCL')
    LEFT JOIN fnm.secSupp s
        ON p.issueId = s.issueId
        AND s.asOf = f.asOf
    WHERE 1=1
        AND p.collateralType = 'LOAN'
    ) t
WHERE asOFDate IS NOT NULL 
GROUP BY asOfDate
HAVING sum(currentBalance) > 0
ORDER BY asOfDate
;

