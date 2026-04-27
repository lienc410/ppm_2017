REM Run PIV and Sonata Daily Reports from a scheduler
@echo off

set BUS_DATE_SCRIPT="S:\IT\Production\Daily Reports\Scripts\vbs\GetPrevBusinessDate.vbs"
set BUS_DATE_FILE="c:\tmp\prev_business_date.txt"

set PIV_RUN_DIR=S:\IT\Production\PIVReports\
set SONATA_RUN_DIR=S:\IT\Production\PIVReports\
set PRIMARY_RUN_DIR=S:\IT\Production\Daily Reports\

set PIV_RUN_SCRIPT=GenerateRiskReports.bat
set SONATA_RUN_SCRIPT=GenerateSonataRiskReports.bat
set PRIMARY_RUN_SCRIPT=RunPrimaryMarketReports.bat

cscript %BUS_DATE_SCRIPT% /today:%1 /outfile:%BUS_DATE_FILE%

echo Running report for:
echo -------------------------------------------
type %BUS_DATE_FILE%
echo -------------------------------------------

S:
cd %PIV_RUN_DIR%

FOR /f "delims=" %%i IN ('type %BUS_DATE_FILE%') DO set CLOSE_DATE=%%i




echo ---------------- Running PIV reports ----------------
echo "Starting running PIV Daily Batch reports for %CLOSE_DATE% ..."
cscript S:\IT\Production\Scripts\emailConfig.vbs "johnson.ho@PIVcapital.com;analytics@PIVcapital.com" "Start running PIV Daily Batch Report %CLOSE_DATE%" "Running PIV Daily Batch Report %CLOSE_DATE%" 
Call %PIV_RUN_SCRIPT% %CLOSE_DATE%
cscript S:\IT\Production\Scripts\emailConfig.vbs "johnson.ho@PIVcapital.com;analytics@PIVcapital.com" "Done running PIV Daily Batch Report %CLOSE_DATE%" "Done running PIV Daily Batch Report %CLOSE_DATE%" 

echo ---------------- Running Sonata reports ----------------
cd %SONATA_RUN_DIR%
echo "Starting running Sonata Daily Batch reports for %CLOSE_DATE% ..."
cscript S:\IT\Production\Scripts\emailConfig.vbs "johnson.ho@PIVcapital.com;analytics@PIVcapital.com" "Start running Sonata Daily Batch Report %CLOSE_DATE%" "Running Sonata Daily Batch Report %CLOSE_DATE%"  
Call %SONATA_RUN_SCRIPT% %CLOSE_DATE%
cscript S:\IT\Production\Scripts\emailConfig.vbs "johnson.ho@PIVcapital.com;analytics@PIVcapital.com" "Done running Sonata Daily Batch Report %CLOSE_DATE%" "Done running Sonata Daily Batch Report %CLOSE_DATE%"  



echo ---------------- Running Primary Market reports ----------------
cd %PRIMARY_RUN_DIR%
echo "Starting running Primary Market Batch reports for %CLOSE_DATE% ..."
cscript S:\IT\Production\Scripts\emailConfig.vbs "lien.chen@PIVcapital.com;analytics@PIVcapital.com" "Start running Primary Market Daily Batch Report %CLOSE_DATE%" "Running Primary Market Daily Batch Report %CLOSE_DATE%"  
Call %PRIMARY_RUN_SCRIPT% %CLOSE_DATE%
cscript S:\IT\Production\Scripts\emailConfig.vbs "lien.chen@PIVcapital.com;analytics@PIVcapital.com" "Done running Primary Market Daily Batch Report %CLOSE_DATE%" "Done running Primary Market Daily Batch Report %CLOSE_DATE%"  
