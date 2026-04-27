@Echo off

REM >> syntax: cscript RunSpecifiedPoolReport /date:12/4/13 /out:c:\tmp\ /env:PROD
cd S:\IT\Production\Scripts\python\ccmUtilP\src
python PrimaryMarketReportDataCheck.py %1