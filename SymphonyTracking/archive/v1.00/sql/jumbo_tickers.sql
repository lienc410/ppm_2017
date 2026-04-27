-- Before execute the script, need to set the ticker 
DROP TABLE IF EXISTS #ticker;
CREATE TABLE #ticker(
    tickerName varchar(20),
    mtgRateSeries varchar(30)
)
;
INSERT #ticker SELECT 'FNCK', 'JUMBO_30YR';           --Jumbo Fannie
INSERT #ticker SELECT 'FGT6', 'JUMBO_30YR';           --Jumbo Freddie
COMMIT;
CREATE INDEX loan_tickerName_idx ON #ticker(tickerName);
COMMIT;
