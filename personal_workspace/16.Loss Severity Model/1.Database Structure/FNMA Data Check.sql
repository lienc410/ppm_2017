select 
    Year = year(asof),
        --avg(currentRPB),
        ForeclosureCostsPct = sum(ForeclosureCosts) / sum(currentRPB), 
        PropertyPreserveAndRepairCostPct = sum(PropertyPreserveAndRepairCost) / sum(currentRPB), 
        AssetRecoveryCostPct = sum(AssetRecoveryCost) / sum(currentRPB), 
        MiscHoldingExpenseAndCreditsPct = sum(MiscHoldingExpenseAndCredits) / sum(currentRPB), 
        AssociatedTaxforHoldingPropertyPct = sum(AssociatedTaxforHoldingProperty) / sum(currentRPB),
    Expenses =  sum(ForeclosureCosts +  
        PropertyPreserveAndRepairCost +  
        AssetRecoveryCost +
        MiscHoldingExpenseAndCredits + 
        AssociatedTaxforHoldingProperty) / sum(currentRPB),
        ---
        NetSaleProceedsPct = sum(NetSaleProceeds) / sum(currentRPB), 
        CreditEnhancementProceedsPct = sum(CreditEnhancementProceeds) / sum(currentRPB), 
        RepurchaseMakeWholeProceedsPct = sum(RepurchaseMakeWholeProceeds) / sum(currentRPB), 
        OtherForecloseProceedsPct = sum(OtherForecloseProceeds) / sum(currentRPB), 
    Proceeds = sum(NetSaleProceeds + CreditEnhancementProceeds + RepurchaseMakeWholeProceeds + OtherForecloseProceeds) / sum(currentRPB)
from fnm.LoanLevelHistMonthlyPerformData
where zerobalancecode in ('09','03')
group by Year




select 
    Year = year(asof),
        --avg(currentRPB),
    sum(currentRPB),
        ForeclosureCostsPct = sum(ForeclosureCosts), 
        PropertyPreserveAndRepairCostPct = sum(PropertyPreserveAndRepairCost), 
        AssetRecoveryCostPct = sum(AssetRecoveryCost), 
        MiscHoldingExpenseAndCreditsPct = sum(MiscHoldingExpenseAndCredits), 
        AssociatedTaxforHoldingPropertyPct = sum(AssociatedTaxforHoldingProperty),
    Expenses =  sum(ForeclosureCosts +  
        PropertyPreserveAndRepairCost +  
        AssetRecoveryCost +
        MiscHoldingExpenseAndCredits + 
        AssociatedTaxforHoldingProperty),
        ---
        NetSaleProceedsPct = sum(NetSaleProceeds), 
        CreditEnhancementProceedsPct = sum(CreditEnhancementProceeds), 
        RepurchaseMakeWholeProceedsPct = sum(RepurchaseMakeWholeProceeds), 
        OtherForecloseProceedsPct = sum(OtherForecloseProceeds), 
    Proceeds = sum(NetSaleProceeds + CreditEnhancementProceeds + RepurchaseMakeWholeProceeds + OtherForecloseProceeds)
from fnm.LoanLevelHistMonthlyPerformData
where zerobalancecode in ('09','03')
group by Year



select 
    --Year = year(dispositiondate),
        --avg(currentRPB),
    --asof,
    dispositiondate,
    Interest = sum(currentRPB * datediff(mm, LastPaidInstallmentDate, DispositionDate)/12 * (CurrentCoupon - 0.25)/100) / sum(case when currentRPB is null then 0 else currentRPB end), 
        ForeclosureCostsPct = sum(case when ForeclosureCosts is null then 0 else ForeclosureCosts end) / sum(case when currentRPB is null then 0 else currentRPB end), 
        PropertyPreserveAndRepairCostPct = sum(case when PropertyPreserveAndRepairCost is null then 0 else PropertyPreserveAndRepairCost end) /  sum(case when currentRPB is null then 0 else currentRPB end), 
        AssetRecoveryCostPct = sum(case when AssetRecoveryCost is null then 0 else AssetRecoveryCost end) / sum(case when currentRPB is null then 0 else currentRPB end), 
        MiscHoldingExpenseAndCreditsPct = sum(case when MiscHoldingExpenseAndCredits is null then 0 else MiscHoldingExpenseAndCredits end) / sum(case when currentRPB is null then 0 else currentRPB end), 
        AssociatedTaxforHoldingPropertyPct = sum(case when AssociatedTaxforHoldingProperty is null then 0 else AssociatedTaxforHoldingProperty end) / sum(case when currentRPB is null then 0 else currentRPB end), 
    Expenses =  sum((case when ForeclosureCosts is null then 0 else ForeclosureCosts end) + 
         (case when PropertyPreserveAndRepairCost is null then 0 else PropertyPreserveAndRepairCost end) +  
         (case when AssetRecoveryCost is null then 0 else AssetRecoveryCost end) + 
         (case when MiscHoldingExpenseAndCredits is null then 0 else MiscHoldingExpenseAndCredits end) + 
         (case when AssociatedTaxforHoldingProperty is null then 0 else AssociatedTaxforHoldingProperty end)) / sum(case when currentRPB is null then 0 else currentRPB end),
        ---
        NetSaleProceedsPct = sum(case when NetSaleProceeds is null then 0 else NetSaleProceeds end) /  sum(case when currentRPB is null then 0 else currentRPB end), 
        CreditEnhancementProceedsPct = sum(case when CreditEnhancementProceeds is null then 0 else CreditEnhancementProceeds end) /  sum(case when currentRPB is null then 0 else currentRPB end), 
        RepurchaseMakeWholeProceedsPct = sum(case when RepurchaseMakeWholeProceeds is null then 0 else RepurchaseMakeWholeProceeds end) /  sum(case when currentRPB is null then 0 else currentRPB end),  
        OtherForecloseProceedsPct = sum(case when OtherForecloseProceeds is null then 0 else OtherForecloseProceeds end) /  sum(case when currentRPB is null then 0 else currentRPB end), 
    Proceeds = sum((case when NetSaleProceeds is null then 0 else NetSaleProceeds end) + 
         (case when CreditEnhancementProceeds is null then 0 else CreditEnhancementProceeds end) + 
         (case when RepurchaseMakeWholeProceeds is null then 0 else RepurchaseMakeWholeProceeds end) + 
         (case when OtherForecloseProceeds is null then 0 else OtherForecloseProceeds end)) / sum(case when currentRPB is null then 0 else currentRPB end)
from fnm.LoanLevelHistMonthlyPerformData
where zerobalancecode in ('03','09')
and loanID  = '139986190029'
and dispositiondate is not null
group by dispositiondate




select *, Interest = currentRPB * datediff(mm, LastPaidInstallmentDate, DispositionDate)/12 * (CurrentCoupon - 0.25)/100 ,
       Proceeds = (case when NetSaleProceeds is null then 0 else NetSaleProceeds end) + (case when RepurchaseMakeWholeProceeds is null then 0 else RepurchaseMakeWholeProceeds end) 
from fnm.LoanLevelHistMonthlyPerformData
-- where loanid = '100557946796'
where delinqStatus = 'X'

select max(asOf) from fnm.LoanLevelHistMonthlyPerformData
select count(1)
select year(asOf) as grp, count(1) 
select *
from fnm.LoanLevelHistMonthlyPerformData
where loanid = '110259657651'
where zerobalancecode in ('03')
and dispositiondate is null
group by grp;
and asOf >= '2014-01-01'



