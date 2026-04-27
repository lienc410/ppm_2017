#' @title Generate forecasts for a submodel of the prepayment model. Default submodel has a separate function.
#' 
#' @description
#' \code{PredictSubmodel} Generate submodel forecasts based on indicative data from a data frame.
#' The forecasts are added as columns to the data frame. Default submodel is driven by PredictDflt.
#'  
#' @param coll  Collateral type for prepayment model
#' @param submodel  Submodel for prepayment model: turn, refi, cout, dflt
#' @param submdl.spl Spline coefficients for the various variables in the model
#' @param ppdata data frame containing indicative data for the loans/pools/replines that we want projections for
#' @param seasadj Produce seasonally-adjusted forecasts if this is TRUE
#' @param version Model version. Allows flexibility in changing model specifications for different versions.
#' 
#' @return 
#' List with submodel predictions and submodel multipliers
#' 
#' @examples
#' \dontrun{
#'  PredictSubmodel(submodel="turn", submdl.spl=turn.mdl, data=ppdata, version="v4.00")
#'  }
#' 


PredictSubmodel_4_50_interpolation <- function(coll, submodel = NA, submdl.spl, data, seasadj = FALSE, version = "") {
    
    submdl.spl <- submdl.spl

    if (!any(is.na(submdl.spl))) { 

        removal_list   <-  c("baselineConstant", "adjustmentFactor", "seasonalityMultipliers")
        
        removal_list_refinance_conv   <-  c("baselineConstant", "adjustmentFactor", "seasonalityMultipliers", "media_effect", "burnout", "inv_wacls","incentive")
        
        removal_list_turnover_conv   <-  c("baselineConstant", "adjustmentFactor", "seasonalityMultipliers", "hpa_interp", "hpa_interp_U6", "hpa_interp_U9", "wala", "wala_U6", "wala_U9")
        
        removal_list_refinance_gnma   <-  c("baselineConstant", "adjustmentFactor", "seasonalityMultipliers", "media_effect", "burnout", "elbow_wacls", "fico", "incentive")
        
        removal_list_turnover_gnma   <-  c("baselineConstant", "adjustmentFactor", "seasonalityMultipliers", "hpa_interp", "purch_wala", "refi_wala")
    
    if ((submodel == "refi") & (coll == "conv30")) {
        param.submdl <- names(submdl.spl)[-match(removal_list_refinance_conv, names(submdl.spl))]
    }
    else if ((submodel == "refi") & (coll == "gnma30")) {
        param.submdl <- names(submdl.spl)[-match(removal_list_refinance_gnma, names(submdl.spl))]
    }
    else if ((submodel == "turn") & (coll == "conv30")) {
        param.submdl <- names(submdl.spl)[-match(removal_list_turnover_conv, names(submdl.spl))]
    }
    else if ((submodel == "turn") & (coll == "gnma30")) {
        param.submdl <- names(submdl.spl)[-match(removal_list_turnover_gnma, names(submdl.spl))]
    }
    else{
        param.submdl <- names(submdl.spl)[-match(removal_list, names(submdl.spl))]
    }

        mult.df <- data.frame(matrix(nrow = nrow(data), ncol = length(param.submdl)))
        names(mult.df) <- param.submdl

        submdl.pred <- rep(submdl.spl$baselineConstant, times = nrow(data))
        
        # Calculate actual multiplier values by building splines and instantiating them at the values of the data set
        for (p in param.submdl) {
            if(!(p %in% names(data))) {
            mult.df[, p] <- 1.0
            cat("ATTENTION!Missing Parameter in INPUT!", " missing: ", p, "\n")
            }
            else {
            idx <- match(p, names(submdl.spl))
            a <- unlist(submdl.spl[idx][[1]][1])  # Otherwise R complains about not being able to coerce a list into a double
            b <- unlist(submdl.spl[idx][[1]][2])
            x <- data[, p]
            mult.df[, p] <- BuildSpline(a = a, b = b, x = x)$y
            }
            #cat("parameter: ", p, "\n")
            #cat("dial: ", mult.df[1, p], "\n")
        }

        # The non-refi submodels have a simple specification as the product of spline functions
        if (submodel == "refi") {
            if (coll == "gnma30") {
              #step 1. handle burnout S curves
              burnout_submdl  <- submdl.spl$incentive$functions$functions
              names(burnout_submdl)  <-c("burnout_curves_0","burnout_curves_1","burnout_curves_2")
              
              burnout_submdl_0  <- burnout_submdl$burnout_curves_0
              burnout_submdl_1  <- burnout_submdl$burnout_curves_1
              burnout_submdl_2  <- burnout_submdl$burnout_curves_2
              names(burnout_submdl_0) <- c("first_incentive_burnout0","first_incentive_burnout1","first_incentive_burnout2","first_incentive_burnout3","first_incentive_burnout4","first_incentive_burnout5","first_incentive_burnout6","first_incentive_burnout7","first_incentive_burnout8","first_incentive_burnout9","first_incentive_burnout10","first_incentive_burnout11")
              names(burnout_submdl_1) <- c("second_incentive_burnout0","second_incentive_burnout1","second_incentive_burnout2","second_incentive_burnout3","second_incentive_burnout4","second_incentive_burnout5","second_incentive_burnout6","second_incentive_burnout7","second_incentive_burnout8","second_incentive_burnout9","second_incentive_burnout10","second_incentive_burnout11")
              names(burnout_submdl_2) <- c("third_incentive_burnout0","third_incentive_burnout1","third_incentive_burnout2","third_incentive_burnout3","third_incentive_burnout4","third_incentive_burnout5","third_incentive_burnout6","third_incentive_burnout7","third_incentive_burnout8","third_incentive_burnout9","third_incentive_burnout10","third_incentive_burnout11")
             
              burnout_list_refinance  <- c("first_incentive_burnout0","first_incentive_burnout1","first_incentive_burnout2","first_incentive_burnout3","first_incentive_burnout4","first_incentive_burnout5","first_incentive_burnout6","first_incentive_burnout7","first_incentive_burnout8","first_incentive_burnout9","first_incentive_burnout10","first_incentive_burnout11","second_incentive_burnout0","second_incentive_burnout1","second_incentive_burnout2","second_incentive_burnout3","second_incentive_burnout4","second_incentive_burnout5","second_incentive_burnout6","second_incentive_burnout7","second_incentive_burnout8","second_incentive_burnout9","second_incentive_burnout10","second_incentive_burnout11","third_incentive_burnout0","third_incentive_burnout1","third_incentive_burnout2","third_incentive_burnout3","third_incentive_burnout4","third_incentive_burnout5","third_incentive_burnout6","third_incentive_burnout7","third_incentive_burnout8","third_incentive_burnout9","third_incentive_burnout10","third_incentive_burnout11")

              burnout.df <- data.frame(matrix(nrow = nrow(ppdata), ncol = length(burnout_list_refinance)))
              names(burnout.df) <- burnout_list_refinance
             
                for (p in names(burnout_submdl_0)) {
                    if(!(p %in% names(ppdata))) {
                        burnout.df[, p] <- 1.0
                        cat("ATTENTION!Missing low media burnout shift in INPUT!", " missing: ", p, "\n")
                    }
                    else {
                        idx <- match(p, names(burnout_submdl_0))
                        a <- unlist(burnout_submdl_0[idx][[1]][1]) 
                        b <- unlist(burnout_submdl_0[idx][[1]][2])
                        x <- ppdata[, p]
                        burnout.df[, p] <- BuildSpline(a = a, b = b, x = x)$y
                    }
                }
                
                for (p in names(burnout_submdl_1)) {
                    if(!(p %in% names(ppdata))) {
                        burnout.df[, p] <- 1.0
                        cat("ATTENTION!Missing mid media burnout shift in INPUT!", " missing: ", p, "\n")
                    }
                    else {
                        idx <- match(p, names(burnout_submdl_1))
                        a <- unlist(burnout_submdl_1[idx][[1]][1]) 
                        b <- unlist(burnout_submdl_1[idx][[1]][2])
                        x <- ppdata[, p]
                        burnout.df[, p] <- BuildSpline(a = a, b = b, x = x)$y
                    }
                }
                
                for (p in names(burnout_submdl_2)) {
                    if(!(p %in% names(ppdata))) {
                        burnout.df[, p] <- 1.0
                        cat("ATTENTION!Missing high media burnout shift in INPUT!", " missing: ", p, "\n")
                    }
                    else {
                        idx <- match(p, names(burnout_submdl_2))
                        a <- unlist(burnout_submdl_2[idx][[1]][1]) 
                        b <- unlist(burnout_submdl_2[idx][[1]][2])
                        x <- ppdata[, p]
                        burnout.df[, p] <- BuildSpline(a = a, b = b, x = x)$y
                    }
                }
              burnout.df  <- data.frame(burnout.df)

			  temp1 <- data.frame(cbind(data[,"burnout_interpolation_int"], data[,"burnout_interpolation_dec"], burnout.df[,"first_incentive_burnout0"], burnout.df[,"first_incentive_burnout1"], burnout.df[,"first_incentive_burnout2"], burnout.df[,"first_incentive_burnout3"], burnout.df[,"first_incentive_burnout4"], burnout.df[,"first_incentive_burnout5"], burnout.df[,"first_incentive_burnout6"], burnout.df[,"first_incentive_burnout7"], burnout.df[,"first_incentive_burnout8"], burnout.df[,"first_incentive_burnout9"], burnout.df[,"first_incentive_burnout10"], burnout.df[,"first_incentive_burnout11"]))  
              
              names(temp1) <- c("burnout_interpolation_int","burnout_interpolation_dec","first_incentive_burnout0","first_incentive_burnout1", "first_incentive_burnout2", "first_incentive_burnout3", "first_incentive_burnout4", "first_incentive_burnout5", "first_incentive_burnout6", "first_incentive_burnout7", "first_incentive_burnout8", "first_incentive_burnout9", "first_incentive_burnout10", "first_incentive_burnout11")
              
              temp2 <- data.frame(cbind(data[,"burnout_interpolation_int"], data[,"burnout_interpolation_dec"], burnout.df[,"second_incentive_burnout0"], burnout.df[,"second_incentive_burnout1"], burnout.df[,"second_incentive_burnout2"], burnout.df[,"second_incentive_burnout3"], burnout.df[,"second_incentive_burnout4"], burnout.df[,"second_incentive_burnout5"], burnout.df[,"second_incentive_burnout6"], burnout.df[,"second_incentive_burnout7"], burnout.df[,"second_incentive_burnout8"], burnout.df[,"second_incentive_burnout9"], burnout.df[,"second_incentive_burnout10"], burnout.df[,"second_incentive_burnout11"]))   
              
              names(temp2) <- c("burnout_interpolation_int","burnout_interpolation_dec","second_incentive_burnout0","second_incentive_burnout1", "second_incentive_burnout2", "second_incentive_burnout3", "second_incentive_burnout4", "second_incentive_burnout5", "second_incentive_burnout6", "second_incentive_burnout7", "second_incentive_burnout8", "second_incentive_burnout9", "second_incentive_burnout10", "second_incentive_burnout11")
              
              temp3 <- data.frame(cbind(data[,"burnout_interpolation_int"], data[,"burnout_interpolation_dec"], burnout.df[,"third_incentive_burnout0"], burnout.df[,"third_incentive_burnout1"], burnout.df[,"third_incentive_burnout2"], burnout.df[,"third_incentive_burnout3"], burnout.df[,"third_incentive_burnout4"], burnout.df[,"third_incentive_burnout5"], burnout.df[,"third_incentive_burnout6"], burnout.df[,"third_incentive_burnout7"], burnout.df[,"third_incentive_burnout8"], burnout.df[,"third_incentive_burnout9"], burnout.df[,"third_incentive_burnout10"], burnout.df[,"third_incentive_burnout11"]))   
              
              names(temp3) <- c("burnout_interpolation_int","burnout_interpolation_dec","third_incentive_burnout0","third_incentive_burnout1", "third_incentive_burnout2", "third_incentive_burnout3", "third_incentive_burnout4", "third_incentive_burnout5", "third_incentive_burnout6", "third_incentive_burnout7", "third_incentive_burnout8", "third_incentive_burnout9", "third_incentive_burnout10", "third_incentive_burnout11")
              
              
              Burnout_Scurve_gnm <- function(x, y = 0){
                if(x[[1]] == 0){
                y = (x[[2]] * x[[4]] + (1 - x[[2]]) * x[[3]])              
                }
                else if (x[[1]] == 1){
                y = (x[[2]] * x[[5]] + (1 - x[[2]]) * x[[4]])                                            
                }
                else if (x[[1]] == 2){
                y = (x[[2]] * x[[6]] + (1 - x[[2]]) * x[[5]])                                             
                }
                else if (x[[1]] == 3){
                y = (x[[2]] * x[[7]] + (1 - x[[2]]) * x[[6]])
                }
                else if (x[[1]] == 4){
                y = (x[[2]] * x[[8]] + (1 - x[[2]]) * x[[7]])                                                  
                }
                else if (x[[1]] == 5){
                y = (x[[2]] * x[[9]] + (1 - x[[2]]) * x[[8]])
                }
                else if (x[[1]] == 6){
                y = (x[[2]] * x[[10]] + (1 - x[[2]]) * x[[9]])                                              
                }
                else if (x[[1]] == 7){
                y = (x[[2]] * x[[11]] + (1 - x[[2]]) * x[[10]])                                          
                }
				else if (x[[1]] == 8){
                y = (x[[2]] * x[[12]] + (1 - x[[2]]) * x[[11]])                                              
                }
                else if (x[[1]] == 9){
                y = (x[[2]] * x[[13]] + (1 - x[[2]]) * x[[12]])       
                }
                else if (x[[1]] == 10){
                y = (x[[2]] * x[[14]] + (1 - x[[2]]) * x[[13]])                                              
                }
                else if (x[[1]] >= 11){
                y = x[[14]]                                            
                }
                return(y)                
              }
              
              test1 <- data.frame(apply(temp1, 1, Burnout_Scurve_gnm))
              names(test1) <- c("incentive_dial_0")
              
              test2 <- data.frame(apply(temp2, 1, Burnout_Scurve_gnm))
              names(test2) <- c("incentive_dial_1")
              
              test3 <- data.frame(apply(temp3, 1, Burnout_Scurve_gnm))
              names(test3) <- c("incentive_dial_2")
             
              
              #step 2. handle fico dials
              fico_submdl   <- submdl.spl$fico$functions
              names(fico_submdl)   <- c("fico_0","fico_1","fico_2")
              fico_list_refinance  <- c("fico_0","fico_1","fico_2")

              fico_mult.df <- data.frame(matrix(nrow = nrow(ppdata), ncol = length(fico_list_refinance)))
              names(fico_mult.df) <- fico_list_refinance
             
                for (p in names(fico_submdl)) {
                    if(!(p %in% names(ppdata))) {
                        fico_mult.df[, p] <- 1.0
                        cat("ATTENTION!Missing low fico adjustment in INPUT!", " missing: ", p, "\n")
                    }
                    else {
                        idx <- match(p, names(fico_submdl))
                        a <- unlist(fico_submdl[idx][[1]][1]) 
                        b <- unlist(fico_submdl[idx][[1]][2])
                        x <- ppdata[, p]
                        fico_mult.df[, p] <- BuildSpline(a = a, b = b, x = x)$y
                    }
                }

              fico_mult.df  <- data.frame(fico_mult.df) 
              
              media_effect_0 <- fico_mult.df[,"fico_0"] * test1[,"incentive_dial_0"]
              media_effect_1 <- fico_mult.df[,"fico_1"] * test2[,"incentive_dial_1"]
              media_effect_2 <- fico_mult.df[,"fico_2"] * test3[,"incentive_dial_2"]
    
              Medial_Effect <- data.frame(cbind(data[,"media_effect_interpolation_int"], data[,"media_effect_interpolation_dec"], media_effect_0, media_effect_1, media_effect_2))
              names(Medial_Effect)  <- c("media_effect_interpolation_int","media_effect_interpolation_dec","media_effect_related_0","media_effect_related_1","media_effect_related_2")
              
               Media_Effect_Interpolation_gnm <- function(x, y = 0){
                if(x[[1]] == 0){
                y = (x[[2]] * x[[4]] + (1 - x[[2]]) * x[[3]])              
                }
                else if (x[[1]] == 1){
                y = (x[[2]] * x[[5]] + (1 - x[[2]]) * x[[4]])                                            
                }
                else if (x[[1]] >= 2){
                y = x[[5]]                                         
                }
                return(y)                
              }
              
              Media_Effect_dial <- data.frame(apply(Medial_Effect, 1, Media_Effect_Interpolation_gnm))
              names(Media_Effect_dial) <- c("media_effect_dial")
              
              #step 3. handle wacls adjustment
                                                
              submdl.pred <- submdl.pred * mult.df[, "cltv"] * mult.df[, "wala"] * mult.df[, "pct_second_lien"] * mult.df[, "low_fico_adjustment"] * mult.df[, "wacls"] * 
              ((mult.df[, "NY_wacls"] * data[, "pct_NY"] + 1.0 * (100 - data[, "pct_NY"]))/100) * 
              Media_Effect_dial[,"media_effect_dial"]                                                  
            }
            else {
              #step 1: handle tpo wacls dials
              nonRetail_wacls_0 <- submdl.spl$incentive$functions$functions[[1]]$functions[1][[1]]["nonRetail"]
              nonRetail_wacls_1 <- submdl.spl$incentive$functions$functions[[2]]$functions[1][[1]]["nonRetail"]
              nonRetail_wacls_2 <- submdl.spl$incentive$functions$functions[[3]]$functions[1][[1]]["nonRetail"]
              nonretail_submdl  <- c(nonRetail_wacls_0,nonRetail_wacls_1,nonRetail_wacls_2)
              
              broker_wacls_0 <- submdl.spl$incentive$functions$functions[[1]]$functions[1][[1]]["broker"]
              broker_wacls_1 <- submdl.spl$incentive$functions$functions[[2]]$functions[1][[1]]["broker"]
              broker_wacls_2 <- submdl.spl$incentive$functions$functions[[3]]$functions[1][[1]]["broker"]
              broker_submdl  <- c(broker_wacls_0,broker_wacls_1,broker_wacls_2)
              
              corres_wacls_0 <- submdl.spl$incentive$functions$functions[[1]]$functions[1][[1]]["corres"]
              corres_wacls_1 <- submdl.spl$incentive$functions$functions[[2]]$functions[1][[1]]["corres"]
              corres_wacls_2 <- submdl.spl$incentive$functions$functions[[3]]$functions[1][[1]]["corres"]
              corres_submdl  <- c(corres_wacls_0,corres_wacls_1,corres_wacls_2)
              
              retailCashWindow_wacls_0 <- submdl.spl$incentive$functions$functions[[1]]$functions[1][[1]]["retailCashWindow"]
              retailCashWindow_wacls_1 <- submdl.spl$incentive$functions$functions[[2]]$functions[1][[1]]["retailCashWindow"]
              retailCashWindow_wacls_2 <- submdl.spl$incentive$functions$functions[[3]]$functions[1][[1]]["retailCashWindow"]
              retailCashWindow_submdl  <- c(retailCashWindow_wacls_0,retailCashWindow_wacls_1,retailCashWindow_wacls_2)
              
              retailNonCashWindow_wacls_0 <- submdl.spl$incentive$functions$functions[[1]]$functions[1][[1]]["retailNonCashWindow"]
              retailNonCashWindow_wacls_1 <- submdl.spl$incentive$functions$functions[[2]]$functions[1][[1]]["retailNonCashWindow"]
              retailNonCashWindow_wacls_2 <- submdl.spl$incentive$functions$functions[[3]]$functions[1][[1]]["retailNonCashWindow"]
              retailNonCashWindow_submdl  <- c(retailNonCashWindow_wacls_0,retailNonCashWindow_wacls_1,retailNonCashWindow_wacls_2)
            
              names(nonretail_submdl)   <- c("nonRetail_wacls_0","nonRetail_wacls_1","nonRetail_wacls_2")
              names(broker_submdl)      <- c("broker_wacls_0","broker_wacls_1","broker_wacls_2")
              names(corres_submdl)      <- c("corres_wacls_0","corres_wacls_1","corres_wacls_2")
              names(retailCashWindow_submdl)      <- c("retailCashWindow_wacls_0","retailCashWindow_wacls_1","retailCashWindow_wacls_2")
              names(retailNonCashWindow_submdl)      <- c("retailNonCashWindow_wacls_0","retailNonCashWindow_wacls_1","retailNonCashWindow_wacls_2")
           
              tpo_list_refinance  <- c("nonRetail_wacls_0","nonRetail_wacls_1","nonRetail_wacls_2","broker_wacls_0","broker_wacls_1","broker_wacls_2","corres_wacls_0","corres_wacls_1","corres_wacls_2","retailCashWindow_wacls_0","retailCashWindow_wacls_1","retailCashWindow_wacls_2","retailNonCashWindow_wacls_0","retailNonCashWindow_wacls_1","retailNonCashWindow_wacls_2")
            
              tpo.df <- data.frame(matrix(nrow = nrow(ppdata), ncol = length(tpo_list_refinance)))
              names(tpo.df) <- tpo_list_refinance         
                for (p in names(nonretail_submdl)) {
                    if(!(p %in% names(ppdata))) {
                        tpo.df[, p] <- 1.0
                        cat("ATTENTION!Missing nonretail in INPUT!", " missing: ", p, "\n")
                    }
                    else {
                        idx <- match(p, names(nonretail_submdl))
                        a <- unlist(nonretail_submdl[idx][[1]][1]) 
                        b <- unlist(nonretail_submdl[idx][[1]][2])
                        x <- ppdata[, p]
                        tpo.df[, p] <- BuildSpline(a = a, b = b, x = x)$y
                    }
                }
                for (p in names(broker_submdl)) {
                    if(!(p %in% names(ppdata))) {
                        tpo.df[, p] <- 1.0
                        cat("ATTENTION!Missing broker in INPUT!", " missing: ", p, "\n")
                    }
                    else {
                        idx <- match(p, names(broker_submdl))
                        a <- unlist(broker_submdl[idx][[1]][1]) 
                        b <- unlist(broker_submdl[idx][[1]][2])
                        x <- ppdata[, p]
                        tpo.df[, p] <- BuildSpline(a = a, b = b, x = x)$y
                    }
                }
                for (p in names(corres_submdl)) {
                    if(!(p %in% names(ppdata))) {
                        tpo.df[, p] <- 1.0
                        cat("ATTENTION!Missing corres in INPUT!", " missing: ", p, "\n")
                    }
                    else {
                        idx <- match(p, names(corres_submdl))
                        a <- unlist(corres_submdl[idx][[1]][1]) 
                        b <- unlist(corres_submdl[idx][[1]][2])
                        x <- ppdata[, p]
                        tpo.df[, p] <- BuildSpline(a = a, b = b, x = x)$y
                    }
                }
                for (p in names(retailCashWindow_submdl)) {
                    if(!(p %in% names(ppdata))) {
                        tpo.df[, p] <- 1.0
                        cat("ATTENTION!Missing retailCashWindow in INPUT!", " missing: ", p, "\n")
                    }
                    else {
                        idx <- match(p, names(retailCashWindow_submdl))
                        a <- unlist(retailCashWindow_submdl[idx][[1]][1]) 
                        b <- unlist(retailCashWindow_submdl[idx][[1]][2])
                        x <- ppdata[, p]
                        tpo.df[, p] <- BuildSpline(a = a, b = b, x = x)$y
                    }
                }
                for (p in names(retailNonCashWindow_submdl)) {
                    if(!(p %in% names(ppdata))) {
                        tpo.df[, p] <- 1.0
                        cat("ATTENTION!Missing retailNonCashWindow in INPUT!", " missing: ", p, "\n")
                    }
                    else {
                        idx <- match(p, names(retailNonCashWindow_submdl))
                        a <- unlist(retailNonCashWindow_submdl[idx][[1]][1]) 
                        b <- unlist(retailNonCashWindow_submdl[idx][[1]][2])
                        x <- ppdata[, p]
                        tpo.df[, p] <- BuildSpline(a = a, b = b, x = x)$y
                    }
                }

              tpo.df  <- data.frame(tpo.df) 
              
              tpo.df$tpo_dial_0  <- (ppdata$pct_NonRETAIL * tpo.df$nonRetail_wacls_0 + ppdata$pct_BROKER * tpo.df$broker_wacls_0 + ppdata$pct_CORRES * tpo.df$corres_wacls_0 + ppdata$pct_RETAIL_CashWindow * tpo.df$retailCashWindow_wacls_0 + ppdata$pct_RETAIL_NonCashWindow * tpo.df$retailNonCashWindow_wacls_0) / 100
              
              tpo.df$tpo_dial_1  <- (ppdata$pct_NonRETAIL * tpo.df$nonRetail_wacls_1 + ppdata$pct_BROKER * tpo.df$broker_wacls_1 + ppdata$pct_CORRES * tpo.df$corres_wacls_1 + ppdata$pct_RETAIL_CashWindow * tpo.df$retailCashWindow_wacls_1 + ppdata$pct_RETAIL_NonCashWindow * tpo.df$retailNonCashWindow_wacls_1) / 100
              
              tpo.df$tpo_dial_2  <- (ppdata$pct_NonRETAIL * tpo.df$nonRetail_wacls_2 + ppdata$pct_BROKER * tpo.df$broker_wacls_2 + ppdata$pct_CORRES * tpo.df$corres_wacls_2 + ppdata$pct_RETAIL_CashWindow * tpo.df$retailCashWindow_wacls_2 + ppdata$pct_RETAIL_NonCashWindow * tpo.df$retailNonCashWindow_wacls_2) / 100
              
              #step 2: handle loanPurposeType wacls dials
              purch_oltv_0 <- submdl.spl$incentive$functions$functions[[1]]$functions[2][[1]]["purch"]
              purch_oltv_1 <- submdl.spl$incentive$functions$functions[[2]]$functions[2][[1]]["purch"]
              purch_oltv_2 <- submdl.spl$incentive$functions$functions[[3]]$functions[2][[1]]["purch"]
              purch_submdl  <- c(purch_oltv_0,purch_oltv_1,purch_oltv_2)
              
              refi_HARP_oltv_0 <- submdl.spl$incentive$functions$functions[[1]]$functions[2][[1]]["refiHARP"]
              refi_HARP_oltv_1 <- submdl.spl$incentive$functions$functions[[2]]$functions[2][[1]]["refiHARP"]
              refi_HARP_oltv_2 <- submdl.spl$incentive$functions$functions[[3]]$functions[2][[1]]["refiHARP"]
              refiHARP_submdl  <- c(refi_HARP_oltv_0,refi_HARP_oltv_1,refi_HARP_oltv_2)
              
              refi_NonHARP_oltv_0 <- submdl.spl$incentive$functions$functions[[1]]$functions[2][[1]]["refiNonHARP"]
              refi_NonHARP_oltv_1 <- submdl.spl$incentive$functions$functions[[2]]$functions[2][[1]]["refiNonHARP"]
              refi_NonHARP_oltv_2 <- submdl.spl$incentive$functions$functions[[3]]$functions[2][[1]]["refiNonHARP"]
              refiNonHARP_submdl  <- c(refi_NonHARP_oltv_0,refi_NonHARP_oltv_1,refi_NonHARP_oltv_2)
            
              names(purch_submdl)   <- c("purch_oltv_0","purch_oltv_1","purch_oltv_2")
              names(refiHARP_submdl)      <- c("refi_HARP_oltv_0","refi_HARP_oltv_1","refi_HARP_oltv_2")
              names(refiNonHARP_submdl)      <- c("refi_NonHARP_oltv_0","refi_NonHARP_oltv_1","refi_NonHARP_oltv_2")
           
              loanPurposeType_list_refinance  <- c("purch_oltv_0","purch_oltv_1","purch_oltv_2","refi_HARP_oltv_0","refi_HARP_oltv_1","refi_HARP_oltv_2","refi_NonHARP_oltv_0","refi_NonHARP_oltv_1","refi_NonHARP_oltv_2")
            
              purpose.df <- data.frame(matrix(nrow = nrow(ppdata), ncol = length(loanPurposeType_list_refinance)))
              names(purpose.df) <- loanPurposeType_list_refinance
                            
                for (p in names(purch_submdl)) {
                    if(!(p %in% names(ppdata))) {
                        purpose.df[, p] <- 1.0
                        cat("ATTENTION!Missing purch_oltv in INPUT!", " missing: ", p, "\n")
                    }
                    else {
                        idx <- match(p, names(purch_submdl))
                        a <- unlist(purch_submdl[idx][[1]][1]) 
                        b <- unlist(purch_submdl[idx][[1]][2])
                        x <- ppdata[, p]
                        purpose.df[, p] <- BuildSpline(a = a, b = b, x = x)$y
                    }
                }

                for (p in names(refiHARP_submdl)) {
                    if(!(p %in% names(ppdata))) {
                        purpose.df[, p] <- 1.0
                        cat("ATTENTION!Missing refiHARP_oltv in INPUT!", " missing: ", p, "\n")
                    }
                    else {
                        idx <- match(p, names(refiHARP_submdl))
                        a <- unlist(refiHARP_submdl[idx][[1]][1]) 
                        b <- unlist(refiHARP_submdl[idx][[1]][2])
                        x <- ppdata[, p]
                        purpose.df[, p] <- BuildSpline(a = a, b = b, x = x)$y
                    }
                }

                for (p in names(refiNonHARP_submdl)) {
                    if(!(p %in% names(ppdata))) {
                        purpose.df[, p] <- 1.0
                        cat("ATTENTION!Missing refiNonHARP_oltv in INPUT!", " missing: ", p, "\n")
                    }
                    else {
                        idx <- match(p, names(refiNonHARP_submdl))
                        a <- unlist(refiNonHARP_submdl[idx][[1]][1]) 
                        b <- unlist(refiNonHARP_submdl[idx][[1]][2])
                        x <- ppdata[, p]
                        purpose.df[, p] <- BuildSpline(a = a, b = b, x = x)$y
                    }
                }


              purpose.df  <- data.frame(purpose.df) 
              
              purpose.df$purpose_dial_0  <- (ppdata$pct_purchase * purpose.df$purch_oltv_0 + ppdata$pct_HARPed * purpose.df$refi_HARP_oltv_0 + (100 - ppdata$pct_purchase - ppdata$pct_HARPed) * purpose.df$refi_NonHARP_oltv_0) / 100
              
              purpose.df$purpose_dial_1  <- (ppdata$pct_purchase * purpose.df$purch_oltv_1 + ppdata$pct_HARPed * purpose.df$refi_HARP_oltv_1 + (100 - ppdata$pct_purchase - ppdata$pct_HARPed) * purpose.df$refi_NonHARP_oltv_1) / 100
              
              purpose.df$purpose_dial_2  <- (ppdata$pct_purchase * purpose.df$purch_oltv_2 + ppdata$pct_HARPed * purpose.df$refi_HARP_oltv_2 + (100 - ppdata$pct_purchase - ppdata$pct_HARPed) * purpose.df$refi_NonHARP_oltv_2) / 100
              
              #step 3: handle inv wacls dials
              inv_submdl  <- submdl.spl$inv_wacls$functions
            
              names(inv_submdl)   <- c("inv_wacls_0","inv_wacls_1","inv_wacls_2")
           
              inv_list_refinance  <- c("inv_wacls_0","inv_wacls_1","inv_wacls_2")
            
              inv_wacls.df <- data.frame(matrix(nrow = nrow(ppdata), ncol = length(inv_list_refinance)))
              names(inv_wacls.df) <- inv_list_refinance
                            
                for (p in names(inv_submdl)) {
                    if(!(p %in% names(ppdata))) {
                        inv_wacls.df[, p] <- 1.0
                        cat("ATTENTION!Missing inv_wacls in INPUT!", " missing: ", p, "\n")
                    }
                    else {
                        idx <- match(p, names(inv_submdl))
                        a <- unlist(inv_submdl[idx][[1]][1]) 
                        b <- unlist(inv_submdl[idx][[1]][2])
                        x <- ppdata[, p]
                        inv_wacls.df[, p] <- BuildSpline(a = a, b = b, x = x)$y
                    }
                }


              inv_wacls.df  <- data.frame(inv_wacls.df) 
              
              inv_wacls.df$inv_dial_0  <- (inv_wacls.df$inv_wacls_0 * ppdata$pct_inv + (100 - ppdata$pct_inv) * 1.0) / 100
              
              inv_wacls.df$inv_dial_1  <- (inv_wacls.df$inv_wacls_1 * ppdata$pct_inv + (100 - ppdata$pct_inv) * 1.0) / 100
              
              inv_wacls.df$inv_dial_2  <- (inv_wacls.df$inv_wacls_2 * ppdata$pct_inv + (100 - ppdata$pct_inv) * 1.0) / 100
              
              #step 4: handle burnout dials
              burnout_submdl_0  <- submdl.spl$incentive$functions$functions[1][[1]]$functions[3][[1]]
              burnout_submdl_1  <- submdl.spl$incentive$functions$functions[2][[1]]$functions[3][[1]]
              burnout_submdl_2  <- submdl.spl$incentive$functions$functions[3][[1]]$functions[3][[1]]
              
              names(burnout_submdl_0) <- c("first_incentive_burnout0","first_incentive_burnout1","first_incentive_burnout2","first_incentive_burnout3","first_incentive_burnout4","first_incentive_burnout5","first_incentive_burnout6","first_incentive_burnout7","first_incentive_burnout8","first_incentive_burnout9","first_incentive_burnout10","first_incentive_burnout11")
              names(burnout_submdl_1) <- c("second_incentive_burnout0","second_incentive_burnout1","second_incentive_burnout2","second_incentive_burnout3","second_incentive_burnout4","second_incentive_burnout5","second_incentive_burnout6","second_incentive_burnout7","second_incentive_burnout8","second_incentive_burnout9","second_incentive_burnout10","second_incentive_burnout11")
              names(burnout_submdl_2) <- c("third_incentive_burnout0","third_incentive_burnout1","third_incentive_burnout2","third_incentive_burnout3","third_incentive_burnout4","third_incentive_burnout5","third_incentive_burnout6","third_incentive_burnout7","third_incentive_burnout8","third_incentive_burnout9","third_incentive_burnout10","third_incentive_burnout11")
             
              burnout_list_refinance  <- c("first_incentive_burnout0","first_incentive_burnout1","first_incentive_burnout2","first_incentive_burnout3","first_incentive_burnout4","first_incentive_burnout5","first_incentive_burnout6","first_incentive_burnout7","first_incentive_burnout8","first_incentive_burnout9","first_incentive_burnout10","first_incentive_burnout11","second_incentive_burnout0","second_incentive_burnout1","second_incentive_burnout2","second_incentive_burnout3","second_incentive_burnout4","second_incentive_burnout5","second_incentive_burnout6","second_incentive_burnout7","second_incentive_burnout8","second_incentive_burnout9","second_incentive_burnout10","second_incentive_burnout11","third_incentive_burnout0","third_incentive_burnout1","third_incentive_burnout2","third_incentive_burnout3","third_incentive_burnout4","third_incentive_burnout5","third_incentive_burnout6","third_incentive_burnout7","third_incentive_burnout8","third_incentive_burnout9","third_incentive_burnout10","third_incentive_burnout11")

              burnout.df <- data.frame(matrix(nrow = nrow(ppdata), ncol = length(burnout_list_refinance)))
              names(burnout.df) <- burnout_list_refinance
             
                for (p in names(burnout_submdl_0)) {
                    if(!(p %in% names(ppdata))) {
                        burnout.df[, p] <- 1.0
                        cat("ATTENTION!Missing low media burnout shift in INPUT!", " missing: ", p, "\n")
                    }
                    else {
                        idx <- match(p, names(burnout_submdl_0))
                        a <- unlist(burnout_submdl_0[idx][[1]][1]) 
                        b <- unlist(burnout_submdl_0[idx][[1]][2])
                        x <- ppdata[, p]
                        burnout.df[, p] <- BuildSpline(a = a, b = b, x = x)$y
                    }
                }
                
                for (p in names(burnout_submdl_1)) {
                    if(!(p %in% names(ppdata))) {
                        burnout.df[, p] <- 1.0
                        cat("ATTENTION!Missing mid media burnout shift in INPUT!", " missing: ", p, "\n")
                    }
                    else {
                        idx <- match(p, names(burnout_submdl_1))
                        a <- unlist(burnout_submdl_1[idx][[1]][1]) 
                        b <- unlist(burnout_submdl_1[idx][[1]][2])
                        x <- ppdata[, p]
                        burnout.df[, p] <- BuildSpline(a = a, b = b, x = x)$y
                    }
                }
                
                for (p in names(burnout_submdl_2)) {
                    if(!(p %in% names(ppdata))) {
                        burnout.df[, p] <- 1.0
                        cat("ATTENTION!Missing high media burnout shift in INPUT!", " missing: ", p, "\n")
                    }
                    else {
                        idx <- match(p, names(burnout_submdl_2))
                        a <- unlist(burnout_submdl_2[idx][[1]][1]) 
                        b <- unlist(burnout_submdl_2[idx][[1]][2])
                        x <- ppdata[, p]
                        burnout.df[, p] <- BuildSpline(a = a, b = b, x = x)$y
                    }
                }
              burnout.df  <- data.frame(burnout.df)

			  temp1 <- data.frame(cbind(data[,"burnout_interpolation_int"], data[,"burnout_interpolation_dec"], burnout.df[,"first_incentive_burnout0"], burnout.df[,"first_incentive_burnout1"], burnout.df[,"first_incentive_burnout2"], burnout.df[,"first_incentive_burnout3"], burnout.df[,"first_incentive_burnout4"], burnout.df[,"first_incentive_burnout5"], burnout.df[,"first_incentive_burnout6"], burnout.df[,"first_incentive_burnout7"], burnout.df[,"first_incentive_burnout8"], burnout.df[,"first_incentive_burnout9"], burnout.df[,"first_incentive_burnout10"], burnout.df[,"first_incentive_burnout11"]))  
              
              names(temp1) <- c("burnout_interpolation_int","burnout_interpolation_dec","first_incentive_burnout0","first_incentive_burnout1", "first_incentive_burnout2", "first_incentive_burnout3", "first_incentive_burnout4", "first_incentive_burnout5", "first_incentive_burnout6", "first_incentive_burnout7", "first_incentive_burnout8", "first_incentive_burnout9","first_incentive_burnout10","first_incentive_burnout11")
              
              temp2 <- data.frame(cbind(data[,"burnout_interpolation_int"], data[,"burnout_interpolation_dec"], burnout.df[,"second_incentive_burnout0"], burnout.df[,"second_incentive_burnout1"], burnout.df[,"second_incentive_burnout2"], burnout.df[,"second_incentive_burnout3"], burnout.df[,"second_incentive_burnout4"], burnout.df[,"second_incentive_burnout5"], burnout.df[,"second_incentive_burnout6"], burnout.df[,"second_incentive_burnout7"], burnout.df[,"second_incentive_burnout8"], burnout.df[,"second_incentive_burnout9"],burnout.df[,"second_incentive_burnout10"],burnout.df[,"second_incentive_burnout11"]))   
              
              names(temp2) <- c("burnout_interpolation_int","burnout_interpolation_dec","second_incentive_burnout0","second_incentive_burnout1", "second_incentive_burnout2", "second_incentive_burnout3", "second_incentive_burnout4", "second_incentive_burnout5", "second_incentive_burnout6", "second_incentive_burnout7", "second_incentive_burnout8", "second_incentive_burnout9","second_incentive_burnout10","second_incentive_burnout11")
              
              temp3 <- data.frame(cbind(data[,"burnout_interpolation_int"], data[,"burnout_interpolation_dec"], burnout.df[,"third_incentive_burnout0"], burnout.df[,"third_incentive_burnout1"], burnout.df[,"third_incentive_burnout2"], burnout.df[,"third_incentive_burnout3"], burnout.df[,"third_incentive_burnout4"], burnout.df[,"third_incentive_burnout5"], burnout.df[,"third_incentive_burnout6"], burnout.df[,"third_incentive_burnout7"], burnout.df[,"third_incentive_burnout8"], burnout.df[,"third_incentive_burnout9"],burnout.df[,"third_incentive_burnout10"],burnout.df[,"third_incentive_burnout11"]))   
              
              names(temp3) <- c("burnout_interpolation_int","burnout_interpolation_dec","third_incentive_burnout0","third_incentive_burnout1", "third_incentive_burnout2", "third_incentive_burnout3", "third_incentive_burnout4", "third_incentive_burnout5", "third_incentive_burnout6", "third_incentive_burnout7", "third_incentive_burnout8", "third_incentive_burnout9","third_incentive_burnout10","third_incentive_burnout11")
              
              
              Burnout_Scurve_fhl <- function(x, y = 0){
                if(x[[1]] == 0){
                y = (x[[2]] * x[[4]] + (1 - x[[2]]) * x[[3]])              
                }
                else if (x[[1]] == 1){
                y = (x[[2]] * x[[5]] + (1 - x[[2]]) * x[[4]])                                            
                }
                else if (x[[1]] == 2){
                y = (x[[2]] * x[[6]] + (1 - x[[2]]) * x[[5]])                                             
                }
                else if (x[[1]] == 3){
                y = (x[[2]] * x[[7]] + (1 - x[[2]]) * x[[6]])
                }
                else if (x[[1]] == 4){
                y = (x[[2]] * x[[8]] + (1 - x[[2]]) * x[[7]])                                                  
                }
                else if (x[[1]] == 5){
                y = (x[[2]] * x[[9]] + (1 - x[[2]]) * x[[8]])
                }
                else if (x[[1]] == 6){
                y = (x[[2]] * x[[10]] + (1 - x[[2]]) * x[[9]])                                              
                }
                else if (x[[1]] == 7){
                y = (x[[2]] * x[[11]] + (1 - x[[2]]) * x[[10]])                                          
                }
				else if (x[[1]] == 8){
                y = (x[[2]] * x[[12]] + (1 - x[[2]]) * x[[11]])                                              
                }
                else if (x[[1]] == 9){
                y = (x[[2]] * x[[13]] + (1 - x[[2]]) * x[[12]])       
                }
                else if (x[[1]] == 10){
                y = (x[[2]] * x[[14]] + (1 - x[[2]]) * x[[13]])                                              
                }
                else if (x[[1]] >= 11){
                y = x[[14]]                                             
                }
                return(y)                
              }
              
              test1 <- data.frame(apply(temp1, 1, Burnout_Scurve_fhl))
              names(test1) <- c("incentive_dial_0")
              
              test2 <- data.frame(apply(temp2, 1, Burnout_Scurve_fhl))
              names(test2) <- c("incentive_dial_1")
              
              test3 <- data.frame(apply(temp3, 1, Burnout_Scurve_fhl))
              names(test3) <- c("incentive_dial_2")
              
              
              media_effect_0 <- tpo.df[,"tpo_dial_0"] * purpose.df[,"purpose_dial_0"] * inv_wacls.df[,"inv_dial_0"] * test1[,"incentive_dial_0"]
              media_effect_1 <- tpo.df[,"tpo_dial_1"] * purpose.df[,"purpose_dial_1"] * inv_wacls.df[,"inv_dial_1"] * test2[,"incentive_dial_1"]
              media_effect_2 <- tpo.df[,"tpo_dial_2"] * purpose.df[,"purpose_dial_2"] * inv_wacls.df[,"inv_dial_2"] * test3[,"incentive_dial_2"]
  
              
              Medial_Effect <- data.frame(cbind(data[,"media_effect_interpolation_int"], data[,"media_effect_interpolation_dec"], media_effect_0, media_effect_1, media_effect_2))
              names(Medial_Effect)  <- c("media_effect_interpolation_int","media_effect_interpolation_dec","media_effect_related_0","media_effect_related_1","media_effect_related_2")
              
               Media_Effect_Interpolation_fhl <- function(x, y = 0){
                if(x[[1]] == 0){
                y = (x[[2]] * x[[4]] + (1 - x[[2]]) * x[[3]])              
                }
                else if (x[[1]] == 1){
                y = (x[[2]] * x[[5]] + (1 - x[[2]]) * x[[4]])                                            
                }
                else if (x[[1]] >= 2){
                y = x[[5]]                                         
                }
                return(y)                
              }
              
              Medial_Effect_dial <- data.frame(apply(Medial_Effect, 1, Media_Effect_Interpolation_fhl))
              names(Medial_Effect_dial) <- c("media_effect_dial")
			 
              submdl.pred <- submdl.pred * mult.df[, "cltv"] * mult.df[, "refi_elig_pct"] * mult.df[, "wala"] * mult.df[, "pct_second_lien"] * mult.df[, "fico"] * mult.df[, "wacls"] * Medial_Effect_dial[,"media_effect_dial"] *
                ((mult.df[, "preHARP_wacls"] * data[, "pct_preHARP"] + 1.0 * (100 - data[, "pct_preHARP"]))/100) *
                ((mult.df[, "NY_wacls"] * data[, "pct_NY"] + 1.0 * (100 - data[, "pct_NY"]))/100)
                       
            }
        }
        else if ((submodel == "turn") & (coll == "conv30")) {       
              wala_submdl        <- submdl.spl$wala$functions
              wala_submdl_U6     <- submdl.spl$wala_U6$functions
              wala_submdl_U9     <- submdl.spl$wala_U9$functions
            
              names(wala_submdl)         <- c("lohpa_wala","hihpa_wala")
              names(wala_submdl_U6)      <- c("lohpa_wala_U6","hihpa_wala_U6")
              names(wala_submdl_U9)      <- c("lohpa_wala_U9","hihpa_wala_U9")
           
              wala_list_turnover  <- c("lohpa_wala","hihpa_wala","lohpa_wala_U6","hihpa_wala_U6","lohpa_wala_U9","hihpa_wala_U9")
            
              wala.df <- data.frame(matrix(nrow = nrow(ppdata), ncol = length(wala_list_turnover)))
              names(wala.df) <- wala_list_turnover
                            
                for (p in names(wala_submdl)) {
                    if(!(p %in% names(ppdata))) {
                        wala.df[, p] <- 1.0
                        cat("ATTENTION!Missing wala in INPUT!", " missing: ", p, "\n")
                    }
                    else {
                        idx <- match(p, names(wala_submdl))
                        a <- unlist(wala_submdl[idx][[1]][1]) 
                        b <- unlist(wala_submdl[idx][[1]][2])
                        x <- ppdata[, p]
                        wala.df[, p] <- BuildSpline(a = a, b = b, x = x)$y
                    }
                }

                for (p in names(wala_submdl_U6)) {
                    if(!(p %in% names(ppdata))) {
                        wala.df[, p] <- 1.0
                        cat("ATTENTION!Missing wala_U6 in INPUT!", " missing: ", p, "\n")
                    }
                    else {
                        idx <- match(p, names(wala_submdl_U6))
                        a <- unlist(wala_submdl_U6[idx][[1]][1]) 
                        b <- unlist(wala_submdl_U6[idx][[1]][2])
                        x <- ppdata[, p]
                        wala.df[, p] <- BuildSpline(a = a, b = b, x = x)$y
                    }
                }

                for (p in names(wala_submdl_U9)) {
                    if(!(p %in% names(ppdata))) {
                        wala.df[, p] <- 1.0
                        cat("ATTENTION!Missing wala_U9 in INPUT!", " missing: ", p, "\n")
                    }
                    else {
                        idx <- match(p, names(wala_submdl_U9))
                        a <- unlist(wala_submdl_U9[idx][[1]][1]) 
                        b <- unlist(wala_submdl_U9[idx][[1]][2])
                        x <- ppdata[, p]
                        wala.df[, p] <- BuildSpline(a = a, b = b, x = x)$y
                    }
                }


              wala.df  <- data.frame(wala.df) 
              
              wala.df$wala      <- (1.0 - ppdata$hpa_interpolation) * wala.df$lohpa_wala + ppdata$hpa_interpolation * wala.df$hihpa_wala
              wala.df$wala_U6   <- (1.0 - ppdata$hpa_interpolation_U6) * wala.df$lohpa_wala_U6 + ppdata$hpa_interpolation_U6 * wala.df$hihpa_wala_U6
              wala.df$wala_U9   <- (1.0 - ppdata$hpa_interpolation_U9) * wala.df$lohpa_wala_U9 + ppdata$hpa_interpolation_U9 * wala.df$hihpa_wala_U9
              
              wala.df$wala_mult <- (ppdata$pct_FGU6 * wala.df$wala_U6 + ppdata$pct_FGU9 * wala.df$wala_U9 + (100 - ppdata$pct_FGU6 - ppdata$pct_FGU9) * wala.df$wala) / 100
              
            
            submdl.pred <- submdl.pred * mult.df[, "hpa_annual"] * mult.df[, "incentive"] * mult.df[, "cltv"] * mult.df[, "fico"] *mult.df[, "tax"] *mult.df[, "pct_second_lien"] * mult.df[, "acls"] * wala.df[, "wala_mult"] *
              ((mult.df[, "nonRetail_acls"] * data[, "pct_NonRETAIL"] + mult.df[, "broker_acls"] * data[, "pct_BROKER"] + mult.df[, "corres_acls"] * data[, "pct_CORRES"] + mult.df[, "retailCashWindow_acls"] * data[, "pct_RETAIL_CashWindow"] + mult.df[, "retailNonCashWindow_acls"] * data[, "pct_RETAIL_NonCashWindow"])/100) *
              ((mult.df[, "purch_oltv"] * data[, "pct_purchase"] + mult.df[, "refi_HARP_oltv"] * data[, "pct_HARPed"] + mult.df[, "refi_NonHARP_oltv"] * (100 - data[, "pct_purchase"] - data[, "pct_HARPed"]))/ 100) *
              ((mult.df[, "preHARP_acls"] * data[, "pct_preHARP"] + 1.0 * (100 - data[, "pct_preHARP"]))/100) *
              ((mult.df[, "NY_acls"] * data[, "pct_NY"] + 1.0 * (100 - data[, "pct_NY"]))/100) *
              ((mult.df[, "inv_acls"] * data[, "pct_inv"] + 1.0 * (100 - data[, "pct_inv"]))/100) *
              (mult.df[, "fico_acls_interact_2_fico"] * mult.df[, "fico_acls_interact_1_acls"] + 1 *(1 - mult.df[, "fico_acls_interact_2_fico"]))        
        }      
        else if ((submodel == "turn") & (coll == "gnma30")) {
        
              purch_wala_submdl                 <- submdl.spl$purch_wala$functions
              names(purch_wala_submdl)          <- c("purch_lohpa_wala","purch_hihpa_wala")
              
              refi_wala_submdl                 <- submdl.spl$purch_wala$functions
              names(refi_wala_submdl)          <- c("refi_lohpa_wala","refi_hihpa_wala")
           
              wala_list_turnover  <- c("purch_lohpa_wala","purch_hihpa_wala","refi_lohpa_wala","refi_hihpa_wala")
            
              wala.df <- data.frame(matrix(nrow = nrow(ppdata), ncol = length(wala_list_turnover)))
              names(wala.df) <- wala_list_turnover
              
                            
                for (p in names(purch_wala_submdl)) {
                    if(!(p %in% names(ppdata))) {
                        wala.df[, p] <- 1.0
                        cat("ATTENTION!Missing purchase wala in INPUT!", " missing: ", p, "\n")
                    }
                    else {
                        idx <- match(p, names(purch_wala_submdl))
                        a <- unlist(purch_wala_submdl[idx][[1]][1]) 
                        b <- unlist(purch_wala_submdl[idx][[1]][2])
                        x <- ppdata[, p]
                        wala.df[, p] <- BuildSpline(a = a, b = b, x = x)$y
                    }
                }

                for (p in names(refi_wala_submdl)) {
                    if(!(p %in% names(ppdata))) {
                        wala.df[, p] <- 1.0
                        cat("ATTENTION!Missing refi wala in INPUT!", " missing: ", p, "\n")
                    }
                    else {
                        idx <- match(p, names(refi_wala_submdl))
                        a <- unlist(refi_wala_submdl[idx][[1]][1]) 
                        b <- unlist(refi_wala_submdl[idx][[1]][2])
                        x <- ppdata[, p]
                        wala.df[, p] <- BuildSpline(a = a, b = b, x = x)$y
                    }
                }                
                
              wala.df  <- data.frame(wala.df) 
              
              wala.df$purch_wala  <- (1.0 - ppdata$hpa_interpolation) * wala.df$purch_lohpa_wala + ppdata$hpa_interpolation * wala.df$purch_hihpa_wala
              wala.df$refi_wala  <- (1.0 - ppdata$hpa_interpolation) * wala.df$refi_lohpa_wala + ppdata$hpa_interpolation * wala.df$refi_hihpa_wala
              wala.df$wala  <- (wala.df$purch_wala * data$pct_purchase + wala.df$refi_wala * (data$pct_refi_co + data$pct_refi_nco)) / 100
              
              mult.df  <- data.frame(mult.df)
              mult.df$incentive   <-  (mult.df$purch_incentive * data$pct_purchase + mult.df$refi_co_incentive * data$pct_refi_co + mult.df$refi_nco_incentive * data$pct_refi_nco) / 100
              
              submdl.pred <- submdl.pred * mult.df[, "hpa_annual"] * mult.df[, "incentive"] * mult.df[, "acls"] * 
              mult.df[, "cltv"] * mult.df[, "fico"] * mult.df[, "tax"] * mult.df[, "pct_second_lien"] *
              ((mult.df[, "NY_acls"] * data[, "pct_NY"] + 1.0 * (100 - data[, "pct_NY"]))/100) *
              (mult.df[, "fico_acls_interact_2_fico"] * mult.df[, "fico_acls_interact_1_acls"] + 1 *(1 - mult.df[, "fico_acls_interact_2_fico"])) * wala.df[,"wala"]
        }
		else if ((submodel == "cout") & (coll == "conv30")) {
              submdl.pred <- submdl.pred * mult.df[, "wala"] * mult.df[, "incentive"] * mult.df[, "cltv"] * mult.df[, "fico"] * mult.df[, "refi_elig_pct"] * mult.df[, "hpa_cum"] * mult.df[, "wacls"] *
              ((mult.df[, "preHARP_wacls"] * data[, "pct_preHARP"] + 1.0 * (100 - data[, "pct_preHARP"]))/100) *
              ((mult.df[, "NY_wacls"] * data[, "pct_NY"] + 1.0 * (100 - data[, "pct_NY"]))/100) *
              ((mult.df[, "nonRetail_wacls"] * data[, "pct_NonRETAIL"] + mult.df[, "broker_wacls"] * data[, "pct_BROKER"] + mult.df[, "corres_wacls"] * data[, "pct_CORRES"] + mult.df[, "retailCashWindow_wacls"] * data[, "pct_RETAIL_CashWindow"] + mult.df[, "retailNonCashWindow_wacls"] * data[, "pct_RETAIL_NonCashWindow"])/100)             
        }
        else if ((submodel == "cout") & (coll == "gnma30")) {
              mult.df  <- data.frame(mult.df)
              mult.df$incentive     <-  (mult.df$purch_incentive * data$pct_purchase + mult.df$refi_co_incentive * data$pct_refi_co + mult.df$refi_nco_incentive * data$pct_refi_nco) / 100
              
              submdl.pred <- submdl.pred * mult.df[, "wala"] * mult.df[, "incentive"] * 
              mult.df[, "cltv"] * mult.df[, "fico"] * mult.df[, "hpa_cum"] * mult.df[, "wacls"] *
              ((mult.df[, "NY_wacls"] * data[, "pct_NY"] + 1.0 * (100 - data[, "pct_NY"]))/100) *
              ((mult.df[, "TX_wacls"] * data[, "pct_TX"] + 1.0 * (100 - data[, "pct_TX"]))/100)               
        }
        else if ((submodel == "cc") & (coll == "gnma30")) {
              mult.df  <- data.frame(mult.df)
              mult.df$incentive     <-  (mult.df$purch_incentive * data$pct_purchase + mult.df$refi_co_incentive * data$pct_refi_co + mult.df$refi_nco_incentive * data$pct_refi_nco) / 100 
              
              submdl.pred <- submdl.pred * mult.df[, "wala1"] * mult.df[, "wala2"] * mult.df[, "cltv"] * mult.df[, "wacls"] * mult.df[, "fico1"] * mult.df[, "fico2"] * 
              mult.df[, "incentive"] * mult.df[, "hpa_cum"]
     
        }
        else{
          for (p in param.submdl) {
            submdl.pred <- submdl.pred * mult.df[, p]
          }
        }

        
        # Layer on seasonals to forecasts if necessary
        if (seasadj == TRUE) 
            seasonals <- SeasonalAdjustment(seasonals = submdl.spl$seasonalityMultipliers, months = data$monthBucket) 
        else seasonals <- rep(1, nrow(data))
        submdl.pred <- submdl.pred * seasonals
        
    } else {
        submdl.pred <- NA
    }
    
    names(mult.df) <- paste(paste(submodel, names(mult.df), sep="_"), version, sep="_")
    
    return(list(pred = submdl.pred, mult = mult.df))
} 
