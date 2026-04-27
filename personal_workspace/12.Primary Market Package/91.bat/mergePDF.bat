@ECHO off

For /f "tokens=2-4 delims=/ " %%a in ('date /t') do (set CURR_DATE=%%c-%%a-20)


set NAME_PREFIX="S:\Analytics\Primary Market Report\
REM set NAME_PREFIX=%2
set OUT_PDF="S:\Analytics\Primary Market Report\0.Daily Report\Primary Market Report %CURR_DATE%.pdf"

set FILE1=%NAME_PREFIX%1.Daily Originator Mortgage Rate Report\Daily Originator Mortgage Rate Report %CURR_DATE%.pdf"
set FILE2=%NAME_PREFIX%3.Servicing Spread and FNCL Survey Rate\Servicing Spread and FNCL Survey Rate %CURR_DATE%.pdf"
set FILE3=%NAME_PREFIX%4.Time from Refinancing Application to Funding\Time from Refinancing Application to Funding %CURR_DATE%.pdf"
set FILE4=%NAME_PREFIX%5.Market Concentration\Market Concentration %CURR_DATE%.pdf"
set FILE5=%NAME_PREFIX%9.Assumption Page\Assumptions Page.pdf"

c:\pdftk\bin\pdftk A=%FILE1% B=%FILE2% C=%FILE3% D=%FILE4% E=%FILE5% cat output %OUT_PDF%