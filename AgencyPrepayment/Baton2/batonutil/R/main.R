# Workflow for typical prepayment modeling session. 

main <- function() {
  
  # Step 0: Read in JSON with configuration values. 
  configData <- jsonlite::fromJSON(config())
  
  coll        <- configData$FitParam$coll
  submodel    <- configData$FitParam$submodel
  gnmaProgram <- configData$FitParam$gnmaProgram
  aggType     <- configData$FitParam$aggType
  
  cat("Collateral=", coll, "Submodel=", submodel, "GNMA Program=", gnmaProgram,  "aggType=", aggType, "\n")

  if (aggType == "RschGrid") {
    ppdataFile <- configData$Datafiles$RschGrid
  } else {
    ppdataFile <- configData$Datafiles$SpecPool
  }
  
  # Step 1: Import prepayment data into R from flat file
  ppdata.imp <- imprtr(infile=ppdataFile)
  
  # Step 2: Tidy R data (see source file for definition of 'tidy')
  ppdata.td <- tidyr(coll=coll, submodel = submodel, ppdata=ppdata.imp)
   
  # Step 3: Transform R data (add any new columns if necessary); filter data if necessary
  ppdata.tf <- tfrmr(configData=configData, ppdata=ppdata.td)
  
  # Step 4: Filter data and track prepayment model on various aggregations of this data set
  ppdata.sub <- ppdata.tf %>% dplyr::filter((ppdata.tf$bal >  configData$FitParam$minBal))
  #ppdata.sub$refi_elig_pct <- rep(100, nrow(ppdata.sub))
  #ppdata.sub$pct_tpo       <- rep(40, nrow(ppdata.sub))
  # ppdata.sub <- ppdata.sub %>% dplyr::filter((ppdata.sub$asofdate > as.Date(c("2009-06-01"))))
  #ppdata.sub <- ppdata.sub %>% dplyr::filter((ppdata.sub$media_effect < 30.0))
  #ppdata.sub <- ppdata.sub %>% dplyr::filter((ppdata.sub$wala > 0) & (ppdata.sub$wala < 60))
  # ppdata.sub  <- ppdata.sub %>% dplyr::filter(ppdata.sub$marketTicker == "FGLMC")
  #ppdata.sub <- ppdata.sub %>% dplyr::filter(ppdata.sub$asofdate > as.Date(c("2017-01-01")))
  #ppdata.sub <- ppdata.sub %>% dplyr::filter(ppdata.sub$incentive.store < 150)
  #ppdata.sub <- ppdata.sub %>% dplyr::filter(ppdata.sub$pct_dq > 0.1)
  # ppdata.sub  <- ppdata.sub[1:100,]
  # ppdata.sub <- subset(ppdata.sub, incentive <= -25)
  # ppdata.sub <- subset(ppdata.sub, wacls > 175)
  # ppdata.sub <- subset(ppdata.sub, highOLTV == 0)
  # ppdata.sub <- subset(ppdata.sub, wala >= 48)
  # ppdata.sub <- subset(ppdata.sub, acls > 0)
  
  # ticker=""
  # ppdata=ppdata.sub
  # 
  # ppdata.fin <- trackr(configData=configData, ticker="", ppdata=ppdata.sub)
  ppdata <- trackr(configData=configData, ticker="", ppdata=ppdata.sub)
  
  # Step 5: Estimate submodel (This step is optional. Can rely on Step 3 for a more iterative & visual fitting process.)
  # This step produces a json file that can be inspected and copied into the appropriate folder.
  extparamsFitted <- c("cltv", "wala")
  submdl <- estimatr(configData=configData, extparamsFitted=extparamsFitted, ppdata=ppdata.sub)
  
  # Step 6. Visualize time-series of different variables used in the model
  visualizr(configData=configData, ppdata=ppdata.fin)
   
  #if (coll == "conv30") {
  #  tickers <- c(unique(ppdata.sub$marketTicker), "preHARP", "postHARP")
  #  
  #} else {
  #    tickers <- unique(ppdata.sub$marketTicker)
  #}
  
  #for (tick in tickers) {
  #  trackr(configData=configData, ticker=tick, ppdata = ppdata.sub)
  #}
  
  
}
