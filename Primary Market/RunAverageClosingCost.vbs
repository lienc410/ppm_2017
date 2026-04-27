option explicit

' >> Example - cscript RunAverageClosingCost /date:12/4/13 /out:c:\tmp\ /env:PROD

if WScript.Arguments.Count < 2 then
	msgbox "Please specify => Syntax - RunAverageClosingCost /date:<mm/dd/yy> /out:<PDF Report File Directory> /env:<PROD | DEV>"
else
	RunReport
end if

' ------------- main sub -------------
Sub RunReport()
	Dim xlApp
	Dim xlBook

	Dim args : set args = wscript.arguments.named
	
	Dim closeDate
	Dim pdfReportDir
	Dim portfolioID
	Dim env
	Dim masterPath
	Dim calc
	
	' --------- parsing input parameters ---------
	closeDate = args.item("date")
	pdfReportDir = args.item("out")	
	env = args.item("env")	

	' --------- parsing input parameters ---------
	
	Set xlApp = CreateObject("Excel.Application")
	masterPath = "S:\IT\Production\Daily Reports\Primary Market\"
	Set xlBook = xlApp.Workbooks.Open(masterPath & "10.Bankrate Closing Costs Survey Master.xlsm", 0, True)  ' open read-only
	
	WScript.stdout.WriteLine("--------- Input Parameters ---------")
	WScript.stdout.WriteLine("Report: RunAverageClosingCost")
	WScript.stdout.WriteLine("Close Date = " & closeDate)
	WScript.stdout.WriteLine("Output Folder = " & pdfReportDir)
	WScript.stdout.WriteLine("Database Env = " & env)
	WScript.stdout.WriteLine("--------- Input Parameters ---------")
	WScript.stdout.WriteLine("  ")
	
 'xlApp.visible = true	
	
	' --------- setting parameters ---------
	xlBook.sheets("Report").range("CurrentCloseDate") = closeDate
	xlBook.sheets("Report").range("PDFReportDir") = pdfReportDir
	
	
	if env <> "" then
		xlBook.sheets("Report").range("DatabaseEnv") = env
	end if
	

	' --------- setting parameters ---------
	
	WScript.stdout.WriteLine("--------- Sheet Parameters ---------")
	WScript.stdout.WriteLine("Close Date = " &  xlBook.sheets("Report").range("CurrentCloseDate"))
	WScript.stdout.WriteLine("Output Folder = " &  xlBook.sheets("Report").range("PDFReportDir"))
	WScript.stdout.WriteLine("Database Env = " &  xlBook.sheets("Report").range("DatabaseEnv"))
	WScript.stdout.WriteLine("--------- Sheet Parameters ---------")

	' run the report
	xlApp.run "RunClosingCostReportBatch"
	
	'xlApp.quit
end sub 