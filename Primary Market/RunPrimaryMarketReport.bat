@Echo off

REM >> syntax: cscript RunServicingSpreadandSurveyRateReport /date:20/3/15 /out:c:\tmp\ /env:PROD
set SCRIPT_PATH="S:\IT\Production\Daily Reports\Primary Market\"
set CLOSE_DATE=%1
set PROD_REPORT_FOLDER=%2

REM get month & date for folder
SET CLOSE_DATE1=abc %1
  
FOR /F "TOKENS=1,2 eol=/ DELIMS=/ " %%A IN ('echo %CLOSE_DATE1%') DO SET mm=%%B
FOR /F "TOKENS=1,2 DELIMS=/ eol=/" %%A IN ('echo %CLOSE_DATE%') DO SET dd=%%B
FOR /F "TOKENS=2,3 DELIMS=/ " %%A IN ('echo %CLOSE_DATE%') DO SET yyyy=%%B


set OUT_FOLDER="S:\IT\Production\Daily Reports\Primary Market\%yyyy%-%mm%\"

echo RunOriginatorMortgageRateReport.....
Call RunOriginatorMortgageRateReport.bat %CLOSE_DATE% %OUT_FOLDER%
echo RunServicingSpreadandSurveyRateReport.....
Call RunServicingSpreadandSurveyRateReport.bat %CLOSE_DATE% %OUT_FOLDER%
echo RunTimeFromRefinancingApplicationToFundingReport.....
Call RunTimeFromRefinancingApplicationToFundingReport.bat %CLOSE_DATE% %OUT_FOLDER%
echo RunProxyForPipelineHedgingCostsReport.....
Call RunProxyForPipelineHedgingCostsReport.bat %CLOSE_DATE% %OUT_FOLDER%
echo RunMarketConcentrationReport.....
Call RunMarketConcentrationReport.bat %CLOSE_DATE% %OUT_FOLDER%
echo RunEffectiveGFees.....
Call RunEffectiveGFees.bat %CLOSE_DATE% %OUT_FOLDER%
echo RunSpecifiedPoolReport.....
Call RunSpecifiedPoolReport.bat %CLOSE_DATE% %OUT_FOLDER%
echo RunSpecifiedPoolReportFreddie.....
Call RunSpecifiedPoolReportFreddie.bat %CLOSE_DATE% %OUT_FOLDER%
echo RunApplicationActivityReport.....
Call RunApplicationActivityReport.bat %CLOSE_DATE% %OUT_FOLDER%
echo RunAverageClosingCost.....
Call RunAverageClosingCost.bat %CLOSE_DATE% %OUT_FOLDER%
echo RunMarketConcentrationReport_NonBankLender.....
Call RunMarketConcentrationReport_NonBankLender.bat %CLOSE_DATE% %OUT_FOLDER%
echo RunMortgageBankEmploymentReport.....
Call RunMortgageBankEmploymentReport.bat %CLOSE_DATE% %OUT_FOLDER%
echo RunMortgageRateDifferences.....
Call RunMortgageDifferencesReport.bat %CLOSE_DATE% %OUT_FOLDER%
echo RunMarketConcentrationGNMReport.....
Call RunMarketConcentrationReportGNM.bat %CLOSE_DATE% %OUT_FOLDER%
echo RunUniverseCreditAvailabilityReport.....
Call RunUniverseCreditAvailabilityReport.bat %CLOSE_DATE% %OUT_FOLDER%
echo RunConvCreditAvailabilityReport.....
Call RunConvCreditAvailabilityReport.bat %CLOSE_DATE% %OUT_FOLDER%

echo RunRefinancibleUniverseReport.....
Call RunRefinancibleUniverseReport.bat %CLOSE_DATE% %OUT_FOLDER%
REM echo RunRefinancibleUniverseReport_MediaEffect.....
REM Call RunRefinancibleUniverseReport_MediaEffect.bat %CLOSE_DATE% %OUT_FOLDER%


TIMEOUT /T 3


REM merge reports
Call PrimaryMarketMergePDFReports.bat %CLOSE_DATE% %OUT_FOLDER% %PROD_REPORT_FOLDER%

cd %SCRIPT_PATH%