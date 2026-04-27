#' @title Decompose actual prepayment rate into subcomponents by prepayment type 
#' 
#' @description
#' \code{PrepayComp} Decomposes the actual prepayment rate into its constituents (curtailments, default, ...) by
#' using the prepayment model. The actual components are added as columns to the data frame. Note that the decomposition
#' depends on the choice of prepayment model
#'  
#' @param submodel  submodel type
#' @param ppdata data frame containing indicative data for the loans/pools/replines that we want projections for
#' @param modelVersion Prepayment model version
#' 
#' @return
#' Prepayment model dataframe with added columns
#' 
#' @examples
#' \dontrun{
#'  PrepayComp(submodel="turn", ppdata=ppdata, modelVersion)
#'  }
#'  
PrepayComp <- function(submodel, modelVersion, ppdata) {
  
    submodelNames <- paste(c("curt", "dfltall", "dfltcurr", "dfltdelq", "cout", "turn", "refi"), modelVersion, sep="_")
  
    if (configData$FitParam$useAltDfltFile) {
      dfltall.mdl <- ppdata[, paste(c("dfltall"), modelVersion, sep="_")]
      dfltcurr.mdl <- ppdata[, paste(c("dfltcurr"), modelVersion, sep="_")]
      dfltdelq.mdl <- ppdata[, paste(c("dfltdelq"), modelVersion, sep="_")]
    } else {
        curt.mdl     <- ppdata[, paste(c("curt"), modelVersion, sep="_")]
        dfltall.mdl  <- ppdata[, paste(c("dfltall"), modelVersion, sep="_")]
        dfltcurr.mdl <- ppdata[, paste(c("dfltcurr"), modelVersion, sep="_")]
        dfltdelq.mdl <- ppdata[, paste(c("dfltdelq"), modelVersion, sep="_")]
        cout.mdl     <- ppdata[, paste(c("cout"), modelVersion, sep="_")]
        turn.mdl     <- ppdata[, paste(c("turn"), modelVersion, sep="_")]
        refi.mdl     <- ppdata[, paste(c("refi"), modelVersion, sep="_")]
    }
    
    if ((submodel == "turn") | (submodel == "refi") | (submodel == "cout") | (submodel == "all")) {
        
      # Note that prepay subcomponents may have some negative values but we don't floor at zero 
      # in order to avoid censoring the data
      
      #Turnover
      ppdata$turn.act <- ppdata$smm - (curt.mdl + dfltall.mdl + cout.mdl + refi.mdl)
      
      #OTM Cashouts
      ppdata$cout.act <- ppdata$smm - (curt.mdl + dfltall.mdl + turn.mdl + refi.mdl)
      
      #Refinancings
      ppdata$refi.act <- ppdata$smm - (curt.mdl + dfltall.mdl + cout.mdl + turn.mdl)
    }
    else if ((submodel == "dflt") | (submodel == "dfltcurr")) {
      # Default data set is structured differently; in this case we are able to directly estimate default-related
      # prepayments
      ppdata$dflt.act <- ppdata$mdr
    }
    else if (submodel == "dfltdelq") {
      # Infer default rates for pools that are 100% delinquent. These pools are rarely observable in practice
      # and what one sees is the blended default rates corresponding to pools that are somewhat delinquent.
      dflt.bal  <- ppdata$bal * ppdata$mdr # Total defaults in $s
      dflt.bal.curr <- ppdata$bal * (1 - ppdata$pct_dq/100) *  dfltcurr.mdl
      dflt.bal.delq <- pmax(0, dflt.bal - dflt.bal.curr) # Total defaults from delinquent loans
      
      smm.delq <- pmin(1, dflt.bal.delq/(ppdata$bal * ppdata$pct_dq/100))
      
      # Rewrite balances and default rates for the data set so that they correspond to 100% delinquent pools 
      ppdata$dflt.act <- ppdata$mdr <- ppdata$smm <- smm.delq
      ppdata$bal      <- ppdata$bal * ppdata$pct_dq/100
    }
    else {
      stop("Unknown submodel type\n")
    }
    
    ppdata$cpr.act    <- SMMtoCPR(ppdata$smm)
    
    return(ppdata)
} 
