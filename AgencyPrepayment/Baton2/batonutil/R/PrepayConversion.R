SMMtoCPR <- function(smm) {
  
  if (any(smm < 0.0)) {
    warning("SMM vector has negative values")
  }
  
  cpr <- (1-(1-smm)^12) * 100
  
  return(cpr)
}

CPRtoSMM <- function(cpr) {
  
  if (any(cpr < 0)) {
    warning("CPR vector has negative values")
  }
  
  smm <- 1 - (1 - cpr/100)^(1/12)
  
  return(smm)
}