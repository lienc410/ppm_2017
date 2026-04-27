#' @title Visualize prepayment data: Actual and Projected 
#' 
#' @description
#'   \code{visualizr} tracks prepayment behavior versus various attributes
#'  
#' @param coll  collateral being modeled (\code{"conv30"} or \code{"gnma30"})
#' @param ticker ticker for collateral  (\code{"FGLMC"}, \code{"FGT6"}, \code{"FGU6"}, \code{"FGU9"})
#' @param submodel prepayment component we want dataset for (\code{"dflt"}, \code{"dfltcurr"}, \code{"dfltdelq"}, 
#' \code{"refi"}, \code{"turn"}, \code{"all"})
#' @param aggType how the prepayment data is aggregated (\code{"RschGrid"} or \code{"SpecPool"})
#' 
#' @return 
#' Prepayment data frame
#' 
#' @examples
#'  trackr(coll="conv30", submodel="refi", gnmaProgram="FHA", aggType="RschGrid")
#'  
#' @export
visualizr <- function(configData, ppdata) {
  
  coll        <- configData$FitParam$coll
  submodel    <- configData$FitParam$submodel
  gnmaProgram <- configData$FitParam$gnmaProgram
  aggType     <- configData$FitParam$aggType
  bucketSize  <- configData$FitParam$bucketSize
  OutputDir   <- configData$Directory$Output
  
  
  kPlotFile <- paste(paste0(coll, submodel, gnmaProgram, "AggPlot"), "_", 
                     format(Sys.time(),'%d_%m_%H_%M'), ".pdf", sep="")
  kPlotFile <- paste(OutputDir, kPlotFile, sep="/")
  
  # Create plots that track various columns in the prepayment data set by asofdate.
  if (coll == "gnma30") {
    paramsNotFitted <- c("asOf", "year", "month", "day", "marketTicker", "loanType", "monthsSince", "bal", "mdr", 
                         "asofdate", "monthBucket", "lomedia_incentive", "himedia_incentive", "wt")
  }
  else {
    paramsNotFitted <- c("asOf", "year", "month", "day", "marketTicker", "monthsSince", "bal", 
                         "asofdate", "monthBucket", "lomedia_incentive", "himedia_incentive")
  }
  
  paramsPlotted   <- colnames(ppdata)[-match(paramsNotFitted, colnames(ppdata))]
  
  numPlots <- length(paramsPlotted)
  plot.list <- vector(mode="list", numPlots)
  
  plotCtr <- 1
  
  for (i in 1:numPlots) {
    y.col <- paramsPlotted[i]
    x.col <- "asofdate"
    cat("Plotting: ", y.col, "\n")
    agg <- aggregatr(data=ppdata, x.col=x.col, y.col=y.col, bucketSize=bucketSize)
    
    plotData <- data.frame(x=agg$aggX, y=agg$aggY)
    plot(plotData, type='l', col = 'green', 
         main=paste(coll, gnmaProgram, submodel, y.col),
         xlab=x.col, ylab=y.col)
    
    plot.list[[plotCtr]] <- recordPlot()
    plotCtr <- plotCtr + 1
  }
  
  graphics.off()
  pdf(kPlotFile, onefile=TRUE)
  for (j in 1:(plotCtr-1)) {
    replayPlot(plot.list[[j]])
  }
  graphics.off()
}
  