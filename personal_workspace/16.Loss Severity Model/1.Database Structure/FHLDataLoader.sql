-----------------------------------------------------------------
-- FREDDIE MAC LOAN LEVEL DATA SCRUBBING AND CONVERSION SCRIPT --
-----------------------------------------------------------------

-- Testing with Random Sample
DROP TABLE IF EXISTS #loanIDs;
SELECT loanID, NEWID() as IDX INTO #loanIDs FROM fhl.LoanLevelHistOriginationData; -- WHERE year(firstPaymtDt) IN (2004, 2005, 2006, 2007);
COMMIT;
DROP TABLE IF EXISTS #LoanSample;
SELECT top 1000000 loanID INTO #LoanSample FROM #loanIDs ORDER BY IDX;
COMMIT;

-- Field Name Mappings 

    -- channel
DROP TABLE IF EXISTS #channelMapping;
CREATE TABLE #channelMapping(
    code varchar(8),
    val  varchar(20)
)
;
INSERT #channelMapping SELECT 'R', 'RETAIL';
INSERT #channelMapping SELECT 'B', 'BROKER';
INSERT #channelMapping SELECT 'C', 'CORRES';
INSERT #channelMapping SELECT 'T', 'UNKNOWN';
COMMIT;

    -- rateType
DROP TABLE IF EXISTS #rateTypeMapping;
CREATE TABLE #rateTypeMapping(
    code varchar(8),
    val  varchar(20)
)
;
INSERT #rateTypeMapping SELECT '30', 'LIBOR';
INSERT #rateTypeMapping SELECT '70', 'FNMA/FHLMC';
COMMIT;

    -- propertyType
DROP TABLE IF EXISTS #propertyTypeMapping;
CREATE TABLE #propertyTypeMapping(
    code varchar(8),
    val  varchar(20)
)
;
INSERT #propertyTypeMapping SELECT 'SF', 'SFR';
INSERT #propertyTypeMapping SELECT 'CO', 'CONDO';
INSERT #propertyTypeMapping SELECT 'CP', 'CO-OP';
INSERT #propertyTypeMapping SELECT 'MH', 'MH';
INSERT #propertyTypeMapping SELECT 'PU', 'PUD';
INSERT #propertyTypeMapping SELECT 'LH', 'LEASEHOLD';
INSERT #propertyTypeMapping SELECT '  ', 'UNKNOWN';
COMMIT;

    -- product
DROP TABLE IF EXISTS #prodMapping;
CREATE TABLE #prodMapping(
    code varchar(8),
    val  varchar(20)
)
;
INSERT #prodMapping SELECT 'FIX30', 'FIXED30';
COMMIT;

    -- loan purpose
DROP TABLE IF EXISTS #loanPurposeMapping;
CREATE TABLE #loanPurposeMapping(
    code varchar(8),
    val  varchar(20)
)
;
INSERT #loanPurposeMapping SELECT 'P', 'PURCH';
INSERT #loanPurposeMapping SELECT 'C', 'RE-FI-CO';
INSERT #loanPurposeMapping SELECT 'R', 'RE-FI-NCO';
INSERT #loanPurposeMapping SELECT 'N', 'RE-FI-NCO';
INSERT #loanPurposeMapping SELECT 'U', 'UNKNOWN';
INSERT #loanPurposeMapping SELECT ' ', 'UNKNOWN';
COMMIT;

    -- loan type (needed for other tapes)
DROP TABLE IF EXISTS #loanTypeMapping;
CREATE TABLE #loanTypeMapping(
    code varchar(8),
    val  varchar(20)
)
;
INSERT #loanTypeMapping SELECT '1', 'CONVENTIONAL';
COMMIT;

    -- doc type
DROP TABLE IF EXISTS #docTypeMapping;
CREATE TABLE #docTypeMapping(
    code varchar(8),
    val  varchar(20)
)
;
INSERT #docTypeMapping SELECT '1', 'FULL';
INSERT #docTypeMapping SELECT '2', 'LOW';
INSERT #docTypeMapping SELECT '3', 'NONE';
COMMIT;

    -- occupancy
DROP TABLE IF EXISTS #occupancyMapping;
CREATE TABLE #occupancyMapping(
    code varchar(8),
    val  varchar(20)
)
;
INSERT #occupancyMapping SELECT 'P', 'OWNER';
INSERT #occupancyMapping SELECT 'O', 'OWNER';
INSERT #occupancyMapping SELECT 'S', '2ND';
INSERT #occupancyMapping SELECT 'I', 'INV';
INSERT #occupancyMapping SELECT 'U', 'UNKNOWN';
INSERT #occupancyMapping SELECT ' ', 'UNKNOWN';
COMMIT;

    -- zero balance code
DROP TABLE IF EXISTS #zbcMapping;
CREATE TABLE #zbcMapping(
    code varchar(8),
    val  varchar(20)
)
;
INSERT #zbcMapping SELECT '01', 'PP';
INSERT #zbcMapping SELECT '03', 'FC';
INSERT #zbcMapping SELECT '06', 'RP';
INSERT #zbcMapping SELECT '09', 'REO';
INSERT #zbcMapping SELECT '97', 'DQ';
COMMIT;

    -- zero balance code (numeric)
DROP TABLE IF EXISTS #zbcNumMapping;
CREATE TABLE #zbcNumMapping(
    code smallint,
    val  varchar(20)
)
;
INSERT #zbcNumMapping SELECT 1, 'PP';
INSERT #zbcNumMapping SELECT 3, 'FC';
INSERT #zbcNumMapping SELECT 6, 'RP';
INSERT #zbcNumMapping SELECT 9, 'REO';
INSERT #zbcNumMapping SELECT 97, 'DQ';
COMMIT;

    -- state judicial vs non-judicial
DROP TABLE IF EXISTS #stateMapping;
CREATE TABLE #stateMapping(
    code varchar(8),
    val  varchar(20),
    jud_flag char(1)
)
;
INSERT #stateMapping SELECT 'AK',  'Alaska' , 0;
INSERT #stateMapping SELECT 'AR',  'Arkansas' , 0;
INSERT #stateMapping SELECT 'AZ',  'Arizona' , 0;
INSERT #stateMapping SELECT 'CA',  'California' , 0;
INSERT #stateMapping SELECT 'CO',  'Colorado' , 0;
INSERT #stateMapping SELECT 'CT',  'Connecticut' , 1;
INSERT #stateMapping SELECT 'DC',  'Washington D.C.' , 0;
INSERT #stateMapping SELECT 'DE',  'Delaware' , 1;
INSERT #stateMapping SELECT 'FL',  'Florida' , 1;
INSERT #stateMapping SELECT 'GA',  'Georgia' , 0;
INSERT #stateMapping SELECT 'GU',  'Guam' , 0;
INSERT #stateMapping SELECT 'HI',  'Hawaii' , 0;
INSERT #stateMapping SELECT 'IA',  'Iowa' , 0;
INSERT #stateMapping SELECT 'ID',  'Idaho' , 0;
INSERT #stateMapping SELECT 'IL',  'Illinois' , 1;
INSERT #stateMapping SELECT 'IN',  'Indiana' , 1;
INSERT #stateMapping SELECT 'KS',  'Kansas' , 1;
INSERT #stateMapping SELECT 'KY',  'Kentucky' , 1;
INSERT #stateMapping SELECT 'LA',  'Louisiana' , 1;
INSERT #stateMapping SELECT 'MA',  'Massachusetts' , 1;
INSERT #stateMapping SELECT 'MD',  'Maryland' , 1;
INSERT #stateMapping SELECT 'ME',  'Maine' , 1;
INSERT #stateMapping SELECT 'MI',  'Michigan' , 0;
INSERT #stateMapping SELECT 'MN',  'Minnesota' , 0;
INSERT #stateMapping SELECT 'MO',  'Missouri' , 0;
INSERT #stateMapping SELECT 'MS',  'Mississippi' , 0;
INSERT #stateMapping SELECT 'MT',  'Montana' , 0;
INSERT #stateMapping SELECT 'NC',  'North Carolina' , 0;
INSERT #stateMapping SELECT 'ND',  'North Dakota' , 1;
INSERT #stateMapping SELECT 'NE',  'Nebraska' , 1;
INSERT #stateMapping SELECT 'NH',  'New Hampshire' , 0;
INSERT #stateMapping SELECT 'NJ',  'New Jersey' , 1;
INSERT #stateMapping SELECT 'NM',  'New Mexico' , 1;
INSERT #stateMapping SELECT 'NV',  'Nevada' , 0;
INSERT #stateMapping SELECT 'NY',  'New York' , 1;
INSERT #stateMapping SELECT 'OH',  'Ohio' , 1;
INSERT #stateMapping SELECT 'OK',  'Oklahoma' , 1;
INSERT #stateMapping SELECT 'OR',  'Oregon' , 0;
INSERT #stateMapping SELECT 'PA',  'Pennsylvania' , 1;
INSERT #stateMapping SELECT 'PR',  'Puerto Rico' , 0;
INSERT #stateMapping SELECT 'RI',  'Rhode Island' , 0;
INSERT #stateMapping SELECT 'SC',  'South Carolina' , 1;
INSERT #stateMapping SELECT 'SD',  'South Dakota' , 1;
INSERT #stateMapping SELECT 'TN',  'Tennessee' , 0;
INSERT #stateMapping SELECT 'TX',  'Texas' , 0;
INSERT #stateMapping SELECT 'UT',  'Utah' , 0;
INSERT #stateMapping SELECT 'VA',  'Virginia' , 0;
INSERT #stateMapping SELECT 'VI',  'Virgin Islands' , 0;
INSERT #stateMapping SELECT 'VT',  'Vermont' , 1;
INSERT #stateMapping SELECT 'WA',  'Washington' , 0;
INSERT #stateMapping SELECT 'WI',  'Wisconsin' , 1;
INSERT #stateMapping SELECT 'WV',  'West Virginia' , 0;
INSERT #stateMapping SELECT 'WY',  'Wyoming' , 0;
COMMIT;

--------- STATIC DATA ------------
-- Create Temporary Static Table with Payment calculation and Other derived information
DROP TABLE IF EXISTS #PIV_FMACLoanLevel_Static;
SELECT
    s.loanID as loanID,
    year(firstPaymentDate) as vintage,
    coupon as origCoupon,
    originalLoanAmount as origBalance,
    origTerm,
    cast(originalLoanAmount * ((coupon / 1200.0) + ((coupon / 1200.0) / (power(1.0 + (coupon / 1200.0), origTerm) - 1.0))) as numeric(10,4)) as origPayment,
    origLTV,
    IFNULL(cltv, origLTV, cltv) as origCLTV,
    cast(CASE WHEN origLTV IS NOT NULL THEN (origBalance / origLTV) * 100.0 ELSE NULL END as numeric(14,2)) as origValue,
    1 as lien,
    cast(CASE WHEN abs(origCLTV - origLTV) > .0001 THEN origValue * (origCLTV / 100.0) - origBalance ELSE 0.0 END as numeric(14,2)) as secondBalance,
    DTI as origDTI,
    fico as origFICO,
    NULL as origCoFICO,
    CASE WHEN pctMtgIns IS NOT NULL AND pctMtgIns > 0 THEN 1 ELSE 0 END as miFlag,
    IFNULL(pctMtgIns, 0.0, pctMtgIns) as miLevel,
    CASE WHEN firstTimeHomeBuyerFlag = '' THEN 'U' ELSE firstTimeHomeBuyerFlag END as firstTimeHomeBuyerFlag,
    numBorrowers as numberBorrowers,
    numUnits as numberUnits,
    IFNULL(lp.val, s.loanPurposeFlag, lp.val) as loanPurpose,
    IFNULL(pt.val, s.propertyType, pt.val) as propertyType,
    IFNULL(occ.val, s.occStatusFlag, occ.val) as occupancyStatus,
    IFNULL(prd.val, s.productType, prd.val) as productType,
    'CONVENTIONAL' as loanType,
    'FULL' as docType,
    prepayPenaltyFlag,
    cast(dateadd(month, -(s.origTerm), s.matDt) as date) as originationDate,
    firstPaymtDt as firstPaymentDate,
    matDt as maturityDate,
    IFNULL(ch.val, s.channel_status, ch.val) as channel,
    seller,
    CASE WHEN servicer = '' THEN 'UNKNOWN' ELSE servicer END as origServicer,
    state,
    IFNULL(st.jud_flag, '0', st.jud_flag) as judicialFlag,
    msa,
    convert(CHAR(5), cast(zipcode / 100 as integer)) as zip_3
INTO #PIV_FMACLoanLevel_Static
FROM fhl.LoanLevelHistOriginationData s
JOIN #LoanSample ls
    ON s.loanID = ls.loanID
LEFT JOIN #channelMapping ch
    ON s.channel_status = ch.code
LEFT JOIN #propertyTypeMapping pt
    ON s.propertyType = pt.code
LEFT JOIN #prodMapping prd
    ON s.productType = prd.code
LEFT JOIN #loanPurposeMapping lp
    ON s.loanPurposeFlag = lp.code
LEFT JOIN #occupancyMapping occ
    ON s.occStatusFlag = occ.code
LEFT JOIN #stateMapping st
    ON s.state = st.code
;
COMMIT;

-- Unit Test
--SELECT count(1) FROM #PIV_FMACLoanLevel_Static;
--SELECT count(1) FROM fhl.LoanLevelHistOriginationData;
-- they should be equal

-- Drop loans with bad attributes (no LTV, etc)
DELETE FROM #PIV_FMACLoanLevel_Static
WHERE origLTV IS NULL;
COMMIT;

DELETE FROM #PIV_FMACLoanLevel_Static
WHERE origCoupon IS NULL;
COMMIT;

CREATE INDEX loan_id_idx ON #PIV_FMACLoanLevel_Static(loanID);
COMMIT;

--------- DYNAMIC DATA ------------

-- Supplement data with missing REO periods
DROP TABLE IF EXISTS #unique_dates;
SELECT asOf 
INTO #unique_dates 
FROM fhl.LoanLevelHistMonthlyPerformData
GROUP BY asOf
ORDER BY asOf
;

DROP TABLE IF EXISTS #ReoLoans;
SELECT
    *,
    asOf as firstREO,
    cast(NULL as date) as lastREO 
INTO #ReoLoans
FROM fhl.LoanLevelHistMonthlyPerformData
WHERE delinqStatus = 'R'
    AND currentRpb > 0
;

UPDATE #ReoLoans r SET lastREO = f.asOf
FROM fhl.LoanLevelHistMonthlyPerformData f
WHERE r.loanId = f.loanId
    AND f.delinqStatus = 'R'
    AND f.currentRpb = 0
;

UPDATE #ReoLoans r SET lastREO = dateadd(month, 1, mx.maxAsOf)
FROM (SELECT max(asOf) as maxAsOf FROM #unique_dates) mx
WHERE lastREO IS NULL
;

DROP TABLE IF EXISTS #ReoHist;
SELECT
    r.loanId, 
    t.asOf, 
    r.currentRPB, 
    r.delinqStatus, 
    r.loanAge + datediff(month, r.firstREO, t.asOf) as loanAge, 
    r.remTerm - datediff(month, r.firstREO, t.asOf) as remTerm, 
    r.repurchaseFlag, 
    r.loanModFlag, 
    r.zeroBalanceCode, 
    r.asOfZeroBalance, 
    r.CurrentCoupon, 
    r.currentdeferredUPB, 
    r.dueDateLastPaidInstallment, 
    r.mortageInsurancerecoveries, 
    r.netSaleProceeds, 
    r.nonMortageInsurancerecoveries, 
    r.expenses
INTO #ReoHist
FROM #ReoLoans r
JOIN #unique_dates t 
    ON t.asOf > r.firstREO 
    AND t.asOf < r.lastREO
;
COMMIT;

CREATE INDEX loan_id_idx ON #ReoHist(loanID);
CREATE INDEX loan_asOf_idx ON #ReoHist(asOf);
COMMIT;


DROP TABLE IF EXISTS #LoanLevelHistMonthlyPerformData;
SELECT *
INTO #LoanLevelHistMonthlyPerformData
FROM (
    SELECT * FROM fhl.LoanLevelHistMonthlyPerformData WHERE loanID IN (SELECT loanID FROM #PIV_FMACLoanLevel_Static)
    UNION ALL
    SELECT * FROM #ReoHist WHERE loanID IN (SELECT loanID FROM #PIV_FMACLoanLevel_Static)
) o
;
COMMIT;

CREATE INDEX loan_id_idx ON #LoanLevelHistMonthlyPerformData(loanID);
CREATE INDEX loan_asOf_idx ON #LoanLevelHistMonthlyPerformData(asOf);
COMMIT;


-- Create Temporary Performance Table with From and To Columns
DROP TABLE IF EXISTS #PIV_FMACLoanLevel_Dynamic;
SELECT
    t1.loanID,
    t2.asOf as beginDate,
    --cast(dateadd(month, 1, t2.asOf) as date) as endDate, --not needed
    --datediff(month, '19890101', t2.asOf) as to_period, --LP style period, starts from arbitrary date (1989-01-01) in the past --not needed
    t1.remTerm as beginRemainingTerm,
    t2.remTerm - t1.remTerm as diffRemainingTerm,
    cast(NULL as smallint) as adjRemainingTerm, --remove later
    t1.LoanAge as beginLoanAge,
    t1.CurrentCoupon as beginCoupon,
    t2.CurrentCoupon as endCoupon, --remove later
    t2.CurrentCoupon - t1.CurrentCoupon as diffCoupon,
    t1.currentRPB as beginBalance,
	t2.currentRPB as endBalance, --remove later
    t2.currentRPB - t1.currentRPB as diffBalance,
    cast(NULL as numeric(14,4)) as beginScheduledPayment,
    cast(NULL as numeric(14,4)) as endScheduledPayment, --remove later
    cast(NULL as numeric(14,4)) as diffScheduledPayment,
    CASE 
        WHEN t1.delinqStatus IN ('-2','-1','0') THEN 'C' -- negative status treated as 'C'
        WHEN t1.delinqStatus IN ('R') THEN 'REO'
        ELSE t1.delinqStatus
    END as beginStatus,
    CASE 
        WHEN t2.zeroBalanceCode IS NOT NULL THEN 'X'
        WHEN t2.delinqStatus IN ('-2','-1','0') THEN 'C' -- negative status treated as 'C'
        WHEN t2.delinqStatus IN ('R') THEN 'REO'
        ELSE t2.delinqStatus
    END as endStatus,
    t2.zeroBalanceCode as zeroBalanceCode,
    --t2.repurchaseFlag as to_repo, -- not used
    CASE WHEN t1.loanModFlag = 'N' THEN '' ELSE t1.loanModFlag END as beginModificationFlag, --remove later
    CASE WHEN t2.loanModFlag = 'N' THEN '' ELSE t2.loanModFlag END as modificationFlag,
    cast(0 as smallint) as modificationCount,
    cast(0 as smallint) as monthsInModification,
    --t1.zeroBalanceCode as from_zbc, --not needed
    --t2.zeroBalanceCode as to_zbc, --not needed
    --cast(NULL as varchar(20)) as perfstatus_BOP, --not needed
    cast(NULL as numeric(8, 4)) as HPI, --remove later, only needed for computing hpa efficiently (will be confusing if both exist)
    cast(NULL as numeric(8, 4)) as HPA,
    --cast(NULL as numeric(14,10)) as amort_ltv, --not needed
    --cast(NULL as numeric(14,10)) as amort_cltv, --not needed
    --cast(NULL as numeric(14,10)) as mtm_ltv, --not needed
    --cast(NULL as numeric(14,10)) as mtm_cltv, --not needed
    --cast(NULL as numeric(8, 4)) as fhl30_lag2, --not needed
    --cast(NULL as numeric(8, 4)) as fhl30_chg, --not needed
    cast(0 as smallint) as countNonCurrent,
    cast(0 as smallint) as ageSinceLastCurrent,
    cast(0 as smallint) as ageSinceLastDelinquent
    --cast(0 as smallint) as nb_since_3, --not needed
    --cast(0 as smallint) as nb_since_6, --not needed
    --cast(0 as smallint) as nb_since_9 --not needed
INTO #PIV_FMACLoanLevel_Dynamic
FROM #LoanLevelHistMonthlyPerformData t1
JOIN #LoanLevelHistMonthlyPerformData t2
    ON t1.loanID = t2.loanID
    AND t1.asOf = dateadd(month, -1, t2.asOf)
JOIN #PIV_FMACLoanLevel_Static orig
    ON orig.loanID = t1.loanID
LEFT JOIN #zbcNumMapping zbc
    ON t2.zeroBalanceCode = zbc.code
;
COMMIT;

CREATE INDEX loan_id_idx ON #PIV_FMACLoanLevel_Dynamic(loanID);
CREATE INDEX loan_beginDate_idx ON #PIV_FMACLoanLevel_Dynamic(beginDate);
COMMIT;


-- Fix some bad data for the last REO period
UPDATE #PIV_FMACLoanLevel_Dynamic SET diffRemainingTerm = -1, endCoupon = beginCoupon, diffCoupon = 0.0
WHERE beginStatus = 'REO' AND endStatus = 'X'
;

-- Remove any data after a termination
DROP TABLE IF EXISTS #TerminatedLoans;
SELECT
    loanID,
    count(1) as NbTerms,
    min(beginDate) as min_term_dt
INTO #TerminatedLoans
FROM #PIV_FMACLoanLevel_Dynamic
WHERE zeroBalanceCode IS NOT NULL
GROUP BY loanID
;
COMMIT;

CREATE INDEX loan_id_idx ON #TerminatedLoans(loanID);
COMMIT;

DELETE FROM #PIV_FMACLoanLevel_Dynamic
FROM #PIV_FMACLoanLevel_Dynamic perf, #TerminatedLoans mt
WHERE perf.loanID = mt.loanID
    AND perf.beginDate > mt.min_term_dt
;

-- Align Static and Dynamic tables with same loans
DELETE FROM #PIV_FMACLoanLevel_Dynamic
WHERE loanID NOT IN (SELECT distinct loanID FROM #PIV_FMACLoanLevel_Static);
COMMIT;

DELETE FROM #PIV_FMACLoanLevel_Static
WHERE loanID NOT IN (SELECT distinct loanID FROM #PIV_FMACLoanLevel_Dynamic);
COMMIT;

-- Unit Test
--SELECT count(distinct loanID) FROM #PIV_FMACLoanLevel_Static;
--SELECT count(distinct loanID) FROM #PIV_FMACLoanLevel_Dynamic;
-- they should be equal
--SELECT beginStatus, endStatus, zeroBalanceCode, count(1) FROM #PIV_FMACLoanLevel_Dynamic GROUP BY beginStatus, endStatus, zeroBalanceCode ORDER BY 1 ,2 ,3;


-- Update the LoanAge Column
UPDATE #PIV_FMACLoanLevel_Dynamic SET beginLoanAge = 0 WHERE beginLoanAge < 0;

-- Update beginBalance
UPDATE #PIV_FMACLoanLevel_Dynamic perf 
SET beginBalance = s.origPayment / ((beginCoupon / 1200.0) + ((beginCoupon / 1200.0)/(power(1.0 + (beginCoupon / 1200.0), (CASE WHEN beginRemainingTerm IS NOT NULL THEN beginRemainingTerm ELSE adjRemainingTerm END)) - 1.0)))
FROM #PIV_FMACLoanLevel_Static s
WHERE perf.loanID = s.loanID 
    AND (perf.beginBalance IS NULL OR (perf.beginBalance = 0 AND beginStatus <> 'X'))
;

-- Update endBalance 
  -- from beginBalance
UPDATE #PIV_FMACLoanLevel_Dynamic p1 SET p1.endBalance = p2.beginBalance
FROM #PIV_FMACLoanLevel_Dynamic p2
WHERE p1.loanID = p2.loanID
    AND p1.beginDate = dateadd(month, -1, p2.beginDate)
    AND p1.endBalance IS NULL
;
  -- from formula
UPDATE #PIV_FMACLoanLevel_Dynamic perf 
SET endBalance = s.origPayment / ((beginCoupon / 1200.0) + ((beginCoupon / 1200.0)/(power(1.0 + (beginCoupon / 1200.0), (CASE WHEN beginRemainingTerm IS NOT NULL THEN beginRemainingTerm ELSE adjRemainingTerm END - 1)) - 1.0)))
FROM #PIV_FMACLoanLevel_Static s
WHERE perf.loanID = s.loanID 
    AND (perf.endBalance IS NULL OR (perf.endBalance = 0 AND endStatus <> 'X'))
;

-- Update corner case balances
UPDATE #PIV_FMACLoanLevel_Dynamic perf SET beginBalance = endBalance WHERE beginBalance IS NULL OR perf.diffBalance < -200000000;
UPDATE #PIV_FMACLoanLevel_Dynamic perf SET endBalance = beginBalance WHERE endBalance IS NULL OR perf.diffBalance > 200000000;

-- Update diffBalance
UPDATE #PIV_FMACLoanLevel_Dynamic SET diffBalance = endBalance - beginBalance
WHERE diffBalance IS NULL
;

-- Update beginCoupon and endCoupon
--SELECT * FROM #PIV_FMACLoanLevel_Dynamic where loanid = 'F103Q1009237';
DROP TABLE IF EXISTS #LoanCoupons;
SELECT distinct
    orig.loanID as loanID,
    origCoupon,
    beginCoupon,
    endCoupon,
    CASE WHEN origCoupon = beginCoupon AND beginCoupon = endCoupon THEN 'Y' ELSE 'N' END as Valid
INTO #LoanCoupons
FROM #PIV_FMACLoanLevel_Static orig
JOIN #PIV_FMACLoanLevel_Dynamic perf
    ON orig.loanID = perf.loanID
WHERE orig.loanID IN (SELECT distinct loanID FROM #PIV_FMACLoanLevel_Dynamic WHERE beginCoupon IS NULL or endCoupon IS NULL)
    AND perf.beginCoupon IS NOT NULL
    AND perf.endCoupon IS NOT NULL
;

UPDATE #PIV_FMACLoanLevel_Dynamic perf 
SET perf.beginCoupon = lc.origCoupon,
    perf.endCoupon = lc.origCoupon
FROM #LoanCoupons lc
WHERE perf.loanID = lc.loanID
    AND lc.Valid = 'Y'
    AND (perf.beginCoupon IS NULL OR perf.endCoupon IS NULL)
;

UPDATE #PIV_FMACLoanLevel_Dynamic perf SET endCoupon = beginCoupon WHERE endCoupon = 0 AND endStatus = 'X'
;

UPDATE #PIV_FMACLoanLevel_Dynamic SET diffCoupon = endCoupon - beginCoupon WHERE diffCoupon IS NULL
;

-- Update Scheduled Payments
UPDATE #PIV_FMACLoanLevel_Dynamic perf SET beginScheduledPayment = CASE WHEN beginCoupon <> 0 THEN orig.origBalance * ((beginCoupon / 1200.0) + ((beginCoupon / 1200.0) / (power(1.0 + (beginCoupon / 1200.0), orig.origTerm) - 1.0))) ELSE 0.0 END
FROM #PIV_FMACLoanLevel_Static orig
WHERE perf.loanID = orig.loanID
;

UPDATE #PIV_FMACLoanLevel_Dynamic perf SET perf.endScheduledPayment = perf2.beginScheduledPayment
FROM #PIV_FMACLoanLevel_Dynamic perf2
WHERE perf.loanID = perf2.loanID AND perf.beginDate = dateadd(month, -1, perf2.beginDate)
;

UPDATE #PIV_FMACLoanLevel_Dynamic perf SET endScheduledPayment = CASE WHEN endCoupon <> 0 THEN orig.origBalance * ((endCoupon / 1200.0) + ((endCoupon / 1200.0) / (power(1.0 + (endCoupon / 1200.0), orig.origTerm) - 1.0))) ELSE 0.0 END
FROM #PIV_FMACLoanLevel_Static orig
WHERE perf.loanID = orig.loanID
    AND perf.endScheduledPayment IS NULL
;

UPDATE #PIV_FMACLoanLevel_Dynamic SET diffScheduledPayment = endScheduledPayment - beginScheduledPayment
;

-- Unit Test 
--SELECT loanID, beginDate, count(1) as Cnt FROM #PIV_FMACLoanLevel_Dynamic GROUP BY loanID, beginDate HAVING Cnt > 1;
-- should return 0 rows

-- Update countNonCurrent
DROP TABLE IF EXISTS #LoanLevelHistMonthlyPerformData_countNonCurrent;
SELECT
	t2.loanID as loanID,
    t2.beginDate as beginDate,
	sum(CASE WHEN t1.beginStatus <> 'C' THEN 1.0 ELSE 0.0 END) as countNonCurrent
INTO #LoanLevelHistMonthlyPerformData_countNonCurrent
FROM #PIV_FMACLoanLevel_Dynamic t1
JOIN #PIV_FMACLoanLevel_Dynamic t2
	ON t1.loanID = t2.loanID
	AND t1.beginDate <= t2.beginDate
GROUP BY t2.loanID, t2.beginDate
;
COMMIT;

CREATE INDEX loan_id_idx ON #LoanLevelHistMonthlyPerformData_countNonCurrent(loanID);
CREATE INDEX loan_beginDate_idx ON #LoanLevelHistMonthlyPerformData_countNonCurrent(beginDate);
COMMIT;

UPDATE #PIV_FMACLoanLevel_Dynamic p1 SET p1.countNonCurrent = p2.countNonCurrent
FROM #LoanLevelHistMonthlyPerformData_countNonCurrent p2
WHERE p1.loanID = p2.loanID 
    AND p1.beginDate = p2.beginDate
    AND p2.countNonCurrent IS NOT NULL
;

-- Update ageSinceLastCurrent
   -- Update all Delq loans
DROP TABLE IF EXISTS #LoanLevelHistMonthlyPerformData_ageSinceLastCurrent;
SELECT
    t1.loanID as loanID,
    t1.beginDate as beginDate,
    min(datediff(month, cur.beginDate, t1.beginDate)) as ageSinceLastCurrent
INTO #LoanLevelHistMonthlyPerformData_ageSinceLastCurrent
FROM #PIV_FMACLoanLevel_Dynamic t1
LEFT JOIN 
(
    SELECT
    	loanID,
        beginDate
    FROM #PIV_FMACLoanLevel_Dynamic
    WHERE beginStatus = 'C'
) cur
    ON t1.loanID = cur.loanID
    AND t1.beginDate > cur.beginDate
WHERE t1.beginStatus <> 'C'
GROUP BY t1.loanID, t1.beginDate
;
COMMIT;

CREATE INDEX loan_id_idx ON #LoanLevelHistMonthlyPerformData_ageSinceLastCurrent(loanID);
CREATE INDEX loan_beginDate_idx ON #LoanLevelHistMonthlyPerformData_ageSinceLastCurrent(beginDate);
COMMIT;

UPDATE #PIV_FMACLoanLevel_Dynamic p1 SET p1.ageSinceLastCurrent = p2.ageSinceLastCurrent
FROM #LoanLevelHistMonthlyPerformData_ageSinceLastCurrent p2
WHERE p1.loanID = p2.loanID 
    AND p1.beginDate = p2.beginDate
    AND p2.ageSinceLastCurrent IS NOT NULL
;

-- Update ageSinceLastDelinquent
   -- Update all Current loans
DROP TABLE IF EXISTS #LoanLevelHistMonthlyPerformData_ageSinceLastDelinquent;
SELECT
    t1.loanID as loanID,
    t1.beginDate as beginDate,
    min(datediff(month, delq.beginDate, t1.beginDate)) as ageSinceLastDelinquent
INTO #LoanLevelHistMonthlyPerformData_ageSinceLastDelinquent
FROM #PIV_FMACLoanLevel_Dynamic t1
LEFT JOIN 
(
    SELECT
    	loanID,
        beginDate
    FROM #PIV_FMACLoanLevel_Dynamic
    WHERE beginStatus <> 'C'
) delq
    ON t1.loanID = delq.loanID
    AND t1.beginDate > delq.beginDate
WHERE t1.beginStatus = 'C'
GROUP BY t1.loanID, t1.beginDate
;
COMMIT;

CREATE INDEX loan_id_idx ON #LoanLevelHistMonthlyPerformData_ageSinceLastDelinquent(loanID);
CREATE INDEX loan_beginDate_idx ON #LoanLevelHistMonthlyPerformData_ageSinceLastDelinquent(beginDate);
COMMIT;

UPDATE #PIV_FMACLoanLevel_Dynamic p1 SET p1.ageSinceLastDelinquent = p2.ageSinceLastDelinquent
FROM #LoanLevelHistMonthlyPerformData_ageSinceLastDelinquent p2
WHERE p1.loanID = p2.loanID 
    AND p1.beginDate = p2.beginDate
    AND p2.ageSinceLastDelinquent IS NOT NULL
;

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
    NSAIndex
INTO #HomePriceIndex_temp1
FROM hpi.HomePriceIndex
WHERE TransactionType = 'ALL_TRANSACTIONS'
    AND loadQuarter = (SELECT max(loadQuarter) FROM hpi.HomePriceIndex)
    AND RegionType IN ('MSA','STATE','STATE_NONMSA','US_AND_CENSUS')
;
COMMIT;

DROP TABLE IF EXISTS #HomePriceIndex_norm;
SELECT
    t1.RegionType,
    t1.Region,
    t1.MSACode,
    t1.asOf as beginDate,
    t2.asOf as endDate,
    t1.NSAIndex as from_Idx,
    t2.NSAIndex as to_Idx,
    t1.NSAIndex + (t2.NSAIndex - t1.NSAIndex) / 3.0 as interp1,
    t1.NSAIndex + 2 * (t2.NSAIndex - t1.NSAIndex) / 3.0 as interp2
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
        ELSE t1.NSAIndex 
    END as NSAIndex
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

-- Add HPA and HPA Adjusted CLTV

   -- (MSA First)
    -- Create temp Static HPI at Origination
DROP TABLE IF EXISTS #LoanLevelHistOriginationData_hpi;
SELECT
    s.loanID,
    hpi.NSAIndex as hpi
INTO #LoanLevelHistOriginationData_hpi
FROM #PIV_FMACLoanLevel_Static s
LEFT JOIN #HomePriceIndex_monthly hpi
    ON s.originationDate = hpi.asOf
    AND s.msa = hpi.MSACode
    AND hpi.RegionType = 'MSA'
;
COMMIT;

CREATE INDEX loan_loanid_idx ON #LoanLevelHistOriginationData_hpi(loanID);
COMMIT;

    -- Update Dynamic HPI at Current Date
UPDATE #PIV_FMACLoanLevel_Dynamic perf SET perf.HPI = hpi.NSAIndex
FROM #PIV_FMACLoanLevel_Static s
LEFT JOIN #HomePriceIndex_monthly hpi
    ON s.msa = hpi.MSACode
    AND hpi.RegionType = 'MSA'
WHERE perf.loanID = s.loanID AND perf.beginDate = hpi.asOf
;

   -- Update HPA
UPDATE #PIV_FMACLoanLevel_Dynamic perf SET perf.HPA = CASE WHEN perf.HPI IS NOT NULL AND s.hpi IS NOT NULL THEN perf.HPI / s.hpi ELSE NULL END
FROM #LoanLevelHistOriginationData_hpi s
WHERE perf.loanID = s.loanID
;

   -- (Non Metro State Second)
DROP TABLE IF EXISTS #LoanLevelHistOriginationData_hpi;
SELECT
    s.loanID,
    hpi.NSAIndex as hpi
INTO #LoanLevelHistOriginationData_hpi
FROM #PIV_FMACLoanLevel_Static s
LEFT JOIN #HomePriceIndex_monthly hpi
    ON s.originationDate = hpi.asOf
    AND s.state = hpi.Region
    AND hpi.RegionType = 'STATE_NONMSAMSA'
;
COMMIT;

CREATE INDEX loan_loanid_idx ON #LoanLevelHistOriginationData_hpi(loanID);
COMMIT;

    -- Update Dynamic HPI at Current Date
UPDATE #PIV_FMACLoanLevel_Dynamic perf SET perf.HPI = hpi.NSAIndex
FROM #PIV_FMACLoanLevel_Static s
LEFT JOIN #HomePriceIndex_monthly hpi
    ON s.state = hpi.Region
    AND hpi.RegionType = 'STATE_NONMSAMSA'
WHERE perf.HPA IS NULL AND perf.loanID = s.loanID AND perf.beginDate = hpi.asOf
;

   -- Update HPA
UPDATE #PIV_FMACLoanLevel_Dynamic perf SET perf.HPA = CASE WHEN perf.HPI IS NOT NULL AND s.hpi IS NOT NULL THEN perf.HPI / s.hpi ELSE NULL END
FROM #LoanLevelHistOriginationData_hpi s
WHERE perf.HPA IS NULL AND perf.loanID = s.loanID
;

   -- (State Third)
DROP TABLE IF EXISTS #LoanLevelHistOriginationData_hpi;
SELECT
    s.loanID,
    hpi.NSAIndex as hpi
INTO #LoanLevelHistOriginationData_hpi
FROM #PIV_FMACLoanLevel_Static s
LEFT JOIN #HomePriceIndex_monthly hpi
    ON s.originationDate = hpi.asOf
    AND s.state = hpi.Region
    AND hpi.RegionType = 'STATE'
;
COMMIT;

CREATE INDEX loan_loanid_idx ON #LoanLevelHistOriginationData_hpi(loanID);
COMMIT;

    -- Update Dynamic HPI at Current Date
UPDATE #PIV_FMACLoanLevel_Dynamic perf SET perf.HPI = hpi.NSAIndex
FROM #PIV_FMACLoanLevel_Static s
LEFT JOIN #HomePriceIndex_monthly hpi
    ON s.state = hpi.Region
    AND hpi.RegionType = 'STATE'
WHERE perf.HPA IS NULL AND perf.loanID = s.loanID AND perf.beginDate = hpi.asOf
;

   -- Update HPA
UPDATE #PIV_FMACLoanLevel_Dynamic perf SET perf.HPA = CASE WHEN perf.HPI IS NOT NULL AND s.hpi IS NOT NULL THEN perf.HPI / s.hpi ELSE NULL END
FROM #LoanLevelHistOriginationData_hpi s
WHERE perf.HPA IS NULL AND perf.loanID = s.loanID
;

-- TODO: Find out Missing Data for VI
   -- (USA Last)
DROP TABLE IF EXISTS #LoanLevelHistOriginationData_hpi;
SELECT
    s.loanID,
    hpi.NSAIndex as hpi
INTO #LoanLevelHistOriginationData_hpi
FROM #PIV_FMACLoanLevel_Static s
LEFT JOIN #HomePriceIndex_monthly hpi
    ON s.originationDate = hpi.asOf
    AND hpi.Region = 'USA'
    AND hpi.RegionType = 'US_AND_CENSUS'
;
COMMIT;

CREATE INDEX loan_loanid_idx ON #LoanLevelHistOriginationData_hpi(loanID);
COMMIT;

    -- Update Dynamic HPI at Current Date
UPDATE #PIV_FMACLoanLevel_Dynamic perf SET perf.HPI = hpi.NSAIndex
FROM #PIV_FMACLoanLevel_Static s
LEFT JOIN #HomePriceIndex_monthly hpi
    ON hpi.Region = 'USA'
    AND hpi.RegionType = 'US_AND_CENSUS'
WHERE perf.HPA IS NULL AND perf.loanID = s.loanID AND perf.beginDate = hpi.asOf
;

   -- Update HPA
UPDATE #PIV_FMACLoanLevel_Dynamic perf SET perf.HPA = CASE WHEN perf.HPI IS NOT NULL AND s.hpi IS NOT NULL THEN perf.HPI / s.hpi ELSE NULL END
FROM #LoanLevelHistOriginationData_hpi s
WHERE perf.HPA IS NULL AND perf.loanID = s.loanID
;


-- Update Mods Data (Change to 1 time indicator)
-- Should effect Fannie Data only
UPDATE #PIV_FMACLoanLevel_Dynamic 
SET beginModificationFlag = '',
    modificationFlag = ''
WHERE beginModificationFlag = 'Y' AND modificationFlag = 'Y'
;

-- Update modificationCount
   -- Update all Current loans
DROP TABLE IF EXISTS #LoanLevelHistMonthlyPerformData_modificationCount;
SELECT
	t2.loanID as loanID,
    t2.beginDate as beginDate,
	sum(CASE WHEN t1.modificationFlag = 'Y' THEN 1.0 ELSE 0.0 END) as modificationCount
INTO #LoanLevelHistMonthlyPerformData_modificationCount
FROM #PIV_FMACLoanLevel_Dynamic t1
JOIN #PIV_FMACLoanLevel_Dynamic t2
	ON t1.loanID = t2.loanID
	AND t1.beginDate < t2.beginDate
GROUP BY t2.loanID, t2.beginDate
;
COMMIT;

CREATE INDEX loan_id_idx ON #LoanLevelHistMonthlyPerformData_modificationCount(loanID);
CREATE INDEX loan_beginDate_idx ON #LoanLevelHistMonthlyPerformData_modificationCount(beginDate);
COMMIT;

UPDATE #PIV_FMACLoanLevel_Dynamic p1 SET p1.modificationCount = p2.modificationCount
FROM #LoanLevelHistMonthlyPerformData_modificationCount p2
WHERE p1.loanID = p2.loanID 
    AND p1.beginDate = p2.beginDate
    AND p2.modificationCount IS NOT NULL
;

-- Update monthsInModification
   -- Update all Non Mod loans
DROP TABLE IF EXISTS #LoanLevelHistMonthlyPerformData_monthsInModification;
SELECT
    t1.loanID as loanID,
    t1.beginDate as beginDate,
    min(datediff(month, t2.beginDate, t1.beginDate)) as monthsInModification
INTO #LoanLevelHistMonthlyPerformData_monthsInModification
FROM #PIV_FMACLoanLevel_Dynamic t1
LEFT JOIN 
(
    SELECT
    	loanID,
        beginDate
    FROM #PIV_FMACLoanLevel_Dynamic
    WHERE modificationFlag = 'Y'
) t2
    ON t1.loanID = t2.loanID
    AND t1.beginDate > t2.beginDate
WHERE t1.modificationFlag <> 'Y'
GROUP BY t1.loanID, t1.beginDate
;
COMMIT;

CREATE INDEX loan_id_idx ON #LoanLevelHistMonthlyPerformData_monthsInModification(loanID);
CREATE INDEX loan_beginDate_idx ON #LoanLevelHistMonthlyPerformData_monthsInModification(beginDate);
COMMIT;

UPDATE #PIV_FMACLoanLevel_Dynamic p1 SET p1.monthsInModification = p2.monthsInModification
FROM #LoanLevelHistMonthlyPerformData_monthsInModification p2
WHERE p1.loanID = p2.loanID 
    AND p1.beginDate = p2.beginDate
    AND p2.monthsInModification IS NOT NULL
;

-- Unit Test
--SELECT count(distinct loanID) FROM #PIV_FMACLoanLevel_Static;
--SELECT count(distinct loanID) FROM #PIV_FMACLoanLevel_Dynamic;
-- they should be equal


--------- LOSS DATA ------------

-- Create Temporary Loss Table
DROP TABLE IF EXISTS #PIV_FMACLoanLevel_Loss;
SELECT 
    orig.loanID,
    loss.asOf as beginDate,
    perf.beginBalance as beginBalance,
    perf.beginStatus as beginStatus,
    loss.zeroBalanceCode,
    loss.currentDeferredUPB,
    loss.dueDateLastPaidInstallment as lastPaymentDate,
    loss.mortageInsuranceRecoveries as MIRecoveries,
    loss.netSaleProceeds,
    loss.nonMortageInsuranceRecoveries as nonMIRecoveries,
    loss.expenses
INTO #PIV_FMACLoanLevel_Loss
FROM #PIV_FMACLoanLevel_Static orig
JOIN #PIV_FMACLoanLevel_Dynamic perf
    ON orig.loanID = perf.loanID
JOIN fhl.LoanLevelHistMonthlyPerformData loss
    ON perf.loanID = loss.loanID
    AND perf.beginDate = loss.asOf
WHERE loss.zeroBalanceCode IN (3,9)
;
COMMIT;

CREATE INDEX loan_id_idx ON #PIV_FMACLoanLevel_Loss(loanID);
COMMIT;


-- Testing
--SELECT * FROM #PIV_FMACLoanLevel_Static;
--SELECT miLevel as grp, count(1) from #PIV_FMACLoanLevel_Static GROUP BY grp ORDER BY 2 DESC;
--SELECT count(1) as Cnt FROM #PIV_FMACLoanLevel_Static WHERE origLTV < 80 AND miLevel > 0;
--SELECT * FROM #PIV_FMACLoanLevel_Static WHERE origLTV < 80 AND miLevel > 0;

--SELECT count(1) as Cnt FROM #PIV_FMACLoanLevel_Static WHERE origLTV > 85 and origLTV = origCLTV AND miLevel = 0;
--SELECT * FROM #PIV_FMACLoanLevel_Static WHERE origLTV > 85 and origLTV = origCLTV AND miLevel = 0;

--SELECT 
--    CASE 
--        WHEN miLevel = 12 THEN 'mi_12'
--        WHEN miLevel = 17 THEN 'mi_17'
--        WHEN miLevel = 18 THEN 'mi_18'
--        WHEN miLevel = 20 THEN 'mi_20'
--        WHEN miLevel = 25 THEN 'mi_25'
--        WHEN miLevel = 30 THEN 'mi_30'
--        WHEN miLevel = 35 THEN 'mi_35'
--    END as grp,
--    count(1) as Cnt,
--    avg(origLTV) as avg_OLTV
--FROM #PIV_FMACLoanLevel_Static
--WHERE miLevel > 0
--GROUP BY grp
--HAVING grp IS NOT NULL
--;

--select currentDeferredUPB as grp, count(1) as cnt FROM #PIV_FMACLoanLevel_Loss group by grp;
--select loanID FROM #PIV_FMACLoanLevel_Loss  where currentDeferredUPB > 0;
--select * from #PIV_FMACLoanLevel_Dynamic WHERE loanID = 'F102Q4122448';
--select * from #PIV_FMACLoanLevel_Loss WHERE loanID = 'F102Q4122448';

--SELECT loanID, MIRecoveries, beginBalance - netSaleProceeds + expenses + 
--FROM #PIV_FMACLoanLevel_Loss
--WHERE beginStatus = 'REO'
--;


SELECT 
    orig.loanID,
    orig.state,
    perf.beginCoupon,
    orig.origValue * perf.HPA as currentValue,
    perf.beginBalance,
    loss.expenses,
    loss.netSaleProceeds,
    loss.lastPaymentDate,
    datediff(month, loss.lastPaymentDate, perf.beginDate) as timeDQ
FROM #PIV_FMACLoanLevel_Static orig
JOIN #PIV_FMACLoanLevel_Dynamic perf
    ON orig.loanID = perf.loanID
LEFT JOIN #PIV_FMACLoanLevel_Loss loss
    ON orig.loanID = loss.loanID
WHERE 1=1
    AND perf.zeroBalanceCode IN (3, 9)
    --AND orig.loanID = 'F102Q4122448'
;


----- Insert Data into Permanent Tables ---

---- Static
--DELETE FROM fhl.PIV_CreditOrigination;
--COMMIT;

--INSERT INTO fhl.PIV_CreditOrigination
--SELECT * FROM #PIV_FMACLoanLevel_static;
--COMMIT;

---- Loss
--DELETE FROM fhl.PIV_CreditLossHist;
--COMMIT;

--INSERT INTO fhl.PIV_CreditLossHist
--SELECT * FROM #PIV_FMACLoanLevel_loss;
--COMMIT;

---- Dynamic
--DELETE FROM fhl.PIV_CreditPerformanceHist;
--COMMIT;

--INSERT INTO fhl.PIV_CreditPerformanceHist (
--    loanID,
--    beginDate,
--    beginLoanAge,
--    beginCoupon,
--    diffCoupon,
--    beginBalance,
--    diffBalance,
--    beginScheduledPayment,
--    diffScheduledPayment,
--    beginStatus,
--    endStatus,
--	zeroBalanceCode,
--    modificationFlag,
--    modificationCount,
--    monthsInModification,
--    HPA,
--    countNonCurrent,
--    ageSinceLastCurrent,
--    ageSinceLastDelinquent,
--    beginRemainingTerm,
--    diffRemainingTerm
--)
--SELECT
--    loanID,
--    beginDate,
--    beginLoanAge,
--    beginCoupon,
--    diffCoupon,
--    beginBalance,
--    diffBalance,
--    beginScheduledPayment,
--    diffScheduledPayment,
--    beginStatus,
--    endStatus,
--	zeroBalanceCode,
--	modificationFlag,
--    modificationCount,
--    monthsInModification,
--    HPA,
--    countNonCurrent,
--    ageSinceLastCurrent,
--    ageSinceLastDelinquent,
--    beginRemainingTerm,
--    diffRemainingTerm
--FROM #PIV_FMACLoanLevel_Dynamic
--;
--COMMIT;

--DROP TABLE #PIV_FMACLoanLevel_static;
--DROP TABLE #PIV_FMACLoanLevel_loss;
--DROP TABLE #PIV_FMACLoanLevel_Dynamic;


SELECT 
    orig.loanID,
    orig.state,
    perf.beginCoupon,
    orig.origValue * perf.HPA as currentValue,
    perf.beginBalance,
    loss.expenses,
    loss.netSaleProceeds,
    loss.lastPaymentDate,
    datediff(month, loss.lastPaymentDate, perf.beginDate) as timeDQ
FROM #PIV_FMACLoanLevel_Static orig
JOIN #PIV_FMACLoanLevel_Dynamic perf
    ON orig.loanID = perf.loanID
LEFT JOIN #PIV_FMACLoanLevel_Loss loss
    ON orig.loanID = loss.loanID
WHERE 1=1
    AND perf.zeroBalanceCode IN (3, 9)





SELECT 
    orig.loanID,
    orig.state,
    perf.beginCoupon,
    convert(decimal(16,2),round(orig.origValue * perf.HPA,2)) as currentValue,
    --orig.origValue,
    perf.beginBalance UPB,
    loss.expenses,
    loss.netSaleProceeds,
    loss.lastPaymentDate,
    datediff(month, loss.lastPaymentDate, perf.beginDate) as timeDQ,
    ActuralLoss = convert(decimal(16,2),round(perf.beginBalance - cast(loss.netSaleProceeds as double) - loss.expenses + (timeDQ * perf.beginBalance * 30/360 * (perf.endcoupon - 0.25)/100) - loss.MIRecoveries - loss.nonMIRecoveries,2)),
    orig.JudicialFlag
FROM #PIV_FMACLoanLevel_Static orig
JOIN #PIV_FMACLoanLevel_Dynamic perf
    ON orig.loanID = perf.loanID
LEFT JOIN #PIV_FMACLoanLevel_Loss loss
    ON orig.loanID = loss.loanID
WHERE 1=1
    AND perf.zeroBalanceCode IN (3, 9)
    AND loss.netSaleProceeds != 'C'



-------------------------- Expenses on States------------------
SELECT 
    orig.state,
    --ExpensesPct = convert(decimal(16,2),round(sum(-loss.expenses / perf.beginBalance * perf.beginBalance) / sum(perf.beginBalance) * 100,2))
    timeDQ = convert(decimal(16,2),round(sum(datediff(month, loss.lastPaymentDate, perf.beginDate) * perf.beginBalance) / sum(perf.beginBalance),2))
FROM #PIV_FMACLoanLevel_Static orig
JOIN #PIV_FMACLoanLevel_Dynamic perf
    ON orig.loanID = perf.loanID
LEFT JOIN #PIV_FMACLoanLevel_Loss loss
    ON orig.loanID = loss.loanID
WHERE 1=1
    AND perf.zeroBalanceCode IN (3, 9)
    AND loss.netSaleProceeds != 'C'
Group by orig.state
Order by timeDQ



-------------------------- Expenses on States------------------
SELECT 
    --perf.beginBalance,
    BalanceBucket =    (case when perf.beginBalance < 100000 then '100000'
                    when perf.beginBalance < 200000 then '200000'
                    when perf.beginBalance < 300000 then '300000'
                    when perf.beginBalance < 400000 then '400000'
                    when perf.beginBalance < 500000 then '500000'
                    when perf.beginBalance < 600000 then '600000'
                    when perf.beginBalance < 700000 then '700000'
                    when perf.beginBalance < 800000 then '800000'
                    when perf.beginBalance < 900000 then '900000'
                    when perf.beginBalance < 1000000 then '1000000'
		            else '1000000' end),
    --ExpensesPct = convert(decimal(16,2),round(sum(-loss.expenses / perf.beginBalance * perf.beginBalance) / sum(perf.beginBalance) * 100,2))
    timeDQ = convert(decimal(16,2),round(sum(datediff(month, loss.lastPaymentDate, perf.beginDate) * perf.beginBalance) / sum(perf.beginBalance),2))
FROM #PIV_FMACLoanLevel_Static orig
JOIN #PIV_FMACLoanLevel_Dynamic perf
    ON orig.loanID = perf.loanID
LEFT JOIN #PIV_FMACLoanLevel_Loss loss
    ON orig.loanID = loss.loanID
WHERE 1=1
    AND perf.zeroBalanceCode IN (3, 9)
    --AND loss.netSaleProceeds != 'C'
Group by BalanceBucket
Order by timeDQ



-------------------------- Price Discount on States------------------
SELECT 
    orig.state,
    --ExpensesPct = convert(decimal(16,2),round(sum(-loss.expenses / perf.beginBalance * perf.beginBalance) / sum(perf.beginBalance) * 100,2))
    UPpct = convert(decimal(16,2),round(sum(perf.beginBalance) / sum(orig.origValue * perf.HPA)*100,2)),
    DiscountPct = convert(decimal(16,2),round(sum(cast(loss.netSaleProceeds as double)) / sum(orig.origValue * perf.HPA)*100,2)),
    orig.JudicialFlag
FROM #PIV_FMACLoanLevel_Static orig
JOIN #PIV_FMACLoanLevel_Dynamic perf
    ON orig.loanID = perf.loanID
LEFT JOIN #PIV_FMACLoanLevel_Loss loss
    ON orig.loanID = loss.loanID
WHERE 1=1
    AND perf.zeroBalanceCode IN (3, 9)
    AND loss.netSaleProceeds != 'C'
Group by orig.state,
Order by DiscountPct

SELECT 
    --orig.state,
    --ExpensesPct = convert(decimal(16,2),round(sum(-loss.expenses / perf.beginBalance * perf.beginBalance) / sum(perf.beginBalance) * 100,2))
    UPpct = convert(decimal(16,2),round(sum(perf.beginBalance) / sum(orig.origValue * perf.HPA)*100,2)),
    DiscountPct = convert(decimal(16,2),round(sum(cast(loss.netSaleProceeds as double)) / sum(orig.origValue * perf.HPA)*100,2)),
    orig.JudicialFlag
FROM #PIV_FMACLoanLevel_Static orig
JOIN #PIV_FMACLoanLevel_Dynamic perf
    ON orig.loanID = perf.loanID
LEFT JOIN #PIV_FMACLoanLevel_Loss loss
    ON orig.loanID = loss.loanID
WHERE 1=1
    AND perf.zeroBalanceCode IN (3, 9)
    AND loss.netSaleProceeds != 'C'
Group by orig.JudicialFlag -- orig.state,
Order by orig.JudicialFlag



-------------------------- Haircut Regression ------------------

SELECT 
    orig.loanID,
    --year(loss.begindate) as year,
    loss.begindate,
    perf.beginLoanAge,
    orig.JudicialFlag,
    orig.origbalance,
    orig.loanpurpose,
    orig.occupancyStatus,
    orig.propertyType,
    perf.beginCoupon,
    convert(decimal(16,2),round(orig.origValue * perf.HPA,2)) as currentValue,
    perf.beginBalance UPB,
    loss.expenses,
    netSaleProceeds = cast(loss.netSaleProceeds as double),
    datediff(month, loss.lastPaymentDate, perf.beginDate) as timeDQ,
    DiscountPct = convert(decimal(16,2),round(cast(loss.netSaleProceeds as double) / (orig.origValue * perf.HPA)*100,2)),
    ActuralLoss = convert(decimal(16,2),round(perf.beginBalance - cast(loss.netSaleProceeds as double) - loss.expenses + (timeDQ * perf.beginBalance * 30/360 * (perf.endcoupon - 0.25)/100) - loss.MIRecoveries - loss.nonMIRecoveries,2)),
    perf.HPA
FROM #PIV_FMACLoanLevel_Static orig
JOIN #PIV_FMACLoanLevel_Dynamic perf
    ON orig.loanID = perf.loanID
LEFT JOIN #PIV_FMACLoanLevel_Loss loss
    ON orig.loanID = loss.loanID
WHERE 1=1
    AND perf.zeroBalanceCode IN (3, 9)
    AND loss.netSaleProceeds != 'C'




SELECT 
count(1) cnt
FROM #PIV_FMACLoanLevel_Static orig
JOIN #PIV_FMACLoanLevel_Dynamic perf
    ON orig.loanID = perf.loanID
LEFT JOIN #PIV_FMACLoanLevel_Loss loss
    ON orig.loanID = loss.loanID
WHERE 1=1
    AND perf.zeroBalanceCode IN (3, 9)
    AND loss.netSaleProceeds != 'C'



select *
FROM #PIV_FMACLoanLevel_Static orig
select *
FROM #PIV_FMACLoanLevel_Loss loss
select *
from #PIV_FMACLoanLevel_Dynamic perf


select *
FROM fhl.PIV_CreditLossHist

select *
FROM fhl.LoanLevelHistMonthlyPerformData

select *
FROM fhl.PIV_CreditPerformanceHist