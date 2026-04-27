-- Before execute the script, need to set the ticker 
DROP TABLE IF EXISTS #ticker;
CREATE TABLE #ticker(
    tickerName varchar(20),
    mtgRateSeries varchar(30)
)
;
INSERT #ticker SELECT 'FNCL', 'CONVENTIONAL_30YR';    --Conventional Fannie
INSERT #ticker SELECT 'FGLMC', 'CONVENTIONAL_30YR';   --Conventional Freddie
INSERT #ticker SELECT 'FGU6', 'CONVENTIONAL_30YR';    --CQ Freddie High LTV[105-125]
INSERT #ticker SELECT 'FGU9', 'CONVENTIONAL_30YR';    --CR Freddie High LTV[125-150]
INSERT #ticker SELECT 'FNCQ30', 'CONVENTIONAL_30YR';  --CQ Fannie High LTV[105-125]
INSERT #ticker SELECT 'FNCR', 'CONVENTIONAL_30YR';    --CR Fannie High LTV[125-150]
INSERT #ticker SELECT 'FNCK', 'JUMBO_30YR';           --Jumbo Fannie
INSERT #ticker SELECT 'FGT6', 'JUMBO_30YR';           --Jumbo Freddie
COMMIT;
CREATE INDEX loan_tickerName_idx ON #ticker(tickerName);
COMMIT;
