@echo off

set CLOSE_DATE=%1
REM Risk report

REM get month & date for folder
SET CLOSE_DATE1=abc %1
  
FOR /F "TOKENS=1,2 eol=/ DELIMS=/ " %%A IN ('echo %CLOSE_DATE1%') DO SET mm=%%B
FOR /F "TOKENS=1,2 DELIMS=/ eol=/" %%A IN ('echo %CLOSE_DATE%') DO SET dd=%%B
FOR /F "TOKENS=2,3 DELIMS=/ " %%A IN ('echo %CLOSE_DATE%') DO SET yyyy=%%B


REM **************** Primary Market Daily ****************
echo "Running Primary Market Daily report..."
cd "S:\IT\Production\Daily Reports\Primary Market\"
call RunPrimaryMarketReport.bat %CLOSE_DATE% "S:\Analytics\Primary Market\%yyyy%\%mm%" 



cd "S:\IT\Production\Daily Reports\"


