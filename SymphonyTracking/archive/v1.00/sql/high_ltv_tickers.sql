-- Before execute the script, need to set the ticker 
DROP TABLE IF EXISTS #ticker;
CREATE TABLE #ticker(
    tickerName varchar(20),
    mtgRateSeries varchar(30)
)
;
INSERT #ticker SELECT 'FGU6', 'CONVENTIONAL_30YR';    --CQ Freddie High LTV[105-125]
INSERT #ticker SELECT 'FGU9', 'CONVENTIONAL_30YR';    --CR Freddie High LTV[125-150]
INSERT #ticker SELECT 'FNCQ30', 'CONVENTIONAL_30YR';  --CQ Fannie High LTV[105-125]
INSERT #ticker SELECT 'FNCR', 'CONVENTIONAL_30YR';    --CR Fannie High LTV[125-150]
COMMIT;
CREATE INDEX loan_tickerName_idx ON #ticker(tickerName);
COMMIT;
