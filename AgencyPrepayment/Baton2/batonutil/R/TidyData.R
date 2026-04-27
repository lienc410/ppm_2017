#' @title Tidy prepayment data 
#' 
#' @description
#' \code{tidyr} ensures that the data is in "tidy" format. In practice, this is not really an issue with 
#' the prepayment data set since it is already structured to be "tidy." Most of the work involves handling missing values. 
#' See also \code{\link{imprtr}} and \code{\link{tfrmr}} for functions that perform additional data 
#' munging.
#'  
#' @param coll  collateral being modeled (\code{"conv"} or \code{"gnma"})
#' @param ppdata  Data frame of prepayment data
#' 
#' @details
#' Most of the work in \code{imprtr} is in handling NA values. There are two cases to consider: (1) When NA values are
#' replaceable with an estimate and (2) when this is not possible. In the first case, we usually replace the NA values with
#' an average. In the second case, we drop the row that contains the NA value.
#' 
#' @return 
#' ppdata Tidied prepayment data frame
#' 
#' @examples
#'  tidyr(coll = "conv", ppdata=ppdata)
#'  
#' @seealso
#' \url{http://r4ds.had.co.nz/tidy-data.html}
#'  
#' @export

tidyr <- function(coll, submodel, gnmaProgram="", ppdata) {
    
    cat("Tidying data", "\n")
    
    if (coll == "conv30") {
      fico.avg <- weighted.mean(ppdata$fico, ppdata$bal, na.rm = TRUE)
      cltv.avg <- weighted.mean(ppdata$cltv, ppdata$bal, na.rm = TRUE)
      wacls.avg <- weighted.mean(ppdata$wacls, ppdata$bal, na.rm = TRUE)
      pct_REFI.avg <- weighted.mean(ppdata$pct_REFI, ppdata$bal, na.rm = TRUE)
      pct_tpo.avg <- 40  # Corresponds to a knot point of 1 in the JSON file. The lack of historical data on the TPO field
      # makes calculating a value based on historical averages problematic.
      pct_2nd.avg <- weighted.mean(ppdata$pct_2nd, ppdata$bal, na.rm = TRUE)
      pct_inv.avg <- weighted.mean(ppdata$pct_inv, ppdata$bal, na.rm = TRUE)
      pct_dq.avg <- weighted.mean(ppdata$pct_dq, ppdata$bal, na.rm = TRUE)
      
      dataReplaceColNames <- c("fico", "cltv", "wacls", "pct_REFI", "pct_tpo", "pct_2nd", "pct_inv", "pct_dq")
      replaceValues <- c(fico.avg, cltv.avg, wacls.avg, pct_REFI.avg, pct_tpo.avg, pct_2nd.avg, pct_inv.avg, pct_dq.avg)
      ppdata <- ReplaceNAs(ppdata, dataColNames = dataReplaceColNames, replaceValues = replaceValues)
      
      dataDropNames <- c("incentive", "burnout", "sato", "smm")
      ppdata <- RemoveNARows(ppdata, dataColNames = dataDropNames)
    }
    else if (coll == "gnma30") {
      dataDropNames <- c("incentive")
      ppdata <- RemoveNARows(ppdata, dataColNames = dataDropNames)
    }
    else {
      cat("Unsupported collateral type", coll, "\n")
    }
        
    return(ppdata)  
} 
