set temporary option temp_extract_name1='@EXTRACT_FILE_PATH@';
set temporary option temp_extract_column_delimiter='|';
set temporary option Temp_Extract_Row_Delimiter='\n';
set temporary option Temp_Extract_Quote='"';
set temporary option Temp_Extract_Quotes_All='OFF';
set temporary option Temp_Extract_Quotes='ON';
set temporary option Temp_Extract_Null_As_Empty='ON';

SELECT
    slh.issueId,
    slh.asOf,
    slh.monthBucket,
	slh.schamBalance,
    slh.percentCURRENT,
    slh.percentDQ30,
    slh.percentDQ60,
    slh.percentDQ90,
    slh.refi_incentive,
    
    --slh.max_refi_incentive,
    slh.adjusted_refi_incentive,
    
    slh.burnout,
    slh.wala,
    slh.origLoanSize,
    slh.currLoanSize,
    slh.origNoteRate,
    slh.percentConstruction,
    slh.percentCanPrepay,
    
    --slh.penaltyRate,
    --slh.penaltyCycle,
    slh.surge_index,
    slh.penalty_cycle_mult,
    
    1.0 as monthSinceCurrent,
    slh.turnoverWALA,
    slh.monthsSinceLoanIssuance,
    slh.ignoreDelinq,
    slh.projected_origLoanSize,
    slh.projected_currLoanSize
FROM #Symphony_pools slh
--@SAMPLE_JOIN@
WHERE 1=1
    @VINTAGE_WHERE@
    @ASOF_WHERE@
;

