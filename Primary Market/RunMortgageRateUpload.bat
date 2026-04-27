@Echo off


set SCRIPT_PATH="S:\IT\Production\Daily Reports\Primary Market\"

REM get month & date for folder
For /f "tokens=2-4 delims=/ " %%a in ('date /t') do (set CLOSE_DATE=%%c%%a%%b)

echo %CLOSE_DATE%

s:
cd S:\IT\Production\Scripts\python\ccmUtilP\src
python LoadMortgageRate.py %CLOSE_DATE%


rem TIMEOUT /T 20

cd %SCRIPT_PATH%
