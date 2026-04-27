-----Total Issuance
select distinct marketTicker, product from fhl.sec p

select p.marketTicker,
sum(p.issueAmount),
p.issueDate
from fnm.sec p
where p.collateralType = 'LOAN' 
and p.marketTicker in ('FNCL', 'FGLMC', 'FNCQ30', 'FGU6', 'FNCR', 'FGU9', 'FNCK', 'FGT6', 'FNNP', 'FNNQ', 'FNNO', 'FNNJ')
and p.issueDate >= '19980101'
group by p.marketTicker, p.issueDate
order by p.marketTicker, p.issueDate

select  
sum(p.issueAmount),
p.issueDate
from fnm.sec p
where p.collateralType = 'LOAN' 
and p.marketTicker in ('FNCL', 'FGLMC', 'FNCQ30', 'FGU6', 'FNCR', 'FGU9', 'FNCK', 'FGT6', 'FNNP', 'FNNQ', 'FNNO', 'FNNJ')
and p.issueDate >= '19980101'
group by   p.issueDate
order by   p.issueDate

select *
from fhl.sec p
where p.collateralType = 'LOAN' 
and p.marketTicker in (  'FGT6')
and p.issueDate = '20080501'
group by p.marketTicker, p.issueDate
order by p.marketTicker, p.issueDate


select  marketTicker, product, sum(issueAmount) 
from fnm.sec where product =  'FNM30INITIO' group by product, marketTicker

select * from fnm.sec

---Loan Balance Spec
select p.marketTicker,
asOf = min(q.asOf),
p.issueId 
into #tempAOLS
from fnm.sec p, fnm.aolsQuartile q
where p.issueId  = q.issueId 
and p.marketTicker in ('FNCL', 'FGLMC', 'FNCQ30', 'FGU6', 'FNCR', 'FGU9')
and q.q4Max > 0.01
group by p.marketTicker, p.issueId

drop table #tempAOLS
select * from #tempAOLS

select p.marketTicker,
bucket = (case 
--               when q.q4Max <= 85000  then 'LLB'
--               when q.q4Max <= 110000 then 'MLB'
--               when q.q4Max <= 150000 then 'HLB'
               when q.q4Max <= 175000 then '175K'
               else 'TBA' end),
sum(p.issueAmount),
p.issueDate
from fnm.sec p, fnm.aolsQuartile q, #tempAOLS t
where p.issueId = q.issueId
and p.issueId = t.issueId
and q.asOf = t.asOf
and p.collateralType = 'LOAN' 
--and p.marketTicker in ('FNCL', 'FGLMC', 'FNCQ30', 'FGU6', 'FNCR', 'FGU9')
and p.marketTicker in ('FNCL', 'FGLMC')
and p.issueDate >= '19980101'
group by p.marketTicker, p.issueDate, bucket
order by p.marketTicker, bucket, p.issueDate


--------MHA ---------------------No filter on min LTV
select distinct distributionType from fnm.loanPurposeDist where loans < 0 9999999
select * from fnm.loanPurposeDist
select * from fnm.secsummary

select p.marketTicker,
asOf = min(q.asOf),
p.issueId 
into #tempPurpose
from fnm.sec p, fnm.loanPurposeDist q
where p.issueId  = q.issueId 
and p.marketTicker in ('FNCL', 'FGLMC', 'FNCQ30', 'FGU6', 'FNCR', 'FGU9')
group by p.marketTicker, p.issueId

drop table #tempPurpose

select p.marketTicker,
bucket = (case when p.waoltv < 0   then '-999' 
               when p.waoltv <= 80 then '<= 80'
               else 'MHA' end),
sum(s.issueAmount),
s.issueDate
from fnm.secsummary p, fnm.loanPurposeDist q, #tempPurpose t, fnm.sec s
where p.issueId = q.issueId
and p.issueId = s.issueId
and p.issueId = t.issueId
and p.asOf = q.asOf
and q.asOf = t.asOf
and s.collateralType = 'LOAN' 
and q.distributionType = 'RE-FI'
and q.percentRpb >= 100.0
--and p.marketTicker in ('FNCL', 'FGLMC', 'FNCQ30', 'FGU6', 'FNCR', 'FGU9')
and p.marketTicker in ('FNCL', 'FGLMC')
and p.issueDate >= '19980101'
group by p.marketTicker, s.issueDate, bucket
order by p.marketTicker, bucket, s.issueDate

--------MHA with Filter on OLTV
select distinct distributionType from fnm.loanPurposeDist where loans < 0 9999999
select * from fnm.loanPurposeDist
select * from fnm.secsummary

select p.marketTicker,
asOf = min(q.asOf),
p.issueId 
into #tempPurpose
from fnm.sec p, fnm.loanPurposeDist q
where p.issueId  = q.issueId 
and p.marketTicker in ('FNCL', 'FGLMC', 'FNCQ30', 'FGU6', 'FNCR', 'FGU9')
group by p.marketTicker, p.issueId

drop table #tempPurpose
drop table #tempRefi
drop table #tempLTV

select p.marketTicker,
p.issueId
into #tempRefi
from  fnm.loanPurposeDist q, #tempPurpose t, fnm.sec p
where p.issueId = q.issueId
and p.issueId = t.issueId
and q.asOf = t.asOf
and p.collateralType = 'LOAN' 
and q.distributionType = 'RE-FI'
and q.percentRpb >= 100.0
--and p.marketTicker in ('FNCL', 'FGLMC', 'FNCQ30', 'FGU6', 'FNCR', 'FGU9')
and p.marketTicker in ('FNCL', 'FGLMC')
and p.issueDate >= '19980101'
group by p.marketTicker, p.issueId

select p.marketTicker,
asOf = min(q.asOf),
p.issueId 
into #tempLTV
from fnm.sec p, fnm.WAOLTVQuartile q
where p.issueId  = q.issueId 
and p.collateralType = 'LOAN' 
and q.q1Min > 80
and p.marketTicker in ('FNCL', 'FGLMC', 'FNCQ30', 'FGU6', 'FNCR', 'FGU9')
group by p.marketTicker, p.issueId



select p.marketTicker,
sum(p.issueAmount),
p.issueDate
from  fnm.sec p, #tempRefi s, #tempLTV t, fnm.waoltvQuartile q
where p.issueId = s.issueId
and p.issueId = t.issueId
and p.issueId = q.issueId
and q.asOf = t.asOf
and p.marketTicker in ('FNCL', 'FGLMC')
and p.issueDate >= '19980101'
group by p.marketTicker, p.issueDate 
order by p.marketTicker, p.issueDate

-----------------------------------------------------------------------------
select * from fnm.WAOLTVQuartile q
select distinct distributionType from fnm.loanpurposeDist q

select * from fnm.loanpurposeDist q, fnm.loanPurposeDist q2
where q.issueId = q2.issueId
and q.asOf = q2.asOf
and q.distributionType in ('RE-FI')
and q2.distributionType in ('PURCH')
and q.percentRpb + q2.percentRpb < 100

select *
from fnm.sec p, #tempRefi s, fnm.secSummary f, fnm.WAOLTVQuartile q
where p.issueId = s.issueId
and p.issueId = f.issueId
and p.issueID = q.issueId
and f.asOf = q.asOf
and f.waoltv > 80
and q.q1Min <= 80
and q.q1Min > 0
and p.marketTicker in ('FNCL', 'FGLMC')



-----100% Investor-----------------------------------------------------------------
select p.marketTicker,
asOf = min(q.asOf),
p.issueId,
p.poolNumber 
into #tempInvestor1
from fnm.sec p, fnm.occupancyDist q
where p.issueId  = q.issueId 
and p.collateralType = 'LOAN' 
and p.marketTicker in ('FNCL', 'FGLMC', 'FNCQ30', 'FGU6', 'FNCR', 'FGU9')
group by p.marketTicker, p.issueId, p.poolNumber

select p.marketTicker,
NonInvestorPct = sum(case when q.distributionType in ('OWNER','2ND') then q.percentRpb else 0 end),
p.issueId,
p.poolNumber 
into #tempInvestor
from fnm.sec p, fnm.occupancyDist q, #tempInvestor1 t
where p.issueId  = q.issueId 
and p.issueId = t.issueId
and q.asOf = t.asOf
and p.marketTicker in ('FNCL', 'FGLMC', 'FNCQ30', 'FGU6', 'FNCR', 'FGU9')
group by p.marketTicker, p.issueId, p.poolNumber 

select p.marketTicker,
sum(p.issueAmount),
p.issueDate
from fnm.sec p,  #tempInvestor t
where p.issueId = t.issueId
and p.marketTicker in ('FNCL', 'FGLMC')
and t.NonInvestorPct <= 0.0
and p.issueDate >= '19980101'
--and p.poolNumber = 'AO7390'
group by p.marketTicker, p.issueDate 
order by p.marketTicker, p.issueDate 

drop table #tempInvestor1
drop table #tempInvestor

-----100% Non-Owner

select p.marketTicker,
asOf = min(q.asOf),
p.issueId,
p.poolNumber 
into #tempNonOwner1
from fnm.sec p, fnm.occupancyDist q
where p.collateralType = 'LOAN' 
and p.issueId  = q.issueId 
and p.marketTicker in ('FNCL', 'FGLMC', 'FNCQ30', 'FGU6', 'FNCR', 'FGU9')
group by p.marketTicker, p.issueId, p.poolNumber


select p.marketTicker,
OwnerPct = sum(case when q.distributionType = 'OWNER' then q.percentRpb else 0 end),
p.issueId,
p.poolNumber 
into #tempNonOwner
from fnm.sec p, fnm.occupancyDist q, #tempNonOwner1 t
where p.issueId  = q.issueId 
and p.issueId = t.issueId
and q.asOf = t.asOf
and p.marketTicker in ('FNCL', 'FGLMC', 'FNCQ30', 'FGU6', 'FNCR', 'FGU9')
group by p.marketTicker, p.issueId, p.poolNumber 


select p.marketTicker,
sum(p.issueAmount),
p.issueDate
from fnm.sec p,  #tempNonOwner t
where p.issueId = t.issueId
and p.marketTicker in ('FNCL', 'FGLMC')
and t.OwnerPct <= 0.0
and p.issueDate >= '20120101'
 and p.poolNumber = 'AO7390'
group by p.marketTicker, p.issueDate 
order by p.marketTicker, p.issueDate 


select * from #tempNonOwner where poolNumber = 'AK4499'
select * from #tempNonOwner where poolNumber = 'AO7390'
select * from #tempNonOwner where poolNumber = 'AJ9734'
drop table #tempNonOwner1


select *
from fnm.sec p, fnm.occupancyDist q, #tempNonOwner1 t
where p.issueId  = q.issueId 
and p.issueId = t.issueId
and q.asOf = t.asOf
--and t.poolNumber = 'AO7390'
and t.poolNumber = 'AJ9734'
and p.marketTicker in ('FNCL', 'FGLMC', 'FNCQ30', 'FGU6', 'FNCR', 'FGU9')


---------------------Low FICO
select p.marketTicker,
asOf = min(q.asOf),
p.issueId,
p.poolNumber 
into #tempFICO
from fnm.sec p, fnm.WAOCSQuartile q
where p.issueId  = q.issueId 
and p.collateralType = 'LOAN'
and q.q4Max > 0
and p.marketTicker in ('FNCL', 'FGLMC', 'FNCQ30', 'FGU6', 'FNCR', 'FGU9')
group by p.marketTicker, p.issueId, p.poolNumber

drop table #tempFICO
select * from #tempFICO where  poolNumber = 'AK1522'


select p.marketTicker,
sum(p.issueAmount),
p.issueDate
from fnm.sec p, fnm.WAOCSQuartile q,  #tempFICO t
where p.issueId = t.issueId
and p.issueId = q.issueId
and q.asOf = t.asOf
and p.marketTicker in ('FNCL', 'FGLMC')
and q.q4Max < 700
and q.q4Max > 0
and p.issueDate >= '19980101'
--and p.poolNumber = 'AK1522'
group by p.marketTicker, p.issueDate 
order by p.marketTicker, p.issueDate 


select *
from fnm.sec p, fnm.WAOCSQuartile q
where p.issueId = q.issueId
and p.issueDate >= '20111001'
and p.collateralType = 'LOAN'
and p.poolNumber = 'AK1522'
--and q.q4Max < 0
order by p.productionMonth DESC
and p.poolNumber = 'AQ9050'
and p.poolNumber = 'AK1522'


------------------------------100% Geo
select p.marketTicker,
asOf = min(q.asOf),
p.issueId,
p.poolNumber 
into #tempGeo
from fnm.sec p, fnm.geoDist q
where p.issueId  = q.issueId 
and p.collateralType = 'LOAN'
and q.state in ('ZZ')
and q.loans > 0
and p.marketTicker in ('FNCL', 'FGLMC', 'FNCQ30', 'FGU6', 'FNCR', 'FGU9')
group by p.marketTicker, p.issueId, p.poolNumber


select p.marketTicker,
sum(p.issueAmount),
p.issueDate,
q.state
from fnm.sec p, fnm.geoDist q,  #tempGeo t
where p.issueId = t.issueId
and p.issueId = q.issueId
and q.asOf = t.asOf
and p.marketTicker in ('FNCL', 'FGLMC')
and q.state in ('NY', 'TX', 'FL', 'PR')
and q.state in ( 'FL')
--and q.state in (  'NY')
and q.percentRPB = 100.0
and p.issueDate >= '19980101'
--and p.poolNumber = 'AK1522'
group by p.marketTicker, p.issueDate, q.state
order by p.marketTicker, q.state, p.issueDate 

drop table #tempGeo
select * from fnm.geoDist where percentRPB < 0


select datediff(mm, '20120101','20120201')

select * from fnm.secSummary

select * from fnm.WAOCSQuartile

-----------------------Jumbo
select  
sum(p.issueAmount),
p.issueDate
from fnm.sec p
where p.collateralType = 'LOAN' 
and p.marketTicker in ('FNCL', 'FGLMC', 'FNCQ30', 'FGU6', 'FNCR', 'FGU9', 'FNCK', 'FGT6', 'FNNP', 'FNNQ', 'FNNO', 'FNNJ')
and p.marketTicker in ('FNCK')
and p.issueDate >= '19980101'
group by   p.issueDate
order by   p.issueDate


-----------------------CQ
select  
sum(p.issueAmount),
p.issueDate
from fnm.sec p
where p.collateralType = 'LOAN' 
and p.marketTicker in ('FNCL', 'FGLMC', 'FNCQ30', 'FGU6', 'FNCR', 'FGU9', 'FNCK', 'FGT6', 'FNNP', 'FNNQ', 'FNNO', 'FNNJ')
and p.marketTicker in ('FNCQ30')
and p.issueDate >= '19980101'
group by   p.issueDate
order by   p.issueDate


-----------------------CR
select  
sum(p.issueAmount),
p.issueDate
from fnm.sec p
where p.collateralType = 'LOAN' 
and p.marketTicker in ('FNCL', 'FGLMC', 'FNCQ30', 'FGU6', 'FNCR', 'FGU9', 'FNCK', 'FGT6', 'FNNP', 'FNNQ', 'FNNO', 'FNNJ')
and p.marketTicker in ('FNCR')
and p.issueDate >= '19980101'
group by   p.issueDate
order by   p.issueDate


-----------------------Fixed Rate IO
select  
sum(p.issueAmount),
p.issueDate
from fnm.sec p
where p.collateralType = 'LOAN' 
and p.marketTicker in ('FNCL', 'FGLMC', 'FNCQ30', 'FGU6', 'FNCR', 'FGU9', 'FNCK', 'FGT6', 'FNNP', 'FNNQ', 'FNNO', 'FNNJ')
and p.marketTicker in ('FNNP', 'FNNQ', 'FNNO', 'FNNJ')
and p.issueDate >= '19980101'
group by   p.issueDate
order by   p.issueDate