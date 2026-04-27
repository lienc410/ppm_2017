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
rawData$X.zeroBalanceCode. <- as.factor(rawData$X.zeroBalanceCode.) 
# rawData$X.year. <- as.factor(rawData$X.year.) 
# gc()   # Garbage Collection


## Fitting Generalized Linear Models  
# xy.rg <- glm(rawData$X.DiscountPct.~rawData$X.beginLoanAge.+rawData$X.JudicialFlag.+rawData$X.origbalance.+rawData$X.loanpurpose.+rawData$X.occupancyStatus.+rawData$X.propertyType.+rawData$X.timeDQ.+rawData$X.HPA.)
xy.rg <- glm(rawData$X.DiscountPct.~rawData$X.beginLoanAge.+rawData$X.JudicialFlag.+rawData$X.origbalance.+rawData$X.loanpurpose.
             +rawData$X.occupancyStatus.+rawData$X.propertyType.+rawData$X.timeDQ.+rawData$X.HPA.)
# +rawData$X.zeroBalanceCode.
summary(xy.rg)

## Projecting using refression result
rawData$estimateDiscountPct <- predict(xy.rg,type='response',newdata=rawData)

# plotData <- data.frame(rawData$X.DiscountPct.,estimateDiscountPct)
# plot(plotData)


### Discount Pct Group by month

# Output1 <- data.frame(rawData$X.lossDate.,rawData$X.DiscountPct., rawData$estimateDiscountPct)
# Output <- na.omit(Output1)
#   
# sp <- split(Output,Output[,c("rawData.X.lossDate.")],drop=TRUE) 
# aggActualDiscountPct <- lapply(sp,FUN=function(x) mean(x$rawData.X.DiscountPct)) 
# aggEstimDiscountPct <- lapply(sp,FUN=function(x) mean(x$rawData.estimateDiscountPct)) 
#   
# result<-cbind(aggActualDiscountPct,aggEstimDiscountPct)
# write.csv(result, "data/DiscountPct.csv", row.names = FALSE)






### calculate base loss
ActuralLoss <- rawData$X.UPB. - rawData$X.netSaleProceeds.
EstimateLoss <- rawData$X.UPB. - (rawData$X.currentValue.*rawData$estimateDiscountPct/100)


ActuralLoss1 <- na.omit(ActuralLoss)
EstimateLoss1 <- na.omit(EstimateLoss)



### Base Loss Group by Month
Output1 <- data.frame(rawData$X.lossDate.,ActuralLoss, EstimateLoss)
Output <- na.omit(Output1)

sp <- split(Output,Output[,c("rawData.X.lossDate.")], drop=TRUE) 
aggActual <- lapply(sp, FUN=function(x) mean(x$ActuralLoss)) 
aggEstim <- lapply(sp, FUN=function(x) mean(x$EstimateLoss)) 

result<-cbind(aggActual,aggEstim)
write.csv(result, "data/BaseLoss.csv", row.names = FALSE)






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