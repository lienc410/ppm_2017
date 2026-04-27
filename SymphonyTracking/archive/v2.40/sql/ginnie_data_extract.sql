set temporary option temp_extract_name1='@EXTRACT_FILE_PATH@';
set temporary option temp_extract_column_delimiter='|';
set temporary option Temp_Extract_Row_Delimiter='\n';
set temporary option Temp_Extract_Quote='"';
set temporary option Temp_Extract_Quotes_All='OFF';
set temporary option Temp_Extract_Quotes='ON';
set temporary option Temp_Extract_Null_As_Empty='ON';

SELECT
    sph.issueId,
    sph.asOf,
    sph.monthBucket,
	sph.schamBalance,
    100.0 as percentOCC_OWN,
    0.0 as percentOCC_2ND,
    0.0 as percentOCC_INV,
    sph.percentCURRENT,
    sph.percentDELQ30plus,
    sph.refi_incentive,
    sph.burnout,
    sph.wala,
    sph.currLoanSize,
    sph.cltv,
    sph.origFICO,
    sph.origNoteRate,
    sph.percentPURP_REFI,
    sph.conventional_eligible,
    NULL as percentHARPed, 
    sph.percentCHANNEL_BROKER + sph.percentCHANNEL_CORRES as pct_TPO,
    NULL as HARP_eligible,
    1.0 as monthSinceCurrent,
    100.0 * hpi.HPA_2YR as HPA_2YR,
    ca.mca_18mo,
    me.media_effect
FROM #Symphony_pools sph
--@SAMPLE_JOIN@
JOIN #HPA_MA hpi
    ON sph.asOf = hpi.asOf
JOIN #MediaEffect me
    ON sph.asOf = me.asOf
JOIN #CreditAvailability ca
    ON sph.asOf = ca.asOf
WHERE 1=1
    @VINTAGE_WHERE@
    @ASOF_WHERE@
;

