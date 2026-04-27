
------------------------------------------------------------------------
-----------procedure for the function of rates----------------
------------------------------------------------------------------------
create procedure RefinancibleUniverse_FunctionOfRates (@rate double, @asof Date) 
as
begin
		  
	select   
	refinancible1 = sum(case when f.wac - (@rate-0.5) >= 0.5 then f.currentBalance else 0 end)/sum(f.currentBalance),
	refinancible2 = sum(case when f.wac - (@rate-0.4) >= 0.5 then f.currentBalance else 0 end)/sum(f.currentBalance),
	refinancible3 = sum(case when f.wac - (@rate-0.3) >= 0.5 then f.currentBalance else 0 end)/sum(f.currentBalance),
	refinancible4 = sum(case when f.wac - (@rate-0.2) >= 0.5 then f.currentBalance else 0 end)/sum(f.currentBalance),
	refinancible5 = sum(case when f.wac - (@rate-0.1) >= 0.5 then f.currentBalance else 0 end)/sum(f.currentBalance),
	refinancible6 = sum(case when f.wac - @rate >= 0.5 then f.currentBalance else 0 end)/sum(f.currentBalance),
	refinancible7 = sum(case when f.wac - (@rate+0.1) >= 0.5 then f.currentBalance else 0 end)/sum(f.currentBalance),
	refinancible8 = sum(case when f.wac - (@rate+0.2) >= 0.5 then f.currentBalance else 0 end)/sum(f.currentBalance),
	refinancible9 = sum(case when f.wac - (@rate+0.3) >= 0.5 then f.currentBalance else 0 end)/sum(f.currentBalance),
	refinancible10 = sum(case when f.wac - (@rate+0.4) >= 0.5 then f.currentBalance else 0 end)/sum(f.currentBalance),
	refinancible11 = sum(case when f.wac - (@rate+0.5) >= 0.5 then f.currentBalance else 0 end)/sum(f.currentBalance)
	from fnm.sec p, fnm.secFactor f 
	where p.issueId = f.issueId
	and p.collateralType = 'LOAN' 
	and p.marketTicker in ('FNCL')
	and f.asOf = @asof ---- update to the latest factor date

end



exec RefinancibleUniverse_FunctionOfRates 3.77, '2015-05-01'