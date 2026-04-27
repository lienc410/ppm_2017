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

### Reading raw data
#
rawData <- read.csv("data/tempFHL.txt")

# rawData <- read.csv("data/tempFNM.txt")



### Fitting Generalized Linear Models 
#
BaseLossRegression <- function(data) {
  
  # xy.rg <- glm(rawData$DiscountPct.~rawData$beginLoanAge.+rawData$JudicialFlag.+rawData$origbalance.+rawData$loanpurpose.+rawData$occupancyStatus.+rawData$propertyType.+rawData$timeDQ.+rawData$HPA.)
  #   Base.rg <- glm(data$DiscountPct.~ data$beginLoanAge.+data$JudicialFlag.+data$origbalance.+data$loanpurpose.
  #                +data$occupancyStatus.+data$propertyType.+data$timeDQ.+ data$HPA2Yr.)
  Base.rg <- glm(data$DiscountPct~ data$beginLoanAge + data$JudicialFlag + data$origbalance + data$loanpurpose
                 + data$occupancyStatus + data$propertyType + data$timeDQ + data$HPA2Yr)
  # +rawData$zeroBalanceCode
  print(summary(Base.rg))
  
  ## Projecting using refression result
  estimateDiscountPct <- predict(Base.rg, type='response',newdata=data)
  
  ### calculate base loss
  #   data$ActuralBaseLoss <- data$UPB - data$netSaleProceeds
  data$EstimateBaseLoss <- data$UPB - (data$currentValue * estimateDiscountPct / 100)
  
  #   return(data)
}

### Fitting Generalized Linear Models 
#
ExpensesRegression <- function(data) {
  
  #   JudicialFlag: vary from states; timeDQ: time in delinquency;  AvgNSAIndex: 2 year moving average of USA level HPI
  #   Expensesrg <- glm(data$expenses ~ data$JudicialFlag + data$timeDQ + data$NSAInde + data$UPB)
  Expenses.rg <- glm(data$expenses ~ data$JudicialFlag + data$timeDQ + data$UPB)
  
  #   Expenses.rg <- glm(data$expenses ~ data$state + data$timeDQ + data$AvgNSAInde + data$UPB)
  print(summary(Expenses.rg))
  
  ### Projecting using refression result
  #
  estimateExpenses <- predict(Expenses.rg, type='response', newdata=data)
}



GroupByMonth <- function(data) {
  ### Expense Group by Month
  #
  data$ActuralBaseLoss <- data$UPB - data$netSaleProceeds
  Output1 <- data.frame(data$lossDate,
                        #                         data$expenses, data$estimateExpenses, 
                        #                         data$ActuralBaseLoss, data$estimateBassLoss, 
                        #                                               data$estimateInterest, 
                        #                         data$miRecoveries, data$estimateMIRecoveries,
                        data$ActuralLossBEI, data$estimateTotalLossBEI,
                        data$ActuralLossBEIM, data$estimateTotalLossBEIM,
                        data$ActuralLoss, data$estimateTotal,
                        #                         data$ActuralSeverity, data$estimateTotalSeverity,
                        data$UPB
  )
  Output <- na.omit(Output1)
  
  ## split data by loss date
  sp <- split(Output,Output[,c("data.lossDate")],drop=TRUE) 
  #   ## aggregate Bass Loss by month
  #   aggActuralBaseLoss <- lapply(sp,FUN=function(x) weighted.mean((x$data.ActuralBaseLoss / x$data.UPB), x$data.UPB)) 
  #   aggEstimBassLoss <- lapply(sp,FUN=function(x) weighted.mean((x$data.estimateBassLoss / x$data.UPB), x$data.UPB)) 
  #   
  #   ## aggregate Expenses by month
  #   aggActualExpenses <- lapply(sp,FUN=function(x) weighted.mean((-x$data.expenses. / x$data.UPB), x$data.UPB)) 
  #   aggEstimExpenses <- lapply(sp,FUN=function(x) weighted.mean((-x$data.estimateExpenses / x$data.UPB), x$data.UPB)) 
  
  ## aggregate Total Loss BEI
  aggActuralTotalLossBEI <- lapply(sp,FUN=function(x) weighted.mean((x$data.ActuralLossBEI/ x$data.UPB), x$data.UPB)) 
  aggEstimTotalLossBEI <- lapply(sp,FUN=function(x) weighted.mean((x$data.estimateTotalLossBEI/ x$data.UPB), x$data.UPB)) 
  
  ## aggregate Total Loss BEIM
  aggActuralTotalLossBEIM <- lapply(sp,FUN=function(x) weighted.mean((x$data.ActuralLossBEIM/ x$data.UPB), x$data.UPB)) 
  aggEstimTotalLossBEIM <- lapply(sp,FUN=function(x) weighted.mean((x$data.estimateTotalLossBEIM/ x$data.UPB), x$data.UPB)) 
  
  ## aggregate Total Loss BEIMN
  aggActuralTotalLoss <- lapply(sp,FUN=function(x) weighted.mean((x$data.ActuralLoss/ x$data.UPB), x$data.UPB)) 
  aggEstimTotalLoss <- lapply(sp,FUN=function(x) weighted.mean((x$data.estimateTotal/ x$data.UPB), x$data.UPB)) 
  
  #   ## aggregate Total Severity
  #   aggActuralTotalSeverity <- lapply(sp,FUN=function(x) weighted.mean(x$data.ActuralSeverity., x$data.UPB)) 
  #   aggEstimTotalSeverity <- lapply(sp,FUN=function(x) weighted.mean(x$data.estimateTotalSeverity, x$data.UPB)) 
  
  ### Construct return matix
  result<-cbind(
    #                 aggActuralBaseLoss, aggEstimBassLoss, 
    #                 aggActualExpenses,aggEstimExpenses,
    #                 aggEstimInterest, 
    #                 aggActualMIRecoveries, aggEstimMIRecoveries, 
    aggActuralTotalLossBEI, aggEstimTotalLossBEI,
    aggActuralTotalLossBEIM, aggEstimTotalLossBEIM,
    aggActuralTotalLoss, aggEstimTotalLoss
    #                 aggActuralTotalSeverity, aggEstimTotalSeverity
  ) 
}




# rawData <- na.omit(rawData)


# rawData$ActuralLossBEI.


### Change columns to factor, prepared for regression
#
rawData$zeroBalanceCode <- as.factor(rawData$zeroBalanceCode) 
# rawData$expenses. <- rawData$expenses. + rawData$nonMIRecoveries.
# rawData$year. <- as.factor(rawData$year.) 
# gc()   # Garbage Collection

### Subset data for FC and REO
#
rawDataFC <- subset(rawData,zeroBalanceCode =='3')
rawDataREO <- subset(rawData,zeroBalanceCode =='9')

# rawDataFC <- subset(rawData, zeroBalanceCode.== 3)
# rawDataREO <- subset(rawData, zeroBalanceCode.== 9)


### Fitting Generalized Linear Models #####
#
## Fitting Base
rawDataFC$estimateBassLoss <- BaseLossRegression(rawDataFC)
rawDataREO$estimateBassLoss <- BaseLossRegression(rawDataREO)

## Fitting Expenses 
#  Expenses is a nagtive as to follow that Freddie Mac practice
rawDataFC$estimateExpenses <- ExpensesRegression(rawDataFC)
rawDataREO$estimateExpenses <- ExpensesRegression(rawDataREO)


## Calculate Accrued Interest
rawDataFC$estimateInterest <- rawDataFC$timeDQ* rawDataFC$UPB * 1/12 * (rawDataFC$beginCoupon - 0.25 )/100
rawDataREO$estimateInterest <- rawDataREO$timeDQ* rawDataREO$UPB * 1/12 * (rawDataREO$beginCoupon - 0.25 )/100

## Calculate MI recoveries
MIHaircut <- 0.8
rawDataFC$estimateMIRecoveries <- rawDataFC$miLevel / 100 * (rawDataFC$UPB + rawDataFC$estimateInterest + rawDataFC$estimateExpenses) * MIHaircut
rawDataREO$estimateMIRecoveries <- rawDataREO$miLevel / 100 * (rawDataREO$UPB + rawDataREO$estimateInterest + rawDataREO$estimateExpenses) * MIHaircut

## Calculate MI recoveries
NonMIRatio <- 0.75
rawDataFC$estimateNonMIRecoveries <- rawDataFC$estimateMIRecoveries * NonMIRatio
rawDataREO$estimateNonMIRecoveries <- rawDataREO$estimateMIRecoveries * NonMIRatio
# 
# ## Calculate Total Loss
# rawDataFC$estimateTotalLoss <- rawDataFC$estimateBassLoss + rawDataFC$estimateInterest - rawDataFC$estimateExpenses - rawDataFC$estimateMIRecoveries
# rawDataREO$estimateTotalLoss <- rawDataREO$estimateBassLoss + rawDataREO$estimateInterest - rawDataREO$estimateExpenses - rawDataREO$estimateMIRecoveries
# 
# # ## change neegative number into 0
# # rawDataFC$estimateTotalLoss[rawDataFC$estimateTotalLoss < 0] <- 0
# # rawDataREO$estimateTotalLoss[rawDataREO$estimateTotalLoss < 0] <- 0
# 
# ## Calculate Total Severity
# rawDataFC$estimateTotalSeverity <- rawDataFC$estimateTotalLoss / rawDataFC$UPB
# rawDataREO$estimateTotalSeverity <- rawDataREO$estimateTotalLoss / rawDataREO$UPB

## Calculate Total Loss (Base + Expenses + Interest)
rawDataFC$estimateTotalLossBEI <- rawDataFC$estimateBassLoss + rawDataFC$estimateExpenses + rawDataFC$estimateInterest
rawDataREO$estimateTotalLossBEI <- rawDataREO$estimateBassLoss + rawDataREO$estimateExpenses + rawDataREO$estimateInterest

## Calculate Total Loss (Base + Expenses + Interest - MIRecoveries)
rawDataFC$estimateTotalLossBEIM <- rawDataFC$estimateBassLoss + rawDataFC$estimateExpenses + rawDataFC$estimateInterest - rawDataFC$estimateMIRecoveries
rawDataREO$estimateTotalLossBEIM <- rawDataREO$estimateBassLoss + rawDataREO$estimateExpenses + rawDataREO$estimateInterest - rawDataREO$estimateMIRecoveries

## Calculate Total Loss (Base + Expenses + Interest - MIRecoveries - nonMIRecoveries)
rawDataFC$estimateTotal <- rawDataFC$estimateBassLoss + rawDataFC$estimateExpenses + rawDataFC$estimateInterest - rawDataFC$estimateMIRecoveries - rawDataFC$estimateNonMIRecoveries
rawDataREO$estimateTotal <- rawDataREO$estimateBassLoss + rawDataREO$estimateExpenses + rawDataREO$estimateInterest - rawDataREO$estimateMIRecoveries - rawDataREO$estimateNonMIRecoveries



### Group by Month #####
#
resultFC <- GroupByMonth(rawDataFC)
resultREO <- GroupByMonth(rawDataREO)

combinedData <- rbind(rawDataFC, rawDataREO)
                      
result <- GroupByMonth(combinedData)
resultFC <- GroupByMonth(rawDataFC)
resultREO <- GroupByMonth(rawDataREO)

write.csv(result, "data/result.csv", row.names = FALSE)
write.csv(resultFC, "data/result_FC.csv", row.names = FALSE)
write.csv(resultREO, "data/result_REO.csv", row.names = FALSE)




