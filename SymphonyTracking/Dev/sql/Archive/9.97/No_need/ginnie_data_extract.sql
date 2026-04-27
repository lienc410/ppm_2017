set temporary option temp_extract_name1='@EXTRACT_FILE_PATH@';
set temporary option temp_extract_column_delimiter='|';
set temporary option Temp_Extract_Row_Delimiter='\n';
set temporary option Temp_Extract_Quote='"';
set temporary option Temp_Extract_Quotes_All='OFF';
set temporary option Temp_Extract_Quotes='ON';
set temporary option Temp_Extract_Null_As_Empty='ON';


SELECT
    slh.loanSeqNum,
    asOf,
    monthBucket,
    --marketTicker,
    loanType,
    convert(numeric(20, 1), schamBalance) as bal,
    convert(numeric(5, 2), pct_dq) as pct_dq,  
    convert(numeric(8, 1), incentive), 
    convert(numeric(8, 1), burnout),  
    convert(numeric(4, 1), wala),    
    convert(numeric(20, 1), wacls)/1000 as wacls,
    convert(numeric(4, 1), cltv), 
    convert(numeric(4, 1), fico),
    convert(numeric(4, 1), pct_REFI),
    0.0 as monthSinceCurrent,
    convert(numeric(4, 1), hpa2yr),
    convert(numeric(4, 1), cai),
    convert(numeric(4, 1), media_effect)
FROM #Symphony_loans slh
--@SAMPLE_JOIN@
WHERE 1=1
    @VINTAGE_WHERE@
    @ASOF_WHERE@
    @LOANTYPE_WHERE@
    --@ORIGINATION_DATE_WHERE@
;

