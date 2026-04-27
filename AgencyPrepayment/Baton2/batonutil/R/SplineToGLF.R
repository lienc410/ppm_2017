#' @title Fit spline knots using the generalized logistic function. 
#' 
#' @description
#' \code{SplineToGLF} "smoothes" a spline curve by fitting a logistic function through its points. This is frequently
#' useful in the fitting process which can produce splines with noticeable kinks and/or wobbles.
#'  
#' @param submdl  List of submodel parameters
#' 
#' @return
#' Smoothed submdl parameters
#' 
#' @examples
#'  SplineToGLF(submdl.spl)
#'  
#' @export  
SplineToGLF <- function(submdl.json, extparamsFitted=NULL) {
  
  #TO-DO: add to config file
  paramsNotFitted <- c("baselineConstant", "adjustmentFactor", "seasonalityMultipliers")
  
  if (!is.null(extparamsFitted)) {
    varNames <- extparamsFitted
  }
  else {
    varNames <- names(submdl.json)[-match(paramsNotFitted, names(submdl.json))]
  }
  
  nVar <- length(varNames)

  model.list        <- vector(mode = "list", nVar)
  names(model.list) <- varNames

  model.knots.list        <- vector(mode = "list", nVar)
  names(model.knots.list) <- varNames

  submodel <- submdl.json

  for (i in 1:nVar) {
    cat("Building GLF curve for: ", varNames[i], "\n")
    idx <- match(varNames[i], names(submodel))
    a    <- unlist(submodel[idx][[1]][1])  # Otherwise R complains about not being able to coerce a list into a double
    b    <- unlist(submodel[idx][[1]][2])
    bGLF <- BuildGLF(a=a, b=b)$glf.out$y
    submodel[idx][[1]][2] <- bGLF
 }
 
 return(submodel)

}
