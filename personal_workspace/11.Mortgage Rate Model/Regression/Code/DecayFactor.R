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
rawData <- read.csv("InputData/CurrentCouponAndMortgageRate.csv")
rawData$asOfDate <- as.Date(rawData$asOfDate,format = "%m/%d/%Y")

#mortgage rate model
num_of_data <- nrow(rawData)
ModelMortgageRate <- 0.85
error_accumulate <- 0
error_i <- 0
i1 <- numeric(0)

MortgageRateFunc <- function(alpha, beta){
  for (i1 in 1:num_of_data){
    mortgage_rate1 <- rawData$ModelCoupon[num_of_data - i1] + alpha^i1 * (rawData$RealCoupon[num_of_data] - rawData$ModelCoupon[num_of_data])
    mortgage_rate <- mortgage_rate1 + beta^i1 * (rawData$RealMortgageRate[num_of_data] - ModelMortgageRate)
    error_i <- abs(mortgage_rate - rawData$RealMortgageRate[num_of_data - i1])
    error_accumulate <- error_accumulate + error_i
  }
  error_accumulate
}

MortgageRateFunc1 <- function(RealCoupon, ModelCoupon, RealMortgageRate, alpha, beta){

  mortgage_rate1 <- ModelCoupon[num_of_data] + alpha * (RealCoupon[num_of_data] - ModelCoupon[num_of_data])
  mortgage_rate <- mortgage_rate1 + beta^i1 * (RealMortgageRate[num_of_data] - ModelMortgageRate)
  error_i <- abs(mortgage_rate - RealMortgageRate[num_of_data - i1])
  error_accumulate + error_i

}

Pur.wt <- nls( ~ MortgageRateFunc1(RealCoupon, ModelCoupon, RealMortgageRate, alpha, beta), data = rawData,
               start = list(alpha = 0.95, beta = 0.95))
summary(Pur.wt)


min(rawData$asOfDate,na.rm=TRUE)






require(graphics)

DNase1 <- subset(DNase, Run == 1)

## weighted nonlinear regression
Treated <- Puromycin[Puromycin$state == "treated", ]
weighted.MM <- function(resp, conc, Vm, K)
{
  ## Purpose: exactly as white book p. 451 -- RHS for nls()
  ##  Weighted version of Michaelis-Menten model
  ## ----------------------------------------------------------
  ## Arguments: 'y', 'x' and the two parameters (see book)
  ## ----------------------------------------------------------
  ## Author: Martin Maechler, Date: 23 Mar 2001
  
  pred <- (Vm * conc)/(K + conc)
  (resp - pred) / sqrt(pred)
}

Pur.wt <- nls( ~ weighted.MM(rate, conc, Vm, K), data = Treated,
               start = list(Vm = 200, K = 0.1))
summary(Pur.wt)