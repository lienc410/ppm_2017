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


PredictSubmodel_4_70_interpolation_production <- function(coll, submodel = NA, submdl.spl, data, seasadj = FALSE, version = "") {
    
    submdl.spl <- submdl.spl

    if (!any(is.na(submdl.spl))) { 

        removal_list   <-  c("baselineConstant", "adjustmentFactor", "seasonalityMultipliers")
        
        removal_list_refinance_conv   <-  c("baselineConstant", "adjustmentFactor", "seasonalityMultipliers", "media_effect", "burnout", "inv_wacls","incentive")
        
        removal_list_turnover_conv   <-  c("baselineConstant", "adjustmentFactor", "seasonalityMultipliers", "hpa_interp", "hpa_interp_U6", "hpa_interp_U9", "wala", "wala_U6", "wala_U9")
        
        removal_list_refinance_gnma   <-  c("baselineConstant", "adjustmentFactor", "seasonalityMultipliers", "media_effect", "burnout", "incentive", "monthsSinceIssued")
        
        removal_list_turnover_gnma   <-  c("baselineConstant", "adjustmentFactor", "seasonalityMultipliers", "hpa_interp", "wala", "monthsSinceIssued")
        
        removal_list_cashout_gnma   <-  c("baselineConstant", "adjustmentFactor", "seasonalityMultipliers", "wala_interp", "incentive", "monthsSinceIssued")
        
        removal_list_cc_gnma   <-  c("baselineConstant", "adjustmentFactor", "seasonalityMultipliers", "incentive", "monthsSinceIssued")
        
        removal_list_fta_gnma   <-  c("baselineConstant", "adjustmentFactor", "tangibleBenefit_interp", "incentive", "wacls", "monthsSinceIssued")
    
    if ((submodel == "refi") & (coll == "conv30")) {
        param.submdl <- names(submdl.spl)[-match(removal_list_refinance_conv, names(submdl.spl))]
    }
    else if ((submodel == "turn") & (coll == "conv30")) {
        param.submdl <- names(submdl.spl)[-match(removal_list_turnover_conv, names(submdl.spl))]
    }
    else if ((submodel == "refi") & (coll == "gnma30")) {
        param.submdl <- names(submdl.spl)[-match(removal_list_refinance_gnma, names(submdl.spl))]
    }
    else if ((submodel == "turn") & (coll == "gnma30")) {
        param.submdl <- names(submdl.spl)[-match(removal_list_turnover_gnma, names(submdl.spl))]
    }
    else if ((submodel == "cout") & (coll == "gnma30")) {
        param.submdl <- names(submdl.spl)[-match(removal_list_cashout_gnma, names(submdl.spl))]
    }
    else if ((submodel == "cc") & (coll == "gnma30")) {
        param.submdl <- names(submdl.spl)[-match(removal_list_cc_gnma, names(submdl.spl))]
    }
    else if ((submodel == "fta") & (coll == "gnma30")) {
        param.submdl <- names(submdl.spl)[-match(removal_list_fta_gnma, names(submdl.spl))]
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
start_time1 <- Sys.time()
cat("running refi mdl step 1", "\n")
              #step 1. handle fico dials
              fico_submdl_0   <- submdl.spl$incentive$functions$functions[[1]]$functions[1]
              fico_submdl_1   <- submdl.spl$incentive$functions$functions[[2]]$functions[1]
              fico_submdl_2   <- submdl.spl$incentive$functions$functions[[3]]$functions[1]
              fico_submdl     <- c(fico_submdl_0,fico_submdl_1,fico_submdl_2)
              fico_list_refinance  <- c("fico_0","fico_1","fico_2")
              names(fico_submdl)   <- fico_list_refinance

              fico_mult.df <- data.frame(matrix(nrow = nrow(ppdata), ncol = length(fico_list_refinance)))
              names(fico_mult.df) <- fico_list_refinance

                for (p in names(fico_submdl)) {
                    if(!(p %in% names(ppdata))) {
                        fico_mult.df[, p] <- 1.0
                        cat("ATTENTION!Missing fico in INPUT!", " missing: ", p, "\n")
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
end_time1 <- Sys.time()
cat("refi mdl step1: fico ", difftime(end_time1, start_time1, units='mins'), "\n")  
            
              #step 2. handle sato dials
start_time2 <- Sys.time()
cat("running refi mdl step 2", "\n")
              sato_submdl_0   <- submdl.spl$incentive$functions$functions[[1]]$functions[2]
              sato_submdl_1   <- submdl.spl$incentive$functions$functions[[2]]$functions[2]
              sato_submdl_2   <- submdl.spl$incentive$functions$functions[[3]]$functions[2]
              sato_submdl     <- c(sato_submdl_0,sato_submdl_1,sato_submdl_2)
              sato_list_refinance  <- c("sato_0","sato_1","sato_2")
              names(sato_submdl)   <- sato_list_refinance

              sato_mult.df <- data.frame(matrix(nrow = nrow(ppdata), ncol = length(sato_list_refinance)))
              names(sato_mult.df) <- sato_list_refinance

                for (p in names(sato_submdl)) {
                    if(!(p %in% names(ppdata))) {
                        sato_mult.df[, p] <- 1.0
                        cat("ATTENTION!Missing fico in INPUT!", " missing: ", p, "\n")
                    }
                    else {
                        idx <- match(p, names(sato_submdl))
                        a <- unlist(sato_submdl[idx][[1]][1]) 
                        b <- unlist(sato_submdl[idx][[1]][2])
                        x <- ppdata[, p]
                        sato_mult.df[, p] <- BuildSpline(a = a, b = b, x = x)$y
                    }
                }
              sato_mult.df  <- data.frame(sato_mult.df) 
end_time2 <- Sys.time()
cat("refi mdl step2: sato ", difftime(end_time2, start_time2, units='mins'), "\n") 
              
              #step 3: handle tpo wacls dials 
start_time3 <- Sys.time()
cat("running refi mdl step 3", "\n")              
              broker_wacls_0 <- submdl.spl$incentive$functions$functions[[1]]$functions[3][[1]]["broker"]
              broker_wacls_1 <- submdl.spl$incentive$functions$functions[[2]]$functions[3][[1]]["broker"]
              broker_wacls_2 <- submdl.spl$incentive$functions$functions[[3]]$functions[3][[1]]["broker"]
              
              corres_wacls_0 <- submdl.spl$incentive$functions$functions[[1]]$functions[3][[1]]["corres"]
              corres_wacls_1 <- submdl.spl$incentive$functions$functions[[2]]$functions[3][[1]]["corres"]
              corres_wacls_2 <- submdl.spl$incentive$functions$functions[[3]]$functions[3][[1]]["corres"]
              
              retail_wacls_0 <- submdl.spl$incentive$functions$functions[[1]]$functions[3][[1]]["retail"]
              retail_wacls_1 <- submdl.spl$incentive$functions$functions[[2]]$functions[3][[1]]["retail"]
              retail_wacls_2 <- submdl.spl$incentive$functions$functions[[3]]$functions[3][[1]]["retail"]
               
              na_wacls_0 <- submdl.spl$incentive$functions$functions[[1]]$functions[3][[1]]["na"]
              na_wacls_1 <- submdl.spl$incentive$functions$functions[[2]]$functions[3][[1]]["na"]
              na_wacls_2 <- submdl.spl$incentive$functions$functions[[3]]$functions[3][[1]]["na"]
              
              tpo_wacls_submdl  <- c(broker_wacls_0,broker_wacls_1,broker_wacls_2,corres_wacls_0,corres_wacls_1,corres_wacls_2,retail_wacls_0,retail_wacls_1,retail_wacls_2,na_wacls_0,na_wacls_1,na_wacls_2)
           
              tpo_list_refinance  <- c("broker_wacls_0","broker_wacls_1","broker_wacls_2","corres_wacls_0","corres_wacls_1","corres_wacls_2","retail_wacls_0","retail_wacls_1","retail_wacls_2","na_wacls_0","na_wacls_1","na_wacls_2")
              
              names(tpo_wacls_submdl)   <- tpo_list_refinance
            
              tpo.df <- data.frame(matrix(nrow = nrow(ppdata), ncol = length(tpo_list_refinance)))
              names(tpo.df) <- tpo_list_refinance 
              
                for (p in names(tpo_wacls_submdl)) {
                    if(!(p %in% names(ppdata))) {
                        tpo.df[, p] <- 1.0
                        cat("ATTENTION!Missing tpo wacls in INPUT!", " missing: ", p, "\n")
                    }
                    else {
                        idx <- match(p, names(tpo_wacls_submdl))
                        a <- unlist(tpo_wacls_submdl[idx][[1]][1]) 
                        b <- unlist(tpo_wacls_submdl[idx][[1]][2])
                        x <- ppdata[, p]
                        tpo.df[, p] <- BuildSpline(a = a, b = b, x = x)$y
                    }
                }

              tpo.df  <- data.frame(tpo.df) 
              
              tpo.df$tpo_dial_0  <- (ppdata$pct_broker * tpo.df$broker_wacls_0 + ppdata$pct_corres * tpo.df$corres_wacls_0 + ppdata$pct_retail * tpo.df$retail_wacls_0 + ppdata$pct_na * tpo.df$na_wacls_0) / 100
              
              tpo.df$tpo_dial_1  <- (ppdata$pct_broker * tpo.df$broker_wacls_1 + ppdata$pct_corres * tpo.df$corres_wacls_1 + ppdata$pct_retail * tpo.df$retail_wacls_1 + ppdata$pct_na * tpo.df$na_wacls_1) / 100
              
              tpo.df$tpo_dial_2  <- (ppdata$pct_broker * tpo.df$broker_wacls_2 + ppdata$pct_corres * tpo.df$corres_wacls_2 + ppdata$pct_retail * tpo.df$retail_wacls_2 + ppdata$pct_na * tpo.df$na_wacls_2) / 100
end_time3 <- Sys.time()
cat("refi mdl step3: tpo ", difftime(end_time3, start_time3, units='mins'), "\n") 
             
              #step 4: handle loanPurposeType wacls dials
start_time4 <- Sys.time()
cat("running refi mdl step 4", "\n")              
              purch_wacls_0 <- submdl.spl$incentive$functions$functions[[1]]$functions[4][[1]]["purchase"]
              purch_wacls_1 <- submdl.spl$incentive$functions$functions[[2]]$functions[4][[1]]["purchase"]
              purch_wacls_2 <- submdl.spl$incentive$functions$functions[[3]]$functions[4][[1]]["purchase"]
              
              cout_wacls_0  <- submdl.spl$incentive$functions$functions[[1]]$functions[4][[1]]["cashout"]
              cout_wacls_1  <- submdl.spl$incentive$functions$functions[[2]]$functions[4][[1]]["cashout"]
              cout_wacls_2  <- submdl.spl$incentive$functions$functions[[3]]$functions[4][[1]]["cashout"]
              
              refi_wacls_0  <- submdl.spl$incentive$functions$functions[[1]]$functions[4][[1]]["refi"]
              refi_wacls_1  <- submdl.spl$incentive$functions$functions[[2]]$functions[4][[1]]["refi"]
              refi_wacls_2  <- submdl.spl$incentive$functions$functions[[3]]$functions[4][[1]]["refi"]
              
              hmod_wacls_0  <- submdl.spl$incentive$functions$functions[[1]]$functions[4][[1]]["hampMod"]
              hmod_wacls_1  <- submdl.spl$incentive$functions$functions[[2]]$functions[4][[1]]["hampMod"]
              hmod_wacls_2  <- submdl.spl$incentive$functions$functions[[3]]$functions[4][[1]]["hampMod"]
              
              nhmod_wacls_0 <- submdl.spl$incentive$functions$functions[[1]]$functions[4][[1]]["nonHampMod"]
              nhmod_wacls_1 <- submdl.spl$incentive$functions$functions[[2]]$functions[4][[1]]["nonHampMod"]
              nhmod_wacls_2 <- submdl.spl$incentive$functions$functions[[3]]$functions[4][[1]]["nonHampMod"]
              
              rp_wacls_0    <- submdl.spl$incentive$functions$functions[[1]]$functions[4][[1]]["reperf"]
              rp_wacls_1    <- submdl.spl$incentive$functions$functions[[2]]$functions[4][[1]]["reperf"]
              rp_wacls_2    <- submdl.spl$incentive$functions$functions[[3]]$functions[4][[1]]["reperf"]
             
              purpose_wacls_submdl  <- c(purch_wacls_0,purch_wacls_1,purch_wacls_2,cout_wacls_0,cout_wacls_1,cout_wacls_2,refi_wacls_0,refi_wacls_1,refi_wacls_2,hmod_wacls_0,hmod_wacls_1,hmod_wacls_2,nhmod_wacls_0,nhmod_wacls_1,nhmod_wacls_2,rp_wacls_0,rp_wacls_1,rp_wacls_2)
              
              loanPurposeType_list_refinance  <- c("purch_wacls_0","purch_wacls_1","purch_wacls_2","cout_wacls_0","cout_wacls_1","cout_wacls_2","refi_wacls_0","refi_wacls_1","refi_wacls_2","hmod_wacls_0","hmod_wacls_1","hmod_wacls_2","nhmod_wacls_0","nhmod_wacls_1","nhmod_wacls_2","rp_wacls_0","rp_wacls_1","rp_wacls_2")
              
              names(purpose_wacls_submdl)   <-  loanPurposeType_list_refinance
            
              purpose.df <- data.frame(matrix(nrow = nrow(ppdata), ncol = length(loanPurposeType_list_refinance)))
              names(purpose.df) <- loanPurposeType_list_refinance
                            
                for (p in names(purpose_wacls_submdl)) {
                    if(!(p %in% names(ppdata))) {
                        purpose.df[, p] <- 1.0
                        cat("ATTENTION!Missing purpose wacls in INPUT!", " missing: ", p, "\n")
                    }
                    else {
                        idx <- match(p, names(purpose_wacls_submdl))
                        a <- unlist(purpose_wacls_submdl[idx][[1]][1]) 
                        b <- unlist(purpose_wacls_submdl[idx][[1]][2])
                        x <- ppdata[, p]
                        purpose.df[, p] <- BuildSpline(a = a, b = b, x = x)$y
                    }
                }
 
              purpose.df  <- data.frame(purpose.df) 
              
              purpose.df$purpose_dial_0  <- (ppdata$pct_purchase * purpose.df$purch_wacls_0 + ppdata$pct_refi_co * purpose.df$cout_wacls_0 + ppdata$pct_refi_nco * purpose.df$refi_wacls_0 + ppdata$pct_hmod * purpose.df$hmod_wacls_0 + ppdata$pct_nhmod * purpose.df$nhmod_wacls_0 + ppdata$pct_rp * purpose.df$rp_wacls_0) / 100
              
              purpose.df$purpose_dial_1  <- (ppdata$pct_purchase * purpose.df$purch_wacls_1 + ppdata$pct_refi_co * purpose.df$cout_wacls_1 + ppdata$pct_refi_nco * purpose.df$refi_wacls_1 + ppdata$pct_hmod * purpose.df$hmod_wacls_1 + ppdata$pct_nhmod * purpose.df$nhmod_wacls_1 + ppdata$pct_rp * purpose.df$rp_wacls_1) / 100
              
              purpose.df$purpose_dial_2  <- (ppdata$pct_purchase * purpose.df$purch_wacls_2 + ppdata$pct_refi_co * purpose.df$cout_wacls_2 + ppdata$pct_refi_nco * purpose.df$refi_wacls_2 + ppdata$pct_hmod * purpose.df$hmod_wacls_2 + ppdata$pct_nhmod * purpose.df$nhmod_wacls_2 + ppdata$pct_rp * purpose.df$rp_wacls_2) / 100
end_time4 <- Sys.time()
cat("refi mdl step4: loanpurpose ", difftime(end_time4, start_time4, units='mins'), "\n")   
            
              #step 5. handle burnout S curves
start_time5 <- Sys.time()
cat("running refi mdl step 5", "\n")                
              burnout_submdl_0  <- submdl.spl$incentive$functions$functions[1][[1]]$functions[5][[1]]
              burnout_submdl_1  <- submdl.spl$incentive$functions$functions[2][[1]]$functions[5][[1]]
              burnout_submdl_2  <- submdl.spl$incentive$functions$functions[3][[1]]$functions[5][[1]]
              
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
end_time5 <- Sys.time()
cat("refi mdl step5: burnout S curves ", difftime(end_time5, start_time5, units='mins'), "\n") 

              #step 6. media effect interpolation
start_time6 <- Sys.time()
cat("running refi mdl step 6", "\n")                
              media_effect_0 <- fico_mult.df[,"fico_0"] * sato_mult.df[,"sato_0"] * tpo.df$tpo_dial_0 * purpose.df$purpose_dial_0 * test1[,"incentive_dial_0"]
              media_effect_1 <- fico_mult.df[,"fico_1"] * sato_mult.df[,"sato_1"] * tpo.df$tpo_dial_1 * purpose.df$purpose_dial_1 * test2[,"incentive_dial_1"]
              media_effect_2 <- fico_mult.df[,"fico_2"] * sato_mult.df[,"sato_2"] * tpo.df$tpo_dial_2 * purpose.df$purpose_dial_2 * test3[,"incentive_dial_2"]
    
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
end_time6 <- Sys.time()
cat("refi mdl step6: media effect interpolation ", difftime(end_time6, start_time6, units='mins'), "\n") 

              #step 7. monthsSinceIssued
start_time7 <- Sys.time()
cat("running refi mdl step 7", "\n")               
              none_msi_refi     <- submdl.spl$monthsSinceIssued$functions["none"]
              hmod_msi_refi     <- submdl.spl$monthsSinceIssued$functions["hampMod"]
              nhmod_msi_refi    <- submdl.spl$monthsSinceIssued$functions["nonHampMod"]
              rp_msi_refi       <- submdl.spl$monthsSinceIssued$functions["reperf"]
              
              msi_refi_submdl   <- c(none_msi_refi,hmod_msi_refi,nhmod_msi_refi,rp_msi_refi)
              
              msi_refi_list  <- c("none_msi","hmod_msi","nhmod_msi","rp_msi")
              
              names(msi_refi_submdl)   <-  msi_refi_list
            
              msi_refi.df <- data.frame(matrix(nrow = nrow(ppdata), ncol = length(msi_refi_list)))
              names(msi_refi.df) <- msi_refi_list
                            
                for (p in names(msi_refi_submdl)) {
                    if(!(p %in% names(ppdata))) {
                        msi_refi.df[, p] <- 1.0
                        cat("ATTENTION!Missing refi msi in INPUT!", " missing: ", p, "\n")
                    }
                    else {
                        idx <- match(p, names(msi_refi_submdl))
                        a <- unlist(msi_refi_submdl[idx][[1]][1]) 
                        b <- unlist(msi_refi_submdl[idx][[1]][2])
                        x <- ppdata[, p]
                        msi_refi.df[, p] <- BuildSpline(a = a, b = b, x = x)$y
                    }
                }

              msi_refi.df  <- data.frame(msi_refi.df) 
              
              mult.df$msi  <- (ppdata$pct_hmod * msi_refi.df$hmod_msi + ppdata$pct_nhmod * msi_refi.df$nhmod_msi + ppdata$pct_rp * msi_refi.df$rp_msi + ppdata$pct_none * msi_refi.df$none_msi) / 100
end_time7 <- Sys.time()
cat("refi mdl step7: monthsSinceIssued ", difftime(end_time7, start_time7, units='mins'), "\n")  
             
              #step 8. result
start_time8 <- Sys.time()
cat("running refi mdl step 8", "\n")               
              submdl.pred <- submdl.pred * mult.df[, "cltv"] * mult.df[, "wala"] * mult.df[, "low_fico_adjustment"] * 
              mult.df[, "wacls"] * Media_Effect_dial[,"media_effect_dial"] * mult.df[, "msi"] *
              ((mult.df[, "NY_wacls"] * data[, "pct_NY"] + 1.0 * (100 - data[, "pct_NY"]))/100)
             
              rm(msi_refi.df, test1, test2, test3, purpose.df, tpo.df, sato_mult.df, fico_mult.df)
              
              
end_time8 <- Sys.time()
cat("refi mdl step8: results ", difftime(end_time8, start_time8, units='mins'), "\n")                            
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
              
              #step 2: handle loanPurposeType oltv dials
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
              ((mult.df[, "inv_oltv"] * data[, "pct_inv"] + 1.0 * (100 - data[, "pct_inv"]))/100) *
              (mult.df[, "fico_acls_interact_2_fico"] * mult.df[, "fico_acls_interact_1_acls"] + 1 *(1 - mult.df[, "fico_acls_interact_2_fico"]))        
        }      
        else if ((submodel == "turn") & (coll == "gnma30")) {
start_time_turn <- Sys.time()
cat("running turn mdl", "\n")        
              #step 1: handle wala dials 
              
              purch_wala_submdl                 <- submdl.spl$wala$functions$purchase$functions             
              refi_co_wala_submdl               <- submdl.spl$wala$functions$cashout$functions            
              refi_nco_wala_submdl              <- submdl.spl$wala$functions$refi$functions
              hmod_wala_submdl                  <- submdl.spl$wala$functions$hampMod$functions
              nhmod_wala_submdl                 <- submdl.spl$wala$functions$nonHampMod$functions
              rp_wala_submdl                    <- submdl.spl$wala$functions$reperf$functions
              
              wala_submdl  <- c(purch_wala_submdl,refi_co_wala_submdl,refi_nco_wala_submdl,hmod_wala_submdl,nhmod_wala_submdl,rp_wala_submdl)
           
              wala_list_turnover  <- c("purch_wala_0","purch_wala_1","purch_wala_2","refi_co_wala_0","refi_co_wala_1","refi_co_wala_2","refi_nco_wala_0","refi_nco_wala_1","refi_nco_wala_2","hmod_wala_0","hmod_wala_1","hmod_wala_2","nhmod_wala_0","nhmod_wala_1","nhmod_wala_2","rp_wala_0","rp_wala_1","rp_wala_2")
              
              names(wala_submdl)  <- wala_list_turnover
            
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
                
              wala.df  <- data.frame(wala.df) 
              
			  tover_temp1 <- data.frame(cbind(data[,"hpa_interpolation_int"], data[,"hpa_interpolation_dec"], wala.df[,"purch_wala_0"], wala.df[,"purch_wala_1"], wala.df[,"purch_wala_2"]))  
              
              names(tover_temp1) <- c("hpa_interpolation_int","hpa_interpolation_dec","purch_wala_0","purch_wala_1", "purch_wala_2")
              
			  tover_temp2 <- data.frame(cbind(data[,"hpa_interpolation_int"], data[,"hpa_interpolation_dec"], wala.df[,"refi_co_wala_0"], wala.df[,"refi_co_wala_1"], wala.df[,"refi_co_wala_2"]))  
              
              names(tover_temp2) <- c("hpa_interpolation_int","hpa_interpolation_dec","refi_co_wala_0","refi_co_wala_1", "refi_co_wala_2")
              
			  tover_temp3 <- data.frame(cbind(data[,"hpa_interpolation_int"], data[,"hpa_interpolation_dec"], wala.df[,"refi_nco_wala_0"], wala.df[,"refi_nco_wala_1"], wala.df[,"refi_nco_wala_2"]))  
              
              names(tover_temp3) <- c("hpa_interpolation_int","hpa_interpolation_dec","refi_nco_wala_0","refi_nco_wala_1", "refi_nco_wala_2")

			  tover_temp4 <- data.frame(cbind(data[,"hpa_interpolation_int"], data[,"hpa_interpolation_dec"], wala.df[,"hmod_wala_0"], wala.df[,"hmod_wala_1"], wala.df[,"hmod_wala_2"]))  
              
              names(tover_temp4) <- c("hpa_interpolation_int","hpa_interpolation_dec","hmod_wala_0","hmod_wala_1", "hmod_wala_2")

			  tover_temp5 <- data.frame(cbind(data[,"hpa_interpolation_int"], data[,"hpa_interpolation_dec"], wala.df[,"nhmod_wala_0"], wala.df[,"nhmod_wala_1"], wala.df[,"nhmod_wala_2"]))  
              
              names(tover_temp5) <- c("hpa_interpolation_int","hpa_interpolation_dec","nhmod_wala_0","nhmod_wala_1", "nhmod_wala_2")

			  tover_temp6 <- data.frame(cbind(data[,"hpa_interpolation_int"], data[,"hpa_interpolation_dec"], wala.df[,"rp_wala_0"], wala.df[,"rp_wala_1"], wala.df[,"rp_wala_2"]))  
              
              names(tover_temp6) <- c("hpa_interpolation_int","hpa_interpolation_dec","rp_wala_0","rp_wala_1", "rp_wala_2")             
              
              Tover_Wala_gnm <- function(x, y = 0){
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
              
              tover_test1 <- data.frame(apply(tover_temp1, 1, Tover_Wala_gnm))
              names(tover_test1) <- c("purch_wala")
              
              tover_test2 <- data.frame(apply(tover_temp2, 1, Tover_Wala_gnm))
              names(tover_test2) <- c("refi_co_wala")
              
              tover_test3 <- data.frame(apply(tover_temp3, 1, Tover_Wala_gnm))
              names(tover_test3) <- c("refi_nco_wala")

              tover_test4 <- data.frame(apply(tover_temp4, 1, Tover_Wala_gnm))
              names(tover_test4) <- c("hmod_wala")
              
              tover_test5 <- data.frame(apply(tover_temp5, 1, Tover_Wala_gnm))
              names(tover_test5) <- c("nhmod_wala")
              
              tover_test6 <- data.frame(apply(tover_temp6, 1, Tover_Wala_gnm))
              names(tover_test6) <- c("rp_wala")
              
              wala.df$wala  <- (tover_test1$purch_wala * data$pct_purchase + tover_test2$refi_co_wala * data$pct_refi_co + tover_test3$refi_nco_wala *data$pct_refi_nco + tover_test4$hmod_wala *data$pct_hmod + tover_test5$nhmod_wala *data$pct_nhmod + tover_test6$rp_wala *data$pct_rp) / 100
              
              #step 2: handle msi dials  
              
              none_msi_tover     <- submdl.spl$monthsSinceIssued$functions["none"]
              hmod_msi_tover     <- submdl.spl$monthsSinceIssued$functions["hampMod"]
              nhmod_msi_tover    <- submdl.spl$monthsSinceIssued$functions["nonHampMod"]
              rp_msi_tover       <- submdl.spl$monthsSinceIssued$functions["reperf"]
              
              msi_tover_submdl   <- c(none_msi_tover,hmod_msi_tover,nhmod_msi_tover,rp_msi_tover)
              
              msi_tover_list  <- c("none_msi","hmod_msi","nhmod_msi","rp_msi")
              
              names(msi_tover_submdl)   <-  msi_tover_list
            
              msi_tover.df <- data.frame(matrix(nrow = nrow(ppdata), ncol = length(msi_tover_list)))
              names(msi_tover.df) <- msi_tover_list
                            
                for (p in names(msi_tover_submdl)) {
                    if(!(p %in% names(ppdata))) {
                        msi_tover.df[, p] <- 1.0
                        cat("ATTENTION!Missing tover msi in INPUT!", " missing: ", p, "\n")
                    }
                    else {
                        idx <- match(p, names(msi_tover_submdl))
                        a <- unlist(msi_tover_submdl[idx][[1]][1]) 
                        b <- unlist(msi_tover_submdl[idx][[1]][2])
                        x <- ppdata[, p]
                        msi_tover.df[, p] <- BuildSpline(a = a, b = b, x = x)$y
                    }
                }

              msi_tover.df  <- data.frame(msi_tover.df) 
              
              mult.df$msi  <- (ppdata$pct_hmod * msi_tover.df$hmod_msi + ppdata$pct_nhmod * msi_tover.df$nhmod_msi + ppdata$pct_rp * msi_tover.df$rp_msi + ppdata$pct_none * msi_tover.df$none_msi) / 100
              
              #step 3: result  
              
              mult.df  <- data.frame(mult.df)
              
              submdl.pred <- submdl.pred * mult.df[, "hpa_annual"] * mult.df[, "incentive"] * mult.df[, "acls"] * wala.df[,"wala"] * 
              mult.df[, "cltv"] * mult.df[, "fico"] * mult.df[, "tax"] * mult.df[, "sato"] * mult.df[, "msi"] *
              ((data[, "pct_broker"] * mult.df[, "broker_acls"] + data[, "pct_corres"] * mult.df[, "corres_acls"] + data[, "pct_retail"] * mult.df[, "retail_acls"] + data[, "pct_na"] * mult.df[, "na_acls"]) / 100) *
              ((mult.df[, "NY_acls"] * data[, "pct_NY"] + 1.0 * (100 - data[, "pct_NY"]))/100)
              
              rm(msi_tover.df, tover_test1, tover_test2, tover_test3, tover_test4, tover_test5, tover_test6)
end_time_turn <- Sys.time()
cat("turn mdl finish ", difftime(end_time_turn, start_time_turn, units='mins'), "\n")  
        }
		else if ((submodel == "cout") & (coll == "conv30")) {
              submdl.pred <- submdl.pred * mult.df[, "wala"] * mult.df[, "incentive"] * mult.df[, "cltv"] * mult.df[, "fico"] * mult.df[, "refi_elig_pct"] * mult.df[, "hpa_cum"] * mult.df[, "wacls"] *
              ((mult.df[, "preHARP_wacls"] * data[, "pct_preHARP"] + 1.0 * (100 - data[, "pct_preHARP"]))/100) *
              ((mult.df[, "NY_wacls"] * data[, "pct_NY"] + 1.0 * (100 - data[, "pct_NY"]))/100) *
              ((mult.df[, "nonRetail_wacls"] * data[, "pct_NonRETAIL"] + mult.df[, "broker_wacls"] * data[, "pct_BROKER"] + mult.df[, "corres_wacls"] * data[, "pct_CORRES"] + mult.df[, "retailCashWindow_wacls"] * data[, "pct_RETAIL_CashWindow"] + mult.df[, "retailNonCashWindow_wacls"] * data[, "pct_RETAIL_NonCashWindow"])/100)             
        }
        else if ((submodel == "cout") & (coll == "gnma30")) {
start_time_cout1 <- Sys.time()
cat("running cout mdl step 1", "\n")         
              #step 1: handle cashout burnout multi curve  
              
              cout_burnout_submdl_purch     <- submdl.spl$incentive$functions$purchase$functions           
              cout_burnout_submdl_refi_co   <- submdl.spl$incentive$functions$cashout$functions
              cout_burnout_submdl_refi_nco  <- submdl.spl$incentive$functions$refi$functions
              cout_burnout_submdl_hmod      <- submdl.spl$incentive$functions$hampMod$functions
              cout_burnout_submdl_nhmod     <- submdl.spl$incentive$functions$nonHampMod$functions
              cout_burnout_submdl_rp        <- submdl.spl$incentive$functions$reperf$functions
              
              cout_burnout_submdl           <- c(cout_burnout_submdl_purch,cout_burnout_submdl_refi_co,cout_burnout_submdl_refi_nco,cout_burnout_submdl_hmod,cout_burnout_submdl_nhmod,cout_burnout_submdl_rp)
              
              cout_burnout_list  <- c("purch_incentive_0","purch_incentive_1","purch_incentive_2","purch_incentive_3","purch_incentive_4","refi_co_incentive_0","refi_co_incentive_1","refi_co_incentive_2","refi_co_incentive_3","refi_co_incentive_4","refi_nco_incentive_0","refi_nco_incentive_1","refi_nco_incentive_2","refi_nco_incentive_3","refi_nco_incentive_4","hmod_incentive_0","hmod_incentive_1","hmod_incentive_2","hmod_incentive_3","hmod_incentive_4","nhmod_incentive_0","nhmod_incentive_1","nhmod_incentive_2","nhmod_incentive_3","nhmod_incentive_4","rp_incentive_0","rp_incentive_1","rp_incentive_2","rp_incentive_3","rp_incentive_4")
              
              names(cout_burnout_submdl)  <- cout_burnout_list
              
              cout_burnout.df <- data.frame(matrix(nrow = nrow(ppdata), ncol = length(cout_burnout_list)))
              names(cout_burnout.df) <- cout_burnout_list
             
                for (p in names(cout_burnout_submdl)) {
                    if(!(p %in% names(ppdata))) {
                        cout_burnout.df[, p] <- 1.0
                        cat("ATTENTION!Missing cout incentive in INPUT!", " missing: ", p, "\n")
                    }
                    else {
                        idx <- match(p, names(cout_burnout_submdl))
                        a <- unlist(cout_burnout_submdl[idx][[1]][1]) 
                        b <- unlist(cout_burnout_submdl[idx][[1]][2])
                        x <- ppdata[, p]
                        cout_burnout.df[, p] <- BuildSpline(a = a, b = b, x = x)$y
                    }
                }

              cout_burnout.df  <- data.frame(cout_burnout.df)
              
			  cout_temp1 <- data.frame(cbind(data[,"wala_interpolation_int"], data[,"wala_interpolation_dec"], cout_burnout.df[,"purch_incentive_0"], cout_burnout.df[,"purch_incentive_1"], cout_burnout.df[,"purch_incentive_2"], cout_burnout.df[,"purch_incentive_3"], cout_burnout.df[,"purch_incentive_4"]))  
              
              names(cout_temp1) <- c("wala_interpolation_int","wala_interpolation_dec","purch_incentive_0","purch_incentive_1", "purch_incentive_2", "purch_incentive_3", "purch_incentive_4")
              
			  cout_temp2 <- data.frame(cbind(data[,"wala_interpolation_int"], data[,"wala_interpolation_dec"], cout_burnout.df[,"refi_co_incentive_0"], cout_burnout.df[,"refi_co_incentive_1"], cout_burnout.df[,"refi_co_incentive_2"], cout_burnout.df[,"refi_co_incentive_3"], cout_burnout.df[,"refi_co_incentive_4"]))  
              
              names(cout_temp2) <- c("wala_interpolation_int","wala_interpolation_dec","refi_co_incentive_0","refi_co_incentive_1", "refi_co_incentive_2", "refi_co_incentive_3", "refi_co_incentive_4")
              
			  cout_temp3 <- data.frame(cbind(data[,"wala_interpolation_int"], data[,"wala_interpolation_dec"], cout_burnout.df[,"refi_nco_incentive_0"], cout_burnout.df[,"refi_nco_incentive_1"], cout_burnout.df[,"refi_nco_incentive_2"], cout_burnout.df[,"refi_nco_incentive_3"], cout_burnout.df[,"refi_nco_incentive_4"]))  
              
              names(cout_temp3) <- c("wala_interpolation_int","wala_interpolation_dec","refi_nco_incentive_0","refi_nco_incentive_1", "refi_nco_incentive_2", "refi_nco_incentive_3", "refi_nco_incentive_4")
              
			  cout_temp4 <- data.frame(cbind(data[,"wala_interpolation_int"], data[,"wala_interpolation_dec"], cout_burnout.df[,"hmod_incentive_0"], cout_burnout.df[,"hmod_incentive_1"], cout_burnout.df[,"hmod_incentive_2"], cout_burnout.df[,"hmod_incentive_3"], cout_burnout.df[,"hmod_incentive_4"]))  
              
              names(cout_temp4) <- c("wala_interpolation_int","wala_interpolation_dec","hmod_incentive_0","hmod_incentive_1", "hmod_incentive_2", "hmod_incentive_3", "hmod_incentive_4")
              
			  cout_temp5 <- data.frame(cbind(data[,"wala_interpolation_int"], data[,"wala_interpolation_dec"], cout_burnout.df[,"nhmod_incentive_0"], cout_burnout.df[,"nhmod_incentive_1"], cout_burnout.df[,"nhmod_incentive_2"], cout_burnout.df[,"nhmod_incentive_3"], cout_burnout.df[,"nhmod_incentive_4"]))  
              
              names(cout_temp5) <- c("wala_interpolation_int","wala_interpolation_dec","nhmod_incentive_0","nhmod_incentive_1", "nhmod_incentive_2", "nhmod_incentive_3", "nhmod_incentive_4")
              
			  cout_temp6 <- data.frame(cbind(data[,"wala_interpolation_int"], data[,"wala_interpolation_dec"], cout_burnout.df[,"rp_incentive_0"], cout_burnout.df[,"rp_incentive_1"], cout_burnout.df[,"rp_incentive_2"], cout_burnout.df[,"rp_incentive_3"], cout_burnout.df[,"rp_incentive_4"]))  
              
              names(cout_temp6) <- c("wala_interpolation_int","wala_interpolation_dec","rp_incentive_0","rp_incentive_1", "rp_incentive_2", "rp_incentive_3", "rp_incentive_4")
              
              Cout_Burnout_Scurve_gnm <- function(x, y = 0){
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
                else if (x[[1]] >= 4){
                y = x[[7]] 
                }
                return(y)                
              }
              
              cout_test1 <- data.frame(apply(cout_temp1, 1, Cout_Burnout_Scurve_gnm))
              names(cout_test1) <- c("purch_cout_incentive")        
              
              cout_test2 <- data.frame(apply(cout_temp2, 1, Cout_Burnout_Scurve_gnm))
              names(cout_test2) <- c("refi_co_cout_incentive")
              
              cout_test3 <- data.frame(apply(cout_temp3, 1, Cout_Burnout_Scurve_gnm))
              names(cout_test3) <- c("refi_nco_cout_incentive")
              
              cout_test4 <- data.frame(apply(cout_temp4, 1, Cout_Burnout_Scurve_gnm))
              names(cout_test4) <- c("hmod_cout_incentive")
              
              cout_test5 <- data.frame(apply(cout_temp5, 1, Cout_Burnout_Scurve_gnm))
              names(cout_test5) <- c("nhmod_cout_incentive")
              
              cout_test6 <- data.frame(apply(cout_temp6, 1, Cout_Burnout_Scurve_gnm))
              names(cout_test6) <- c("rp_cout_incentive")
              
              mult.df$cout_incentive     <-  (cout_test1$purch_cout_incentive * data$pct_purchase + cout_test2$refi_co_cout_incentive * data$pct_refi_co + cout_test3$refi_nco_cout_incentive * data$pct_refi_nco + cout_test4$hmod_cout_incentive * data$pct_hmod + cout_test5$nhmod_cout_incentive * data$pct_nhmod + cout_test6$rp_cout_incentive * data$pct_rp) / 100
end_time_cout1 <- Sys.time()
cat("cout mdl step1: burnout S curves ", difftime(end_time_cout1, start_time_cout1, units='mins'), "\n")  
             
              #step 2: handle msi dials  
start_time_cout2 <- Sys.time()
cat("running cout mdl step 2", "\n")                 
              none_msi_cout      <- submdl.spl$monthsSinceIssued$functions["none"]
              hmod_msi_cout      <- submdl.spl$monthsSinceIssued$functions["hampMod"]
              nhmod_msi_cout     <- submdl.spl$monthsSinceIssued$functions["nonHampMod"]
              rp_msi_cout        <- submdl.spl$monthsSinceIssued$functions["reperf"]
              
              msi_cout_submdl   <- c(none_msi_cout,hmod_msi_cout,nhmod_msi_cout,rp_msi_cout)
              
              msi_cout_list  <- c("none_msi","hmod_msi","nhmod_msi","rp_msi")
              
              names(msi_cout_submdl)   <-  msi_cout_list
            
              msi_cout.df <- data.frame(matrix(nrow = nrow(ppdata), ncol = length(msi_cout_list)))
              names(msi_cout.df) <- msi_cout_list
                            
                for (p in names(msi_cout_submdl)) {
                    if(!(p %in% names(ppdata))) {
                        msi_cout.df[, p] <- 1.0
                        cat("ATTENTION!Missing cout msi in INPUT!", " missing: ", p, "\n")
                    }
                    else {
                        idx <- match(p, names(msi_cout_submdl))
                        a <- unlist(msi_cout_submdl[idx][[1]][1]) 
                        b <- unlist(msi_cout_submdl[idx][[1]][2])
                        x <- ppdata[, p]
                        msi_cout.df[, p] <- BuildSpline(a = a, b = b, x = x)$y
                    }
                }

              msi_cout.df  <- data.frame(msi_cout.df) 
              
              mult.df$msi  <- (ppdata$pct_hmod * msi_cout.df$hmod_msi + ppdata$pct_nhmod * msi_cout.df$nhmod_msi + ppdata$pct_rp * msi_cout.df$rp_msi + ppdata$pct_none * msi_cout.df$none_msi) / 100
end_time_cout2 <- Sys.time()
cat("cout mdl step2: monthsSinceIssued ", difftime(end_time_cout2, start_time_cout2, units='mins'), "\n")   
             
              #step 3: result  
start_time_cout3 <- Sys.time()
cat("running cout mdl step 3", "\n")               
              mult.df  <- data.frame(mult.df)
              
              submdl.pred <- submdl.pred * mult.df[, "wala"] * mult.df[, "cout_incentive"] * mult.df[, "msi"] *
              mult.df[, "cltv"] * mult.df[, "fico"] * mult.df[, "hpa_cum"] * mult.df[, "wacls"] *  mult.df[, "sato"] *
              ((data[, "pct_broker"] * mult.df[, "broker_wacls"] + data[, "pct_corres"] * mult.df[, "corres_wacls"] + data[, "pct_retail"] * mult.df[, "retail_wacls"] + data[, "pct_na"] * mult.df[, "na_wacls"]) / 100) *
              ((mult.df[, "NY_wacls"] * data[, "pct_NY"] + 1.0 * (100 - data[, "pct_NY"]))/100) *
              ((mult.df[, "TX_wacls"] * data[, "pct_TX"] + 1.0 * (100 - data[, "pct_TX"]))/100)               
             rm(msi_cout.df, cout_test1, cout_test2, cout_test3, cout_test4, cout_test5, cout_test6)
end_time_cout3 <- Sys.time()
cat("cout mdl step3: results ", difftime(end_time_cout3, start_time_cout3, units='mins'), "\n") 
        }
        else if ((submodel == "cc") & (coll == "gnma30")) {
start_time_cc <- Sys.time()
cat("running cc mdl", "\n")         
              #step 1: handle incentive dial             
              
              cc_submdl  <- submdl.spl$incentive$functions
              
              cc_list  <- c("purch_incentive","refi_co_incentive","refi_nco_incentive","hmod_incentive","nhmod_incentive","rp_incentive")
              
              names(cc_submdl)  <- cc_list
              
              cc.df <- data.frame(matrix(nrow = nrow(ppdata), ncol = length(cc_list)))
              names(cc.df) <- cc_list
             
                for (p in names(cc_submdl)) {
                    if(!(p %in% names(ppdata))) {
                        cc.df[, p] <- 1.0
                        cat("ATTENTION!Missing cc incentive in INPUT!", " missing: ", p, "\n")
                    }
                    else {
                        idx <- match(p, names(cc_submdl))
                        a <- unlist(cc_submdl[idx][[1]][1]) 
                        b <- unlist(cc_submdl[idx][[1]][2])
                        x <- ppdata[, p]
                        cc.df[, p] <- BuildSpline(a = a, b = b, x = x)$y
                    }
                }

              cc.df  <- data.frame(cc.df)
              
              cc.df$incentive     <-  (cc.df$purch_incentive * data$pct_purchase + cc.df$refi_co_incentive * data$pct_refi_co + cc.df$refi_nco_incentive * data$pct_refi_nco + cc.df$hmod_incentive * data$pct_hmod + cc.df$nhmod_incentive * data$pct_nhmod + cc.df$rp_incentive * data$pct_rp) / 100 
              
              #step 2: handle msi dials  
              
              none_msi_cc      <- submdl.spl$monthsSinceIssued$functions["none"]
              hmod_msi_cc      <- submdl.spl$monthsSinceIssued$functions["hampMod"]
              nhmod_msi_cc     <- submdl.spl$monthsSinceIssued$functions["nonHampMod"]
              rp_msi_cc        <- submdl.spl$monthsSinceIssued$functions["reperf"]
              
              msi_cc_submdl   <- c(none_msi_cc,hmod_msi_cc,nhmod_msi_cc,rp_msi_cc)
              
              msi_cc_list  <- c("none_msi","hmod_msi","nhmod_msi","rp_msi")
              
              names(msi_cc_submdl)   <-  msi_cc_list
            
              msi_cc.df <- data.frame(matrix(nrow = nrow(ppdata), ncol = length(msi_cc_list)))
              names(msi_cc.df) <- msi_cc_list
                            
                for (p in names(msi_cc_submdl)) {
                    if(!(p %in% names(ppdata))) {
                        msi_cc.df[, p] <- 1.0
                        cat("ATTENTION!Missing fta msi in INPUT!", " missing: ", p, "\n")
                    }
                    else {
                        idx <- match(p, names(msi_cc_submdl))
                        a <- unlist(msi_cc_submdl[idx][[1]][1]) 
                        b <- unlist(msi_cc_submdl[idx][[1]][2])
                        x <- ppdata[, p]
                        msi_cc.df[, p] <- BuildSpline(a = a, b = b, x = x)$y
                    }
                }

              msi_cc.df  <- data.frame(msi_cc.df) 
              
              mult.df$msi  <- (ppdata$pct_hmod * msi_cc.df$hmod_msi + ppdata$pct_nhmod * msi_cc.df$nhmod_msi + ppdata$pct_rp * msi_cc.df$rp_msi + ppdata$pct_none * msi_cc.df$none_msi) / 100
              
              #step 3: result
              
              mult.df  <- data.frame(mult.df)
           
              submdl.pred <- submdl.pred * mult.df[, "wala1"] * mult.df[, "wala2"] * mult.df[, "cltv"] * mult.df[, "wacls"] * mult.df[, "fico1"] * mult.df[, "fico2"] * 
              cc.df[, "incentive"] * mult.df[, "hpa_cum"] * mult.df[, "msi"]
end_time_cc <- Sys.time()
cat("cc mdl finish ", difftime(end_time_cc, start_time_cc, units='mins'), "\n")      
        }
        else if ((submodel == "fta") & (coll == "gnma30")) {
start_time_fta <- Sys.time()
cat("running fta mdl", "\n")        
              #step 1: handle incentive multi curve
              
              mult.df  <- data.frame(mult.df)
              
              tangible_submdl                   <- submdl.spl$incentive$functions
              names(tangible_submdl)          <- c("tangible_0","tangible_1")
              
              fta_list  <- c("tangible_0","tangible_1")
            
              fta.df <- data.frame(matrix(nrow = nrow(ppdata), ncol = length(fta_list)))
              names(fta.df) <- fta_list
              
                for (p in names(tangible_submdl)) {
                    if(!(p %in% names(ppdata))) {
                        fta.df[, p] <- 1.0
                        cat("ATTENTION!Missing FTA incentive in INPUT!", " missing: ", p, "\n")
                    }
                    else {
                        idx <- match(p, names(tangible_submdl))
                        a <- unlist(tangible_submdl[idx][[1]][1]) 
                        b <- unlist(tangible_submdl[idx][[1]][2])
                        x <- ppdata[, p]
                        fta.df[, p] <- BuildSpline(a = a, b = b, x = x)$y
                    }
                }
                
              fta.df  <- data.frame(fta.df)

              mult.df$tangible     <-  fta.df$tangible_0 * (1.0 - data$tangibleBenefit_interp) + fta.df$tangible_1 * data$tangibleBenefit_interp
              
              #step 2: handle wacls
              
              fta_wacls_submdl  <- submdl.spl$wacls$functions
              
              fta_wacls_list  <- c("TXPurch_wacls","TXNonPurch_wacls","nonTXPurch_wacls","nonTXNonPurch_wacls")
              
              names(fta_wacls_submdl)  <- fta_wacls_list
              
              fta_wacls.df <- data.frame(matrix(nrow = nrow(ppdata), ncol = length(fta_wacls_list)))
              names(fta_wacls.df) <- fta_wacls_list
             
                for (p in names(fta_wacls_submdl)) {
                    if(!(p %in% names(ppdata))) {
                        fta_wacls.df[, p] <- 1.0
                        cat("ATTENTION!Missing fta wacls in INPUT!", " missing: ", p, "\n")
                    }
                    else {
                        idx <- match(p, names(fta_wacls_submdl))
                        a <- unlist(fta_wacls_submdl[idx][[1]][1]) 
                        b <- unlist(fta_wacls_submdl[idx][[1]][2])
                        x <- ppdata[, p]
                        fta_wacls.df[, p] <- BuildSpline(a = a, b = b, x = x)$y
                    }
                }

              fta_wacls.df  <- data.frame(fta_wacls.df) 
              
              mult.df$wacls     <-  (fta_wacls.df$TXPurch_wacls * data$pct_TX * data$pct_purchase + fta_wacls.df$TXNonPurch_wacls * data$pct_TX * (100 - data$pct_purchase)
                                    + fta_wacls.df$nonTXPurch_wacls * (100 - data$pct_TX) * data$pct_purchase + fta_wacls.df$nonTXNonPurch_wacls * (100 - data$pct_TX) * (100 - data$pct_purchase)) / 10000 
                                    
              #step 3: handle msi dials  
              
              none_msi_fta      <- submdl.spl$monthsSinceIssued$functions["none"]
              hmod_msi_fta      <- submdl.spl$monthsSinceIssued$functions["hampMod"]
              nhmod_msi_fta     <- submdl.spl$monthsSinceIssued$functions["nonHampMod"]
              rp_msi_fta        <- submdl.spl$monthsSinceIssued$functions["reperf"]
              
              msi_fta_submdl   <- c(none_msi_fta,hmod_msi_fta,nhmod_msi_fta,rp_msi_fta)
              
              msi_fta_list  <- c("none_msi","hmod_msi","nhmod_msi","rp_msi")
              
              names(msi_fta_submdl)   <-  msi_fta_list
            
              msi_fta.df <- data.frame(matrix(nrow = nrow(ppdata), ncol = length(msi_fta_list)))
              names(msi_fta.df) <- msi_fta_list
                            
                for (p in names(msi_fta_submdl)) {
                    if(!(p %in% names(ppdata))) {
                        msi_fta.df[, p] <- 1.0
                        cat("ATTENTION!Missing fta msi in INPUT!", " missing: ", p, "\n")
                    }
                    else {
                        idx <- match(p, names(msi_fta_submdl))
                        a <- unlist(msi_fta_submdl[idx][[1]][1]) 
                        b <- unlist(msi_fta_submdl[idx][[1]][2])
                        x <- ppdata[, p]
                        msi_fta.df[, p] <- BuildSpline(a = a, b = b, x = x)$y
                    }
                }

              msi_fta.df  <- data.frame(msi_fta.df) 
              
              mult.df$msi  <- (ppdata$pct_hmod * msi_fta.df$hmod_msi + ppdata$pct_nhmod * msi_fta.df$nhmod_msi + ppdata$pct_rp * msi_fta.df$rp_msi + ppdata$pct_none * msi_fta.df$none_msi) / 100
                                    
              #step 4: result              
              mult.df  <- data.frame(mult.df)
              
              submdl.pred <- submdl.pred * mult.df[, "wacls"] * mult.df[, "wala"] * mult.df[, "fico"] * mult.df[, "tangible"] * mult.df[, "msi"] *
              ((mult.df[, "NY_wacls"] * data[, "pct_NY"] + 1.0 * (100 - data[, "pct_NY"]))/100)
end_time_fta <- Sys.time()
cat("fta mdl finish ", difftime(end_time_fta, start_time_fta, units='mins'), "\n")       
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
