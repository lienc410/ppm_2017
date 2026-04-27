
# Base.rg <- glm(data$X.DiscountPct.~ data$X.beginLoanAge.+data$X.JudicialFlag.+data$X.origbalance.+data$X.loanpurpose.
#                +data$X.occupancyStatus.+data$X.propertyType.+data$X.timeDQ.+ data$X.HPA2Yr.)


rawData <- rawData.tgt

rawData$BaseSev <- (rawData$UPB - rawData$netSaleProceeds) / rawData$UPB

rawData1 <- na.omit(rawData)



for (i in 1:length(rawData1$BaseSev)){
  if(rawData1$BaseSev[i] < 0){
    rawData1$BaseSev[i] <- 0
  } else if(rawData1$BaseSev[i] > 1.5) {
    rawData1$BaseSev[i] <- 1.5
  }
}


summary(rawData1$origbalance)
hist(rawData1$BaseSev,breaks = 50)

plot(rawData1$beginLoanAge, rawData1$BaseSev)


boxplot(rawData1$X.beginLoanAge., rawData1$BaseSev)




# occupancyStatus <- tapply(rawData1$BaseSev,rawData1$X.occupancyStatus., mean)

LoanAge <- tapply(rawData1$BaseSev,rawData1$X.beginLoanAge., mean, simplify = FALSE)
ListName <- names(LoanAge)
LoanAge <- do.call(rbind, LoanAge)
LoanAge <- cbind(ListName, LoanAge)
write.csv(LoanAge, "data/TempResult.csv", row.names = FALSE)
plot(LoanAge)

# Judicial <- tapply(rawData1$BaseSev,rawData1$X.JudicialFlag., mean)
# write.csv(Judicial, "data/TempResult.csv", row.names = FALSE)
# barplot(Judicial)

# OrigBalance <- tapply(rawData1$X.DiscountPct,rawData1$X.origbalance., mean)
OrigBalance <- tapply(rawData1$BaseSev,rawData1$origbalance, mean, simplify = FALSE)
ListName <- names(OrigBalance)
OrigBalance <- do.call(rbind, OrigBalance)
OrigBalance <- cbind(ListName, OrigBalance)

write.csv(OrigBalance, "data/TempResult.csv", row.names = FALSE)
plot(OrigBalance)



# loanpurpose <- tapply(rawData1$BaseSev,rawData1$X.loanpurpose., mean)
# plot(loanpurpose)
# 
# occupancyStatus <- tapply(rawData1$BaseSev,rawData1$X.occupancyStatus., mean)
# plot(occupancyStatus)



# propertyType <- tapply(rawData1$BaseSev,rawData1$X.propertyType., mean)
# plot(propertyType)

# timeDQ <- tapply(rawData1$X.DiscountPct,rawData1$X.timeDQ., mean)
timeDQ <- tapply(rawData1$BaseSev,rawData1$X.timeDQ., mean, simplify = FALSE)
ListName <- names(timeDQ)
timeDQ <- do.call(rbind, timeDQ)
timeDQ <- cbind(ListName, timeDQ)
write.csv(timeDQ, "data/TempResult.csv", row.names = FALSE)
plot(timeDQ)



rawData1$hpaGroup <- (rawData1$HPA2Yr %/% 0.1 + 1) * 0.1
HPA2Yr <- tapply(rawData1$BaseSev,rawData1$hpaGroup, mean)

summary(rawData1$hpaGroup)


barplot(HPA2Yr)

#
# Expenses.rg <- glm(data$X.expenses. ~ data$X.JudicialFlag. + data$X.timeDQ. + data$X.UPB.)
#

rawData1$ExpesesSev <- (-rawData1$X.expenses.) / rawData1$X.UPB.

rawData1$upbGroup <- (rawData1$X.UPB. %/% 50000 + 1) * 50000
summary(rawData1$upbGroup)

for (i in 1:length(rawData1$ExpesesSev)){
  if(rawData1$ExpesesSev[i] < 0){
    rawData1$ExpesesSev[i] <- 0
  } else if(rawData1$ExpesesSev[i] > 1.5) {
    rawData1$ExpesesSev[i] <- 1.5
  }
}


timeDQ <- tapply(rawData1$ExpesesSev,rawData1$X.timeDQ., mean, simplify = FALSE)
ListName <- names(timeDQ)
timeDQ <- do.call(rbind, timeDQ)
timeDQ <- cbind(ListName, timeDQ)
write.csv(timeDQ, "data/TempResult.csv", row.names = FALSE)
plot(timeDQ)


Judicial <- tapply(rawData1$ExpesesSev,rawData1$X.JudicialFlag., mean)
write.csv(Judicial, "data/TempResult.csv", row.names = FALSE)
barplot(Judicial)



upb <- tapply(rawData1$ExpesesSev,rawData1$upbGroup, mean, simplify = FALSE)
ListName <- names(upb)
upb <- do.call(rbind, upb)
upb <- cbind(ListName, upb)
write.csv(upb, "data/TempResult.csv", row.names = FALSE)
plot(upb)


##############################################################


# Bse Severity group on HPI 2yr changes, while controling CLTV
# clear all the data in workspace

rawDataBsaeSev <- read.csv("data/tempBsaeSevWithCLTV90to100.txt")
rawDataBsaeSev <- na.omit(rawDataBsaeSev)


rawDataBsaeSev$hpaGroup <- (rawDataBsaeSev$HPA2Yr %/% 0.1 + 1) * 0.1
HPA2Yr <- tapply(rawDataBsaeSev$BaseSev,rawDataBsaeSev$hpaGroup, mean)

summary(rawDataBsaeSev$hpaGroup)


barplot(HPA2Yr)


