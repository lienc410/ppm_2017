#' @title RMSE with option to use weights for different points and to also allow computation of an adjusted RMSE 
#' 
#' @description
#' \code{ModelErrorStats} calculates the RMSE given a vector of actual prepayments and a vector of projected prepayments.
#'  
#' @param actual  observed prepayment rates
#' @param pred model predictions
#' @param weights weights for the various observations
#' @param totalparams not used
#' @param freeparams not used
#' 
#' @return
#' List with error statistics
#' 
#' @examples
#' \dontrun{
#'  ModelErrorStats(actual=actual, pred=pred, weights)
#'  }
#'  
ModelErrorStats <- function(actual, pred, weights = NULL, totalparams = 0, freeparams = 0) {
    
    if (is.null(weights)) 
        weights <- rep(1, length(actual))
    else {
      if ((sum(weights) > 1.01) | (sum(weights) < 0.99)) {
        stop(paste("Weights need to add to 1", round(sum(weights), digits=2), "\n", sep=" "))
      } 
    }
    
    sse <- sum(weights * (actual - pred)^2)
    
    rmse <- sqrt(sse/length(weights))
    
    if ((totalparams > 0) && (totalparams > freeparams)) {
        adj.rmse <- sqrt(sse/(totalparams - freeparams))
        aic <- (totalparams * log(sse/totalparams)) - (freeparams * log(totalparams))
        bic <- (totalparams * log(sse/totalparams)) - (freeparams * 2)
    } else adj.rmse <- aic <- bic <- NULL
    
    model.error.stats <- list(rmse = rmse, adj.rmse = adj.rmse, aic = aic, bic = bic)
    
    return(model.error.stats)
} 
