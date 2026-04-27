
require(data.table) # data.frame extension package
require(DMwR)
require(jsonlite) # json utility
source("batonutil/R/spline_utilities.R")


cltv.knots <- read.csv("C:/Lien Workspace/01.Work Progress Documents/Refi_Eligibile_Projection/CLTV_Knots.csv")
raw.data <- data.frame(read.csv("C:/PIV/PIV-it-dev/trunk/Research/AgencyPrepayment/Baton/data/tracking/FHL_All_200302_201702_TRACK_Coho_SpecPool.csv"), stringsAsFactors = FALSE)
data <- raw.data[,c("factorDate", "poolListName", "cltv", "refi_elig_pct", "wala")]
head(data)

# initial cltv / refi_elig_pct for time 0
data$cltv.0 <- 0
data$refi_elig_pct.0 <- 0
data$wala.0 <- 0

# find cltv / RE at time 0 
poolListName_unique <- unique(data$poolListName)
for(i in 1:length(poolListName_unique)){
  data.one.set <- data[data[,"poolListName"] == poolListName_unique[i], ]
  data.one.set.initial <- data.one.set[data.one.set[,"factorDate"] == min(data.one.set$factorDate), ]
  
  data[data[,"poolListName"] == poolListName_unique[i], ]$cltv.0 <- data.one.set.initial$cltv
  data[data[,"poolListName"] == poolListName_unique[i], ]$refi_elig_pct.0 <- data.one.set.initial$refi_elig_pct
  data[data[,"poolListName"] == poolListName_unique[i], ]$wala.0 <- data.one.set.initial$wala
  
  if(i == 1) data.initial <- data.one.set.initial
  else data.initial <- rbind(data.initial, data.one.set.initial)
}

# New Algorithm
data$RE_0_est <- SplineFunc(cltv.knots$Knots, cltv.knots$KnotValues, data$cltv.0)
data$diff_cltv <- data$cltv - data$cltv.0
data$RE_i_est <- SplineFunc(cltv.knots$Knots, cltv.knots$KnotValues, data$cltv.0 + data$diff_cltv)
data$diff_RE_est = data$RE_i_est - data$RE_0_est
data$RE_new <- pmax(pmin(data$refi_elig_pct.0 + data$diff_RE_est, 100.0), 0.0)

# Wala Decay
data$diff_wala <- data$wala - data$wala.0

# linear decay
# DecayFunc <- function(current, start.point, end.point, start.value, end.value){
#   decayFactor <- ifelse(current < start.point, start.value, ifelse(current > end.point, end.value, start.value - (start.value - end.value)/(end.point - start.point)*(current-1))) 
# }
# data$decay.factor <- DecayFunc(current = data$diff_wala, start.point = 1, end.point = 2*12, start.value = 1, end.value = 0)

# exponential decay a^i 0<a<1
DecayFunc <- function(a){
  data$RE_new_decay <- (data$refi_elig_pct.0 - data$RE_0_est) * a ^ data$diff_wala + data$RE_i_est
  regr.eval(data$refi_elig_pct,data$RE_new_decay,stats=c('rmse'))
}

a.optim <- optimize(DecayFunc, lower = 0.0, upper = 1.0)

data$decay.factor <- a.optim$minimum
data$RE_new_decay <- (data$refi_elig_pct.0 - data$RE_0_est) * data$decay.factor ^ data$diff_wala + data$RE_i_est

# Old Algorithm
# refi_elig_percent_i = max(min((100.0 - refi_elig_percent_i) * -10.0 * cltv_pct_delta + refi_elig_percent_i, 100.0), 0.0);
#   cltv_pct_delta = (cltv_i - cltv_prev) / cltv_prev;
data$cltv_pct_delta <- (data$cltv - data$cltv.0) / data$cltv.0
data$RE_old <- pmax(pmin((100 - data$refi_elig_pct) * -10.0 * data$cltv_pct_delta + data$refi_elig_pct, 100.0), 0.0)


result <- data[, c("factorDate", "poolListName", "cltv", "refi_elig_pct", "RE_new", "RE_old", "RE_new_decay")]
write.csv(result, file=paste("./output/Refi_Eligibile_Projection_withoutHARP_Decay.csv"))

regr.eval(result$refi_elig_pct,result$RE_new,stats=c('rmse'))
regr.eval(result$refi_elig_pct,result$RE_old,stats=c('rmse'))
regr.eval(result$refi_elig_pct,result$RE_new_decay,stats=c('rmse'))


f <- function (x, a) (x - a)^2
xmin <- optimize(f, c(0, 1), tol = 0.0001, a = 1/3)
xmin

data[data[,"poolListName"] == "FHL30.300.12(U6)", ]

# create JSON file
refi.eligibility.knots <- list("cltv"=data.frame(Knots=cltv.knots$Knots, KnotValues=cltv.knots$KnotValues))

# Write JSON
refi.eligibility.json <- toJSON(refi.eligibility.knots, digits=10, pretty=TRUE)
write(refi.eligibility.json, file=paste("./JSON/conventional/dev/refi_eligibility_projection.json", sep=""))



1 - 2*-10