library(lubridate)
context("Prepayment Model Functions")



test_that("AddMonths is correctly adding months", {
  expect_equal(AddMonths(as.Date(c("2017-01-01")), 12), as.Date(c("2018-01-01")))
})

test_that("AddMonths is correctly subtracting months", {
  expect_equal(AddMonths(as.Date(c("2017-01-01")), -12), as.Date(c("2016-01-01")))
})