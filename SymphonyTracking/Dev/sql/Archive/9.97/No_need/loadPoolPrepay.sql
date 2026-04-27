
load Table @TABLE@ (
issueId,asOf,smmCurtail,smmDefault,smmTurnover,smmCashout,smmRefinance,smmTotal)
FROM '@LOAD_FILE_PATH@'
QUOTES OFF ESCAPES OFF
delimited by '|'