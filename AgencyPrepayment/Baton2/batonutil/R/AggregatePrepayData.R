#' Aggregate prepayment data along a specified dimension 
#' 
#'  \code{AggregatePrepaymentData} calculates the weighted average prepayment rate (actual and model) associated with a 
#'  specific bucketing of the specified dimension. It requires the data.table package.
#'  
#' @param data A data frame with prepayment data
#' @param act actual prepayments (in smm)
#' @param pred model forecasted prepayments (in smm)
#' @param col.name column to aggregate over
#' @param configData configuration data
#' 
#' @return A list containing actual and projected prepays (in cpr) when aggregated along the specified dimension. 
#' Additionally, the act/proj ratio, balances and column values associated with the gridding of the dimension are also
#' provided.
#' 
#' @examples
#' \dontrun{
#' AggregatePrepaymentData(data=ppdata, act=act.smm, pred=mdl.smm, col.name="asofdate")
#' AggregatePrepaymentData(data=ppdata, act=act.smm, pred=mdl.smm, col.name="burnout")
#' }
#' 
AggregatePrepaymentData <- function(data, act, pred, col.name, configData) {
   
    bucketSize <- configData$FitParam$bucketSize
    cutoffBal  <- configData$FitParam$minBal
  
    # Convert %prepayments into dollars for weighting
    data$mdl.ppbal <- pred * data$bal
    data$act.ppbal <- act * data$bal
    
    data$col <- data[, c(col.name)]
    
    if ((col.name != "asofdate") & (col.name != "asOf")) {
        data$col <- floor(data$col/bucketSize) * bucketSize
    }
    
    data <- data.table::as.data.table(data)  # Convert data frame into a data table for aggregations
    
    actbal <- data[, list(actbal = sum(act.ppbal)), by = list(col)][order(col)]
    mdlbal <- data[, list(mdlbal = sum(mdl.ppbal)), by = list(col)][order(col)]
    totbal <- data[, list(totbal = sum(bal)),       by = list(col)][order(col)]
    x <- totbal[, col]
    
    # Filter negligible balances to avoid division by zero
    idx <- (totbal$totbal > cutoffBal)
    totbal.idx <- totbal$totbal[idx]
    actbal.idx <- actbal$actbal[idx]
    mdlbal.idx <- mdlbal$mdlbal[idx]
    x.idx <- x[idx]
    
    act.cpr   <- 100 * (1 - (1 - actbal.idx/totbal.idx)^12)
    mdl.cpr   <- 100 * (1 - (1 - mdlbal.idx/totbal.idx)^12)
    ratio.cpr <- act.cpr/mdl.cpr
    ratio.bal <- totbal.idx
    
    return(list(act.cpr = act.cpr, mdl.cpr = mdl.cpr, ratio.cpr = ratio.cpr, ratio.bal = ratio.bal, col.x = x.idx))
} 
