delete LoanPrepayTracking p
from staging_LoanPrepayTracking s
where p.modelId = s.modelId
and p.loanSeqNum = s.loanSeqNum
and p.asOf = s.asOf 

insert LoanPrepayTracking select * from staging_LoanPrepayTracking 