-- Before execute the script, need to set the tickers
DROP TABLE IF EXISTS #ticker;
CREATE TABLE #ticker(
    tickerName varchar(20),
    mtgRateSeries varchar(30)
)
;
--INSERT #ticker SELECT 'FGLMC', 'CONVENTIONAL_30YR';   --Conventional Freddie
--INSERT #ticker SELECT 'FGT6', 'JUMBO_30YR';           --Jumbo Freddie
--INSERT #ticker SELECT 'FGU6', 'CONVENTIONAL_30YR';    --CQ Freddie High LTV[105-125]
--INSERT #ticker SELECT 'FGU9', 'CONVENTIONAL_30YR';    --CR Freddie High LTV[125-150]
INSERT #ticker SELECT 'FGTW', 'CONVENTIONAL_20YR';    --15 Yr Conventional Freddie
INSERT #ticker SELECT 'FGU5', 'CONVENTIONAL_20YR';    --15 Yr Freddie High LTV
INSERT #ticker SELECT 'FGU8', 'CONVENTIONAL_20YR';    --15 Yr Freddie High LTV
INSERT #ticker SELECT 'FGT5', 'JUMBO_20YR';           --15 Yr Jumbo Freddie
COMMIT;

CREATE INDEX pool_tickerName_idx ON #ticker(tickerName);
COMMIT;

