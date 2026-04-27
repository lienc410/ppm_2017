-----------------------------------------------------------------
-- FREDDIE MAC LOAN LEVEL DATA SCRUBBING AND CONVERSION SCRIPT --
-----------------------------------------------------------------

-- Testing with Random Sample
--DROP TABLE IF EXISTS #loanIDs;
--SELECT loanID, NEWID() as IDX INTO #loanIDs FROM fhl.LoanLevelHistOriginationData; -- WHERE year(firstPaymtDt) IN (2004, 2005, 2006, 2007);
--COMMIT;
--DROP TABLE IF EXISTS #LoanSample;
--SELECT top 100000 loanID INTO #LoanSample FROM #loanIDs ORDER BY IDX;
--COMMIT;

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
INSERT #channelMapping SELECT '#', 'UNKNOWN';
COMMIT;

--'not found'
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
COMMIT;

    -- product
DROP TABLE IF EXISTS #prodMapping;
CREATE TABLE #prodMapping(
    code varchar(8),
    val  varchar(20)
)
;
INSERT #prodMapping SELECT 'FRM30', 'FIXED30';
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
INSERT #loanPurposeMapping SELECT 'N', 'RE-FI-NCO';
INSERT #loanPurposeMapping SELECT '#', 'UNKNOWN';
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

--'not found'
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
INSERT #occupancyMapping SELECT 'O', 'OWNER';
INSERT #occupancyMapping SELECT 'S', '2ND';
INSERT #occupancyMapping SELECT 'I', 'INV';
COMMIT;

    -- delinq
DROP TABLE IF EXISTS #dqMapping;
CREATE TABLE #dqMapping(
    code varchar(8),
    val  varchar(20)
)
;
INSERT #dqMapping SELECT '00', 'C';
INSERT #dqMapping SELECT '01', '30';
INSERT #dqMapping SELECT '02', '60';
INSERT #dqMapping SELECT '03', '90';
INSERT #dqMapping SELECT '04', '120';
INSERT #dqMapping SELECT '05', '150';
INSERT #dqMapping SELECT '06', '180+';
INSERT #dqMapping SELECT '07', '180+';
INSERT #dqMapping SELECT '08', '180+';
INSERT #dqMapping SELECT '09', '180+';
COMMIT;

    -- zero balance code
DROP TABLE IF EXISTS #zbcMapping;
CREATE TABLE #zbcMapping(
    code varchar(8),
    val  varchar(20)
)
;
INSERT #zbcMapping SELECT '01', 'PP';
INSERT #zbcMapping SELECT '04', 'FC';
INSERT #zbcMapping SELECT '98', 'Other';
INSERT #zbcMapping SELECT '96', 'UDP';
INSERT #zbcMapping SELECT '97', 'DQ';
--INSERT #zbcMapping SELECT '#', 'UNKNOWN';
COMMIT;

    -- zero balance code (numeric)
DROP TABLE IF EXISTS #zbcNumMapping;
CREATE TABLE #zbcNumMapping(
    code smallint,
    val  varchar(20)
)
;
INSERT #zbcNumMapping SELECT '01', 'PP';
INSERT #zbcNumMapping SELECT '04', 'FC';
INSERT #zbcNumMapping SELECT '98', 'Other';
INSERT #zbcNumMapping SELECT '96', 'UDP'; --Underwriting Defect Prior to D180
INSERT #zbcNumMapping SELECT '97', 'DQ';
--INSERT #zbcNumMapping SELECT #, 'UNKNOWN';
COMMIT;
--01,#,04,97,96,98

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
DROP TABLE IF EXISTS #PIV_FHLCRTLoanLevel_Static;
SELECT
    asof,    
    s.loanID as loanID,
    year(firstPaymtDt) as vintage,
    origNoteRate as origCoupon,
    origLoanAmt as origBalance,
    origTerm,
    cast(origLoanAmt * ((origNoteRate / 1200.0) + ((origNoteRate / 1200.0) / (power(1.0 + (origNoteRate / 1200.0), origTerm) - 1.0))) as numeric(10,4)) as origPayment,
    origLTV,
    origLTV as origCLTV,
    cast(CASE WHEN origLTV IS NOT NULL THEN (origBalance / origLTV) * 100.0 ELSE NULL END as numeric(14,2)) as origValue,
    1 as lien,
    cast(CASE WHEN abs(origCLTV - origLTV) > .0001 THEN origValue * (origCLTV / 100.0) - origBalance ELSE 0.0 END as numeric(14,2)) as secondBalance,
    DTI as origDTI,
    CS as origFICO,
    NULL as origCoFICO,
    CASE WHEN pctMtgIns IS NOT NULL AND pctMtgIns > 0 THEN 1 ELSE 0 END as miFlag,
    IFNULL(pctMtgIns, 0.0, pctMtgIns) as miLevel,
    CASE WHEN firstTimeHomeBuyerFlag = '' THEN 'U' ELSE firstTimeHomeBuyerFlag END as firstTimeHomeBuyerFlag,
    numBorrowers as numberBorrowers,
    numUnits as numberUnits,
    IFNULL(lp.val, s.loanPurpose, lp.val) as loanPurpose,
    IFNULL(pt.val, s.propType, pt.val) as propertyType,
    IFNULL(occ.val, s.occStatus, occ.val) as occupancyStatus,
    'FIXED30' as productType,
    'CONVENTIONAL' as loanType,
    'FULL' as docType,
    --prepayPenaltyFlag,
    cast(dateadd(month, -(s.origTerm), s.matDt) as date) as originationDate,
    firstPaymtDt as firstPaymentDate,
    matDt as maturityDate,
    IFNULL(ch.val, s.channel, ch.val) as channel,
    seller,
    CASE WHEN servicer = '' THEN 'UNKNOWN' ELSE servicer END as origServicer,
    state,
    IFNULL(st.jud_flag, '0', st.jud_flag) as judicialFlag,
    msa,
    ZipPrefix as zip_3
INTO #PIV_FHLCRTLoanLevel_Static1
FROM fhl.RefLoan s
--JOIN #LoanSample ls
--    ON s.loanID = ls.loanID
LEFT JOIN #channelMapping ch
    ON s.channel = ch.code
LEFT JOIN #propertyTypeMapping pt
    ON s.propType = pt.code
--LEFT JOIN #prodMapping prd
    --ON s.productType = prd.code
LEFT JOIN #loanPurposeMapping lp
    ON s.loanPurpose = lp.code
LEFT JOIN #occupancyMapping occ
    ON s.occStatus = occ.code
LEFT JOIN #stateMapping st
    ON s.state = st.code
;
COMMIT;

-- Unit Test
--SELECT count(1) FROM #PIV_FMACLoanLevel_Static;
--SELECT count(1) FROM fhl.LoanLevelHistOriginationData;
-- they should be equal

-- Drop loans with bad attributes (no LTV, etc)
DELETE FROM #PIV_FHLCRTLoanLevel_Static1
WHERE origLTV IS NULL;
COMMIT;

DELETE FROM #PIV_FHLCRTLoanLevel_Static1
WHERE origCoupon IS NULL;
COMMIT;

CREATE INDEX loan_id_idx ON #PIV_FHLCRTLoanLevel_Static1(loanID);
COMMIT;


DROP TABLE IF EXISTS #temp1;
select loanID, min(asof) asof into #temp1 
from #PIV_FHLCRTLoanLevel_Static1 tmp 
group by loanID;

DROP TABLE IF EXISTS #temp2;
DROP TABLE IF EXISTS #PIV_FHLCRTLoanLevel_Static;
select lls.* into #PIV_FHLCRTLoanLevel_Static from #PIV_FHLCRTLoanLevel_Static1 lls, #temp1 tmp1
where lls.loanID = tmp1.loanID
and lls.asof = tmp1.asof
;



--------- DYNAMIC DATA ------------

-- Create Temporary Performance Table with From and To Columns
DROP TABLE IF EXISTS #PIV_FHLCRTLoanLevel_Dynamic;
SELECT
    t1.loanID,
    t1.asOf as beginDate,
    --t2.asOf as endDate, --not needed
    --datediff(month, '19890101', t2.asOf) as to_period, --LP style period, starts from arbitrary date (1989-01-01) in the past --not needed
    t1.remTerm as beginRemainingTerm,
    t2.remTerm - t1.remTerm as diffRemainingTerm,
    --cast(NULL as smallint) as adjRemainingTerm, --remove later
    t1.LoanAge as beginLoanAge,
    t1.CurrNoteRate as beginCoupon,
    t2.CurrNoteRate as endCoupon, --remove later
    t2.CurrNoteRate - t1.CurrNoteRate as diffCoupon,
    t1.currRPB as beginBalance,
	t2.currRPB as endBalance, --remove later
    t2.currRPB - t1.currRPB as diffBalance,
    cast(NULL as numeric(14,4)) as beginScheduledPayment,
    cast(NULL as numeric(14,4)) as endScheduledPayment, --remove later
    cast(NULL as numeric(14,4)) as diffScheduledPayment,
    dqfrom.val as beginStatus,
    CASE 
        WHEN t2.PIFCode IS NOT NULL OR dqto.val IN ('180+', 'REO') THEN 'X' -- for the Freddie data we are setting the '180+' and 'R' DQ status as a terminating event
        ELSE dqto.val
    END as endStatus,
    CASE
        WHEN dqto.val IN ('180+', 'REO') THEN 'DQ' -- for the Freddie data we are setting the '180+' and 'R' DQ status as a terminating event
        WHEN t2.PIFCode IS NOT NULL THEN zbc.val
            --CASE 
            --    WHEN zbc.code IN ('01', '06') THEN 'P'
            --    WHEN zbc.code IN ('03', '09', '97') THEN 'D'
            --    ELSE 'X'
            --END
        ELSE dqto.val
    END as zeroBalanceCode,
    --t2.repurchaseFlag as to_repo, -- not used
    CASE WHEN t1.ModFlag = 'N' THEN '' ELSE t1.ModFlag END as beginModificationFlag, --remove later
    CASE WHEN t2.ModFlag = 'N' THEN '' ELSE t2.ModFlag END as modificationFlag,
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
INTO #PIV_FHLCRTLoanLevel_Dynamic
FROM fhl.RefLoan t1
JOIN fhl.RefLoan t2
    ON t1.loanID = t2.loanID
    AND t1.asOf = dateadd(month, -1, t2.asOf)
JOIN #PIV_FHLCRTLoanLevel_Static orig
    ON orig.loanID = t1.loanID
LEFT JOIN #dqMapping dqfrom
    ON t1.delqStatus = dqfrom.code
LEFT JOIN #dqMapping dqto
    ON t2.delqStatus = dqto.code
LEFT JOIN #zbcMapping zbc
    ON t2.PIFCode = zbc.code
;
COMMIT;


---------------Check Result------------------
SELECT  count(1) FROM #PIV_FHLCRTLoanLevel_Static1;
SELECT  count(1) FROM #PIV_FHLCRTLoanLevel_Static;
select count(distinct loanID) FROM #PIV_FHLCRTLoanLevel_Static;

select * from #PIV_FHLCRTLoanLevel_Dynamic
where begindate = '2015-01-01'
SELECT  count(1) FROM #PIV_FHLCRTLoanLevel_Dynamic;

select pifcode as grp, count(1) as Cnt from #PIV_FHLCRTLoanLevel_Dynamic GROUP BY grp order by grp;