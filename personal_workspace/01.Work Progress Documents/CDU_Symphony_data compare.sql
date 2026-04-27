
commit;


select

HARP_eligible = sum(spe.HARP_eligible * CollateralContributionFactor * m.currentBalance)/sum(CollateralContributionFactor  * m.currentBalance),
dimensionCombination = 'ALGORITHM:TICKER',
factorDate = m.asOf,
modifyDate = m.asOf,
sliceId = 'TICKER:FGLMC',
wacls = sum(m.currentBalance * CollateralContributionFactor) / sum(m.currNumLoans),-- * m.currentBalance)/sum(CollateralContributionFactor  * m.currentBalance),
ols = sum(m.waolSize * CollateralContributionFactor) / sum(m.currNumLoans),
burnout = sum(spb.burnout * CollateralContributionFactor * m.currentBalance)/sum(CollateralContributionFactor  * m.currentBalance),
cpr = 100*(1.0 - power(sum(CollateralContributionFactor * m.currentBalance)/sum(CollateralContributionFactor  * m.calcSchamBalance), 12)),
bal = sum(CollateralContributionFactor * m.currentBalance),
currLLPA = sum(spi.currLLPA * CollateralContributionFactor * m.currentBalance)/sum(CollateralContributionFactor  * m.currentBalance),
currMIP = sum(spi.currMIP * CollateralContributionFactor * m.currentBalance)/sum(CollateralContributionFactor  * m.currentBalance),
currPMI = sum(spi.currPMI * CollateralContributionFactor * m.currentBalance)/sum(CollateralContributionFactor  * m.currentBalance),
pct_dq = sum(CASE WHEN percentDELQ30plus IS NOT NULL THEN percentDELQ30plus ELSE Est_Pct_DELQ30plus END * CollateralContributionFactor * m.currentBalance)/sum(CollateralContributionFactor  * m.currentBalance),
pct_fha = 0.0,
pct_HARPed = sum(spd.percentHARPed * CollateralContributionFactor * m.currentBalance)/sum(CollateralContributionFactor  * m.currentBalance),
pct_inv = sum(spd.percentOCC_INV * CollateralContributionFactor * m.currentBalance)/sum(CollateralContributionFactor  * m.currentBalance),
issueDate = '20120101',
origMIP = 0.0,
origPMI = sum(spi.origPMI * CollateralContributionFactor * m.currentBalance)/sum(CollateralContributionFactor  * m.currentBalance),
pct_owner = sum(spd.percentOCC_OWN * CollateralContributionFactor * m.currentBalance)/sum(CollateralContributionFactor  * m.currentBalance),
poolListName_ =  'FHL30.400.12(GEN)',
refi_elig_pct =  sum(spe.refi_eligible * CollateralContributionFactor * m.currentBalance)/sum(CollateralContributionFactor  * m.currentBalance),
incentive = sum(m.refi_incentive * CollateralContributionFactor * m.currentBalance)/sum(CollateralContributionFactor  * m.currentBalance),
pct_REFI = sum(spd.percentPURP_REFI * CollateralContributionFactor * m.currentBalance)/sum(CollateralContributionFactor  * m.currentBalance),
replineMode = 'PL',
origbal = 0.0,
pct_2nd = sum(spd.percentOCC_2ND * CollateralContributionFactor * m.currentBalance)/sum(CollateralContributionFactor  * m.currentBalance),
pct_tpo = sum((spd.percentCHANNEL_BROKER + spd.percentCHANNEL_CORRES) * CollateralContributionFactor * m.currentBalance)/sum(CollateralContributionFactor  * m.currentBalance),
cltv = sum(m.waCLTV * CollateralContributionFactor * m.currentBalance)/sum(CollateralContributionFactor  * m.currentBalance),
odti = 0.0,
fico = sum(m.waocs * CollateralContributionFactor * m.currentBalance)/sum(CollateralContributionFactor  * m.currentBalance),
oltv = sum(m.waoltv * CollateralContributionFactor * m.currentBalance)/sum(CollateralContributionFactor  * m.currentBalance),
sato = sum(m.SATO * CollateralContributionFactor * m.currentBalance)/sum(CollateralContributionFactor  * m.currentBalance),
wac = sum(m.wac * CollateralContributionFactor * m.currentBalance)/sum(CollateralContributionFactor  * m.currentBalance),
wala = sum(m.wala * CollateralContributionFactor * m.currentBalance)/sum(CollateralContributionFactor  * m.currentBalance),
wam = sum(m.wam * CollateralContributionFactor * m.currentBalance)/sum(CollateralContributionFactor  * m.currentBalance)
from 
 fhl.SecFactorView m  
join CollateralAnalysis_PoolList p on p.issueID = m.issueId and poolListName = 'FHL30.400.12(GEN)'
join scale.FHL_POOLBurnout spb ON spb.issueId = m.issueId and spb.asof = m.asof
join scale.FHL_POOLdistribution spd ON spd.issueId = m.issueId and spd.asof = m.asof
join scale.FHL_POOLeligibility spe ON spe.issueId = m.issueId and spe.asof = m.asof
join scale.FHL_POOLIncentive spi ON spi.issueId = m.issueId and spi.asof = m.asof
where
 m.schamBalance > 0.1
and spb.version = '2.40'
 and m.asof is NOT NULL
-- and m.asOf='2017-03-01' 
group by m.asof
order by m.asof

select *
from 
 fhl.SecFactorView m m pe ON spe.issueId = m.issueId and spe.asof = m.asof
join scale.FHL_POOLIncentive spi ON spi.issueId = m.issueId and spi.asof = m.asof
join scale.FHL_POOLBurnout spb ON spb.issueId = m.issueId and spb.asof = m.asof
where
 m.schamBalance > 0.1
and spi.version = '2.00'
and spb.version = '2.40'
group by m.asof
order by m.asof

commit;


select

HARP_eligible = sum(spe.HARP_eligible * CollateralContributionFactor * m.currentBalance)/sum(CollateralContributionFactor  * m.currentBalance),
dimensionCombination = 'ALGORITHM:TICKER',
factorDate = m.asOf,
modifyDate = m.asOf,
sliceId = 'TICKER:FGLMC',
wacls = sum(m.waclsize * CollateralContributionFactor * m.currentBalance)/sum(CollateralContributionFactor  * m.currentBalance),
ols = sum(m.waolsize * CollateralContributionFactor * m.currentBalance)/sum(CollateralContributionFactor  * m.currentBalance),
burnout = sum(spb.burnout * CollateralContributionFactor * m.currentBalance)/sum(CollateralContributionFactor  * m.currentBalance),
cpr = 100*(1.0 - power(sum(CollateralContributionFactor * m.currentBalance)/sum(CollateralContributionFactor  * m.currentBalance), 12)),
bal = sum(CollateralContributionFactor*m.schamBalance),
currLLPA = sum(spi.currLLPA * CollateralContributionFactor * m.currentBalance)/sum(CollateralContributionFactor  * m.currentBalance),
currMIP = sum(spi.currMIP * CollateralContributionFactor * m.currentBalance)/sum(CollateralContributionFactor  * m.currentBalance),
currPMI = sum(spi.currPMI * CollateralContributionFactor * m.currentBalance)/sum(CollateralContributionFactor  * m.currentBalance),
pct_dq = sum(CASE WHEN percentDELQ30plus IS NOT NULL THEN percentDELQ30plus ELSE Est_Pct_DELQ30plus END * CollateralContributionFactor * m.currentBalance)/sum(CollateralContributionFactor  * m.currentBalance),
pct_fha = 0.0,
pct_HARPed = sum(spd.percentHARPed * CollateralContributionFactor * m.currentBalance)/sum(CollateralContributionFactor  * m.currentBalance),
pct_inv = sum(spd.percentOCC_INV * CollateralContributionFactor * m.currentBalance)/sum(CollateralContributionFactor  * m.currentBalance),
issueDate = '20120101',
origMIP = 0.0,
origPMI = sum(spi.origPMI * CollateralContributionFactor * m.currentBalance)/sum(CollateralContributionFactor  * m.currentBalance),
pct_owner = sum(spd.percentOCC_OWN * CollateralContributionFactor * m.currentBalance)/sum(CollateralContributionFactor  * m.currentBalance),
poolListName_ =  'FHL30.400.12(GEN)',
refi_elig_pct =  sum(spe.refi_eligible * CollateralContributionFactor * m.currentBalance)/sum(CollateralContributionFactor  * m.currentBalance),
incentive = sum(m.refi_incentive * CollateralContributionFactor * m.currentBalance)/sum(CollateralContributionFactor  * m.currentBalance),
pct_REFI = sum(spd.percentPURP_REFI * CollateralContributionFactor * m.currentBalance)/sum(CollateralContributionFactor  * m.currentBalance),
replineMode = 'PL',
origbal = 0.0,
pct_2nd = sum(spd.percentOCC_2ND * CollateralContributionFactor * m.currentBalance)/sum(CollateralContributionFactor  * m.currentBalance),
pct_tpo = sum((spd.percentCHANNEL_BROKER + spd.percentCHANNEL_CORRES) * CollateralContributionFactor * m.currentBalance)/sum(CollateralContributionFactor  * m.currentBalance),
cltv = sum(m.waCLTV * CollateralContributionFactor * m.currentBalance)/sum(CollateralContributionFactor  * m.currentBalance),
odti = 0.0,
fico = sum(m.waocs * CollateralContributionFactor * m.currentBalance)/sum(CollateralContributionFactor  * m.currentBalance),
oltv = sum(m.waoltv * CollateralContributionFactor * m.currentBalance)/sum(CollateralContributionFactor  * m.currentBalance),
sato = sum(m.SATO * CollateralContributionFactor * m.currentBalance)/sum(CollateralContributionFactor  * m.currentBalance),
wac = sum(m.wac * CollateralContributionFactor * m.currentBalance)/sum(CollateralContributionFactor  * m.currentBalance),
wala = sum(m.wala * CollateralContributionFactor * m.currentBalance)/sum(CollateralContributionFactor  * m.currentBalance),
wam = sum(m.wam * CollateralContributionFactor * m.currentBalance)/sum(CollateralContributionFactor  * m.currentBalance)
from 
 fhl.SecFactorView m  
join CollateralAnalysis_PoolList p on p.issueID = m.issueId and poolListName = 'FHL30.400.12(GEN)'
join scale.FHL_POOLBurnout spb ON spb.issueId = m.issueId and spb.asof = m.asof
join scale.FHL_POOLdistribution spd ON spd.issueId = m.issueId and spd.asof = m.asof
join scale.FHL_POOLeligibility spe ON spe.issueId = m.issueId and spe.asof = m.asof
join scale.FHL_POOLIncentive spi ON spi.issueId = m.issueId and spi.asof = m.asof
where
 m.schamBalance > 0.1
and spb.version = '2.40'
 and m.asof is NOT NULL
 and m.asOf='2017-03-01' 
group by m.asof
order by m.asof.asof
order by m.asofasoffy m.asoffrder by m.asofrder by m.asof
