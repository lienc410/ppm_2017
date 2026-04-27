delete LoanPrepayTracking p
from staging_LoanPrepayTracking s
where p.modelId = s.modelId
and p.loanSeqNum = s.loanSeqNum
and p.asOf = s.asOf 

insert into LoanPrepayTracking 
select 
loanseqnum,
issueId,
asOf,
modelId,
cast(smmCurtail as numeric(9,8)) as smmCurtail,
cast(smmDefault as numeric(9,8)) as smmDefault,
cast(smmTurnover as numeric(9,8)) as smmTurnover,
cast(smmCashout as numeric(9,8)) as smmCashout,
cast(smmRefinance as numeric(9,8)) as smmRefinance,
cast(smmTotal as numeric(9,8)) as smmTotal,
cast((smmCurtail+smmTurnover+smmCashout+smmRefinance) as numeric(9,8)) as SMM_CRR,
cast(smmDefault as numeric(9,8)) as SMM_CDR
from staging_LoanPrepayTracking 