#' Aggregate data along a specified dimension 
#' 
#'  \code{AggregateData} calculates the weighted average y-value associated with a 
#'  specific bucketing of the specified dimension (the x-value). It requires the data.table package.
#'  
#' @param data A data frame with data
#' @param x.col Value to aggregate over
#' @param y.col Value that is aggregated
#' @return A list containing aggregated y and x column values
#' @examples
#' \dontrun{
#' AddMonths(data=ppdata, act=act.smm, pred=mdl.smm, col.name="asofdate")
#' AddMonths(data=ppdata, act=act.smm, pred=mdl.smm, col.name="burnout")
#' }
aggregatr <- function(data, x.col="asofdate", y.col, bucketSize=5) {
  
    data$x.col     <- data[, c(x.col)]
    data$y.col.bal <- data[, c(y.col)] * data$bal
    
    if ((x.col != "asofdate") & (x.col != "asOf")) {
        data$x.col <- floor(data$x.col/bucketSize) * bucketSize
    }
    
    data <- data.table::as.data.table(data)  # Convert data frame into a data table for aggregations
    
    ybal   <- data[, list(ybal = sum(y.col.bal)), by = list(x.col)][order(x.col)]
    totbal <- data[, list(totbal = sum(bal)), by = list(x.col)][order(x.col)]
    aggY   <- ybal$ybal/totbal$totbal 
    aggX   <- totbal[, x.col]
    
    return(list(aggX=aggX, aggY=aggY))
} 
