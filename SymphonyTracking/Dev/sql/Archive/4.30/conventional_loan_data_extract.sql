set temporary option temp_extract_name1='@EXTRACT_FILE_PATH@';
set temporary option temp_extract_column_delimiter='|';
set temporary option Temp_Extract_Row_Delimiter='\n';
set temporary option Temp_Extract_Quote='"';
set temporary option Temp_Extract_Quotes_All='OFF';
set temporary option Temp_Extract_Quotes='ON';
set temporary option Temp_Extract_Null_As_Empty='ON';

SELECT
    slh.loanseqnum,
    slh.asOf,
    slh.monthBucket,
	slh.schamBalance,
    slh.percentOCC_OWN,
    slh.percentOCC_2ND,
    slh.percentOCC_INV,
    slh.percentCURRENT,
    slh.percentDELQ30plus,
    slh.refi_incentive,
    slh.burnout,
    slh.wala,
    slh.currLoanSize / 1000.0 as wacls,
    slh.cltv,
    slh.origFICO,
    slh.origNoteRate,
    slh.percentPURP_REFI,
    slh.refi_eligible,
    slh.percentHARPed, 
    slh.percentCHANNEL_BROKER + slh.percentCHANNEL_CORRES as pct_TPO,
    slh.HARP_eligible,
    slh.SATO as sato,
    0.0 as monthsSince,
    100.0 * hpi.HPA_2YR as HPA_2YR,
    ca.mca_18mo,
    me.media_effect,
	dc.day_count,
	slh.wam,
	slh.hpa_annual,
	slh.hpa_cum,
	slh.currLoanSize / 1000.0 as acls,
	slh.pct_purchase,
	slh.pct_second_lien,
	slh.refinance_incentive,
    slh.oltv
FROM #Symphony_loans slh
--@SAMPLE_JOIN@
JOIN #HPA_MA hpi
    ON slh.asOf = hpi.asOf
JOIN #MediaEffect me
    ON slh.asOf = me.asOf
JOIN #CreditAvailability ca
    ON slh.asOf = ca.asOf
JOIN #Business_Day_Count dc
	ON slh.asOf = dc.asOf
WHERE 1=1
    @VINTAGE_WHERE@
    @ASOF_WHERE@
;

