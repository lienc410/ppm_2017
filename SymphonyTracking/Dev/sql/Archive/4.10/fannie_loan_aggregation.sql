INSERT @POOL_TABLE@ 
SELECT 
    issueId = cl.issueId,
    asof = p.asof,
    modelId = NULL,
    smmCurtail = sum(slh.balance * p.smmCurtail) / sum(slh.balance),
    smmDefault = sum(slh.balance * p.smmDefault) / sum(slh.balance),
    smmTurnover = sum(slh.balance * p.smmTurnover) / sum(slh.balance),
    smmCashout = sum(slh.balance * p.smmCashout) / sum(slh.balance),
    smmRefinance = sum(slh.balance * p.smmRefinance) / sum(slh.balance),
    smmTotal = sum(slh.balance * p.smmTotal) / sum(slh.balance)
FROM @LOAN_TABLE@ p
JOIN scale.fnm_loanhist slh ON p.loanSeqNum = slh.loanSeqNum AND p.asof = dateadd(month, 1, slh.asof)
JOIN fnm.PIV_loan cl ON cl.loanSeqNum = p.loanSeqNum
WHERE slh.balance > 0
AND p.modelId = '@MODEL_VERSION@'
GROUP BY cl.issueId, p.asof