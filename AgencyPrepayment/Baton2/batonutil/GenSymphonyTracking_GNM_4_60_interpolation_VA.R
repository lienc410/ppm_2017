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
kNewModelVersion <- c("v4.62")

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
paste("using", GNMA_MODEL)
gnma.mdl       <- fromJSON(paste(kJSONDir, kNewModelVersion, GNMA_MODEL, sep = "/"))

fha_curt.mdl        <- gnma.mdl$FHA$CurtailmentSubModel
fha_dfltD0.mdl      <- gnma.mdl$FHA$DefaultSubModelCurrEarlyToLate
fha_dfltD30.mdl     <- gnma.mdl$FHA$DefaultSubModelD30EarlyToLate
fha_dfltD60.mdl     <- gnma.mdl$FHA$DefaultSubModelD60EarlyToLate
fha_dfltD90.mdl     <- gnma.mdl$FHA$DefaultSubModelD90EarlyToLate
fha_dfltCure.mdl    <- gnma.mdl$FHA$DefaultSubModelLateToEarly
fha_dfltBuyout.mdl  <- gnma.mdl$FHA$BuyoutSubModel
fha_turn.mdl        <- gnma.mdl$FHA$TurnoverSubModel
fha_cout.mdl        <- gnma.mdl$FHA$CashoutSubModel
fha_refi.mdl        <- gnma.mdl$FHA$RefinanceSubModel
fha_credcur.mdl     <- gnma.mdl$FHA$CreditCuringSubModel
fha_fta.mdl         <- gnma.mdl$FHA$FixedToARMSubModel

va_curt.mdl         <- gnma.mdl$VA$CurtailmentSubModel
va_dfltD0.mdl       <- gnma.mdl$VA$DefaultSubModelCurrEarlyToLate
va_dfltD30.mdl      <- gnma.mdl$VA$DefaultSubModelD30EarlyToLate
va_dfltD60.mdl      <- gnma.mdl$VA$DefaultSubModelD60EarlyToLate
va_dfltD90.mdl      <- gnma.mdl$VA$DefaultSubModelD90EarlyToLate
va_dfltCure.mdl     <- gnma.mdl$VA$DefaultSubModelLateToEarly
va_dfltBuyout.mdl   <- gnma.mdl$VA$BuyoutSubModel
va_turn.mdl         <- gnma.mdl$VA$TurnoverSubModel
va_cout.mdl         <- gnma.mdl$VA$CashoutSubModel
va_refi.mdl         <- gnma.mdl$VA$RefinanceSubModel
va_credcur.mdl      <- gnma.mdl$VA$CreditCuringSubModel
va_fta.mdl          <- gnma.mdl$VA$FixedToARMSubModel

pih_curt.mdl        <- gnma.mdl$PIH$CurtailmentSubModel
pih_dfltD0.mdl      <- gnma.mdl$PIH$DefaultSubModelCurrEarlyToLate
pih_dfltD30.mdl     <- gnma.mdl$PIH$DefaultSubModelD30EarlyToLate
pih_dfltD60.mdl     <- gnma.mdl$PIH$DefaultSubModelD60EarlyToLate
pih_dfltD90.mdl     <- gnma.mdl$PIH$DefaultSubModelD90EarlyToLate
pih_dfltCure.mdl    <- gnma.mdl$PIH$DefaultSubModelLateToEarly
pih_dfltBuyout.mdl  <- gnma.mdl$PIH$BuyoutSubModel
pih_turn.mdl        <- gnma.mdl$PIH$TurnoverSubModel
pih_cout.mdl        <- gnma.mdl$PIH$CashoutSubModel
pih_refi.mdl        <- gnma.mdl$PIH$RefinanceSubModel
pih_credcur.mdl     <- gnma.mdl$PIH$CreditCuringSubModel
pih_fta.mdl         <- gnma.mdl$PIH$FixedToARMSubModel

rhs_curt.mdl        <- gnma.mdl$RHS$CurtailmentSubModel
rhs_dfltD0.mdl      <- gnma.mdl$RHS$DefaultSubModelCurrEarlyToLate
rhs_dfltD30.mdl     <- gnma.mdl$RHS$DefaultSubModelD30EarlyToLate
rhs_dfltD60.mdl     <- gnma.mdl$RHS$DefaultSubModelD60EarlyToLate
rhs_dfltD90.mdl     <- gnma.mdl$RHS$DefaultSubModelD90EarlyToLate
rhs_dfltCure.mdl    <- gnma.mdl$RHS$DefaultSubModelLateToEarly
rhs_dfltBuyout.mdl  <- gnma.mdl$RHS$BuyoutSubModel
rhs_turn.mdl        <- gnma.mdl$RHS$TurnoverSubModel
rhs_cout.mdl        <- gnma.mdl$RHS$CashoutSubModel
rhs_refi.mdl        <- gnma.mdl$RHS$RefinanceSubModel
rhs_credcur.mdl     <- gnma.mdl$RHS$CreditCuringSubModel
rhs_fta.mdl         <- gnma.mdl$RHS$FixedToARMSubModel

# Read in loan/pool/repline data
cat("input data: Start",  "\n")
ppdata          <- fread(data.input, sep="|", header=FALSE, stringsAsFactors = FALSE, colClasses=(list(character=1)))
names(ppdata)   <- c("loanseqnum","asOf","monthBucket","loanType","bal","incentive","refinance_incentive","burnout","wala","wacls","acls","cltv","fico","hasFICOFlag",
                     "hpa_annual","hpa_cum","pct_broker","pct_corres","pct_retail","pct_na","cai","media_effect","pct_purchase","pct_second_lien","wam","oltv","day_count",
                     "pct_preHARP","pct_NY","pct_refi_co","pct_refi_nco", "pct_hmod","pct_nhmod","pct_rp","pct_none","monthsSinceIssued","pct_TX","delq_flag","monthsSince",
                     "delMonths","reperformingStatus","walaAtStatus","sato","dti","laggedUnemployChangeSinceStatus","cumHpi","buyoutIncentive","servicerBuyoutIndex",
                     "ftaIncentive","prepayMonth","NACol")
ppdata                    <- data.frame(ppdata)

if (all(ppdata$loanType == 'FHA')) {
  cat("Using FHA Model", "\n")
  curt.mdl        <- fha_curt.mdl
  dfltD0.mdl      <- fha_dfltD0.mdl
  dfltD30.mdl     <- fha_dfltD30.mdl
  dfltD60.mdl     <- fha_dfltD60.mdl
  dfltD90.mdl     <- fha_dfltD90.mdl
  dfltCure.mdl    <- fha_dfltCure.mdl
  dfltBuyout.mdl  <- fha_dfltBuyout.mdl
  turn.mdl        <- fha_turn.mdl
  cout.mdl        <- fha_cout.mdl
  refi.mdl        <- fha_refi.mdl
  credcur.mdl     <- fha_credcur.mdl 
  fta.mdl         <- fha_fta.mdl 
}
if (all(ppdata$loanType == 'VA')){
  cat("Using VA Model", "\n")
  curt.mdl        <- va_curt.mdl
  dfltD0.mdl      <- va_dfltD0.mdl
  dfltD30.mdl     <- va_dfltD30.mdl
  dfltD60.mdl     <- va_dfltD60.mdl
  dfltD90.mdl     <- va_dfltD90.mdl
  dfltBuyout.mdl  <- va_dfltBuyout.mdl
  dfltCure.mdl    <- va_dfltCure.mdl
  turn.mdl        <- va_turn.mdl
  cout.mdl        <- va_cout.mdl
  refi.mdl        <- va_refi.mdl
  credcur.mdl     <- va_credcur.mdl
  fta.mdl         <- va_fta.mdl 
}

if (all(ppdata$loanType == 'PIH')){
  cat("Using PIH Model", "\n")
  curt.mdl        <- pih_curt.mdl
  dfltD0.mdl      <- pih_dfltD0.mdl
  dfltD30.mdl     <- pih_dfltD30.mdl
  dfltD60.mdl     <- pih_dfltD60.mdl
  dfltD90.mdl     <- pih_dfltD90.mdl
  dfltCure.mdl    <- pih_dfltCure.mdl
  dfltBuyout.mdl  <- pih_dfltBuyout.mdl
  turn.mdl        <- pih_turn.mdl
  cout.mdl        <- pih_cout.mdl
  refi.mdl        <- pih_refi.mdl
  credcur.mdl     <- pih_credcur.mdl
  fta.mdl         <- pih_fta.mdl
}

if (all(ppdata$loanType == 'RHS')){
  cat("Using RHS Model", "\n")
  curt.mdl        <- rhs_curt.mdl    
  dfltD0.mdl      <- rhs_dfltD0.mdl
  dfltD30.mdl     <- rhs_dfltD30.mdl
  dfltD60.mdl     <- rhs_dfltD60.mdl
  dfltD90.mdl     <- rhs_dfltD90.mdl
  dfltCure.mdl    <- rhs_dfltCure.mdl
  dfltBuyout.mdl  <- rhs_dfltBuyout.mdl    
  turn.mdl        <- rhs_turn.mdl
  cout.mdl        <- rhs_cout.mdl
  refi.mdl        <- rhs_refi.mdl
  credcur.mdl     <- rhs_credcur.mdl 
  fta.mdl         <- rhs_fta.mdl  
}
# DATA preparation: calculate media_effect and burnout and hpa_interp and wala_interp multiplier
#1 fta submodel
pre_list_fta  <- c("tangibleBenefit_interp") 

preparation_fta <-  names(fta.mdl)[match(pre_list_fta, names(fta.mdl))]

preparation_fta.df <- data.frame(matrix(nrow = nrow(ppdata), ncol = length(preparation_fta))) 

names(preparation_fta.df) <- pre_list_fta

ppdata$tangibleBenefit_interp       <- ppdata$prepayMonth

for (p in preparation_fta) {
    if(!(p %in% names(ppdata))) {
        preparation_fta.df[, p] <- 1.0
        cat("ATTENTION!Missing tangibleBenefit interpolation in INPUT!", " missing: ", p, "\n")
    }
    else {
        idx <- match(p, names(fta.mdl))
        a <- unlist(fta.mdl[idx][[1]][1])  
        b <- unlist(fta.mdl[idx][[1]][2])
        x <- ppdata[, p]
        preparation_fta.df[, p] <- BuildSpline(a = a, b = b, x = x)$y
    }
}

preparation_fta.df  <- data.frame(preparation_fta.df) 
names(preparation_fta.df)   <- pre_list_fta

ppdata$tangibleBenefit_interp         <-   preparation_fta.df$tangibleBenefit_interp

#2 tover submodel
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
ppdata$hpa_interpolation_int         <-   floor(preparation_tover.df$hpa_interp)
ppdata$hpa_interpolation_dec         <-   ppdata$hpa_interpolation - ppdata$hpa_interpolation_int 


#3 cout submodel
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

#4 refi submodel
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

#5 incentive elbow shift for refi submodel
ppdata$elbow_wacls_purch0     <- ppdata$wacls
ppdata$elbow_wacls_purch1     <- ppdata$wacls
ppdata$elbow_wacls_purch2     <- ppdata$wacls

ppdata$elbow_wacls_cout0     <- ppdata$wacls
ppdata$elbow_wacls_cout1     <- ppdata$wacls
ppdata$elbow_wacls_cout2     <- ppdata$wacls

ppdata$elbow_wacls_refi0     <- ppdata$wacls
ppdata$elbow_wacls_refi1     <- ppdata$wacls
ppdata$elbow_wacls_refi2     <- ppdata$wacls

ppdata$elbow_wacls_hmod0     <- ppdata$wacls
ppdata$elbow_wacls_hmod1     <- ppdata$wacls
ppdata$elbow_wacls_hmod2     <- ppdata$wacls

ppdata$elbow_wacls_nhmod0     <- ppdata$wacls
ppdata$elbow_wacls_nhmod1     <- ppdata$wacls
ppdata$elbow_wacls_nhmod2     <- ppdata$wacls

ppdata$elbow_wacls_rp0     <- ppdata$wacls
ppdata$elbow_wacls_rp1     <- ppdata$wacls
ppdata$elbow_wacls_rp2     <- ppdata$wacls

ppdata$elbow_wacls_broker0     <- ppdata$wacls
ppdata$elbow_wacls_broker1     <- ppdata$wacls
ppdata$elbow_wacls_broker2     <- ppdata$wacls

ppdata$elbow_wacls_corres0     <- ppdata$wacls
ppdata$elbow_wacls_corres1     <- ppdata$wacls
ppdata$elbow_wacls_corres2     <- ppdata$wacls

ppdata$elbow_wacls_retail0     <- ppdata$wacls
ppdata$elbow_wacls_retail1     <- ppdata$wacls
ppdata$elbow_wacls_retail2     <- ppdata$wacls

ppdata$elbow_wacls_na0     <- ppdata$wacls
ppdata$elbow_wacls_na1     <- ppdata$wacls
ppdata$elbow_wacls_na2     <- ppdata$wacls

ppdata$elbow_sato0     <- ppdata$sato
ppdata$elbow_sato1     <- ppdata$sato
ppdata$elbow_sato2     <- ppdata$sato

elbow_submdl_purpose0  <- refi.mdl$incentive$functions$functions[[1]]$elbow[5][[1]]$functions[1][[1]]
elbow_submdl_purpose1  <- refi.mdl$incentive$functions$functions[[2]]$elbow[5][[1]]$functions[1][[1]]
elbow_submdl_purpose2  <- refi.mdl$incentive$functions$functions[[3]]$elbow[5][[1]]$functions[1][[1]]

elbow_submdl_tpo0      <- refi.mdl$incentive$functions$functions[[1]]$elbow[5][[1]]$functions[2][[1]]
elbow_submdl_tpo1      <- refi.mdl$incentive$functions$functions[[2]]$elbow[5][[1]]$functions[2][[1]]
elbow_submdl_tpo2      <- refi.mdl$incentive$functions$functions[[3]]$elbow[5][[1]]$functions[2][[1]]

elbow_submdl_sato0  <- refi.mdl$incentive$functions$functions[[1]]$elbow[5][[1]]$functions[3]
elbow_submdl_sato1  <- refi.mdl$incentive$functions$functions[[2]]$elbow[5][[1]]$functions[3]
elbow_submdl_sato2  <- refi.mdl$incentive$functions$functions[[3]]$elbow[5][[1]]$functions[3]

elbow_submdl   <- c(elbow_submdl_purpose0,elbow_submdl_purpose1,elbow_submdl_purpose2,elbow_submdl_tpo0,elbow_submdl_tpo1,elbow_submdl_tpo2,elbow_submdl_sato0,elbow_submdl_sato1,elbow_submdl_sato2)

elbow_list_refinance  <- c("elbow_wacls_purch0","elbow_wacls_cout0","elbow_wacls_refi0","elbow_wacls_hmod0","elbow_wacls_nhmod0","elbow_wacls_rp0","elbow_wacls_purch1","elbow_wacls_cout1","elbow_wacls_refi1","elbow_wacls_hmod1","elbow_wacls_nhmod1","elbow_wacls_rp1","elbow_wacls_purch2","elbow_wacls_cout2","elbow_wacls_refi2","elbow_wacls_hmod2","elbow_wacls_nhmod2","elbow_wacls_rp2","elbow_wacls_broker0","elbow_wacls_corres0","elbow_wacls_retail0","elbow_wacls_na0","elbow_wacls_broker1","elbow_wacls_corres1","elbow_wacls_retail1","elbow_wacls_na1","elbow_wacls_broker2","elbow_wacls_corres2","elbow_wacls_retail2","elbow_wacls_na2","elbow_sato0","elbow_sato1","elbow_sato2")

names(elbow_submdl)   <- elbow_list_refinance

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

ppdata$incentive_adj_0  <- (ppdata$pct_broker * elbow_mult.df$elbow_wacls_broker0 + ppdata$pct_corres * elbow_mult.df$elbow_wacls_corres0 + ppdata$pct_retail * elbow_mult.df$elbow_wacls_retail0 + ppdata$pct_na * elbow_mult.df$elbow_wacls_na0) / 100 + (ppdata$pct_purchase * elbow_mult.df$elbow_wacls_purch0 + ppdata$pct_refi_co * elbow_mult.df$elbow_wacls_cout0 + ppdata$pct_refi_nco * elbow_mult.df$elbow_wacls_refi0 + ppdata$pct_hmod * elbow_mult.df$elbow_wacls_hmod0 + ppdata$pct_nhmod * elbow_mult.df$elbow_wacls_nhmod0 + ppdata$pct_rp * elbow_mult.df$elbow_wacls_rp0) / 100 + elbow_mult.df$elbow_sato0

ppdata$incentive_adj_1  <- (ppdata$pct_broker * elbow_mult.df$elbow_wacls_broker1 + ppdata$pct_corres * elbow_mult.df$elbow_wacls_corres1 + ppdata$pct_retail * elbow_mult.df$elbow_wacls_retail1 + ppdata$pct_na * elbow_mult.df$elbow_wacls_na1) / 100 + (ppdata$pct_purchase * elbow_mult.df$elbow_wacls_purch1 + ppdata$pct_refi_co * elbow_mult.df$elbow_wacls_cout1 + ppdata$pct_refi_nco * elbow_mult.df$elbow_wacls_refi1 + ppdata$pct_hmod * elbow_mult.df$elbow_wacls_hmod1 + ppdata$pct_nhmod * elbow_mult.df$elbow_wacls_nhmod1 + ppdata$pct_rp * elbow_mult.df$elbow_wacls_rp1) / 100 + elbow_mult.df$elbow_sato1

ppdata$incentive_adj_2  <- (ppdata$pct_broker * elbow_mult.df$elbow_wacls_broker2 + ppdata$pct_corres * elbow_mult.df$elbow_wacls_corres2 + ppdata$pct_retail * elbow_mult.df$elbow_wacls_retail2 + ppdata$pct_na * elbow_mult.df$elbow_wacls_na2) / 100 + (ppdata$pct_purchase * elbow_mult.df$elbow_wacls_purch2 + ppdata$pct_refi_co * elbow_mult.df$elbow_wacls_cout2 + ppdata$pct_refi_nco * elbow_mult.df$elbow_wacls_refi2 + ppdata$pct_hmod * elbow_mult.df$elbow_wacls_hmod2 + ppdata$pct_nhmod * elbow_mult.df$elbow_wacls_nhmod2 + ppdata$pct_rp * elbow_mult.df$elbow_wacls_rp2) / 100 + elbow_mult.df$elbow_sato2

ppdata$incentive.store    <- ppdata$incentive

ppdata$incentive_0  <- ppdata$refinance_incentive + ppdata$incentive_adj_0
ppdata$incentive_1  <- ppdata$refinance_incentive + ppdata$incentive_adj_1
ppdata$incentive_2  <- ppdata$refinance_incentive + ppdata$incentive_adj_2

ppdata$purch_incentive          <- ppdata$refinance_incentive
ppdata$refi_co_incentive        <- ppdata$refinance_incentive
ppdata$refi_nco_incentive       <- ppdata$refinance_incentive
ppdata$hmod_incentive           <- ppdata$refinance_incentive
ppdata$nhmod_incentive          <- ppdata$refinance_incentive
ppdata$rp_incentive             <- ppdata$refinance_incentive

ppdata$tangible_0      <- ppdata$ftaIncentive
ppdata$tangible_1      <- ppdata$ftaIncentive

ppdata$broker_wacls_0       <-  ppdata$wacls
ppdata$broker_wacls_1       <-  ppdata$wacls
ppdata$broker_wacls_2       <-  ppdata$wacls
ppdata$corres_wacls_0       <-  ppdata$wacls
ppdata$corres_wacls_1       <-  ppdata$wacls
ppdata$corres_wacls_2       <-  ppdata$wacls
ppdata$retail_wacls_0       <-  ppdata$wacls
ppdata$retail_wacls_1       <-  ppdata$wacls
ppdata$retail_wacls_2       <-  ppdata$wacls
ppdata$na_wacls_0           <-  ppdata$wacls
ppdata$na_wacls_1           <-  ppdata$wacls
ppdata$na_wacls_2           <-  ppdata$wacls

ppdata$purch_wacls_0        <-  ppdata$wacls
ppdata$purch_wacls_1        <-  ppdata$wacls
ppdata$purch_wacls_2        <-  ppdata$wacls
ppdata$cout_wacls_0         <-  ppdata$wacls
ppdata$cout_wacls_1         <-  ppdata$wacls
ppdata$cout_wacls_2         <-  ppdata$wacls
ppdata$refi_wacls_0         <-  ppdata$wacls
ppdata$refi_wacls_1         <-  ppdata$wacls
ppdata$refi_wacls_2         <-  ppdata$wacls
ppdata$hmod_wacls_0         <-  ppdata$wacls
ppdata$hmod_wacls_1         <-  ppdata$wacls
ppdata$hmod_wacls_2         <-  ppdata$wacls
ppdata$nhmod_wacls_0        <-  ppdata$wacls
ppdata$nhmod_wacls_1        <-  ppdata$wacls
ppdata$nhmod_wacls_2        <-  ppdata$wacls
ppdata$rp_wacls_0           <-  ppdata$wacls
ppdata$rp_wacls_1           <-  ppdata$wacls
ppdata$rp_wacls_2           <-  ppdata$wacls

ppdata$NACol			  <- NULL

ppdata$fico_0     <- ppdata$fico
ppdata$fico_1     <- ppdata$fico
ppdata$fico_2     <- ppdata$fico

ppdata$sato_0     <- ppdata$sato
ppdata$sato_1     <- ppdata$sato
ppdata$sato_2     <- ppdata$sato

ppdata$low_fico_adjustment     <- ppdata$fico

ppdata$wala1              <- ppdata$wala
ppdata$wala2              <- ppdata$wala

ppdata$purch_wala_0                 <- ppdata$wala
ppdata$purch_wala_1                 <- ppdata$wala
ppdata$purch_wala_2                 <- ppdata$wala
ppdata$refi_co_wala_0               <- ppdata$wala
ppdata$refi_co_wala_1               <- ppdata$wala
ppdata$refi_co_wala_2               <- ppdata$wala
ppdata$refi_nco_wala_0              <- ppdata$wala
ppdata$refi_nco_wala_1              <- ppdata$wala
ppdata$refi_nco_wala_2              <- ppdata$wala
ppdata$hmod_wala_0              	<- ppdata$wala
ppdata$hmod_wala_1               	<- ppdata$wala
ppdata$hmod_wala_2               	<- ppdata$wala
ppdata$nhmod_wala_0             	<- ppdata$wala
ppdata$nhmod_wala_1               	<- ppdata$wala
ppdata$nhmod_wala_2               	<- ppdata$wala
ppdata$rp_wala_0                  	<- ppdata$wala
ppdata$rp_wala_1                  	<- ppdata$wala
ppdata$rp_wala_2                  	<- ppdata$wala

ppdata$none_msi             <-ppdata$monthsSinceIssued
ppdata$hmod_msi             <-ppdata$monthsSinceIssued
ppdata$nhmod_msi            <-ppdata$monthsSinceIssued
ppdata$rp_msi               <-ppdata$monthsSinceIssued

ppdata$fico1              <- ppdata$fico
ppdata$fico2              <- ppdata$fico

ppdata$NY_acls      <- ppdata$acls
ppdata$NY_wacls     <- ppdata$wacls
ppdata$TX_wacls     <- ppdata$wacls

ppdata$broker_wacls       <-  ppdata$wacls
ppdata$corres_wacls       <-  ppdata$wacls
ppdata$retail_wacls       <-  ppdata$wacls
ppdata$na_wacls           <-  ppdata$wacls

ppdata$broker_acls       <-  ppdata$acls
ppdata$corres_acls       <-  ppdata$acls
ppdata$retail_acls       <-  ppdata$acls
ppdata$na_acls           <-  ppdata$acls

ppdata$TXPurch_wacls            <- ppdata$wacls
ppdata$TXNonPurch_wacls         <- ppdata$wacls
ppdata$nonTXPurch_wacls         <- ppdata$wacls
ppdata$nonTXNonPurch_wacls      <- ppdata$wacls

ppdata$tax                <- 20200101

ppdata$bizDayCntBase      <- 20.91
ppdata$bizDatCntAdj       <- ppdata$day_count / ppdata$bizDayCntBase

cat("input data: Done",  "\n")

cat("Cleaning data: Start",  "\n")
ppdata <- na.omit(ppdata)
cat("Cleaning data: Done",  "\n")


# Calculate prepayment results
cat("Calculate Curtailment: Start",  "\n")
ppdata$curt       <- PredictSubmodel_4_60_interpolation_VA(coll=coll, submodel="curt", submdl.spl=curt.mdl, data=ppdata, seasadj=TRUE, version=kNewModelVersion)$pred
ppdata$curt       <- ppdata$curt * ppdata$delq_flag
#ppdata$curt   <- NULL
#cat("Curtailment SMM set to NULL!!", "\n")
cat("Calculate Curtailment: Done",  "\n")

# Use unadjusted incentive for default predictions
cat("Calculate Default: Start",  "\n")
ppdata$monthsSince1 <- ppdata$monthsSince
ppdata$monthsSince2 <- ppdata$monthsSince
defaultResult       <- data.frame(PredictDflt(dfltD0.mdl, dfltD30.mdl, dfltD60.mdl, NA, dfltCure.mdl, dfltBuyout.mdl, test = FALSE, ppdata, kNewModelVersion))
ppdata$dfltall      <- defaultResult$pred_all
ppdata$dfltTransit  <- defaultResult$pred_transit
ppdata$dfltBuyout   <- defaultResult$pred_buyout
#ppdata$dfltall      <- NULL
#ppdata$dfltTransit  <- NULL
#ppdata$dfltBuyout   <- NULL
# cat("Default SMM set to NULL!!", "\n")
cat("Calculate Default: Done", "\n")


# Use unadjusted incentive for OTM Cashout-refis
cat("Calculate Cashout: Start", "\n")
ppdata$cout                 <- PredictSubmodel_4_60_interpolation_VA(coll=coll, submodel="cout", submdl.spl=cout.mdl, data=ppdata, seasadj=TRUE, version=kNewModelVersion)$pred * ppdata$bizDatCntAdj
ppdata$cout                 <- ppdata$cout * ppdata$delq_flag
#ppdata$cout   <- NULL
#cat("Cashout SMM set to NULL!!", "\n")
cat("Calculate Cashout: Done", "\n")
 
# Use unadjusted incentive for turnover predictions
cat("Calculate Turnover: Start", "\n")
ppdata$incentive            <- ppdata$incentive.store
ppdata$turn                 <- PredictSubmodel_4_60_interpolation_VA(coll=coll, submodel="turn", submdl.spl=turn.mdl, data=ppdata, seasadj=TRUE, version=kNewModelVersion)$pred * ppdata$bizDatCntAdj
ppdata$turn                 <- ppdata$turn * ppdata$delq_flag
#ppdata$turn   <- NULL
#cat("Turnover SMM set to NULL!!", "\n")
cat("Calculate Turnover: Done", "\n")
 
# Use adjusted incentive to refi predictions
cat("Calculate Refinance: Start",  "\n")
ppdata$refi                 <- PredictSubmodel_4_60_interpolation_VA(coll=coll, submodel="refi", submdl.spl=refi.mdl, data=ppdata, seasadj=TRUE, version=kNewModelVersion)$pred * ppdata$bizDatCntAdj
ppdata$refi                 <- ppdata$refi * ppdata$delq_flag
#ppdata$refi   <- NULL
#cat("Refinance SMM set to NULL!!", "\n")
cat("Calculate Refinance: Done",  "\n")
 
# Use adjusted incentive to credit curing predictions
cat("Calculate Credit Curing: Start",  "\n")
ppdata$credit_curing        <- PredictSubmodel_4_60_interpolation_VA(coll=coll, submodel="cc", submdl.spl=credcur.mdl, data=ppdata, seasadj=TRUE, version=kNewModelVersion)$pred * ppdata$bizDatCntAdj
ppdata$credit_curing        <- ppdata$credit_curing * ppdata$delq_flag
#ppdata$credit_curing   <- NULL
#cat("Credit Curing SMM set to NULL!!", "\n")
cat("Calculate Credit Curing: Done",  "\n")

# Use fixedToARM incentive to FTA predictions
cat("Calculate Fixed To ARM: Start",  "\n")
ppdata$fta            <- PredictSubmodel_4_60_interpolation_VA(coll=coll, submodel="fta", submdl.spl=fta.mdl, data=ppdata, seasadj=FALSE, version=kNewModelVersion)$pred * ppdata$bizDatCntAdj
ppdata$fta            <- ppdata$fta * ppdata$delq_flag
#ppdata$fta   <- NULL
#cat("Fixed To Arm SMM set to NULL!!", "\n")
cat("Calculate Fixed To ARM: Done",  "\n")

# Save total SMM
cat("Calculate Model SMM: Start",  "\n")
ppdata$modelSMM   <- ppdata$curt + ppdata$dfltall + ppdata$cout + ppdata$turn + ppdata$refi + ppdata$credit_curing + ppdata$fta
#ppdata$modelSMM   <- NULL
#cat("Total SMM set to NULL!!", "\n")
cat("Calculate Model SMM: Done",  "\n")

# shift by one month, show as factor date
ppdata$asOf       <- as.Date(ppdata$asOf, '%Y-%m-%d')
ppdata$asOf       <- ppdata$asOf + months(1)

# change date format to yyyymmdd
ppdata$asOf       <- format(ppdata$asOf, format = "%Y%m%d")
# turn_test       <- PredictSubmodel_4_60_interpolation_VA(coll=coll, submodel="turn", submdl.spl=turn.mdl, data=ppdata, seasadj=TRUE, version=kNewModelVersion)$mult
# refi_test       <- PredictSubmodel_4_60_interpolation_VA(coll=coll, submodel="refi", submdl.spl=refi.mdl, data=ppdata, seasadj=TRUE, version=kNewModelVersion)$mult
# cc_test       <- PredictSubmodel_4_60_interpolation_VA(coll=coll, submodel="cc", submdl.spl=credcur.mdl, data=ppdata, seasadj=TRUE, version=kNewModelVersion)$mult
# fta_test       <- PredictSubmodel_4_60_interpolation_VA(coll=coll, submodel="fta", submdl.spl=fta.mdl, data=ppdata, seasadj=TRUE, version=kNewModelVersion)$mult

# Create the output data
# smm.df.csv <- paste(raw.data$issueId, raw.data$asOf, raw.data$curt.mdl, raw.data$dflt.mdl, raw.data$turn.mdl, raw.data$refi.mdl,"\x0d\x0a", sep = "|")
cat("Storing Results: Start",  "\n")
#smm.df.csv    <- data.frame(paste(ppdata$loanseqnum, ppdata$asOf, ppdata$curt, ppdata$dfltall, ppdata$turn, ppdata$cout, ppdata$refi, ppdata$credit_curing, ppdata$fta, ppdata$dfltTransit, ppdata$dfltBuyout, ppdata$modelSMM, names(fta_test), fta_test, "",sep = "|"))
smm.df.csv    <- data.frame(paste(ppdata$loanseqnum, ppdata$asOf, ppdata$curt, ppdata$dfltall, ppdata$turn, ppdata$cout, ppdata$refi, ppdata$credit_curing, ppdata$fta, ppdata$dfltTransit, ppdata$dfltBuyout, ppdata$modelSMM, "",sep = "|"))

#write.csv(smm.df.csv, data.output, row.names = F, col.names = F, quote = F)
fwrite(smm.df.csv, data.output, row.names = F, col.names = F, qmethod = "escape")

cat("Storing Results: Done",  "\n")