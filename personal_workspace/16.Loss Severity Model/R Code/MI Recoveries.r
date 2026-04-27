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
rawData <- read.csv("data/temp.txt")


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
                        data$X.miRecoveries., data$estimateMIRecoveries,
                        data$X.nonMIRecoveries., data$estimateNonMIRecoveries,
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
  aggActuralMI <- lapply(sp,FUN=function(x) weighted.mean((x$data.X.miRecoveries./ x$data.X.UPB.), x$data.X.UPB.)) 
  aggEstimMI <- lapply(sp,FUN=function(x) weighted.mean((x$data.estimateMIRecoveries/ x$data.X.UPB.), x$data.X.UPB.)) 
  
  ## aggregate Total Loss BEIM
  aggActuralNonMI <- lapply(sp,FUN=function(x) weighted.mean((x$data.X.nonMIRecoveries./ x$data.X.UPB.), x$data.X.UPB.)) 
#   aggEstimNonMI <- lapply(sp,FUN=function(x) weighted.mean((x$data.estimateNonMIRecoveries./ x$data.X.UPB.), x$data.X.UPB.)) 
  
#   ## aggregate Total Loss BEIMN
#   aggActuralTotalLoss <- lapply(sp,FUN=function(x) weighted.mean((x$data.X.ActuralLoss./ x$data.X.UPB.), x$data.X.UPB.)) 
#   aggEstimTotalLoss <- lapply(sp,FUN=function(x) weighted.mean((x$data.estimateTotal/ x$data.X.UPB.), x$data.X.UPB.)) 
  
  #   ## aggregate Total Severity
  #   aggActuralTotalSeverity <- lapply(sp,FUN=function(x) weighted.mean(x$data.X.ActuralSeverity., x$data.X.UPB.)) 
  #   aggEstimTotalSeverity <- lapply(sp,FUN=function(x) weighted.mean(x$data.estimateTotalSeverity, x$data.X.UPB.)) 
  
  ### Construct return matix
  result<-cbind(
    #                 aggActuralBaseLoss, aggEstimBassLoss, 
    #                 aggActualExpenses,aggEstimExpenses,
    #                 aggEstimInterest, 
    #                 aggActualMIRecoveries, aggEstimMIRecoveries, 
    aggActuralMI, aggEstimMI,
    aggActuralNonMI
#     , aggEstimNonMI
    #                 aggActuralTotalSeverity, aggEstimTotalSeverity
  ) 
}




# rawData <- na.omit(rawData)



### Change columns to factor, prepared for regression
#
rawData$X.zeroBalanceCode. <- as.factor(rawData$X.zeroBalanceCode.) 
# rawData$X.year. <- as.factor(rawData$X.year.) 
# gc()   # Garbage Collection

### Subset data for FC and REO
#
rawDataFC <- subset(rawData,X.zeroBalanceCode.=='3')
rawDataREO <- subset(rawData,X.zeroBalanceCode.=='9')



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

## Calculate non-MI recoveries
NonMIRatio <- 0.75
rawDataFC$estimateNonMIRecoveries <- rawDataFC$estimateMIRecoveries * NonMIRatio
rawDataREO$estimateNonMIRecoveries <- rawDataREO$estimateMIRecoveries * NonMIRatio



### Group by Month #####
#
resultFC <- GroupByMonth(rawDataFC)
resultREO <- GroupByMonth(rawDataREO)

combinedData <- rbind(rawDataFC, rawDataREO)
result <- GroupByMonth(combinedData)

resultFC <- GroupByMonth(rawDataFC)
resultREO <- GroupByMonth(rawDataREO)

write.csv(result, "data/MIRecoveries.csv", row.names = FALSE)
write.csv(resultFC, "data/MIRecoveries_FC.csv", row.names = FALSE)
write.csv(resultREO, "data/MIRecoveries_REO.csv", row.names = FALSE)
