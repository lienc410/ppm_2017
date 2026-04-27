# determine if a monotonic
isMonotonic <- function(a) {
    l = length(a) - 1
    f = a[1:l]
    b = a[1:l+1]
    diff = b - f  
    if (sum(diff>=0) == l || sum(diff<=0) == l){
        return (TRUE)
    }
    else{
        return (FALSE)
    }
} 
