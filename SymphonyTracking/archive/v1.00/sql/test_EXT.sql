set temporary option temp_extract_name1='G:/tempExtract/model_input/PrepayPoolData_jumbo_2016.csv';
set temporary option temp_extract_column_delimiter='|';
set temporary option Temp_Extract_Row_Delimiter='\n';
set temporary option Temp_Extract_Quote='"';
set temporary option Temp_Extract_Quotes_All='OFF';
set temporary option Temp_Extract_Quotes='ON';
set temporary option Temp_Extract_Null_As_Empty='ON';
SELECT
   agency,factorasOf
FROM  loadDates
;