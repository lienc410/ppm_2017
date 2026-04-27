set temporary option temp_extract_name1='@EXTRACT_FILE_PATH@';
set temporary option temp_extract_column_delimiter='|';
set temporary option Temp_Extract_Row_Delimiter='\n';
set temporary option Temp_Extract_Quote='"';
set temporary option Temp_Extract_Quotes_All='OFF';
set temporary option Temp_Extract_Quotes='ON';
set temporary option Temp_Extract_Null_As_Empty='ON';

SELECT
    p.issueId as trackId,
    vintage,
    origCoupon,
    p.asOfDate,
    monthBucket,
	bbal as schambal,
    ppct_owner as pct_owner,
    ppct_2nd as pct_2nd,
    ppct_inv as pct_inv,
    ppct_CURRENT as pct_CURRENT,
    ppct_DELQ as pct_DELQ,
    iincentive as incentive,
    bburnout as burnout,
    wwala as wala,
    wwacls as wacls,
	ccltv as cltv,
	ffico as fico,
    wwac as wac,
    hhpa2yr as hpa2yr,
    hhpa2yr as credit_availability,
    rfp.pct_refinancible_pool as media_refi,
	1.0 as monthSinceCurrent,
    NULL as pct_REFI,
    NULL as refiEligPct,
    NULL as pct_HARP, 
    NULL as pct_tpo,
    NULL as HARPElig,    
    smm
FROM #refinance_pools p
--@SAMPLE_JOIN@
JOIN #refinanceable rfp
    ON p.asOfDate = rfp.asOfDate
WHERE 1=1
    AND ffico IS NOT NULL AND ffico > 200
    AND ccltv IS NOT NULL AND ccltv > 0
    AND hhpa2yr IS NOT NULL
    AND wwacls IS NOT NULL
    AND bburnout IS NOT NULL
    @VINTAGE_WHERE@
    @ASOF_WHERE@
;
