Create Table #Loading(
loanSeqNum varchar(12),
asOf date,
smmDefault numeric(60,15));
COMMIT;


load Table #Loading (
asOf,
loanSeqNum,
smmDefault
)
FROM '@LOAD_FILE_PATH@'
QUOTES OFF ESCAPES OFF
DELIMITED BY '|'
ROW DELIMITED BY '\x0d\x0a';
COMMIT;


INSERT INTO @TABLE@ (
loanSeqNum,
asOf,
smmDefault,
SMM_CDR
)
SELECT
loanSeqNum,
asOf,
cast (smmDefault as numeric(9,8)) as smmDefault,
cast (smmDefault as numeric(9,8)) as SMM_CDR
FROM #Loading;
COMMIT;

DROP TABLE IF EXISTS #Loading;
COMMIT;
