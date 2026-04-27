INSERT @POOL_TABLE@ 
SELECT 
    issueId = cl.issueId,
    asof = p.asof,
    modelId = NULL,
    smmCurtail = sum(slh.currentBalance * p.smmCurtail) / sum(slh.currentBalance),
    smmDefault = sum(slh.currentBalance * p.smmDefault) / sum(slh.currentBalance),
    smmTurnover = sum(slh.currentBalance * p.smmTurnover) / sum(slh.currentBalance),
    smmCashout = sum(slh.currentBalance * p.smmCashout) / sum(slh.currentBalance),
    smmRefinance = sum(slh.currentBalance * p.smmRefinance) / sum(slh.currentBalance),
    smmTotal = sum(slh.currentBalance * p.smmTotal) / sum(slh.currentBalance)
FROM @LOAN_TABLE@ p
JOIN scale.gnm_loanhist slh ON p.loanSeqNum = slh.loanSeqNum AND p.asof = dateadd(month, 1, slh.asof)
JOIN gnm.PIV_loan cl ON cl.loanSeqNum = p.loanSeqNum
WHERE slh.currentBalance > 0
GROUP BY cl.issueId, p.asof