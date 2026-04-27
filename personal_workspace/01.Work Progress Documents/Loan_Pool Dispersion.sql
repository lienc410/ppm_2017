
 select 
	PREPAY_CPR1 = 100*(1.0 - power(sum(1*currentRpb)/sum(1*calcScham), 12))
	, groupByColumn = asOf
    ,Balance = sum(schamBalance)
	,LoanCount = count(1)
    ,originationDate
from
FHL.PIV_LoanView v
join scale.fhl_loan sl on v.loanSeqNum = sl.loanSeqNum
where 
 	1 = 1
and schamBalance > 0.1
 and ( 1=2 
 OR v.marketTicker LIKE 'FGLMC')
 and calcOrigYear_LL >= 2006 and calcOrigYear_LL<=2017
 and refi_incentive >= -150 and refi_incentive<=-50
 and asOf>='19900101' and asOf<='29990101'
 and agency in ( 'FHL')
 and asof = '2013-01-01'
group by 
    originationDate
order by 
	groupByColumn

 
 select * from fhl.SecfactorView sf
 
 
 
 
 
 
 select 
 PREPAY_CPR1 = 100*(1.0 - power(sum(1 * m.currentBalance)/sum(1* m.calcSchamBalance), 12))
 ,Balance = sum(1*m.schamBalance)
,LoanCount = sum(1*m.currNumLoans)
 ,calcOrigMonth
from
(
select 
sf.issueId,
sf.asOf 
from
fhl.SecfactorView sf
where
sf.schamBalance > 0.1

 and ( 1=2 OR 
sf.marketTicker LIKE 'FGLMC')
 and sf.calcOrigYear >= 2006 and sf.calcOrigYear<=2017
 and sf.refi_incentive >= -150 and sf.refi_incentive<=-50
 ) pools
join fhl.SecFactorView m on m.issueID = pools.issueId and m.asOf = pools.asOf
--join scale.fhl_poolHist sph on sph.issueId = m.issueId
where
 m.schamBalance > 0.1
 and m.asof = '2013-01-01'
--and m.asOf>='19940101' and m.asOf<='29990101'
group by calcOrigMonth

 
 
 
 
SELECT 
 originationDate,
 sum(balance)
FROM  scale.fhl_loanHist slh
 JOIN scale.fhl_loan sl ON slh.loanSeqNum = sl.loanSeqNum
 JOIN scale.fhl_loanIncentive sli on slh.loanSeqNum = sli.loanSeqNum AND slh.asof = sli.asof
WHERE sli.asof = '2013-01-01'
 AND conventional_refi_incentive >= -150
 AND conventional_refi_incentive <= -50
GROUP BY originationDate
 
 
SELECT 
 originationDate,
 sum(balance)
FROM  scale.fhl_poolHist sph
  JOIN scale.fhl_poolIncentive spi on sph.issueId = spi.issueId AND sph.asof = spi.asof
 WHERE spi.asof = '2013-01-01'
 AND conventional_refi_incentive >= -150
 AND conventional_refi_incentive <= -50
 GROUP BY originationDate
 
 
 -------------------------------------------------
SELECT 
 *
FROM  scale.fhl_loanHist slh
 JOIN scale.fhl_loan sl ON slh.loanSeqNum = sl.loanSeqNum
 JOIN scale.fhl_loanIncentive sli on slh.loanSeqNum = sli.loanSeqNum AND slh.asof = sli.asof
WHERE sli.asof = '2013-01-01'
-- AND conventional_refi_incentive >= -150
-- AND conventional_refi_incentive <= -50
 AND originationDate = '2009-09-01'
  ORDER by conventional_refi_incentive
 
SELECT 
 *
FROM  scale.fhl_poolHist sph
  JOIN scale.fhl_poolIncentive spi on sph.issueId = spi.issueId AND sph.asof = spi.asof
 WHERE spi.asof = '2013-01-01'
-- AND conventional_refi_incentive >= -150
-- AND conventional_refi_incentive <= -50
 AND originationDate = '2009-09-01'
 ORDER by conventional_refi_incentive
 
 
 -------------------------------------------------------
 

SELECT 
 sph.issueId,
 spi.conventional_refi_incentive as conventional_refi_incentive_pool,
 sum(sli.conventional_refi_incentive * slh.balance) / sum(CASE WHEN sli.conventional_refi_incentive IS NULL THEN 0.0 ELSE slh.balance END) as conventional_refi_incentive_loan
FROM  scale.fhl_poolHist sph
 JOIN scale.fhl_poolIncentive spi on sph.issueId = spi.issueId AND sph.asof = spi.asof
 JOIN fhl.PIV_Loan cl ON spi.issueId = cl.issueId
 JOIN scale.fhl_loanIncentive sli on cl.loanSeqNum = sli.loanSeqNum AND sph.asof = sli.asof
 JOIN scale.fhl_loanHist slh on  slh.loanSeqNum = sli.loanSeqNum AND slh.asof = sli.asof
 WHERE spi.asof = '2013-01-01'
-- AND conventional_refi_incentive >= -150
-- AND conventional_refi_incentive <= -50
 AND originationDate = '2009-09-01'
 AND sph.issueId = 1561497
 group by sph.issueId, conventional_refi_incentive_pool
 ORDER by spi.conventional_refi_incentive
 
 
SELECT *
 FROM fhl.PIV_Loan cl --ON spi.issueId = cl.issueId
 WHERE  loanSeqNum = 'A88935000040'
 
 ---------------------------------------------------------------------
 
 SELECT 
 sph.issueId,
 spi.conventional_refi_incentive as conventional_refi_incentive_pool,
 sli.loanSeqNum,
 sli.conventional_refi_incentive as conventional_refi_incentive_loan,
 slh.balance
-- sum(sli.conventional_refi_incentive * slh.balance) / sum(CASE WHEN sli.conventional_refi_incentive IS NULL THEN 0.0 ELSE slh.balance END) as conventional_refi_incentive_loan
FROM  scale.fhl_poolHist sph
 JOIN scale.fhl_poolIncentive spi on sph.issueId = spi.issueId AND sph.asof = spi.asof
 JOIN fhl.PIV_Loan cl ON spi.issueId = cl.issueId
 JOIN scale.fhl_loanIncentive sli on cl.loanSeqNum = sli.loanSeqNum AND sph.asof = sli.asof
 JOIN scale.fhl_loanHist slh on  slh.loanSeqNum = sli.loanSeqNum AND slh.asof = sli.asof
 WHERE spi.asof = '2013-01-01'
-- AND conventional_refi_incentive >= -150
-- AND conventional_refi_incentive <= -50
 AND originationDate = '2009-09-01'
 AND sph.issueId = 1561497
-- group by sph.issueId, conventional_refi_incentive_pool
-- ORDER by spi.conventional_refi_incentive
 
 ----------------------------------------------------------------------
SELECT 
 sli.asof,
 sum(slh.balance) as currBal,
 sum(cl.origNoteRate * slh.balance) / sum(CASE WHEN cl.origNoteRate IS NULL THEN 0.0 ELSE slh.balance END) as origNoteRate,
 sum(clh.loanAge * slh.balance) / sum(CASE WHEN clh.loanAge IS NULL THEN 0.0 ELSE slh.balance END) as WALA,
 sum(CASE WHEN sli.conventional_refi_incentive > sli.FHA_refi_incentive THEN sli.conventional_refi_incentive ELSE sli.FHA_refi_incentive END * slh.balance) / sum(CASE WHEN sli.conventional_refi_incentive IS NULL THEN 0.0 ELSE slh.balance END) as incentive,
 100*(1.0 - power(sum(1*v.currentRpb)/sum(1*v.calcScham), 12)) AS CPR
FROM  scale.fhl_loanHist slh
 JOIN scale.fhl_loan sl ON slh.loanSeqNum = sl.loanSeqNum
 JOIN scale.fhl_loanIncentive sli ON slh.loanSeqNum = sli.loanSeqNum AND slh.asof = sli.asof
 JOIN fhl.PIV_loan cl ON slh.loanSeqNum = cl.loanSeqNum
 JOIN fhl.PIV_loanHist clh ON slh.loanSeqNum = clh.loanSeqNum AND clh.asof = sli.asof
 JOIN FHL.PIV_LoanView v ON slh.loanSeqNum = v.loanSeqNum AND v.asof = sli.asof
WHERE 1=1
-- AND sli.asof = '2013-01-01'
-- AND CASE WHEN sli.conventional_refi_incentive > sli.FHA_refi_incentive THEN sli.conventional_refi_incentive ELSE sli.FHA_refi_incentive END >= -150
-- AND CASE WHEN sli.conventional_refi_incentive > sli.FHA_refi_incentive THEN sli.conventional_refi_incentive ELSE sli.FHA_refi_incentive END <= -50
-- AND originationDate >= '2006-01-01'
 and v.refi_incentive >= -150 and v.refi_incentive<=-50
 AND v.calcOrigMonth_LL >= 200601
 and v.schamBalance > 0.1
 AND sl.marketTicker = 'FGLMC'
  GROUP BY sli.asof
 
SELECT 
 sph.asof,
 sum(sph.balance) as currBal,
 sum(sph.origNoteRate * sph.balance) / sum(CASE WHEN sph.origNoteRate IS NULL THEN 0.0 ELSE sph.balance END) as origNoteRate,
 sum(sf.wala * sph.balance) / sum(CASE WHEN sf.wala IS NULL THEN 0.0 ELSE sph.balance END) as WALA,
 sum(spi.refi_incentive * sph.balance) / sum(CASE WHEN spi.refi_incentive IS NULL THEN 0.0 ELSE sph.balance END) as incentive,
 100*(1.0 - power(sum(1 * v.currentBalance)/sum(1* v.calcSchamBalance), 12)) AS CPR
FROM  scale.fhl_poolHist sph
  JOIN scale.fhl_poolIncentive spi on sph.issueId = spi.issueId AND sph.asof = spi.asof
  JOIN fhl.secfactor sf ON sph.issueId = sf.issueId AND sph.asof = sf.asof
  JOIN fhl.SecfactorView v ON sph.issueId = v.issueId AND sph.asof = v.asof
 WHERE 1=1
-- AND spi.refi_incentive >= -150
-- AND spi.refi_incentive <= -50
 AND v.refi_incentive >= -150
 AND v.refi_incentive <= -50
 AND originationDate >= '2006-01-01'
 AND sph.asof >= '2006-09-01'
 AND sph.marketTicker = 'FGLMC'
 AND v.schamBalance > 0.1
 GROUP BY sph.asof
 
---------------------------------------------------------------------
 
 select refi_incentive, sli.* from FHL.PIV_LoanView v JOIN scale.fhl_loanIncentive sli ON sli.loanSeqNum = v.loanSeqNum AND v.asof = sli.asof
 where sli.conventional_refi_incentive < sli.FHA_refi_incentive
 
  select v.refi_incentive, sli.* from fhl.SecfactorView v JOIN scale.fhl_PoolIncentive sli ON sli.issueId = v.issueId AND v.asof = sli.asof
 where sli.conventional_refi_incentive < sli.FHA_refi_incentive
 
 
 
