-- Before execute the script, need to set the ticker 
DROP TABLE IF EXISTS #ticker;
CREATE TABLE #ticker(
    tickerName varchar(20),
    mtgRateSeries varchar(30)
)
;
INSERT #ticker SELECT 'GPL', 'GNM_PL';   -- Ginnie Project Loan
COMMIT;

CREATE INDEX loan_tickerName_idx ON #ticker(tickerName);
COMMIT;
