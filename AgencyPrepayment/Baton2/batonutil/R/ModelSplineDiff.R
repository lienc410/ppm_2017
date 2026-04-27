#' @title Plot spline parameters side by side for different versions of a submodel of the prepayment model. 
#' 
#' @description
#' \code{ModelSplineDiff} goes through the different parameters included in a submodel and plots their 
#' corresponding splines for two separate versions.
#'  
#' @param coll  collateral type
#' @param submodel submodel of prepayment model
#' @param gnmaProgram  GNMA program (ex., FHA) to read submodel JSON files for
#' @param modelVersion1  Release number for the prepayment model
#' @param modelVersion2  Release number for the prepayment model
#' 
#' @examples
#'  ModelSplineDiff(coll="conv30", submodel="turn", modelVersion1="dev", modelVersion2="v2.41")
#'  
#' @export  
ModelSplineDiff <- function(configData) {
  
  coll        <- configData$FitParam$coll
  submodel    <- configData$FitParam$submodel
  gnmaProgram <- configData$FitParam$gnmaProgram
  OutputDir   <- configData$Directory$Output
  
  if (coll == "conv30") {
    modelVersion1 <- configData$Version$newConv30
    modelVersion2 <- configData$Version$oldConv30
  }
  else if (coll == "gnma30") {
    modelVersion1 <- configData$Version$newGNMA30
    modelVersion2 <- configData$Version$oldGNMA30
  }
  else {
    stop(paste0("Unsupported collateral type: ", coll, "\n"))
  }
  
  # Begin Constants
  fileStr <- paste("SplDiff", coll, submodel, gnmaProgram, modelVersion1, modelVersion2, sep="_")
  kSplinePlotFile <- paste(OutputDir, paste(fileStr, "_", format(Sys.time(), "%d_%m_%H_%M"), ".pdf", sep = ""), sep="/")
  # End Constants
  
  json1 <- ParseModelJSON(configData=configData, modelVersion=modelVersion1)
  json2 <- ParseModelJSON(configData=configData, modelVersion=modelVersion2)
    
  if (submodel == "turn") {
     submdl1.json  <- json1$turn.mdl
     submdl2.json  <- json2$turn.mdl
  }
  else if (submodel == "refi") {
    submdl1.json  <- json1$refi.mdl
    submdl2.json  <- json2$refi.mdl
  }
  else if (submodel == "cout") {
    submdl1.json  <- json1$cout.mdl
    submdl2.json  <- json2$cout.mdl
  }
  else if (submodel == "dfltcurr") {
    submdl1.json  <- json1$dfltcurr.mdl
    submdl2.json  <- json2$dfltcurr.mdl
  }
  else if (submodel == "dfltdelq") {
    submdl1.json  <- json1$dfltdelq.mdl
    submdl2.json  <- json2$dfltdelq.mdl
  }
  else if (submodel == "curt") {
    submdl1.json  <- json1$curt.mdl
    submdl2.json  <- json2$curt.mdl
  }
  else {
    stop(paste0("Don't know how to handle this submodel option currently", submodel, "\n"))
  }
  
  paramsNotFitted <- c("baselineConstant", "adjustmentFactor", "seasonalityMultipliers")
  varNames <- names(submdl1.json)[-match(paramsNotFitted, names(submdl1.json))]
  nVar <- length(varNames)

  plot.list <- vector(mode = "list", nVar)
  model1.list <- model2.list <- vector(mode = "list", nVar)
  names(model1.list) <- names(model2.list) <- varNames

  model1.knots.list <- model2.knots.list <- vector(mode = "list", nVar)
  names(model1.knots.list) <- names(model2.knots.list) <- varNames

  submodel1 <- submdl1.json
  submodel2 <- submdl2.json

for (i in 1:nVar) {
    cat("Building spline multiplier curve for: ", varNames[i], "\n")
    
    par(mar = c(5.1, 4.1, 4.1, 8.1), xpd = TRUE)
    
    idx <- match(varNames[i], names(submodel1))
    a <- unlist(submodel1[idx][[1]][1])  # Otherwise R complains about not being able to coerce a list into a double
    b <- unlist(submodel1[idx][[1]][2])
    a.values <- seq(from = min(a), to = max(a), length.out = 100)
    model1.knots.list[[i]] <- data.frame(x = a, y = b)
    model1.list[[i]] <- BuildSpline(a = model1.knots.list[[i]]$x, b = model1.knots.list[[i]]$y, x = a.values)
    
    idx <- match(varNames[i], names(submodel2))
    a <- unlist(submodel2[idx][[1]][1])  # Otherwise R complains about not being able to coerce a list into a double
    b <- unlist(submodel2[idx][[1]][2])
    a.values <- seq(from = min(a), to = max(a), length.out = 100)
    model2.knots.list[[i]] <- data.frame(x = a, y = b)
    model2.list[[i]] <- BuildSpline(a = model2.knots.list[[i]]$x, b = model2.knots.list[[i]]$y, x = a.values)
    
    x.min <- min(model1.knots.list[[i]]$x, model2.knots.list[[i]]$x)
    x.max <- max(model1.knots.list[[i]]$x, model2.knots.list[[i]]$x)
    y.min <- min(model1.knots.list[[i]]$y, model2.knots.list[[i]]$y)
    y.max <- max(model1.knots.list[[i]]$y, model2.knots.list[[i]]$y)
    
    plot(model1.knots.list[[i]]$x, model1.knots.list[[i]]$y, pch = 18, col = "red", 
         main = paste(coll, submodel, gnmaProgram, "Spline:", varNames[i], sep = " "), 
         xlab = varNames[i], ylab = "Multiplier", 
           xlim = c(x.min, x.max), ylim = c(y.min, y.max), lwd = 2)
    lines(model1.list[[i]]$x, model1.list[[i]]$y, lty = 1, col = "red")
    
    par(new = T)
    
    plot(model2.knots.list[[i]]$x, model2.knots.list[[i]]$y, pch = 18, col = "blue", 
         main = paste(coll, submodel, gnmaProgram, "Spline:", varNames[i], sep = " "), xlab = "", ylab = "", 
         xlim = c(x.min, x.max), ylim = c(y.min, y.max), lwd = 2)
    lines(model2.list[[i]]$x, model2.list[[i]]$y, lty = 1, col = "blue")
    
    legend(legend = c(modelVersion1, modelVersion2), lty = 1, "topright", inset = c(-0.3, 0), 
           col = c("red", "blue"), cex = 0.5)
    
    plot.list[[i]] <- recordPlot()
    
}

graphics.off()

pdf(kSplinePlotFile, onefile = TRUE)

for (j in 1:nVar) {
    cat("Building plot for: ", varNames[j], "\n")
    replayPlot(plot.list[[j]])
}

graphics.off() 

}
