#' @title Find longest non-decreasing subsequence 
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
#' @export
lis <- function(x) {
  P <- integer(length(x))
  M <- integer(length(x) + 1)
  L <- newL <- 0  # L represents the length of the longest non-decreasing subsequence found so far
  for (i in seq_along(x) - 1) {
    # Binary search for the largest positive j <= L
    # such that X[M[j]] < X[i]
    lo <- 1
    hi <- L
    while (lo <= hi) {
      mid <- ceiling((lo + hi)/2)
      if (x[M[mid + 1] + 1] <= x[i + 1]) {
        lo <- mid + 1
      } else {
        hi <- mid - 1
      }
    }
    newL <- lo
    P[i + 1] <- M[newL]
    if (newL > L) {
      M[newL + 1] <- i
      L <- newL
    } else if (x[i + 1] <= x[M[newL + 1] + 1]) {
      M[newL + 1] <- i
    }
  }
  k <- M[L + 1]
  S <- integer(L)
  idx <- integer(L)
  for (i in L:1) {
    S[i] <- x[k + 1]
    idx[i] <- k + 1
    k <- P[k + 1]
  }
  return(list("lis"=S, "idx"=idx))
}