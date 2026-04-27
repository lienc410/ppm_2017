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
    slh.turnover_incentive, 
--    slh.refinance_GNM_incentive, 
    slh.refinance_incentive,
    slh.burnout,  
    slh.wala,    
    slh.wacls,
    slh.acls,
    slh.cltv, 
    slh.fico,
    slh.hasFICOFlag,
    slh.hpa_annual,
    slh.hpa_cum,
    slh.percentCHANNEL_BROKER as pct_BROKER,
    slh.percentCHANNEL_CORRES as pct_CORRES,
    slh.percentCHANNEL_RETAIL as pct_RETAIL,
    slh.percentCHANNEL_NA as pct_NA,
    slh.cai,
    slh.media_effect,
    slh.pct_purchase,
    slh.pct_second_lien,
    slh.wam,
    slh.oltv,
	dc.day_count,
    slh.pct_preHARP,
    slh.pct_NY,
    slh.pct_refi_co,
    slh.pct_refi_nco,
    slh.pct_hmod,
    slh.pct_nhmod,
    slh.pct_rp,
    slh.pct_none,
    slh.monthsSinceIssued,
    slh.pct_TX,
    slh.delq_flag,
    1.0 as monthsSince,
    slh.delMonths,
    slh.reperformingStatus,
    slh.wala as walaAtStatus,
    slh.sato,
    slh.dti,
    slh.laggedUnemployChangeSinceStatus,
    slh.cumHPI,
    slh.buyoutIncentive,
    slh.servicerBuyoutIndex,
    slh.FTAIncentive,
    slh.prepayMonth
FROM #Symphony_loans_test slh
JOIN #Business_Day_Count dc
	ON slh.asOf = dc.asOf
--@SAMPLE_JOIN@
WHERE 1=1
    @VINTAGE_WHERE@
    @ASOF_WHERE@
    @LOANTYPE_WHERE@
    --@ORIGINATION_DATE_WHERE@
;

