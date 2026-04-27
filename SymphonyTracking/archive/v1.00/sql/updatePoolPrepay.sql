delete PoolPrepayTracking p
from staging_PoolPrepayTracking s
where p.modelId = s.modelId
and p.issueId = s.issueId
and p.asOf = s.asOf 

insert PoolPrepayTracking from staging_PoolPrepayTracking 
