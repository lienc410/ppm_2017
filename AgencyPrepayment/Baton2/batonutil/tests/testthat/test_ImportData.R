library(data.table)
context("Importing Data")

old <- getwd()
setwd("C:/PIV/PIV-it-dev/trunk/Research/AgencyPrepayment/Baton/batonutil")

test_that("Input file exists", {
  fileExistsVec <- file.exists(pkg.env$RschGridFile)
  
  expect_equal(TRUE, all(fileExistsVec))
})

test_that("Correct column names for input data file", {
  fileCols <- data.frame(data.table::fread(pkg.env$RschGridFile, sep = "auto", nrow=0, header = TRUE, 
                                           stringsAsFactors = FALSE, showProgress = TRUE))
  
  if (pkg.env$coll == "conv30") {
    colNames <- c("asOf", "year", "month", "day", "marketTicker", "HARP_eligible", "monthsSince", "bal", 
                  "pct_inv", "pct_2nd", "pct_REFI", "pct_dq", "incentive", "burnout", "refi_elig_pct", 
                  "cltv", "wacls", "wala", "wac", "fico", "pct_HARPed", "pct_tpo", "cai", "hpa2yr", 
                  "media_effect", "sato", "smm")
  }
  else if (pkg.env$coll == "gnma30") {
    colNames <- c("asOf", "marketTicker", "loanType", "monthsSince", "bal", "pct_REFI", "pct_dq", "incentive", "burnout",
                  "cltv", "wacls", "wala", "fico", "cai", "hpa2yr", "media_effect", "year", "month", "day", "mdr", "smm")
  }
  else {
    stop(paste("Unrecognized collateral type: ", pkg.env$coll, "\n"))
  }
    
  expect_equal(colNames, colnames(fileCols))
})

on.exit(setwd(old), add=TRUE)