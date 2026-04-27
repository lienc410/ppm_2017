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



TIMEOUT /T 3


REM merge reports
Call PrimaryMarketMergePDFReports.bat %CLOSE_DATE% %OUT_FOLDER% %PROD_REPORT_FOLDER%

cd %SCRIPT_PATH%