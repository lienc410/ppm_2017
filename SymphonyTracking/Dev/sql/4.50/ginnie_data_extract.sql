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
    0.0 as monthSinceCurrent,
    slh.hpa2yr,
    slh.hpa_annual,
    slh.hpa_cum,
    slh.cai,
    slh.media_effect,
    (slh.percentCHANNEL_BROKER + slh.percentCHANNEL_CORRES) as pct_TPO,
    slh.percentCHANNEL_BROKER as pct_BROKER,
    slh.percentCHANNEL_CORRES as pct_CORRES,
    slh.percentCHANNEL_TPO as pct_NonRETAIL,
    CASE WHEN slh.percentCHANNEL_RETAIL > slh.percent_CashWindow THEN slh.percent_CashWindow ELSE slh.percentCHANNEL_RETAIL END as pct_RETAIL_CashWindow,
    (slh.percentCHANNEL_RETAIL - pct_RETAIL_CashWindow) as pct_RETAIL_NonCashWindow,
    slh.pct_purchase,
    slh.HARP_eligible,
    slh.refi_eligible,
    slh.pct_second_lien,
    slh.pct_HARPed,
    slh.wam,
    slh.oltv,
	dc.day_count,
    slh.pct_preHARP,
    slh.pct_NY,
    slh.pct_refi_co,
    slh.pct_refi_nco
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

