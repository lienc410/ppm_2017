#' @title Prepayment model estimator 
#' 
#' @description
#' \code{estimatr} estimates the prepayment model.
#'  
#' @param coll  collateral being modeled (\code{"conv30"} or \code{"gnma30"})
#' @param submodel prepayment component we want dataset for (\code{"dflt"}, \code{"refi"}, \code{"turn"})
#' @param gnmaProgram FHA, VA, RHS or PIH
#' @param extparamsFitted vector of spline parameters to optimize
#' @param ppdata  Data frame of prepayment data
#' 
#' @details
#' Find optimal splines through an optimization routine. 
#' 
#' @return 
#' List ppdata JSON
#' 
#' @examples
#'  estimatr(configData=configData, extparamsFitted=NULL, ppdata=ppdata)
#'  
#' @export

estimatr <- function(configData, extparamsFitted=NULL, ppdata) {
    
  coll          <- configData$FitParam$coll
  submodel      <- configData$FitParam$submodel
  gnmaProgram   <- configData$FitParam$gnmaProgram
  aggType       <- configData$FitParam$aggType
  OutputDir     <- configData$Directory$Output
  kTol          <- configData$FitParam$fitTol
  kWeightCutoff <- configData$FitParam$minWt
  
  splinesUpdated <- c()
  
  if (coll == "conv30") {
    modelVersion <- configData$Version$newConv30
  }
  else if (coll == "gnma30") {
    modelVersion <- configData$Version$newGNMA30
  }
  else {
    stop(paste0("Unsupported collateral type: ", coll, "\n"))
  }
    
  # TO-DO: This section of code is ripe for placement in another function call. Note the repetition with trackr.
  json   <- ParseModelJSON(configData, modelVersion=modelVersion)
  ppdata <- ModelProj(configData, modelVersions=c(modelVersion), ppdata=ppdata)
  ppdata <- PrepayComp(submodel=submodel, modelVersion=modelVersion, ppdata=ppdata)
  
  # Initialize so that we know what we want to track
  paramsNotFitted <- c("baselineConstant", "adjustmentFactor", "seasonalityMultipliers")
  if (submodel == "turn") {
    submdl.json     <- json$turn.mdl
    paramsFitted    <- names(submdl.json)[-match(paramsNotFitted, names(submdl.json))]
    ppdata$ppr      <- ppdata$turn.act
    ppdata$pred     <- ppdata[, paste(submodel, modelVersion, sep="_")]
  } else if (submodel == "cout") {
    submdl.json     <- json$cout.mdl
    paramsFitted    <- names(submdl.json)[-match(paramsNotFitted, names(submdl.json))]
    ppdata$ppr      <- ppdata$cout.act
    ppdata$pred     <- ppdata[, paste(submodel, modelVersion, sep="_")]
  } else if (submodel == "refi") {
    submdl.json     <- json$refi.mdl
    paramsFitted    <- names(submdl.json)[-match(paramsNotFitted, names(submdl.json))]
    ppdata$ppr      <- ppdata$refi.act
    ppdata$pred     <- ppdata[, paste(submodel, modelVersion, sep="_")]
  } 
  else if (submodel == "dflt") {
    submdl.json     <- json$dfltcurr.mdl
    paramsFitted    <- names(submdl.json)[-match(paramsNotFitted, names(submdl.json))]
    ppdata$ppr      <- ppdata$dflt.act
    ppdata$pred     <- ppdata[, paste(c("dfltall"), modelVersion, sep="_")]
  }
  else if (submodel == "dfltcurr") {
    submdl.json     <- json$dfltcurr.mdl
    paramsFitted    <- names(submdl.json)[-match(paramsNotFitted, names(submdl.json))]
    ppdata$ppr      <- ppdata$dflt.act
    ppdata$pred     <- ppdata[, paste(submodel, modelVersion, sep="_")]
  }
  else if (submodel == "dfltdelq") {
    submdl.json     <- json$dfltdelq.mdl
    paramsFitted    <- names(submdl.json)[-match(paramsNotFitted, names(submdl.json))]
    ppdata$ppr      <- ppdata$dflt.act
    ppdata$pred     <- ppdata[, paste(submodel, modelVersion, sep="_")]
    ppdata$incentive <- ppdata$incentive.store # Look at default tracking versus unadjusted incentive
  } else if (submodel == "all") {
    submdl.json      <- json$refi.mdl
    paramsFittedRefi <- names(submdl.json)[-match(paramsNotFitted, names(submdl.json))]
    submdl.json      <- json$turn.mdl
    paramsFittedTurn <- names(submdl.json)[-match(paramsNotFitted, names(submdl.json))]
    paramsFitted     <- union(paramsFittedRefi, paramsFittedTurn)
    ppdata$ppr       <- ppdata$smm
    ppdata$pred      <- ppdata[, paste(c("modelSMM"), modelVersion, sep="_")]
  }
  else {
    stop("Don't know how to handle this submodel option currently\n")
  }
    ############################### End TO-DO
    
    wt <- ppdata$bal/sum(ppdata$bal)
    rmse.new <- ModelErrorStats(actual = ppdata$ppr, pred = ppdata$pred, weights = wt)$rmse
    cat("\nAggregate RMSE:", modelVersion, rmse.new, "\n")
     
    iter <- 0
    failCount <- 0
    json.prev <- json
    errCutoff <- rmse.new
    if (!is.null(extparamsFitted)) {
      paramsFitted <- extparamsFitted
    }
    numFitted <- length(paramsFitted)
    
    # Stop the iterative estimation process when you go through a complete cycle (i.e., go through each of the 
    # explanatory variables) of being unable to lower the RMSE by updating spline coefficients for individual 
    # variables.
    
    while (failCount < numFitted) {
        
        iter <- iter + 1
        cat("Fitting Iteration: ", iter, "\n")
        cat("Fail Count", failCount, "\n")
        cat("Fit RMSE:", errCutoff, "\n")
        for (i in seq_len(numFitted)) {
            col.name <- paramsFitted[i]
            cat("\nFitting:", col.name, "\n")
            aggPrepays <- AggregatePrepaymentData(data = ppdata, act = ppdata$ppr, pred = ppdata$pred, 
                                                  col.name = col.name, configData=configData)
            act.cpr <- aggPrepays$act.cpr
            mdl.cpr <- aggPrepays$mdl.cpr
            ratio.cpr <- aggPrepays$ratio.cpr
            ratio.wt <- aggPrepays$ratio.bal/sum(aggPrepays$ratio.bal)
            x <- aggPrepays$col.x
            
            # Screen for points with relatively low weights so that they don't influence the fit. In particular, the
            # technique of trying to find the lis to fit the spline is probably too sensitive to low-weight data points.
            # This is particularly problematic when the distribution is bar-belled.
            kWeightCutoff <- 1.0 #TO-DO: place in config file
            keep.idx <- ((ratio.wt * 100) > kWeightCutoff) & (!is.na(ratio.wt))
            ratio.cpr <- ratio.cpr[keep.idx]
            ratio.wt <- ratio.wt[keep.idx]/sum(ratio.wt[keep.idx])
            x <- x[keep.idx]
            
            idx <- match(col.name, names(submdl.json))
            x.knot <- unlist(submdl.json[idx][[1]][1])  # Otherwise R complains about not being able to coerce a list into a double
            y.knot <- unlist(submdl.json[idx][[1]][2])
            
            # Update JSON values based on the smooth spline estimates
            fit.spl <- BuildSpline(a = x, b = ratio.cpr, x = x.knot, weights = ratio.wt, method = "smooth")
            submdl.json[idx][[1]][2] <- submdl.json[idx][[1]][2] * fit.spl$y
            
            if (submodel == "turn") {
              if ((col.name != "wacls") && (col.name != "cltv"))  {
                spl.tune <- tuner(x=x.knot, y=unlist(submdl.json[idx][[1]][2]), option="inc")
              }
              else {
                spl.tune <- tuner(x=x.knot, y=unlist(submdl.json[idx][[1]][2]), option="dec")
              }
            }
            else if (submodel == "cout") {
              if ((col.name != "fico") && (col.name != "cltv")) {
                spl.tune <- tuner(x=x.knot, y=unlist(submdl.json[idx][[1]][2]), option="inc")
              }
              else {
                spl.tune <- tuner(x=x.knot, y=unlist(submdl.json[idx][[1]][2]), option="dec")
              }
            }
            else if (submodel == "refi") {
              if ((col.name != "burnout") && (col.name != "pct_HARPed") && (col.name != "cltv")) {
                spl.tune <- tuner(x=x.knot, y=unlist(submdl.json[idx][[1]][2]), option="inc")
              }
              else {
                spl.tune <- tuner(x=x.knot, y=unlist(submdl.json[idx][[1]][2]), option="dec")
              }
            }
            else if (submodel == "dfltcurr") {
              if ((col.name != "cai") && (col.name != "fico")) {
                spl.tune <- tuner(x=x.knot, y=unlist(submdl.json[idx][[1]][2]), option="inc")
              }
              else {
                spl.tune <- tuner(x=x.knot, y=unlist(submdl.json[idx][[1]][2]), option="dec")
              }
            }
            else if (submodel == "dfltdelq") {
              if ((col.name != "cai") && (col.name != "fico") && (col.name != "monthsSince")) {
                spl.tune <- tuner(x=x.knot, y=unlist(submdl.json[idx][[1]][2]), option="inc")
              }
              else {
                spl.tune <- tuner(x=x.knot, y=unlist(submdl.json[idx][[1]][2]), option="dec")
              }
            }
            else {
              # do nothing
            }
            
            cat("\nx knot values:", x.knot, "\n")
            cat("Initial spline:", unlist(submdl.json[idx][[1]][2]), "\n")
            cat("Tuned spline:", spl.tune$y, "\n")
            submdl.json[idx][[1]][2] <- list(spl.tune$y)
            
            if (submodel == "turn") {
              json$turn.mdl[idx][[1]][2] <- submdl.json[idx][[1]][2]
            } else if (submodel == "refi") {
              json$refi.mdl[idx][[1]][2] <- submdl.json[idx][[1]][2]
            } else if (submodel == "cout") {
              json$cout.mdl[idx][[1]][2] <- submdl.json[idx][[1]][2]
            } else if (submodel == "dfltcurr") {
              json$dfltcurr.mdl[idx][[1]][2] <- submdl.json[idx][[1]][2]
            } else if (submodel == "dfltdelq") {
              json$dfltdelq.mdl[idx][[1]][2] <- submdl.json[idx][[1]][2]  
            } else {
              # do nothing
            }
            
            # Regenerate model predictions using updated spline for this parameter
            ppdata <- ModelProj(configData, modelVersions=c(modelVersion), json=json, ppdata=ppdata)
            ppdata <- PrepayComp(submodel=submodel, modelVersion=modelVersion, ppdata=ppdata)
            ppdata$pred     <- ppdata[, paste(submodel, modelVersion, sep="_")]
            
            # Calculate error rmse using updated parameters
            wt <- ppdata$bal/sum(ppdata$bal)
            rmse <- ModelErrorStats(actual = ppdata$ppr, pred = ppdata$pred, weights = wt)$rmse
            
            # if rmse < (errCutOff - kTol) then update spline knot values for that variable in the submodel JSON. 
            # Else, you've failed to improve the fit by updating the spline for this variable so move onto
            # the next one.
           
            if (rmse < (errCutoff - kTol)) {
                cat("\nSUCCESS: Updated splines coefficients for:", col.name, "\n")
                cat("Knots:", x.knot, "\n")
                cat("Prev:", y.knot, "\n")
                cat("New:", unlist(submdl.json[idx][[1]][2]), "\n")
                json.prev <- json
                errCutoff <- rmse
                failCount <- 0
                if (!(col.name %in% splinesUpdated)) {
                  splinesUpdated <- c(splinesUpdated, col.name)
                }
            } else {
                cat("\nFAILURE: Did not update spline coefficients for:", col.name, "\n")
                # Restore previous knot values
                json <- json.prev
                failCount <- failCount + 1
                # Restore previous values for model predictions
                ppdata <- ModelProj(configData, modelVersions=c(modelVersion), json=json, ppdata=ppdata)
                ppdata <- PrepayComp(submodel=submodel, modelVersion=modelVersion, ppdata=ppdata)
                ppdata$pred     <- ppdata[, paste(submodel, modelVersion, sep="_")]
                
                if (failCount == numFitted) { 
                   cat('Completed fitting process\n')
                   break
                }
            }    
            
        }
        
        gc() #garbage collection
        
    }
    
    cat("Initial RMSE:", rmse.new, "\n")
    cat("Final RMSE (after spline Fit):", errCutoff, "\n")
    cat("RMSE Reduction (%):", round(-1 * (errCutoff/rmse.new - 1) * 100), "\n")
    cat("Number of iterations:", iter, "\n")
    cat("Splines updated: ", splinesUpdated, "\n")
  
    if (submodel == "turn") {
      submdl.json <- json$turn.mdl
      fileName    <- paste(paste(submodel, gnmaProgram, sep="_"), "json", sep=".")
    } else if (submodel == "refi") {
        submdl.json <- json$refi.mdl
        fileName    <- paste(paste(submodel, gnmaProgram, sep="_"), "json", sep=".")
    } else if (submodel == "cout") {
        submdl.json <- json$cout.mdl
        fileName    <- paste(paste(submodel, gnmaProgram, sep="_"), "json", sep=".")
    } else if (submodel == "dfltcurr") {
        submdl.json <- json$dfltcurr.mdl
        fileName    <- paste(paste("dflt_curr", gnmaProgram, sep=""), "json", sep=".")
    } else if (submodel == "dfltdelq") {
        submdl.json <- json$dfltdelq.mdl 
        fileName    <- paste(paste("dflt_delq", gnmaProgram, sep=""), "json", sep=".")
    } else {
        # do nothing
    }
  
    jsonFile       <- paste(OutputDir, fileName, sep="/")
    mdl.json       <- jsonlite::toJSON(submdl.json, digits = 10, pretty = TRUE)
    write(mdl.json, file=jsonFile)
    
    submdlGLF.json <- SplineToGLF(submdl.json, extparamsFitted)
    # Regenerate model predictions using GLF-smoothed splines
    if (submodel == "turn") {
      json$turn.mdl <- submdlGLF.json
    } else if (submodel == "refi") {
      json$refi.mdl <- submdlGLF.json
    } else if (submodel == "cout") {
      json$cout.mdl <- submdlGLF.json
    } else if (submodel == "dfltcurr") {
      json$dfltcurr.mdl <- submdlGLF.json
    } else if (submodel == "dfltdelq") {
      json$dfltdelq.mdl <- submdlGLF.json 
    } else {
        # do nothing
    }
  
    ppdata      <- ModelProj(configData, modelVersions=c(modelVersion), json=json, ppdata=ppdata)
    ppdata      <- PrepayComp(submodel=submodel, modelVersion=modelVersion, ppdata=ppdata)
    ppdata$pred <- ppdata[, paste(submodel, modelVersion, sep="_")]
    wt          <- ppdata$bal/sum(ppdata$bal)
    rmse.glf    <- ModelErrorStats(actual = ppdata$ppr, pred = ppdata$pred, weights = wt)$rmse
  
    cat("Initial RMSE:", rmse.new, "\n")
    cat("Final RMSE (after GLF Fit):", rmse.glf, "\n")
    cat("RMSE Change (%):", round((rmse.glf/rmse.new - 1) * 100), "\n")
    
    jsonFileGLF       <- paste0(jsonFile, "GLF", sep=".")
    mdlGLF.json       <- jsonlite::toJSON(submdlGLF.json, digits = 10, pretty = TRUE)
    write(mdlGLF.json, file=jsonFileGLF)
    
    return(list("Spl" = submdl.json, "GLF" = submdlGLF.json))    
} 