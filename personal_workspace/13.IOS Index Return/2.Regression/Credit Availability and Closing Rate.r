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

rawData <- read.csv("CreditAvailabilityRegression1.csv")



#regression, exam the result
xy.lm <- lm(rawData$AllLoan ~ rawData$UniverseSeries)

xy.lm$coefficients
summary(xy.lm)

