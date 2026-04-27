Create Table #Loading(
loanSeqNum varchar(12),
asOf date,
smmCurtail numeric(60,15),
smmDefault numeric(60,15),
smmTurnover numeric(60,15),
smmCashout numeric(60,15),
smmRefinance numeric(60,15),
smmTotal numeric(60,15));
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

DELETE FROM #Loading WHERE smmCurtail>=1 or smmDefault>=1 or smmTurnover>=1 or smmCashout>=1 or smmRefinance>=1 or smmTotal>=1;
COMMIT;

INSERT INTO @TABLE@ (
loanSeqNum,
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
loanSeqNum,
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
