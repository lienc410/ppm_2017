create Table #Loading(
issueId int,
asOf date,
smmCurtail numeric(30,15),
smmDefault numeric(30,15),
smmTurnover numeric(30,15),
smmCashout numeric(30,15),
smmRefinance numeric(30,15),
smmTotal numeric(30,15));
COMMIT;

load Table #Loading (
issueId,asOf,smmCurtail,smmDefault,smmTurnover,smmCashout,smmRefinance,smmTotal)
FROM '@LOAD_FILE_PATH@'
QUOTES OFF ESCAPES OFF
delimited by '|'
ROW DELIMITED BY '\x0d\x0a';
COMMIT;

INSERT INTO @TABLE@ (
issueId,
asOf,
smmCurtail,
smmDefault,
smmTurnover,
smmCashout,
smmRefinance,
smmTotal,
SMM_CRR,
SMM_CDR
)
SELECT
issueId,
asOf,
cast (smmCurtail as numeric(9,8)) as smmCurtail,
cast (smmDefault as numeric(9,8)) as smmDefault,
cast (smmTurnover as numeric(9,8)) as smmTurnover,
cast (smmCashout as numeric(9,8)) as smmCashout,
cast (smmRefinance as numeric(9,8)) as smmRefinance,
cast (smmTotal as numeric(9,8)) as smmTotal,
cast ((smmCurtail+smmTurnover+smmCashout+smmRefinance) as numeric(9,8)) as SMM_CRR,
cast (smmDefault as numeric(9,8)) as SMM_CDR
FROM #Loading;
COMMIT;

DROP TABLE IF EXISTS #Loading;
COMMIT;