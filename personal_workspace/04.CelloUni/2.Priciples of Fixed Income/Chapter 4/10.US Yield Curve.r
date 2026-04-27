data(FedYieldCurve)


require(xts)
require(YieldCurve)
data(FedYieldCurve)
first(FedYieldCurve,'3 month')
last(FedYieldCurve,'3 month')
mat<-c(3/12, 0.5, 1,2,3,5,7,10)
par(mfrow=c(2,2))

for( i in c(12+12*4+1,13+12*4+1,14+12*4+1,15+12*4+1) ){
  plot(mat, FedYieldCurve[i,], type="o", xlab="Maturities structure in years", ylab="Interest rates values")
  title(main=paste("Federal Reserve yield curve obeserved at",time(FedYieldCurve[i], sep=" ") ))
  grid()
}
