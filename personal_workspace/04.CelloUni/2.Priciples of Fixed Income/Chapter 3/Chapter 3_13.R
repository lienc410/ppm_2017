CalculateBondPrice <- function (cpn,mat,yld,par){
  
  px <- cpn/yld + (par - cpn/yld) * (1 + yld)^(-2 * mat) - 9800
}

GetYTM <- function(cpn, mat, yld, par, price){
  result <- CalculateBondPrice - price
  
}

price <- 9800
C <- 280
T <- 8
par <- 10000

r <- seq(0.02, 0.04, length = 300)

prices <- CalculateBondPrice(cpn=C, mat=T, yld=r, par=par)
yield.to.maturaty <- spline(prices, r, xout=prices)

plot(r,prices, xlab="yield to maturity", ylab="bond price",
     type="l", lwd=2)
abline(h=1200)
abline(v=yield.to.maturity)


uniroot(function(r) r^2 - 0.5, c(0.7,0.8))

result <- uniroot(GetYTM,  c(-1,1), cpn=C, mat=T, par=par, price=price)
result$root

result <- uniroot(CalculateBondPrice,  c(-1,1), cpn=C, mat=T, par=par)
result$root

f1 <- function (x, a, b) a*x+b

