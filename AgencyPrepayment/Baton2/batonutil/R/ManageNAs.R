
ReplaceNAs <- function(data, dataColNames, replaceValues) {
    
    if (length(dataColNames) != length(replaceValues)) 
        stop("Number of column names doesn't match number of replacement values")
    
    for (k in 1:length(dataColNames)) {
        colName <- dataColNames[k]
        value <- replaceValues[k]
        
        if (colName %in% colnames(data)) {
          idx <- is.na(data[, colName])
          countNARows <- sum(idx, na.rm = TRUE)
          
          if (countNARows > 0) {
            data[, colName][idx] <- rep(value, countNARows)
            cat("Replaced", countNARows, "NA Values for", colName, "with", value, "\n")
          }
        } 
        
    }
    
    return(data)
    
}

RemoveNARows <- function(data, dataColNames) {
    
    for (colName in dataColNames) {
      if (colName %in% colnames(data)) {
        idx <- is.na(data[, colName])
        countNARows <- sum(idx, na.rm = TRUE)
        
        if (countNARows > 0) {
          data <- data[!idx, ]
          cat("Removed", countNARows, "NA Rows for", colName, "\n")
        }
      }
     
    }
    
    return(data)
} 
