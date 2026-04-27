#' @title Read in prepayment data from csv files 
#' 
#' @description
#' \code{imprtr} reads in various prepayment data sets.  It also manages naming conventions and type conversions for various columns.
#' See also \code{\link{tfrmr}} for functions that perform additional data munging.
#' 
#' @details
#' \code{imprtr} reads in various aggregations (replines) of Agency MBS pool- and loan-level prepayment data.
#' The input file name and location is passed in as an argument. 
#' 
#' @param infile  Input filename and location
#' 
#' @return 
#' ppdata Prepayment data as a data frame
#' 
#' @examples
#'  imprtr(infile=RschGridFile)
#'  
#' @export

imprtr <- function(infile=NA) {
  
    if (is.na(infile)) {
      stop(paste("No input file specified!"))
    }
    
    cat("Reading input data from: ", infile, "\n")       
    
    ppdata <- data.frame(data.table::fread(infile, sep = "auto", header = TRUE, 
                                           stringsAsFactors = FALSE, showProgress = TRUE))            
    return(ppdata)
} 
