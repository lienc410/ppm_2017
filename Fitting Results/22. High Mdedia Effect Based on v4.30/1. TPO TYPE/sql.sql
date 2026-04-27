-------------------------------Verify--------------------------------------------------------

                     select md1.modelId,
						SFACTOR_PREPAY_TRACKING_CPR = 1 - ( sum(md1.smmTotal*1*l.schamBalance)/sum(sign(md1.issueId)*1*l.schamBalance)),
	                    PREPAY_CPR1 = 100*(1.0 - power(sum(1*currentRpb)/sum(1*calcScham), 12))
			,PREPAY_TRACKING_CPR1 = 100*(1-POWER(SFACTOR_PREPAY_TRACKING_CPR,12))
            ,PREPAY_SMM1 = 1-sum(1*currentRpb)/sum(1*calcScham)
			,PREPAY_TRACKING_SMM1 = sum(md1.smmTotal*1*l.schamBalance)/sum(sign(md1.issueId)*1*l.schamBalance)
			,PCT_LOANTYPE = sum(case when loanType in ( 'FHA') then  1*schamBalance else 0  end) / sum( 1*schamBalance)
			,_ORIGNOTERATE = sum( case when OrigNoteRate >0 then 1*schamBalance else NULL end *OrigNoteRate) / sum(case when OrigNoteRate >0   then  1*schamBalance  else NULL end)
			,_ZEROSATO = sum( case when zeroSATORate >0 then 1*schamBalance else NULL end *zeroSATORate) / sum(case when zeroSATORate >0   then  1*schamBalance  else NULL end)
			,_SATO = sum(  schamBalance * SATO) / sum( schamBalance)
            ,_REFI_INCENTIVE_Fixed = sum( case when refi_incentive_eligible_fixed_cost >-99999 then 1*schamBalance else NULL end *refi_incentive_eligible_fixed_cost) / sum(case when refi_incentive_eligible_fixed_cost >-99999   then  1*schamBalance  else NULL end)
            ,_Fixed_cost = sum( case when refi_incentive_eligible_fixed_cost >-99999 then 1*schamBalance else NULL end *(refi_incentive_eligible - refi_incentive_eligible_fixed_cost)) / sum(case when refi_incentive_eligible_fixed_cost >-99999   then  1*schamBalance  else NULL end)			
            ,_LOANAGE = sum( case when loanAge >0 then 1*schamBalance else NULL end *loanAge) / sum(case when loanAge >0   then  1*schamBalance  else NULL end)
			,_LTV = sum( case when origLTV >0 then 1*schamBalance else NULL end *origLTV) / sum(case when origLTV >0   then  1*schamBalance  else NULL end)
			,_CLTV = sum( case when CLTV >0 then 1*schamBalance else NULL end *CLTV) / sum(case when CLTV >0   then  1*schamBalance  else NULL end)
			,_AVG_LOANSIZE_SCHAMBALANCE = sum( schamBalance*schamBalance)/sum( schamBalance)
            ,_WACLS = sum( 1*schamBalance)/sum( 1*1)
			,_FICO = sum( case when cs >0 then 1*schamBalance else NULL end *cs) / sum(case when cs >0   then  1*schamBalance  else NULL end)
			,PCT_ISSECONDLIEN = sum(case when isSecondLien in ( 'Y') then  1*schamBalance else 0  end) / sum( 1*schamBalance)
			,_OrigCombLTV = sum(case when isSecondLien in ( 'Y') then  l.origCombLTV*schamBalance else 0  end) / sum( 1*schamBalance)

			,PCT_SVC = sum(case when servicerName in ( 'CALIBER HOME LOANS INC','CALIBERHOMELOANSINC','CARRINGTON MORTGAGE SERVICES, LLC','EVER BANK','FLAGSTAR','FRANKLIN AMERICAN MORTGAGE COMPANY','FRANKLINAMERICANMTGE','FREEDOM','HOMEBRIDGE FINANCIAL SERVICES INC','LAKEVIEW LOAN SERVICING, LLC','MIDFIRST','OCWEN','PACIFIC UNION FINANCIAL LLC','PENNYMAC CORP.','PENNYMAC LOAN SERVICES, LLC','PENNYMACCORP','PINGORA LOAN SERVICING, INC.','PLAZA HOME MORTGAGE, INC','PLAZAHOMEMORTGAGEIN','PROVIDENT FUNDING','PROVIDENTSAVINGSBANK','QUICKEN','STEARNS LENDING INC DBA FPF WHOLESALE CU','STEARNS LENDING, LLC','STONEGATE MORTGAGE CORPORATION','UNITED SHORE FINANCIAL SERVICES, LLC','UNITEDSHOREFINANCIAL') then  1*schamBalance else 0  end) / sum( 1*schamBalance)
			,PCT_TPO = sum(case when tpoType in ( 'RETAIL') then  1*schamBalance else 0  end) / sum( 1*schamBalance)
			,PCT_GEO = sum(case when state in ( 'NY','PR') then  1*schamBalance else 0  end) / sum( 1*schamBalance)
			,PCT_LOANPURPOSE = sum(case when loanPurposeType in ( 'RE-FI','RE-FI-NCO','RE-FI-CO','RE-FI-STR','RE-FI-NSTR','RE-FI-N/S','RE-FI-N/A') then  1*schamBalance else 0  end) / sum( 1*schamBalance)
			,PCT_OCC = sum(case when occType in ( 'INV') then  1*schamBalance else 0  end) / sum( 1*schamBalance)
			,curtailsmm = sum( schamBalance * smmCurtail) / sum( schamBalance )
            ,defaultsmm = sum( schamBalance * smmDefault) / sum( schamBalance )
            ,toverSmm = sum( schamBalance * smmturnover) / sum( schamBalance )
            ,cashoutSmm = sum( schamBalance * smmCashout) / sum( schamBalance )
            ,refiSmm = sum( schamBalance * smmRefinance) / sum( schamBalance )
            ,cumHPA = sum( schamBalance * ((l.calcScham/l.cltv)/(l.originalLoanAmount/l.origLTV) - 1.0)   ) / sum( schamBalance )
            ,cumHPA05Pct = sum( schamBalance * ( case when (l.calcScham/l.cltv)/(l.originalLoanAmount/l.origLTV) - 1.0  <=  0.05 then 1.0 else 0 end  )) / sum( schamBalance )
            ,cumHPA15Pct = sum( schamBalance * ( case when (l.calcScham/l.cltv)/(l.originalLoanAmount/l.origLTV) - 1.0  <=  0.15 then 1.0 else 0 end  )) / sum( schamBalance )          
            ,cumHPA20Pct = sum( schamBalance * ( case when (l.calcScham/l.cltv)/(l.originalLoanAmount/l.origLTV) - 1.0  <=  0.20 then 1.0 else 0 end  )) / sum( schamBalance )
            ,cumHPA25Pct = sum( schamBalance * ( case when (l.calcScham/l.cltv)/(l.originalLoanAmount/l.origLTV) - 1.0  <=  0.25 then 1.0 else 0 end  )) / sum( schamBalance )
            ,cumHPA30Pct = sum( schamBalance * ( case when (l.calcScham/l.cltv)/(l.originalLoanAmount/l.origLTV) - 1.0  <=  0.30 then 1.0 else 0 end  )) / sum( schamBalance )
            ,cumHPA35Pct = sum( schamBalance * ( case when (l.calcScham/l.cltv)/(l.originalLoanAmount/l.origLTV) - 1.0  <=  0.35 then 1.0 else 0 end  )) / sum( schamBalance )
            ,cumHPA40Pct = sum( schamBalance * ( case when (l.calcScham/l.cltv)/(l.originalLoanAmount/l.origLTV) - 1.0  <=  0.40 then 1.0 else 0 end  )) / sum( schamBalance )	  
--            ,adjtoverSmm = sum( schamBalance * smmturnover * s.mult) / sum( schamBalance )
            ,adjtoverSmm = 0
            ,adjRefiSmm = 0
                 , groupByColumn = 
-- case 
-- when  refi_incentive_eligible_fixed_cost <= -200 then  '00:<= -200'
-- when  refi_incentive_eligible_fixed_cost <= -175 then '01:-200--175'
-- when  refi_incentive_eligible_fixed_cost <= -150 then '02:-175--150'
-- when  refi_incentive_eligible_fixed_cost <= -125 then '03:-150--125'
-- when  refi_incentive_eligible_fixed_cost <= -100 then '04:-125--100'
-- when  refi_incentive_eligible_fixed_cost <= -75 then '05:-100--75'
-- when  refi_incentive_eligible_fixed_cost <= -50 then '06:-75--50'
-- when  refi_incentive_eligible_fixed_cost <= -25 then '07:-50--25'
-- when  refi_incentive_eligible_fixed_cost <= 0 then '08:-25-0'
-- when  refi_incentive_eligible_fixed_cost <= 25 then '09:0-25'
-- when  refi_incentive_eligible_fixed_cost <= 50 then '10:25-50'
-- when  refi_incentive_eligible_fixed_cost <= 75 then '11:50-75'
-- when  refi_incentive_eligible_fixed_cost <= 100 then '12:75-100'
-- when  refi_incentive_eligible_fixed_cost <= 125 then '13:100-125'
-- when  refi_incentive_eligible_fixed_cost <= 150 then '14:125-150'
-- when  refi_incentive_eligible_fixed_cost <= 175 then '15:150-175'
-- when  refi_incentive_eligible_fixed_cost <= 200 then '16:175-200'
-- when  refi_incentive_eligible_fixed_cost <= 225 then '17:200-225'
-- when  refi_incentive_eligible_fixed_cost <= 250 then '18:225-250'
-- when  refi_incentive_eligible_fixed_cost<= 9999999 then  '999:>= 250'
-- else '9999'
--end

 case 
 when  refi_incentive_eligible_fixed_cost <= -200 then  '00:<= -200'
 when  refi_incentive_eligible_fixed_cost <= -175 then '01:-200--175'
 when  refi_incentive_eligible_fixed_cost <= -150 then '02:-175--150'
 when  refi_incentive_eligible_fixed_cost <= -125 then '03:-150--125'
 when  refi_incentive_eligible_fixed_cost <= -100 then '04:-125--100'
 when  refi_incentive_eligible_fixed_cost <= -75 then '05:-100--75'
 when  refi_incentive_eligible_fixed_cost <= -50 then '06:-75--50'
 when  refi_incentive_eligible_fixed_cost <= -25 then '07:-50--25'
 when  refi_incentive_eligible_fixed_cost <= -20 then '08-1:-25--20'
 when  refi_incentive_eligible_fixed_cost <= -15 then '08-2:-20--15'
 when  refi_incentive_eligible_fixed_cost <= -10 then '08-3:-15--10'
 when  refi_incentive_eligible_fixed_cost <= -5 then '08-4:-10--5'
 when  refi_incentive_eligible_fixed_cost <= 0 then '08:-25-0'
 when  refi_incentive_eligible_fixed_cost <= 5 then '09-1:0-5'
 when  refi_incentive_eligible_fixed_cost <= 10 then '09-2:5-10'
 when  refi_incentive_eligible_fixed_cost <= 15 then '09-3:10-15'
 when  refi_incentive_eligible_fixed_cost <= 20 then '09-4:15-20'
 when  refi_incentive_eligible_fixed_cost <= 25 then '09:0-25'
 when  refi_incentive_eligible_fixed_cost <= 30 then '10-1:25-30'
 when  refi_incentive_eligible_fixed_cost <= 35 then '10-2:30-35'
 when  refi_incentive_eligible_fixed_cost <= 40 then '10-3:35-40'
 when  refi_incentive_eligible_fixed_cost <= 45 then '10-4:40-45'
 when  refi_incentive_eligible_fixed_cost <= 50 then '10:25-50'
 when  refi_incentive_eligible_fixed_cost <= 55 then '11-1:50-55'
 when  refi_incentive_eligible_fixed_cost <= 60 then '11-2:55-60'
 when  refi_incentive_eligible_fixed_cost <= 65 then '11-3:60-65'
 when  refi_incentive_eligible_fixed_cost <= 70 then '11-4:65-70'
 when  refi_incentive_eligible_fixed_cost <= 75 then '11:50-75'
 when  refi_incentive_eligible_fixed_cost <= 100 then '12:75-100'
 when  refi_incentive_eligible_fixed_cost <= 125 then '13:100-125'
 when  refi_incentive_eligible_fixed_cost <= 150 then '14:125-150'
 when  refi_incentive_eligible_fixed_cost <= 175 then '15:150-175'
 when  refi_incentive_eligible_fixed_cost <= 200 then '16:175-200'
 when  refi_incentive_eligible_fixed_cost <= 225 then '17:200-225'
 when  refi_incentive_eligible_fixed_cost <= 250 then '18:225-250'
 when  refi_incentive_eligible_fixed_cost<= 9999999 then  '999:>= 250'
 else '9999'
end
,curve = substring( groupByColumn,charindex(':',groupByColumn)+1)  

					   ,Balance = sum(schamBalance)
					   ,LoanCount = count(1)
    ,PCT_BROKER = sum(CASE WHEN tpoType='BROKER' THEN 100 * schamBalance else 0  end) / sum( 1*schamBalance)
    ,PCT_CORRES = sum(CASE WHEN tpoType='CORRES' THEN 100 * schamBalance else 0  end) / sum( 1*schamBalance)
    ,PCT_NonRETAIL = sum(CASE WHEN tpoType in ('BROKER', 'CORRES', 'TPO') THEN 100 * schamBalance else 0 end) / sum( 1*schamBalance)
    ,PCT_RETAIL = sum(CASE WHEN tpoType in ('BROKER', 'CORRES', 'TPO') THEN 0 else 100 * schamBalance end) / sum( 1*schamBalance)
    
    ,PCT_CashWindow = sum(CASE WHEN (CASE WHEN tpoType in ('BROKER', 'CORRES', 'TPO') THEN 0 else 100 end) > (CASE WHEN isCashWindow = 'Y' THEN 100 ELSE 0 END) 
                            THEN (CASE WHEN isCashWindow = 'Y' THEN 100 ELSE 0 END) ELSE (CASE WHEN tpoType in ('BROKER', 'CORRES', 'TPO') THEN 0 else 100 end) END * schamBalance) / sum( 1*schamBalance)
    ,PCT_NonCashWindow = sum(((CASE WHEN tpoType in ('BROKER', 'CORRES', 'TPO') THEN 0 else 100 end) 
                                - (CASE WHEN (CASE WHEN tpoType in ('BROKER', 'CORRES', 'TPO') THEN 0 else 100 end) > (CASE WHEN isCashWindow = 'Y' THEN 100 ELSE 0 END) 
                            THEN (CASE WHEN isCashWindow = 'Y' THEN 100 ELSE 0 END) ELSE (CASE WHEN tpoType in ('BROKER', 'CORRES', 'TPO') THEN 0 else 100 end) END))*schamBalance) / sum( 1*schamBalance)

                    from
                        FHL.PIV_LoanView l, scale.LoanPrepayTracking md1 , scale.fhl_loanIncentive i
						where
                        md1.loanseqNum = l.loanseqNum 
                        and md1.loanseqNum = i.loanseqNum 
                        and datediff(mm, i.asOF, l.asOf) = 1
                        and i.version = '2.70'
                        and md1.asOf =  l.asOf 
                        and md1.modelId = '4.30' ------'4.30 has the latest where cashout is using turnover incentive 
                    ------------------'98 is the latest','4.30' has HARP and 2nd matrix but loan size is buggy and tover incentive is wrong, 99 has the wrong refi incentive
                        and calcScham > 0.1
--                        and l.loanSeqNum = t.id
--                        and 100*((l.calcScham/l.cltv)/(l.originalLoanAmount/l.origLTV) - 1.0) > cc.low
--                        and 100*((l.calcScham/l.cltv)/(l.originalLoanAmount/l.origLTV) - 1.0) <= cc.high
--                        and refi_incentive_eligible_fixed_cost  > ci.low
--                        and refi_incentive_eligible_fixed_cost  <= ci.high
--                        and refi_incentive_eligible_fixed_cost  > ri.low
--                        and refi_incentive_eligible_fixed_cost  <= ri.high              
                        
--                        and l.sato > s.low
--                        and l.sato <= s.high
	                    and groupByColumn is NOT NULL
	                    

 and ( 1=2 
 OR marketTicker LIKE 'FGLMC' OR marketTicker LIKE 'FGU6' OR marketTicker LIKE 'FGU9' OR marketTicker LIKE 'FGT6')

-- and marketTicker like 'FGT6'

 and (l.asOf >= '20120101' and l.asOf<='20130401') 
--or (l.asOf >= '20160401' and l.asOf<='20161201')

 and calcOrigMonth_LL >= 200907 and calcOrigMonth_LL<=201809
-- and numUnits = 1
-- and loanAge >= 48 and loanAge<=120
 and originalLoanAmount > 175000 and originalLoanAmount<=417000
-- and originalLoanAmount > 800000
-- and originalLoanAmount > 417000  

 and loanAge >= 12 and loanAge<24
--and loanAge >= 24
--  and loanAge >= 24 and loanAge<=48
--and originalLoanAmount > 417000
--  and schamBalance <= 70000
--and schamBalance > 250000 and schamBalance <= 400000
--and schamBalance > 250000 and schamBalance <= 300000
--and schamBalance > 300000 and schamBalance <= 350000
--and schamBalance > 350000 and schamBalance <= 400000
--and schamBalance > 400000 and schamBalance <= 450000
--and schamBalance > 450000 and schamBalance <= 500000
--and schamBalance > 500000 and schamBalance <= 550000
--and schamBalance > 550000 and schamBalance <= 600000
--and schamBalance > 425000 and schamBalance <= 550000
--  and schamBalance > 450000
--and schamBalance > 550000  
--and schamBalance > 600000
--and schamBalance > 525000 and schamBalance <= 600000  -- We need schamBalance buckets

--and originalLoanAmount > 0 and originalLoanAmount<= 85000
--and originalLoanAmount > 85000 and originalLoanAmount<= 110000
-- and originalLoanAmount > 110000 and originalLoanAmount<= 150000
-- and originalLoanAmount > 150000 and originalLoanAmount<= 175000
-- and originalLoanAmount > 175000 and originalLoanAmount<= 200000
--   and originalLoanAmount > 110000 and originalLoanAmount <= 175000

--  and (originalLoanAmount > 110000 or cs >= 740)  ---U6 or U9

--  and (originalLoanAmount <= 110000 and cs < 740)

-- and origLTV >= 0 and origLTV<=80
 and origLTV > 0
 and CLTV > 0 and CLTV<=80
-- and CLTV > 80 and CLTV <= 90
-- and CLTV > 90 and CLTV <= 100
-- and CLTV > 100


-- and CLTV * (case when isSecondLien = 'Y' then origCombLTV else origLTV end)/origLTV <= 75

   and cs >= 740 and cs<=860
--   and cs < 740
--   and cs >= 700 and cs < 740
--  and cs >= 660 and cs < 700
--  and cs >= 620 and cs < 660
--   and cs < 660
--   and cs > 800

-- and ( 1=2 
-- OR occType LIKE 'OWNER' OR occType LIKE '2ND')



-- and origLTV > 80
-- and origLTV <= 85
-- and origLTV <= 105
-- and origLTV > 125
--and origLTV > 80
-- and origLTV <= 105
-- and origLTV > 105
-- and origLTV <= 125
-- and origLTV > 125
--  and origLTV > 75
--  and origLTV <= 80
--  and origLTV > 85
--  and origLTV <= 90
-- and l.tpoType in ('RETAIL', 'CORRES','BROKER')
-- and l.tpoType in ('RETAIL')
-- and l.tpoType in ('CORRES')
-- and l.tpoType in ('BROKER')

 
--and HARPSTATUS not like 'HARP'  ----Only refi has a HARP dial
--  and origLTV <= 80
--   and origLTV > 105
-- and loanPurposeType like '%RE-FI%'
--xxxxxx and loanPurposeType like '%PURCH%'
-- and l.loanPurposeType like '%PURCH%' and l.marketTicker not in ('FGU6', 'FGU9')
-- and l.state not in ('NY','PR','HI')
 and l.state not in ('NY','PR')
-- and l.state in ('AK','AL','AR','CT','DE','IA','LA','MD','ME','MS','ND','NJ','NM','OK','PA','VA','VT','WV','WY')
--and l.state  in ('AZ', 'CA','CO','DC','FL','GA','ID','MI','NV','OR','TX','UT','WA')
-- and ( 1=2 
-- OR isSecondLien LIKE 'N')

 and isSecondLien = 'N'
 and occType not like 'INV'

--   and SATO <= -100
--   and SATO > -100 and SATO <= -50
--   and SATO > -50 and SATO <= 0
--   and SATO > 0   and SATO <= 50
--   and SATO > 50

--    and tpoType='BROKER'
--    and tpoType='CORRES'
--    and tpoType in ('BROKER', 'CORRES', 'TPO')     -- Non-Retail
--    and tpoType not in ('BROKER', 'CORRES', 'TPO') -- Retail
--    and tpoType not in ('BROKER', 'CORRES', 'TPO') and isCashWindow = 'Y'  -- CashWindow
    and tpoType not in ('BROKER', 'CORRES', 'TPO') and isCashWindow != 'Y' -- NonCashWindow
--    and (tpoType='CORRES' or tpoType not in ('BROKER', 'CORRES', 'TPO') and isCashWindow = 'Y')  -- Corres and CashWindow



-- and refi_incentive_eligible_fixed_cost>=-99999999 and refi_incentive_eligible_fixed_cost<=99999999
 and agency in ( 'FHL')
                    group by 
	                    groupByColumn, md1.modelId
					having 
						1=1
						
-- and sum(schamBalance) >100000000
                    order by 
	                    groupByColumn, md1.modelId
;
commit;
