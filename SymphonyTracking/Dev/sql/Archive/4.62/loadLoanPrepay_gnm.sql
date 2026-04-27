Create Table #Loading(
loanSeqNum varchar(12),
asOf date,
smmCurtail numeric(60,15),
smmDefault numeric(60,15),
smmTurnover numeric(60,15),
smmCashout numeric(60,15),
smmRefinance numeric(60,15),
smmCreditCuring numeric(60,15),
smmFixedToARM numeric(60,15),
defaultTransitRate numeric(60,15),
defaultBuyoutRate numeric(60,15),
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
smmCreditCuring,
smmFixedToARM,
defaultTransitRate,
defaultBuyoutRate,
smmTotal
)
FROM '@LOAD_FILE_PATH@'
QUOTES OFF ESCAPES OFF
DELIMITED BY '|'
ROW DELIMITED BY '\x0d\x0a';
COMMIT;
/*
UPDATE #Loading
SET smmFixedToARM = NULL
;
COMMIT;
*/
DELETE FROM #Loading WHERE smmCurtail>=1 or smmTurnover>=1 or smmCashout>=1 or smmRefinance>=1 or smmCreditCuring>=1 or smmFixedToARM>=1 or defaultTransitRate>=1 or defaultBuyoutRate>=1;
COMMIT;

DELETE FROM #Loading WHERE smmCurtail<0 or smmTurnover<0 or smmCashout<0 or smmRefinance<0 or smmCreditCuring<0 or smmFixedToARM<0 or defaultTransitRate<0 or defaultBuyoutRate<0;
COMMIT;

INSERT INTO @TABLE@ (
loanSeqNum,
asOf,
smmCurtail,
smmDefault,
smmTurnover,
smmCashout,
smmRefinance,
smmCreditCuring,
smmFixedToARM,
defaultTransitRate,
defaultBuyoutRate,
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
cast (smmCreditCuring as numeric(9,8)) as smmCreditCuring,
cast (smmFixedToARM as numeric(9,8)) as smmFixedToARM,
cast (defaultTransitRate as numeric(9,8)) as defaultTransitRate,
cast (defaultBuyoutRate as numeric(9,8)) as defaultBuyoutRate,
cast (smmTotal as numeric(9,8)) as smmTotal,
cast ((smmCurtail+smmTurnover+smmCashout+smmRefinance+smmCreditCuring+smmFixedToARM) as numeric(9,8)) as SMM_CRR,
cast (smmDefault as numeric(9,8)) as SMM_CDR
FROM #Loading;
COMMIT;

DROP TABLE IF EXISTS #Loading;
COMMIT;
