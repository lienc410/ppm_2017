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
kNewModelVersion <- c("v4.40")

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
GNMA_MODEL     <- paste(model.version, ".json", sep = "")
gnma.mdl       <- fromJSON(paste(kJSONDir, kNewModelVersion, GNMA_MODEL, sep = "/"))

fha_curt.mdl        <- gnma.mdl$FHA$CurtailmentSubModel
fha_dfltcurr.mdl    <- gnma.mdl$FHA$DefaultSubModelCurr
fha_dfltdelq.mdl    <- gnma.mdl$FHA$DefaultSubModelDelq
fha_turn.mdl        <- gnma.mdl$FHA$TurnoverSubModel
fha_cout.mdl        <- gnma.mdl$FHA$CashoutSubModel
fha_refi.mdl        <- gnma.mdl$FHA$RefinanceSubModel

va_curt.mdl        <- gnma.mdl$VA$CurtailmentSubModel
va_dfltcurr.mdl    <- gnma.mdl$VA$DefaultSubModelCurr
va_dfltdelq.mdl    <- gnma.mdl$VA$DefaultSubModelDelq
va_turn.mdl        <- gnma.mdl$VA$TurnoverSubModel
va_cout.mdl        <- gnma.mdl$VA$CashoutSubModel
va_refi.mdl        <- gnma.mdl$VA$RefinanceSubModel


# Read in loan/pool/repline data
cat("input data: Start",  "\n")
ppdata          <- fread(data.input, sep="|", header=FALSE, stringsAsFactors = FALSE, colClasses=(list(character=1)))
names(ppdata)   <- c("loanseqnum","asOf","monthBucket","loanType","bal","pct_dq","incentive","refinance_incentive"
                     ,"burnout","wala","wacls","acls","cltv","fico","pct_REFI","monthsSince","hpa2yr","hpa_annual","hpa_cum","cai","media_effect","pct_tpo",
                     "pct_BROKER","pct_CORRES","pct_NonRETAIL","pct_RETAIL_CashWindow","pct_RETAIL_NonCashWindow",
                     "pct_purchase","HARP_eligible","refi_elig_pct","pct_second_lien","pct_HARPed","wam","oltv","day_count","pct_preHARP","pct_NY","NACol")

ppdata                    <- data.frame(ppdata)
ppdata$incentive.store    <- ppdata$incentive
ppdata$lomedia_incentive_burnout0  <- ppdata$refinance_incentive
ppdata$lomedia_incentive_burnout500  <- ppdata$refinance_incentive
ppdata$lomedia_incentive_burnout1500  <- ppdata$refinance_incentive
ppdata$lomedia_incentive_burnout2500  <- ppdata$refinance_incentive
ppdata$lomedia_incentive_burnout3500  <- ppdata$refinance_incentive
ppdata$lomedia_incentive_burnout4500  <- ppdata$refinance_incentive
ppdata$lomedia_incentive_burnout5500  <- ppdata$refinance_incentive
ppdata$lomedia_incentive_burnout7000  <- ppdata$refinance_incentive
ppdata$lomedia_incentive_burnout8000  <- ppdata$refinance_incentive
ppdata$himedia_incentive  <- ppdata$refinance_incentive
ppdata$NACol			  <- NULL

ppdata$lohpa_wala         <- ppdata$wala
ppdata$hihpa_wala         <- ppdata$wala
ppdata$pct_hihpa_wala     <- ppdata$hpa_annual

ppdata$purch_oltv         <- ppdata$oltv
ppdata$refi_HARP_oltv     <- ppdata$oltv
ppdata$refi_NonHARP_oltv  <- ppdata$oltv

ppdata$fico_acls_interact_1_acls     <- ppdata$acls
ppdata$fico_acls_interact_2_fico     <- ppdata$fico

ppdata$preHARP_acls      <- ppdata$acls
ppdata$preHARP_wacls     <- ppdata$wacls

ppdata$NY_acls      <- ppdata$acls
ppdata$NY_wacls     <- ppdata$wacls

ppdata$nonRetail_acls      <- ppdata$acls
ppdata$nonRetail_wacls     <- ppdata$wacls

ppdata$broker_acls      <- ppdata$acls
ppdata$broker_wacls     <- ppdata$wacls

ppdata$corres_acls      <- ppdata$acls
ppdata$corres_wacls     <- ppdata$wacls

ppdata$retailCashWindow_acls      <- ppdata$acls
ppdata$retailCashWindow_wacls     <- ppdata$wacls

ppdata$retailNonCashWindow_acls      <- ppdata$acls
ppdata$retailNonCashWindow_wacls     <- ppdata$wacls

ppdata$lomedia_nonRetail_wacls     <- ppdata$wacls
ppdata$lomedia_broker_wacls     <- ppdata$wacls
ppdata$lomedia_corres_wacls     <- ppdata$wacls
ppdata$lomedia_retailCashWindow_wacls     <- ppdata$wacls
ppdata$lomedia_retailNonCashWindow_wacls     <- ppdata$wacls

ppdata$tax                <- 20200101

ppdata$bizDayCntBase      <- 20.91
ppdata$bizDatCntAdj       <- ppdata$day_count / ppdata$bizDayCntBase

cat("input data: Done",  "\n")

cat("Cleaning data: Start",  "\n")
ppdata <- na.omit(ppdata)
cat("Cleaning data: Done",  "\n")

if (all(ppdata$loanType == 'FHA')) {
    cat("Using FHA Model", "\n")
    curt.mdl        <- fha_curt.mdl
    dfltcurr.mdl    <- fha_dfltcurr.mdl
    dfltdelq.mdl    <- fha_dfltdelq.mdl
    turn.mdl        <- fha_turn.mdl
    cout.mdl        <- fha_cout.mdl
    refi.mdl        <- fha_refi.mdl
}
if (all(ppdata$loanType == 'VA')){
    cat("Using VA Model", "\n")
    curt.mdl        <- va_curt.mdl
    dfltcurr.mdl    <- va_dfltcurr.mdl
    dfltdelq.mdl    <- va_dfltdelq.mdl
    turn.mdl        <- va_turn.mdl
    cout.mdl        <- va_cout.mdl
    refi.mdl        <- va_refi.mdl
}

# Calculate prepayment results
cat("Calculate Curtailment: Start",  "\n")
ppdata$curt       <- PredictSubmodel_4_40(coll=coll, submodel="curt", submdl.spl=curt.mdl, data=ppdata, seasadj=TRUE, version=kNewModelVersion)$pred
cat("Calculate Curtailment: Done",  "\n")

# Use unadjusted incentive for default predictions
cat("Calculate Default: Start",  "\n")
ppdata$incentive  <- ppdata$incentive.store  
ppdata$dfltall    <- PredictDflt(curr.spl=dfltcurr.mdl, delq.spl=dfltdelq.mdl, data=ppdata, version=kNewModelVersion)$pred_all
cat("Calculate Default: Done", "\n")

# Use unadjusted incentive for OTM Cashout-refis
cat("Calculate Cashout: Start", "\n")
ppdata$incentive  <- ppdata$incentive.store
ppdata$cout       <- PredictSubmodel_4_40(coll=coll, submodel="cout", submdl.spl=cout.mdl, data=ppdata, seasadj=TRUE, version=kNewModelVersion)$pred * ppdata$bizDatCntAdj
cat("Calculate Cashout: Done", "\n")

# Use unadjusted incentive for turnover predictions
cat("Calculate Turnover: Start", "\n")
ppdata$incentive  <- ppdata$incentive.store  
ppdata$turn       <- PredictSubmodel_4_40(coll=coll, submodel="turn", submdl.spl=turn.mdl, data=ppdata, seasadj=TRUE, version=kNewModelVersion)$pred * ppdata$bizDatCntAdj
cat("Calculate Turnover: Done", "\n")

# Use adjusted incentive to refi predictions
cat("Calculate Refinance: Start",  "\n")
ppdata$incentive  <- ppdata$refinance_incentive
ppdata$refi       <- PredictSubmodel_4_40(coll=coll, submodel="refi", submdl.spl=refi.mdl, data=ppdata, seasadj=TRUE, version=kNewModelVersion)$pred * ppdata$bizDatCntAdj
cat("Calculate Refinance: Done",  "\n")

ppdata$modelSMM   <- ppdata$curt + ppdata$dfltall + ppdata$cout + ppdata$turn + ppdata$refi


# shift by one month, show as factor date
ppdata$asOf       <- as.Date(ppdata$asOf, '%Y-%m-%d')
ppdata$asOf       <- ppdata$asOf + months(1)

# change date format to yyyymmdd
ppdata$asOf       <- format(ppdata$asOf, format = "%Y%m%d")
# turn_test       <- PredictSubmodel_4_40(coll=coll, submodel="turn", submdl.spl=turn.mdl, data=ppdata, seasadj=TRUE, version=kNewModelVersion)$mult
# refi_test       <- PredictSubmodel_4_40(coll=coll, submodel="refi", submdl.spl=refi.mdl, data=ppdata, seasadj=TRUE, version=kNewModelVersion)$mult

# Create the output data
# smm.df.csv <- paste(raw.data$issueId, raw.data$asOf, raw.data$curt.mdl, raw.data$dflt.mdl, raw.data$turn.mdl, raw.data$refi.mdl,"\x0d\x0a", sep = "|")
cat("Storing Results: Start",  "\n")
#smm.df.csv    <- data.frame(paste(ppdata$loanseqnum, ppdata$asOf, ppdata$curt, ppdata$dfltall, ppdata$turn, ppdata$cout, ppdata$refi, ppdata$modelSMM, names(refi_test), refi_test, "",sep = "|"))
smm.df.csv    <- data.frame(paste(ppdata$loanseqnum, ppdata$asOf, ppdata$curt, ppdata$dfltall, ppdata$turn, ppdata$cout, ppdata$refi, ppdata$modelSMM, "",sep = "|"))


#write.csv(smm.df.csv, data.output, row.names = F, col.names = F, quote = F)
fwrite(smm.df.csv, data.output, row.names = F, col.names = F, qmethod = "escape")

cat("Storing Results: Done",  "\n")

