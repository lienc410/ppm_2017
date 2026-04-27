
load Table @TABLE@ (
issueId,asOf,smmCurtail,smmDefault,smmTurnover,smmRefinance,smmTotal)
FROM '@LOAD_FILE_PATH@'
QUOTES OFF ESCAPES OFF
delimited by '|'