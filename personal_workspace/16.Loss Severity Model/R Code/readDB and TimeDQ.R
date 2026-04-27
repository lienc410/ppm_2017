library(RODBC)

ch <- odbcConnect("Agency", believeNRows=FALSE)

# Query data for loan list
query <- "select distinct LoanId FROM fhl.LoanLevelHistMonthlyPerformData where delinqStatus != '0'"
LoanList <- sqlQuery(ch, query)

close(ch)




TimesOfDLQ <- 0
for(loanCounter in 1:nrow(LoanList))
{
  # Query data for one loan
  query <- paste("select * FROM fhl.LoanLevelHistMonthlyPerformData WHERE loanID = '",LoanList[loanCounter,],"' order by asof", sep = "", collapse = NULL)
  PerfData <- sqlQuery(ch, query)
  
  i <- 2
  while (i <= nrow(PerfData))
  {
    if (PerfData[i,]$delinqStatus != 0)
    {
     
      if(is.na(PerfData[i,]$zeroBalanceCode))
      {
        j <- i
        
        while (j <= nrow(PerfData))
        {
          # Get the delinqStatus number a loan goes to REO
          if (PerfData[j,]$delinqStatus == 'R')
          {
            i <- j
            
              if(TimesOfDLQ == 0)
              {
                Output <- data.frame(LoanID = PerfData[j-1,]$LoanId, Index = j-1, DelinqStatus = PerfData[j-1,]$delinqStatus, EndStatus = "REO")
              } else               
              {
                Partial <- data.frame(LoanID = PerfData[j-1,]$LoanId, Index = j-1, DelinqStatus = PerfData[j-1,]$delinqStatus, EndStatus = "REO")
                Output <- rbind(Output, Partial)
              }
              TimesOfDLQ <- TimesOfDLQ + 1
            
            break
          } else if (as.numeric(PerfData[j,]$delinqStatus) < as.numeric(PerfData[j-1,]$delinqStatus))
          {
            # Get the max delinqStatus number a loan can go back to current after dlq
            i <- j
            
            if(TimesOfDLQ == 0)
            {
              Output <- data.frame(LoanID = PerfData[j-1,]$LoanId, Index = j-1, DelinqStatus = as.numeric(PerfData[j-1,]$delinqStatus), EndStatus = "btc")
            } else               
            {
              Partial <- data.frame(LoanID = PerfData[j-1,]$LoanId, Index = j-1, DelinqStatus = as.numeric(PerfData[j-1,]$delinqStatus), EndStatus = "btc")
              Output <- rbind(Output, Partial)
            }
            TimesOfDLQ <- TimesOfDLQ + 1
            
            break
          }
          
          j <- j + 1
        }
      } else if(PerfData[i,]$zeroBalanceCode == 3)
      {
        # Get the delinqStatus number a loan goes to Foreclosure
        if(TimesOfDLQ == 0)
        {
          Output <- data.frame(LoanID = PerfData[j-1,]$LoanId, Index = j-1, DelinqStatus = as.numeric(PerfData[j-1,]$delinqStatus), EndStatus = "FC")
        } else               
        {
          Partial <- data.frame(LoanID = PerfData[j-1,]$LoanId, Index = j-1, DelinqStatus = as.numeric(PerfData[j-1,]$delinqStatus), EndStatus = "FC")
          Output <- rbind(Output, Partial)
        }
        TimesOfDLQ <- TimesOfDLQ + 1
      } 
    }
    
    i <- i + 1
  }
}


write.csv(Output, "data/LoanForeclosureTimeCount.csv", row.names = FALSE)