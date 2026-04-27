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
rawDataFHL <- read.csv("data/tempFHL.txt")
rawData <- read.csv("data/tempFNM.txt")

### Fitting Generalized Linear Models 
#
BaseLossRegression <- function(data) {
  
  # xy.rg <- glm(rawData$X.DiscountPct.~rawData$X.beginLoanAge.+rawData$X.JudicialFlag.+rawData$X.origbalance.+rawData$X.loanpurpose.+rawData$X.occupancyStatus.+rawData$X.propertyType.+rawData$X.timeDQ.+rawData$X.HPA.)
#   Base.rg <- glm(data$X.DiscountPct.~ data$X.beginLoanAge.+data$X.JudicialFlag.+data$X.origbalance.+data$X.loanpurpose.
#                +data$X.occupancyStatus.+data$X.propertyType.+data$X.timeDQ.+ data$X.HPA2Yr.)
  Base.rg <- glm(data$X.DiscountPct.~ data$X.beginLoanAge.+data$X.JudicialFlag.+data$X.origbalance.+data$X.loanpurpose.
                 +data$X.occupancyStatus.+data$X.propertyType.+data$X.timeDQ.+ data$X.HPA2Yr.)
  # +rawData$X.zeroBalanceCode.
  print(summary(Base.rg))
  
  ## Projecting using refression result
  estimateDiscountPct <- predict(Base.rg, type='response',newdata=data)
  
  ### calculate base loss
#   data$ActuralBaseLoss <- data$X.UPB. - data$X.netSaleProceeds.
  data$EstimateBaseLoss <- data$X.UPB. - (data$X.currentValue. * estimateDiscountPct / 100)
  
#   return(data)
}

### Fitting Generalized Linear Models 
#
ExpensesRegression <- function(data) {
 
  #   JudicialFlag: vary from states; timeDQ: time in delinquency;  AvgNSAIndex: 2 year moving average of USA level HPI
#   Expenses.rg <- glm(data$X.expenses. ~ data$X.JudicialFlag. + data$X.timeDQ. + data$X.NSAIndex. + data$X.UPB.)
  Expenses.rg <- glm(data$X.expenses. ~ data$X.JudicialFlag. + data$X.timeDQ. + data$X.UPB.)
  
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
#                         data$X.expenses., data$estimateExpenses, 
#                         data$ActuralBaseLoss, data$estimateBassLoss, 
#                                               data$estimateInterest, 
#                         data$X.miRecoveries., data$estimateMIRecoveries,
                        data$X.ActuralLossBEI., data$estimateTotalLossBEI,
                        data$X.ActuralLossBEIM., data$estimateTotalLossBEIM,
                        data$X.ActuralLoss., data$estimateTotal,
#                         data$X.ActuralSeverity., data$estimateTotalSeverity,
                        data$X.UPB.
                        )
  Output <- na.omit(Output1)
  
  ## split data by loss date
  sp <- split(Output,Output[,c("data.X.lossDate.")],drop=TRUE) 
#   ## aggregate Bass Loss by month
#   aggActuralBaseLoss <- lapply(sp,FUN=function(x) weighted.mean((x$data.ActuralBaseLoss / x$data.X.UPB.), x$data.X.UPB.)) 
#   aggEstimBassLoss <- lapply(sp,FUN=function(x) weighted.mean((x$data.estimateBassLoss / x$data.X.UPB.), x$data.X.UPB.)) 
#   
#   ## aggregate Expenses by month
#   aggActualExpenses <- lapply(sp,FUN=function(x) weighted.mean((-x$data.X.expenses. / x$data.X.UPB.), x$data.X.UPB.)) 
#   aggEstimExpenses <- lapply(sp,FUN=function(x) weighted.mean((-x$data.estimateExpenses / x$data.X.UPB.), x$data.X.UPB.)) 
  
  ## aggregate Total Loss BEI
  aggActuralTotalLossBEI <- lapply(sp,FUN=function(x) weighted.mean((x$data.X.ActuralLossBEI./ x$data.X.UPB.), x$data.X.UPB.)) 
  aggEstimTotalLossBEI <- lapply(sp,FUN=function(x) weighted.mean((x$data.estimateTotalLossBEI/ x$data.X.UPB.), x$data.X.UPB.)) 

  ## aggregate Total Loss BEIM
  aggActuralTotalLossBEIM <- lapply(sp,FUN=function(x) weighted.mean((x$data.X.ActuralLossBEIM./ x$data.X.UPB.), x$data.X.UPB.)) 
  aggEstimTotalLossBEIM <- lapply(sp,FUN=function(x) weighted.mean((x$data.estimateTotalLossBEIM/ x$data.X.UPB.), x$data.X.UPB.)) 

  ## aggregate Total Loss BEIMN
  aggActuralTotalLoss <- lapply(sp,FUN=function(x) weighted.mean((x$data.X.ActuralLoss./ x$data.X.UPB.), x$data.X.UPB.)) 
  aggEstimTotalLoss <- lapply(sp,FUN=function(x) weighted.mean((x$data.estimateTotal/ x$data.X.UPB.), x$data.X.UPB.)) 

#   ## aggregate Total Severity
#   aggActuralTotalSeverity <- lapply(sp,FUN=function(x) weighted.mean(x$data.X.ActuralSeverity., x$data.X.UPB.)) 
#   aggEstimTotalSeverity <- lapply(sp,FUN=function(x) weighted.mean(x$data.estimateTotalSeverity, x$data.X.UPB.)) 

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


# rawData$X.ActuralLossBEI.


### Change columns to factor, prepared for regression
#
rawData$X.zeroBalanceCode. <- as.factor(rawData$X.zeroBalanceCode.) 
# rawData$X.expenses. <- rawData$X.expenses. + rawData$X.nonMIRecoveries.
# rawData$X.year. <- as.factor(rawData$X.year.) 
# gc()   # Garbage Collection

### Subset data for FC and REO
#
# rawDataFC <- subset(rawData,X.zeroBalanceCode.=='3')
# rawDataREO <- subset(rawData,X.zeroBalanceCode.=='9')

rawDataFC <- subset(rawData, X.zeroBalanceCode.== 3)
rawDataREO <- subset(rawData, X.zeroBalanceCode.== 9)


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
rawDataFC$estimateInterest <- rawDataFC$X.timeDQ.* rawDataFC$X.UPB. * 1/12 * (rawDataFC$X.beginCoupon. - 0.25 )/100
rawDataREO$estimateInterest <- rawDataREO$X.timeDQ.* rawDataREO$X.UPB. * 1/12 * (rawDataREO$X.beginCoupon. - 0.25 )/100

## Calculate MI recoveries
MIHaircut <- 0.8
rawDataFC$estimateMIRecoveries <- rawDataFC$X.miLevel. / 100 * (rawDataFC$X.UPB. + rawDataFC$estimateInterest + rawDataFC$estimateExpenses) * MIHaircut
rawDataREO$estimateMIRecoveries <- rawDataREO$X.miLevel. / 100 * (rawDataREO$X.UPB. + rawDataREO$estimateInterest + rawDataREO$estimateExpenses) * MIHaircut

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
# rawDataFC$estimateTotalSeverity <- rawDataFC$estimateTotalLoss / rawDataFC$X.UPB.
# rawDataREO$estimateTotalSeverity <- rawDataREO$estimateTotalLoss / rawDataREO$X.UPB.

## Calculate Total Loss (Base + Expenses + Interest)
rawDataFC$estimateTotalLossBEI <- rawDataFC$estimateBassLoss - rawDataFC$estimateExpenses + rawDataFC$estimateInterest
rawDataREO$estimateTotalLossBEI <- rawDataREO$estimateBassLoss - rawDataREO$estimateExpenses + rawDataREO$estimateInterest

## Calculate Total Loss (Base + Expenses + Interest - MIRecoveries)
rawDataFC$estimateTotalLossBEIM <- rawDataFC$estimateBassLoss - rawDataFC$estimateExpenses + rawDataFC$estimateInterest - rawDataFC$estimateMIRecoveries
rawDataREO$estimateTotalLossBEIM <- rawDataREO$estimateBassLoss - rawDataREO$estimateExpenses + rawDataREO$estimateInterest - rawDataREO$estimateMIRecoveries

## Calculate Total Loss (Base + Expenses + Interest - MIRecoveries - nonMIRecoveries)
rawDataFC$estimateTotal <- rawDataFC$estimateBassLoss - rawDataFC$estimateExpenses + rawDataFC$estimateInterest - rawDataFC$estimateMIRecoveries - rawDataFC$estimateNonMIRecoveries
rawDataREO$estimateTotal <- rawDataREO$estimateBassLoss - rawDataREO$estimateExpenses + rawDataREO$estimateInterest - rawDataREO$estimateMIRecoveries - rawDataREO$estimateNonMIRecoveries



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




Base.rg <- glm(data$X.DiscountPct.~ data$X.beginLoanAge.+data$X.JudicialFlag.+data$X.origbalance.+data$X.loanpurpose.
               +data$X.occupancyStatus.+data$X.propertyType.+data$X.timeDQ.+ data$X.HPA2Yr.)
