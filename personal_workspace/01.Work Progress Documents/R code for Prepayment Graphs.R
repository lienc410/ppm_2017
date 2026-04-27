
rm(list = ls())
gc()

# Required Packages
require(ggplot2) # optional graph package
require(png) # optional graph package
require(leaps) # package for best subsets selection
require(jsonlite) # json utility
require(data.table) # data.frame extension package

# Include Functions
includeFunc <- function(name) {
  fileName = paste(getwd(),"/",name,sep="");
  
  if(file.exists(fileName)) {
    source(fileName);
  } else {
    cat("can not find ", fileName, "\n");
  }
}

includeFunc("spline_utilities.R")
includeFunc("curtailment_function.R")
includeFunc("default_function.R")
includeFunc("turnover_function.R")
includeFunc("refinance_function.R")



# Baton Model
BATON_MODEL <- "Baton_v2.00.json"



# Baton Model
baton.mdl <- fromJSON(paste("./regressions/", BATON_MODEL, sep=""))


# Conventional
curtailment.mdl <- baton.mdl$Conventional$CurtailmentModule
current.mdl <- baton.mdl$Conventional$DefaultModule.current
delinq.mdl <- baton.mdl$Conventional$DefaultModule.dq
turnover.mdl <- baton.mdl$Conventional$TurnoverModule
refinance.mdl <- baton.mdl$Conventional$RefinanceModule

#
# Prepayment Graphs: Request #1
#

# Lock-in Effect:
#   y-axis: Baseline Turnover * Lock-in Multiplier
# x-axis: Incentive (bps)

turnover.mdl$baselineConstant

lockIn.knots <- turnover.mdl$incentiveSpline$incentiveKnots
lockIn.optim <- turnover.mdl$incentiveSpline$incentiveKnotValues


possible.lockIn <- seq(-350, 0, 1)
lockIn.spline.mult <- SplineFunc(lockIn.knots, lockIn.optim, possible.lockIn)
plot(possible.lockIn, lockIn.spline.mult, type='l',main="Spline Multiplier: lockIn", xlab="lockIn", ylab="Multiplier")
points(lockIn.knots, lockIn.optim, pch = 8, col = 'blue')
cbind(possible.lockIn, lockIn.spline.mult)


# Seasoning Ramp:
#   y-axis: Baseline Turnover * Seasoning Ramp * HPA 2-year multiplier corresponding to 5%, 10%, and 15%
# (i.e., so 3 graphs corresponding to the different values of the HPA 2-year multiplier)
# x-axis: WALA (months)

hpa2yr.knots <- turnover.mdl$hpa2yrSpline$hpa2yrKnots
hpa2yr.optim <- turnover.mdl$hpa2yrSpline$hpa2yrKnotValues

possible.hpa2yr <- seq(105,115, 5)
hpa2yr.spline.mult <- SplineFunc(hpa2yr.knots, hpa2yr.optim, possible.hpa2yr)
# plot(possible.hpa2yr, hpa2yr.spline.mult, type='l',main="Spline Multiplier: hpa2yr", xlab="hpa2yr", ylab="Multiplier")
# points(hpa2yr.knots, hpa2yr.optim, pch = 8, col = 'blue', )



wala.knots <- turnover.mdl$walaSpline$walaKnots
wala.optim <- turnover.mdl$walaSpline$walaKnotValues

possible.wala <- seq(0, 180, 1)
wala.spline.mult <- SplineFunc(wala.knots, wala.optim, possible.wala)
plot(possible.wala, wala.spline.mult, type='l',main="Spline Multiplier: wala", xlab="wala", ylab="Multiplier")
points(wala.knots, wala.optim, pch = 8, col = 'blue', )
cbind(possible.wala, wala.spline.mult)



#
# Prepayment Graphs: Request #2
#

# Baseline S-Curve
# 
# y-axis: Refinancing Rates
# x-axis: Incentive (bps)

refinance.mdl$baselineConstant

incentive.knots <- refinance.mdl$incentiveSpline$incentiveKnots
incentive.optim <- refinance.mdl$incentiveSpline$incentiveKnotValues

# get model value at all the raw data points
possible.incentive <- seq(-300, 700, 1)
incentive.spline.mult <- SplineFunc(incentive.knots, incentive.optim, possible.incentive)
plot(possible.incentive, incentive.spline.mult, type='l',main="Spline Multiplier: incentive", xlab="incentive", ylab="Multiplier")
points(incentive.knots, incentive.optim, pch = 8, col = 'blue', )
cbind(possible.incentive, incentive.spline.mult)


# Media Effect
# y-axis: Refinancing Rates for High and Low Values of the Media Effect (2 lines). Say %Refinanceable = 40 and %Refinanceable = 70
# x-axis: Incentive (bps)

media_refi.knots <- refinance.mdl$mediaSpline$mediaKnots
media_refi.optim <- refinance.mdl$mediaSpline$mediaKnotValues


# get model value at all the raw data points
possible.media_refi <- seq(0,120, 1)
media_refi.spline.mult <- SplineFunc(media_refi.knots, media_refi.optim, possible.media_refi)
plot(possible.media_refi, media_refi.spline.mult, type='l',main="Spline Multiplier: media_refi", xlab="media_refi", ylab="Multiplier")
points(media_refi.knots, media_refi.optim, pch = 8, col = 'blue', )
cbind(possible.media_refi,media_refi.spline.mult)

# Refinance Eligible Pct
refiEligPct.knots <- refinance.mdl$refiEligSpline$refiEligPctKnots
refiEligPct.optim <- refinance.mdl$refiEligSpline$refiEligPctKnotValues

possible.refiEligPct <- seq(0, 100, 1)
refiEligPct.spline.mult <- SplineFunc(refiEligPct.knots, refiEligPct.optim, possible.refiEligPct)
plot(possible.refiEligPct, refiEligPct.spline.mult, type='l',main="Spline Multiplier: refiEligPct", xlab="refiEligPct", ylab="Multiplier")
points(refiEligPct.knots, refiEligPct.optim, pch = 8, col = 'blue', )


# cltv
cltv.knots <- turnover.mdl$cltvSpline$cltvKnots
cltv.optim <- turnover.mdl$cltvSpline$cltvKnotValues

# get model value at all the raw data points
possible.cltv <- seq(0, 170, 1)
cltv.spline.mult <- SplineFunc(cltv.knots, cltv.optim, possible.cltv)
plot(possible.cltv, cltv.spline.mult, type='l',main="Spline Multiplier: cltv", xlab="cltv", ylab="Multiplier")
points(cltv.knots, cltv.optim, pch = 8, col = 'blue')