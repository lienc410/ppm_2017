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
    sph.percentCURRENT,
    sph.percentDQ30,
    sph.percentDQ60,
    sph.percentDQ90,
    sph.refi_incentive,
    
    --sph.max_refi_incentive,
    sph.adjusted_refi_incentive,
    
    sph.burnout,
    sph.wala,
    sph.origLoanSize,
    sph.currLoanSize,
    sph.origNoteRate,
    sph.percentConstruction,
    sph.percentCanPrepay,
    
    --sph.penaltyRate,
    --sph.penaltyCycle,
    sph.surge_index,
    sph.penalty_cycle_mult,
    
    1.0 as monthSinceCurrent,
    sph.turnoverWALA,
    sph.monthsSinceLoanIssuance,
    sph.ignoreDelinq,
    sph.projected_origLoanSize,
    sph.projected_currLoanSize
FROM #Symphony_pools sph
--@SAMPLE_JOIN@
WHERE 1=1
    @VINTAGE_WHERE@
    @ASOF_WHERE@
;

