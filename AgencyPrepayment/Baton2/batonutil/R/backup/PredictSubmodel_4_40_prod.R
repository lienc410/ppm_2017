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
PredictSubmodel_4_40_prod <- function(coll, submodel = NA, submdl.spl, data, seasadj = FALSE, version = "") {
    
    submdl.spl <- submdl.spl
    
    if (!any(is.na(submdl.spl))) {
        param.submdl <- names(submdl.spl)[-match(c("baselineConstant", "adjustmentFactor", "seasonalityMultipliers"), 
                                                 names(submdl.spl))]
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
              submdl.pred <- submdl.pred * mult.df[, "hpa2yr"] * mult.df[, "burnout"] * mult.df[, "cltv"] *
                mult.df[, "refi_elig_pct"] * mult.df[, "pct_HARPed"] * mult.df[, "HARP_eligible"]  * mult.df[, "wala"] * mult.df[, "pct_second_lien"] * mult.df[, "pct_purchase"] * mult.df[, "fico"] * mult.df[, "pct_tpo"] * mult.df[, "wacls"] * 
                ((mult.df[, "lomedia_nonRetail_wacls"] * data[, "pct_NonRETAIL"] + mult.df[, "lomedia_broker_wacls"] * data[, "pct_BROKER"] + mult.df[, "lomedia_corres_wacls"] * data[, "pct_CORRES"] + mult.df[, "lomedia_retailCashWindow_wacls"] * data[, "pct_RETAIL_CashWindow"] + mult.df[, "lomedia_retailNonCashWindow_wacls"] * data[, "pct_RETAIL_NonCashWindow"])/100) *
                ((mult.df[, "purch_oltv"] * data[, "pct_purchase"] + mult.df[, "refi_HARP_oltv"] * data[, "pct_HARPed"] + mult.df[, "refi_NonHARP_oltv"] * (100 - data[, "pct_purchase"] - data[, "pct_HARPed"]))/ 100) *
                ((mult.df[, "preHARP_wacls"] * data[, "pct_preHARP"] + 1.0 * (100 - data[, "pct_preHARP"]))/100) *
                ((mult.df[, "NY_wacls"] * data[, "pct_NY"] + 1.0 * (100 - data[, "pct_NY"]))/100) *
                (mult.df[, "lomedia_incentive"] * (1 - mult.df[, "media_effect"]) + mult.df[, "himedia_incentive"] * mult.df[, "media_effect"])
            }
            else if ((coll == "conv30") & (version == "v4.30")){
              submdl.pred <- submdl.pred * mult.df[, "cai"] * mult.df[, "hpa2yr"] * mult.df[, "burnout"] * mult.df[, "wacls"] * mult.df[, "cltv"] *
                mult.df[, "refi_elig_pct"] * mult.df[, "pct_tpo"] * mult.df[, "pct_HARPed"] * mult.df[, "HARP_eligible"] * mult.df[, "wala"] * 
                mult.df[, "pct_purchase"] * mult.df[, "pct_inv"] * mult.df[, "pct_second_lien"] * mult.df[, "fico"] *
                ((mult.df[, "purch_oltv"] * data[, "pct_purchase"] + mult.df[, "refi_HARP_oltv"] * data[, "pct_HARPed"] + mult.df[, "refi_NonHARP_oltv"] * (100 - data[, "pct_purchase"] - data[, "pct_HARPed"]))/ 100) *
                (mult.df[, "lomedia_incentive"] * (1 - mult.df[, "media_effect"]) + mult.df[, "himedia_incentive"] * mult.df[, "media_effect"])
            }
            else {
              submdl.pred <- submdl.pred * mult.df[, "hpa2yr"] * mult.df[, "burnout"] * mult.df[, "cltv"] *
                mult.df[, "refi_elig_pct"] * mult.df[, "pct_HARPed"] * mult.df[, "HARP_eligible"] * mult.df[, "wala"] * 
                mult.df[, "pct_purchase"] * mult.df[, "pct_inv"] * mult.df[, "pct_second_lien"] * mult.df[, "fico"] * mult.df[, "wacls"] * 
                ((mult.df[, "lomedia_nonRetail_wacls"] * data[, "pct_NonRETAIL"] + mult.df[, "lomedia_broker_wacls"] * data[, "pct_BROKER"] + mult.df[, "lomedia_corres_wacls"] * data[, "pct_CORRES"] + mult.df[, "lomedia_retailCashWindow_wacls"] * data[, "pct_RETAIL_CashWindow"] + mult.df[, "lomedia_retailNonCashWindow_wacls"] * data[, "pct_RETAIL_NonCashWindow"])/100) *
                ((mult.df[, "purch_oltv"] * data[, "pct_purchase"] + mult.df[, "refi_HARP_oltv"] * data[, "pct_HARPed"] + mult.df[, "refi_NonHARP_oltv"] * (100 - data[, "pct_purchase"] - data[, "pct_HARPed"]))/ 100) *
                ((mult.df[, "preHARP_wacls"] * data[, "pct_preHARP"] + 1.0 * (100 - data[, "pct_preHARP"]))/100) *
                ((mult.df[, "NY_wacls"] * data[, "pct_NY"] + 1.0 * (100 - data[, "pct_NY"]))/100) *
                (mult.df[, "lomedia_incentive"] * (1 - mult.df[, "media_effect"]) + mult.df[, "himedia_incentive"] * mult.df[, "media_effect"])          
            }
        }
        else if ((submodel == "turn") & (coll == "conv30") & (version == "v4.30")) {
            submdl.pred <- submdl.pred * mult.df[, "cai"] * mult.df[, "hpa_annual"] * mult.df[, "incentive"] * 
              mult.df[, "cltv"] * mult.df[, "acls"] * mult.df[, "fico"] *mult.df[, "tax"] * mult.df[, "sato"] * mult.df[, "HARP_eligible"] *
              mult.df[, "pct_purchase"] * mult.df[, "pct_inv"] * mult.df[, "pct_second_lien"] *
              ((mult.df[, "purch_oltv"] * data[, "pct_purchase"] + mult.df[, "refi_HARP_oltv"] * data[, "pct_HARPed"] + mult.df[, "refi_NonHARP_oltv"] * (100 - data[, "pct_purchase"] - data[, "pct_HARPed"]))/ 100) *
              (mult.df[, "fico_acls_interact_2_fico"] * mult.df[, "fico_acls_interact_1_acls"] + 1 *(1 - mult.df[, "fico_acls_interact_2_fico"])) *
              (mult.df[, "lohpa_wala"] * (1 - mult.df[, "pct_hihpa_wala"]) + mult.df[, "hihpa_wala"] * mult.df[, "pct_hihpa_wala"])
        }
        else if ((submodel == "turn") & (coll == "conv30")) {
            submdl.pred <- submdl.pred * mult.df[, "hpa_annual"] * mult.df[, "incentive"] *
              mult.df[, "cltv"] * mult.df[, "fico"] *mult.df[, "tax"] * mult.df[, "sato"] * mult.df[, "HARP_eligible"] *
              mult.df[, "pct_purchase"] * mult.df[, "pct_inv"] * mult.df[, "pct_second_lien"] * mult.df[, "acls"] * 
              ((mult.df[, "nonRetail_acls"] * data[, "pct_NonRETAIL"] + mult.df[, "broker_acls"] * data[, "pct_BROKER"] + mult.df[, "corres_acls"] * data[, "pct_CORRES"] + mult.df[, "retailCashWindow_acls"] * data[, "pct_RETAIL_CashWindow"] + mult.df[, "retailNonCashWindow_acls"] * data[, "pct_RETAIL_NonCashWindow"])/100) *
              ((mult.df[, "purch_oltv"] * data[, "pct_purchase"] + mult.df[, "refi_HARP_oltv"] * data[, "pct_HARPed"] + mult.df[, "refi_NonHARP_oltv"] * (100 - data[, "pct_purchase"] - data[, "pct_HARPed"]))/ 100) *
              ((mult.df[, "preHARP_acls"] * data[, "pct_preHARP"] + 1.0 * (100 - data[, "pct_preHARP"]))/100) *
              ((mult.df[, "NY_acls"] * data[, "pct_NY"] + 1.0 * (100 - data[, "pct_NY"]))/100) *
              (mult.df[, "fico_acls_interact_2_fico"] * mult.df[, "fico_acls_interact_1_acls"] + 1 *(1 - mult.df[, "fico_acls_interact_2_fico"])) *
              (mult.df[, "lohpa_wala"] * (1 - mult.df[, "pct_hihpa_wala"]) + mult.df[, "hihpa_wala"] * mult.df[, "pct_hihpa_wala"])       
        }      
        else if ((submodel == "turn") & (coll == "gnma30")) {
              submdl.pred <- submdl.pred * mult.df[, "hpa_annual"] * mult.df[, "incentive"] * mult.df[, "acls"] * 
              mult.df[, "cltv"] * mult.df[, "fico"] *mult.df[, "tax"] * mult.df[, "HARP_eligible"] * mult.df[, "pct_second_lien"] *
              ((mult.df[, "nonRetail_acls"] * data[, "pct_NonRETAIL"] + mult.df[, "broker_acls"] * data[, "pct_BROKER"] + mult.df[, "corres_acls"] * data[, "pct_CORRES"] + mult.df[, "retailCashWindow_acls"] * data[, "pct_RETAIL_CashWindow"] + mult.df[, "retailNonCashWindow_acls"] * data[, "pct_RETAIL_NonCashWindow"])/100) *
              ((mult.df[, "purch_oltv"] * data[, "pct_purchase"] + mult.df[, "refi_HARP_oltv"] * data[, "pct_HARPed"] + mult.df[, "refi_NonHARP_oltv"] * (100 - data[, "pct_purchase"] - data[, "pct_HARPed"]))/ 100) *
              ((mult.df[, "preHARP_acls"] * data[, "pct_preHARP"] + 1.0 * (100 - data[, "pct_preHARP"]))/100) *
              ((mult.df[, "NY_acls"] * data[, "pct_NY"] + 1.0 * (100 - data[, "pct_NY"]))/100) *
              (mult.df[, "fico_acls_interact_2_fico"] * mult.df[, "fico_acls_interact_1_acls"] + 1 *(1 - mult.df[, "fico_acls_interact_2_fico"])) *
              (mult.df[, "lohpa_wala"] * (1 - mult.df[, "pct_hihpa_wala"]) + mult.df[, "hihpa_wala"] * mult.df[, "pct_hihpa_wala"])
        }
        else if ((submodel == "cout") & (coll == "conv30") & (version == "v4.40")) {
              submdl.pred <- submdl.pred * mult.df[, "wala"] * mult.df[, "incentive"] * 
              mult.df[, "cltv"] * mult.df[, "pct_HARPed"] * mult.df[, "fico"] * mult.df[, "refi_elig_pct"] * mult.df[, "hpa_cum"] * mult.df[, "hpa2yr"] *  mult.df[, "wacls"] *
              ((mult.df[, "preHARP_wacls"] * data[, "pct_preHARP"] + 1.0 * (100 - data[, "pct_preHARP"]))/100) *
              ((mult.df[, "NY_wacls"] * data[, "pct_NY"] + 1.0 * (100 - data[, "pct_NY"]))/100) *
              ((mult.df[, "nonRetail_wacls"] * data[, "pct_NonRETAIL"] + mult.df[, "broker_wacls"] * data[, "pct_BROKER"] + mult.df[, "corres_wacls"] * data[, "pct_CORRES"] + mult.df[, "retailCashWindow_wacls"] * data[, "pct_RETAIL_CashWindow"] + mult.df[, "retailNonCashWindow_wacls"] * data[, "pct_RETAIL_NonCashWindow"])/100)             
        }
        else if ((submodel == "cout") & (coll == "gnma30")) {
              submdl.pred <- submdl.pred * mult.df[, "wala"] * mult.df[, "incentive"] * 
              mult.df[, "cltv"] * mult.df[, "pct_HARPed"] * mult.df[, "fico"] * mult.df[, "refi_elig_pct"] * mult.df[, "hpa_cum"] * mult.df[, "hpa2yr"] *
              mult.df[, "wacls"] *
              ((mult.df[, "nonRetail_wacls"] * data[, "pct_NonRETAIL"] + mult.df[, "broker_wacls"] * data[, "pct_BROKER"] + mult.df[, "corres_wacls"] * data[, "pct_CORRES"] + mult.df[, "retailCashWindow_wacls"] * data[, "pct_RETAIL_CashWindow"] + mult.df[, "retailNonCashWindow_wacls"] * data[, "pct_RETAIL_NonCashWindow"])/100) *
              ((mult.df[, "NY_wacls"] * data[, "pct_NY"] + 1.0 * (100 - data[, "pct_NY"]))/100) *
              ((mult.df[, "preHARP_wacls"] * data[, "pct_preHARP"] + 1.0 * (100 - data[, "pct_preHARP"]))/100)          
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
