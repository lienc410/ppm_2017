# clear all the data in workspace
rm(list = ls())
library(nnet)


# set up your working directory here
setwd("C:/Lien Workspace/16.Loss Severity Model/R Code/")

includeFunc <- function(name) {
  fileName = paste(getwd(),"/",name,sep="");
  
  if(file.exists(fileName)) {
    source(fileName);
  } else {
    cat("can not find ", fileName, "\n");
  }
}


BaseLossRegression <- function(data) {
  ## Fitting Generalized Linear Models  
  # xy.rg <- glm(rawData$X.DiscountPct.~rawData$X.beginLoanAge.+rawData$X.JudicialFlag.+rawData$X.origbalance.+rawData$X.loanpurpose.+rawData$X.occupancyStatus.+rawData$X.propertyType.+rawData$X.timeDQ.+rawData$X.HPA.)
  Base.rg <- glm(data$X.baseSev.~ data$X.beginLoanAge.+data$X.JudicialFlag.+data$X.origbalance.+data$X.loanpurpose.
                 +data$X.occupancyStatus.+data$X.propertyType.+data$X.timeDQ.+data$X.AvgNSAIndex.)
  # +rawData$X.zeroBalanceCode.
  print(summary(Base.rg))
  
  ## Projecting using refression result
  estimateBassSev <- predict(Base.rg, type='response',newdata=data)
  
  ### calculate base loss
  #   data$ActuralBaseLoss <- data$X.UPB. - data$X.netSaleProceeds.
  data$EstimateBaseLoss <- estimateBassSev
  
  #   return(data)
}


ExpensesRegression <- function(data) {
  ### Fitting Generalized Linear Models  
  #   JudicialFlag: vary from states; timeDQ: time in delinquency;  AvgNSAIndex: 2 year moving average of USA level HPI
  Expenses.rg <- glm(data$X.expensesSev. ~ data$X.JudicialFlag. + data$X.timeDQ. + data$X.AvgNSAIndex. + data$X.UPB.)
  
  #   Expenses.rg <- glm(data$X.expenses. ~ data$X.state. + data$X.timeDQ. + data$X.AvgNSAIndex. + data$X.UPB.)
  print(summary(Expenses.rg))
  
  ### Projecting using refression result
  #
  estimateExpenses <- predict(Expenses.rg, type='response', newdata=data)
}



GroupByMonth <- function(data) {
  ### Expense Group by Month
  #
  data$ActuralBaseLoss <- data$X.UPB. - data$X.netSaleProceeds.
  Output1 <- data.frame(data$X.lossDate.,
                        data$X.expensesSev., data$estimateExpenses, 
                        data$X.baseSev., data$estimateBassLoss, 
                        data$estimateInterest, 
                        data$X.miRecoveries., data$estimateMIRecoveries,
                        data$X.ActuralLoss., data$estimateTotalLoss,
                        data$X.ActuralSeverity., data$estimateTotalSeverity,
                        data$X.UPB.
  )
  Output <- na.omit(Output1)
  
  ## split data by loss date
  sp <- split(Output,Output[,c("data.X.lossDate.")],drop=TRUE) 
  ## aggregate Bass Loss by month
  aggActuralBaseLoss <- lapply(sp,FUN=function(x) weighted.mean(x$data.X.baseSev., x$data.X.UPB.)) 
  aggEstimBassLoss <- lapply(sp,FUN=function(x) weighted.mean(x$data.estimateBassLoss, x$data.X.UPB.)) 
  
  ## aggregate Expenses by month
  aggActualExpenses <- lapply(sp,FUN=function(x) weighted.mean(-x$data.X.expensesSev., x$data.X.UPB.)) 
  aggEstimExpenses <- lapply(sp,FUN=function(x) weighted.mean(-x$data.estimateExpenses, x$data.X.UPB.)) 
  
  ## aggregate Accrued Interest
  aggEstimInterest <- lapply(sp,FUN=function(x) weighted.mean(x$data.estimateInterest, x$data.X.UPB.)) 
  
  ## aggregate MI recoveries
  aggActualMIRecoveries <- lapply(sp,FUN=function(x) weighted.mean(x$data.X.miRecoveries., x$data.X.UPB.)) 
  aggEstimMIRecoveries <- lapply(sp,FUN=function(x) weighted.mean(x$data.estimateMIRecoveries, x$data.X.UPB.)) 
  
  #   ## aggregate Total Loss
  #   aggActuralTotalLoss <- lapply(sp,FUN=function(x) weighted.mean(x$data.X.ActuralLoss., x$data.X.UPB.)) 
  #   aggEstimTotalLoss <- lapply(sp,FUN=function(x) weighted.mean(x$data.estimateBassLoss + x$data.estimateInterest - x$data.estimateMIRecoveries - x$data.X.expenses., x$data.X.UPB.)) 
  
  ## aggregate Total Severity
  #   aggActuralTotalSeverity <- lapply(sp,FUN=function(x) weighted.mean(x$data.X.ActuralLoss./x$data.X.UPB., x$data.X.UPB.)) 
  #   aggEstimTotalSeverity <- lapply(sp,FUN=function(x) weighted.mean((x$data.estimateBassLoss + x$data.estimateInterest - x$data.estimateMIRecoveries - x$data.estimateExpenses)
  #                                                                    /x$data.X.UPB., x$data.X.UPB.)) 
  #   aggActuralTotalSeverity1 <- lapply(sp,FUN=function(x) mean(x$data.X.ActuralLoss./x$data.X.UPB.)) 
  #   aggEstimTotalSeverity1 <- lapply(sp,FUN=function(x) mean((x$data.estimateBassLoss + x$data.estimateInterest - x$data.estimateMIRecoveries - x$data.estimateExpenses)/x$data.X.UPB.)) 
  #   
  
  ## aggregate Total Loss
  aggActuralTotalLoss <- lapply(sp,FUN=function(x) weighted.mean(x$data.X.ActuralLoss., x$data.X.UPB.)) 
  aggEstimTotalLoss <- lapply(sp,FUN=function(x) weighted.mean(x$data.estimateTotalLoss, x$data.X.UPB.)) 
  
  ## aggregate Total Severity
  aggActuralTotalSeverity <- lapply(sp,FUN=function(x) weighted.mean(x$data.X.ActuralSeverity., x$data.X.UPB.)) 
  aggEstimTotalSeverity <- lapply(sp,FUN=function(x) weighted.mean(x$data.estimateTotalSeverity, x$data.X.UPB.)) 
  
  ### Construct return matix
  result<-cbind(aggActuralBaseLoss, aggEstimBassLoss, 
                aggActualExpenses,aggEstimExpenses, 
                aggEstimInterest, 
                aggActualMIRecoveries, aggEstimMIRecoveries, 
                aggActuralTotalLoss, aggEstimTotalLoss, 
                aggActuralTotalSeverity, aggEstimTotalSeverity
  ) 
}



rawData <- read.csv("data/tempSev.txt")
# rawData <- na.omit(rawData)

### Calculate Severity for each sub-component
#


#rawData[1,]


### Change columns to factor, prepared for regression
#
rawData$X.zeroBalanceCode. <- as.factor(rawData$X.zeroBalanceCode.) 
# rawData$X.year. <- as.factor(rawData$X.year.) 
# gc()   # Garbage Collection

### Subset data for FC and REO
#
rawDataFC <- subset(rawData,X.zeroBalanceCode.=='3')
rawDataREO <- subset(rawData,X.zeroBalanceCode.=='9')

### Fitting Generalized Linear Models #####
#
## Fitting Base
rawDataFC$estimateBassLoss <- BaseLossRegression(rawDataFC)
rawDataREO$estimateBassLoss <- BaseLossRegression(rawDataREO)

## Fitting Expenses
rawDataFC$estimateExpenses <- ExpensesRegression(rawDataFC)
rawDataREO$estimateExpenses <- ExpensesRegression(rawDataREO)

## Calculate Accrued Interest
rawDataFC$estimateInterest <- (rawDataFC$X.timeDQ.* rawDataFC$X.UPB. * 1/12 * (rawDataFC$X.beginCoupon. - 0.25 )/100) / rawDataFC$X.UPB.
rawDataREO$estimateInterest <- (rawDataREO$X.timeDQ.* rawDataREO$X.UPB. * 1/12 * (rawDataREO$X.beginCoupon. - 0.25 )/100) / rawDataREO$X.UPB.

## Calculate MI recoveries
rawDataFC$estimateMIRecoveries <- (rawDataFC$X.miLevel. / 100 * (rawDataFC$X.UPB. + rawDataFC$estimateInterest + rawDataFC$estimateExpenses)) / rawDataFC$X.UPB.
rawDataREO$estimateMIRecoveries <- (rawDataREO$X.miLevel. / 100 * (rawDataREO$X.UPB. + rawDataREO$estimateInterest + rawDataREO$estimateExpenses)) / rawDataREO$X.UPB.

## Calculate Total Loss
rawDataFC$estimateTotalSeverity <- rawDataFC$estimateBassLoss + rawDataFC$estimateInterest - rawDataFC$estimateExpenses - rawDataFC$estimateMIRecoveries
rawDataREO$estimateTotalSeverity <- rawDataREO$estimateBassLoss + rawDataREO$estimateInterest - rawDataREO$estimateExpenses - rawDataREO$estimateMIRecoveries

# ## change neegative number into 0
# rawDataFC$estimateTotalLoss[rawDataFC$estimateTotalLoss < 0] <- 0
# rawDataREO$estimateTotalLoss[rawDataREO$estimateTotalLoss < 0] <- 0

## Calculate Total Severity
rawDataFC$estimateTotalLoss <- rawDataFC$estimateTotalSeverity * rawDataFC$X.UPB.
rawDataREO$estimateTotalLoss <- rawDataREO$estimateTotalSeverity * rawDataREO$X.UPB.



### Group by Month #####
#
resultFC <- GroupByMonth(rawDataFC)
resultREO <- GroupByMonth(rawDataREO)

# combinedData <- rbind(rawDataFC, rawDataREO)
combinedData <- rawDataREO

result <- GroupByMonth(combinedData)



write.csv(result, "data/resultSev.csv", row.names = FALSE)




plot(rawData$X.ActuralLoss.)
plot(rawData$X.JudicialFlag., rawData$X.timeDQ.)
plot(rawData$X.JudicialFlag., rawData$X.state.)
