rm(list = ls())
gc()

require(jsonlite) # json utility
source("C:/PIV/PIV-it-dev/trunk/Research/AgencyPrepayment/Baton/batonutil/R/spline_utilities.R")

SplineCurveOutput <- function(model.type, submodel.name, submodel.mdl){
  
  for(para_count in 3: length(submodel.mdl)){
    
    x.min       <- submodel.mdl[[para_count]]$Knots[1]
    x.max       <- submodel.mdl[[para_count]]$Knots[length(submodel.mdl[[para_count]]$Knots)]
    x.expand    <- 0.2
    
    if(class(submodel.mdl[[para_count]]$Knots) != "character"){
      x.range     <- x.max - x.min
      x.rang.min  <- x.min - x.range * x.expand
      x.rang.max  <- x.max + x.range * x.expand
      x.val       <- seq(x.rang.min, x.rang.max)
      
      model.smm   <- SplineFunc(submodel.mdl[[para_count]]$Knots, submodel.mdl[[para_count]]$KnotValues, x.val)
      output.file <- paste("../output/spline_tieout/",model.type,"_",submodel.name,"_",names(submodel.mdl[para_count]),"_spline_testing.csv",  sep = "")
      write.csv(data.frame(x=x.val, model.smm=model.smm), output.file) 
    }
  }
}

#######################
# Conventional        #
#######################
# prepay.mdl <- fromJSON(paste("C:/PIV/PIV-it-dev/trunk/Research/AgencyPrepayment/Baton2/JSON/conv30/v4.20/conv30_model.json"))
prepay.mdl <- fromJSON(paste("S:/IT/Dev/Scale/PrepayModel/ModelSpecification/Baton_v4.20.json"))
conventional.mdl <- prepay.mdl$Conventional

SplineCurveOutput("conventional","refinance", conventional.mdl$RefinanceSubModel)
SplineCurveOutput("conventional","turnover", conventional.mdl$TurnoverSubModel)
SplineCurveOutput("conventional","default_current", conventional.mdl$DefaultSubModelCurr)
SplineCurveOutput("conventional","default_dq", conventional.mdl$DefaultSubModelDelq)
SplineCurveOutput("conventional","curtailment", conventional.mdl$CurtailmentSubModel)
SplineCurveOutput("conventional","cashout", conventional.mdl$CashoutSubModel)



#######################
# Ginnie              #
#######################
prepay.mdl <- fromJSON(paste("../JSON/ginnie/v3.00/gnma30_model.json"))

for(model.type.count in 3:length(prepay.mdl)){
  
  ginnie.mdl <- prepay.mdl[[model.type.count]]
  loan.type  <- names(prepay.mdl[model.type.count])
  model.type <- paste("ginnie_",loan.type,sep="")
  
  SplineCurveOutput(model.type, "refinance", ginnie.mdl$RefinanceSubModel)
  SplineCurveOutput(model.type, "turnover", ginnie.mdl$TurnoverSubModel)
  SplineCurveOutput(model.type, "default_current", ginnie.mdl$DefaultSubModelCurr)
  SplineCurveOutput(model.type, "default_dq", ginnie.mdl$DefaultSubModelDelq)
  SplineCurveOutput(model.type, "curtailment", ginnie.mdl$CurtailmentSubModel)
  SplineCurveOutput(model.type, "cashout", ginnie.mdl$CashoutSubModel)
}