@Echo off

REM >> syntax: cscript RunServicingSpreadandSurveyRateReport /date:20/3/15 /out:c:\tmp\ /env:PROD
set SCRIPT_PATH="C:\PIV\PIV-it-dev\trunk\Research\CurrentCouponModel\"

REM get month & date for folder
Rem For /f "tokens=2-4 delims=/ " %%a in ('date /t') do (set CLOSE_DATE=%%c%%a%%b)
For /f "tokens=2-4 delims=/ " %%a in ('date /t') do (set CLOSE_DATE=%%a/%%b/%%c)

echo %CLOSE_DATE%

c:
cd S:\IT\Production\Current Coupon
CurrentCouponInput.exe %CLOSE_DATE%

For /f "tokens=2-4 delims=/ " %%a in ('date /t') do (set CLOSE_DATE=%%c%%a%%b)
CurrentCoupon.exe %CLOSE_DATE%

For /f "tokens=2-4 delims=/ " %%a in ('date /t') do (set CLOSE_DATE=%%a/%%b/%%c)
CurrentCouponResult.exe %CLOSE_DATE%

rem TIMEOUT /T 20

cd %SCRIPT_PATH%