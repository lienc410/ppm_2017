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
    sph.percentOCC_OWN,
    sph.percentOCC_2ND,
    sph.percentOCC_INV,
    sph.percentCURRENT,
    sph.percentDELQ30plus,
    sph.refi_incentive,
    sph.burnout,
    sph.wala,
    sph.currLoanSize / 1000.0 as wacls,
    sph.cltv,
    sph.origFICO,
    sph.origNoteRate,
    sph.percentPURP_REFI,
    sph.refi_eligible,
    sph.percentHARPed, 
    sph.percentCHANNEL_BROKER + sph.percentCHANNEL_CORRES as pct_TPO,
    sph.HARP_eligible,
	sph.SATO as sato,
    0.0 as monthsSince,
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

