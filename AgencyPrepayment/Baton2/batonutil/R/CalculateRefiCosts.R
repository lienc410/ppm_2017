#' @title Calculate refi costs for different loan/property attributes. 
#' 
#' @description
#' \code{CalculateRefiCosts} estimates the cost of a refinancing based on different loan and/or property attributes. 
#'  In particular, these costs can vary by loan size, whether the property is a second home, and/or if it is an investor
#'  property, among other attributes.
#'  
#' @param ppdata Data frame of prepayment observations
#' 
#' @details
#' TO-DO
#' 
#' @return 
#' ppdata Prepayment data frame with an extra column for refi-related costs
#' 
#' @examples
#'  CalculateRefiCosts(ppdata=ppdata)
#'   
CalculateRefiCosts <- function(ppdata, configData) {
    # Linear cost functions. A positive cost implies that there's less incentive (the model will forecast lower speeds)
    # and vice-versa. All costs are in bps.
   
    # Since fixed costs of refinancing are independent of loan size they pose a greater hurdle for small balance
    # loans. We assume that the hurdle is inversely proportional to the loan size. Also, the refi cost offset is
    # 0bps for the average loan size.
  
    coll <- configData$FitParam$coll
    pct2ndRefiCost <- configData$Model$pct2ndRefiCost
    pctInvRefiCost <- configData$Model$pctInvRefiCost
    conversionFact <- configData$Model$conversionFact
    conv30WACLS    <- configData$Model$conv30WACLS
    gnma30WACLS    <- configData$Model$gnma30WACLS
    minWACLS       <- configData$Model$minWACLS
    fixedRefiCosts <- configData$Model$fixedRefiCosts
    
    if (coll == "conv30") {
      # costMaxWACLS <- conversionFact * ((fixedRefiCosts/conv30WACLS) - (fixedRefiCosts/minWACLS))  
      # costWACLS    <- pmin(conversionFact * ((fixedRefiCosts/conv30WACLS) - (fixedRefiCosts/ppdata$acls)), 
      #                      rep(costMaxWACLS, length(ppdata$acls)))
      costWACLS       <- -conversionFact * (fixedRefiCosts/ppdata$acls)
      costWACLS       <- pmin(costWACLS, 100.0)
      ppdata$reficost <- (ppdata$pct_2nd/100 * pct2ndRefiCost) + (ppdata$pct_inv/100 * pctInvRefiCost) + costWACLS
    }
    else if (coll == "gnma30") {
      costMaxWACLS <- conversionFact * ((fixedRefiCosts/gnma30WACLS) - (fixedRefiCosts/minWACLS))  
      costWACLS    <- pmin(conversionFact * ((fixedRefiCosts/gnma30WACLS) - (fixedRefiCosts/ppdata$wacls)), 
                           rep(costMaxWACLS, length(ppdata$wacls)))
      ppdata$reficost <- costWACLS
    }
    else {
      stop(paste0("Don't know how to calculate refi costs for this collateral type:", coll, "\n"))
    }
    
    #ppdata$reficost <- rep(0, length(ppdata$wacls))
     
    return(ppdata)
} 
