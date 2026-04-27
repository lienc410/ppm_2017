## Read in collateral data and construct a "model" estimate for prepayment smm for each loan/pool/repline
##
## Inputs: loan/pool/repline data (must contain wala, cltv, and fico)
## Outputs: model estimates of smm for each loan/pool/repline
rm(list = ls())
gc()

require(data.table)
require(lubridate)
require(jsonlite)
require(dplyr)

sourceDir <- function(path, trace = TRUE, ...) {
  for (nm in list.files(path, pattern = "[.][Rr]$")) {
    if(trace) cat(nm,":")
    source(file.path(path, nm), ...)
    if(trace) cat("\n")
  }
}

setwd("H:/AgencyPrepayment/Baton2/batonutil")
sourceDir("R")


kJSONDir         <- c("../JSON/gnma30")
kNewModelVersion <- c("v4.61")

usage <- function() {
  print("Please pass model version [2.00, 2.10, 2.11...'], model type [CONVENTIONAL, GINNIE], input file ['sample_file.csv'], input path ['C:/...'], output path ['C:/...']")
}

# Interacitve Args
root.path     <- "./"
model.version <- paste0("GNMandolin_", kNewModelVersion)
model.type    <- "GINNIE"
input.file    <- "PrepayLoanData_freddie_sample.csv"
input.path    <- "H:/tempExtract/PrepayLoanData/CONVENTIONAL/Model_4.20/20180801/model_input"
output.path   <- "H:/tempExtract/PrepayLoanData/CONVENTIONAL/Model_4.20/20180801/model_output"


# Batch Arg Parsing
if(!is.na(commandArgs()[7])) {
  if (!is.na(commandArgs()[8])) {
    kNewModelVersion <- gsub("--","",commandArgs()[8])
    kNewModelVersion <- paste0("v",kNewModelVersion)
    cat("Model.version: ", kNewModelVersion,  "\n")
  } else {
    usage()
    stop()
  }
  
  if (!is.na(commandArgs()[9])) {
    model.type <- gsub("--","",commandArgs()[9])
  } else {
    usage()
    stop()
  }
  
  if (!is.na(commandArgs()[10])) {
    input.file <- gsub("--","",commandArgs()[10])
  } else {
    usage()
    stop()
  }
  
  if (!is.na(commandArgs()[11])) {
    input.path <- gsub("--","",commandArgs()[11])
  } else {
    usage()
    stop()
  }
  
  if (!is.na(commandArgs()[12])) {
    output.path <- gsub("--","",commandArgs()[12])
  } else {
    usage()
    stop()
  }
}


# Set Runtime variables
output.file <- gsub(".csv", ".out", input.file)
data.input  <- paste(input.path, input.file, sep="/")
data.output <- paste(output.path, output.file, sep="/")

# print to log file
cat("input.file: ", input.file,  "\n")
cat("output.file",  output.file, "\n")
cat("data.input",   data.input,  "\n")
cat("data.output",  data.output, "\n")

if(model.type == "CONVENTIONAL"){
  coll = "conv30"
  model.version <- paste0("Baton_", kNewModelVersion)
} else if ( model.type == "GINNIE"){
  coll = "gnma30"
  model.version <- paste0("GNMandolin_", kNewModelVersion)
}

# Start the Clock
ptm <- proc.time()


# Read in GNMA Model
GNMA_MODEL     <- paste(model.version, "_PIHnRHS.json", sep = "")
gnma.mdl       <- fromJSON(paste(kJSONDir, kNewModelVersion, GNMA_MODEL, sep = "/"))

fha_curt.mdl        <- gnma.mdl$FHA$CurtailmentSubModel
fha_dfltD0.mdl    <- gnma.mdl$FHA$DefaultSubModelCurr
fha_dfltD30.mdl     <- gnma.mdl$FHA$DefaultSubModelD30
fha_dfltD60.mdl     <- gnma.mdl$FHA$DefaultSubModelD60
fha_dfltD90.mdl     <- gnma.mdl$FHA$DefaultSubModelD90
fha_dfltBuyout.mdl  <- gnma.mdl$FHA$BuyoutSubModel
fha_turn.mdl        <- gnma.mdl$FHA$TurnoverSubModel
fha_cout.mdl        <- gnma.mdl$FHA$CashoutSubModel
fha_refi.mdl        <- gnma.mdl$FHA$RefinanceSubModel
fha_credcur.mdl     <- gnma.mdl$FHA$CreditCuringSubModel

pih_curt.mdl        <- gnma.mdl$PIH$CurtailmentSubModel
pih_dfltD0.mdl      <- gnma.mdl$PIH$DefaultSubModelCurr
pih_dfltD30.mdl     <- gnma.mdl$PIH$DefaultSubModelD30
pih_dfltD60.mdl     <- gnma.mdl$PIH$DefaultSubModelD60
pih_dfltD90.mdl     <- gnma.mdl$PIH$DefaultSubModelD90
pih_dfltBuyout.mdl  <- gnma.mdl$PIH$BuyoutSubModel
pih_turn.mdl        <- gnma.mdl$PIH$TurnoverSubModel
pih_cout.mdl        <- gnma.mdl$PIH$CashoutSubModel
pih_refi.mdl        <- gnma.mdl$PIH$RefinanceSubModel
pih_credcur.mdl     <- gnma.mdl$PIH$CreditCuringSubModel

rhs_curt.mdl        <- gnma.mdl$RHS$CurtailmentSubModel
rhs_dfltD0.mdl      <- gnma.mdl$RHS$DefaultSubModelCurr
rhs_dfltD30.mdl     <- gnma.mdl$RHS$DefaultSubModelD30
rhs_dfltD60.mdl     <- gnma.mdl$RHS$DefaultSubModelD60
rhs_dfltD90.mdl     <- gnma.mdl$RHS$DefaultSubModelD90
rhs_dfltBuyout.mdl  <- gnma.mdl$RHS$BuyoutSubModel
rhs_turn.mdl        <- gnma.mdl$RHS$TurnoverSubModel
rhs_cout.mdl        <- gnma.mdl$RHS$CashoutSubModel
rhs_refi.mdl        <- gnma.mdl$RHS$RefinanceSubModel
rhs_credcur.mdl     <- gnma.mdl$RHS$CreditCuringSubModel

# Read in loan/pool/repline data
cat("input data: Start",  "\n")
ppdata          <- fread(data.input, sep="|", header=FALSE, stringsAsFactors = FALSE, colClasses=(list(character=1)))
names(ppdata)   <- c("loanseqnum","asOf","monthBucket","loanType","bal","pct_dq","incentive","refinance_incentive"
                     ,"burnout","wala","wacls","acls","cltv","fico","hpa2yr","hpa_annual","hpa_cum","cai","media_effect","pct_tpo",
                     "pct_BROKER","pct_CORRES","pct_NonRETAIL","pct_RETAIL_CashWindow","pct_RETAIL_NonCashWindow","pct_purchase","HARP_eligible",
                     "refi_elig_pct","pct_second_lien","pct_HARPed","wam","oltv","day_count","pct_preHARP","pct_NY","pct_refi_co","pct_refi_nco",
                     "pct_hmod","pct_nhmod","pct_rp","monthsSinceIssued","pct_TX","delq_flag","monthsSince", "delMonths","reperformingStatus",
                     "walaAtStatus","sato","dti","laggedUnemployChangeSinceStatus","cumHPI","buyoutIncentive","servicerBuyoutIndex","ftaIncentive","prepayMonth","NACol")
ppdata                    <- data.frame(ppdata)

if (all(ppdata$loanType == 'FHA')) {
  cat("Using FHA Model", "\n")
  curt.mdl        <- fha_curt.mdl
  dfltD0.mdl      <- fha_dfltD0.mdl
  dfltD30.mdl     <- fha_dfltD30.mdl
  dfltD60.mdl     <- fha_dfltD60.mdl
  dfltD90.mdl     <- fha_dfltD90.mdl
  dfltBuyout.mdl  <- fha_dfltBuyout.mdl
  turn.mdl        <- fha_turn.mdl
  cout.mdl        <- fha_cout.mdl
  refi.mdl        <- fha_refi.mdl
  credcur.mdl     <- fha_credcur.mdl 
}
if (all(ppdata$loanType == 'VA')){
  cat("Using VA Model", "\n")
  curt.mdl        <- va_curt.mdl
  dfltD0.mdl      <- va_dfltD0.mdl
  dfltD30.mdl     <- va_dfltD30.mdl
  dfltD60.mdl     <- va_dfltD60.mdl
  dfltD90.mdl     <- va_dfltD90.mdl
  turn.mdl        <- va_turn.mdl
  cout.mdl        <- va_cout.mdl
  refi.mdl        <- va_refi.mdl
  credcur.mdl     <- va_credcur.mdl
}

if (all(ppdata$loanType == 'PIH')){
  cat("Using PIH Model", "\n")
  curt.mdl        <- pih_curt.mdl
  dfltD0.mdl      <- pih_dfltD0.mdl
  dfltD30.mdl     <- pih_dfltD30.mdl
  dfltD60.mdl     <- pih_dfltD60.mdl
  dfltD90.mdl     <- pih_dfltD90.mdl
  dfltBuyout.mdl  <- pih_dfltBuyout.mdl
  turn.mdl        <- pih_turn.mdl
  cout.mdl        <- pih_cout.mdl
  refi.mdl        <- pih_refi.mdl
  credcur.mdl     <- pih_credcur.mdl
}

if (all(ppdata$loanType == 'RHS')){
  cat("Using RHS Model", "\n")
  curt.mdl        <- rhs_curt.mdl    
  dfltD0.mdl      <- rhs_dfltD0.mdl
  dfltD30.mdl     <- rhs_dfltD30.mdl
  dfltD60.mdl     <- rhs_dfltD60.mdl
  dfltD90.mdl     <- rhs_dfltD90.mdl
  dfltBuyout.mdl  <- rhs_dfltBuyout.mdl    
  turn.mdl        <- rhs_turn.mdl
  cout.mdl        <- rhs_cout.mdl
  refi.mdl        <- rhs_refi.mdl
  credcur.mdl     <- rhs_credcur.mdl    
}
# calculate media_effect and burnout and hpa_interp and wala_interp multiplier
#1
pre_list_turnover  <- c("hpa_interp") 

preparation_tover <-  names(turn.mdl)[match(pre_list_turnover, names(turn.mdl))]

preparation_tover.df <- data.frame(matrix(nrow = nrow(ppdata), ncol = length(preparation_tover))) 

names(preparation_tover.df) <- pre_list_turnover

ppdata$hpa_interp       <- ppdata$hpa_annual

for (p in preparation_tover) {
  if(!(p %in% names(ppdata))) {
    preparation_tover.df[, p] <- 1.0
    cat("ATTENTION!Missing hpa interpolation in INPUT!", " missing: ", p, "\n")
  }
  else {
    idx <- match(p, names(turn.mdl))
    a <- unlist(turn.mdl[idx][[1]][1])  
    b <- unlist(turn.mdl[idx][[1]][2])
    x <- ppdata[, p]
    preparation_tover.df[, p] <- BuildSpline(a = a, b = b, x = x)$y
  }
}

preparation_tover.df  <- data.frame(preparation_tover.df) 
names(preparation_tover.df)   <- pre_list_turnover

ppdata$hpa_interpolation         <-   preparation_tover.df$hpa_interp
#2
pre_list_cashout  <- c("wala_interp") 

preparation_cashout <-  names(cout.mdl)[match(pre_list_cashout, names(cout.mdl))]

preparation_cout.df <- data.frame(matrix(nrow = nrow(ppdata), ncol = length(preparation_cashout))) 
names(preparation_cout.df) <- pre_list_cashout

ppdata$wala_interp       <- ppdata$wala

for (p in preparation_cashout) {
  if(!(p %in% names(ppdata))) {
    preparation_cout.df[, p] <- 1.0
    cat("ATTENTION!Missing wala interpolation in INPUT!", " missing: ", p, "\n")
  }
  else {
    idx <- match(p, names(cout.mdl))
    cat("test", p, "\n")
    a <- unlist(cout.mdl[idx][[1]][1])  
    b <- unlist(cout.mdl[idx][[1]][2])
    x <- ppdata[, p]
    preparation_cout.df[, p] <- BuildSpline(a = a, b = b, x = x)$y
  }
}
preparation_cout.df  <- data.frame(preparation_cout.df) 
names(preparation_cout.df)   <- pre_list_cashout

ppdata$wala_interpolation           <-   preparation_cout.df$wala_interp
ppdata$wala_interpolation_int       <- floor(preparation_cout.df$wala_interp)
ppdata$wala_interpolation_dec       <- ppdata$wala_interpolation - ppdata$wala_interpolation_int
#3
pre_list_refinance  <- c("media_effect", "burnout") 

preparation <-  names(refi.mdl)[match(pre_list_refinance, names(refi.mdl))]

preparation.df <- data.frame(matrix(nrow = nrow(ppdata), ncol = length(preparation))) 

names(preparation.df) <- pre_list_refinance

for (p in preparation) {
  if(!(p %in% names(ppdata))) {
    preparation.df[, p] <- 1.0
    cat("ATTENTION!Missing Media Effect or Burnout in INPUT!", " missing: ", p, "\n")
  }
  else {
    idx <- match(p, names(refi.mdl))
    a <- unlist(refi.mdl[idx][[1]][1])  
    b <- unlist(refi.mdl[idx][[1]][2])
    x <- ppdata[, p]
    preparation.df[, p] <- BuildSpline(a = a, b = b, x = x)$y
  }
}

preparation.df  <- data.frame(preparation.df) 
names(preparation.df)   <- pre_list_refinance

ppdata$media_effect_interpolation  <- preparation.df$media_effect
ppdata$media_effect_interpolation_int  <- floor(preparation.df$media_effect)
ppdata$media_effect_interpolation_dec  <- ppdata$media_effect_interpolation - ppdata$media_effect_interpolation_int

ppdata$burnout_interpolation  <- preparation.df$burnout
ppdata$burnout_interpolation_int  <- floor(preparation.df$burnout)
ppdata$burnout_interpolation_dec  <- ppdata$burnout_interpolation - ppdata$burnout_interpolation_int

# incentive elbow shift for refinance submodel

ppdata$elbow_wacls_0     <- ppdata$wacls
ppdata$elbow_wacls_1     <- ppdata$wacls
ppdata$elbow_wacls_2     <- ppdata$wacls

elbow_submdl  <- refi.mdl$elbow_wacls$functions

names(elbow_submdl)   <- c("elbow_wacls_0","elbow_wacls_1","elbow_wacls_2")

elbow_list_refinance  <- c("elbow_wacls_0","elbow_wacls_1","elbow_wacls_2")

elbow_mult.df <- data.frame(matrix(nrow = nrow(ppdata), ncol = length(elbow_list_refinance)))
names(elbow_mult.df) <- elbow_list_refinance

for (p in names(elbow_submdl)) {
  if(!(p %in% names(ppdata))) {
    elbow_mult.df[, p] <- 1.0
    cat("ATTENTION!Missing elbow shift in INPUT!", " missing: ", p, "\n")
  }
  else {
    idx <- match(p, names(elbow_submdl))
    a <- unlist(elbow_submdl[idx][[1]][1]) 
    b <- unlist(elbow_submdl[idx][[1]][2])
    x <- ppdata[, p]
    elbow_mult.df[, p] <- BuildSpline(a = a, b = b, x = x)$y
  }
}

elbow_mult.df  <- data.frame(elbow_mult.df) 

ppdata$incentive_adj_0  <- elbow_mult.df$elbow_wacls_0

ppdata$incentive_adj_1  <- elbow_mult.df$elbow_wacls_1

ppdata$incentive_adj_2  <- elbow_mult.df$elbow_wacls_2


ppdata$incentive.store    <- ppdata$incentive

ppdata$incentive_0  <- ppdata$refinance_incentive + ppdata$incentive_adj_0
ppdata$incentive_1  <- ppdata$refinance_incentive + ppdata$incentive_adj_1
ppdata$incentive_2  <- ppdata$refinance_incentive + ppdata$incentive_adj_2

ppdata$first_incentive_burnout0  <- ppdata$incentive_0
ppdata$first_incentive_burnout1  <- ppdata$incentive_0
ppdata$first_incentive_burnout2  <- ppdata$incentive_0
ppdata$first_incentive_burnout3  <- ppdata$incentive_0
ppdata$first_incentive_burnout4  <- ppdata$incentive_0
ppdata$first_incentive_burnout5  <- ppdata$incentive_0
ppdata$first_incentive_burnout6  <- ppdata$incentive_0
ppdata$first_incentive_burnout7  <- ppdata$incentive_0
ppdata$first_incentive_burnout8  <- ppdata$incentive_0
ppdata$first_incentive_burnout9  <- ppdata$incentive_0
ppdata$first_incentive_burnout10 <- ppdata$incentive_0
ppdata$first_incentive_burnout11 <- ppdata$incentive_0

ppdata$second_incentive_burnout0  <- ppdata$incentive_1
ppdata$second_incentive_burnout1  <- ppdata$incentive_1
ppdata$second_incentive_burnout2  <- ppdata$incentive_1
ppdata$second_incentive_burnout3  <- ppdata$incentive_1
ppdata$second_incentive_burnout4  <- ppdata$incentive_1
ppdata$second_incentive_burnout5  <- ppdata$incentive_1
ppdata$second_incentive_burnout6  <- ppdata$incentive_1
ppdata$second_incentive_burnout7  <- ppdata$incentive_1
ppdata$second_incentive_burnout8  <- ppdata$incentive_1
ppdata$second_incentive_burnout9  <- ppdata$incentive_1
ppdata$second_incentive_burnout10 <- ppdata$incentive_1
ppdata$second_incentive_burnout11 <- ppdata$incentive_1

ppdata$third_incentive_burnout0  <- ppdata$incentive_2
ppdata$third_incentive_burnout1  <- ppdata$incentive_2
ppdata$third_incentive_burnout2  <- ppdata$incentive_2
ppdata$third_incentive_burnout3  <- ppdata$incentive_2
ppdata$third_incentive_burnout4  <- ppdata$incentive_2
ppdata$third_incentive_burnout5  <- ppdata$incentive_2
ppdata$third_incentive_burnout6  <- ppdata$incentive_2
ppdata$third_incentive_burnout7  <- ppdata$incentive_2
ppdata$third_incentive_burnout8  <- ppdata$incentive_2
ppdata$third_incentive_burnout9  <- ppdata$incentive_2
ppdata$third_incentive_burnout10 <- ppdata$incentive_2
ppdata$third_incentive_burnout11 <- ppdata$incentive_2

ppdata$purch_incentive_0      <- ppdata$incentive
ppdata$purch_incentive_1      <- ppdata$incentive
ppdata$purch_incentive_2      <- ppdata$incentive
ppdata$purch_incentive_3      <- ppdata$incentive
ppdata$refi_co_incentive_0      <- ppdata$incentive
ppdata$refi_co_incentive_1      <- ppdata$incentive
ppdata$refi_co_incentive_2      <- ppdata$incentive
ppdata$refi_co_incentive_3      <- ppdata$incentive
ppdata$refi_nco_incentive_0      <- ppdata$incentive
ppdata$refi_nco_incentive_1      <- ppdata$incentive
ppdata$refi_nco_incentive_2      <- ppdata$incentive
ppdata$refi_nco_incentive_3      <- ppdata$incentive

ppdata$NACol			  <- NULL

ppdata$fico_0     <- ppdata$fico
ppdata$fico_1     <- ppdata$fico
ppdata$fico_2     <- ppdata$fico

ppdata$low_fico_adjustment     <- ppdata$fico

ppdata$wala1              <- ppdata$wala
ppdata$wala2              <- ppdata$wala

ppdata$purch_lohpa_wala              <- ppdata$wala
ppdata$purch_hihpa_wala              <- ppdata$wala
ppdata$refi_lohpa_wala               <- ppdata$wala
ppdata$refi_hihpa_wala               <- ppdata$wala

ppdata$HMOD_monthsSinceIssued         <-ppdata$monthsSinceIssued
ppdata$NHMOD_monthsSinceIssued        <-ppdata$monthsSinceIssued
ppdata$RP_monthsSinceIssued           <-ppdata$monthsSinceIssued

ppdata$fico1              <- ppdata$fico
ppdata$fico2              <- ppdata$fico

ppdata$fico_acls_interact_1_acls     <- ppdata$acls
ppdata$fico_acls_interact_2_fico     <- ppdata$fico

ppdata$NY_acls      <- ppdata$acls
ppdata$NY_wacls     <- ppdata$wacls
ppdata$TX_wacls     <- ppdata$wacls

ppdata$tax                <- 20200101

ppdata$bizDayCntBase      <- 20.91
ppdata$bizDatCntAdj       <- ppdata$day_count / ppdata$bizDayCntBase

cat("input data: Done",  "\n")

cat("Cleaning data: Start",  "\n")
ppdata <- na.omit(ppdata)
cat("Cleaning data: Done",  "\n")


# # Calculate prepayment results
# cat("Calculate Curtailment: Start",  "\n")
# ppdata$curt       <- PredictSubmodel_4_60_interpolation(coll=coll, submodel="curt", submdl.spl=curt.mdl, data=ppdata, seasadj=TRUE, version=kNewModelVersion)$pred
# ppdata$curt       <- ppdata$curt * ppdata$delq_flag
# cat("Calculate Curtailment: Done",  "\n")

# Use unadjusted incentive for default predictions
cat("Calculate Default: Start",  "\n")
# ppdata$incentive  <- ppdata$incentive.store  
ppdata$dfltall    <- PredictDflt_1(dfltD0.mdl, dfltD30.mdl, dfltD60.mdl, dfltD90.mdl, dfltBuyout.mdl, ppdata, kNewModelVersion)$pred_all
ppdata$dfltTransit    <- PredictDflt_1(dfltD0.mdl, dfltD30.mdl, dfltD60.mdl, dfltD90.mdl, dfltBuyout.mdl, ppdata, kNewModelVersion)$pred_transit
ppdata$dfltBuyout    <- PredictDflt_1(dfltD0.mdl, dfltD30.mdl, dfltD60.mdl, dfltD90.mdl, dfltBuyout.mdl, ppdata, kNewModelVersion)$pred_buyout
# cat("Default SMM set to NULL!!", "\n")
cat("Calculate Default: Done", "\n")


# # Use unadjusted incentive for OTM Cashout-refis
# cat("Calculate Cashout: Start", "\n")
# ppdata$purch_incentive      <- ppdata$incentive.store
# ppdata$refi_co_incentive    <- ppdata$incentive.store
# ppdata$refi_nco_incentive   <- ppdata$incentive.store
# ppdata$hmod_incentive       <- ppdata$incentive.store
# ppdata$nhmod_incentive      <- ppdata$incentive.store
# ppdata$rp_incentive         <- ppdata$incentive.store
# ppdata$cout                 <- PredictSubmodel_4_60_interpolation(coll=coll, submodel="cout", submdl.spl=cout.mdl, data=ppdata, seasadj=TRUE, version=kNewModelVersion)$pred * ppdata$bizDatCntAdj
# ppdata$cout                 <- ppdata$cout * ppdata$delq_flag
# cat("Calculate Cashout: Done", "\n")
# 
# # Use unadjusted incentive for turnover predictions
# cat("Calculate Turnover: Start", "\n")
# ppdata$purch_incentive      <- ppdata$incentive.store
# ppdata$refi_co_incentive    <- ppdata$incentive.store
# ppdata$refi_nco_incentive   <- ppdata$incentive.store
# ppdata$hmod_incentive       <- ppdata$incentive.store
# ppdata$nhmod_incentive      <- ppdata$incentive.store
# ppdata$rp_incentive         <- ppdata$incentive.store
# ppdata$turn                 <- PredictSubmodel_4_60_interpolation(coll=coll, submodel="turn", submdl.spl=turn.mdl, data=ppdata, seasadj=TRUE, version=kNewModelVersion)$pred * ppdata$bizDatCntAdj
# ppdata$turn                 <- ppdata$turn * ppdata$delq_flag
# cat("Calculate Turnover: Done", "\n")
# 
# # Use adjusted incentive to refi predictions
# cat("Calculate Refinance: Start",  "\n")
# ppdata$refi       <- PredictSubmodel_4_60_interpolation(coll=coll, submodel="refi", submdl.spl=refi.mdl, data=ppdata, seasadj=TRUE, version=kNewModelVersion)$pred * ppdata$bizDatCntAdj
# ppdata$refi       <- ppdata$refi * ppdata$delq_flag
# cat("Calculate Refinance: Done",  "\n")
# 
# # Use adjusted incentive to credit curing predictions
# cat("Calculate Credit Curing: Start",  "\n")
# ppdata$purch_incentive          <- ppdata$refinance_incentive
# ppdata$refi_co_incentive        <- ppdata$refinance_incentive
# ppdata$refi_nco_incentive       <- ppdata$refinance_incentive
# ppdata$hmod_incentive           <- ppdata$refinance_incentive
# ppdata$nhmod_incentive          <- ppdata$refinance_incentive
# ppdata$rp_incentive             <- ppdata$refinance_incentive
# ppdata$credit_curing            <- PredictSubmodel_4_60_interpolation(coll=coll, submodel="cc", submdl.spl=credcur.mdl, data=ppdata, seasadj=TRUE, version=kNewModelVersion)$pred * ppdata$bizDatCntAdj
# ppdata$credit_curing            <- ppdata$credit_curing * ppdata$delq_flag
# cat("Calculate Credit Curing: Done",  "\n")

#cat("Calculate Model SMM: Start",  "\n")

# ppdata$modelSMM   <- ppdata$curt + ppdata$dfltall + ppdata$cout + ppdata$turn + ppdata$refi + ppdata$credit_curing
ppdata$modelSMM   <- NULL
cat("CPR SMM set to NULL!!", "\n")
# cat("Calculate Model SMM: Done",  "\n")

# shift by one month, show as factor date
ppdata$asOf       <- as.Date(ppdata$asOf, '%Y-%m-%d')
ppdata$asOf       <- ppdata$asOf + months(1)

# change date format to yyyymmdd
ppdata$asOf       <- format(ppdata$asOf, format = "%Y%m%d")
# turn_test       <- PredictSubmodel_4_60_interpolation(coll=coll, submodel="turn", submdl.spl=turn.mdl, data=ppdata, seasadj=TRUE, version=kNewModelVersion)$mult
# refi_test       <- PredictSubmodel_4_60_interpolation(coll=coll, submodel="refi", submdl.spl=refi.mdl, data=ppdata, seasadj=TRUE, version=kNewModelVersion)$mult

# Create the output data
# smm.df.csv <- paste(raw.data$issueId, raw.data$asOf, raw.data$curt.mdl, raw.data$dflt.mdl, raw.data$turn.mdl, raw.data$refi.mdl,"\x0d\x0a", sep = "|")
cat("Storing Results: Start",  "\n")
#smm.df.csv    <- data.frame(paste(ppdata$loanseqnum, ppdata$asOf, ppdata$curt, ppdata$dfltall, ppdata$turn, ppdata$cout, ppdata$refi, ppdata$credi_curing, ppdata$modelSMM, names(turn_test), turn_test, "",sep = "|"))
#smm.df.csv    <- data.frame(paste(ppdata$loanseqnum, ppdata$asOf, ppdata$curt, ppdata$dfltall, ppdata$dfltTransit, ppdata$dfltBuyout, ppdata$turn, ppdata$cout, ppdata$refi, ppdata$credit_curing, ppdata$modelSMM, "",sep = "|"))
smm.df.csv    <- data.frame(paste(ppdata$loanseqnum, ppdata$asOf, ppdata$dfltall, ppdata$dfltTransit, ppdata$dfltBuyout, ppdata$modelSMM, "",sep = "|"))

#write.csv(smm.df.csv, data.output, row.names = F, col.names = F, quote = F)
fwrite(smm.df.csv, data.output, row.names = F, col.names = F, qmethod = "escape")

cat("Storing Results: Done",  "\n")

