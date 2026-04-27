@Echo on

REM >> syntax: cscript DownloadFileWeb /url:12/4/13 /filename:c:\tmp\test.xls

set URL=http://www.freddiemac.com/pmms/2015/historicalweeklydata.xls


For /f "tokens=2-4 delims=/ " %%a in ('date /t') do (set CURR_DATE=%%c-%%a-%%b)

SET FILE_DATE=%CURR_DATE%
rem	SET FILE_NAME=S:\it\tmp\johnson\historicalweeklydata_%FILE_DATE%.xls
SET FILE_NAME= S:\Research\PIV\Mortgage Data\Freddie Survey Rates\historicalweeklydata.xls

cscript DownloadFileWeb.vbs /url:%URL% /filename:"%FILE_NAME%"

