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

rawData <- read.csv("data/temp.txt")
# rawData <- na.omit(rawData)


#rawData[1,]


### Change columns to factor, prepared for regression
#
rawData$X.zeroBalanceCode. <- as.factor(rawData$X.zeroBalanceCode.) 
# rawData$X.year. <- as.factor(rawData$X.year.) 
# gc()   # Garbage Collection


### Fitting Generalized Linear Models  
#
# Expenses.rg <- glm(rawData$X.expenses.~rawData$X.JudicialFlag.+rawData$X.origbalance.+rawData$X.loanpurpose.
#                   +rawData$X.occupancyStatus.+rawData$X.propertyType.+rawData$X.timeDQ.+rawData$X.HPA.+rawData$X.zeroBalanceCode.)
Expenses.rg <- glm(rawData$X.expenses.~rawData$X.JudicialFlag.+rawData$X.timeDQ.+rawData$X.HPA.+rawData$X.currentValue.)
# Expenses.rg <- glm(rawData$X.expenses.~rawData$X.JudicialFlag.+rawData$X.loanpurpose.
#                   +rawData$X.occupancyStatus.+rawData$X.propertyType.+rawData$X.timeDQ.+rawData$X.HPA.+rawData$X.zeroBalanceCode.+rawData$X.currentValue.)
# 
summary(Expenses.rg)

### Projecting using refression result
#
rawData$estimateExpenses <- predict(Expenses.rg, type='response', newdata=rawData)

# plotData <- data.frame(rawData$X.DiscountPct.,estimateDiscountPct)
# plot(plotData)





### Expense Group by Month
#
Output1 <- data.frame(rawData$X.lossDate.,rawData$X.expenses., rawData$estimateExpenses, rawData$X.UPB.)
Output <- na.omit(Output1)
  
sp <- split(Output,Output[,c("rawData.X.lossDate.")],drop=TRUE) 
aggActualExpenses <- lapply(sp,FUN=function(x) mean(-x$rawData.X.expenses.)) 
aggEstimExpenses <- lapply(sp,FUN=function(x) mean(-x$rawData.estimateExpenses)) 

aggEstimExpenses <- lapply(sp,FUN=function(x) weighted.mean(-x$rawData.estimateExpenses, x$rawData.X.UPB.)) 

result<-cbind(aggActualExpenses,aggEstimExpenses)
write.csv(result, "data/Expenses.csv", row.names = FALSE)






### Estimate Difference
# EstimateDiff <- EstimateLoss1 - ActuralLoss1
# hist(EstimateDiff)

EstimateDiff <- estimateDiscountPct - rawData$X.DiscountPct.
mean(EstimateDiff)
sd(EstimateDiff)
hist(EstimateDiff)

plot(EstimateDiff,type = "p")


class(rawData$X.year.)
# heatmap(EstimateDiff, Rowv=NA, Colv=NA, col=cm.colors(256), revC=FALSE, scale='column')





x<-data.frame(matrix(1:30,nrow=5,byrow=T))
rownames(x)=c("one","two","three","four","five")
colnames(x)=c("a","b","c","d","e","f")
x
new<-subset(x,a>=14,select=a:f)
new                            ## ???a???f?????????a>14?????????
