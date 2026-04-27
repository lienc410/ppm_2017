# Generalized Logistic Function Y(x): allows for flexible S-shaped curves. It has 6 parameters: 
# A: the lower asymptote 
# K: the upper asymptote (if C = 1). Otherwise, it is (K-A)/C
# B: the growth rate 
# nu > 0: affects near which asymptote maximum growth occurs 
# Q: related to the value of the function at Y(0) 
# C: typically takes on a value of 1 but will be allowed to vary here
# See https://en.wikipedia.org/wiki/Generalised_logistic_function
glf <- function(x, params, A.ext=NULL, K.ext=NULL, C.ext=NULL, nu.ext=NULL) {
  
  if (!is.null(A.ext)) {
    params["A"] <- A.ext
  }
  
  if (!is.null(K.ext)) {
    params["K"] <- K.ext
  }
  
  if (!is.null(C.ext)) {
    params["C"] <- C.ext
  }
  
  if (!is.null(nu.ext)) {
    params["nu"] <- nu.ext
  }
  
  y <- params["A"] + (params["K"] - params["A"])/(params["C"] + params["Q"] * exp(-1 * params["B"] * x))^(1/params["nu"])
    
  return(y)
}

penaltyfn <- function(params, xvalues, yvalues, weights, A.ext=NULL, K.ext=NULL, C.ext=NULL, nu.ext=NULL) {
  
   if (is.null(weights)) 
     weights <- rep(1, length(xvalues)) 
   
   if (!is.null(A.ext)) {
     params["A"] <- A.ext
   }
   
   if (!is.null(K.ext)) {
     params["K"] <- K.ext
   }
   
   if (!is.null(C.ext)) {
     params["C"] <- C.ext
   }
   
   if (!is.null(nu.ext)) {
     params["nu"] <- nu.ext
   }
     
   r <- sum(weights * (yvalues - glf(xvalues, params))^2)
   return(r)
}

glf.start <- function(x, y, weights) {
  
  # We have strong priors for A.start, K.start, C.start, and nu.start. The idea is to make the optimizer's life easier
  # by only having to solve for B and Q. The overall goal is to come up with a good initial starting point for the full
  # scale optimization.
  C.start <- nu.start <- 1.0
  
  # Guesses for the lower and upper asymptotes assuming C=1
  
  if (y[1] < y[length(y)]) {
    if (min(y) >= 0) {
      A.start <- 0.95 * min(y)
    }
    else {
      A.start <- 1.05 * min(y)
    }
    
    if (max(y) >= 0) {
      K.start <- 1.05 * max(y)
    }
    else {
      K.start <- 0.95 * max(y)
    }
  }
  else {
    if (min(y) >= 0) {
      K.start <- 0.95 * min(y)
    }
    else {
      K.start <- 1.05 * min(y)
    }
    
    if (max(y) >= 0) {
      A.start <- 1.05 * max(y)
    }
    else {
      A.start <- 0.95 * max(y)
    }
  }
  
  
  # Strategy 1:
  # Solve for B and Q using lm since having nu=1 allows us to linearize the logistic equation through an
  # appropriate change of variables and taking logs
  z <- (y - A.start)/(K.start - A.start)
  idx <- (z <= 0)
  z[idx] <- 1e-08 # To prevent problems with division by zero or taking log of zero or a negative number
  zz <- log ((1-z)/z) # zz = log(Q) - B * x
  fit <- lm(zz ~ x)
  Q.start <- exp(fit$coefficients[1])
  B.start <- -1 * fit$coefficients[2]
  
  # Re-estimate nu given B and Q
  u <- log(1 + Q.start * exp(-1 * B.start * x))
  fit.nu <- lm(log(z) ~ u - 1)
  nu.start <- -1 * 1/fit.nu$coefficients[1]
  
  # Feed these estimates into optim as starting points  
  params.start1 <- c(A.start, K.start, B.start, C.start, nu.start, Q.start)
  names(params.start1) <- c("A", "K", "B", "C", "nu", "Q")
  
  # Set up constraints
  params.old1           <- params.start1
  params.start1        <- c(B.start, nu.start, Q.start)
  names(params.start1) <- c("B",     "nu",     "Q")
  nu.lo <- 0.1
  params.lo            <- c(0,       nu.lo,    0)
  params.hi            <- c(Inf,     Inf,      Inf)
  
  # Constrained optimizations must use method L-BFGS-B
  results <- optim(params.start1, penaltyfn, xvalues = x, yvalues = y, weights = weights, 
                   A.ext=A.start, K.ext=K.start, C.ext=C.start,
                   method=c("L-BFGS-B"), lower=params.lo, upper=params.hi, control=list(maxit=20000))
    
  y.glf1 <- glf(x = x, params = results$par, A.ext=A.start, K.ext=K.start, C.ext=C.start)
  sse1 <- sum(weights * (y.glf1 - y)^2)
    
  params.start1 <- c(A.start, K.start, B.start, C.start, nu.start, Q.start)
  names(params.start1) <- c("A", "K", "B", "C", "nu", "Q")
  params.start1["B"]   <- results$par["B"]
  params.start1["nu"]  <- results$par["nu"]
  params.start1["Q"]   <- results$par["Q"]
  
  # Strategy 2
  # Another try at coming up with a good initial guess. This uses R's selfStart guess for the logistic function.
  # The logistic function here is given by Asymp/(1 + exp((x_mid - t)/scale)) so some transformations are necessary
  # to convert into the general logistic framework.
  
  # Modeling priors
  # Reuse A.start, C.start and nu.start values from Strategy 1
  
  if (A.start < K.start) {
    z <- y - A.start
    idx <- (z <= 0)
    z[idx] <- 1e-08
    glf.df <- data.frame(x, z)
    logit.start <- getInitial(z ~ SSlogis(x, Asym, xmid, scal), data=glf.df)
    K.start <- logit.start["Asym"] + A.start
    B.start <- 1/logit.start["scal"]
    Q.start <- exp(logit.start["xmid"]/logit.start["scal"])
    
    # Feed these estimates into optim as starting points  
    params.start2 <- c(A.start, K.start, B.start, C.start, nu.start, Q.start)
    names(params.start2) <- c("A", "K", "B", "C", "nu", "Q")
  }
  else {
    params.start2 <- params.start1
    names(params.start2) <- names(params.start1)
  }
  
  # Set up constraints
  params.old2           <- params.start2
  params.start2        <- c(B.start, Q.start)
  names(params.start2) <- c("B",     "Q")
  nu.lo <- 0.1
  params.lo            <- c(0,       0)
  params.hi            <- c(Inf,   Inf)
  
  # Constrained optimizations must use method L-BFGS-B
  results <- optim(params.start2, penaltyfn, xvalues = x, yvalues = y, weights = weights, 
                   A.ext=A.start, K.ext=K.start, C.ext=C.start, nu.ext=nu.start,
                   method=c("L-BFGS-B"), lower=params.lo, upper=params.hi, control=list(maxit=20000))
  
  y.glf2 <- glf(x = x, params = results$par, A.ext=A.start, K.ext=K.start, C.ext=C.start, nu.ext=nu.start)
  sse2 <- sum(weights * (y.glf2 - y)^2)
  
  params.start2 <- c(A.start, K.start, B.start, C.start, nu.start, Q.start)
  names(params.start2) <- c("A", "K", "B", "C", "nu", "Q")
  params.start2["B"]   <- results$par["B"]
  params.start2["Q"]   <- results$par["Q"]
  
  y.glf2 <- glf(x = x, params = params.start2)
  sse2 <- sum(weights * (y.glf2 - y)^2)
  
  return(list("params.start1"=params.start1, "params.start2"=params.start2, "sse1"=sse1, "sse2"=sse2))
}

FitGLF <- function(x, y, weights=NULL) {
    
    if (is.null(weights)) 
      weights <- rep(1, length(x))
    
    # Choose a good starting point to help with the convergence of the non-linear optimization
    fit.start <- glf.start(x, y, weights)
    
    A  <- fit.start$params.start1["A"]
    K  <- fit.start$params.start1["K"]
    B  <- fit.start$params.start1["B"]
    C  <- fit.start$params.start1["C"]
    nu <- fit.start$params.start1["nu"]
    Q  <- fit.start$params.start1["Q"]
    
    # Set up constraints
    nu.lo <- 0.1
    
    if (A < K) {
      K.lo <- max(y)
      A.hi <- min(y)
      params.lo     <- c(-Inf,   K.lo,   0,    0,   nu.lo,   0)
      params.hi     <- c(A.hi,   Inf,    Inf,  Inf, Inf,     Inf)
    }
    else {
      K.hi <- min(y)
      A.lo <- max(y)
      params.lo     <- c(A.lo,  -Inf,   0,    0,   nu.lo,   0)
      params.hi     <- c(Inf,    K.hi,  Inf,  Inf, Inf,     Inf)
    }
    
    
    params.start1 <- c(A,      K,      B,    C,   nu,      Q)
    
    
    # Constrained optimizations must use method L-BFGS-B
    results <- optim(params.start1, penaltyfn, xvalues = x, yvalues = y, weights = weights,
                     method=c("L-BFGS-B"), lower=params.lo, upper=params.hi, control=list(maxit=20000))
                     
    params1 <- results$par
    
    A  <- fit.start$params.start2["A"]
    K  <- fit.start$params.start2["K"]
    B  <- fit.start$params.start2["B"]
    C  <- fit.start$params.start2["C"]
    nu <- fit.start$params.start2["nu"]
    Q  <- fit.start$params.start2["Q"]
    
    # Set up constraints
    K.lo <- max(y)
    A.hi <- min(y)
    nu.lo <- 0.1
    params.start2 <- c(A,      K,      B,    C,   nu,      Q)
    params.lo    <- c(-Inf,   K.lo,   0,    0,   nu.lo,   0)
    params.hi    <- c(A.hi,   Inf,    Inf,  Inf, Inf,     Inf)
    
    # Constrained optimizations must use method L-BFGS-B
    results <- optim(params.start2, penaltyfn, xvalues = x, yvalues = y, weights = weights,
                     method=c("L-BFGS-B"), lower=params.lo, upper=params.hi, control=list(maxit=20000))
    
    params2 <- results$par
    
    y.glf1 <- glf(x = x, params = params1)
    sse1 <- sum(weights * (y.glf1 - y)^2)
    
    y.glf2 <- glf(x = x, params = params2)
    sse2 <- sum(weights * (y.glf2 - y)^2)
    
    if (sse1 <= sse2) {
      sse <- sse1
      win <- c("first")
      params.final <- params1
    }
    else {
      sse <- sse2
      win <- c("second")
      params.final <- params2
    }
    
    return(list("params.start1"=fit.start$params.start1, "params.start2"=fit.start$params.start2,
                "params1"=params1, "params2"=params2, "sse1"=sse1, "sse2"=sse2, "params.final"=params.final,
                "win"=win))
}

# Use a set of given data points in (a, b) format to fit the parameters of a generalized logistic function.  
# This function can then be used to interpolate values for a more comprehensive set of x-coordinates if required.
BuildGLF <- function(a, b, x = NULL, weights = NULL) {
    
    if (is.null(weights)) 
        weights <- rep(1, length(a))
    
    fit.glf <- FitGLF(x = a, y = b, weights = weights)
    
    if (is.null(x)) {
        y <- glf(x = a, params = fit.glf$params.final)
        glf.data <- data.frame(a, y)
        sse <- sum(weights * (y - b)^2)
    } else {
        y <- glf(x = x, params = fit.glf$params.final)
        glf.data <- data.frame(x, y)
        sse <- NULL
    }
    
    return(list("params.final"=fit.glf$params.final, 
                "sse"=sse, "win"=fit.glf$win, "glf.output"=glf.data))
} 