set temporary option temp_extract_name1='@EXTRACT_FILE_PATH@';
set temporary option temp_extract_column_delimiter='|';
set temporary option Temp_Extract_Row_Delimiter='\n';
set temporary option Temp_Extract_Quote='"';
set temporary option Temp_Extract_Quotes_All='OFF';
set temporary option Temp_Extract_Quotes='ON';
set temporary option Temp_Extract_Null_As_Empty='ON';

SELECT
    p.issueId,
    marketTicket,
    issueDate,
    p.asofdate,
    monthBucket,
	bbal as bal,
    ppct_owner as pct_owner,
    ppct_2nd as pct_2nd,
    ppct_inv as pct_inv,
    ppct_CURRENT as pct_curr,
    ppct_DELQ as pct_dq,
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
    ppct_REFI as pct_REFI,
    CASE WHEN refiEligPct IS NULL THEN 100.0 ELSE refiEligPct END as refiEligPct,
    p.ppct_HARP as pct_HARP, 
    CASE WHEN p.ppct_TPO IS NOT NULL THEN p.ppct_TPO ELSE 0.0 END as pct_tpo,
    CASE WHEN (issueDate < '2009-06-01' AND p.asofdate >= '2009-06-01') THEN 1 ELSE 0 END as HARPElig,       
    smm as smm
FROM #refinance_pools p
--@SAMPLE_JOIN@
JOIN #refinanceable rfp
    ON p.asOfDate = rfp.asOfDate
WHERE 1=1
    AND ffico IS NOT NULL AND ffico > 200
    AND ccltv IS NOT NULL AND ccltv > 0
    AND wwaoltv IS NOT NULL AND wwaoltv > 0
    AND hhpa2yr IS NOT NULL
    AND wwacls IS NOT NULL
    @VINTAGE_WHERE@
    @ASOF_WHERE@
;