
load Table @TABLE@ (
loanSeqNum,asOf,smmCurtail,smmDefault,smmTurnover,smmCashout,smmRefinance,smmTotal)
FROM '@LOAD_FILE_PATH@'
QUOTES OFF ESCAPES OFF
FORMAT BCP
DELIMITED BY '|'
ROW DELIMITED BY '\n'