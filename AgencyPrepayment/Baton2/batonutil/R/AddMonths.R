#' Add months to a date. 
#' 
#'  \code{AddMonths} increases the month part of a date by n months (as opposed to adding a certain number of days). This works
#'  for both positive and negative n. It requires the lubridate package.
#'  
#' @param date An R-date.
#' @param n An integer.
#' @return The date shifted by n months.
#' @examples
#'  AddMonths(as.Date(c("2017-01-01")), 12)
#'  AddMonths(as.Date(c("2017-01-01")), -12)
AddMonths <- function(date, n) {
  shiftedDate <- date %m+% months(n)
  return(shiftedDate)
}