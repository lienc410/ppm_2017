# clear all the data in workspace
rm(list = ls())


# set up your working directory here
setwd("C:/Rwd/MortgageRateModel/Regression/")

includeFunc <- function(name) {
  fileName = paste(getwd(),"/",name,sep="");
  
  if(file.exists(fileName)) {
    source(fileName);
  } else {
    cat("can not find ", fileName, "\n");
  }
}

#  RdTurnDB()
rawData <- read.csv("InputData/SwapRateInput06to15.csv")



#Exam the variables
xy.lm <- lm(rawData$Coupon ~ rawData$X10yrSwap)
plot(rawData$X10yrSwap,rawData$Coupon)
abline(xy.lm, col = 'red', lwd=2)

xy.lm <- lm(rawData$Coupon ~ rawData$X2yrSwap)
plot(rawData$X2yrSwap,rawData$Coupon)
abline(xy.lm, col = 'red', lwd=2)

#log transferm
X2yrSwap <- log(rawData$X2yrSwap)
xy.lm <- lm(rawData$Coupon ~ X2yrSwap)
plot(X2yrSwap,rawData$Coupon)
abline(xy.lm, col = 'red', lwd=2)

xy.lm <- lm(rawData$Coupon ~ rawData$X3y7y_ATM)
plot(rawData$X3y7y_ATM,rawData$Coupon)
abline(xy.lm, col = 'red', lwd=2)

rawData$X2yrSwap <- X2yrSwap
pairs(rawData[2:5])

#regression, exam the result
xy.lm <- lm(rawData$Coupon ~ rawData$X10yrSwap + rawData$X2yrSwap + rawData$X3y7y_ATM)
xy.lm$coefficients

summary(xy.lm)

#plot the linear regression quality
plot(xy.lm,which=1:4)
plot(xy.lm)

#calculate model current coupon rate
model_current_coupon_rate <- numeric(0)
model_current_coupon_rate <- xy.lm$coefficients[1] + xy.lm$coefficients[2]*rawData$X10yrSwap + xy.lm$coefficients[3]*rawData$X2yrSwap + xy.lm$coefficients[4]*rawData$X3y7y_ATM

#output current coupon regression result 
output_data <- numeric(0)
output_data <- data.frame(rawData$asOfDate, rawData$Coupon, model_current_coupon_rate)
names(output_data)[1] <- "asOfDate"
names(output_data)[2] <- "RealCoupon"
names(output_data)[3] <- "ModelCoupon"
output_data$PercentError <- abs((output_data$ModelCoupon - output_data$RealCoupon)/output_data$RealCoupon)

write.csv(output_data, "OutputData/modelCurrentCoupon0615.csv", row.names = FALSE)

mean(output_data$PercentError)


