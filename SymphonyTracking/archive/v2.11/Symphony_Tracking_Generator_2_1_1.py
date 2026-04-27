'''
Symphony_Tracking_Generator.py
This is the program to create and store model tracking data for use in Symphony

Steps:
1) Run SQL queries to create files with pool collateral data
2) Run Scale [SYMPHONY_TRACKING_REQUEST] for each data file
3) Load the model output files from Scale into IQ

This procedure should be run for each factor date (9th business day),
or for a new model release

v2.10 Notes
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


def generate_pool_data(full_update, model, factor_date, sample_only):

    # Function for Threading
    def process(ticker):

        print "Processing:" + ticker
        # Acquire Semaphore
        pool_semaphore.acquire()

        # Constants
        dt_now = datetime.date.today()
        latest_year = dt_now.year
        factor_date_dt = datetime.datetime.strptime(factor_date, '%Y%m%d')
        prepay_date_dt = (factor_date_dt - datetime.timedelta(1)).replace(day=1)
        prepay_date = datetime.date.strftime(prepay_date_dt, '%Y%m%d')
        symphony_tracking_path = 'S:/IT/Production/Scripts/python/SymphonyTracking/v' + model + '/'
        sql_path = os.path.join(symphony_tracking_path, 'sql')
        ticker_dict = {'ginnie': ('ginnie_tickers.sql',
                                  'hpa_data.sql',
                                  'media_effect_data.sql',
                                  'credit_availability_data.sql',
                                  'ginnie_pool_data.sql',
                                  'ginnie_data_extract.sql',
                                  [1950, 1985, 1986, 1988, 1991, 1993, 1996, 1999, 2004, latest_year]),
                       'fannie': ('fannie_tickers.sql',
                                  'hpa_data.sql',
                                  'media_effect_data.sql',
                                  'credit_availability_data.sql',
                                  'fannie_pool_data.sql',
                                  'conventional_data_extract.sql',
                                  [1950, 1989, 1991, 1992, 1993, 1994, 1996, 1997, 1998, 1999, 2000, 2001, 2002,
                                   2003, 2004, 2006, 2008, latest_year]),
                       'freddie': ('freddie_tickers.sql',
                                   'hpa_data.sql',
                                   'media_effect_data.sql',
                                   'credit_availability_data.sql',
                                   'freddie_pool_data.sql',
                                   'conventional_data_extract.sql',
                                   [1950, 1989, 1991, 1992, 1993, 1994, 1996, 1997, 1998, 1999, 2000, 2001, 2002,
                                    2003, 2004, 2006, 2008, latest_year])
                       }

        model_path = os.path.join(drive, 'tempExtract/PrepayPoolData/Model_' + model)
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

        # Get the Ticker Tuple
        ticker_tuple = ticker_dict[ticker]
        ticker_sql_file = ticker_tuple[0]
        hpa_sql_file = ticker_tuple[1]
        media_effect_sql_file = ticker_tuple[2]
        mcai_sql_file = ticker_tuple[3]
        data_sql_file = ticker_tuple[4]
        extract_sql_file = ticker_tuple[5]
        vintage_list = ticker_tuple[6] if full_update else [1950, latest_year]

        # Step 0: Setup the SQL
        full_sql = ''
        sql_chunk = ''
        full_sql_file = os.path.join(sql_output_path, ticker + '_' + 'prepay_model_data_full.sql')

        # Step 1: Add the Ticker SQL
        ticker_sql_file = os.path.join(sql_path, ticker_sql_file)
        print "Ticker:" + ticker + "--->" + ticker_sql_file + "   ----- TICKER SQL FILE"
        full_sql += process_sql_file(ticker_sql_file, cursor)

        # Step 2: Add the HPA Series
        hpa_sql_file = os.path.join(sql_path, hpa_sql_file)
        print "Ticker:" + ticker + "--->" + hpa_sql_file + "   ----- HPA SQL FILE"
        full_sql += process_sql_file(hpa_sql_file, cursor)

        # Step 3: Add the Media Effect Series
        media_effect_sql_file = os.path.join(sql_path, media_effect_sql_file)
        print "Ticker:" + ticker + "--->" + media_effect_sql_file + "   ----- MEDIA EFFECT SQL FILE"
        full_sql += process_sql_file(media_effect_sql_file, cursor)

        # Step 4: Add the Credit Availability Series
        mcai_sql_file = os.path.join(sql_path, mcai_sql_file)
        print "Ticker:" + ticker + "--->" + mcai_sql_file + "   ----- MCAI SQL FILE"
        full_sql += process_sql_file(mcai_sql_file, cursor)

        # Step 5: Add the Data SQL
        data_sql_file = os.path.join(sql_path, data_sql_file)
        print "Ticker:" + ticker + "--->" + data_sql_file + "   ----- DATA SQL FILE"
        asof_where = " AND sph.asOf <= '%s' " % prepay_date if full_update else " AND sph.asOf = '%s' " % prepay_date
        with open(data_sql_file, 'r') as inp:
            file_contents = inp.read().replace("@ASOF_WHERE@", asof_where)
        inp.close()
        full_sql += process_sql_contents(file_contents, cursor)

        # Step 6: Add the Vintage Extract
        if not sample_only:
            print "Processing for Ticker For Vintages: " + ticker + " Started"
            extract_file = os.path.join(sql_path, extract_sql_file)
            for ii in range(len(vintage_list) - 1):
                vintage_low = vintage_list[ii]
                vintage_high = vintage_list[ii+1]
                extract_file_path = extract_path + '/' + 'PrepayPoolData_' + ticker + '_' + str(vintage_high) + '.csv'
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

        # Step 7: Add the Sample Extract (Sample for more pools)
        print "Processing for Ticker For Sample(Sample for more pools):" + ticker + " Started"
        extract_file = os.path.join(sql_path, extract_sql_file)
        extract_file_path = extract_path + '/' + 'PrepayPoolData_' + ticker + '_sample.csv'
        vintage_where = ' AND 1=1 '
        sample_join = ' JOIN scale.SampleIssueIds si ON sph.issueId = si.issueId '
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
        
        print "Processing for Ticker For Sample(Sample for more pools):" + ticker + " Completed"

        # Step 8: Add the Sample Extract (Sample for Scale tie-out)
        if not sample_only:
            print "Processing for Ticker For Sample(Sample for Scale tie-out):" + ticker + " Started"
            extract_file = os.path.join(sql_path, extract_sql_file)
            extract_file_path = extract_path + '/' + 'PrepayPoolData_' + ticker + 'Scale_Tieout_sample.csv'
            vintage_where = ' AND 1=1 '
            sample_join = ' JOIN report.Scale_V2_conv_samples_id si ON sph.issueId = si.issueId '
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

            print "Processing for Ticker For Sample(Sample for Scale tie-out):" + ticker + " Completed"

        # Step 9: Exit
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
    for run_ticker in ticker_list:
        threads.append(threading.Thread(target=process, args=(run_ticker,)))
        time.sleep(2)
        try:
            threads[-1].start()
        except:
            time.sleep(5)

    for t in threads:
        t.join()

    print "Exiting generate_pool_data"


def generate_model_output(model, factor_date, use_r_engine):

    # Function for Threading
    def process(scale_cmd):

        # Aquire Semaphore
        pool_semaphore.acquire()

        # Run the System Command to Start Scale
        print "starting..."
        os.system(scale_cmd)

        # Release Semaphore
        pool_semaphore.release()

    # Constants
    model_path = os.path.join(drive, 'tempExtract/PrepayPoolData/Model_' + model)
    factor_path = model_path + '/' + factor_date
    data_path = factor_path + '/' + 'model_input/'
    model_output_path = factor_path + '/' + 'model_output/'
    json_input_path = os.path.join(factor_path, 'json_input')

    symphony_tracking_path = 'S:/IT/Production/Scripts/python/SymphonyTracking/v' + model + '/'
    json_path = os.path.join(symphony_tracking_path, 'json')
    json_file = os.path.join(json_path, 'symphony_tracking.json')
    scale_bat = os.path.join(scale_path, 'RunScale.bat')
    uid = 'symphony_tracking'
    collateral = 'POOL'
    model_version = 'Baton_v' + model

    # Create the output folder
    if not os.path.exists(model_output_path):
        os.makedirs(model_output_path)
    if not os.path.exists(json_input_path):
        os.makedirs(json_input_path)

    # Ticker Dictionary
    ticker_dict = {'ginnie': ('GINNIE',),
                   'fannie': ('CONVENTIONAL',),
                   'freddie': ('CONVENTIONAL',)
                   }

    # Run Scale on each data file
    # One Thread for File
    threads = []
    max_connections = scale_threads
    pool_semaphore = threading.BoundedSemaphore(value=max_connections)

    for ticker in ticker_list:
        # Get the Ticker Tuple
        ticker_tuple = ticker_dict[ticker]
        model_type = ticker_tuple[0]

        # Search the Directory for Matching Files
        file_list = [f for f in os.listdir(data_path) if os.path.isfile(os.path.join(data_path, f)) and ticker in f]
        for file_name in file_list:
            json_file_name = file_name.replace('.csv', '')
            json_infile_name = json_file_name + '_in.json'
            json_outfile_name = json_file_name + '_out.json'
            json_infile_path = os.path.join(json_input_path, json_infile_name)
            json_outfile_path = os.path.join(json_input_path, json_outfile_name)
            input_file_name = file_name

            if use_r_engine:
                os.chdir(r_baton_path)
                r_script = os.path.join(r_baton_path, "prepay_model_tieout_v2.11.R")
                log_file_name = file_name + '.log'
                cmd = "\"C:\\Program Files\\R\\R-3.1.3\\bin\\x64\\R.exe\" CMD BATCH --vanilla --slave --%s --%s --%s --%s --%s %s %s" % (model_version, model_type, input_file_name, data_path, model_output_path, r_script, log_file_name)
                print "Processing for:" + file_name
                print "cmd: " + cmd
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
                json_file_json = json_file_json.replace("@PREPAY_MODEL_VERSION@", model_version)
                json_file_json = json_file_json.replace("@PREPAY_MODEL_TYPE@", model_type)

                # Write JSON File
                with open(json_infile_path, 'w+') as content_file:
                    content_file.write(json_file_json)
                os.chdir(scale_path)
                cmd = '%s %s %s' % (scale_bat, json_infile_path, json_outfile_path)
                print "Processing for:" + file_name
                print "cmd: " + cmd

            # Begin Threading for Scale
            threads.append(threading.Thread(target=process, args=(cmd,)))
            try:
                threads[-1].start()
                time.sleep(2)
            except:
                print "did not work"
                time.sleep(5)

    for t in threads:
        t.join()

    print "Exiting generate_model_output"


def load_model_data(model, factor_date, full_update):

    # Constants
    tableName = "PoolPrepayTracking"  if full_update else  "staging_PoolPrepayTracking"
    
    # Get Sybase IQ Database connection
    conn = pyodbc.connect('DSN=' + "Agency" + ';UID=' + "scale"+';PWD=' + "xaYc14rJ" + ';DATABASE=' + 'Agency' + ';Autostop=No')
    cursor = conn.cursor()

    # Cleanup data in table
    print "Cleaning Up Old Data"
    cleanupSQLStmt = "delete " + tableName + "  where modelId = '" + model + "'" if full_update else " delete staging_PoolPrepayTracking"
    print (cleanupSQLStmt)
    cursor.execute(cleanupSQLStmt)

    # Get the load SQL Stmt
    symphony_tracking_path = 'S:/IT/Production/Scripts/python/SymphonyTracking/v' + model + '/'
    sql_path = os.path.join(symphony_tracking_path, 'sql')
    load_file = os.path.join(sql_path, "loadPoolPrepay.sql")
    with open(load_file, 'r') as sqlFile:
        loadSQLStmt = sqlFile.read()
    loadSQLStmt = loadSQLStmt.replace("@TABLE@", tableName)
    print loadSQLStmt

    # Get the path of files to be loaded in the Tracking table
    model_path = os.path.join(drive, 'tempExtract/PrepayPoolData/Model_' + model)
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
    updateSQLStmt = "update " + tableName + "  set modelId = '" + model + "' where modelId is NULL"
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
    

def usage(function_name):
    print("Usage 1: %s --factor_update --model 2.10 --factor_date 20160701" % function_name)
    print("Usage 2: %s --new_model --model 2.10 --factor_date 20160701" % function_name)
    print("Usage 3: %s --new_model --model 2.10 --factor_date 20160701 -R" % function_name)
    print("Usage 4: %s --new_model --model 2.10 --factor_date 20160701 -S" % function_name)


def main(argv):

    # Globals
    global drive
    drive = 'S:/IT/TMP/'
    #drive = 'g:/'

    global scale_threads
    scale_threads = 5 # adjust based on how much CPU you want to allocate to Scale (1 = lowest, 6 = highest)

    global IQ_threads
    IQ_threads = 3 # adjust based on how many tickers you are running in ticker_list

    global ticker_list
    ticker_list = ['ginnie', 'fannie', 'freddie']
    #ticker_list = ['fannie', 'freddie']
    #ticker_list = ['ginnie']
    #ticker_list = ['fannie']
    #ticker_list = ['freddie']
    
    global scale_path
    #scale_path = 'S:\\IT\\Production\\ScaleMQ\\release\\4.08\\'
    scale_path = 'S:\\IT\\Dev\\ScaleMQ\\release_bobby\\'

    global r_baton_path
    #r_baton_path = 'C:\\dev\\PIV-it-dev\\trunk\\Research\\AgencyPrepayment\\Baton\\'
    #r_baton_path = 'C:\\PIV\\PIV-it-dev\\trunk\\Research\\AgencyPrepayment\\Baton\\'
    r_baton_path = 'S:\\IT\\Dev\\AgencyPrepayment\\Baton\\'

    # Get the User Options for the Run
    full_update = True
    use_r_engine = False
    sample_only = False
    model = ""
    factor_date = ""
    opts, args = getopt.getopt(argv[1:], "hSR", ['factor_update', 'new_model', 'model=', 'factor_date='])
    if len(opts) < 3:
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
    generate_pool_data(full_update, model, factor_date, sample_only)

    # Step 2
    # Run Scale for each data file
    generate_model_output(model, factor_date, use_r_engine)

    # Step 3
    # Load the model output into IQ
    #load_model_data(model, factor_date, full_update)

if __name__ == "__main__":
    main(sys.argv[0:])

