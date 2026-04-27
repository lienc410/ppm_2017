delete PoolPrepayTracking p
from staging_PoolPrepayTracking s
where p.modelId = s.modelId
and p.issueId = s.issueId
and p.asOf = s.asOf 

insert PoolPrepayTracking(issueId,asOf,modelId,smmCurtail,smmDeFault,smmTurnover,smmCashout,smmRefinance,smmTotal,smm_CRR,smm_CDR)
select
issueId,
asOf,
modelId,
smmCurtail,
smmDeFault,
smmTurnover,
smmCashout,
smmRefinance,
smmTotal,
(smmCurtail+smmTurnover+smmCashout+smmRefinance) as smm_CRR,
smmDeFault as smm_CDR
from staging_PoolPrepayTracking 
