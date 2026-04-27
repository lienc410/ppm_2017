
rawDataFC <- subset(model.environment$ll.data, beginStatus != 'REO')
rawDataREO <- subset(model.environment$ll.data, beginStatus == 'REO')

### Assign regression result from Accordion
# base loss - haircut factor
FCBase.rg <- model.environment$measure.regression[['BaseHaircutFC']]
REOBase.rg <- model.environment$measure.regression[['BaseHaircutREO']]

# expenses
FCExpenses.rg <- model.environment$measure.regression[['ExpensesFC']]
REOExpenses.rg <- model.environment$measure.regression[['ExpensesREO']]
# +rawData$X.zeroBalanceCode.
# print(summary(Base.rg))

## Projecting using regression result
FCestimateDiscountPct <- predict(FCBase.rg, type='response', newdata = rawDataFC)
REOestimateDiscountPct <- predict(REOBase.rg, type='response', newdata = rawDataREO)

    # summary(FCEstimateBaseLoss)
    rawDataFC$EstimateBaseLoss <- rawDataFC$beginBalance - ((rawDataFC$origValue * rawDataFC$HPA) * FCestimateDiscountPct / 100)
    rawDataREO$EstimateBaseLoss <- rawDataREO$beginBalance - ((rawDataREO$origValue * rawDataREO$HPA) * REOestimateDiscountPct / 100)

rawDataFC$estimateExpenses <- predict(FCExpenses.rg, type='response', newdata=rawDataFC)
rawDataREO$estimateExpenses <- predict(REOExpenses.rg, type='response', newdata=rawDataREO)

## Calculate Accrued Interest
rawDataFC$estimateInterest <- rawDataFC$monthsAccrued * rawDataFC$beginBalance * 1/12 * (rawDataFC$beginCoupon - 0.25 )/100
rawDataREO$estimateInterest <- rawDataREO$monthsAccrued * rawDataREO$beginBalance * 1/12 * (rawDataREO$beginCoupon - 0.25 )/100

## Calculate MI recoveries
MIHaircut <- 0.8
rawDataFC$estimateMIRecoveries <- rawDataFC$miLevel / 100 * (rawDataFC$beginBalance + rawDataFC$estimateInterest + rawDataFC$estimateExpenses) * MIHaircut
rawDataREO$estimateMIRecoveries <- rawDataREO$miLevel / 100 * (rawDataREO$beginBalance + rawDataREO$estimateInterest + rawDataREO$estimateExpenses) * MIHaircut

## Calculate MI recoveries
NonMIRatio <- 0.8
rawDataFC$estimateNonMIRecoveries <- rawDataFC$estimateMIRecoveries * NonMIRatio
rawDataREO$estimateNonMIRecoveries <- rawDataREO$estimateMIRecoveries * NonMIRatio

# ## Calculate Total Loss (Base + Expenses + Interest)
# rawDataFC$estimateTotalLossBEI <- rawDataFC$estimateBassLoss + rawDataFC$estimateExpenses + rawDataFC$estimateInterest
# rawDataREO$estimateTotalLossBEI <- rawDataREO$estimateBassLoss + rawDataREO$estimateExpenses + rawDataREO$estimateInterest
# 
# ## Calculate Total Loss (Base + Expenses + Interest - MIRecoveries)
# rawDataFC$estimateTotalLossBEIM <- rawDataFC$estimateBassLoss - rawDataFC$estimateExpenses + rawDataFC$estimateInterest - rawDataFC$estimateMIRecoveries
# rawDataREO$estimateTotalLossBEIM <- rawDataREO$estimateBassLoss - rawDataREO$estimateExpenses + rawDataREO$estimateInterest - rawDataREO$estimateMIRecoveries
# 
# ## Calculate Total Loss (Base + Expenses + Interest - MIRecoveries - nonMIRecoveries)
# rawDataFC$estimateTotal <- rawDataFC$estimateBassLoss - rawDataFC$estimateExpenses + rawDataFC$estimateInterest - rawDataFC$estimateMIRecoveries - rawDataFC$estimateNonMIRecoveries
# rawDataREO$estimateTotal <- rawDataREO$estimateBassLoss - rawDataREO$estimateExpenses + rawDataREO$estimateInterest - rawDataREO$estimateMIRecoveries - rawDataREO$estimateNonMIRecoveries




### Expense Group by Month
#
GroupByMonth <- function(data) {

    data$ActuralBaseLoss <- data$beginBalance - data$netSaleProceeds
    Output1 <- data.frame(data$beginDate,
                          data$expenses, data$estimateExpenses, 
                          data$ActuralBaseLoss, data$EstimateBaseLoss, 
                                                data$estimateInterest, 
                          data$miRecoveries, data$estimateMIRecoveries,
#                         data$X.ActuralLossBEI., data$estimateTotalLossBEI,
#                         data$X.ActuralLossBEIM., data$estimateTotalLossBEIM,
#                         data$X.ActuralLoss., data$estimateTotal,
#                         data$X.ActuralSeverity., data$estimateTotalSeverity,
                          data$beginBalance
    )
     Output <- na.omit(Output1)
    
    ## split data by loss date
    sp <- split(Output,Output[,c("data.beginDate")],drop=TRUE) 
    ## aggregate Bass Loss by month
    aggActuralBaseLoss <- lapply(sp,FUN=function(x) weighted.mean((x$data.ActuralBaseLoss / x$data.beginBalance), x$data.beginBalance)) 
    aggEstimBassLoss <- lapply(sp,FUN=function(x) weighted.mean((x$data.EstimateBaseLoss / x$data.beginBalance), x$data.beginBalance)) 
      
    ## aggregate Expenses by month
    aggActualExpenses <- lapply(sp,FUN=function(x) weighted.mean((x$data.expenses / x$data.beginBalance), x$data.beginBalance)) 
    aggEstimExpenses <- lapply(sp,FUN=function(x) weighted.mean((x$data.estimateExpenses / x$data.beginBalance), x$data.beginBalance)) 
    
    ## aggregate Interest by month
    aggEstimInterest <- lapply(sp,FUN=function(x) weighted.mean((x$data.estimateInterest / x$data.beginBalance), x$data.beginBalance)) 
    
    ## aggregate MI by month
    aggActualMIRecoveries <- lapply(sp,FUN=function(x) weighted.mean((x$data.miRecoveries / x$data.beginBalance), x$data.beginBalance)) 
    aggEstimMIRecoveries <- lapply(sp,FUN=function(x) weighted.mean((x$data.estimateMIRecoveries / x$data.beginBalance), x$data.beginBalance)) 

    ### Construct return matix
    result<-cbind(
                         aggActuralBaseLoss, aggEstimBassLoss, 
                         aggActualExpenses,aggEstimExpenses,
                         aggEstimInterest, 
                         aggActualMIRecoveries, aggEstimMIRecoveries 
        #         aggActuralTotalLossBEI, aggEstimTotalLossBEI,
        #         aggActuralTotalLossBEIM, aggEstimTotalLossBEIM,
        #         aggActuralTotalLoss, aggEstimTotalLoss
        #                 aggActuralTotalSeverity, aggEstimTotalSeverity
    ) 
}


### Group by Month #####
#
resultFC <- GroupByMonth(rawDataFC)
resultREO <- GroupByMonth(rawDataREO)


combinedData <- rbind(rawDataFC, rawDataREO)
result <- GroupByMonth(combinedData)


write.csv(result, "data/result.csv", row.names = FALSE)
write.csv(resultFC, "data/result_FC.csv", row.names = FALSE)
write.csv(resultREO, "data/result_REO.csv", row.names = FALSE)