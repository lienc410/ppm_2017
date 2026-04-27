
DROP TABLE IF EXISTS #bucket;
SELECT 
    cltvBucket = (case
                  when slh.cltv < 10 THEN '10'
                  when slh.cltv < 20 THEN '20'
                  when slh.cltv < 30 THEN '30'
                  when slh.cltv < 40 THEN '40'
                  when slh.cltv < 50 THEN '50'
                  when slh.cltv < 60 THEN '60'
                  when slh.cltv < 70 THEN '70'
                  when slh.cltv < 80 THEN '80'
                  when slh.cltv < 90 THEN '90'
                  when slh.cltv < 100 THEN '100'
                  when slh.cltv < 110 THEN '110'
                  when slh.cltv < 120 THEN '120'
                  when slh.cltv < 130 THEN '130'
                  when slh.cltv < 140 THEN '140'
                  else '150' end),
    convert(numeric(6,2), sum(slh.cltv * slh.balance) / sum(slh.balance)) as cltv,
    sum(CASE WHEN sle.conventional_eligible <= sle.fha_eligible THEN sle.fha_eligible ELSE sle.conventional_eligible END * slh.balance) / sum(slh.balance) as refi_elig_pct
INTO #bucket
FROM scale.fhl_loanEligibility sle
JOIN scale.fhl_loanHist slh ON sle.asof = slh.asof AND sle.loanSeqNum = slh.loanSeqNum
WHERE 1=1
and slh.asof >= '2009-06-01'
GROUP BY cltvBucket

select * from #bucket 
order by cltvBucket
