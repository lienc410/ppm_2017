#' @title Tune splines 
#' 
#' @description
#'   \code{lis} finds longest non-decreasing subsequence and also returns the locations of the subsequence values
#'   in the original array. 
#'   See https://en.wikipedia.org/wiki/Longest_increasing_subsequence for details of algorithm implementation.
#'  
#' @param x  numeric vector
#' 
#' @return 
#' Longest non-decreasing subsequence and its location
#' 
#' @examples
#' \dontrun{
#'  set.seed(11)
#'  lis(rnorm(50))
#'  }
#'  
tuner <- function(x, y, option="inc") {
  # Replace negative coefficient values with near-zero values. Avoid zero since that creates division problems.
  y[y < 0] <- 1e-05
  
  # Enforce monotonicity for select splines
  if (option == "inc") {
    y.lis <- lis(y)$lis
    x.lis <- x[lis(y)$idx]
    spl.tune <- BuildSpline(a = x.lis, b = y.lis, x = x)
  }
  else {
    y.lis <- lis(-1*y)$lis
    x.lis <- x[lis(-1*y)$idx]
    spl.tune <- BuildSpline(a = x.lis, b = -1*y.lis, x = x)
  }
  spl.tune$y[spl.tune$y < 0] <- 1e-05
  
  return(spl.tune)
}