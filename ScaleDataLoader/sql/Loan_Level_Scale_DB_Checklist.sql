-- Checking Process for Loading Data into Scale Database

--!! Always do data check for temp table before loading data into scale database table !!

-- Checking Process Step-by-step




-- Step 1-2. Set-Up &  Load Basic Data


--- Check 1.1 Check Start Factor Date

select * from #tmp_asOf

--- Check 1.2 Check Database Version

select * from #tmp_version

--- Check 1.3 Check marketTicker List

select * from #ticker

-- Generate Temp Table #FHL_Loan & #FHL_LoanHist

--- Check 1.4  Check Missing Time Period

select distinct(originationDate) from #FHL_Loan order by originationDate
select distinct(asOf) from #FHL_LoanHist order by asOf

--- Check 1.5 Check NULL or Wrong Value
--- balance (>0)

 declare   @cnt int
        SELECT
            @cnt =  count(1)
        FROM #FHL_LoanHist  WHERE balance IS NULL OR balance < 0.0

        if (@cnt > 0)
        BEGIN
            RAISERROR 99999 'FHL Loans with INVALID VALUE for Balance LoanCount : %1!', @cnt
            RETURN
        END
		
--- cltv (>=0, <=1000)

 declare   @cnt int
        SELECT
            @cnt =  count(1)
        FROM #FHL_LoanHist  WHERE cltv IS NULL OR cltv <= 0.0 OR cltv > 1000

        if (@cnt > 0)
        BEGIN
            RAISERROR 99999 'FHL Loans with INVALID VALUE for  CLTV LoanCount : %1!', @cnt
            RETURN
        END
		
--- origLoanSize (>0, <10000000)

 declare   @cnt int
         SELECT
            @cnt =  count(1)
        FROM #FHL_Loan  WHERE    origLoanSize IS NULL OR origLoanSize <= 0.0 OR origLoanSize > 10000000

        if (@cnt > 0)
        BEGIN
            RAISERROR 99999 'FHL Loans with INVALID VALUE for origLoanSize LoanCount : %1!', @cnt
            RETURN
        END
		
--- numberUnits (>0, <10)

 declare   @cnt int
        SELECT
            @cnt =  count(1)
        FROM #FHL_Loan  WHERE   numberUnits IS NULL OR numberUnits <= 0 OR numberUnits > 10

        if (@cnt > 0)
        BEGIN
            RAISERROR 99999 'FHL Loans with INVALID VALUE for numberUnits LoanCount : %1!', @cnt
            RETURN
        END
		
--- origFICO (>0, <=900)

 declare   @cnt int
        SELECT
            @cnt =  count(1)
        FROM #FHL_Loan  WHERE   origFICO IS NULL OR origFICO <= 0.0 OR origFICO > 900

        if (@cnt > 0)
        BEGIN
            RAISERROR 99999 'FHL Loans with INVALID VALUE for origFICO LoanCount : %1!', @cnt
            RETURN
        END

--- origLTV (>0, <=1000)

 declare   @cnt int
        SELECT
            @cnt =  count(1)
        FROM #FHL_Loan  WHERE   origLTV IS NULL OR origLTV <= 0.0 OR origLTV > 1000

        if (@cnt > 0)
        BEGIN
            RAISERROR 99999 'FHL Loans with INVALID VALUE for origLTV LoanCount : %1!', @cnt
            RETURN
        END
		
--- origNoteRate (>0, <=20)

 declare   @cnt int
        SELECT
            @cnt =  count(1)
        FROM #FHL_Loan  WHERE    origNoteRate IS NULL OR origNoteRate <= 0.0 OR origNoteRate > 20

        if (@cnt > 0)
        BEGIN
            RAISERROR 99999 'FHL Loans with INVALID VALUE for origNoteRate LoanCount : %1!', @cnt
            RETURN
        END
		
--- miLevel (>0, <=80)

 declare   @cnt int
        SELECT
            @cnt =  count(1)
        FROM #FHL_Loan  WHERE   miLevel IS NULL OR miLevel < 0.0 OR miLevel > 80

        if (@cnt > 0)
        BEGIN
            RAISERROR 99999 'FHL Loans with INVALID VALUE for miLevel LoanCount : %1!', @cnt
            RETURN
        END
		
--- HPI_orig (>0, <=1000)

 declare   @cnt int
        SELECT
            @cnt =  count(1)
        FROM #FHL_Loan  WHERE  HPI_orig IS NULL OR HPI_orig < 0.0 OR HPI_orig > 1000

        if (@cnt > 0)
        BEGIN
            RAISERROR 99999 'FHL Loans with INVALID VALUE for HPI_orig LoanCount : %1!', @cnt
            RETURN
        END

--- hpa (>=0.5, <=10)

 declare   @cnt int
        SELECT
            @cnt =  count(1)
        FROM #FHL_LoanHist  WHERE  hpa IS NULL OR hpa < 0.5 OR hpa > 10

        if (@cnt > 0)
        BEGIN
            RAISERROR 99999 'FHL Loans with INVALID VALUE for  HPA LoanCount : %1!', @cnt
            RETURN
        END

--- hpa_2yr (>=0.5, <=1.5)

 declare   @cnt int
        SELECT
            @cnt =  count(1)
        FROM #FHL_Loan  WHERE  HPI_orig IS NULL OR HPI_orig < 0.0 OR HPI_orig > 1000

        if (@cnt > 0)
        BEGIN
            RAISERROR 99999 'FHL Loans with INVALID VALUE for HPI_orig LoanCount : %1!', @cnt
            RETURN
        END


--- Check 1.6 Count of current month changes in a noticeable amount compare with previous month

 declare   @cnt int
 declare   @cnt_previous int
        SELECT
            @cnt =  count(1)
        FROM #FHL_LoanHist WHERE asof = (SELECT asOf FROM #tmp_asOf)

        SELECT
            @cnt_previous =  count(1)
        FROM scale.FHL_LoanHist WHERE asof = (SELECT dateadd(month, -1, asOf) FROM #tmp_asOf)
        
        if (@cnt - @cnt_previous > 0.1 * @cnt_previous OR @cnt_previous - @cnt > 0.1 * @cnt_previous)
        BEGIN
            RAISERROR 99999 'FHL LoanHist with INVALID COUNT compare with previous month. Currnt: %1!; Previous: %2!', @cnt, @cnt_previous
            RETURN
        END 
		


-- Step 3  Update HARPed Percentage (Step 1)

--- Check 3.1 Setup Check (same as step 1)

--- Check 3.2 Check count of percentHARPed

select count(1) from #FHL_HARPStatus where percentHARPed=0.0
select count(1) from #FHL_HARPStatus where percentHARPed=100.0
select count(1) from #FHL_HARPStatus where percentHARPed not in (0.0, 100.0)

--- Check 3.3 Check NULL Value

--- percentHARPed (0.0 or 100.0)
declare   @cnt int
        SELECT
            @cnt =  count(1)
        FROM #FHL_HARPStatus  WHERE percentHARPed IS NULL

        if (@cnt > 0)
        BEGIN
            RAISERROR 99999 'FHL Loans with NULL VALUE for  percentHARPed LoanCount : %1!', @cnt
            RETURN
        END
		
		
-- Step 4  Update Origination PMI

--- Check 4.1 Setup Check (same as step 1)

--- Check 4.2 Check NULL or Wrong Value

--- pmi_begin (>=0, <=5)
 declare   @cnt int
        SELECT
            @cnt =  count(1)
        FROM #FHL_OrigPMI  WHERE pmi_begin IS NULL

        if (@cnt > 0)
        BEGIN
            RAISERROR 99999 'FHL Loans with NULL VALUE for  pmi_begin LoanCount : %1!', @cnt
            RETURN
        END

 declare   @cnt int
        SELECT
            @cnt =  count(1)
        FROM #FHL_OrigPMI  WHERE pmi_begin < 0.0 OR pmi_begin > 5

        if (@cnt > 0)
        BEGIN
            RAISERROR 99999 'FHL Loans with INVALID RANGE VALUE for  pmi_begin LoanCount : %1!', @cnt
            RETURN
        END
		
-- Step 5  Update HARP_eligible, conventional_eligible and fha_eligible

--- Check 5.1 Setup Check (same as step 1)

--- Check 5.2 Check count of eligibility

select count(1) from #FHL_harp_eligibility where HARP_eligible=0.0
select count(1) from #FHL_harp_eligibility where HARP_eligible=1
select count(1) from #FHL_harp_eligibility where HARP_eligible not in (0.0, 1)

select count(1) from #FHL_conventional_eligibility where conventional_eligible=0.0
select count(1) from #FHL_conventional_eligibility where conventional_eligible=1
select count(1) from #FHL_conventional_eligibility where conventional_eligible not in (0.0, 1)

select count(1) from #FHL_fha_eligibility where fha_eligible=0.0
select count(1) from #FHL_fha_eligibility where fha_eligible=1
select count(1) from #FHL_fha_eligibility where fha_eligible not in (0.0, 1)

--- Check 5.3 Check Update if FHA Eligible is updated for INVESTOR / 2ND

 declare   @cnt int 
 SELECT
            @cnt =  count(1)
        FROM
            #FHL_fha_eligibility e
        JOIN 
            fhl.PIV_Loan cl ON e.loanSeqNum = cl.loanSeqNum
        WHERE
            fha_eligible > 0.0
        AND
            cl.occType in ('2ND', 'INV')

        if (@cnt > 0)  
        BEGIN
            RAISERROR 99999 'FHL Loans with Invalid FHA Eligible is updated for INVESTOR / 2ND Range LoanCount : %1!', @cnt
            RETURN
        END 
		
--- Check 5.4 Check NULL Value
  declare   @cnt int 
        SELECT
            @cnt =  count(1)
        FROM #FHL_harp_eligibility  WHERE HARP_eligible IS NULL 

        if (@cnt > 0)  
        BEGIN
            RAISERROR 99999 'FHL Loans with NULL HARP Eligibility LoanCount : %1!', @cnt
            RETURN
        END  
		
   declare   @cnt int 
		SELECT
            @cnt =  count(1)
        FROM #FHL_conventional_eligibility  WHERE conventional_eligible IS NULL

        if (@cnt > 0)  
        BEGIN
            RAISERROR 99999 'FHL Loans with NULL Conventional Eligibility LoanCount : %1!', @cnt
            RETURN
        END  
		
   declare   @cnt int 
		SELECT
            @cnt =  count(1)
        FROM #FHL_fha_eligibility  WHERE fha_eligible IS NULL

        if (@cnt > 0)  
        BEGIN
            RAISERROR 99999 'FHL Loans with NULL FHA Eligibility LoanCount : %1!', @cnt
            RETURN
		END  
		
--- Check 5.5 Check no duplicates
  declare   @cnt int
        SELECT
            @cnt =  count(1)
        FROM
            (SELECT loanSeqnum, asOf, count(1) as cnt FROM #FHL_conventional_eligibility GROUP BY loanSeqnum, asOf HAVING count(1) > 1) t

        if (@cnt > 0) 
        BEGIN
            RAISERROR 99999 'FHL Loans with Invalid FHA Eligibile Range LoanCount : %1!', @cnt
            RETURN
        END 
		
		
--- Check 5.6 Check if count of current month changes in a noticeable amount compare with previous month
  declare   @cnt int
  declare   @cnt_previous int
        SELECT
            @cnt =  count(1)
        FROM #FHL_conventional_eligibility WHERE asof = (SELECT asOf FROM #tmp_asOf)

        SELECT
            @cnt_previous =  count(1)
        FROM scale.FHL_LoanEligibility WHERE asof = (SELECT dateadd(month, -1, asOf) FROM #tmp_asOf)
        
        if (@cnt - @cnt_previous > 0.1 * @cnt_previous OR @cnt_previous - @cnt > 0.1 * @cnt_previous)
        BEGIN
            RAISERROR 99999 'FHL LoanEligibility with INVALID COUNT compare with previous month. Currnt: %1!; Previous: %2!', @cnt, @cnt_previous
            RETURN
        END    


-- Step 6  Update refi_incentive, currLLPA and currPMI

--- Check 6.1 Setup Check (same as step 1)

--- Check 6.2 Check NULL value	
select count(1) from #FHL_LoanIncentive where conv_incentive is NULL
select count(1) from #FHL_LoanIncentive where fha_incentive is NULL
select count(1) from #FHL_LoanIncentive where refi_incentive is NULL
select count(1) from #FHL_LoanIncentive where llpa is NULL
select count(1) from #FHL_LoanIncentive where pmi is NULL
select count(1) from #FHL_LoanIncentive where mip is NULL

declare   @cnt int
        SELECT
            @cnt =  count(1)
        FROM #FHL_LoanIncentive WHERE conv_incentive IS NULL

        if (@cnt > 0)
        BEGIN
            RAISERROR 99999 'FHL Loans with NULL conv_incentive LoanCount : %1!', @cnt
            RETURN
        END

		
        SELECT
            @cnt =  count(1)
        FROM #FHL_LoanIncentive WHERE fha_incentive IS NULL

        if (@cnt > 0)
        BEGIN
            RAISERROR 99999 'FHL Loans with NULL fha_incentive LoanCount : %1!', @cnt
            RETURN
        END

		
        SELECT
            @cnt =  count(1)
        FROM #FHL_LoanIncentive WHERE llpa IS NULL

        if (@cnt > 0)
        BEGIN
            RAISERROR 99999 'FHL Loans with NULL llpa LoanCount : %1!', @cnt
            RETURN
        END

		
        SELECT
            @cnt =  count(1)
        FROM #FHL_LoanIncentive WHERE pmi IS NULL

        if (@cnt > 0)
        BEGIN
            RAISERROR 99999 'FHL Loans with NULL pmi LoanCount : %1!', @cnt
            RETURN
        END

		
        SELECT
            @cnt =  count(1)
        FROM #FHL_LoanIncentive WHERE mip IS NULL

        if (@cnt > 0)
        BEGIN
            RAISERROR 99999 'FHL Loans with NULL mip LoanCount : %1!', @cnt
            RETURN
        END
		
--- Check 6.3 Check Wrong Value

--- conv_incentive (>=-20.0, <=20.0)
 declare   @cnt int
 SELECT
            @cnt =  count(1)
        FROM
            #FHL_LoanIncentive
        WHERE
            conv_incentive < -20.0 OR conv_incentive > 20.0

        if (@cnt > 0)
        BEGIN
            RAISERROR 99999 'FHL Loans with Invalid conv_incentive Range LoanCount : %1!', @cnt
            RETURN
        END
		
--- fha_incentive (>=-20.0, <=20.0)
 declare   @cnt int
 SELECT
            @cnt =  count(1)
        FROM
            #FHL_LoanIncentive
        WHERE
            fha_incentive < -20.0 OR fha_incentive > 20.0

        if (@cnt > 0)
        BEGIN
            RAISERROR 99999 'FHL Loans with Invalid fha_incentive Range LoanCount : %1!', @cnt
            RETURN
        END
		
--- refi_incentive (>=-20.0, <=20.0)
 declare   @cnt int
 SELECT
            @cnt =  count(1)
        FROM
            #FHL_LoanIncentive
        WHERE
            refi_incentive_eligible < -20.0 OR refi_incentive_eligible > 20.0

        if (@cnt > 0)
        BEGIN
            RAISERROR 99999 'FHL Loans with Invalid refi_incentive_eligible Range LoanCount : %1!', @cnt
            RETURN
        END
		
--- llpa (>=-1, <=20.0)
 declare   @cnt int
 SELECT
            @cnt =  count(1)
        FROM
            #FHL_LoanIncentive
        WHERE
            llpa < -1 OR llpa > 20.0

        if (@cnt > 0)
        BEGIN
            RAISERROR 99999 'FHL Loans with Invalid llpa Range LoanCount : %1!', @cnt
            RETURN
        END
		
--- pmi (>=0, <=10.0)
 declare   @cnt int
 SELECT
            @cnt =  count(1)
        FROM
            #FHL_LoanIncentive
        WHERE
            pmi < 0 OR pmi > 10.0

        if (@cnt > 0)
        BEGIN
            RAISERROR 99999 'FHL Loans with Invalid pmi Range LoanCount : %1!', @cnt
            RETURN
        END
		
--- mip (>=0, <=5.0)
 declare   @cnt int
 SELECT
            @cnt =  count(1)
        FROM
            #FHL_LoanIncentive
        WHERE
            mip < 0 OR mip > 5.0

        if (@cnt > 0)
        BEGIN
            RAISERROR 99999 'FHL Loans with Invalid mip Range LoanCount : %1!', @cnt
            RETURN
        END
		
--- Check 6.4 Check if count of current month changes in a noticeable amount compare with previous month
  declare   @cnt int
  SELECT
            @cnt =  count(1)
        FROM #FHL_LoanIncentive WHERE asof = (SELECT asOf FROM #tmp_asOf where asOf>'19940101') 

        SELECT
            @cnt_previous =  count(1)
        FROM scale.FHL_LoanIncentive WHERE asof = (SELECT dateadd(month, -1, asOf) FROM #tmp_asOf  where asOf>'19940101') AND version = (select  version from #tmp_version)
        
        if (@cnt - @cnt_previous > 0.1 * @cnt_previous OR @cnt_previous - @cnt > 0.1 * @cnt_previous)
        BEGIN
            RAISERROR 99999 'FHL LoanIncentive with INVALID COUNT compare with previous month. Current: %1!; Previous: %2!', @cnt, @cnt_previous
            RETURN
        END

-- Step 7 	Update HARPed Percentage (Step 2)	

--- Check 7.1 Setup Check (same as step 1)

--- Check 7.2 Check count of pctHARPed

select count(1) from #FHL_regression where pctHARPed=0.0
select count(1) from #FHL_regression where pctHARPed=100.0
select count(1) from #FHL_regression where pctHARPed not in (0.0, 100.0)

--- Check 7.3 Check NULL Value

--- pctHARPed (0.0 or 100.0)
declare   @cnt int
        SELECT
            @cnt =  count(1)
        FROM ##FHL_regression  WHERE pctHARPed IS NULL

        if (@cnt > 0)
        BEGIN
            RAISERROR 99999 'FHL Loans with NULL VALUE for  pctHARPed LoanCount : %1!', @cnt
            RETURN
        END
		
-- Step 8  Update Burnout

--- Check 8.1 Setup Check (same as step 1)

--- Check 8.2 Check NULL Value
declare   @cnt int
SELECT
            @cnt =  count(1)
        FROM #FHL_LoanBurnout WHERE burnout IS NULL

        if (@cnt > 0)
        BEGIN
            RAISERROR 99999 'FHL Loans with NULL Burnout LoanCount : %1!', @cnt
            RETURN
        END
		
--- Check 8.3 Check Wrong Value

--- burnout (>=0.0)
declare   @cnt int
SELECT
            @cnt =  count(1)
        FROM
            #FHL_LoanBurnout
        WHERE
            burnout < 0.0 

        if (@cnt > 0)
        BEGIN
            RAISERROR 99999 'FHL Loans with Invalid burnout Range LoanCount : %1!', @cnt
            RETURN
        END
		
--- Check 8.4 Check if count of current month changes in a noticeable amount compare with previous month
    declare   @cnt_previous int
    SELECT
            @cnt =  count(1)
        FROM #FHL_LoanBurnout WHERE asof = (SELECT asOf FROM #tmp_asOf where asOf>'20060901')

        SELECT
            @cnt_previous =  count(1)
        FROM scale.FHL_LoanBurnout WHERE asof = (SELECT dateadd(month, -1, asOf) FROM #tmp_asOf where asOf>'20060901') AND version = (select  version from #tmp_version)
        
        if (@cnt - @cnt_previous > 0.1 * @cnt_previous OR @cnt_previous - @cnt > 0.1 * @cnt_previous)
        BEGIN
            RAISERROR 99999 'FHL LoanBurnout with INVALID COUNT compare with previous month. Current: %1!; Previous: %2!', @cnt, @cnt_previous
            RETURN
        END    