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
rawData.rg <- read.csv("data/tempFHL.txt")

rawData.tgt <- read.csv("data/tempFHL.txt")



### Fitting Generalized Linear Models 
#
BaseLossRegression <- function(data.rg, data.tgt) {
  
  # xy.rg <- glm(rawData$DiscountPct.~rawData$beginLoanAge.+rawData$JudicialFlag.+rawData$origbalance.+rawData$loanpurpose.+rawData$occupancyStatus.+rawData$propertyType.+rawData$timeDQ.+rawData$HPA.)
  #   Base.rg <- glm(data$DiscountPct.~ data$beginLoanAge.+data$JudicialFlag.+data$origbalance.+data$loanpurpose.
  #                +data$occupancyStatus.+data$propertyType.+data$timeDQ.+ data$HPA2Yr.)
  Base.rg <- glm(data.rg$DiscountPct~ data.rg$beginLoanAge + data.rg$JudicialFlag + data.rg$origbalance + data.rg$loanpurpose
                 + data.rg$occupancyStatus + data.rg$propertyType + data.rg$timeDQ + data.rg$HPA2Yr)
  # +rawData$zeroBalanceCode
  print(summary(Base.rg))
  
  ## Projecting using refression result
  estimateDiscountPct <- predict(Base.rg, type='response',newdata = data.tgt)
  
  ### calculate base loss
  #   data$ActuralBaseLoss <- data$UPB - data$netSaleProceeds
  data.tgt$EstimateBaseLoss <- data.tgt$UPB - (data.tgt$currentValue * estimateDiscountPct / 100)
  
  #   return(data)
}

### Fitting Generalized Linear Models 
#
ExpensesRegression <- function(data.rg, data.tgt) {
  
  #   JudicialFlag: vary from states; timeDQ: time in delinquency;  AvgNSAIndex: 2 year moving average of USA level HPI
  #   Expensesrg <- glm(data.rg$expenses ~ data.rg$JudicialFlag + data.rg$timeDQ + data.rg$NSAInde + data.rg$UPB)
  Expenses.rg <- glm(data.rg$expenses ~ data.rg$JudicialFlag + data.rg$timeDQ + data.rg$UPB)
  
  #   Expenses.rg <- glm(data$expenses ~ data$state + data$timeDQ + data$AvgNSAInde + data$UPB)
  print(summary(Expenses.rg))
  
  ### Projecting using refression result
  #
  estimateExpenses <- predict(Expenses.rg, type='response', newdata = data.tgt)
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
rawData.rg$zeroBalanceCode <- as.factor(rawData.rg$zeroBalanceCode) 
rawData.tgt$zeroBalanceCode <- as.factor(rawData.tgt$zeroBalanceCode) 
# rawData$expenses. <- rawData$expenses. + rawData$nonMIRecoveries.
# rawData$year. <- as.factor(rawData$year.) 
# gc()   # Garbage Collection

### Subset data for FC and REO
#
# FHL 
rawDataFC.rg <- subset(rawData.rg,zeroBalanceCode =='3')
rawDataREO.rg <- subset(rawData.rg,zeroBalanceCode =='9')

# FNMA
rawDataFC.tgt <- subset(rawData.tgt, zeroBalanceCode == '3')
rawDataREO.tgt <- subset(rawData.tgt, zeroBalanceCode == '9')


### Fitting Generalized Linear Models #####
#
## Fitting Base
rawDataFC.tgt$estimateBassLoss <- BaseLossRegression(rawDataFC.rg, rawDataFC.tgt)
rawDataREO.tgt$estimateBassLoss <- BaseLossRegression(rawDataREO.rg, rawDataREO.tgt)

## Fitting Expenses 
#  Expenses is a nagtive as to follow that Freddie Mac practice
rawDataFC.tgt$estimateExpenses <- ExpensesRegression(rawDataFC.rg, rawDataFC.tgt)
rawDataREO.tgt$estimateExpenses <- ExpensesRegression(rawDataREO.rg, rawDataREO.tgt)


## Calculate Accrued Interest
rawDataFC.tgt$estimateInterest <- rawDataFC.tgt$timeDQ* rawDataFC.tgt$UPB * 1/12 * (rawDataFC.tgt$beginCoupon - 0.25 )/100
rawDataREO.tgt$estimateInterest <- rawDataREO.tgt$timeDQ* rawDataREO.tgt$UPB * 1/12 * (rawDataREO.tgt$beginCoupon - 0.25 )/100

## Calculate MI recoveries
MIHaircut <- 0.8
rawDataFC.tgt$estimateMIRecoveries <- rawDataFC.tgt$miLevel / 100 * (rawDataFC.tgt$UPB + rawDataFC.tgt$estimateInterest + rawDataFC.tgt$estimateExpenses) * MIHaircut
rawDataREO.tgt$estimateMIRecoveries <- rawDataREO.tgt$miLevel / 100 * (rawDataREO.tgt$UPB + rawDataREO.tgt$estimateInterest + rawDataREO.tgt$estimateExpenses) * MIHaircut

## Calculate MI recoveries
NonMIRatio <- 0.75
rawDataFC.tgt$estimateNonMIRecoveries <- rawDataFC.tgt$estimateMIRecoveries * NonMIRatio
rawDataREO.tgt$estimateNonMIRecoveries <- rawDataREO.tgt$estimateMIRecoveries * NonMIRatio
# 
# ## Calculate Total Loss
# rawDataFC.tgt$estimateTotalLoss <- rawDataFC.tgt$estimateBassLoss + rawDataFC.tgt$estimateInterest - rawDataFC.tgt$estimateExpenses - rawDataFC.tgt$estimateMIRecoveries
# rawDataREO.tgt$estimateTotalLoss <- rawDataREO.tgt$estimateBassLoss + rawDataREO.tgt$estimateInterest - rawDataREO.tgt$estimateExpenses - rawDataREO.tgt$estimateMIRecoveries
# 
# # ## change neegative number into 0
# # rawDataFC.tgt$estimateTotalLoss[rawDataFC.tgt$estimateTotalLoss < 0] <- 0
# # rawDataREO.tgt$estimateTotalLoss[rawDataREO.tgt$estimateTotalLoss < 0] <- 0
# 
# ## Calculate Total Severity
# rawDataFC.tgt$estimateTotalSeverity <- rawDataFC.tgt$estimateTotalLoss / rawDataFC.tgt$UPB
# rawDataREO.tgt$estimateTotalSeverity <- rawDataREO.tgt$estimateTotalLoss / rawDataREO.tgt$UPB

## Calculate Total Loss (Base + Expenses + Interest)
rawDataFC.tgt$estimateTotalLossBEI <- rawDataFC.tgt$estimateBassLoss + rawDataFC.tgt$estimateExpenses + rawDataFC.tgt$estimateInterest
rawDataREO.tgt$estimateTotalLossBEI <- rawDataREO.tgt$estimateBassLoss + rawDataREO.tgt$estimateExpenses + rawDataREO.tgt$estimateInterest

## Calculate Total Loss (Base + Expenses + Interest - MIRecoveries)
rawDataFC.tgt$estimateTotalLossBEIM <- rawDataFC.tgt$estimateBassLoss + rawDataFC.tgt$estimateExpenses + rawDataFC.tgt$estimateInterest - rawDataFC.tgt$estimateMIRecoveries
rawDataREO.tgt$estimateTotalLossBEIM <- rawDataREO.tgt$estimateBassLoss + rawDataREO.tgt$estimateExpenses + rawDataREO.tgt$estimateInterest - rawDataREO.tgt$estimateMIRecoveries

## Calculate Total Loss (Base + Expenses + Interest - MIRecoveries - nonMIRecoveries)
rawDataFC.tgt$estimateTotal <- rawDataFC.tgt$estimateBassLoss + rawDataFC.tgt$estimateExpenses + rawDataFC.tgt$estimateInterest - rawDataFC.tgt$estimateMIRecoveries - rawDataFC.tgt$estimateNonMIRecoveries
rawDataREO.tgt$estimateTotal <- rawDataREO.tgt$estimateBassLoss + rawDataREO.tgt$estimateExpenses + rawDataREO.tgt$estimateInterest - rawDataREO.tgt$estimateMIRecoveries - rawDataREO.tgt$estimateNonMIRecoveries



### Group by Month #####
#
resultFC <- GroupByMonth(rawDataFC.tgt)
resultREO <- GroupByMonth(rawDataREO.tgt)

combinedData <- rbind(rawDataFC.tgt, rawDataREO.tgt)

result <- GroupByMonth(combinedData)
resultFC <- GroupByMonth(rawDataFC.tgt)
resultREO <- GroupByMonth(rawDataREO.tgt)

write.csv(result, "data/result.csv", row.names = FALSE)
write.csv(resultFC, "data/result_FC.csv", row.names = FALSE)
write.csv(resultREO, "data/result_REO.csv", row.names = FALSE)



Base.rg <- glm(rawData.rg$DiscountPct~ rawData.rg$beginLoanAge + rawData.rg$JudicialFlag + rawData.rg$origbalance + rawData.rg$loanpurpose
               + rawData.rg$occupancyStatus + rawData.rg$propertyType + rawData.rg$timeDQ + rawData.rg$HPA2Yr)
# +rawrawData$zeroBalanceCode
print(summary(Base.rg))

## Projecting using refression result
estimateDiscountPct <- predict(Base.rg, type='response', newdata = rawData.tgt)
