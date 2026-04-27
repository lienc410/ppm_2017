# clear all the data in workspace
rm(list = ls())


# set up your working directory here
setwd("C:/PIVUni/")

oerData <- read.csv("oer.csv")
cpiData <- read.csv("cpi.csv")

oer <- numeric(0)
cpi <- numeric(0)
cpiDiffShift <- numeric(0)
cpiRatio<- numeric(0)

for(i in 1:29){
	for(j in 1:12){
		oer[(i-1)*12 + j] <- oerData[i,j+1]
		cpi[(i-1)*12 + j] <- cpiData[i,j+1]
	}

}

cpiDiff <- diff(cpi)

for(i in 1:length(cpiDiff)){
	cpiDiffShift[1] <- 1
	cpiRatio[1] <- 1

	cpiDiffShift[1+i] <- cpiDiff[i]/cpi[i]*100
	cpiRatio[1+i] <- cpi[i+1] / cpi[i]
}

cor(oer,cpiDiffShift)
cor(oer,cpiRatio)

plot(oer,type='l')
twoord.plot(1:length(cpiDiffShift),oer,1:length(cpiDiffShift),cpiDiffShift, type = 'l')

write.csv(oer, "oerT.csv", row.names = FALSE)
write.csv(cpi, "cpiT.csv", row.names = FALSE)