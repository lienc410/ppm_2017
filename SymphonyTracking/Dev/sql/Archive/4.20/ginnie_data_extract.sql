set temporary option temp_extract_name1='@EXTRACT_FILE_PATH@';
set temporary option temp_extract_column_delimiter='|';
set temporary option Temp_Extract_Row_Delimiter='\n';
set temporary option Temp_Extract_Quote='"';
set temporary option Temp_Extract_Quotes_All='OFF';
set temporary option Temp_Extract_Quotes='ON';
set temporary option Temp_Extract_Null_As_Empty='ON';


SELECT
    slh.loanSeqNum,
    slh.asOf,
    slh.monthBucket,
    --marketTicker,
    slh.loanType,
    slh.schamBalance as bal,
    slh.pct_dq as pct_dq,  
    slh.turnover_incentive, 
    slh.refinance_incentive, 
    slh.burnout,  
    slh.wala,    
    slh.wacls,
    slh.acls,
    slh.cltv, 
    slh.fico,
    slh.pct_REFI,
    0.0 as monthSinceCurrent,
    slh.hpa2yr,
    slh.hpa_annual,
    slh.hpa_cum,
    slh.cai,
    slh.media_effect,
    slh.pct_TPO,
    slh.pct_purchase,
    slh.HARP_eligible,
    slh.refi_eligible,
    slh.pct_second_lien,
    slh.pct_HARPed,
    slh.wam,
    slh.oltv,
	dc.day_count
FROM #Symphony_loans slh
JOIN #Business_Day_Count dc
	ON slh.asOf = dc.asOf
--@SAMPLE_JOIN@
WHERE 1=1
    @VINTAGE_WHERE@
    @ASOF_WHERE@
    @LOANTYPE_WHERE@
    --@ORIGINATION_DATE_WHERE@
;

