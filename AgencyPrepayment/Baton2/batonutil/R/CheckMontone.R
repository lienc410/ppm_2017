#' @title Check to see if a vector is monotone increasing or decreasing
#' 
#' @description
#' \code{isMonotone} Check to see if a vector is monotone increasing or decreasing; useful in ensuring that we are selecting the
#' correct spline building utilities some of which will only work with monotone inputs.
#'  
#' @param x numeric or a complex object that can be coerced into a numeric
#' 
#' @return 
#' Boolean indicating wheter the vector is monotone or not.
#' 
#' @examples
#'  set.seed(11)
#'  isMonotone(rnorm(10))
#'  
#' @export
#'
isMonotone <- function(x) {
  
    if (class(x) == "Date") {
      x <- as.numeric(x)
    }
    
    result <- all(x == cummax(x) || x == cummin(x))
    
    return(result)
}