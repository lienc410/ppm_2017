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


kJSONDir         <- c("../JSON/conv30")
kNewModelVersion <- c("v4.60")

usage <- function() {
  print("Please pass model version [2.00, 2.10, 2.11...'], model type [CONVENTIONAL, GINNIE], input file ['sample_file.csv'], input path ['C:/...'], output path ['C:/...']")
}

# Interacitve Args
root.path     <- "./"
model.version <- paste0("Baton_", kNewModelVersion)
model.type    <- "CONVENTIONAL"
input.file    <- "PrepayLoanData_freddie_sample.csv"
input.path    <- "H:/tempExtract/PrepayLoanData/CONVENTIONAL/Model_4.20/20180801/model_input"
output.path   <- "H:/tempExtract/PrepayLoanData/CONVENTIONAL/Model_4.20/20180801/model_output"


# Batch Arg Parsing
if(!is.na(commandArgs()[7])) {
  if (!is.na(commandArgs()[8])) {
    kNewModelVersion <- gsub("--","",commandArgs()[8])
    kNewModelVersion <- paste0("v",kNewModelVersion)
    cat("Model Version: ", kNewModelVersion,  "\n")
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

# Read in Baton Model
BATON_MODEL     <- paste(model.version, ".json", sep = "")
baton.mdl       <- fromJSON(paste(kJSONDir, kNewModelVersion, BATON_MODEL, sep = "/"))

curt.mdl        <- baton.mdl$Conventional$CurtailmentSubModel
dfltcurr.mdl    <- baton.mdl$Conventional$DefaultSubModelCurr
dfltdelq.mdl    <- baton.mdl$Conventional$DefaultSubModelDelq
turn.mdl        <- baton.mdl$Conventional$TurnoverSubModel
cout.mdl        <- baton.mdl$Conventional$CashoutSubModel
refi.mdl        <- baton.mdl$Conventional$RefinanceSubModel


# Read in loan/pool/repline data
cat("input data: Start",  "\n")
ppdata          <- fread(data.input, sep="|", header=FALSE, stringsAsFactors = FALSE, colClasses=(list(character=1)))
names(ppdata)   <- c("loanseqnum","asOf","monthBucket","bal","pct_owner","pct_2nd","pct_inv"
                     ,"pct_curr","pct_dq","incentive","burnout","wala","wacls","cltv","fico","wac"
                     ,"pct_REFI","refi_elig_pct","pct_HARPed","pct_tpo","pct_BROKER","pct_CORRES","pct_NonRETAIL","pct_RETAIL_CashWindow","pct_RETAIL_NonCashWindow","HARP_eligible","sato","monthsSince"
                     ,"hpa2yr","cai","media_effect","day_count","wam","hpa_annual","hpa_cum","acls","pct_purchase","pct_second_lien", "refinance_incentive","oltv","pct_preHARP","pct_NY","pct_FGU6","pct_FGU9","NACol")

ppdata  <- data.frame(ppdata) 

# step 1: calculate media_effect and burnout and hpa_interp multiplier
pre_list_refinance  <- c("media_effect", "burnout") 
pre_list_turnover  <- c("hpa_interp","hpa_interp_U6","hpa_interp_U9") 

preparation <-  names(refi.mdl)[match(pre_list_refinance, names(refi.mdl))]
preparation_tover <-  names(turn.mdl)[match(pre_list_turnover, names(turn.mdl))]

preparation.df <- data.frame(matrix(nrow = nrow(ppdata), ncol = length(preparation))) 
preparation_tover.df <- data.frame(matrix(nrow = nrow(ppdata), ncol = length(preparation_tover))) 

names(preparation.df) <- pre_list_refinance
names(preparation_tover.df) <- pre_list_turnover

ppdata$hpa_interp       <- ppdata$hpa_annual
ppdata$hpa_interp_U6    <- ppdata$hpa_annual
ppdata$hpa_interp_U9    <- ppdata$hpa_annual

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

ppdata$media_effect_interpolation  <- preparation.df$media_effect
ppdata$media_effect_interpolation_int  <- floor(preparation.df$media_effect)
ppdata$media_effect_interpolation_dec  <- ppdata$media_effect_interpolation - ppdata$media_effect_interpolation_int
ppdata$burnout_interpolation  <- preparation.df$burnout
ppdata$burnout_interpolation_int  <- floor(preparation.df$burnout)
ppdata$burnout_interpolation_dec  <- ppdata$burnout_interpolation - ppdata$burnout_interpolation_int

ppdata$hpa_interpolation         <-   preparation_tover.df$hpa_interp
ppdata$hpa_interpolation_U6      <-   preparation_tover.df$hpa_interp_U6
ppdata$hpa_interpolation_U9      <-   preparation_tover.df$hpa_interp_U9

     
# step 2: incentive elbow shift for TPO for refinance submodel
ppdata$nonRetail_elbow_wacls_0     <- ppdata$wacls
ppdata$nonRetail_elbow_wacls_1     <- ppdata$wacls
ppdata$nonRetail_elbow_wacls_2     <- ppdata$wacls
ppdata$broker_elbow_wacls_0     <- ppdata$wacls
ppdata$broker_elbow_wacls_1     <- ppdata$wacls
ppdata$broker_elbow_wacls_2     <- ppdata$wacls
ppdata$corres_elbow_wacls_0     <- ppdata$wacls
ppdata$corres_elbow_wacls_1     <- ppdata$wacls
ppdata$corres_elbow_wacls_2     <- ppdata$wacls
ppdata$retailCashWindow_elbow_wacls_0     <- ppdata$wacls
ppdata$retailCashWindow_elbow_wacls_1     <- ppdata$wacls
ppdata$retailCashWindow_elbow_wacls_2     <- ppdata$wacls
ppdata$retailNonCashWindow_elbow_wacls_0     <- ppdata$wacls
ppdata$retailNonCashWindow_elbow_wacls_1     <- ppdata$wacls
ppdata$retailNonCashWindow_elbow_wacls_2     <- ppdata$wacls

nonRetail_elbow_wacls_0  <- refi.mdl$incentive$functions$functions[[1]]$elbow[3][[1]]$functions$nonRetail[2]
nonRetail_elbow_wacls_1  <- refi.mdl$incentive$functions$functions[[2]]$elbow[3][[1]]$functions$nonRetail[2]
nonRetail_elbow_wacls_2  <- refi.mdl$incentive$functions$functions[[3]]$elbow[3][[1]]$functions$nonRetail[2]
nonretail_elbow_submdl   <- c(nonRetail_elbow_wacls_0,nonRetail_elbow_wacls_1,nonRetail_elbow_wacls_2)

broker_elbow_wacls_0  <- refi.mdl$incentive$functions$functions[[1]]$elbow[3][[1]]$functions$broker[2]
broker_elbow_wacls_1  <- refi.mdl$incentive$functions$functions[[2]]$elbow[3][[1]]$functions$broker[2]
broker_elbow_wacls_2  <- refi.mdl$incentive$functions$functions[[3]]$elbow[3][[1]]$functions$broker[2]
broker_elbow_submdl   <- c(broker_elbow_wacls_0,broker_elbow_wacls_1,broker_elbow_wacls_2)

corres_elbow_wacls_0  <- refi.mdl$incentive$functions$functions[[1]]$elbow[3][[1]]$functions$corres[2]
corres_elbow_wacls_1  <- refi.mdl$incentive$functions$functions[[2]]$elbow[3][[1]]$functions$corres[2]
corres_elbow_wacls_2  <- refi.mdl$incentive$functions$functions[[3]]$elbow[3][[1]]$functions$corres[2]
corres_elbow_submdl   <- c(corres_elbow_wacls_0,corres_elbow_wacls_1,corres_elbow_wacls_2)

retailCashWindow_elbow_wacls_0  <- refi.mdl$incentive$functions$functions[[1]]$elbow[3][[1]]$functions$retailCashWindow[2]
retailCashWindow_elbow_wacls_1  <- refi.mdl$incentive$functions$functions[[2]]$elbow[3][[1]]$functions$retailCashWindow[2]
retailCashWindow_elbow_wacls_2  <- refi.mdl$incentive$functions$functions[[3]]$elbow[3][[1]]$functions$retailCashWindow[2]
retailCashWindow_elbow_submdl   <- c(retailCashWindow_elbow_wacls_0,retailCashWindow_elbow_wacls_1,retailCashWindow_elbow_wacls_2)

retailNonCashWindow_elbow_wacls_0  <- refi.mdl$incentive$functions$functions[[1]]$elbow[3][[1]]$functions$retailNonCashWindow[2]
retailNonCashWindow_elbow_wacls_1  <- refi.mdl$incentive$functions$functions[[2]]$elbow[3][[1]]$functions$retailNonCashWindow[2]
retailNonCashWindow_elbow_wacls_2  <- refi.mdl$incentive$functions$functions[[3]]$elbow[3][[1]]$functions$retailNonCashWindow[2]
retailNonCashWindow_elbow_submdl   <- c(retailNonCashWindow_elbow_wacls_0,retailNonCashWindow_elbow_wacls_1,retailNonCashWindow_elbow_wacls_2)

names(nonretail_elbow_submdl)   <- c("nonRetail_elbow_wacls_0","nonRetail_elbow_wacls_1","nonRetail_elbow_wacls_2")
names(broker_elbow_submdl)      <- c("broker_elbow_wacls_0","broker_elbow_wacls_1","broker_elbow_wacls_2")
names(corres_elbow_submdl)      <- c("corres_elbow_wacls_0","corres_elbow_wacls_1","corres_elbow_wacls_2")
names(retailCashWindow_elbow_submdl)      <- c("retailCashWindow_elbow_wacls_0","retailCashWindow_elbow_wacls_1","retailCashWindow_elbow_wacls_2")
names(retailNonCashWindow_elbow_submdl)      <- c("retailNonCashWindow_elbow_wacls_0","retailNonCashWindow_elbow_wacls_1","retailNonCashWindow_elbow_wacls_2")

elbow_list_refinance  <- c("nonRetail_elbow_wacls_0","nonRetail_elbow_wacls_1","nonRetail_elbow_wacls_2","broker_elbow_wacls_0","broker_elbow_wacls_1","broker_elbow_wacls_2","corres_elbow_wacls_0","corres_elbow_wacls_1","corres_elbow_wacls_2", "retailCashWindow_elbow_wacls_0","retailCashWindow_elbow_wacls_1","retailCashWindow_elbow_wacls_2","retailNonCashWindow_elbow_wacls_0","retailNonCashWindow_elbow_wacls_1","retailNonCashWindow_elbow_wacls_2")

elbow_mult.df <- data.frame(matrix(nrow = nrow(ppdata), ncol = length(elbow_list_refinance)))
names(elbow_mult.df) <- elbow_list_refinance
  
for (p in names(nonretail_elbow_submdl)) {
    if(!(p %in% names(ppdata))) {
        elbow_mult.df[, p] <- 1.0
        cat("ATTENTION!Missing nonretail elbow shift in INPUT!", " missing: ", p, "\n")
    }
    else {
        idx <- match(p, names(nonretail_elbow_submdl))
        a <- unlist(nonretail_elbow_submdl[idx][[1]][1]) 
        b <- unlist(nonretail_elbow_submdl[idx][[1]][2])
        x <- ppdata[, p]
        elbow_mult.df[, p] <- BuildSpline(a = a, b = b, x = x)$y
    }
}

for (p in names(broker_elbow_submdl)) {
    if(!(p %in% names(ppdata))) {
        elbow_mult.df[, p] <- 1.0
        cat("ATTENTION!Missing broker elbow shift in INPUT!", " missing: ", p, "\n")
    }
    else {
        idx <- match(p, names(broker_elbow_submdl))
        a <- unlist(broker_elbow_submdl[idx][[1]][1]) 
        b <- unlist(broker_elbow_submdl[idx][[1]][2])
        x <- ppdata[, p]
        elbow_mult.df[, p] <- BuildSpline(a = a, b = b, x = x)$y
    }
}

for (p in names(corres_elbow_submdl)) {
    if(!(p %in% names(ppdata))) {
        elbow_mult.df[, p] <- 1.0
        cat("ATTENTION!Missing corres elbow shift in INPUT!", " missing: ", p, "\n")
    }
    else {
        idx <- match(p, names(corres_elbow_submdl))
        a <- unlist(corres_elbow_submdl[idx][[1]][1]) 
        b <- unlist(corres_elbow_submdl[idx][[1]][2])
        x <- ppdata[, p]
        elbow_mult.df[, p] <- BuildSpline(a = a, b = b, x = x)$y
    }
}

for (p in names(retailCashWindow_elbow_submdl)) {
    if(!(p %in% names(ppdata))) {
        elbow_mult.df[, p] <- 1.0
        cat("ATTENTION!Missing retailCashWindow elbow shift in INPUT!", " missing: ", p, "\n")
    }
    else {
        idx <- match(p, names(retailCashWindow_elbow_submdl))
        a <- unlist(retailCashWindow_elbow_submdl[idx][[1]][1]) 
        b <- unlist(retailCashWindow_elbow_submdl[idx][[1]][2])
        x <- ppdata[, p]
        elbow_mult.df[, p] <- BuildSpline(a = a, b = b, x = x)$y
    }
}

for (p in names(retailNonCashWindow_elbow_submdl)) {
    if(!(p %in% names(ppdata))) {
        elbow_mult.df[, p] <- 1.0
        cat("ATTENTION!Missing retailNonCashWindow elbow shift in INPUT!", " missing: ", p, "\n")
    }
    else {
        idx <- match(p, names(retailNonCashWindow_elbow_submdl))
        a <- unlist(retailNonCashWindow_elbow_submdl[idx][[1]][1]) 
        b <- unlist(retailNonCashWindow_elbow_submdl[idx][[1]][2])
        x <- ppdata[, p]
        elbow_mult.df[, p] <- BuildSpline(a = a, b = b, x = x)$y
    }
}

elbow_mult.df  <- data.frame(elbow_mult.df) 

ppdata$tpo_incentive_adj_0  <- (ppdata$pct_NonRETAIL * elbow_mult.df$nonRetail_elbow_wacls_0 + ppdata$pct_BROKER * elbow_mult.df$broker_elbow_wacls_0 + ppdata$pct_CORRES * elbow_mult.df$corres_elbow_wacls_0 + ppdata$pct_RETAIL_CashWindow * elbow_mult.df$retailCashWindow_elbow_wacls_0 + ppdata$pct_RETAIL_NonCashWindow * elbow_mult.df$retailNonCashWindow_elbow_wacls_0) / 100

ppdata$tpo_incentive_adj_1  <- (ppdata$pct_NonRETAIL * elbow_mult.df$nonRetail_elbow_wacls_1 + ppdata$pct_BROKER * elbow_mult.df$broker_elbow_wacls_1 + ppdata$pct_CORRES * elbow_mult.df$corres_elbow_wacls_1 + ppdata$pct_RETAIL_CashWindow * elbow_mult.df$retailCashWindow_elbow_wacls_1 + ppdata$pct_RETAIL_NonCashWindow * elbow_mult.df$retailNonCashWindow_elbow_wacls_1) / 100

ppdata$tpo_incentive_adj_2  <- (ppdata$pct_NonRETAIL * elbow_mult.df$nonRetail_elbow_wacls_2 + ppdata$pct_BROKER * elbow_mult.df$broker_elbow_wacls_2 + ppdata$pct_CORRES * elbow_mult.df$corres_elbow_wacls_2 + ppdata$pct_RETAIL_CashWindow * elbow_mult.df$retailCashWindow_elbow_wacls_2 + ppdata$pct_RETAIL_NonCashWindow * elbow_mult.df$retailNonCashWindow_elbow_wacls_2) / 100

# step 3: incentive elbow shift for loanPurposeType for refinance submodel
ppdata$purch_elbow_oltv_0           <- ppdata$oltv
ppdata$refiHARP_elbow_oltv_0        <- ppdata$oltv
ppdata$refiNonHARP_elbow_oltv_0     <- ppdata$oltv

ppdata$purch_elbow_oltv_1           <- ppdata$oltv
ppdata$refiHARP_elbow_oltv_1        <- ppdata$oltv
ppdata$refiNonHARP_elbow_oltv_1     <- ppdata$oltv

ppdata$purch_elbow_oltv_2           <- ppdata$oltv
ppdata$refiHARP_elbow_oltv_2        <- ppdata$oltv
ppdata$refiNonHARP_elbow_oltv_2     <- ppdata$oltv

purch_elbow_oltv_0          <- refi.mdl$incentive$functions$functions[[1]]$elbow[3][[1]]$functions$purch[1]
purch_elbow_oltv_1          <- refi.mdl$incentive$functions$functions[[2]]$elbow[3][[1]]$functions$purch[1]
purch_elbow_oltv_2          <- refi.mdl$incentive$functions$functions[[3]]$elbow[3][[1]]$functions$purch[1]
purch_elbow_submdl          <- c(purch_elbow_oltv_0,purch_elbow_oltv_1,purch_elbow_oltv_2)

refiHARP_elbow_oltv_0       <- refi.mdl$incentive$functions$functions[[1]]$elbow[3][[1]]$functions$refiHARP[1]
refiHARP_elbow_oltv_1       <- refi.mdl$incentive$functions$functions[[2]]$elbow[3][[1]]$functions$refiHARP[1]
refiHARP_elbow_oltv_2       <- refi.mdl$incentive$functions$functions[[3]]$elbow[3][[1]]$functions$refiHARP[1]
refiHARP_elbow_submdl          <- c(refiHARP_elbow_oltv_0,refiHARP_elbow_oltv_1,refiHARP_elbow_oltv_2)

refiNonHARP_elbow_oltv_0       <- refi.mdl$incentive$functions$functions[[1]]$elbow[3][[1]]$functions$refiNonHARP[1]
refiNonHARP_elbow_oltv_1       <- refi.mdl$incentive$functions$functions[[2]]$elbow[3][[1]]$functions$refiNonHARP[1]
refiNonHARP_elbow_oltv_2       <- refi.mdl$incentive$functions$functions[[3]]$elbow[3][[1]]$functions$refiNonHARP[1]
refiNonHARP_elbow_submdl          <- c(refiNonHARP_elbow_oltv_0,refiNonHARP_elbow_oltv_1,refiNonHARP_elbow_oltv_2)

names(purch_elbow_submdl)   <- c("purch_elbow_oltv_0","purch_elbow_oltv_1","purch_elbow_oltv_2")
names(refiHARP_elbow_submdl)      <- c("refiHARP_elbow_oltv_0","refiHARP_elbow_oltv_1","refiHARP_elbow_oltv_2")
names(refiNonHARP_elbow_submdl)      <- c("refiNonHARP_elbow_oltv_0","refiNonHARP_elbow_oltv_1","refiNonHARP_elbow_oltv_2")

loanpurpose_elbow_list_refinance  <- c("purch_elbow_oltv_0","purch_elbow_oltv_1","purch_elbow_oltv_2","refiHARP_elbow_oltv_0","refiHARP_elbow_oltv_1","refiHARP_elbow_oltv_2","refiNonHARP_elbow_oltv_0","refiNonHARP_elbow_oltv_1","refiNonHARP_elbow_oltv_2")

loanpurpose_elbow_mult.df <- data.frame(matrix(nrow = nrow(ppdata), ncol = length(loanpurpose_elbow_list_refinance)))
names(loanpurpose_elbow_mult.df) <- loanpurpose_elbow_list_refinance
             
for (p in names(purch_elbow_submdl)) {
    if(!(p %in% names(ppdata))) {
        loanpurpose_elbow_mult.df[, p] <- 1.0
        cat("ATTENTION!Missing purchase elbow shift in INPUT!", " missing: ", p, "\n")
    }
    else {
        idx <- match(p, names(purch_elbow_submdl))
        a <- unlist(purch_elbow_submdl[idx][[1]][1]) 
        b <- unlist(purch_elbow_submdl[idx][[1]][2])
        x <- ppdata[, p]
        loanpurpose_elbow_mult.df[, p] <- BuildSpline(a = a, b = b, x = x)$y
    }
}

for (p in names(refiHARP_elbow_submdl)) {
    if(!(p %in% names(ppdata))) {
        loanpurpose_elbow_mult.df[, p] <- 1.0
        cat("ATTENTION!Missing refi HARP elbow shift in INPUT!", " missing: ", p, "\n")
    }
    else {
        idx <- match(p, names(refiHARP_elbow_submdl))
        a <- unlist(refiHARP_elbow_submdl[idx][[1]][1]) 
        b <- unlist(refiHARP_elbow_submdl[idx][[1]][2])
        x <- ppdata[, p]
        loanpurpose_elbow_mult.df[, p] <- BuildSpline(a = a, b = b, x = x)$y
    }
}

for (p in names(refiNonHARP_elbow_submdl)) {
    if(!(p %in% names(ppdata))) {
        loanpurpose_elbow_mult.df[, p] <- 1.0
        cat("ATTENTION!Missing refi NonHARP elbow shift in INPUT!", " missing: ", p, "\n")
    }
    else {
        idx <- match(p, names(refiNonHARP_elbow_submdl))
        a <- unlist(refiNonHARP_elbow_submdl[idx][[1]][1]) 
        b <- unlist(refiNonHARP_elbow_submdl[idx][[1]][2])
        x <- ppdata[, p]
        loanpurpose_elbow_mult.df[, p] <- BuildSpline(a = a, b = b, x = x)$y
    }
}

loanpurpose_elbow_mult.df  <- data.frame(loanpurpose_elbow_mult.df) 

ppdata$loanPurpose_incentive_adj_0  <- (ppdata$pct_purchase * loanpurpose_elbow_mult.df$purch_elbow_oltv_0 + ppdata$pct_HARPed * loanpurpose_elbow_mult.df$refiHARP_elbow_oltv_0 + (100 - ppdata$pct_purchase - ppdata$pct_HARPed) * loanpurpose_elbow_mult.df$refiNonHARP_elbow_oltv_0 ) / 100

ppdata$loanPurpose_incentive_adj_1  <- (ppdata$pct_purchase * loanpurpose_elbow_mult.df$purch_elbow_oltv_1 + ppdata$pct_HARPed * loanpurpose_elbow_mult.df$refiHARP_elbow_oltv_1 + (100 - ppdata$pct_purchase - ppdata$pct_HARPed) * loanpurpose_elbow_mult.df$refiNonHARP_elbow_oltv_1 ) / 100

ppdata$loanPurpose_incentive_adj_2  <- (ppdata$pct_purchase * loanpurpose_elbow_mult.df$purch_elbow_oltv_2 + ppdata$pct_HARPed * loanpurpose_elbow_mult.df$refiHARP_elbow_oltv_2 + (100 - ppdata$pct_purchase - ppdata$pct_HARPed) * loanpurpose_elbow_mult.df$refiNonHARP_elbow_oltv_2 ) / 100
                     
ppdata$incentive.store    <- ppdata$incentive

ppdata$incentive_0  <- ppdata$refinance_incentive + ppdata$tpo_incentive_adj_0 + ppdata$loanPurpose_incentive_adj_0 
ppdata$incentive_1  <- ppdata$refinance_incentive + ppdata$tpo_incentive_adj_1 + ppdata$loanPurpose_incentive_adj_1
ppdata$incentive_2  <- ppdata$refinance_incentive + ppdata$tpo_incentive_adj_2 + ppdata$loanPurpose_incentive_adj_2 

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

ppdata$NACol			  <- NULL

ppdata$lohpa_wala         <- ppdata$wala
ppdata$lohpa_wala_U6      <- ppdata$wala
ppdata$lohpa_wala_U9      <- ppdata$wala

ppdata$hihpa_wala         <- ppdata$wala
ppdata$hihpa_wala_U6      <- ppdata$wala
ppdata$hihpa_wala_U9      <- ppdata$wala

ppdata$purch_oltv           <- ppdata$oltv
ppdata$purch_oltv_0         <- ppdata$oltv
ppdata$purch_oltv_1         <- ppdata$oltv
ppdata$purch_oltv_2         <- ppdata$oltv


ppdata$refi_HARP_oltv       <- ppdata$oltv
ppdata$refi_HARP_oltv_0     <- ppdata$oltv
ppdata$refi_HARP_oltv_1     <- ppdata$oltv
ppdata$refi_HARP_oltv_2     <- ppdata$oltv


ppdata$refi_NonHARP_oltv    <- ppdata$oltv
ppdata$refi_NonHARP_oltv_0  <- ppdata$oltv
ppdata$refi_NonHARP_oltv_1  <- ppdata$oltv
ppdata$refi_NonHARP_oltv_2  <- ppdata$oltv

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

ppdata$nonRetail_wacls_0     <- ppdata$wacls
ppdata$broker_wacls_0     <- ppdata$wacls
ppdata$corres_wacls_0     <- ppdata$wacls
ppdata$retailCashWindow_wacls_0     <- ppdata$wacls
ppdata$retailNonCashWindow_wacls_0     <- ppdata$wacls
ppdata$inv_wacls_0      <- ppdata$wacls

ppdata$nonRetail_wacls_1     <- ppdata$wacls
ppdata$broker_wacls_1     <- ppdata$wacls
ppdata$corres_wacls_1     <- ppdata$wacls
ppdata$retailCashWindow_wacls_1     <- ppdata$wacls
ppdata$retailNonCashWindow_wacls_1     <- ppdata$wacls
ppdata$inv_wacls_1      <- ppdata$wacls

ppdata$nonRetail_wacls_2     <- ppdata$wacls
ppdata$broker_wacls_2     <- ppdata$wacls
ppdata$corres_wacls_2     <- ppdata$wacls
ppdata$retailCashWindow_wacls_2     <- ppdata$wacls
ppdata$retailNonCashWindow_wacls_2     <- ppdata$wacls
ppdata$inv_wacls_2      <- ppdata$wacls

ppdata$inv_acls   <- ppdata$acls
ppdata$inv_oltv   <- ppdata$oltv

ppdata$tax                <- 20200101

ppdata$bizDayCntBase      <- 20.91
ppdata$bizDatCntAdj       <- ppdata$day_count / ppdata$bizDayCntBase

cat("input data: Done",  "\n")

cat("Cleaning data: Start",  "\n")
ppdata <- na.omit(ppdata)
cat("Cleaning data: Done",  "\n")

# Calculate prepayment results
cat("Calculate Curtailment: Start",  "\n")
ppdata$curt       <- PredictSubmodel_4_60_interpolation(coll=coll, submodel="curt", submdl.spl=curt.mdl, data=ppdata, seasadj=TRUE, version=kNewModelVersion)$pred
cat("Calculate Curtailment: Done",  "\n")

# Use unadjusted incentive for default predictions
cat("Calculate Default: Start",  "\n")
ppdata$incentive  <- ppdata$incentive.store  
ppdata$dfltall    <- PredictDflt_conv(curr.spl=dfltcurr.mdl, delq.spl=dfltdelq.mdl, data=ppdata, version=kNewModelVersion)$pred_all
cat("Calculate Default: Done", "\n")

# Use adjusted incentive for OTM Cashout-refis
cat("Calculate Cashout: Start", "\n")
ppdata$incentive  <- ppdata$incentive.store
ppdata$cout       <- PredictSubmodel_4_60_interpolation(coll=coll, submodel="cout", submdl.spl=cout.mdl, data=ppdata, seasadj=TRUE, version=kNewModelVersion)$pred * ppdata$bizDatCntAdj
cat("Calculate Cashout: Done", "\n")

# Use unadjusted incentive for turnover predictions
cat("Calculate Turnover: Start", "\n")
ppdata$incentive  <- ppdata$incentive.store  
ppdata$turn       <- PredictSubmodel_4_60_interpolation(coll=coll, submodel="turn", submdl.spl=turn.mdl, data=ppdata, seasadj=TRUE, version=kNewModelVersion)$pred * ppdata$bizDatCntAdj
cat("Calculate Turnover: Done", "\n")

# Use adjusted incentive to refi predictions
cat("Calculate Refinance: Start",  "\n")
ppdata$incentive  <- ppdata$refinance_incentive
ppdata$refi       <- PredictSubmodel_4_60_interpolation(coll=coll, submodel="refi", submdl.spl=refi.mdl, data=ppdata, seasadj=TRUE, version=kNewModelVersion)$pred * ppdata$bizDatCntAdj
cat("Calculate Refinance: Done",  "\n")

ppdata$modelSMM   <- ppdata$curt + ppdata$dfltall + ppdata$cout + ppdata$turn + ppdata$refi


# shift by one month, show as factor date
ppdata$asOf       <- as.Date(ppdata$asOf, '%Y-%m-%d')
ppdata$asOf       <- ppdata$asOf + months(1)

# change date format to yyyymmdd
ppdata$asOf       <- format(ppdata$asOf, format = "%Y%m%d")
# refi_test       <- PredictSubmodel_4_60_interpolation(coll=coll, submodel="refi", submdl.spl=refi.mdl, data=ppdata, seasadj=TRUE, version=kNewModelVersion)$mult
# turn_test       <- PredictSubmodel_4_60_interpolation(coll=coll, submodel="turn", submdl.spl=turn.mdl, data=ppdata, seasadj=TRUE, version=kNewModelVersion)$mult

# Create the output data
# smm.df.csv <- paste(raw.data$issueId, raw.data$asOf, raw.data$curt.mdl, raw.data$dflt.mdl, raw.data$turn.mdl, raw.data$refi.mdl,"\x0d\x0a", sep = "|")
cat("Storing Results: Start",  "\n")
#smm.df.csv    <- data.frame(paste(ppdata$loanseqnum, ppdata$asOf, ppdata$curt, ppdata$dfltall, ppdata$turn, ppdata$cout, ppdata$refi, ppdata$modelSMM, names(refi_test), refi_test, "",sep = "|"))
smm.df.csv    <- data.frame(paste(ppdata$loanseqnum, ppdata$asOf, ppdata$curt, ppdata$dfltall, ppdata$turn, ppdata$cout, ppdata$refi, ppdata$modelSMM, "",sep = "|"))


#write.csv(smm.df.csv, data.output, row.names = F, col.names = F, quote = F)
fwrite(smm.df.csv, data.output, row.names = F, col.names = F, qmethod = "escape")

cat("Storing Results: Done",  "\n")

