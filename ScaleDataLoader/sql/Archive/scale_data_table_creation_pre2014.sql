
DROP TABLE IF EXISTS "scale"."GNM_PoolDistribution_v2_00";
CREATE TABLE "scale"."GNM_PoolDistribution_v2_00" (
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
    "percentTYPE_RHS" NUMERIC(5,2) NULL,
    "percentTYPE_PIH" NUMERIC(5,2) NULL,
    "percentTYPE_NA" NUMERIC(5,2) NULL
) IN "IQ_USER_MAIN";


DROP TABLE IF EXISTS "scale"."GNM_PoolIncentive_v2_00";
CREATE TABLE "scale"."GNM_PoolIncentive_v2_00" (
	"issueId" INT NULL,
    "loanType" VARCHAR(12) NULL,
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
CREATE HG INDEX "GNM_PoolIncentive_issueid_HG" ON "scale"."GNM_PoolIncentive_v2_00" ("issueId"  ) IN "IQ_USER_MAIN";
CREATE LF INDEX "GNM_PoolIncentive_asof_LF" ON "scale"."GNM_PoolIncentive_v2_00" ("asOf" ) IN "IQ_USER_MAIN";
CREATE LF INDEX "GNM_PoolIncentive_version_LF" ON "scale"."GNM_PoolIncentive_v2_00" ("version" ) IN "IQ_USER_MAIN";
COMMIT;


DROP TABLE IF EXISTS "scale"."GNM_PoolBurnout_v2_00";
CREATE TABLE "scale"."GNM_PoolBurnout_v2_00" (
	"issueId" INT NULL,
    "loanType" VARCHAR(12) NULL,
	"asOf" DATE NULL,
    "version" VARCHAR(5) NULL,
	"burnout" NUMERIC(10,4) NULL
) IN "IQ_USER_MAIN";

COMMIT;
CREATE HG INDEX "GNM_PoolBurnout_issueid_HG" ON "scale"."GNM_PoolBurnout" ("issueId"  ) IN "IQ_USER_MAIN";
CREATE LF INDEX "GNM_PoolBurnout_asof_LF" ON "scale"."GNM_PoolBurnout" ("asOf" ) IN "IQ_USER_MAIN";
CREATE LF INDEX "GNM_PoolBurnout_version_LF" ON "scale"."GNM_PoolBurnout" ("version" ) IN "IQ_USER_MAIN";
COMMIT;