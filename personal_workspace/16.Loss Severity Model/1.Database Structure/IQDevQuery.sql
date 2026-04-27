
select * from fhl.LoanLevelHistOriginationData

select * from fhl.LoanLevelHistMonthlyPerformData
where LoanId = 'F106Q1263687'

------------------Lost Severity--------------------------
select p1.LoanId, p1.asOf asOfREOStart,  datediff(mm, p1.asOf, p2.asOf) as REOTime
from fhl.LoanLevelHistMonthlyPerformData p1
join fhl.LoanLevelHistMonthlyPerformData p2
on  p2.delinqStatus = p1.delinqStatus
and p2.LoanId = p1.LoanId
and p2.asOF > p1.asOf
join fhl.LoanLevelHistOriginationData o
on o.LoanId = p1.LoanId
where p1.delinqStatus = 'R'
and p2.ZerobalanceCode = 9


select datediff(mm, p1.asOf, p2.asOf) as REOTime,
       count(1) as cnt
from fhl.LoanLevelHistMonthlyPerformData p1
join fhl.LoanLevelHistMonthlyPerformData p2
on  p2.delinqStatus = p1.delinqStatus
and p2.LoanId = p1.LoanId
and p2.asOF > p1.asOf
where p1.delinqStatus = 'R'
and p2.ZerobalanceCode = 9
group by REOTime



column_name numeric(precision ,0) identity

create table tmp_PerformData
    (sale_id numeric(5,0) identity, 
    stor_id char(4) not null)

select * from tmp_PerformData



declare @ym char(10)
set @ym = asof

while datediff(mm, @ym, '2003-06-01') >= 0
begin
select @ym
select @ym = dateadd(mm, 1, @ym)
end


substring(convert(char(10),dateadd(mm,1,substring(@ym,1,7)+'-01'),102),1,10)

select * 
from fhl.LoanLevelHistMonthlyPerformData
where delinqStatus = 'R'
and ZerobalanceCode is Null
and loanId = 'F199Q1000083'


select LoanId, asOf, currentRPB, delinqStatus, loanAge, remTerm, CurrentCoupon, currentdeferredUPB
into #Perform1
from fhl.LoanLevelHistMonthlyPerformData
where delinqStatus = 'R'
and ZerobalanceCode is Null
and loanId = 'F199Q1000083'





select asOf into #tmp_asOf from fhl.LoanLevelHistMonthlyPerformData group by asOf

select *, asOf loanOutAsOf into #ReoLoans from fhl.LoanLevelHistMonthlyPerformData where delinqStatus ='R' and currentRpb>0
update #ReoLoans r
set 
    loanOutAsOf = f.asOf
from 
    fhl.LoanLevelHistMonthlyPerformData f
where 
    r.loanId=f.loanId
    and  f.delinqStatus ='R' and f.currentRpb=0

select  r.loanId, t.asOf, r.currentRPB, r.delinqStatus, r.loanAge, r.remTerm, r.repurchaseFlag, r.loanModFlag, r.zeroBalanceCode, 
        r.asOfZeroBalance, r.CurrentCoupon, r.currentdeferredUPB, r.dueDateLastPaidInstallment, r.mortageInsurancerecoveries, 
        r.netSaleProceeds, r.nonMortageInsurancerecoveries, r.expenses
into #ReoHist
from #ReoLoans r
join #tmp_asOf t on t.asOf>r.asOf and t.asOf<loanOutAsOf
and loanId = 'F199Q1000083'

--select * from #ReoHist

select *
from fhl.LoanLevelHistMonthlyPerformData f
join #ReoHist r
on r.loanId = f.loanId
where f.loanId = 'F199Q1000083'


select *
from fhl.LoanLevelHistMonthlyPerformData f
where f.loanId = 'F199Q1000083'





--------------fill REO asof gap---------------------------------------------
select asOf into #tmp_asOf from fhl.LoanLevelHistMonthlyPerformData group by asOf

select *, asOf loanOutAsOf into #ReoLoans from fhl.LoanLevelHistMonthlyPerformData where delinqStatus ='R' and currentRpb>0
    update #ReoLoans r
    set 
        loanOutAsOf = f.asOf
    from 
        fhl.LoanLevelHistMonthlyPerformData f
    where 
        r.loanId=f.loanId
        and  f.delinqStatus ='R' and f.currentRpb=0
    
select  r.loanId, t.asOf, r.currentRPB, r.delinqStatus, r.loanAge, r.remTerm, r.repurchaseFlag, r.loanModFlag, r.zeroBalanceCode, 
        r.asOfZeroBalance, r.CurrentCoupon, r.currentdeferredUPB, r.dueDateLastPaidInstallment, r.mortageInsurancerecoveries, 
        r.netSaleProceeds, r.nonMortageInsurancerecoveries, r.expenses
    into #ReoHist
    from #ReoLoans r
    join #tmp_asOf t on t.asOf>r.asOf and t.asOf<loanOutAsOf
    and loanId = 'F199Q1000083'

--select * from #ReoHist

select *
from
(
    select * from fhl.LoanLevelHistMonthlyPerformData where  loanId = 'F199Q1000083'
    union all
    select * from #ReoHist
) cat
order by asof



----------------- netSaleProceeds = 'C' ----------------
select * from fhl.LoanLevelHistMonthlyPerformData
where netSaleProceeds = 'C'

select count(1) cnt from fhl.LoanLevelHistMonthlyPerformData
where netSaleProceeds = 'C'

select * from fhl.LoanLevelHistMonthlyPerformData
where loanId = 'F199Q1000083'

select delinqStatus, count(1) as cnt from fhl.LoanLevelHistMonthlyPerformData
where netSaleProceeds = 'C'
group by delinqStatus


----------------- Check Actual MI recoveries ---------------------
select  top 20 p1.loanId, 
        REOTime = datediff(mm, p2.dueDateLastPaidInstallment, p2.asOfZeroBalance), 
        ActualLoss = round(p1.currentRPB - cast(p2.netSaleProceeds as double) - p2.expenses + (datediff(mm, p2.dueDateLastPaidInstallment, p2.asOfZeroBalance) * p1.currentRPB * 30/360 * (p1.CurrentCoupon - 0.25)/100) - p2.mortageInsurancerecoveries - p2.nonMortageInsurancerecoveries,2),                
        LossClaim = convert(decimal(16,2),round(p1.currentRPB - p2.expenses + (datediff(mm, p2.dueDateLastPaidInstallment, p2.asOfZeroBalance) * p1.currentRPB * 30/360 * (p1.CurrentCoupon - 0.25)/100),2)),
        UPB = p1.currentRPB,
        --interest = convert(decimal(16,2),round((datediff(mm, p2.dueDateLastPaidInstallment, p2.asOfZeroBalance) * p1.currentRPB * 30/360 * (p1.CurrentCoupon - 0.25)/100),2))
        --MInNonMI = p2.mortageInsurancerecoveries + p2.nonMortageInsurancerecoveries,
        MICoveries = p2.mortageInsurancerecoveries,
        max_MICoverage - MICoveries as MI_shortfall,
        o.pctMtgIns,
        (o.pctMtgIns / 100.0) * LossClaim as max_MICoverage,
        OLTV = o.origLTV,
        CLTV = o.cltv,
        ActualMIPct = convert(decimal(16,2),round(MICoveries/LossClaim,2)*100)
from fhl.LoanLevelHistMonthlyPerformData p1
join fhl.LoanLevelHistMonthlyPerformData p2
on p1.loanId = p2.loanId
and p1.asof < p2.asof
and p1.delinqStatus = p2.delinqStatus
join fhl.LoanLevelHistOriginationData o
on p1.loanId = o.loanId
where p1.delinqStatus = 'R'
--new conditions
and o.pctMtgIns > 0 
--and o.pctMtgIns * LossClaim <= ActualLoss
and ActualLoss > 1000
and LossClaim > max_MICoverage
and MICoveries > 0
ORDER BY MI_shortfall DESC
;


-------------- average by year ----------------------
select  year(p2.asof) as REOEndYear,  
        pctMtgIns = convert(decimal(16,2),round(sum(o.pctMtgIns*p1.currentRPB)/sum(p1.currentRPB),2)),
        ActualMIPct = convert(decimal(16,2),round(sum(p2.mortageInsurancerecoveries/(p1.currentRPB - p2.expenses + (datediff(mm, p2.dueDateLastPaidInstallment, p2.asOfZeroBalance) * p1.currentRPB * 30/360 * (p1.CurrentCoupon - 0.25)/100))*p1.currentRPB)/sum(p1.currentRPB)*100,2))
from fhl.LoanLevelHistMonthlyPerformData p1
join fhl.LoanLevelHistMonthlyPerformData p2
on p1.loanId = p2.loanId
and p1.asof < p2.asof
and p1.delinqStatus = p2.delinqStatus
join fhl.LoanLevelHistOriginationData o
on p1.loanId = o.loanId
where p1.delinqStatus = 'R'
and o.pctMtgIns is not null
and o.pctMtgIns > 0 
and p1.currentRPB - cast(p2.netSaleProceeds as double) - p2.expenses + (datediff(mm, p2.dueDateLastPaidInstallment, p2.asOfZeroBalance) * p1.currentRPB * 30/360 * (p1.CurrentCoupon - 0.25)/100) - p2.mortageInsurancerecoveries - p2.nonMortageInsurancerecoveries > 1000
group by REOEndYear



-------------- average by OLTV ----------------------
select  o.origLTV as OLTV,  
        pctMtgIns = convert(decimal(16,2),round(sum(o.pctMtgIns*p1.currentRPB)/sum(p1.currentRPB),2)),
        --ActualMIPct = convert(decimal(16,2),round(sum(p2.mortageInsurancerecoveries/(p1.currentRPB - p2.expenses + (datediff(mm, p2.dueDateLastPaidInstallment, p2.asOfZeroBalance) * p1.currentRPB * 30/360 * (p1.CurrentCoupon - 0.25)/100))*p1.currentRPB)/sum(p1.currentRPB)*100,2))
        ActualMIPct = convert(decimal(16,2),round(sum(p2.mortageInsurancerecoveries/(p1.currentRPB)*p1.currentRPB)/sum(p1.currentRPB)*100,2))
from fhl.LoanLevelHistMonthlyPerformData p1
join fhl.LoanLevelHistMonthlyPerformData p2
on p1.loanId = p2.loanId
and p1.asof < p2.asof
and p1.delinqStatus = p2.delinqStatus
join fhl.LoanLevelHistOriginationData o
on p1.loanId = o.loanId
where p1.delinqStatus = 'R'
and o.pctMtgIns is not null
and OLTV > 80
and o.pctMtgIns > 0 
and p1.currentRPB - cast(p2.netSaleProceeds as double) - p2.expenses + (datediff(mm, p2.dueDateLastPaidInstallment, p2.asOfZeroBalance) * p1.currentRPB * 30/360 * (p1.CurrentCoupon - 0.25)/100) - p2.mortageInsurancerecoveries - p2.nonMortageInsurancerecoveries > 1000
group by OLTV
order by OLTV

--new conditions
and OLTV > 85
and o.pctMtgIns is null





select count(1) cnt
from fhl.LoanLevelHistMonthlyPerformData p1
join fhl.LoanLevelHistMonthlyPerformData p2
on p1.loanId = p2.loanId
and p1.asof < p2.asof
and p1.delinqStatus = p2.delinqStatus 
join fhl.LoanLevelHistOriginationData o
on p1.loanId = o.loanId
where p1.delinqStatus = 'R'
and o.pctMtgIns is null

and o.origLTV > 85
and o.pctMtgIns = 0


and firstPaymtdt >= '2003-01-01'
and o.pctMtgIns > 0


select * from fhl.LoanLevelHistOriginationData
where loanId = 'F105Q2058748'
where p1.delinqStatus = 'R'





LossClaim = p1.currentRPB - p2.netSaleProceeds