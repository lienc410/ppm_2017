--------------------------------
-- Scale Data Table Creation
--------------------------------

-----------------------------------
-- Conventional Fixed 30yr Data
-- Loan Level
-----------------------------------

-- Conventional Loan Origination Tables

DROP TABLE IF EXISTS "scale"."FNM_Loan";
CREATE TABLE "scale"."FNM_Loan" (
	"loanSeqNum" VARCHAR(12) NULL,
    "marketTicker" VARCHAR(20) NULL,
    "originationDate" DATE NULL,
    "origLoanSize" NUMERIC(12,2) NULL,
    "numberUnits" INT NULL,
    "origFICO" NUMERIC(6,2) NULL,
    "origLTV" NUMERIC(6,2) NULL,
    "dti" NUMERIC(6,2) NULL,
    "origNoteRate" NUMERIC(6,2) NULL,
    "miLevel" NUMERIC(6,2) NULL,
    "HPI_orig" NUMERIC(6,2) NULL,
	"origPMI" NUMERIC(7,4) NULL,
	"percentHARPed" NUMERIC(5,2) NULL
) IN "IQ_USER_MAIN";

COMMIT;
CREATE HG INDEX FNM_Loan_loanseqnum_HG ON scale.FNM_Loan(loanSeqNum);
CREATE LF INDEX FNM_Loan_marketTicker_LF ON scale.FNM_Loan(marketTicker);
COMMIT;

DROP TABLE IF EXISTS "scale"."FHL_Loan";
CREATE TABLE "scale"."FHL_Loan" (
	"loanSeqNum" VARCHAR(12) NULL,
    "marketTicker" VARCHAR(20) NULL,
    "originationDate" DATE NULL,
    "origLoanSize" NUMERIC(12,2) NULL,
    "numberUnits" INT NULL,
    "origFICO" NUMERIC(6,2) NULL,
    "origLTV" NUMERIC(6,2) NULL,
    "dti" NUMERIC(6,2) NULL,
    "origNoteRate" NUMERIC(6,2) NULL,
    "miLevel" NUMERIC(6,2) NULL,
    "HPI_orig" NUMERIC(6,2) NULL,
	"origPMI" NUMERIC(7,4) NULL,
	"percentHARPed" NUMERIC(5,2) NULL
) IN "IQ_USER_MAIN";

COMMIT;
CREATE HG INDEX FHL_Loan_loanseqnum_HG ON scale.FHL_Loan(loanSeqNum);
CREATE LF INDEX FHL_Loan_marketTicker_LF ON scale.FHL_Loan(marketTicker);
COMMIT;


DROP TABLE IF EXISTS "scale"."GNM_Loan";
CREATE TABLE "scale"."GNM_Loan" (
	"loanSeqNum" VARCHAR(12) NULL,
    "marketTicker" VARCHAR(20) NULL,
    "originationDate" DATE NULL,
    "origLoanSize" NUMERIC(12,2) NULL,
    "origFICO" NUMERIC(6,2) NULL,
    "origLTV" NUMERIC(6,2) NULL,
    "dti" NUMERIC(6,2) NULL,
    "origNoteRate" NUMERIC(6,2) NULL,
    "HPI_orig" NUMERIC(6,2) NULL,
	"origMIP" NUMERIC(7,4) NULL,
    "loanType" VARCHAR(12) NULL,
    "loanPurposeType" VARCHAR(12) NULL,
    "tpoType" VARCHAR(12) NULL,
    "firstTimeHomeBuyerFlag" VARCHAR(12) NULL,
    "reperformingStatus" VARCHAR(12) NULL,
) IN "IQ_USER_MAIN";

COMMIT;
CREATE HG INDEX GNM_Loan_loanseqnum_HG ON scale.GNM_Loan(loanSeqNum);
CREATE LF INDEX GNM_Loan_marketTicker_LF ON scale.GNM_Loan(marketTicker);
COMMIT;

-- Conventional Loan Hist Tables

DROP TABLE IF EXISTS "scale"."FNM_LoanHist";
CREATE TABLE "scale"."FNM_LoanHist" (
	"loanSeqNum" VARCHAR(12) NULL,
	"asOf" DATE NULL,
    "balance" NUMERIC(12,2) NULL,
    "cltv" NUMERIC(7,2) NULL,
    "hpa" NUMERIC(5,4) NULL
) IN "IQ_USER_MAIN";

COMMIT;
CREATE HG INDEX FNM_LoanHist_loanseqnum_HG ON scale.FNM_LoanHist(loanSeqNum);
CREATE LF INDEX FNM_LoanHist_asof_LF ON scale.FNM_LoanHist(asOf);
COMMIT;

DROP TABLE IF EXISTS "scale"."FHL_LoanHist";
CREATE TABLE "scale"."FHL_LoanHist" (
	"loanSeqNum" VARCHAR(12) NULL,
	"asOf" DATE NULL,
    "balance" NUMERIC(12,2) NULL,
    "cltv" NUMERIC(7,2) NULL,
    "hpa" NUMERIC(5,4) NULL
) IN "IQ_USER_MAIN";

COMMIT;
CREATE HG INDEX FHL_LoanHist_loanseqnum_HG ON scale.FHL_LoanHist(loanSeqNum);
CREATE LF INDEX FHL_LoanHist_asof_LF ON scale.FHL_LoanHist(asOf);
COMMIT;

DROP TABLE IF EXISTS "scale"."GNM_LoanHist";
CREATE TABLE "scale"."GNM_LoanHist" (
	"loanSeqNum" VARCHAR(12) NULL,
	"asOf" DATE NULL,
    "currentBalance" NUMERIC(12,2) NULL,
    "schamBalance" NUMERIC(12,2) NULL,
    "cltv" NUMERIC(7,2) NULL,
    "hpa" NUMERIC(5,4) NULL,
    "loanAge" NUMERIC(5,1) NULL,
    "delMonths" NUMERIC(5,1) NULL,
    "removalReasonType" VARCHAR(12) NULL
) IN "IQ_USER_MAIN";

COMMIT;
CREATE HG INDEX GNM_LoanHist_loanseqnum_HG ON scale.GNM_LoanHist(loanSeqNum);
CREATE LF INDEX GNM_LoanHist_asof_LF ON scale.GNM_LoanHist(asOf);
COMMIT;

-- Conventional Loan Eligibility Tables

DROP TABLE IF EXISTS "scale"."FNM_LoanEligibility";
CREATE TABLE "scale"."FNM_LoanEligibility" (
	"loanSeqNum" VARCHAR(12) NULL,
	"asOf" DATE NULL,
    "HARP_eligible"  TINYINT NULL,
	"conventional_eligible" TINYINT NULL,
    "fha_eligible" TINYINT NULL
) IN "IQ_USER_MAIN";

COMMIT;
CREATE HG INDEX FNM_LoanEligibility_loanseqnum_HG ON scale.FNM_LoanEligibility(loanSeqNum);
CREATE LF INDEX FNM_LoanEligibility_asof_LF ON scale.FNM_LoanEligibility(asOf);
COMMIT;

DROP TABLE IF EXISTS "scale"."FHL_LoanEligibility";
CREATE TABLE "scale"."FHL_LoanEligibility" (
	"loanSeqNum" VARCHAR(12) NULL,
	"asOf" DATE NULL,
    "HARP_eligible"  TINYINT NULL,
	"conventional_eligible" TINYINT NULL,
    "fha_eligible" TINYINT NULL
) IN "IQ_USER_MAIN";

COMMIT;
CREATE HG INDEX FHL_LoanEligibility_loanseqnum_HG ON scale.FHL_LoanEligibility(loanSeqNum);
CREATE LF INDEX FHL_LoanEligibility_asof_LF ON scale.FHL_LoanEligibility(asOf);
COMMIT;

DROP TABLE IF EXISTS "scale"."GNM_LoanEligibility";
CREATE TABLE "scale"."GNM_LoanEligibility" (
	"loanSeqNum" VARCHAR(12) NULL,
	"asOf" DATE NULL,
	"conventional_eligible" TINYINT NULL
) IN "IQ_USER_MAIN";

COMMIT;
CREATE HG INDEX GNM_LoanEligibility_loanseqnum_HG ON scale.GNM_LoanEligibility(loanSeqNum);
CREATE LF INDEX GNM_LoanEligibility_asof_LF ON scale.GNM_LoanEligibility(asOf);
COMMIT;

-- Conventional Loan Incentive Tables

DROP TABLE IF EXISTS "scale"."FNM_LoanIncentive";
CREATE TABLE "scale"."FNM_LoanIncentive" (
	"loanSeqNum" VARCHAR(12) NULL,
	"asOf" DATE NULL,
    "version" VARCHAR(5) NULL,
	"conventional_refi_incentive" NUMERIC(10,4) NULL,
    "fha_refi_incentive" NUMERIC(10,4) NULL,
    "refi_incentive_eligible" NUMERIC(10,4) NULL,
	"currLLPA" NUMERIC(7,4) NULL,
	"currPMI" NUMERIC(7,4) NULL,
    "currMIP" NUMERIC(7,4) NULL
) IN "IQ_USER_MAIN";

COMMIT;
CREATE HG INDEX FNM_LoanIncentive_loanseqnum_HG ON scale.FNM_LoanIncentive(loanSeqNum);
CREATE LF INDEX FNM_LoanIncentive_asof_LF ON scale.FNM_LoanIncentive(asOf);
CREATE LF INDEX FNM_LoanIncentive_version_LF ON scale.FNM_LoanIncentive(version);
COMMIT;

DROP TABLE IF EXISTS "scale"."FHL_LoanIncentive";
CREATE TABLE "scale"."FHL_LoanIncentive" (
	"loanSeqNum" VARCHAR(12) NULL,
	"asOf" DATE NULL,
    "version" VARCHAR(5) NULL,
	"conventional_refi_incentive" NUMERIC(10,4) NULL,
    "fha_refi_incentive" NUMERIC(10,4) NULL,
    "refi_incentive_eligible" NUMERIC(10,4) NULL,
	"currLLPA" NUMERIC(7,4) NULL,
	"currPMI" NUMERIC(7,4) NULL,
    "currMIP" NUMERIC(7,4) NULL
) IN "IQ_USER_MAIN";

COMMIT;
CREATE HG INDEX FHL_LoanIncentive_loanseqnum_HG ON scale.FHL_LoanIncentive(loanSeqNum);
CREATE LF INDEX FHL_LoanIncentive_asof_LF ON scale.FHL_LoanIncentive(asOf);
CREATE LF INDEX FHL_LoanIncentive_version_LF ON scale.FHL_LoanIncentive(version);
COMMIT;

DROP TABLE IF EXISTS "scale"."GNM_LoanIncentive";
CREATE TABLE "scale"."GNM_LoanIncentive" (
	"loanSeqNum" VARCHAR(12) NULL,
	"asOf" DATE NULL,
    "version" VARCHAR(5) NULL,
	"conventional_refi_incentive" NUMERIC(10,4) NULL,
    "fha_refi_incentive" NUMERIC(10,4) NULL,
    "refi_incentive" NUMERIC(10,4) NULL,
    "refi_incentive_eligible" NUMERIC(10,4) NULL,
	"currLLPA" NUMERIC(7,4) NULL,
	"currPMI" NUMERIC(7,4) NULL,
    "currMIP" NUMERIC(7,4) NULL
) IN "IQ_USER_MAIN";

COMMIT;
CREATE HG INDEX GNM_LoanIncentive_loanseqnum_HG ON scale.GNM_LoanIncentive(loanSeqNum);
CREATE LF INDEX GNM_LoanIncentive_asof_LF ON scale.GNM_LoanIncentive(asOf);
CREATE LF INDEX GNM_LoanIncentive_version_LF ON scale.GNM_LoanIncentive(version);
COMMIT;

-- Conventional Loan Burnout Tables

DROP TABLE IF EXISTS "scale"."FNM_LoanBurnout";
CREATE TABLE "scale"."FNM_LoanBurnout" (
	"loanSeqNum" VARCHAR(12) NULL,
	"asOf" DATE NULL,
    "version" VARCHAR(5) NULL,
	"burnout" NUMERIC(10,4) NULL
) IN "IQ_USER_MAIN";

COMMIT;
CREATE HG INDEX FNM_LoanBurnout_loanseqnum_HG ON scale.FNM_LoanBurnout(loanSeqNum);
CREATE LF INDEX FNM_LoanBurnout_asof_LF ON scale.FNM_LoanBurnout(asOf);
CREATE LF INDEX FNM_LoanBurnout_version_LF ON scale.FNM_LoanBurnout(version);
COMMIT;

DROP TABLE IF EXISTS "scale"."FHL_LoanBurnout";
CREATE TABLE "scale"."FHL_LoanBurnout" (
	"loanSeqNum" VARCHAR(12) NULL,
	"asOf" DATE NULL,
    "version" VARCHAR(5) NULL,
	"burnout" NUMERIC(10,4) NULL
) IN "IQ_USER_MAIN";

COMMIT;
CREATE HG INDEX FHL_LoanBurnout_loanseqnum_HG ON scale.FHL_LoanBurnout(loanSeqNum);
CREATE LF INDEX FHL_LoanBurnout_asof_LF ON scale.FHL_LoanBurnout(asOf);
CREATE LF INDEX FHL_LoanBurnout_version_LF ON scale.FHL_LoanBurnout(version);
COMMIT;

DROP TABLE IF EXISTS "scale"."GNM_LoanBurnout";
CREATE TABLE "scale"."GNM_LoanBurnout" (
	"loanSeqNum" VARCHAR(12) NULL,
	"asOf" DATE NULL,
    "version" VARCHAR(5) NULL,
	"burnout" NUMERIC(10,4) NULL
) IN "IQ_USER_MAIN";

COMMIT;
CREATE HG INDEX GNM_LoanBurnout_loanseqnum_HG ON scale.GNM_LoanBurnout(loanSeqNum);
CREATE LF INDEX GNM_LoanBurnout_asof_LF ON scale.GNM_LoanBurnout(asOf);
CREATE LF INDEX GNM_LoanBurnout_version_LF ON scale.GNM_LoanBurnout(version);
COMMIT;

-- Conventional Loan Permissions

GRANT SELECT ON "scale"."FNM_Loan" to PUBLIC;
GRANT SELECT ON "scale"."FHL_Loan" to PUBLIC;
GRANT SELECT ON "scale"."GNM_Loan" to PUBLIC;

GRANT SELECT ON "scale"."FNM_LoanHist" to PUBLIC;
GRANT SELECT ON "scale"."FHL_LoanHist" to PUBLIC;
GRANT SELECT ON "scale"."GNM_LoanHist" to PUBLIC;

GRANT SELECT ON "scale"."FNM_LoanEligibility" to PUBLIC;
GRANT SELECT ON "scale"."FHL_LoanEligibility" to PUBLIC;
GRANT SELECT ON "scale"."GNM_LoanEligibility" to PUBLIC;

GRANT SELECT ON "scale"."FNM_LoanIncentive" to PUBLIC;
GRANT SELECT ON "scale"."FHL_LoanIncentive" to PUBLIC;
GRANT SELECT ON "scale"."GNM_LoanIncentive" to PUBLIC;

GRANT SELECT ON "scale"."FNM_LoanBurnout" to PUBLIC;
GRANT SELECT ON "scale"."FHL_LoanBurnout" to PUBLIC;
GRANT SELECT ON "scale"."GNM_LoanBurnout" to PUBLIC;
COMMIT;

-----------------------------------
-- Conventional Fixed 30yr Data
-- Pool Level
-----------------------------------

-- Conventional Pool Hist Tables

DROP TABLE IF EXISTS "scale"."FNM_PoolHist";
CREATE TABLE "scale"."FNM_PoolHist" (
	"issueId" INT NULL,
    "marketTicker" VARCHAR(20) NULL,
	"asOf" DATE NULL,
    "balance" NUMERIC(18,2) NULL,
    "originationDate" DATE NULL,
    "origLoanSize" NUMERIC(12,2) NULL,
    "origFICO" NUMERIC(6,2) NULL,
    "origLTV" NUMERIC(6,2) NULL,
    "origNoteRate" NUMERIC(6,2) NULL,
    "currLoanSize" NUMERIC(12,2) NULL,
    "cltv" NUMERIC(7,2) NULL,
    "hpa" NUMERIC(5,4) NULL,
	"miLevel" NUMERIC(6,2) NULL
) IN "IQ_USER_MAIN";

COMMIT;
CREATE HG INDEX "FNM_PoolHist_issueid_HG" ON "scale"."FNM_PoolHist" ("issueId"  ) IN "IQ_USER_MAIN";
CREATE LF INDEX "FNM_PoolHist_asof_LF" ON "scale"."FNM_PoolHist" ("asOf" ) IN "IQ_USER_MAIN";
CREATE LF INDEX "FNM_PoolHist_ticker_LF" ON "scale"."FNM_PoolHist" ("marketTicker" ) IN "IQ_USER_MAIN";
COMMIT;

DROP TABLE IF EXISTS "scale"."FHL_PoolHist";
CREATE TABLE "scale"."FHL_PoolHist" (
	"issueId" INT NULL,
    "marketTicker" VARCHAR(20) NULL,
	"asOf" DATE NULL,
    "balance" NUMERIC(18,2) NULL,
    "originationDate" DATE NULL,
    "origLoanSize" NUMERIC(12,2) NULL,
    "origFICO" NUMERIC(6,2) NULL,
    "origLTV" NUMERIC(6,2) NULL,
    "origNoteRate" NUMERIC(6,2) NULL,
    "currLoanSize" NUMERIC(12,2) NULL,
    "cltv" NUMERIC(7,2) NULL,
    "hpa" NUMERIC(5,4) NULL,
	"miLevel" NUMERIC(6,2) NULL
) IN "IQ_USER_MAIN";

COMMIT;
CREATE HG INDEX "FHL_PoolHist_issueid_HG" ON "scale"."FHL_PoolHist" ("issueId"  ) IN "IQ_USER_MAIN";
CREATE LF INDEX "FHL_PoolHist_asof_LF" ON "scale"."FHL_PoolHist" ("asOf" ) IN "IQ_USER_MAIN";
CREATE LF INDEX "FHL_PoolHist_ticker_LF" ON "scale"."FHL_PoolHist" ("marketTicker" ) IN "IQ_USER_MAIN";
COMMIT;

DROP TABLE IF EXISTS "scale"."GNM_PoolHist";
CREATE TABLE "scale"."GNM_PoolHist" (
	"issueId" INT NULL,
    "marketTicker" VARCHAR(20) NULL,
	"asOf" DATE NULL,
    "balance" NUMERIC(18,2) NULL,
    "originationDate" DATE NULL,
    "origLoanSize" NUMERIC(12,2) NULL,
    "origFICO" NUMERIC(6,2) NULL,
    "origLTV" NUMERIC(6,2) NULL,
    "origNoteRate" NUMERIC(6,2) NULL,
    "currLoanSize" NUMERIC(12,2) NULL,
    "cltv" NUMERIC(7,2) NULL,
    "hpa" NUMERIC(5,4) NULL
) IN "IQ_USER_MAIN";

COMMIT;
CREATE HG INDEX "GNM_PoolHist_issueid_HG" ON "scale"."GNM_PoolHist" ("issueId"  ) IN "IQ_USER_MAIN";
CREATE LF INDEX "GNM_PoolHist_asof_LF" ON "scale"."GNM_PoolHist" ("asOf" ) IN "IQ_USER_MAIN";
CREATE LF INDEX "GNM_PoolHist_ticker_LF" ON "scale"."GNM_PoolHist" ("marketTicker" ) IN "IQ_USER_MAIN";
COMMIT;

-- Conventional Pool Distribution Tables

DROP TABLE IF EXISTS "scale"."FNM_PoolDistribution";
CREATE TABLE "scale"."FNM_PoolDistribution" (
	"issueId" INT NULL,
	"asOf" DATE NULL,
    "percentHARPed" NUMERIC(5,2) NULL,
	"Est_Pct_HARPed" NUMERIC(5,2) NULL,
    "percentMtgIns" NUMERIC(5,2) NULL,
    "percentOCC_OWN" NUMERIC(5,2) NULL,
    "percentOCC_INV" NUMERIC(5,2) NULL,
    "percentOCC_2ND" NUMERIC(5,2) NULL,
    "percentPURP_PURCH" NUMERIC(5,2) NULL,
    "percentPURP_REFI" NUMERIC(5,2) NULL,
    "percentCHANNEL_RETAIL" NUMERIC(5,2) NULL,
    "percentCHANNEL_BROKER" NUMERIC(5,2) NULL,
    "percentCHANNEL_CORRES" NUMERIC(5,2) NULL,
    "percentUNIT_SINGLE" NUMERIC(5,2) NULL,
    "percentUNIT_MULTIPLE" NUMERIC(5,2) NULL,
    "Est_Pct_CURRENT" NUMERIC(5,2) NULL,
    "Est_Pct_DELQ30plus" NUMERIC(5,2) NULL,
    "Est_Pct_DELQ60plus" NUMERIC(5,2) NULL,
    "Est_Pct_DELQ90plus" NUMERIC(5,2) NULL
) IN "IQ_USER_MAIN";

COMMIT;
CREATE HG INDEX "FNM_PoolDistribution_issueid_HG" ON "scale"."FNM_PoolDistribution" ("issueId"  ) IN "IQ_USER_MAIN";
CREATE LF INDEX "FNM_PoolDistribution_asof_LF" ON "scale"."FNM_PoolDistribution" ("asOf" ) IN "IQ_USER_MAIN";
COMMIT;

DROP TABLE IF EXISTS "scale"."FHL_PoolDistribution";
CREATE TABLE "scale"."FHL_PoolDistribution" (
	"issueId" INT NULL,
	"asOf" DATE NULL,
    "percentHARPed" NUMERIC(5,2) NULL,
    "percentMtgIns" NUMERIC(5,2) NULL,
    "percentOCC_OWN" NUMERIC(5,2) NULL,
    "percentOCC_INV" NUMERIC(5,2) NULL,
    "percentOCC_2ND" NUMERIC(5,2) NULL,
    "percentPURP_PURCH" NUMERIC(5,2) NULL,
    "percentPURP_REFI" NUMERIC(5,2) NULL,
    "percentCHANNEL_RETAIL" NUMERIC(5,2) NULL,
    "percentCHANNEL_BROKER" NUMERIC(5,2) NULL,
    "percentCHANNEL_CORRES" NUMERIC(5,2) NULL,
    "percentUNIT_SINGLE" NUMERIC(5,2) NULL,
    "percentUNIT_MULTIPLE" NUMERIC(5,2) NULL,
    "percentCURRENT" NUMERIC(5,2) NULL,
    "percentDELQ30plus" NUMERIC(5,2) NULL,
    "percentDELQ60plus" NUMERIC(5,2) NULL,
    "percentDELQ90plus" NUMERIC(5,2) NULL,
    "Est_Pct_CURRENT" NUMERIC(5,2) NULL,
    "Est_Pct_DELQ30plus" NUMERIC(5,2) NULL,
    "Est_Pct_DELQ60plus" NUMERIC(5,2) NULL,
    "Est_Pct_DELQ90plus" NUMERIC(5,2) NULL
) IN "IQ_USER_MAIN";

COMMIT;
CREATE HG INDEX "FHL_PoolDistribution_issueid_HG" ON "scale"."FHL_PoolDistribution" ("issueId"  ) IN "IQ_USER_MAIN";
CREATE LF INDEX "FHL_PoolDistribution_asof_LF" ON "scale"."FHL_PoolDistribution" ("asOf" ) IN "IQ_USER_MAIN";
COMMIT;

DROP TABLE IF EXISTS "scale"."GNM_PoolDistribution";
CREATE TABLE "scale"."GNM_PoolDistribution" (
	"issueId" INT NULL,
	"asOf" DATE NULL,
    "percentPURP_PURCH" NUMERIC(5,2) NULL,
    "percentPURP_REFI" NUMERIC(5,2) NULL,
    "percentCHANNEL_RETAIL" NUMERIC(5,2) NULL,
    "percentCHANNEL_BROKER" NUMERIC(5,2) NULL,
    "percentCHANNEL_CORRES" NUMERIC(5,2) NULL,
    "percentUNIT_SINGLE" NUMERIC(5,2) NULL,
    "percentUNIT_MULTIPLE" NUMERIC(5,2) NULL,
    "percentCURRENT" NUMERIC(5,2) NULL,
    "percentDELQ30plus" NUMERIC(5,2) NULL,
    "percentDELQ60plus" NUMERIC(5,2) NULL,
    "percentDELQ90plus" NUMERIC(5,2) NULL,
    "Est_Pct_CURRENT" NUMERIC(5,2) NULL,
    "Est_Pct_DELQ30plus" NUMERIC(5,2) NULL,
    "Est_Pct_DELQ60plus" NUMERIC(5,2) NULL,
    "Est_Pct_DELQ90plus" NUMERIC(5,2) NULL,
    "percentTYPE_FHA" NUMERIC(5,2) NULL,
    "percentTYPE_VA" NUMERIC(5,2) NULL,
    "percentTYPE_OTHER" NUMERIC(5,2) NULL
) IN "IQ_USER_MAIN";

COMMIT;
CREATE HG INDEX "GNM_PoolDistribution_issueid_HG" ON "scale"."GNM_PoolDistribution" ("issueId"  ) IN "IQ_USER_MAIN";
CREATE LF INDEX "GNM_PoolDistribution_asof_LF" ON "scale"."GNM_PoolDistribution" ("asOf" ) IN "IQ_USER_MAIN";
COMMIT;

-- Conventional Pool Eligibility Tables

DROP TABLE IF EXISTS "scale"."FNM_PoolEligibility";
CREATE TABLE "scale"."FNM_PoolEligibility" (
	"issueId" INT NULL,
	"asOf" DATE NULL,
    "HARP_eligible" NUMERIC(5,2) NULL,
	"conventional_eligible" NUMERIC(5,2) NULL,
    "fha_eligible" NUMERIC(5,2) NULL,
    "refi_eligible" NUMERIC(5,2) NULL
) IN "IQ_USER_MAIN";

COMMIT;
CREATE HG INDEX "FNM_PoolEligibility_issueid_HG" ON "scale"."FNM_PoolEligibility" ("issueId"  ) IN "IQ_USER_MAIN";
CREATE LF INDEX "FNM_PoolEligibility_asof_LF" ON "scale"."FNM_PoolEligibility" ("asOf" ) IN "IQ_USER_MAIN";
COMMIT;

DROP TABLE IF EXISTS "scale"."FHL_PoolEligibility";
CREATE TABLE "scale"."FHL_PoolEligibility" (
	"issueId" INT NULL,
	"asOf" DATE NULL,
    "HARP_eligible" NUMERIC(5,2) NULL,
	"conventional_eligible" NUMERIC(5,2) NULL,
    "fha_eligible" NUMERIC(5,2) NULL,
    "refi_eligible" NUMERIC(5,2) NULL
) IN "IQ_USER_MAIN";

COMMIT;
CREATE HG INDEX "FHL_PoolEligibility_issueid_HG" ON "scale"."FHL_PoolEligibility" ("issueId"  ) IN "IQ_USER_MAIN";
CREATE LF INDEX "FHL_PoolEligibility_asof_LF" ON "scale"."FHL_PoolEligibility" ("asOf" ) IN "IQ_USER_MAIN";
COMMIT;

DROP TABLE IF EXISTS "scale"."GNM_PoolEligibility";
CREATE TABLE "scale"."GNM_PoolEligibility" (
	"issueId" INT NULL,
	"asOf" DATE NULL,
	"conventional_eligible" NUMERIC(5,2) NULL
) IN "IQ_USER_MAIN";
        
COMMIT;
CREATE HG INDEX "GNM_PoolEligibility_issueid_HG" ON "scale"."GNM_PoolEligibility" ("issueId"  ) IN "IQ_USER_MAIN";
CREATE LF INDEX "GNM_PoolEligibility_asof_LF" ON "scale"."GNM_PoolEligibility" ("asOf" ) IN "IQ_USER_MAIN";
COMMIT;

-- Conventional Pool Incentive Tables

DROP TABLE IF EXISTS "scale"."FNM_PoolIncentive";
CREATE TABLE "scale"."FNM_PoolIncentive" (
	"issueId" INT NULL,
	"asOf" DATE NULL,
    "version" VARCHAR(5) NULL,
	"conventional_refi_incentive" NUMERIC(10,4) NULL,
    "fha_refi_incentive" NUMERIC(10,4) NULL,
    "refi_incentive" NUMERIC(10,4) NULL,
    "refi_incentive_eligible" NUMERIC(10,4) NULL,
    "origPMI" NUMERIC(7,4) NULL,
	"currLLPA" NUMERIC(7,4) NULL,
	"currPMI" NUMERIC(7,4) NULL,
    "currMIP" NUMERIC(7,4) NULL
) IN "IQ_USER_MAIN";

COMMIT;
CREATE HG INDEX "FNM_PoolIncentive_issueid_HG" ON "scale"."FNM_PoolIncentive" ("issueId"  ) IN "IQ_USER_MAIN";
CREATE LF INDEX "FNM_PoolIncentive_asof_LF" ON "scale"."FNM_PoolIncentive" ("asOf" ) IN "IQ_USER_MAIN";
CREATE LF INDEX "FNM_PoolIncentive_version_LF" ON "scale"."FNM_PoolIncentive" ("version" ) IN "IQ_USER_MAIN";
COMMIT;

DROP TABLE IF EXISTS "scale"."FHL_PoolIncentive";
CREATE TABLE "scale"."FHL_PoolIncentive" (
	"issueId" INT NULL,
	"asOf" DATE NULL,
    "version" VARCHAR(5) NULL,
	"conventional_refi_incentive" NUMERIC(10,4) NULL,
    "fha_refi_incentive" NUMERIC(10,4) NULL,
    "refi_incentive" NUMERIC(10,4) NULL,
    "refi_incentive_eligible" NUMERIC(10,4) NULL,
    "origPMI" NUMERIC(7,4) NULL,
	"currLLPA" NUMERIC(7,4) NULL,
	"currPMI" NUMERIC(7,4) NULL,
    "currMIP" NUMERIC(7,4) NULL
) IN "IQ_USER_MAIN";

COMMIT;
CREATE HG INDEX "FHL_PoolIncentive_issueid_HG" ON "scale"."FHL_PoolIncentive" ("issueId"  ) IN "IQ_USER_MAIN";
CREATE LF INDEX "FHL_PoolIncentive_asof_LF" ON "scale"."FHL_PoolIncentive" ("asOf" ) IN "IQ_USER_MAIN";
CREATE LF INDEX "FHL_PoolIncentive_version_LF" ON "scale"."FHL_PoolIncentive" ("version" ) IN "IQ_USER_MAIN";
COMMIT;

DROP TABLE IF EXISTS "scale"."GNM_PoolIncentive";
CREATE TABLE "scale"."GNM_PoolIncentive" (
	"issueId" INT NULL,
	"asOf" DATE NULL,
    "version" VARCHAR(5) NULL,
	"conventional_refi_incentive" NUMERIC(10,4) NULL,
    "fha_refi_incentive" NUMERIC(10,4) NULL,
    "refi_incentive" NUMERIC(10,4) NULL,
    "refi_incentive_eligible" NUMERIC(10,4) NULL,
    "origMIP" NUMERIC(7,4) NULL,
	"currLLPA" NUMERIC(7,4) NULL,
	"currPMI" NUMERIC(7,4) NULL,
    "currMIP" NUMERIC(7,4) NULL
) IN "IQ_USER_MAIN";

COMMIT;
CREATE HG INDEX "GNM_PoolIncentive_issueid_HG" ON "scale"."GNM_PoolIncentive" ("issueId"  ) IN "IQ_USER_MAIN";
CREATE LF INDEX "GNM_PoolIncentive_asof_LF" ON "scale"."GNM_PoolIncentive" ("asOf" ) IN "IQ_USER_MAIN";
CREATE LF INDEX "GNM_PoolIncentive_version_LF" ON "scale"."GNM_PoolIncentive" ("version" ) IN "IQ_USER_MAIN";
COMMIT;

-- Conventional Pool Burnout Tables

DROP TABLE IF EXISTS "scale"."FNM_PoolBurnout";
CREATE TABLE "scale"."FNM_PoolBurnout" (
	"issueId" INT NULL,
	"asOf" DATE NULL,
    "version" VARCHAR(5) NULL,
	"burnout" NUMERIC(10,4) NULL
) IN "IQ_USER_MAIN";

COMMIT;
CREATE HG INDEX "FNM_PoolBurnout_issueid_HG" ON "scale"."FNM_PoolBurnout" ("issueId"  ) IN "IQ_USER_MAIN";
CREATE LF INDEX "FNM_PoolBurnout_asof_LF" ON "scale"."FNM_PoolBurnout" ("asOf" ) IN "IQ_USER_MAIN";
CREATE LF INDEX "FNM_PoolBurnout_version_LF" ON "scale"."FNM_PoolBurnout" ("version" ) IN "IQ_USER_MAIN";
COMMIT;

DROP TABLE IF EXISTS "scale"."FHL_PoolBurnout";
CREATE TABLE "scale"."FHL_PoolBurnout" (
	"issueId" INT NULL,
	"asOf" DATE NULL,
    "version" VARCHAR(5) NULL,
	"burnout" NUMERIC(10,4) NULL
) IN "IQ_USER_MAIN";

COMMIT;
CREATE HG INDEX "FHL_PoolBurnout_issueid_HG" ON "scale"."FHL_PoolBurnout" ("issueId"  ) IN "IQ_USER_MAIN";
CREATE LF INDEX "FHL_PoolBurnout_asof_LF" ON "scale"."FHL_PoolBurnout" ("asOf" ) IN "IQ_USER_MAIN";
CREATE LF INDEX "FHL_PoolBurnout_version_LF" ON "scale"."FHL_PoolBurnout" ("version" ) IN "IQ_USER_MAIN";
COMMIT;

DROP TABLE IF EXISTS "scale"."GNM_PoolBurnout";
CREATE TABLE "scale"."GNM_PoolBurnout" (
	"issueId" INT NULL,
	"asOf" DATE NULL,
    "version" VARCHAR(5) NULL,
	"burnout" NUMERIC(10,4) NULL
) IN "IQ_USER_MAIN";

COMMIT;
CREATE HG INDEX "GNM_PoolBurnout_issueid_HG" ON "scale"."GNM_PoolBurnout" ("issueId"  ) IN "IQ_USER_MAIN";
CREATE LF INDEX "GNM_PoolBurnout_asof_LF" ON "scale"."GNM_PoolBurnout" ("asOf" ) IN "IQ_USER_MAIN";
CREATE LF INDEX "GNM_PoolBurnout_version_LF" ON "scale"."GNM_PoolBurnout" ("version" ) IN "IQ_USER_MAIN";
COMMIT;

-- Conventional Pool Permissions

GRANT SELECT ON "scale"."FNM_PoolHist" to PUBLIC;
GRANT SELECT ON "scale"."FHL_PoolHist" to PUBLIC;
GRANT SELECT ON "scale"."GNM_PoolHist" to PUBLIC;

GRANT SELECT ON "scale"."FNM_PoolDistribution" to PUBLIC;
GRANT SELECT ON "scale"."FHL_PoolDistribution" to PUBLIC;
GRANT SELECT ON "scale"."GNM_PoolDistribution" to PUBLIC;

GRANT SELECT ON "scale"."FNM_PoolEligibility" to PUBLIC;
GRANT SELECT ON "scale"."FHL_PoolEligibility" to PUBLIC;
GRANT SELECT ON "scale"."GNM_PoolEligibility" to PUBLIC;

GRANT SELECT ON "scale"."FNM_PoolIncentive" to PUBLIC;
GRANT SELECT ON "scale"."FHL_PoolIncentive" to PUBLIC;
GRANT SELECT ON "scale"."GNM_PoolIncentive" to PUBLIC;

GRANT SELECT ON "scale"."FNM_PoolBurnout" to PUBLIC;
GRANT SELECT ON "scale"."FHL_PoolBurnout" to PUBLIC;
GRANT SELECT ON "scale"."GNM_PoolBurnout" to PUBLIC;
COMMIT;



-----------------------------------
-- Ginnie Mae Project Loan Data
-- Pool Level
-----------------------------------


-- GPL Pool Origination Tables

DROP TABLE IF EXISTS "scale"."GPL_Pool";
CREATE TABLE "scale"."GPL_Pool" (
	"issueId" INT NULL,
    "poolNumber" VARCHAR(20) NULL,
	"loanNumber" VARCHAR(20) NULL,
    "marketTicker" VARCHAR(20) NULL,
    "poolType" VARCHAR(5) NULL,
    "term" INTEGER NULL,
    "origIssueAmount" NUMERIC(16,2) NULL,
    "origIssuer" VARCHAR(50) NULL,
    "loanInterestRate" NUMERIC(16,2) NULL,
    "securityInterestRate" NUMERIC(5,2) NULL,
    "fhaNumber" VARCHAR(16) NULL,
    "fhaProgram" VARCHAR(16) NULL,
    "cityLocated" VARCHAR(50) NULL,
    "stateLocated" VARCHAR(5) NULL,
    "poolIsUnique" TINYINT NULL,
    "poolInDeal" TINYINT NULL,
    "beganAsConstructionLoan" CHAR(1) NULL,
    "issueDate" DATE NULL,
    "firstPaymentDate" DATE NULL,
    "lockoutEndDate" DATE NULL,
    "prepayPenaltyEndDate" DATE NULL,
    "maturityDate" DATE NULL,
    "globalPenaltyCode" VARCHAR(5) NULL,
    "payoffDate" DATE NULL,
    "payoffType" VARCHAR(20) NULL,
    "histPenaltyAmount" NUMERIC(16,2) NULL,
    "isEstimate" TINYINT NULL
) IN "IQ_USER_MAIN";

COMMIT;
CREATE HG INDEX "GPL_Pool_issueId_HG" ON "scale"."GPL_Pool"(issueId);
CREATE HG INDEX "GPL_Pool_poolNumber_HG" ON "scale"."GPL_Pool"(poolNumber);
CREATE HG INDEX "GPL_Pool_loanNumber_HG" ON "scale"."GPL_Pool"(loanNumber);
CREATE LF  INDEX "GPL_Pool_marketTicker_LF" ON "scale"."GPL_Pool"(marketTicker);
COMMIT;


-- GPL Pool Hist Tables

DROP TABLE IF EXISTS "scale"."GPL_PoolHist";
CREATE TABLE "scale"."GPL_PoolHist" (
    "issueId" INT NULL,
    "poolNumber" VARCHAR(20) NULL,
	"loanNumber" VARCHAR(20) NULL,
	"asOf" DATE NULL,
    "balance" NUMERIC(16,2) NULL,
    "wala" INTEGER NULL,
    "wam" INTEGER NULL,
    "issuerName" VARCHAR(50) NULL,
    "canPrepay" TINYINT NULL, 
    "penaltyRate" NUMERIC(6,2) NULL,
    "penaltyAmount" NUMERIC(16,2) NULL,
    "hasDelinqInfo" TINYINT NULL, 
    "delinqStatus" VARCHAR(3) NULL,
    "isDelinq" SMALLINT NULL, 
    "ageSinceLastCurrent" SMALLINT NULL, 
    "monthsInStatus" SMALLINT NULL, 
    "monthsToReset" SMALLINT NULL, 
    "monthsSinceReset" SMALLINT NULL, 
    "monthsSinceLockoutEndDate" SMALLINT NULL, 
    "penaltyCycle" VARCHAR(4) NULL, 
    "penalty_non_adjusted_incentive" DOUBLE NULL 
) IN "IQ_USER_MAIN";

COMMIT;
CREATE HG INDEX "GPL_PoolHist_issueId_HG" ON "scale"."GPL_PoolHist"(issueId);
CREATE HG INDEX "GPL_PoolHist_poolNumber_HG" ON "scale"."GPL_PoolHist"(poolNumber);
CREATE HG INDEX "GPL_PoolHist_loanNumber_HG" ON "scale"."GPL_PoolHist"(loanNumber);
COMMIT;


-- Conventional Pool Incentive Tables

DROP TABLE IF EXISTS "scale"."GPL_PoolIncentive";
CREATE TABLE "scale"."GPL_PoolIncentive" (
    "issueId" INT NULL,
    "poolNumber" VARCHAR(20) NULL,
	"loanNumber" VARCHAR(20) NULL,
	"asOf" DATE NULL,
    "version" VARCHAR(5) NULL,
	"penalty_adjusted_incentive" NUMERIC(10,4) NULL,
    "max_penalty_adjusted_incentive" NUMERIC(10,4) NULL
) IN "IQ_USER_MAIN";

COMMIT;
CREATE HG INDEX "GPL_PoolIncentive_issueid_HG" ON "scale"."GPL_PoolIncentive" ("issueId"  ) IN "IQ_USER_MAIN";
CREATE LF INDEX "GPL_PoolIncentive_asof_LF" ON "scale"."GPL_PoolIncentive" ("asOf" ) IN "IQ_USER_MAIN";
CREATE LF INDEX "GPL_PoolIncentive_version_LF" ON "scale"."GPL_PoolIncentive" ("version" ) IN "IQ_USER_MAIN";
COMMIT;


-- Conventional Pool Burnout Tables

DROP TABLE IF EXISTS "scale"."GPL_PoolBurnout";
CREATE TABLE "scale"."GPL_PoolBurnout" (
    "issueId" INT NULL,
    "poolNumber" VARCHAR(20) NULL,
	"loanNumber" VARCHAR(20) NULL,
	"asOf" DATE NULL,
    "version" VARCHAR(5) NULL,
	"burnout" NUMERIC(10,4) NULL
) IN "IQ_USER_MAIN";

COMMIT;
CREATE HG INDEX "GPL_PoolBurnout_issueid_HG" ON "scale"."GPL_PoolBurnout" ("issueId"  ) IN "IQ_USER_MAIN";
CREATE LF INDEX "GPL_PoolBurnout_asof_LF" ON "scale"."GPL_PoolBurnout" ("asOf" ) IN "IQ_USER_MAIN";
CREATE LF INDEX "GPL_PoolBurnout_version_LF" ON "scale"."GPL_PoolBurnout" ("version" ) IN "IQ_USER_MAIN";
COMMIT;


-- GPL Pool Permissions

GRANT SELECT ON "scale"."GPL_Pool" to PUBLIC;
GRANT SELECT ON "scale"."GPL_PoolHist" to PUBLIC;
GRANT SELECT ON "scale"."GPL_PoolIncentive" to PUBLIC;
GRANT SELECT ON "scale"."GPL_PoolBurnout" to PUBLIC;

COMMIT;

