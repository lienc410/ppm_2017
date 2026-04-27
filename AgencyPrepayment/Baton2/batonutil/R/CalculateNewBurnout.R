#' Calculate burnout as a function of cumulative incentive and current loan size. 
#' 
#'  \code{CalculateNewBurnout} estimates burnout as a function of cumulative incentive and loan size. It assumes that
#'  burnout is given by B(I,L) = 1-[(1 - F(I)) * G(L)] where:
#' I = cumulative incentive
#' L = current loan size
#' F is a decreasing function with F(0) = 1. We take F to be the usual burnout multiplier as a function of cumulative
#' incentive. G is an increasing function of WACLS.
#' Note that B(0, L) = 1 and that B(I,L) = F(I) if G(L) = 1 for all L.
#'    
#' @param F a vector of values for F(I).
#' @param L a vector of loan sizes corresponding to I.
#' 
#' @return Burnout multiplier.
#' 
#' @examples
#' \dontrun{
#'  CalculateNewBurnout(F, L)
#'  }
#'  
CalculateNewBurnout <- function(F, L) {
    
  #paramsG <- vector(mode = "numeric", length = 6)
  #names(paramsG) <- c("A", "K", "B", "C", "nu", "Q")
  
  # Parameters for GLF that models loan size dependence of burnout
  #paramsG["A"]  <- -0.06155969
  #paramsG["K"]  <- 1.31752134
  #paramsG["B"]  <- 0.03936763
  #paramsG["C"]  <- 1.14810640
  #paramsG["nu"] <- 1.17960875
  #paramsG["Q"]  <- 119.94545987
  #G <- glf(x=L, params=paramsG)
  
  #Cap and floor G
  #G[G < 0] <- 1e-05
  #G[G > 1] <- 1.0
  
  burn_wacls_adj.x <- c(0,     50,    100,  150,  200,  250,  400,  600,  800)
  burn_wacls_adj.y <- c(1e-05, 0.25, 0.48, 0.90, 1.09, 1.17, 1.25, 1.30, 1.30)
  
  burn_wacls_adj.spl <- BuildSpline(a=burn_wacls_adj.x, b=burn_wacls_adj.y, x=L, weights=NULL, method="smooth")
  G <- burn_wacls_adj.spl$y
  
  #Test
  G <- rep(1, length(F))
    
  burnmult <- 1 - ((1 - F) * G)
  
  # Cap and floor Burnmult
  burnmult[burnmult < 0] <- 1e-05
  burnmult[burnmult > 1] <- 1.0
    
  return(burnmult)
} 
