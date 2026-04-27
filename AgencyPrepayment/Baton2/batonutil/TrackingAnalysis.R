require(ggplot2)
require(plyr)
library(gridExtra)

ppdata$incentive    <- ppdata$incentive.store
ppdata$waolsBucket  <- as.numeric(ppdata$waolsBucket)
ppdata$secondLien   <- as.factor(ppdata$secondLien)
ppdata$occType      <- ifelse(ppdata$occType == '2ND', 'NONINV', ppdata$occType)
ppdata$occType      <- ifelse(ppdata$occType == 'OWNER', 'NONINV', ppdata$occType)
# ppdata$hpa_annualBucket <- ppdata$hpaBucket
# ppdata$hpa2yrBucket <- ifelse(ppdata$hpa2yr < 104, '104', '107')
# ppdata$hpa2yrBucket <- ifelse(ppdata$hpa2yr > 107, '113',  ppdata$hpa2yrBucket)
# summary(ppdata)

# get subset of model
# subdata           <- subset(ppdata, asofdate > '2009-06-01')
# subdata           <- subset(ppdata, marketTicker > 'FGLMC')
subdata             <- ppdata
subdata$ones        <- rep(1, nrow(subdata))
subdata           <- subset(subdata, incentive >= -100)
subdata           <- subset(subdata, incentive <  -25)
# subdata           <- subset(subdata, wacls > 175)
# subdata           <- subset(subdata, high_oltv == 0)
# subdata           <- subset(subdata, wala > 6)
# subdata           <- subset(subdata, wala <= 30)
# subdata           <- subset(subdata, hpa_annualBucket == 8)
# subdata             <- subset(subdata, waolsBucket == 800)
# subdata             <- subset(subdata, asofdate >= as.Date('2017-03-01'))
# subdata             <- subset(subdata, asofdate == as.Date('2018-2-01'))

me.flag             <- read.csv("../data/conv30/ME_flag.csv")
me.flag$Asof        <- as.Date(me.flag$Asof)
subdata             <- inner_join(subdata, me.flag, by=c('asofdate' = 'Asof'))
subdata             <- subset(subdata, Low_ME_Flag == 1)

quantile(subdata$incentive, prob = seq(from=0, to=1, by=.1))

# subdata <- subdata[,1:50]
# summary(subdata)

bal.ration    <- sum(subdata$bal) / sum(ppdata$bal) * 100
cat(bal.ration, "% of initial balance is selected", sep = "")


step.df         <- data.frame()
Bucket.Step <- function(step.by, step = 0, from = 0, to = 0, overwrite = TRUE, numeric = TRUE, spline = FALSE){
  df            <- data.frame(step.by, step, from, to, overwrite, numeric, spline)
  step.df       <- rbind(step.df, df)
}

# flexible plot bucket
#   step and from/to defines the bucket for the parameter
#   overwrite sets whether of not overwrite the existing "bucket" in the raw data file
#   numeric defines whether of not to treat the parameter as a numeric variable, if not then the step bucket won't be applied
#   spline sets if output the spline into output package

# step.df         <- Bucket.Step(step.by = 'asofdate',                                  overwrite = FALSE, numeric = FALSE, spline = FALSE)
# step.df         <- Bucket.Step(step.by = 'incentive', step = 25, from = -200, to = 250, overwrite = TRUE,  numeric = TRUE, spline = FALSE)
step.df         <- Bucket.Step(step.by = 'wala', step = 6, from = 0, to = 60, overwrite = TRUE,  numeric = TRUE, spline = FALSE)
# step.df         <- Bucket.Step(step.by = 'hpa_annual', step = 0.5, from = 0, to = 11, overwrite = TRUE,  numeric = TRUE, spline = FALSE)
# step.df         <- Bucket.Step(step.by = 'ones',                                        overwrite = FALSE, numeric = FALSE, spline = FALSE)
# step.df         <- Bucket.Step(step.by = 'burnout',   step = 2000, from = 2000, to = 10000, overwrite = TRUE,  numeric = TRUE, spline = FALSE)
# step.df         <- Bucket.Step(step.by = 'wacls',     step = 50, from = 0,    to = 300, overwrite = TRUE,  numeric = TRUE)
step.df         <- Bucket.Step(step.by = 'waols',                                       overwrite = FALSE, numeric = TRUE, spline = FALSE)
# step.df         <- Bucket.Step(step.by = 'sato',      step = 50, from = -100, to = 100, overwrite = FALSE, numeric = TRUE, spline = FALSE)
# step.df         <- Bucket.Step(step.by = 'fico',      step = 40, from = 640,  to = 800, overwrite = FALSE, numeric = TRUE, spline = FALSE)
# step.df         <- Bucket.Step(step.by = 'occType',                                     overwrite = FALSE, numeric = FALSE, spline = FALSE)
# step.df         <- Bucket.Step(step.by = 'loanPurposeType',                             overwrite = FALSE, numeric = FALSE, spline = FALSE)
# step.df         <- Bucket.Step(step.by = 'secondLien',                                  overwrite = FALSE, numeric = FALSE, spline = FALSE)
# step.df         <- Bucket.Step(step.by = 'hpa2yr',                                      overwrite = FALSE, numeric = TRUE, spline = TRUE)
# step.df         <- Bucket.Step(step.by = 'hpa_annual',                                          overwrite = FALSE, numeric = TRUE, spline = FALSE)

for (row in 1:nrow(step.df)) {
  step.by       <- paste(step.df$step.by[row])
  step          <- step.df$step[row]
  step.from     <- step.df$from[row]
  step.to       <- step.df$to[row]
  step.overwrite <- step.df$overwrite[row]
  
  if(step.overwrite == TRUE){
    x             <- paste(step.by, 'Bucket', sep = "")
    subdata[[x]]  <- ceiling(subdata[[step.by]] / step) * step
    subdata[[x]]  <- ifelse(subdata[[step.by]] < step.from, step.from, subdata[[x]])
    subdata[[x]]  <- ifelse(subdata[[step.by]] > step.to,   step.to,   subdata[[x]])
  }
}

plot.time.stamp   <- format(Sys.time(),'%m_%d_%H_%M')
plot.folder.name  <- paste("../output/output_", plot.time.stamp,sep='')
dir.create(plot.folder.name)

for (row in 2:nrow(step.df)) {
  group.by        <- paste(step.df$step.by[row])
  group.by.bucket <- ifelse(step.df$numeric[row] == TRUE, paste(group.by, 'Bucket', sep = ""), paste(group.by))
  plot.by         <- paste(step.df$step.by[1]) #'incentive'
  plot.by.bucket  <- ifelse(step.df$numeric[1] == TRUE, paste(plot.by, 'Bucket', sep = ""), paste(plot.by))
  plot.spline     <- step.df$spline[row]
  
  # smm plot  
  agg.data.smm       <- ddply(subdata, .(grp = subdata[[group.by.bucket]], x = subdata[[plot.by.bucket]]), summarise, 
                              actual.smm     = 100 * weighted.mean(smm, bal), 
                              model.smm      = 100 * weighted.mean(modelSMM_v4.20, bal),
                              actual.cpr     = 100 * (1-(1-weighted.mean(smm, bal))^12), 
                              model.cpr      = 100 * (1-(1-weighted.mean(modelSMM_v4.20, bal))^12),
                              ratio          = weighted.mean(smm, bal) / weighted.mean(modelSMM_v4.20, bal),
                              track.err      = 100 * weighted.mean(modelSMM_v4.20 - smm, bal),
                              curt.smm       = 100 * weighted.mean(curt_v4.20, bal),
                              dflt.smm       = 100 * weighted.mean(dfltall_v4.20, bal),
                              cout.smm       = 100 * weighted.mean(cout_v4.20, bal),
                              turn.smm       = 100 * weighted.mean(turn_v4.20, bal),
                              refi.smm       = 100 * weighted.mean(refi_v4.20, bal),
                              pct_inv	       =	weighted.mean(pct_inv, bal),
                              pct_2nd	       =	weighted.mean(pct_2nd, bal),
                              pct_owner	     =	weighted.mean(pct_owner, bal),
                              pct_purchase	 =	weighted.mean(pct_purchase, bal),
                              pct_REFI_NCO	 =	weighted.mean(pct_REFI_NCO, bal),
                              pct_REFI_CO	   =	weighted.mean(pct_REFI_CO, bal),
                              pct_REFI_Other =	weighted.mean(pct_REFI_Other, bal),
                              pct_REFI       =	weighted.mean(pct_REFI, bal),
                              pct_dq	       =	weighted.mean(pct_dq, bal),
                              incentive	     =	weighted.mean(incentive, bal),
                              burnout	       =	weighted.mean(burnout, bal),
                              refi_elig_pct	 =	weighted.mean(refi_elig_pct, bal),
                              cltv	         =	weighted.mean(cltv, bal),
                              wacls	         =	weighted.mean(wacls, bal),
                              acls	         =	weighted.mean(acls, bal),
                              wala	         =	weighted.mean(wala, bal),
                              wam 	         =	weighted.mean(wam, bal),
                              wac	           =	weighted.mean(wac, bal),
                              fico	         =	weighted.mean(fico, bal),
                              pct_HARPed     =	weighted.mean(pct_HARPed, bal),
                              pct_tpo	       =	weighted.mean(pct_tpo, bal),
                              cai	           =	weighted.mean(cai, bal),
                              media_effect	 =	weighted.mean(media_effect, bal),
                              sato	         =	weighted.mean(sato, bal),
                              hpa_annual    =	weighted.mean(hpa_annual, bal),
                              hpa_cum       =	weighted.mean(hpa_cum, bal),
                              turn_cai_mult	= weighted.mean(	turn_cai_v4.20	,bal),
                              turn_hpa_annual_mult	= weighted.mean(	turn_hpa_annual_v4.20	,bal),
                              turn_lohpa_wala_mult	= weighted.mean(	turn_lohpa_wala_v4.20	,bal),
                              turn_hihpa_wala_mult	= weighted.mean(	turn_hihpa_wala_v4.20	,bal),
                              turn_pct_hihpa_wala_mult	= weighted.mean(	turn_pct_hihpa_wala_v4.20	,bal),
                              turn_incentive_mult	= weighted.mean(	turn_incentive_v4.20	,bal),
                              turn_cltv_mult	= weighted.mean(	turn_cltv_v4.20	,bal),
                              turn_acls_mult	= weighted.mean(	turn_acls_v4.20	,bal),
                              turn_fico_mult	= weighted.mean(	turn_fico_v4.20	,bal),
                              turn_tax_mult	= weighted.mean(	turn_tax_v4.20	,bal),
                              turn_sato_mult	= weighted.mean(	turn_sato_v4.20	,bal),
                              turn_pct_HARPed_mult	= weighted.mean(	turn_pct_HARPed_v4.20	,bal),
                              turn_HARP_eligible_mult	= weighted.mean(	turn_HARP_eligible_v4.20	,bal),
                              turn_pct_purchase_mult	= weighted.mean(	turn_pct_purchase_v4.20	,bal),
                              turn_pct_inv_mult	= weighted.mean(	turn_pct_inv_v4.20	,bal),
                              turn_pct_second_lien_mult	= weighted.mean(	turn_pct_second_lien_v4.20	,bal),
                              # refi_cai_mult	 = weighted.mean(	refi_cai_v4.20	, bal),
                              # refi_hpa2yr_mult	 = weighted.mean(	refi_hpa2yr_v4.20	, bal),
                              # refi_wala_mult	 = weighted.mean(	refi_wala_v4.20	, bal),
                              # refi_lomedia_incentive_mult	 = weighted.mean(	refi_lomedia_incentive_v4.20	, bal),
                              # refi_himedia_incentive_mult	 = weighted.mean(	refi_himedia_incentive_v4.20	, bal),
                              # refi_cltv_mult	 = weighted.mean(	refi_cltv_v4.20	, bal),
                              # refi_wacls_mult	 = weighted.mean(	refi_wacls_v4.20	, bal),
                              # refi_fico_mult	 = weighted.mean(	refi_fico_v4.20	, bal),
                              # refi_refi_elig_pct_mult	 = weighted.mean(	refi_refi_elig_pct_v4.20	, bal),
                              # refi_pct_2nd_mult	 = weighted.mean(	refi_pct_2nd_v4.20	, bal),
                              # refi_pct_tpo_mult	 = weighted.mean(	refi_pct_tpo_v4.20	, bal),
                              # refi_media_effect_mult	 = weighted.mean(	refi_media_effect_v4.20	, bal),
                              # refi_burnout_mult	 = weighted.mean(	refi_burnout_v4.20	, bal),
                              # refi_pct_inv_mult	 = weighted.mean(	refi_pct_inv_v4.20	, bal),
                              # refi_pct_dq_mult	 = weighted.mean(	refi_pct_dq_v4.20	, bal),
                              # refi_pct_HARPed_mult	 = weighted.mean(	refi_pct_HARPed_v4.20	, bal),
                              # refi_HARP_eligible_mult	 = weighted.mean(	refi_HARP_eligible_v4.20	, bal),
                              bal            = sum(bal), std = sd(smm), n = length(smm)
                              ) 
  
  # smm plot   
  agg.data.by.grp       <- ddply(subdata, .(x = subdata[[group.by.bucket]]), summarise, 
                              actual.smm     = 100 * weighted.mean(smm, bal), 
                              model.smm      = 100 * weighted.mean(modelSMM_v4.20, bal),
                              ratio          = weighted.mean(smm, bal) / weighted.mean(modelSMM_v4.20, bal),
                              curt.smm       = 100 * weighted.mean(curt_v4.20, bal),
                              dflt.smm       = 100 * weighted.mean(dfltall_v4.20, bal),
                              cout.smm       = 100 * weighted.mean(cout_v4.20, bal),
                              turn.smm       = 100 * weighted.mean(turn_v4.20, bal),
                              refi.smm       = 100 * weighted.mean(refi_v4.20, bal),
                              bal            = sum(bal), std = sd(smm), n = length(smm)
                              ) 
  
  uniq.grp    <- unique(agg.data.smm$grp)
  plt         <- list()
  
  plotFile <- paste(plot.folder.name, "/grp_by_", group.by, "_plot_by_", plot.by, "_", plot.time.stamp, ".pdf", sep="")
  cat("Plot Aggreagated Result To: ", plotFile, "\n")
  pdf(plotFile, onefile = TRUE)
  
  for(grp.i in 1:length(uniq.grp)){
    plt[[grp.i]] <- list()
    agg.data.sub <- subset(agg.data.smm, grp == uniq.grp[grp.i])
    
    plt[[grp.i]]  <- ggplot(data = agg.data.sub) +
                    geom_point(color = "red", aes(x, actual.smm, size = bal / mean(bal)), alpha = 0.5)+
                    geom_text(aes(x, actual.smm, label=round(ratio, 2)), vjust = -1.0, alpha = 0.5) + 
                    geom_text(aes(x, actual.smm, label=round(bal/1000000000, 1)), vjust = 2.0, color = "red", alpha = 0.5) + 
                    geom_line(color = "blue", aes(x, model.smm), size = 0.7) +
                    geom_area(aes(x, curt.smm), alpha = 0.2) +
                    geom_area(aes(x, curt.smm + dflt.smm), alpha = 0.2) +
                    geom_area(aes(x, curt.smm + dflt.smm + cout.smm), alpha = 0.2) +
                    geom_area(aes(x, curt.smm + dflt.smm + cout.smm + turn.smm), alpha = 0.2) +
                    geom_area(aes(x, curt.smm + dflt.smm + cout.smm + turn.smm + refi.smm), alpha = 0.2) +
                    xlab(plot.by) + ylab("SMM") + theme(legend.position="none") + 
                    ggtitle(paste(group.by, ": ", uniq.grp[grp.i], sep=""))
    
    grid.arrange(plt[[grp.i]])
  }
  
  # plot by the "group by" parameter
  plt[[grp.i]] <- ggplot(data = agg.data.by.grp) +
                  geom_point(color = "red", aes(x, actual.smm, size = bal / mean(bal)), alpha = 0.5)+
                  geom_text(aes(x, actual.smm, label=round(ratio, 2)), vjust = -1.0, alpha = 0.5) + 
                  geom_text(aes(x, actual.smm, label=round(bal/1000000000, 1)), vjust = 2.0, color = "red", alpha = 0.5) + 
                  geom_point(color = "blue", aes(x, model.smm), size = 2, alpha = 0.5) +
                  xlab(group.by) + ylab("SMM") + theme(legend.position="none") + 
                  ggtitle(paste("Actual vs Model"))

  grid.arrange(plt[[grp.i]])
  
  # shows the shape of the parameter curve
  if(plot.spline){
    submodel.mdl  <- json$turn.mdl[[group.by]]
    x.min         <- submodel.mdl$Knots[1]
    x.max         <- submodel.mdl$Knots[length(submodel.mdl$Knots)]
    x.expand      <- 0.2
    
    x.range       <- x.max - x.min
    x.rang.min    <- x.min - x.range * x.expand
    x.rang.max    <- x.max + x.range * x.expand
    x.val         <- seq(from=x.rang.min, to=x.rang.max, by=(x.rang.max - x.rang.min)/100)
    
    y.val         <- BuildSpline(a = submodel.mdl$Knots, b = submodel.mdl$KnotValues, x = x.val)$y
    
    plt[[grp.i]]  <- ggplot() +
      geom_line(color = "blue", aes(x.val, y.val)) +
      geom_point(color = "red", aes(submodel.mdl$Knots, submodel.mdl$KnotValues), size = 2) +
      xlab(group.by) + ylab("Multiplier") + theme(legend.position="none") + 
      ggtitle(paste("Spline Shape For: ", group.by, sep=''))
    
    grid.arrange(plt[[grp.i]])
    
    output.file <- paste(plot.folder.name, "/", "", group.by, "_spline.csv",  sep = "")
    write.csv(data.frame(x=x.val, y=y.val), output.file) 
  }
  
  dev.off()
  
  outFile <- paste(plot.folder.name, "/grp_by_", group.by, "_plot_by_", plot.by, "_", plot.time.stamp, ".csv", sep="")
  cat("Save Aggreagated Result To: ", outFile, "\n")
  write.csv(agg.data.smm, file = outFile)
}

