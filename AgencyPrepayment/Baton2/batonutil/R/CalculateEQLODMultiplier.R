#' Modify eqlod multiplier as a function of the current LTV. 
#' 
#'  \code{CalculateEQLODMultiplier} sets the previously calculated eqlod multiplier to 1.0 whenever the cltv is greater
#'  than 100%.
#'    
#' @param origMult original eqlod multiplier.
#' @param cltv a vector of cltv values.
#' @return eqlod multiplier.
#' @examples
#'  CalculateEQLODMultiplier(origMult, cltv)
#'  
CalculateEQLODMultiplier <- function(origMult, cltv) {
    
  eqlodMult                 <- origMult
  eqlodMult[(cltv > 100.0)] <- 1.0 
    
  return(eqlodMult)
} 
