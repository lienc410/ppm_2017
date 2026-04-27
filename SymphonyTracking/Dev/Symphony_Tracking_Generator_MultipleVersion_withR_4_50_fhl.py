'''
Symphony_Tracking_Generator.py
This is the program to create and store model tracking data for use in Symphony

Steps:
1) Run SQL queries to create files with pool collateral data
2) Run Scale [SYMPHONY_TRACKING_REQUEST] for each data file
3) Load the model output files from Scale into IQ

This procedure should be run for each factor date (9th business day),
or for a new model release

v2.20 Notes
-

Options
--model
--factor_date
-R (use R as calculation engine)
-S (sample data only)

Usage
1) 9th business day factor data update
Symphony_Tracking_Generator.py --factor_update --model 2.10 --factor_date 20160701
2) New model tracking
Symphony_Tracking_Generator.py --new_model --model 2.10 --factor_date 20160701
3) New model tracking w/ R as Calculation Engine
Symphony_Tracking_Generator.py --new_model --model 2.10 --factor_date 20160701 -R
4) New model tracking only for sample data
Symphony_Tracking_Generator.py --new_model --model 2.10 --factor_date 20160701 -S

'''

import sys
import pyodbc
import os
import getopt
import datetime
import threading
import time
import re

def process_sql_file(sql_file, sql_cursor):
    full_sql = ''
    sql_chunk = ''
    with open(sql_file, 'r') as inp:
        for line in inp:
            if re.search("^--", line.lstrip()):
                continue
            if re.search(";", line):
                sql_chunk += line
                full_sql += line
                print("----BEG------")
                print(sql_chunk)
                print("-----END-----")
                sql_cursor.execute(sql_chunk)
                sql_chunk = ''
            else:
                sql_chunk += line
                full_sql += line
    inp.close()
    return full_sql


def process_sql_contents(sql_file_contents, sql_cursor):
    full_sql = ''
    sql_chunk = ''
    for line in sql_file_contents.splitlines(True):  # set to True to keep the new lines in the lines (required by sql)
        if re.search("^--", line.lstrip()):
            continue
        if re.search(";", line):
            sql_chunk += line
            full_sql += line
            print("----BEG------")
            print(sql_chunk)
            print("-----END-----")
            sql_cursor.execute(sql_chunk)
            sql_chunk = ''
        else:
            sql_chunk += line
            full_sql += line
    return full_sql

def generate_data(full_update, factor_date, sample_only, model):
    print "Starting generate_data"
    
    running_ticker_list = list(ticker_list)
    print running_ticker_list 
    if 'ginnie' in running_ticker_list:
        ginnie_list = ['ginnie']
        for ticker in ginnie_list:
            generate_loan_data_ginnie(ginnie_list, full_update, factor_date, sample_only, model)
        running_ticker_list.remove('ginnie')
    
    if len(running_ticker_list):
        generate_loan_data_conv(running_ticker_list, full_update, factor_date, sample_only, model)
    
    print "Exiting generate_data"
    
def generate_model_output(factor_date, use_r_engine, model):
    print "Starting generate_model_output"
    
    running_ticker_list = list(ticker_list)
    if 'ginnie' in running_ticker_list:
        ginnie_list = ['ginnie']
        for ticker in ginnie_list:
            generate_model_output_loan_ginnie(ginnie_list, factor_date, use_r_engine, model)
        running_ticker_list.remove('ginnie')
    
    if len(running_ticker_list):
        generate_model_output_loan_conv(running_ticker_list, factor_date, use_r_engine, model)
    
    print "Exiting generate_model_output"
    
def load_model_data(factor_date, full_update, model):
    print "Starting load_model_data"
    
    running_ticker_list = list(ticker_list)
    if 'project_loan' in running_ticker_list:
        GPL_list = ['project_loan']
        for ticker in GPL_list:
            load_model_data_loan_GPL(GPL_list, factor_date, full_update, model)
        running_ticker_list.remove('project_loan')
    
    if len(running_ticker_list):
        load_model_data_loan(running_ticker_list, factor_date, full_update, model)
    
    print "Exiting load_model_data"

def generate_loan_data_conv(run_ticker_list, full_update, factor_date, sample_only, model):

    # Function for Threading
    def process(ticker):

        print "ProcessinH:" + ticker
        # Acquire Semaphore
        pool_semaphore.acquire()

        # Constants
        factor_date_dt = datetime.datetime.strptime(factor_date, '%Y%m%d')
        prepay_date_dt = (factor_date_dt - datetime.timedelta(1)).replace(day=1)
        prepay_date = datetime.date.strftime(prepay_date_dt, '%Y%m%d')

        # Get the Ticker Tuple
        ticker_tuple = ticker_dict[ticker]
		
        model_tuple = model_dict[model]
        model_name = model_tuple[ticker_tuple['model']+'_name']
        model_version = model_tuple[ticker_tuple['model']+'_version']
        model_type = ticker_tuple['model_type']
		
        ticker_sql_file = ticker_tuple['ticker_sql']
        hpa_sql_file = ticker_tuple['hpa_sql'] if 'hpa_sql' in ticker_tuple else None
        media_effect_sql_file = ticker_tuple['media_sql'] if 'media_sql' in ticker_tuple else None
        mcai_sql_file = ticker_tuple['credit_sql'] if 'credit_sql' in ticker_tuple else None
        data_sql_file = ticker_tuple['data_sql']
        extract_sql_file = ticker_tuple['extract_sql']
        vintage_list = ticker_tuple['vintage_list'] if full_update else [1950, latest_year]

        symphony_tracking_path = 'H:/SymphonyTracking/' + environment + '/'
        sql_path = os.path.join(symphony_tracking_path, 'sql/'+model)
        print sql_path

        model_path = os.path.join(drive, 'tempExtract/PrepayLoanData/' + model_type + '/Model_' + model_version)
        factor_path = os.path.join(model_path, factor_date)
        extract_path = os.path.join(factor_path, 'model_input')
        sql_output_path = os.path.join(factor_path, 'sql_output')

        # Create the Output Folder if needed
        if full_update:
            # Create the model folder
            if not os.path.exists(model_path):
                os.makedirs(model_path)
        # Create the extract folder
        if not os.path.exists(extract_path):
            os.makedirs(extract_path)
        # Create the sql extract folder
        if not os.path.exists(sql_output_path):
            os.makedirs(sql_output_path)

        # Get Sybase IQ Database connection
        # DSN: Agency
        conn = pyodbc.connect('DSN=' + "Agency" + ';UID=' + "report" + ';PWD=' + "gm4SJDw4" + ';DATABASE=' + 'Agency' + ';Autostop=No')
        cursor = conn.cursor()

        # Step 0: Setup the SQL
        full_sql = ''
        sql_chunk = ''
        full_sql_file = os.path.join(sql_output_path, ticker + '_' + 'prepay_model_data_full.sql')

        # Step 1: Add the Ticker SQL
        ticker_sql_file = os.path.join(sql_path, ticker_sql_file)
        print "Ticker:" + ticker + "--->" + ticker_sql_file + "   ----- TICKER SQL FILE"
        full_sql += process_sql_file(ticker_sql_file, cursor)

        # Step 2: Add the HPA Series
        if hpa_sql_file is not None:
            hpa_sql_file = os.path.join(sql_path, hpa_sql_file)
            print "Ticker:" + ticker + "--->" + hpa_sql_file + "   ----- HPA SQL FILE"
            full_sql += process_sql_file(hpa_sql_file, cursor)

        # Step 3: Add the Media Effect Series
        if media_effect_sql_file is not None:
            media_effect_sql_file = os.path.join(sql_path, media_effect_sql_file)
            print "Ticker:" + ticker + "--->" + media_effect_sql_file + "   ----- MEDIA EFFECT SQL FILE"
            full_sql += process_sql_file(media_effect_sql_file, cursor)

        # Step 4: Add the Credit Availability Series
        if mcai_sql_file is not None:
            mcai_sql_file = os.path.join(sql_path, mcai_sql_file)
            print "Ticker:" + ticker + "--->" + mcai_sql_file + "   ----- MCAI SQL FILE"
            full_sql += process_sql_file(mcai_sql_file, cursor)

        # Step 5: Add the Data SQL
        data_sql_file = os.path.join(sql_path, data_sql_file)
        print "Ticker:" + ticker + "--->" + data_sql_file + "   ----- DATA SQL FILE"
        asof_where = " AND slh.asOf <= '%s' " % prepay_date if full_update else " AND slh.asOf = '%s' " % prepay_date
        with open(data_sql_file, 'r') as inp:
            file_contents = inp.read().replace("@ASOF_WHERE@", asof_where)
            file_contents = file_contents.replace("@DATABASE@", model)
        if sample_only: 
                sample_join     = ' JOIN scale.SampleLoanSeqNums si ON cl.loanSeqNum = si.loanSeqNum '
                file_contents   = file_contents.replace("--@SAMPLE_JOIN@", sample_join)
        inp.close()
        full_sql += process_sql_contents(file_contents, cursor)

        # Step 6: Add the Vintage Extract
        if not sample_only:
            print "Processing for Ticker For Vintages: " + ticker + " Started"
            extract_file = os.path.join(sql_path, extract_sql_file)
            for ii in range(len(vintage_list) - 1):
                vintage_low = vintage_list[ii]
                vintage_high = vintage_list[ii+1]
                extract_file_path = extract_path + '/' + 'PrepayLoanData_' + ticker + '_' + str(vintage_high) + '.csv'
                vintage_where = ' AND vintage > %s AND vintage <= %s ' % (vintage_low, vintage_high)
                print "Ticker:" + ticker + "--->" + extract_file + "   ----- EXTRACT SQL FILE"
                with open(extract_file, 'r') as inp:
                    file_contents = inp.read().replace("@EXTRACT_FILE_PATH@", extract_file_path)
                    file_contents = file_contents.replace("@VINTAGE_WHERE@", vintage_where)
                    file_contents = file_contents.replace("@ASOF_WHERE@", asof_where)
                inp.close()
                full_sql += process_sql_contents(file_contents, cursor)
                rows = cursor.fetchall()  # must have this line for extraction to work correctly
                cursor.execute("set temporary option temp_extract_name1=''")
                full_sql += "set temporary option temp_extract_name1=''"

            print "Processing for Ticker For Vintages: " + ticker + " Completed"

        # Step 7: Add the Sample Extract (Sample for more loans)
        print "Processing for Ticker For Sample(Sample for more loans):" + ticker + " Started"
        extract_file = os.path.join(sql_path, extract_sql_file)
        extract_file_path = extract_path + '/' + 'PrepayLoanData_' + ticker + '_sample.csv'
        vintage_where = ' AND 1=1 '
        sample_join = ' JOIN scale.SampleLoanSeqNums si ON slh.loanSeqNum = si.loanSeqNum '
        print extract_file_path
        with open(extract_file, 'r') as inp:
            file_contents = inp.read().replace("@EXTRACT_FILE_PATH@", extract_file_path)
            file_contents = file_contents.replace("@VINTAGE_WHERE@", vintage_where)
            file_contents = file_contents.replace("--@SAMPLE_JOIN@", sample_join)
            file_contents = file_contents.replace("@ASOF_WHERE@", asof_where)
        inp.close()
        full_sql += process_sql_contents(file_contents, cursor)
        rows = cursor.fetchall()  # must have this line for extraction to work correctly
        cursor.execute("set temporary option temp_extract_name1=''")
        full_sql += "set temporary option temp_extract_name1=''"
        
        print "Processing for Ticker For Sample(Sample for more loans):" + ticker + " Completed"

        # Step 8: Exit
        cursor.commit()
        with open(full_sql_file, 'w+') as content_file:
            content_file.write(full_sql)

        # Close the Connection
        conn.close()

        # Release Semaphore
        pool_semaphore.release()

    # Run SQL for each Ticker
    # One Thread for each Ticker
    threads = []
    max_connections = IQ_threads
    pool_semaphore = threading.BoundedSemaphore(value=max_connections)

    # Loop over Tickers
    for run_ticker in run_ticker_list:
        threads.append(threading.Thread(target=process, args=(run_ticker,)))
        time.sleep(2)
        try:
            threads[-1].start()
        except:
            time.sleep(5)

    for t in threads:
        t.join()

    print "Exiting generate_loan_data_conv"

def generate_loan_data_ginnie(run_ticker_list, full_update, factor_date, sample_only, model):
    
    # Function for Threading
    def process(ticker):

        print "ProcessinH:" + ticker
        # Acquire Semaphore
        pool_semaphore.acquire()

        # Constants
        factor_date_dt = datetime.datetime.strptime(factor_date, '%Y%m%d')
        prepay_date_dt = (factor_date_dt - datetime.timedelta(1)).replace(day=1)
        prepay_date = datetime.date.strftime(prepay_date_dt, '%Y%m%d')

        # Get the Ticker Tuple
        ticker_tuple = ticker_dict[ticker]
		
        model_tuple = model_dict[model]
        model_name = model_tuple[ticker_tuple['model']+'_name']
        model_version = model_tuple[ticker_tuple['model']+'_version']
        model_type = ticker_tuple['model_type']
		
        ticker_sql_file = ticker_tuple['ticker_sql']
        hpa_sql_file = ticker_tuple['hpa_sql'] if 'hpa_sql' in ticker_tuple else None
        media_effect_sql_file = ticker_tuple['media_sql'] if 'media_sql' in ticker_tuple else None
        mcai_sql_file = ticker_tuple['credit_sql'] if 'credit_sql' in ticker_tuple else None
        data_sql_file = ticker_tuple['data_sql']
        extract_sql_file = ticker_tuple['extract_sql']
        vintage_list = ticker_tuple['vintage_list'] if full_update else [1950, latest_year]
        loan_type_list = ticker_tuple['loan_type_list']

        symphony_tracking_path = 'H:/SymphonyTracking/' + environment + '/'
        sql_path = os.path.join(symphony_tracking_path, 'sql/'+model)

        model_path = os.path.join(drive, 'tempExtract/PrepayLoanData/' + model_type + '/Model_' + model_version)
        factor_path = os.path.join(model_path, factor_date)
        extract_path = os.path.join(factor_path, 'model_input')
        sql_output_path = os.path.join(factor_path, 'sql_output')

        # Create the Output Folder if needed
        if full_update:
            # Create the model folder
            if not os.path.exists(model_path):
                os.makedirs(model_path)
        # Create the extract folder
        if not os.path.exists(extract_path):
            os.makedirs(extract_path)
        # Create the sql extract folder
        if not os.path.exists(sql_output_path):
            os.makedirs(sql_output_path)

        # Get Sybase IQ Database connection
        # DSN: Agency
        #conn = pyodbc.connect('DSN=' + "ScaleAgencyPool" + ';UID=' + "report"+';PWD=' + "xaYc14rJ" + ';DATABASE=' + 'Agency' + ';Autostop=No')
        conn = pyodbc.connect('DSN=' + "Agency" + ';UID=' + "report"+';PWD=' + "gm4SJDw4" + ';DATABASE=' + 'Agency' + ';Autostop=No')
        cursor = conn.cursor()

        # Step 0: Setup the SQL
        full_sql = ''
        sql_chunk = ''
        full_sql_file = os.path.join(sql_output_path, ticker + '_' + 'prepay_model_data_full.sql')

        # Step 1: Add the Ticker SQL
        ticker_sql_file = os.path.join(sql_path, ticker_sql_file)
        print "Ticker:" + ticker + "--->" + ticker_sql_file + "   ----- TICKER SQL FILE"
        full_sql += process_sql_file(ticker_sql_file, cursor)

        # Step 2: Add the HPA Series
        if hpa_sql_file is not None:
            hpa_sql_file = os.path.join(sql_path, hpa_sql_file)
            print "Ticker:" + ticker + "--->" + hpa_sql_file + "   ----- HPA SQL FILE"
            full_sql += process_sql_file(hpa_sql_file, cursor)

        # Step 3: Add the Media Effect Series
        if media_effect_sql_file is not None:
            media_effect_sql_file = os.path.join(sql_path, media_effect_sql_file)
            print "Ticker:" + ticker + "--->" + media_effect_sql_file + "   ----- MEDIA EFFECT SQL FILE"
            full_sql += process_sql_file(media_effect_sql_file, cursor)

        # Step 4: Add the Credit Availability Series
        if mcai_sql_file is not None:
            mcai_sql_file = os.path.join(sql_path, mcai_sql_file)
            print "Ticker:" + ticker + "--->" + mcai_sql_file + "   ----- MCAI SQL FILE"
            full_sql += process_sql_file(mcai_sql_file, cursor)

        # Step 5: Add the Data SQL
        data_sql_file = os.path.join(sql_path, data_sql_file)
        print "Ticker:" + ticker + "--->" + data_sql_file + "   ----- DATA SQL FILE"
        asof_where = " AND slh.asOf <= '%s' " % prepay_date if full_update else " AND slh.asOf = '%s' " % prepay_date
        with open(data_sql_file, 'r') as inp:
            file_contents   = inp.read().replace("@ASOF_WHERE@", asof_where)
            file_contents   = file_contents.replace("@DATABASE@", model)
            if sample_only:
                sample_join     = ' JOIN scale.SampleLoanSeqNums si ON slh.LoanSeqNum = si.LoanSeqNum '
                file_contents   = file_contents.replace("--@SAMPLE_JOIN@", sample_join)
        inp.close()
        full_sql += process_sql_contents(file_contents, cursor)

        # Step 6: Add the Vintage Extract
        for loan_type in loan_type_list:
            if not sample_only:    
                print "Processing for Ticker For Vintages: " + ticker + loan_type + " Started"
                extract_file = os.path.join(sql_path, extract_sql_file)
                for ii in range(len(vintage_list) - 1):
                    vintage_low = vintage_list[ii]
                    vintage_high = vintage_list[ii+1]
                    extract_file_path = extract_path + '/' + 'PrepayLoanData_' + ticker + '_' + loan_type + '_' + str(vintage_high) + '.csv'
                    vintage_where = ' AND vintage > %s AND vintage <= %s ' % (vintage_low, vintage_high)
                    loantype_where = " AND loanType = '%s' " % loan_type
                    print "Ticker:" + ticker + "--->" + extract_file + "   ----- EXTRACT SQL FILE"
                    with open(extract_file, 'r') as inp:
                        file_contents = inp.read().replace("@EXTRACT_FILE_PATH@", extract_file_path)
                        file_contents = file_contents.replace("@VINTAGE_WHERE@", vintage_where)
                        file_contents = file_contents.replace("@ASOF_WHERE@", asof_where)
                        file_contents = file_contents.replace("@LOANTYPE_WHERE@", loantype_where)
                    inp.close()
                    full_sql += process_sql_contents(file_contents, cursor)
                    rows = cursor.fetchall()  # must have this line for extraction to work correctly
                    cursor.execute("set temporary option temp_extract_name1=''")
                    full_sql += "set temporary option temp_extract_name1=''"
    
                print "Processing for Ticker For Vintages: " + ticker + '_' + loan_type + " Completed"

        # Step 7: Add the Sample Extract (Sample for more pools)
            print "Processing for Ticker For Sample(Sample for more loans):" + ticker + " Started"
            extract_file = os.path.join(sql_path, extract_sql_file)
            extract_file_path = extract_path + '/' + 'PrepayLoanData_' + ticker + '_' + loan_type + '_sample.csv'
            vintage_where = ' AND 1=1 '
            loantype_where = " AND loanType = '%s' " % loan_type
            sample_join = ' JOIN scale.SampleLoanSeqNums si ON slh.LoanSeqNum = si.LoanSeqNum '
            print extract_file_path
            with open(extract_file, 'r') as inp:
                file_contents = inp.read().replace("@EXTRACT_FILE_PATH@", extract_file_path)
                file_contents = file_contents.replace("@VINTAGE_WHERE@", vintage_where)
                file_contents = file_contents.replace("--@SAMPLE_JOIN@", sample_join)
                file_contents = file_contents.replace("@ASOF_WHERE@", asof_where)
                file_contents = file_contents.replace("@LOANTYPE_WHERE@", loantype_where)
            inp.close()
            full_sql += process_sql_contents(file_contents, cursor)
            rows = cursor.fetchall()  # must have this line for extraction to work correctly
            cursor.execute("set temporary option temp_extract_name1=''")
            full_sql += "set temporary option temp_extract_name1=''"
            
            print "Processing for Ticker For Sample(Sample for more loans):" + ticker + '_' + loan_type + " Completed"

        # Step 8: Exit
        cursor.commit()
        with open(full_sql_file, 'w+') as content_file:
            content_file.write(full_sql)

        # Close the Connection
        conn.close()

        # Release Semaphore
        pool_semaphore.release()

    # Run SQL for each Ticker
    # One Thread for each Ticker
    threads = []
    max_connections = IQ_threads
    pool_semaphore = threading.BoundedSemaphore(value=max_connections)

    # Loop over Tickers
    for run_ticker in run_ticker_list:
        threads.append(threading.Thread(target=process, args=(run_ticker,)))
        time.sleep(2)
        try:
            threads[-1].start()
        except:
            time.sleep(5)

    for t in threads:
        t.join()

    print "Exiting generate_loan_data_ginnie"

def generate_model_output_loan_conv(run_ticker_list, factor_date, use_r_engine, model):

    # Function for Threading
    def process(scale_cmd, name_of_file):
        # Run the System Command to Start Scale
        print "starting..."
        print "cmd: " + cmd
        os.system(scale_cmd)
        time.sleep(15)
        print "===== Done running: %s =====" %(name_of_file)
		# Release Semaphore
        pool_semaphore.release()

    # Run Scale on each data file
    # One Thread for File
    threads = []
    max_connections = scale_threads
    pool_semaphore = threading.BoundedSemaphore(value=max_connections)

    for ticker in run_ticker_list:

        # Get the Ticker Tuple
        ticker_tuple = ticker_dict[ticker]
		
        model_tuple = model_dict[model]
        model_name = model_tuple[ticker_tuple['model']+'_name']
        model_version = model_tuple[ticker_tuple['model']+'_version']
        model_type = ticker_tuple['model_type']
 
        model_scale_path_tuple = model_scale_path[model]
        scale_path = model_scale_path_tuple[ticker_tuple['model']+'_scale_path']

        r_path = ticker_tuple['r_path']

        # Constants
        model_path = os.path.join(drive, 'tempExtract/PrepayLoanData/' + model_type + '/Model_' + model_version)
        factor_path = model_path + '/' + factor_date
        data_path = factor_path + '/' + 'model_input_split/'
        model_output_path = factor_path + '/' + 'model_output/'
        json_input_path = os.path.join(factor_path, 'json_input')

        symphony_tracking_path = 'S:/IT/Production/Scripts/python/Scale/SymphonyTracking/' + environment + '/'
        json_path = os.path.join(symphony_tracking_path, 'json')
        json_file = os.path.join(json_path, 'symphony_tracking.json')

        scale_bat = os.path.join(scale_path, 'RunScale.bat')
        uid = 'symphony_tracking'
        collateral = 'POOL'

        # Create the output folder
        if not os.path.exists(model_output_path):
            os.makedirs(model_output_path)
        if not os.path.exists(json_input_path):
            os.makedirs(json_input_path)

        # Search the Directory for Matching Files
        file_list = [f for f in os.listdir(data_path) if os.path.isfile(os.path.join(data_path, f)) and ticker in f]
        for file_name in file_list:
            # Begin Threading for Scale
			# Aquire Semaphore
            pool_semaphore.acquire()
			
            json_file_name = file_name.replace('.csv', '')
            json_infile_name = json_file_name + '_in.json'
            json_outfile_name = json_file_name + '_out.json'
            json_infile_path = os.path.join(json_input_path, json_infile_name)
            json_outfile_path = os.path.join(json_input_path, json_outfile_name)
            input_file_name = file_name

            if use_r_engine:
                os.chdir(r_path)
                #r_tieout_file = "GenSymphonyTracking.R"
                r_tieout_file = "GenSymphonyTracking_FHL_4_50_interpolation.R"
                r_script = os.path.join(r_path, r_tieout_file)
                log_file_name = 'log\\' + file_name + '.log'
                cmd = "\"C:\\Program Files\\R\\R-3.5.1\\bin\\x64\\R.exe\" CMD BATCH --vanilla --slave --%s --%s --%s --%s --%s %s %s" % (model_version, model_type, input_file_name, data_path, model_output_path, r_script, log_file_name)
                print "Processing for:" + file_name
                
            else:
                # Modify the JSON
                with open(json_file, 'r') as content_file:
                    json_file_json = content_file.read()

                # Replace Parameters in SQL
                json_file_json = json_file_json.replace("@UID@", uid + '_' + json_file_name)
                json_file_json = json_file_json.replace("@INPUT_FILE@", input_file_name)
                json_file_json = json_file_json.replace("@INPUT_PATH@", data_path)
                json_file_json = json_file_json.replace("@OUTPUT_PATH@", model_output_path)
                json_file_json = json_file_json.replace("@COLLATERAL@", collateral)
                json_file_json = json_file_json.replace("@PREPAY_MODEL_VERSION@", model_name)
                json_file_json = json_file_json.replace("@PREPAY_MODEL_TYPE@", model_type)

                # Write JSON File
                with open(json_infile_path, 'w+') as content_file:
                    content_file.write(json_file_json)
                os.chdir(scale_path)
                cmd = '%s %s %s' % (scale_bat, json_infile_path, json_outfile_path)
                print "Processing for:" + file_name

            # excuting thread
            t = threading.Thread(target=process, args=(cmd, file_name))
            threads.append(t)			
			
            try:
                threads[-1].start()
                time.sleep(2)
            except:
                print "did not work"
                time.sleep(5)

    for t in threads:
        t.join()

    print "Exiting generate_model_output_for_conv_loans"


def generate_model_output_loan_ginnie(run_ticker_list, factor_date, use_r_engine, model):

    # Function for Threading
    def process(scale_cmd, name_of_file):

        # Aquire Semaphore
        pool_semaphore.acquire()

        # Run the System Command to Start Scale
        print "starting..."
        print "cmd: " + cmd
        os.system(scale_cmd)
        time.sleep(15)
        print "===== Done running: %s =====" %(name_of_file)
		# Release Semaphore
        pool_semaphore.release()

    # Run Scale on each data file
    # One Thread for File
    threads = []
    max_connections = scale_threads
    pool_semaphore = threading.BoundedSemaphore(value=max_connections)

    for ticker in run_ticker_list:

        # Get the Ticker Tuple
        ticker_tuple = ticker_dict[ticker]
		
        model_tuple = model_dict[model]
        model_name = model_tuple[ticker_tuple['model']+'_name']
        model_version = model_tuple[ticker_tuple['model']+'_version']
        model_type = ticker_tuple['model_type']
		
        model_scale_path_tuple = model_scale_path[model]
        scale_path = model_scale_path_tuple[ticker_tuple['model']+'_scale_path']

        r_path = ticker_tuple['r_path']
        loan_type_list = ticker_tuple['loan_type_list']

        # Constants
        model_path = os.path.join(drive, 'tempExtract/PrepayLoanData/' + model_type + '/Model_' + model_version)
        factor_path = model_path + '/' + factor_date
        data_path = factor_path + '/' + 'model_input_split/'
        model_output_path = factor_path + '/' + 'model_output/'
        json_input_path = os.path.join(factor_path, 'json_input')

        symphony_tracking_path = 'H:/SymphonyTracking/' + environment + '/'
        json_path = os.path.join(symphony_tracking_path, 'json')
        json_file = os.path.join(json_path, 'symphony_tracking.json')

        scale_bat = os.path.join(scale_path, 'RunScale.bat')
        uid = 'symphony_tracking'
        collateral = 'POOL'

        # Create the output folder
        if not os.path.exists(model_output_path):
            os.makedirs(model_output_path)
        if not os.path.exists(json_input_path):
            os.makedirs(json_input_path)

        for loan_type in loan_type_list:
            # Search the Directory for Matching Files
            file_list = [f for f in os.listdir(data_path) if os.path.isfile(os.path.join(data_path, f)) and ticker in f]
            for file_name in file_list:
                if file_name.find(loan_type) >= 0:
                    json_file_name = file_name.replace('.csv', '')
                    json_infile_name = json_file_name + '_in.json'
                    json_outfile_name = json_file_name + '_out.json'
                    json_infile_path = os.path.join(json_input_path, json_infile_name)
                    json_outfile_path = os.path.join(json_input_path, json_outfile_name)
                    input_file_name = file_name
        
                    if use_r_engine:
                        os.chdir(r_path)
                        r_tieout_file = "GenSymphonyTracking_GNM_4_60_interpolation.R"
                        r_script = os.path.join(r_path, r_tieout_file)
                        log_file_name = 'log\\' + file_name + '.log'
                        cmd = "\"C:\\Program Files\\R\\R-3.5.1\\bin\\x64\\R.exe\" CMD BATCH --vanilla --slave --%s --%s --%s --%s --%s %s %s" % (model_version, model_type, input_file_name, data_path, model_output_path, r_script, log_file_name)
                        print "Processing for:" + file_name
                    else:
                        # Modify the JSON
                        with open(json_file, 'r') as content_file:
                            json_file_json = content_file.read()
        
                        # Replace Parameters in SQL
                        json_file_json = json_file_json.replace("@UID@", uid + '_' + json_file_name)
                        json_file_json = json_file_json.replace("@INPUT_FILE@", input_file_name)
                        json_file_json = json_file_json.replace("@INPUT_PATH@", data_path)
                        json_file_json = json_file_json.replace("@OUTPUT_PATH@", model_output_path)
                        json_file_json = json_file_json.replace("@COLLATERAL@", collateral)
                        json_file_json = json_file_json.replace("@PREPAY_MODEL_VERSION@", model_name)
                        json_file_json = json_file_json.replace("@PREPAY_MODEL_TYPE@", loan_type)
        
                        # Write JSON File
                        with open(json_infile_path, 'w+') as content_file:
                            content_file.write(json_file_json)
                        os.chdir(scale_path)
                        cmd = '%s %s %s' % (scale_bat, json_infile_path, json_outfile_path)
                        print "Processing for:" + file_name
                        print "cmd: " + cmd
        
                    # Begin Threading for Scale
                    threads.append(threading.Thread(target=process, args=(cmd, file_name)))
                    try:
                        threads[-1].start()
                        time.sleep(5)
                    except:
                        print "did not work"
                        time.sleep(5)

    for t in threads:
        t.join()

    print "Exiting generate_model_output_for_ginnie_loans"
    
    
def load_model_data_loan_GPL(run_ticker_list, factor_date, full_update, model):
    print "Starting load_model_data_loan_GPL"
    # Constants
    tableName = "PoolPrepayTracking" if full_update else "staging_PoolPrepayTracking"
    
    # Get Sybase IQ Database connection
    conn = pyodbc.connect('DSN=' + "Agency" + ';UID=' + "scale"+';PWD=' + "xaYc14rJ" + ';DATABASE=' + 'Agency' + ';Autostop=No')
    cursor = conn.cursor()

    for run_ticker in run_ticker_list:
    
        # Get ticker variables
        print run_ticker
        ticker_tuple = ticker_dict[run_ticker]
		
        model_tuple = model_dict[model]
        model_name = model_tuple[ticker_tuple['model']+'_name']
        model_version = model_tuple[ticker_tuple['model']+'_version']
        model_type = ticker_tuple['model_type']
        
        # Cleanup data in table
        agency = {
          'fannie': lambda : 'FNM',
          'freddie': lambda : 'FHL',
          'ginnie': lambda : 'GNM',
          'project_loan': lambda : 'GNM'
        }[run_ticker]()
        print "Cleaning Up Old Data"
        full_update_SQLStmt = "delete " + tableName + "  where modelId = '" + model_version + "' and issueId in (select issueId from   (select issueId,agency from fnm.Sec UNION ALL select issueId,agency from fhl.Sec UNION ALL select issueId,agency from gnm.Sec ) t where agency = '"+agency+"')"
        factor_update_SQLStmt = " delete staging_PoolPrepayTracking"
        cleanupSQLStmt = full_update_SQLStmt if full_update else factor_update_SQLStmt
        print (cleanupSQLStmt)
        cursor.execute(cleanupSQLStmt)

        # Get the load SQL Stmt
        symphony_tracking_path = 'S:/IT/Production/Scripts/python/Scale/SymphonyTracking/' + environment + '/'
        sql_path = os.path.join(symphony_tracking_path, 'sql/'+model)
        load_file = os.path.join(sql_path, "loadPoolPrepay.sql")
        with open(load_file, 'r') as sqlFile:
            loadSQLStmt = sqlFile.read()
        loadSQLStmt = loadSQLStmt.replace("@TABLE@", tableName)
        print loadSQLStmt

        # Get the path of files to be loaded in the Tracking table
        model_path = os.path.join(drive, 'tempExtract/PrepayPoolData/' + model_type + '/Model_' + model_version)
        factor_path = os.path.join(model_path, factor_date)
        load_path = os.path.join(factor_path, 'model_output')

        # Iterating over the list of files to be loaded to Tracking table
        # ignoring sample files
        for outFile in os.listdir(load_path):
            if outFile.endswith(".out") and outFile.find("sample") < 0:
                print "Loading file :" + outFile
                loadFileSQLStmt = loadSQLStmt.replace("@LOAD_FILE_PATH@", load_path+"/" + outFile)
                cursor.execute(loadFileSQLStmt)
                cursor.commit()
                # print loadSQLStmt

        # Update the loaded data in Tracking table with modelId
        #Overriding  modelId in case of project_loan for DB update ONLY
        if run_ticker == 'project_loan':
            model_version = '2.00'

        # Update the loaded data in Tracking table with modelId
        updateSQLStmt = "update " + tableName + "  set modelId = '" + model_version + "' where modelId is NULL"
        print updateSQLStmt
        cursor.execute(updateSQLStmt)

        # In case of factor_update insert data from staging to main table
        update_file = os.path.join(sql_path, "updatePoolPrepay.sql")
        if not (full_update):
            with open(update_file, 'r') as sqlFile:
               updateSQLStmt = sqlFile.read()
            print (updateSQLStmt)
            cursor.execute(updateSQLStmt)

        cursor.commit()
    print "Finish load_model_data_loan_GPL"

def load_model_data_loan(run_ticker_list, factor_date, full_update, model):
    print "Starting load_model_data_loan"
    
    # Constants
    tableName = "LoanPrepayTracking" if full_update else "staging_LoanPrepayTracking"
    pool_tableName = "PoolPrepayTracking" if full_update else "staging_PoolPrepayTracking"
    
    # Get Sybase IQ Database connection
    conn = pyodbc.connect('DSN=' + "Agency" + ';UID=' + "scale"+';PWD=' + "xaYc14rJ" + ';DATABASE=' + 'Agency' + ';Autostop=No')
    cursor = conn.cursor()

    for run_ticker in run_ticker_list:
    
        # Get ticker variable
        print run_ticker
        ticker_tuple = ticker_dict[run_ticker]

        model_tuple = model_dict[model]
        model_name = model_tuple[ticker_tuple['model']+'_name']
        model_version = model_tuple[ticker_tuple['model']+'_version']
        model_type = ticker_tuple['model_type']
        aggregation_sql_file = ticker_tuple['aggregation_sql']
        
        # Cleanup loan data in table
        agency = {
          'fannie': lambda : 'FNM',
          'freddie': lambda : 'FHL',
          'ginnie': lambda : 'GNM',
          'project_loan': lambda : 'GNM'
        }[run_ticker]()
        #print "Cleaning Up Old Loan Data"
        #full_update_SQLStmt = "delete " + tableName + "  where modelId = '" + model_version + "'  and issueId in (select issueId from (select issueId,agency from fnm.Sec UNION ALL select issueId,agency from fhl.Sec UNION ALL select issueId,agency from gnm.Sec ) t where agency = '"+agency+"')"
        full_update_SQLStmt_2 = "delete " + tableName + "  where modelId = '91' and issueId in (select issueId from (select issueId,agency from fnm.Sec UNION ALL select issueId,agency from fhl.Sec UNION ALL select issueId,agency from gnm.Sec ) t where agency = '"+agency+"')"
        #factor_update_SQLStmt = "delete staging_LoanPrepayTracking"
        factor_update_SQLStmt_2 = "commit"
        #cleanupSQLStmt = full_update_SQLStmt if full_update else factor_update_SQLStmt
        cleanupSQLStmt_2 = full_update_SQLStmt_2 if full_update else factor_update_SQLStmt_2
        #print (cleanupSQLStmt)
        print (cleanupSQLStmt_2)
        #cursor.execute(cleanupSQLStmt)
        #cursor.commit()
        cursor.execute(cleanupSQLStmt_2)
        cursor.commit()
		

        # Get the load SQL Stmt
        symphony_tracking_path = 'H:/SymphonyTracking/' + environment + '/'
        sql_path = os.path.join(symphony_tracking_path, 'sql/'+ model)
        load_file = os.path.join(sql_path, "loadLoanPrepay.sql")
        with open(load_file, 'r') as sqlFile:
            loadSQLStmt = sqlFile.read()
        loadSQLStmt = loadSQLStmt.replace("@TABLE@", tableName)
        print loadSQLStmt

        # Get the path of files to be loaded in the Tracking table
        model_path = os.path.join(drive, 'tempExtract/PrepayLoanData/' + model_type + '/Model_' + model_version)
        factor_path = os.path.join(model_path, factor_date)
        load_path = os.path.join(factor_path, 'model_output')

        # Iterating over the list of files to be loaded to Tracking table
        # ignoring sample files
        for outFile in os.listdir(load_path):
            if outFile.endswith(".out") and outFile.find("sample") < 0 and outFile.find(run_ticker) > 0:
                print "Loading file :" + outFile
                loadFileSQLStmt = loadSQLStmt.replace("@LOAD_FILE_PATH@", load_path+"/" + outFile)
                cursor.execute(loadFileSQLStmt)
                cursor.commit()
                # print loadSQLStmt

		# Update the loaded data in Tracking table with modelId
        updateSQLStmt = "update " + tableName + "  set modelId = '91' where modelId is NULL"
        print updateSQLStmt
        cursor.execute(updateSQLStmt)
		
		# Update the loaded data in Tracking table with poolId
        updateSQLStmt = "update " + tableName + " t  set issueId =  l.issueID from (select loanseqNum, issueID from fnm.PIV_Loan UNION ALL select loanseqNum, issueID from fhl.PIV_Loan UNION ALL select loanseqNum, issueID from gnm.PIV_Loan )l where l.loanseqNum = t.loanseqNum and t.issueId is NULL"
        print updateSQLStmt
        cursor.execute(updateSQLStmt)
		
		# Iterating over the list of files to be loaded to Tracking table
        # ignoring sample files
        #for outFile in os.listdir(load_path):
        #    if outFile.endswith(".out") and outFile.find("sample") < 0 and outFile.find(run_ticker) > 0:
        #        print "Loading file :" + outFile
        #        loadFileSQLStmt = loadSQLStmt.replace("@LOAD_FILE_PATH@", load_path+"/" + outFile)
        #        cursor.execute(loadFileSQLStmt)
        #        cursor.commit()
                # print loadSQLStmt

		# Update the loaded data in Tracking table with modelId = '99'
        #updateSQLStmt_99 = "update " + tableName + "  set modelId = '99' where modelId is NULL"
        #print updateSQLStmt_99
        #cursor.execute(updateSQLStmt_99)
		
		# Update the loaded data in Tracking table with poolId
        #updateSQLStmt = "update " + tableName + " t  set issueId =  l.issueID from (select loanseqNum, issueID from fnm.PIV_Loan UNION ALL select loanseqNum, issueID from fhl.PIV_Loan UNION ALL select loanseqNum, issueID from gnm.PIV_Loan )l where l.loanseqNum = t.loanseqNum and t.issueId is NULL"
        #print updateSQLStmt
        #cursor.execute(updateSQLStmt)
		
        # aggregate loan level result to pool level
        #aggregation_file = os.path.join(sql_path, aggregation_sql_file)
        #with open(aggregation_file, 'r') as sqlFile:
        #       aggregationSQLStmt = sqlFile.read()
        #aggregationSQLStmt = aggregationSQLStmt.replace("@POOL_TABLE@", pool_tableName)
        #aggregationSQLStmt = aggregationSQLStmt.replace("@LOAN_TABLE@", tableName)
        #aggregationSQLStmt = aggregationSQLStmt.replace("@MODEL_VERSION@", model_version)
        #print aggregationSQLStmt
        #cursor.execute(aggregationSQLStmt)
        #cursor.commit()

        #updatePoolSQLStmt = "update " + pool_tableName + "  set modelId = '" + model_version + "' where modelId is NULL"
        #print updatePoolSQLStmt
        #cursor.execute(updatePoolSQLStmt)
        
        # In case of factor_update insert data from staging to main table
        update_file = os.path.join(sql_path, "updateLoanPrepay.sql")
        if not (full_update):
            with open(update_file, 'r') as sqlFile:
               updateSQLStmt = sqlFile.read()
            print (updateSQLStmt)
            cursor.execute(updateSQLStmt)

        cursor.commit()
    print "Finish load_model_data_loan"

def split_large_files(factor_date, model, file_size):
    run_ticker_list = list(ticker_list)
	
    # Function for Threading
    def process(file_name, chunksize):    
        print("SpitinH: %s" %(file_name))
        partnum = 0
        with open(file_name) as fin:
            while 1:
                chunk = fin.readlines(chunksize) 
                if not chunk: break
                partnum  = partnum + 1
                filename = "%s%s_%d.csv"%(model_output_path, file_name.replace('.csv', ''), partnum)
                fileobj  = open(filename, 'wb')
                fileobj.write(''.join(chunk))
                fileobj.close()
            fin.close()	
                
		# Release Semaphore
        split_semaphore.release()
    
    # Thread control
    threads = []
    max_connections = split_threads
    split_semaphore = threading.BoundedSemaphore(value=max_connections)
    
    kilobytes = 1024
    megabytes = kilobytes * 1000
    chunksize = int(file_size * megabytes)
    print("spiting large data files")
    
    for ticker in run_ticker_list:

        # Get the Ticker Tuple
        ticker_tuple = ticker_dict[ticker]
		
        model_tuple = model_dict[model]
        model_name = model_tuple[ticker_tuple['model']+'_name']
        model_version = model_tuple[ticker_tuple['model']+'_version']
        model_type = ticker_tuple['model_type']
 
        # Constants
        model_path = os.path.join(drive, 'tempExtract/PrepayLoanData/' + model_type + '/Model_' + model_version)
        factor_path = model_path + '/' + factor_date
        data_path = factor_path + '/' + 'model_input/'
        model_output_path = factor_path + '/' + 'model_input_split/'

        # Create the output folder
        if not os.path.exists(model_output_path):
            os.makedirs(model_output_path)
		
        # Search the Directory for Matching Files
        file_list = [f for f in os.listdir(data_path) if os.path.isfile(os.path.join(data_path, f)) and ticker in f]
        os.chdir(data_path)
        for file_name in file_list:
            # Begin Threading for Scale
			# Aquire Semaphore
            split_semaphore.acquire()
            
            # excuting thread
            t = threading.Thread(target=process, args=(file_name, chunksize))
            threads.append(t)			
			
            try:
                threads[-1].start()
                time.sleep(2)
            except:
                print "did not work"
                time.sleep(5)
    
    for t in threads:
        t.join()
            
    
def usage(function_name):
    print("Usage 1: %s --factor_update --model --factor_date 20161201" % function_name)
    print("Usage 2: %s --new_model --model --factor_date 20161201" % function_name)
    print("Usage 3: %s --new_model --model --factor_date 20161201 -R" % function_name)
    print("Usage 4: %s --new_model --model --factor_date 20161201 -S" % function_name)

def main(argv):

    # Version
    global environment
    environment = 'dev'

    # Latest Year
    global latest_year
    dt_now = datetime.date.today()
    latest_year = dt_now.year

    # Globals
    global drive
    # drive = 'S:/IT/TMP/'
    drive = 'H:/'
    
    global split_threads
    split_threads = 25
    split_file_size = 500    # megabytes

    global scale_threads
    scale_threads = 10 # adjust based on how much CPU you want to allocate to Scale (1 = lowest, 32 = highest)

    global IQ_threads
    IQ_threads = 4 # adjust based on how many tickers you are running in ticker_list
	
    global model_scale_path # To store model version #s
    model_scale_path = {'4.60': {'baton_model_scale_path': 'S:\\IT\\Production\\ScaleMQ\\release\\5.57\\Scale_v2.02',
                           'gnmandolin_model_scale_path': 'S:\\IT\\Production\\ScaleMQ\\release\\5.57\\Scale_v2.02',
                           'glockenspiel_model_scale_path': 'S:\\IT\\Production\\ScaleMQ\\release\\5.54_dev\\\Scale_v2.02'},
                   '4.70': {'baton_model_scale_path': 'S:\\IT\\Production\\ScaleMQ\\release\\5.57\\Scale_v2.02',
                           'gnmandolin_model_scale_path': 'S:\\IT\\Production\\ScaleMQ\\release\\5.57\\Scale_v2.02',
                           'glockenspiel_model_scale_path': 'S:\\IT\\Production\\ScaleMQ\\release\\5.54_dev\\\Scale_v2.02'},
                   '4.50': {'baton_model_scale_path': 'S:\\IT\\Production\\ScaleMQ\\release\\5.57\\Scale_v2.02',
                           'gnmandolin_model_scale_path': 'S:\\IT\\Production\\ScaleMQ\\release\\5.57\\Scale_v2.02',
                           'glockenspiel_model_scale_path': 'S:\\IT\\Production\\ScaleMQ\\release\\5.54_dev\\\Scale_v2.02'}
                   }
    global model_dict # To store  executable for a model
    model_dict = {'4.60': {'baton_model_name': 'Baton_v4.60',
                           'baton_model_version': '4.60',
                           'gnmandolin_model_name': 'Gnmandolin_v4.60',
                           'gnmandolin_model_version': '4.60',
                           'glockenspiel_model_name': 'Glockenspiel_v2.10',
                           'glockenspiel_model_version': '2.10'},
                   '4.70': {'baton_model_name': 'Baton_v4.70',
                           'baton_model_version': '4.70',
                           'gnmandolin_model_name': 'Gnmandolin_v4.70',
                           'gnmandolin_model_version': '4.70',
                           'glockenspiel_model_name': 'Glockenspiel_v2.10',
                           'glockenspiel_model_version': '2.10'},
                   '4.50': {'baton_model_name': 'Baton_v4.50',
                           'baton_model_version': '4.50',
                           'gnmandolin_model_name': 'Gnmandolin_v4.50',
                           'gnmandolin_model_version': '4.50',
                           'glockenspiel_model_name': 'Glockenspiel_v2.10',
                           'glockenspiel_model_version': '2.10'}
                   }
    global ticker_dict # adjust model numbers
    ticker_dict = {'ginnie': {'model':'gnmandolin_model',
	                          'model_type': 'GINNIE',
	                          'r_path': 'H:\\AgencyPrepayment\\Baton2\\batonutil\\',
                              'ticker_sql': 'ginnie_tickers.sql',
                              'hpa_sql': 'hpa_data.sql',
                              'media_sql': 'media_effect_data.sql',
                              'credit_sql': 'credit_availability_data.sql',
                              'data_sql': 'ginnie_loan_data.sql',
                              'extract_sql': 'ginnie_data_extract.sql',
                              'loan_type_list': ['FHA', 'VA', 'RHS', 'PIH'],
							  'aggregation_sql':'ginnie_loan_aggregation.sql',
                              'vintage_list': [2002, 2003, 2006, 2008, 2009, 2010, 2011, 2012, 2013, 2014, 2015, 2016, 2017, 2018, latest_year]},
                   'fannie': {'model':'baton_model',
	                          'model_type': 'CONVENTIONAL',
	                          'r_path': 'H:\\AgencyPrepayment\\Baton2\\batonutil\\',
                              'ticker_sql': 'fannie_tickers.sql',
                              'hpa_sql': 'hpa_data.sql',
                              'media_sql': 'media_effect_data.sql',
                              'credit_sql': 'credit_availability_data.sql',
                              'data_sql': 'fannie_loan_data.sql',
                              'extract_sql': 'conventional_loan_data_extract.sql',
							  'aggregation_sql':'fannie_loan_aggregation.sql',
                              'vintage_list': [1950, 2009, 2010, 2011, 2012, 2013, 2014, 2015, 2016, 2017, 2018, latest_year]},
                   'freddie': {'model':'baton_model',
	                          'model_type': 'CONVENTIONAL',
	                          'r_path': 'H:\\AgencyPrepayment\\Baton2\\batonutil\\',
                              'ticker_sql': 'freddie_tickers.sql',
                              'hpa_sql': 'hpa_data.sql',
                              'media_sql': 'media_effect_data.sql',
                              'credit_sql': 'credit_availability_data.sql',
                              'data_sql': 'freddie_loan_data.sql',
                              'extract_sql': 'conventional_loan_data_extract.sql',
							  'aggregation_sql':'freddie_loan_aggregation.sql',
                              'vintage_list': [1950, 2009, 2010, 2011, 2012, 2013, 2014, 2015, 2016, 2017, 2018, latest_year]},
                   'project_loan': {'model':'glockenspiel_model',
	                                'model_type': 'PROJECT_LOAN',
	                                'r_path': 'S:\\IT\\Dev\\AgencyPrepayment\\Glockenspiel\\v'  + '\\',
                                    'ticker_sql': 'project_loan_tickers.sql',
                                    'media_sql': 'surge_index_data.sql',
    #                                'data_sql': 'project_loan_pool_data_Intex.sql',
                                    'extract_sql': 'project_loan_data_extract_new.sql',
                                    'vintage_list': [1950, latest_year]}
                   }

    global ticker_list # adjust to run all or only specific tickers
    #ticker_list = ['ginnie', 'fannie', 'freddie', 'project_loan']
    #ticker_list = ['ginnie', 'fannie', 'freddie']
    #ticker_list = ['fannie', 'freddie']
    #ticker_list = ['ginnie']
    #ticker_list = ['fannie']
    ticker_list = ['freddie']
    #ticker_list = ['project_loan']
    

    # global r_baton_path
    # r_baton_path = 'C:\\PIV\\PIV-it-dev\\trunk\\Research\\AgencyPrepayment\\Baton2\\batonutil\\'
    # r_baton_path = 'S:\\IT\\Dev\\AgencyPrepayment\\Baton\\v' + baton_model_version + '\\batonutil\\'
    #
    # global r_glockenspiel_path
    # #r_glockenspiel_path = 'C:\\PIV\\PIV-it-dev\\trunk\\Research\\ProjectLoan\\PrepayModel\\Glockenspiel\\'
    # r_glockenspiel_path = 'S:\\IT\\Dev\\AgencyPrepayment\\Glockenspiel\\v' + glockenspiel_model_version + '\\'

    # global r_tieout_file
    # r_tieout_file = "GenSymphonyTracking.R"

    # Get the User Options for the Run
    full_update = True
    use_r_engine = False
    sample_only = False
    factor_date = ""
    model = ""
    opts, args = getopt.getopt(argv[1:], "hSR", ['factor_update', 'new_model', 'model=', 'factor_date='])
    if len(opts) < 2:
        usage(argv[0])
        exit(-1)
    for opt, arg in opts:
        if opt == '--factor_update':
            full_update = False
        if opt == '--new_model':
            full_update = True
        if opt == '--model':
            model = arg
        if opt == '--factor_date':
            factor_date = arg
        if opt == '-S':
            sample_only = True
        if opt == '-R':
            use_r_engine = True
        if opt == '-h':
            usage(argv[0])

    # Step 1
    # Generate the Pool Collateral data
    generate_data(full_update, factor_date, sample_only, model)
    split_large_files(factor_date, model, split_file_size)
	
    # Step 2
    # Run Scale for each data file
    generate_model_output(factor_date, use_r_engine, model)

    # Step 3
    # Load the model output into IQ
    load_model_data(factor_date, full_update, model)

if __name__ == "__main__":
    main(sys.argv[0:])

