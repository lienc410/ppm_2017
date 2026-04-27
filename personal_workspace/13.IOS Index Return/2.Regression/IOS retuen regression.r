# clear all the data in workspace
rm(list = ls())


# set up your working directory here
setwd("C:/Lien Workspace/13.IOS Index Return/2.Regression/")

includeFunc <- function(name) {
  fileName = paste(getwd(),"/",name,sep="");
  
  if(file.exists(fileName)) {
    source(fileName);
  } else {
    cat("can not find ", fileName, "\n");
  }
}

rawData <- read.csv("IOS Return Input Data 2m lag.csv")

# #Exam the variables
# xy.lm <- lm(rawData$MonthlyReturn ~ rawData$Px.Coupon)
# plot(rawData$Px.Coupon,rawData$MonthlyReturn)
# abline(xy.lm, col = 'red', lwd=2)
# 
# xy.lm <- lm(rawData$MonthlyReturn ~ rawData$Carry)
# plot(rawData$Carry,rawData$MonthlyReturn)
# abline(xy.lm, col = 'red', lwd=2)
# 
# xy.lm <- lm(rawData$MonthlyReturn ~ rawData$RealizedVol)
# plot(rawData$RealizedVol,rawData$MonthlyReturn)
# abline(xy.lm, col = 'red', lwd=2)
# 
# xy.lm <- lm(rawData$MonthlyReturn ~ rawData$PrepaymentRisk)
# plot(rawData$PrepaymentRisk,rawData$MonthlyReturn)
# abline(xy.lm, col = 'red', lwd=2)
# 
# xy.lm <- lm(rawData$MonthlyReturn ~ rawData$YieldCurve)
# plot(rawData$YieldCurve,rawData$MonthlyReturn)
# abline(xy.lm, col = 'red', lwd=2)
# 
# #exam correlations for each pair
# pairs(rawData[c("MonthlyReturn", "Px.Coupon","Carry","RealizedVol","PrepaymentRisk","YieldCurve")])


#regression, exam the result
xy.lm <- lm(rawData$MonthlyReturn ~ rawData$Px.Coupon + rawData$Carry + rawData$PrepaymentRisk + rawData$RealizedVol  + rawData$YieldCurve)

xy.lm$coefficients
summary(xy.lm)

# #plot the linear regression quality
# plot(xy.lm,which=1:4)
# plot(xy.lm)

#calculate model current coupon rate
model_return <- numeric(0)
model_return <- xy.lm$coefficients[1] + xy.lm$coefficients[2]*rawData$Px.Coupon + xy.lm$coefficients[3]*rawData$Carry + xy.lm$coefficients[4]*rawData$PrepaymentRisk +  xy.lm$coefficients[5]*rawData$RealizedVol + xy.lm$coefficients[6]*rawData$YieldCurve

#Calculate Z-Score
#Geometric Average on monthly return, need to + 100% to provide all positive number
geo_avg_monthly_return <- exp(mean(log(rawData$MonthlyReturn + 10000))) - 10000
#Standard Deviation
std_monthly_return <- sd(rawData$MonthlyReturn)
geo_avg_monthly_return / std_monthly_return
#z-score
zscore <- (model_return - geo_avg_monthly_return)/std_monthly_return


#Optimazation
SharpeRatio <- function(par){
  a <- par[1]
  b <- par[2]
  
  k <- a + b*zscore
  return_after_k <- k * rawData$MonthlyReturn
  
  geo_avg <- exp(mean(log(return_after_k + 10000))) - 10000
  sigma <- sd(return_after_k)
  
  #sum(return_after_k)
  -geo_avg / sigma
}

opt <- optim(c(1,1), SharpeRatio)
opt

k <- opt$par[1] + opt$par[2]*zscore
return_after_k <- k * rawData$MonthlyReturn



#output current coupon regression result 
output_data <- numeric(0)
output_data <- data.frame(rawData$Date, rawData$MonthlyReturn, model_return, zscore, k, return_after_k)
names(output_data)[1] <- "Date"
names(output_data)[2] <- "MonthlyReturn"
names(output_data)[3] <- "ModelReturn"
names(output_data)[4] <- "zscore"
names(output_data)[5] <- "k"
names(output_data)[6] <- "OptReturn"

#output_data$PercentError <- abs((output_data$ModelReturn - output_data$MonthlyReturn)/output_data$MonthlyReturn)

plot(zscore,k)
write.csv(output_data, "OutputData/modelouput.csv", row.names = FALSE)

mean(output_data$PercentError)


