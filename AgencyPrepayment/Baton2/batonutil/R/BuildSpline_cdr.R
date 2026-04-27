#' @title Construct a cubic, Hermite, or smooth spline function from given data points
#' 
#' @description
#' \code{BuildSpline} Given data points in (a, b) format, construct a cubic, Hermite or smooth spline function. 
#' This function is then used to interpolate for a more comprehensive set of x-coordinates.
#'  
#' @param a x-values for knot points
#' @param b y-values for knot points
#' @param x interpolation values for spline
#' @param weights Use weights in spline construction
#' @param method What spline to build. The three choices right now are "natural", "monoH.FC" and "smooth".
#' 
#' @return 
#' data frame with spline values
#' 
#' @examples
#'  n <- 20
#'  set.seed(11)
#'  a <- sort(runif(n)); b <- cumsum(abs(rnorm(n))); x <- round(rnorm(30), 1)
#'  BuildSpline(a, b, x, method="monoH.FC")
#'  
#' @export
#'
BuildSpline_cdr <- function(a, b, x=NA, weights = NULL, method = NULL) {
    
    if (is.null(weights)) 
        weights <- rep(1, length(a))
    
    # Don't pick the "smooth" spline option unless it's specified
    if (is.null(method)) {
        if (is.monotone(a) && is.monotone(b)){
            method <- "monoH.FC"  # Monotone Hermite spline according to the method of Fritsch-Carlson.
        }    
        else{ 
            method <- "natural"
            cat("Spline is not monotonic.", "\n")
        }    
    }
    
    if ((method == "natural") | (method == "monoH.FC")) {
      
      if (length(a) > 1) {
        f <- splinefun(as.numeric(a), b, method = method)
        y <- f(as.numeric(x))
      }
      else {
        y <- rep(b, length(x))
      }
      
      spl.data <- data.frame(x, y)
                
    } else if (method == "smooth") {
        
      if (length(a) > 3) {
            f.smooth <- smooth.spline(as.numeric(a), b, w = weights)
            spl.data <- predict(f.smooth, as.numeric(x))
      } else {
            warning("Too few points for smooth spline; using linear approximation\n")
            if (length(a) == 1) {
               y <- rep(b, length(x))
            }
            else {
               fit <- lm(b ~ as.numeric(a), weights=weights)
               y <- fit$coefficients[1] +  as.numeric(x) * fit$coefficients[2]
            }             
            spl.data <- data.frame(x, y)
      }
    }
    else {
      stop(paste("Unsupported spline method: ", method, "\n"))
    }
    
    return(spl.data)
} 
