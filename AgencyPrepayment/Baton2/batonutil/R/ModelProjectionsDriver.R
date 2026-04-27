#' @title Driver for generating prepayment forecasts and writing to a flat file 
#' 
#' @description
#' \code{ModelProjDriver} Generate model and submodel forecasts based on indicative data from a flat file.
#' The forecasts are written to another flat file.
#'  
#' @param inFile CSV file containing indicative data for the loans/pools/replines that we want projections for
#' @param outFile CSV file where projections will be stored
#' 
#' @examples
#'  ModelProjDriver(coll="conv30", modelVersion="v2.42", file="testdata.csv")
#'  
#' @export
#'

ModelProjDriver <- function(inFile=NA, outFile=NA) {
  
    configData <- jsonlite::fromJSON(config())
    coll        <- configData$FitParam$coll
    
    if (is.na(inFile)) {
      ppdataInFile <- configData$Datafiles$RschGrid
    } else {
      ppdataInFile <- inFile
    }
    
    cat("Input file: ", ppdataInFile, "\n")
    
    if (is.na(outFile)) {
      ppdataOutFile <- paste(configData$Directory$Output, "ppProj.csv", sep="/")
    }
    else {
      ppdataOutFile <- outFile
      
    }
    
    cat("Output file: ", ppdataOutFile, "\n")
    
    # Step 1: Import prepayment data into R from flat file
    ppdata.imp <- imprtr(infile=ppdataInFile)
    
    # Step 2: Tidy R data (see source file for definition of 'tidy')
    ppdata.td <- tidyr(coll=coll, ppdata=ppdata.imp)
    
    # Step 3: Transform R data (add any new columns if necessary); filter data if necessary
    ppdata.tf <- tfrmr(configData=configData, ppdata=ppdata.td)
    
    if (coll == "conv30") {
      modelVersion <- configData$Version$newConv30
    }
    else if (coll == "gnma30") {
      modelVersion <- configData$Version$newGNMA30
    }
    else {
      stop(paste0("Unsupported collateral type: ", coll, "\n"))
    }
   
    if (coll == "conv30") {
      ppdata <- ModelProj(configData, modelVersions=c(modelVersion), ppdata=ppdata.tf) 
    }
    else if (coll == "gnma30") {
      tmp  <- data.frame()
      for (loanProgram in c("FHA", "VA", "RHS", "PIH")) {
        sub <- ppdata.tf %>% dplyr::filter(ppdata.tf$loanType == loanProgram)
        if (nrow(sub) > 0) {
          configData$FitParam$gnmaProgram <- loanProgram
          sub <- ModelProj(configData, modelVersions=c(modelVersion), ppdata=ppdata.tf)
          tmp <- rbind(tmp, sub)
        }
      }
      ppdata <- tmp
    }
    else {
      stop(paste0("Unsupported collateral type:", coll, "\n"))
    }
     
    write.csv(ppdata, file=ppdataOutFile)
    
} 
