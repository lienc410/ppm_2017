with tabs as
(
select
ROW_NUMBER() over(partition by convert(varchar(10),asof,120)  order by  asof) as rows, 
sum(Schambalance) as Balance, servicerName, asof from fhl.MappedServicerDist group by servicerName,asof)
select asof, servicerName, Balance from tabs 
where rows<6 
and servicerName <> 'N/A'
group by servicerName,asof, Balance
order by asof, Balance desc

select * from  fnm.MappedServicerDist
where asof >= '20030701'




select  * from (
    select 
        servicerName,
        asOf, 
        sum(rpb) TotalBalance,
        Rank = RANK() over(partition by  asOf  order by  TotalBalance desc) 
    from  
        fnm.MappedServicerDist m
    join fnm.Sec b on b.issueID = m.issueId and b.issueDate = m.asOf
    where 
        servicerName not in ('N/A' ,'REMAINING')
        and rpb>0
        and collateralType = 'LOAN'
        and couponType = 'FIX'
        --and asOf >= '20060101'
    group by
         servicerName,asOf
) t
where 
    Rank <= 10
order by asOf


select 
        asOf, 
        sum(rpb) TotalBalance
    from  
        fnm.MappedServicerDist m
    join fnm.Sec b on b.issueID = m.issueId and b.issueDate = m.asOf
    where 
        servicerName not in ('N/A' ,'REMAINING')
        and rpb>0
        and collateralType = 'LOAN'
        and couponType = 'FIX'
        --and asOf >= '20060101'
    group by
         asOf