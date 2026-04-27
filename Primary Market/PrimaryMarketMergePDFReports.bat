@ECHO on

set CLOSE_DATE=%1
REM Risk report

REM get month & date for folder
SET CLOSE_DATE1=abc %1
  
FOR /F "TOKENS=1,2 eol=/ DELIMS=/ " %%A IN ('echo %CLOSE_DATE1%') DO SET mm=%%B
FOR /F "TOKENS=1,2 DELIMS=/ eol=/" %%A IN ('echo %CLOSE_DATE%') DO SET dd=%%B
FOR /F "TOKENS=2,3 DELIMS=/ " %%A IN ('echo %CLOSE_DATE%') DO SET yyyy=%%B

set REPORT_FOLDER=%2

REM go to the report folder
cd %REPORT_FOLDER%

set PROD_REPORT_FOLDER=%3

REM replace " to blank
set PROD_REPORT_FOLDER2=%PROD_REPORT_FOLDER:"=%

REM construct the folder path
set PROD_REPORT_FOLDER=%PROD_REPORT_FOLDER2%

REM set the final pdf file name
set FINAL_PDF="%PROD_REPORT_FOLDER%\Primary Market Report %yyyy%-%mm%-%dd%.pdf"

set FILE1="Daily Originator Mortgage Rate Report %yyyy%-%mm%-%dd%.pdf"
set FILE2="Servicing Spread and Survey Rate %yyyy%-%mm%-%dd%.pdf"
set FILE7="Effective g fee %yyyy%-%mm%-%dd%.pdf"
set FILE3="Time from Refinancing Application to Funding %yyyy%-%mm%-%dd%.pdf"
set FILE4="Proxy For Pipeline Hedging Costs %yyyy%-%mm%-%dd%.pdf"
set FILE5="Market Concentration %yyyy%-%mm%-%dd%.pdf"
set FILE6="Specified Pool %yyyy%-%mm%-%dd%.pdf"
set FILE9="Specified Pool - Freddie %yyyy%-%mm%-%dd%.pdf"
set FILE10="Application Activity %yyyy%-%mm%-%dd%.pdf"
set FILE11="Average Closing Cost %yyyy%-%mm%-%dd%.pdf"
set FILE12="Market Concentration - NonBank Lenders %yyyy%-%mm%-%dd%.pdf"
set FILE13="MortgageBankEmployment %yyyy%-%mm%-%dd%.pdf"
set FILE14="Refinancible Universe %yyyy%-%mm%-%dd%.pdf"
REM set FILE15="Refinancible Universe - Media Effect Scenario %yyyy%-%mm%-%dd%.pdf"
set FILE16="Mortgage Rate Difference Between Large and Small Lenders %yyyy%-%mm%-%dd%.pdf"
set FILE17="Market Concentration  - GNM %yyyy%-%mm%-%dd%.pdf"
set FILE18="Universe Credit Availability %yyyy%-%mm%-%dd%.pdf"
set FILE19="Credit Availability %yyyy%-%mm%-%dd%.pdf"
 
set FILE8="S:\IT\Production\Daily Reports\Primary Market\Assumptions Page.pdf"

c:\pdftk\bin\pdftk A=%FILE1% B=%FILE2%  G=%FILE7% C=%FILE3% D=%FILE4% E=%FILE5% L=%FILE12% Q=%FILE17% F=%FILE6% I=%FILE9% J=%FILE10% K=%FILE11% M=%FILE13% N=%FILE14% P=%FILE16% R=%FILE18% S=%FILE19% H=%FILE8% cat output %FINAL_PDF%

c:\jpdfbookmarks\jpdfbookmarks_cli "%PROD_REPORT_FOLDER%\Primary Market Report %yyyy%-%mm%-%dd%.pdf" -f -a "S:\IT\Production\Daily Reports\Primary Market\Primary Market Report Bookmark.txt" -o "%PROD_REPORT_FOLDER%\Primary Market Report %yyyy%-%mm%-%dd%.pdf"
