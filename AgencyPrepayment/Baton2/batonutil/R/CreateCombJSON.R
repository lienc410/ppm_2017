#' @title Combine individual submodel JSONs into one file
#' 
#' @description
#' \code{CreateCombJSON} reads in JSON files that store splines corresponding to the various submodels for a given
#' collateral type and specified model version.
#'  
#' @param configData  configuration Data
#' @param modelVersion Release number for prepayment model
#' 
#' @examples
#'  CreateCombSON(coll="gnma30", modelVersion="v2.00")
#'  
#' @export

CreateCombJSON <- function(configData, modelVersion=NULL) {
  
  coll <- configData$FitParam$coll
  
  if (coll == "conv30") {
    if (is.null(modelVersion)) {
      modelVersion <- configData$Version$newConv30
    }
    lag <- configData$Model$Conv30RefiLag
    json <- ParseModelJSON(configData=configData, modelVersion=modelVersion)
    
    #Refi Eligibility Model JSON
    kConvRefiEligJSON  <- paste(configData$Directory$Conv30JSON, modelVersion, "refi_eligibility_projection.json", sep = "/")
    jsonRefiElig       <- jsonlite::fromJSON(kConvRefiEligJSON)
    
    # Structure for collecting all variables that we forecast on forward interest rate paths
    proj.mdl <- list("RefiEligibility"=jsonRefiElig)
    
    conv.mdl <- list("MortgageRateLag"=lag,
                     "CurtailmentSubModel"=json$curt.mdl,
                     "DefaultSubModelCurr"=json$dfltcurr.mdl,
                     "DefaultSubModelDelq"=json$dfltdelq.mdl,
                     "TurnoverSubModel"=json$turn.mdl,
                     "CashoutSubModel"=json$cout.mdl,
                     "RefinanceSubModel"=json$refi.mdl,
                     "Projection"=proj.mdl)
    
    prepay.mdl <- list("Version"=modelVersion,
                       "BaseModel"=coll,
                       "Conventional"=conv.mdl)
    prepay.model.json <- jsonlite::toJSON(prepay.mdl, digits=10, pretty=TRUE)
    kConventionalJSON <- paste(configData$Directory$Conv30JSON, modelVersion,
                               paste0(coll, "_model.json"), sep="/")
    write(prepay.model.json, file=kConventionalJSON)
  }
  else if (coll == "gnma30") {
    if (is.null(modelVersion)) {
      modelVersion <- configData$Version$newGNMA30
    }
    lag <- configData$Model$GNMA30RefiLag
    configData$FitParam$gnmaProgram <- "FHA"
    jsonFHA <- ParseModelJSON(configData=configData, modelVersion=modelVersion)
    configData$FitParam$gnmaProgram <- "VA"
    jsonVA  <- ParseModelJSON(configData=configData, modelVersion=modelVersion)
    configData$FitParam$gnmaProgram <- "RHS"
    jsonRHS <- ParseModelJSON(configData=configData, modelVersion=modelVersion)
    configData$FitParam$gnmaProgram <- "PIH"
    jsonPIH <- ParseModelJSON(configData=configData, modelVersion=modelVersion)
    
    # Structure for collecting all variables that we forecast on forward interest rate paths
    #proj.mdl <- list("RefiEligibility"=jsonRefiElig)
    
    fha.mdl <- list("MortgageRateLag"=lag,
                    "CurtailmentSubModel"=jsonFHA$curt.mdl,
                    "DefaultSubModelCurr"=jsonFHA$dfltcurr.mdl,
                    "DefaultSubModelDelq"=jsonFHA$dfltdelq.mdl,
                    "TurnoverSubModel"=jsonFHA$turn.mdl,
                    "CashoutSubModel"=jsonFHA$cout.mdl,
                    "RefinanceSubModel"=jsonFHA$refi.mdl)
    
    va.mdl  <- list("MortgageRateLag"=lag,
                    "CurtailmentSubModel"=jsonVA$curt.mdl,
                    "DefaultSubModelCurr"=jsonVA$dfltcurr.mdl,
                    "DefaultSubModelDelq"=jsonVA$dfltdelq.mdl,
                    "TurnoverSubModel"=jsonVA$turn.mdl,
                    "CashoutSubModel"=jsonVA$cout.mdl,
                    "RefinanceSubModel"=jsonVA$refi.mdl)
    
    rhs.mdl  <- list("MortgageRateLag"=lag,
                    "CurtailmentSubModel"=jsonRHS$curt.mdl,
                    "DefaultSubModelCurr"=jsonRHS$dfltcurr.mdl,
                    "DefaultSubModelDelq"=jsonRHS$dfltdelq.mdl,
                    "TurnoverSubModel"=jsonRHS$turn.mdl,
                    "CashoutSubModel"=jsonRHS$cout.mdl,
                    "RefinanceSubModel"=jsonRHS$refi.mdl)
    
    pih.mdl  <- list("MortgageRateLag"=lag,
                     "CurtailmentSubModel"=jsonPIH$curt.mdl,
                     "DefaultSubModelCurr"=jsonPIH$dfltcurr.mdl,
                     "DefaultSubModelDelq"=jsonPIH$dfltdelq.mdl,
                     "TurnoverSubModel"=jsonPIH$turn.mdl,
                     "CashoutSubModel"=jsonPIH$cout.mdl,
                     "RefinanceSubModel"=jsonPIH$refi.mdl)
    
    prepay.mdl <- list("Version"=modelVersion,
                       "BaseModel"=coll,
                       "FHA"=fha.mdl,
                       "VA"=va.mdl,
                       "RHS"=rhs.mdl,
                       "PIH"=pih.mdl)
                       
    prepay.model.json   <- jsonlite::toJSON(prepay.mdl, digits=10, pretty=TRUE)
    kGinnieMaeJSON      <- paste(configData$Directory$GNMA30JSON, modelVersion, 
                                 paste0(coll, "_model.json"), sep="/")
    write(prepay.model.json, file=kGinnieMaeJSON)
  }
  else {
    stop(paste0("Unsupported collateral type", coll, "\n"))
  }

}
