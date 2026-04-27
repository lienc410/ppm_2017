Create Table #Loading(
loanSeqNum varchar(12),
asOf date,
smmCurtail numeric(30,15),
smmDefault numeric(30,15),
smmTurnover numeric(30,15),
smmCashout numeric(30,15),
smmRefinance numeric(30,15),
smmTotal numeric(30,15));
COMMIT;


load Table #Loading (
loanSeqNum,
asOf,
smmCurtail,
smmDefault,
smmTurnover,
smmCashout,
smmRefinance,
smmTotal
)
FROM '@LOAD_FILE_PATH@'
QUOTES OFF ESCAPES OFF
DELIMITED BY '|'
ROW DELIMITED BY '\x0d\x0a';
COMMIT;

INSERT INTO @TABLE@ (
loanSeqNum,
asOf,
smmCurtail,
smmDefault,
smmTurnover,
smmCashout,
smmRefinance,
smmTotal
)
SELECT
loanSeqNum,
asOf,
cast (smmCurtail as numeric(9,8)) as smmCurtail,
cast (smmDefault as numeric(9,8)) as smmDefault,
cast (smmTurnover as numeric(9,8)) as smmTurnover,
cast (smmCashout as numeric(9,8)) as smmCashout,
cast (smmRefinance as numeric(9,8)) as smmRefinance,
cast (smmTotal as numeric(9,8)) as smmTotal
FROM #Loading;
COMMIT;

DROP TABLE IF EXISTS #Loading;
COMMIT;
