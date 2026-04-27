#' @title Parse model parameters from JSON file
#' 
#' @description
#' \code{ParseModelJSON} reads in JSON files that store splines corresponding to the various submodels for a given
#' collateral type and for a specified version of the model. 
#'  
#' @param coll  collateral type
#' @param gnmaProgram  GNMA program (ex., FHA) to read submodel JSON files for
#' @param modelVersion  Release number for the prepayment model
#' 
#' @return 
#' List whose elements consists of individual submodel JSONs for collateral type and model version
#' 
#' @examples
#' \dontrun{
#' ParseModelJSON(configData=configData, modelVersion="v2.00")
#' }
#'  
ParseModelJSON <- function(configData, modelVersion=NA, combinedJSON = FALSE) {
     
    coll        <- configData$FitParam$coll
    gnmaProgram <- configData$FitParam$gnmaProgram
     
    if (coll == "conv30") {
      if (is.na(modelVersion)) {
        modelVersion <- configData$Version$newConv30
      }
      
      kJSONDir        <- configData$Directory$Conv30JSON
      if (combinedJSON == FALSE) {
        kDfltCurrJSON <- paste(kJSONDir, modelVersion, "dflt_curr.json", sep = "/")
        kDfltDelqJSON <- paste(kJSONDir, modelVersion, "dflt_delq.json", sep = "/")
        kCurtJSON     <- paste(kJSONDir, modelVersion, "curt.json", sep = "/")
        kTurnJSON     <- paste(kJSONDir, modelVersion, "turn.json", sep = "/")
        kCoutJSON     <- paste(kJSONDir, modelVersion, "cout.json", sep = "/")
        kRefiJSON     <- paste(kJSONDir, modelVersion, "refi.json", sep = "/")
        
        turn.mdl      <- jsonlite::fromJSON(kTurnJSON)
        cout.mdl      <- jsonlite::fromJSON(kCoutJSON)
        refi.mdl      <- jsonlite::fromJSON(kRefiJSON)
        curt.mdl      <- jsonlite::fromJSON(kCurtJSON)
        dfltcurr.mdl  <- jsonlite::fromJSON(kDfltCurrJSON)
        dfltdelq.mdl  <- jsonlite::fromJSON(kDfltDelqJSON)
      } else {
        kMdlJSON      <- paste(kJSONDir, modelVersion, "conv30_model.json", sep = "/")
        
        mdl           <- jsonlite::fromJSON(kMdlJSON)
        turn.mdl      <- mdl$Conventional$TurnoverSubModel
        cout.mdl      <- mdl$Conventional$CashoutSubModel
        refi.mdl      <- mdl$Conventional$RefinanceSubModel
        curt.mdl      <- mdl$Conventional$CurtailmentSubModel
        dfltcurr.mdl  <- mdl$Conventional$DefaultSubModelCurr
        dfltdelq.mdl  <- mdl$Conventional$DefaultSubModelDelq
      }
    }
    else if (coll == "gnma30") {
      if (is.na(modelVersion)) {
        modelVersion <- configData$Version$newGNMA30
      }
      kJSONDir <- configData$Directory$GNMA30JSON
      
      kDfltCurrJSON_FHA <- paste(kJSONDir, modelVersion, "dflt_curr_fha.json", sep = "/")
      kDfltDelqJSON_FHA <- paste(kJSONDir, modelVersion, "dflt_delq_fha.json", sep = "/")
      kCurtJSON_FHA     <- paste(kJSONDir, modelVersion, "curt_fha.json", sep = "/")
      kTurnJSON_FHA     <- paste(kJSONDir, modelVersion, "turn_fha.json", sep = "/")
      kCoutJSON_FHA     <- paste(kJSONDir, modelVersion, "cout_fha.json", sep = "/")
      kRefiJSON_FHA     <- paste(kJSONDir, modelVersion, "refi_fha.json", sep = "/")
      
      kDfltCurrJSON_VA <- paste(kJSONDir, modelVersion, "dflt_curr_va.json", sep = "/")
      kDfltDelqJSON_VA <- paste(kJSONDir, modelVersion, "dflt_delq_va.json", sep = "/")
      kCurtJSON_VA     <- paste(kJSONDir, modelVersion, "curt_va.json", sep = "/")
      kTurnJSON_VA     <- paste(kJSONDir, modelVersion, "turn_va.json", sep = "/")
      kCoutJSON_VA     <- paste(kJSONDir, modelVersion, "cout_va.json", sep = "/")
      kRefiJSON_VA     <- paste(kJSONDir, modelVersion, "refi_va.json", sep = "/")
      
      kDfltCurrJSON_RD <- paste(kJSONDir, modelVersion, "dflt_curr_rd.json", sep = "/")
      kDfltDelqJSON_RD <- paste(kJSONDir, modelVersion, "dflt_delq_rd.json", sep = "/")
      kCurtJSON_RD     <- paste(kJSONDir, modelVersion, "curt_rd.json", sep = "/")
      kTurnJSON_RD     <- paste(kJSONDir, modelVersion, "turn_rd.json", sep = "/")
      kCoutJSON_RD     <- paste(kJSONDir, modelVersion, "cout_rd.json", sep = "/")
      kRefiJSON_RD     <- paste(kJSONDir, modelVersion, "refi_rd.json", sep = "/")
      
      kDfltCurrJSON_PIH <- paste(kJSONDir, modelVersion, "dflt_curr_pih.json", sep = "/")
      kDfltDelqJSON_PIH <- paste(kJSONDir, modelVersion, "dflt_delq_pih.json", sep = "/")
      kCurtJSON_PIH     <- paste(kJSONDir, modelVersion, "curt_pih.json", sep = "/")
      kTurnJSON_PIH     <- paste(kJSONDir, modelVersion, "turn_pih.json", sep = "/")
      kCoutJSON_PIH     <- paste(kJSONDir, modelVersion, "cout_pih.json", sep = "/")
      kRefiJSON_PIH     <- paste(kJSONDir, modelVersion, "refi_pih.json", sep = "/")
      
      if (gnmaProgram == "FHA") {
        turn.mdl     <- jsonlite::fromJSON(kTurnJSON_FHA)
        cout.mdl     <- jsonlite::fromJSON(kCoutJSON_FHA)
        refi.mdl     <- jsonlite::fromJSON(kRefiJSON_FHA)
        curt.mdl     <- jsonlite::fromJSON(kCurtJSON_FHA)
        dfltcurr.mdl <- jsonlite::fromJSON(kDfltCurrJSON_FHA)
        dfltdelq.mdl <- jsonlite::fromJSON(kDfltDelqJSON_FHA)
        
      }
      else if (gnmaProgram == "VA") {
        turn.mdl     <- jsonlite::fromJSON(kTurnJSON_VA)
        cout.mdl     <- jsonlite::fromJSON(kCoutJSON_VA)
        refi.mdl     <- jsonlite::fromJSON(kRefiJSON_VA)
        curt.mdl     <- jsonlite::fromJSON(kCurtJSON_VA)
        dfltcurr.mdl <- jsonlite::fromJSON(kDfltCurrJSON_VA)
        dfltdelq.mdl <- jsonlite::fromJSON(kDfltDelqJSON_VA)
            
      }
      else if (gnmaProgram == "RHS") {
        turn.mdl     <- jsonlite::fromJSON(kTurnJSON_RD)
        cout.mdl     <- jsonlite::fromJSON(kCoutJSON_RD)
        refi.mdl     <- jsonlite::fromJSON(kRefiJSON_RD)
        curt.mdl     <- jsonlite::fromJSON(kCurtJSON_RD)
        dfltcurr.mdl <- jsonlite::fromJSON(kDfltCurrJSON_RD)
        dfltdelq.mdl <- jsonlite::fromJSON(kDfltDelqJSON_RD)
        
      }
      else if (gnmaProgram == "PIH") {
        turn.mdl     <- jsonlite::fromJSON(kTurnJSON_PIH)
        cout.mdl     <- jsonlite::fromJSON(kCoutJSON_PIH)
        refi.mdl     <- jsonlite::fromJSON(kRefiJSON_PIH)
        curt.mdl     <- jsonlite::fromJSON(kCurtJSON_PIH)
        dfltcurr.mdl <- jsonlite::fromJSON(kDfltCurrJSON_PIH)
        dfltdelq.mdl <- jsonlite::fromJSON(kDfltDelqJSON_PIH)
        
      }
      else {
        stop(paste0("Unsupported GNMA program type: ", gnmaProgram))
      }
      
    }
    else {
      stop(paste0("Unsupported collateral option: ", coll))
    }
    
    return(list(turn.mdl = turn.mdl, cout.mdl = cout.mdl, refi.mdl = refi.mdl, curt.mdl = curt.mdl, 
                dfltcurr.mdl = dfltcurr.mdl, dfltdelq.mdl = dfltdelq.mdl))
} 
