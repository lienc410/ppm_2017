#' @title Generate seasonal factors for different months
#' 
#' @description
#' \code{SeasonalAdjustment} reads in seasonal multipliers corresponding to different months and then calculates
#' the appropriate multiplier for a vector of months 
#'  
#' @param seasonals  seasonal multipliers for different calendar months in the year
#' @param months vector of months
#' 
#' @return 
#' Vector of seasonal multipliers corresponds to the different months 
#' 
#' @examples
#' \dontrun{
#' SeasonalAdjustment(seasonals=seasonals, months=months)
#' }
#'  

SeasonalAdjustment <- function(seasonals, months) {
    seasonalFactor <- seasonals$KnotValues[match(months, seasonals$Knots)]
    return(seasonalFactor)
}