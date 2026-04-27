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


ExpensesRegression <- function(data) {
  ### Fitting Generalized Linear Models  
  #   JudicialFlag: vary from states; timeDQ: time in delinquency;  AvgNSAIndex: 2 year moving average of USA level HPI
#    Expenses.rg <- glm(data$X.expenses. ~ data$X.JudicialFlag. + data$X.timeDQ. + data$X.AvgNSAIndex. + data$X.UPB.)
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
  Output1 <- data.frame(data$X.lossDate.,data$X.expenses., data$estimateExpenses)
  Output <- na.omit(Output1)
  
  sp <- split(Output,Output[,c("data.X.lossDate.")],drop=TRUE) 
  aggActualExpenses <- lapply(sp,FUN=function(x) mean(-x$data.X.expenses.)) 
  aggEstimExpenses <- lapply(sp,FUN=function(x) mean(-x$data.estimateExpenses)) 
  
  result<-cbind(aggActualExpenses,aggEstimExpenses)

  
}



rawData <- read.csv("data/temp.txt")
rawData$X.expenses. <- rawData$X.expenses. + rawData$X.nonMIRecoveries.
# rawData <- na.omit(rawData)


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

### Fitting Generalized Linear Models  
#

rawDataFC$estimateExpenses <- ExpensesRegression(rawDataFC)
rawDataREO$estimateExpenses <- ExpensesRegression(rawDataREO)

### Expense Group by Month
#
resultFC <- GroupByMonth(rawDataFC)
resultREO <- GroupByMonth(rawDataREO)

combinedData <- rbind(rawDataFC, rawDataREO)
result <- GroupByMonth(combinedData)



write.csv(result, "data/Expenses.csv", row.names = FALSE)




plot(rawData$X.ActuralLoss.)
plot(rawData$X.JudicialFlag., rawData$X.timeDQ.)
plot(rawData$X.JudicialFlag., rawData$X.state.)
