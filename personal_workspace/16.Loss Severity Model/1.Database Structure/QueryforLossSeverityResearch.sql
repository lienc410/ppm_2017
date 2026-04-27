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





---------------------- Check max MI coveries -----------------------
select  
        orig.loanID,
        MaxCoverage = convert(decimal(16,2),round(orig.miLevel * loss.lossclaim/100,2)),
        loss.miRecoveries,
        loss.actualLoss_noMI,
        UncoveredBalance = loss.actualLoss_noMI - loss.miRecoveries
FROM fhl.PIV_CreditLossHist loss
Join fhl.PIV_CreditOrigination orig
    on orig.loanID = loss.loanID
where loss.miRecoveries > 0
    and loss.actualLoss_noMI < MaxCoverage
    and loss.miRecoveries < MaxCoverage

SELECT 
count(1) cnt
FROM fhl.PIV_CreditLossHist loss
Join fhl.PIV_CreditOrigination orig
    on orig.loanID = loss.loanID
where loss.miRecoveries > 0
    and loss.actualLoss_noMI > orig.miLevel * loss.lossclaim/100
    and loss.miRecoveries < orig.miLevel * loss.lossclaim/100


-------------------------- Count FC/REO number and average TimeDQ ---------------------------
SELECT loss.lossDate,
       count(1) FC,
       TimeDQ = convert(decimal(16,2),round(avg( datediff(month, loss.lastPaymentDate, perf.beginDate)),2))
FROM fhl.PIV_CreditOrigination orig
LEFT JOIN fhl.PIV_CreditLossHist loss
    ON orig.loanID = loss.loanID
JOIN fhl.PIV_CreditPerformanceHist perf
    ON orig.loanID = perf.loanID
    and loss.lossDate = perf.begindate
JOIN fhl.LoanLevelHistMonthlyPerformData perf1
    ON orig.loanID = perf1.loanID
    and loss.lossDate = perf1.asof
    AND perf1.zeroBalanceCode IN (3)
group by loss.lossDate




-------------------------- nonMIRecoveries ---------------------------
SELECT loss.lossDate,
       count(1) cnt,
       nonMIRecoveries = convert(decimal(16,2),round(avg(loss.nonMIRecoveries),2)),
       MIRecoveries = convert(decimal(16,2),round(avg(loss.MIRecoveries),2)),
       Loss = convert(decimal(16,2),round(avg(loss.actualLoss_MI),2))
FROM fhl.PIV_CreditOrigination orig
LEFT JOIN fhl.PIV_CreditLossHist loss
    ON orig.loanID = loss.loanID
JOIN fhl.PIV_CreditPerformanceHist perf
    ON orig.loanID = perf.loanID
    and loss.lossDate = perf.begindate
JOIN fhl.LoanLevelHistMonthlyPerformData perf1
    ON orig.loanID = perf1.loanID
    and loss.lossDate = perf1.asof
    AND perf1.zeroBalanceCode IN (3,9)
group by loss.lossDate


 



select *
FROM #PIV_FMACLoanLevel_Static orig
select *
FROM #PIV_FMACLoanLevel_Loss loss
select *
from #PIV_FMACLoanLevel_Dynamic perf



select *
from fhl.PIV_CreditOrigination orig

select * 
FROM fhl.PIV_CreditLossHist loss
order by lossDate desc

select *
FROM fhl.LoanLevelHistMonthlyPerformData

select *
FROM fhl.PIV_CreditPerformanceHist perf
where zerobalancecode = '9'


select * from hpi.HomePriceIndex
where transactiontype = 'PURCHASE_ONLY'
and regiontype = 'USA'
select distinct regiontype from hpi.HomePriceIndex


---------------- 2 year moving average for HPI ----------------
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
WHERE TransactionType = 'PURCHASE_ONLY'
    AND loadQuarter = (SELECT max(loadQuarter) FROM hpi.HomePriceIndex)
    AND RegionType IN ('USA')
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
    END as NSAIndex,
    TwoYearAVG = AVG(NSAIndex) OVER (ORDER BY asof ROWS BETWEEN 24 PRECEDING AND CURRENT ROW)
INTO #HomePriceIndex_monthly
FROM #HomePriceIndex_temp1 t1
CROSS JOIN #t t
LEFT JOIN #HomePriceIndex_norm norm
    ON t1.asOf = norm.endDate
    AND t1.RegionType = norm.RegionType
    AND (t1.Region = norm.Region OR t1.MSACode = norm.MSACode)
;
COMMIT;

DROP TABLE IF EXISTS #HomePriceGrowthIndex_monthly;
SELECT
    --t1.asOf,
    t2.asof,
    t1.TwoYearAVG,
    Delta = (t2.TwoYearAVG-t1.TwoYearAVG) --Percentage changes
--    Delta = (t2.TwoYearAVG-t1.TwoYearAVG)/t1.TwoYearAVG * 100 --Percentage changes
INTO #HomePriceGrowthIndex_monthly
FROM #HomePriceIndex_monthly t1
LEFT JOIN #HomePriceIndex_monthly t2
    ON datediff(mm, t1.asOf, t2.asOf) = 1
;
COMMIT;

CREATE INDEX loan_asOf_idx ON #HomePriceGrowthIndex_monthly(asOf);
COMMIT;

select * 
from #HomePriceGrowthIndex_monthly


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

select * from #HPA_MA



-------------------------- Count FC/REO number and average TimeDQ ---------------------------
SELECT loss.lossDate,
       UPB = convert(decimal(16,2),round(avg(perf.beginBalance),2)),
       count(1) as cnt
FROM fhl.PIV_CreditOrigination orig
LEFT JOIN fhl.PIV_CreditLossHist loss
    ON orig.loanID = loss.loanID
JOIN fhl.PIV_CreditPerformanceHist perf
    ON orig.loanID = perf.loanID
    and loss.lossDate = perf.begindate
JOIN fhl.LoanLevelHistMonthlyPerformData perf1
    ON orig.loanID = perf1.loanID
    and loss.lossDate = perf1.asof
    AND perf1.zeroBalanceCode IN (3,9)
group by loss.lossDate





select 
    asof,
--    avg(perf.beginBalance)
    avg(datediff(month, loss.lastPaymentDate, perf.beginDate))
FROM fhl.PIV_CreditOrigination orig
LEFT JOIN fhl.PIV_CreditLossHist loss
    ON orig.loanID = loss.loanID
JOIN fhl.PIV_CreditPerformanceHist perf
    ON orig.loanID = perf.loanID
    and loss.lossDate = perf.begindate
JOIN fhl.LoanLevelHistMonthlyPerformData perf1
    ON orig.loanID = perf1.loanID
    and loss.lossDate = perf1.asof
    AND perf1.zeroBalanceCode IN (9)
group by asof





-------------------------- Check FHL data to calibrate with FNMA ------------------
SELECT 
    --orig.loanID,
    --year(loss.begindate) as year,
    loss.lossDate,
    --perf.beginBalance UPB,
    interest = sum((datediff(month, loss.lastPaymentDate, perf.beginDate) * perf.beginBalance * 30/360 * (perf.begincoupon - 0.25)/100)) / sum(perf.beginBalance),
    miRecoveries = sum(loss.miRecoveries) / sum(perf.beginBalance),
    nonMIRecoveries = sum(loss.miRecoveries) / sum(perf.beginBalance),
    expenses = sum(loss.expenses) / sum(perf.beginBalance),
    netSaleProceeds = sum(cast(loss.netSaleProceeds as double)) / sum(perf.beginBalance),
    --timeDQ = datediff(month, loss.lastPaymentDate, perf.beginDate),
    --ActuralLoss = convert(decimal(16,2),round(perf.beginBalance - cast(loss.netSaleProceeds as double) - loss.expenses + (timeDQ * perf.beginBalance * 30/360 * (perf.begincoupon - 0.25)/100) - loss.MIRecoveries - loss.nonMIRecoveries,2)),
    ActuralSeverity = sum(perf.beginBalance - cast(loss.netSaleProceeds as double) - loss.expenses + (datediff(month, loss.lastPaymentDate, perf.beginDate) * perf.beginBalance * 30/360 * (perf.begincoupon - 0.25)/100) - loss.MIRecoveries - loss.nonMIRecoveries) / sum(perf.beginBalance)
    --perf1.zeroBalanceCode
FROM fhl.PIV_CreditOrigination orig
LEFT JOIN fhl.PIV_CreditLossHist loss
    ON orig.loanID = loss.loanID
JOIN fhl.PIV_CreditPerformanceHist perf
    ON orig.loanID = perf.loanID
    and loss.lossDate = perf.begindate
JOIN fhl.LoanLevelHistMonthlyPerformData perf1
    ON orig.loanID = perf1.loanID
    and loss.lossDate = perf1.asof
    AND perf1.zeroBalanceCode IN (3)
--where ActuralSeverity >= 0
--    and ActuralSeverity < 1.05
group by loss.lossDate



select *
from fhl.PIV_CreditPerformanceHist perf
where  zerobalancecode in (3,9)
and asof = '2014-09-01'



select loss.lossdate,
        ExpenseServ = sum(-loss.expenses) / sum(perf.beginbalance) 
FROM fhl.PIV_CreditLossHist loss
join fhl.PIV_CreditPerformanceHist perf
on loss.loanId = perf.LoanID
and loss.lossdate = perf.begindate
--where lossDate = '2014-09-01'
where perf.zerobalancecode in ('9')
group by lossdate
order by lossdate desc





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
    perf1.zeroBalanceCode,
--    hpiold.Delta as NSAIndex,
    orig.state as state
FROM fhl.PIV_CreditOrigination orig
LEFT JOIN fhl.PIV_CreditLossHist loss
    ON orig.loanID = loss.loanID
JOIN fhl.PIV_CreditPerformanceHist perf
    ON orig.loanID = perf.loanID
    and loss.lossDate = perf.begindate
JOIN fhl.LoanLevelHistMonthlyPerformData perf1
    ON orig.loanID = perf1.loanID
    and loss.lossDate = perf1.asof
    AND perf1.zeroBalanceCode IN (3)
where lossdate = '2014-09-01'
--JOIN #HomePriceGrowthIndex_monthly hpiold
--    ON loss.lossDate = hpiold.asof

































--------------------------------
-- GSE LOAN LEVEL DATA EXPORT --
--------------------------------
-- This script allows the user to export subsets of the GSE Loan Level data for further analysis in Accordion
-- Note that this script will need to be modified to pull both Fannie and Freddie data

--set temporary option temp_extract_name1='';

-- Create a Random Sample of LoanIDs
-- *** Adjust for Fannie (fnm) or Freddie (fhl)
--DROP TABLE IF EXISTS #loanIDs;
--SELECT loanID, NEWID() as IDX INTO #loanIDs FROM fhl.PIV_CreditOrigination; -- WHERE year(firstPaymtDt) IN (2004, 2005, 2006, 2007);
--COMMIT;
--DROP TABLE IF EXISTS #LoanSample;
--SELECT top 200000 loanID INTO #LoanSample FROM #loanIDs ORDER BY IDX;
--COMMIT;

-- Create a Random Sample of Loan Data
-- *** Adjust for Fannie (fnm) or Freddie (fhl)
--DROP TABLE IF EXISTS #loanRows;
--SELECT loanID, beginDate, NEWID() as IDX INTO #loanRows FROM fhl.PIV_CreditPerformanceHist WHERE beginStatus IN ('C') AND countNonCurrent = 0;
--COMMIT;
--DROP TABLE IF EXISTS #LoanSample;
--SELECT top 5000000 * INTO #LoanSample FROM #loanRows ORDER BY IDX;
--COMMIT;
--CREATE INDEX idx_loanID ON #LoanSample(loanID);
--CREATE INDEX idx_beginDate ON #LoanSample(beginDate);
--COMMIT;

-- Creates the 30 YR FRM Rate (point ajdusted)
-- Copies the Logic from get30YrFRM (sql server)
DROP TABLE IF EXISTS #FHL30YrRates;
SELECT
    dateadd(day, -1, t1.asOfDate) as asOfDate,
    RawRate = t1.seriesValue,
    Points = t2.seriesValue,
    Rate = t1.seriesValue - (1 - t2.seriesValue) / 4
INTO #FHL30YrRates
FROM 	(
    SELECT  
        D.SeriesNumValue seriesValue,
        AsOfDate  
    FROM report.TimeSeriesMeta M
    JOIN report.TimeSeries D
        ON M.TimeSeriesMetaId = D.TimeSeriesMetaId
    WHERE M.source         = 'Freddie' 
        AND M.TickerName   = 'PMMS_FRM_30YR'
        AND M.SeriesType   = 'Rate_US'
        AND M.Category     = 'MTG'
) t1
JOIN (
    SELECT  
        D.SeriesNumValue seriesValue,
        AsOfDate  
    FROM report.TimeSeriesMeta M
    JOIN report.TimeSeries D
        ON M.TimeSeriesMetaId = D.TimeSeriesMetaId
    WHERE M.source         = 'Freddie' 
        AND M.TickerName   = 'PMMS_FRM_30YR'
        AND M.SeriesType   = 'Points_US'
        AND M.Category     = 'MTG'
) t2
ON t1.AsOfDate = t2.AsOfDate
WHERE t1.AsOfDate > '1990-01-01'
;
COMMIT;

-- Group the Rates into Year/Month periods
DROP TABLE IF EXISTS #FHL30YrRates_monthly;
SELECT
    convert(date, year(AsOfDate) || '-' || CASE WHEN month(AsOfDate) < 10 THEN '0' || convert(varchar, month(AsOfDate)) ELSE convert(varchar, month(AsOfDate)) END || '-01') as asOf,
    avg(Rate) as MtgRate
INTO #FHL30YrRates_monthly
FROM #FHL30YrRates
GROUP BY asOf
ORDER BY 1
;
COMMIT;
CREATE INDEX asOf_idx ON #FHL30YrRates_monthly(asOf);
COMMIT;




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





-- Pull the data from the Origination and Historical tables
--set temporary option temp_extract_name1="g:/tempExtract/Freddie_medium2_test_no_headers.txt";--''
--set temporary option temp_extract_column_delimiter='|';
--set temporary option Temp_Extract_Row_Delimiter='\n';
--set temporary option Temp_Extract_Quote='"';
--set temporary option Temp_Extract_Quotes_All='OFF';
--set temporary option Temp_Extract_Quotes='ON';
--set temporary option Temp_Extract_Null_As_Empty='ON';
SELECT 
    s.loanID as loanID,
    vintage,
    origBalance,
    origCoupon,
    origTerm,
    origLTV,
    origCLTV,
    origValue,
    lien,
    secondBalance,
    origDTI,
    origFICO,
    miFlag,
    miLevel,
    numberBorrowers,
    numberUnits,
    judicialFlag,
    convert(varchar(10), d.beginDate, 'yyyy-mm-dd') as beginDate,
    datediff(month, '19890101', beginDate) as from_period, --LP style period, starts from (1989-01-01) in the past. Easier to work with than Dates in R
    beginLoanAge,
    convert(varchar(3), trim(beginStatus)) as beginStatus,
    convert(varchar(3), trim(endStatus)) as endStatus,
    beginCoupon,
    diffCoupon,
    beginBalance,
    diffBalance,
    beginScheduledPayment,
    diffScheduledPayment,
    beginRemainingTerm,
    diffRemainingTerm,
    scheduledPrincipal = beginScheduledPayment - beginBalance * beginCoupon / 1200.0,
    modificationCount,
    monthsInModification,
    HPA,
	HPA_2YR,
    mtm_cltv = CASE WHEN HPA IS NOT NULL THEN (CASE WHEN s.origValue IS NOT NULL THEN 100.0 * (d.beginBalance / s.origValue) ELSE NULL END) / HPA ELSE NULL END,
    rate_curr.MtgRate as fhl30_lag2,
    rate_curr.MtgRate - rate_orig.MtgRate as fhl30_chg,
    countNonCurrent,
    ageSinceLastCurrent,
    ageSinceLastDelinquent,
    --firstTimeHomeBuyerFlag, -- not useful, as it is not well populated
    loanPurpose,
    propertyType,
    occupancyStatus,
    --docType, -- not useful, all FULL
    channel,
    --origServicer,
    state, 
    monthsAccrued,
    accruedInterest,
    -(expenses) as expenses,
    netSaleProceeds,
    lossClaim,
    actualLoss_noMI
FROM fhl.PIV_CreditOrigination s
--JOIN #LoanSample ls
--    ON s.loanID = ls.loanID
JOIN fhl.PIV_CreditPerformanceHist d
    ON s.loanID = d.loanID
--JOIN #LoanSample ls
--    ON s.loanID = ls.loanID
--    AND d.beginDate = ls.beginDate
JOIN fhl.PIV_CreditLossHist l
    ON d.loanID = l.loanID
    AND d.beginDate = l.lossDate
LEFT JOIN #FHL30YrRates_monthly rate_orig
    ON s.originationDate = dateadd(month, 2, rate_orig.asOf)
LEFT JOIN #FHL30YrRates_monthly rate_curr
    ON d.beginDate = dateadd(month, 2, rate_curr.asOf) -- using 1 month diff rather than 2 because joining on beginDate not endDate (still corresponds with a rate lag of 2 month)
LEFT JOIN #HPA_MA hpa
    ON d.beginDate = hpa.asof
    AND hpa.RegionType = 'STATE'
    AND hpa.Region = s.state
;

select * from #HPA_MA;


select distinct delinqstatus
from fhl.LoanLevelHistMonthlyPerformData
order by 1

--select count(1)
select *
from fhl.LoanLevelHistMonthlyPerformData
where zerobalancecode in (3, 9) 
and expenses is null

loanID  = 'F199Q1000366'
and asof != asofzerobalance



--    -- delinq
--DROP TABLE IF EXISTS #dqMapping;
--CREATE TABLE #dqMapping(
--    code varchar(8),
--    val  varchar(20)
--)
--;
--INSERT #dqMapping SELECT '0', 'C';
--INSERT #dqMapping SELECT '1', '30';
--INSERT #dqMapping SELECT '2', '60';
--INSERT #dqMapping SELECT '3', '90';
--INSERT #dqMapping SELECT '4', '120';
--INSERT #dqMapping SELECT '5', '150';
--INSERT #dqMapping SELECT '6', '180+';
--INSERT #dqMapping SELECT '7', '180+';
--INSERT #dqMapping SELECT '8', '180+';
--INSERT #dqMapping SELECT '9', '180+';
--INSERT #dqMapping SELECT 'R', 'REO';
--INSERT #dqMapping SELECT 'X', 'X';
--INSERT #dqMapping SELECT '',  'X';
--COMMIT;






------------- PMMS weekly survey 1-point rate --------------------
DROP TABLE IF EXISTS #tempone
select 
    AsOfDate,
    convert(Date, year(asOfDate) || '-' || month(asOfDate) || '-01') as AsOf,
    datebucket = convert(date, (case when asOfDate <= '2013-12-16' then '2011-09-22'
                when asOfDate <= '2014-01-08' then '2013-12-16'
                when asOfDate <= '2015-01-07' then '2014-01-08'
				when asOfDate < '2015-09-01' then '2015-01-07'
                else '2015-09-01' end)),
    SeriesNumValue = sum(case when M.SeriesType = 'Points_US' then (1.0 - d.SeriesNumvalue)/-4.0 else d.SeriesNumvalue end)
--into #tempone
from report.TimeSeriesMeta M, report.TimeSeries D
where M.TimeSeriesMetaId = D.TimeSeriesMetaId
and M.Source = 'Freddie'
and M.TickerName  ='PMMS_FRM_30YR'
and M.SeriesType in ('Points_US','Rate_US')
group by AsOfDate
order by AsOfDate DESC