'''
Symphony_Tracking_Generator.py
This is the program to create and store model tracking data for use in Symphony

Steps:
1) Run SQL queries to create files with pool collateral data
2) Run Scale [SYMPHONY_TRACKING_REQUEST] for each data file
3) Load the model output files from Scale into IQ

This procedure should be run for each factor date (9th business day),
or for a new model release

v1.0 Notes
-

Options
--model
--factor_date
--

Usage
1) 9th business day factor data update
Symphony_Tracking_Generator.py --factor_update --model 1.00 --factor_date 20160501
2) New model tracking
Symphony_Tracking_Generator.py --new_model --model 2.00 --factor_date 20160501

'''

import sys
import pyodbc
import os
import getopt
import datetime
import threading
import time
import re

def generate_pool_data(full_update, model, factor_date):

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
                                  'ginnie_pool_data.sql',
                                  'ginnie_data_extract.sql',
                                  [1950, 1985, 1986, 1988, 1991, 1993, 1996, 1999, 2004, latest_year]),
                       'conventional': ('conventional_tickers.sql',
                                        'conventional_pool_data.sql',
                                        'conventional_data_extract.sql',
                                        [1950, 1989, 1991, 1992, 1993, 1994, 1996, 1997, 1998, 1999, 2000, 2001, 2002,
                                         2003, 2004, 2006, 2008, latest_year])
                       }

        #sample_sql_file = os.path.join(sql_path, 'sample_data.sql')
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
        conn = pyodbc.connect('DSN=' + "ScaleAgencyPool" + ';UID=' + "report"+';PWD=' + "gm4SJDw4" + ';DATABASE=' + 'Agency' + ';Autostop=No')
        cursor = conn.cursor()

        # Get the Ticker Tuple
        ticker_tuple = ticker_dict[ticker]
        ticker_sql_file = ticker_tuple[0]
        data_sql_file = ticker_tuple[1]
        extract_sql_file = ticker_tuple[2]
        vintage_list = ticker_tuple[3] if full_update else [1950, latest_year]

        # Step 0: Setup the SQL
        full_sql = ''
        sql_chunk = ''
        full_sql_file = os.path.join(sql_output_path, ticker + '_' + 'prepay_model_data_full.sql')

        # Step 1: Add the Ticker SQL
        ticker_sql_file = os.path.join(sql_path, ticker_sql_file)
        print "Ticker:" + ticker + "--->" + ticker_sql_file + "   ----- TICKER SQL FILE"
        with open(ticker_sql_file, 'r') as inp:
            for line in inp:
                if re.search(";", line):
                    sql_chunk += line
                    full_sql += line
                    cursor.execute(sql_chunk)
                    sql_chunk = ''
                else:
                    sql_chunk += line
                    full_sql += line
        inp.close()

        # Step 2: Add the Data SQL
        data_sql_file = os.path.join(sql_path, data_sql_file)
        print "Ticker:" + ticker + "--->" + data_sql_file + "   ----- DATA SQL FILE"
        with open(data_sql_file, 'r') as inp:
            for line in inp:
                if re.search(";", line):
                    sql_chunk += line
                    full_sql += line
                    print("----BEG------")
                    print(sql_chunk)
                    print("-----END-----")
                    cursor.execute(sql_chunk)
                    sql_chunk = ''
                else:
                    sql_chunk += line
                    full_sql += line
        inp.close()

        # Check to Ensure we Have Data
        cursor.execute("select count(1) as cnt from #refinance_pools p JOIN #refinanceable rfp ON p.asOfDate = rfp.asOfDate")
        rows = cursor.fetchall()
        for row in rows:
            print(row.cnt)

        # Step 3: Add the Vintage Extract
        extract_file = os.path.join(sql_path, extract_sql_file)
        sql_chunk = ''
        asof_where = " AND p.asOfDate <= '%s' " % prepay_date if full_update else " AND p.asOfDate = '%s' " % prepay_date
        for ii in range(len(vintage_list) - 1):
            vintage_low = vintage_list[ii]
            vintage_high = vintage_list[ii+1]
            extract_file_path = extract_path + '/' + 'PrepayPoolData_' + ticker + '_' + str(vintage_high) + '.csv'
            vintage_where = ' AND vintage > %s AND vintage <= %s ' % (vintage_low, vintage_high)
            print "Ticker:" + ticker + "--->" + extract_file + "   ----- EXTRACT SQL FILE"
            with open(extract_file, 'r') as inp:
                for line in inp:
                    # Replace Parameters in SQL
                    line = line.replace("@EXTRACT_FILE_PATH@", extract_file_path)
                    line = line.replace("@VINTAGE_WHERE@", vintage_where)
                    line = line.replace("@ASOF_WHERE@", asof_where)
                    if re.search(";", line):
                        sql_chunk += line
                        full_sql += line
                        print("----BEG------")
                        print(sql_chunk)
                        print("-----END-----")
                        cursor.execute(sql_chunk)
                        sql_chunk = ''
                    else:
                        sql_chunk += line
                        full_sql += line
            inp.close()
            rows = cursor.fetchall()  # must have this line for extraction to work correctly
            cursor.execute("set temporary option temp_extract_name1=''")
            full_sql += "set temporary option temp_extract_name1=''"

        print "Processing for Ticker:" + ticker + " Completed"

        # Step 4: Add the Sample Extract
        print "Processing for Ticker For Sample:" + ticker + " Started"
        sql_chunk = ''

        extract_file_path = extract_path + '/' + 'PrepayPoolData_' + ticker + '_sample.csv'
        vintage_where = ' AND 1=1 '
        #sample_join = ' JOIN #refinance_pools_sample ps ON p.issueId = ps.issueId '
        sample_join = ' JOIN scale.SampleIssueIds ps ON p.issueId = ps.issueId '
        print extract_file_path
        with open(extract_file, 'r') as inp:
            for line in inp:
                # Replace Parameters in SQL
                line = line.replace("@EXTRACT_FILE_PATH@", extract_file_path)
                line = line.replace("@VINTAGE_WHERE@", vintage_where)
                line = line.replace("--@SAMPLE_JOIN@", sample_join)
                line = line.replace("@ASOF_WHERE@", asof_where)
                if re.search(";", line):
                    sql_chunk += line
                    full_sql += line
                    print("----BEG------")
                    print(sql_chunk)
                    print("-----END-----")
                    cursor.execute(sql_chunk)
                    sql_chunk = ''
                else:
                    sql_chunk += line
                    full_sql += line
        inp.close()
        rows = cursor.fetchall()  # must have this line for extraction to work correctly
        cursor.execute("set temporary option temp_extract_name1=''")
        full_sql += "set temporary option temp_extract_name1=''"
        print "Processing for Ticker For Sample:" + ticker + " Completed"

        # Step 5: Exit
        cursor.commit()
        with open(full_sql_file, 'w+') as content_file:
            content_file.write(full_sql)

        # Close the Connection
        conn.close()

        # Release Semaphore
        pool_semaphore.release()

    # Run SQL for each Ticker
    # One Thread for each Ticker
    ticker_list = ['ginnie', 'conventional']
    #ticker_list = ['conventional']
    threads = []
    max_connections = 2
    pool_semaphore = threading.BoundedSemaphore(value=max_connections)

    # Loop over Tickers
    for run_ticker in ticker_list:
        threads.append(threading.Thread(target=process, args=(run_ticker,)))
        not_started = True
        time.sleep(2)
        while not_started:
            try:
                threads[-1].start()
                not_started = False
            except:
                time.sleep(5)


def generate_model_output(model, factor_date):

    # Function for Threading
    def process(scale_cmd):

        # Aquire Semaphore
        pool_semaphore.acquire()

        # Run the System Command to Start Scale
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
    #scale_path = 'S:/IT/Dev/ScaleMQ/release/'
    scale_path = 'S:/IT/Production/ScaleMQ/release/4.08/'
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
                   'conventional': ('CONVENTIONAL',),
                   }

    # Run Scale on each data file
    # One Thread for File
    threads = []
    max_connections = 4
    pool_semaphore = threading.BoundedSemaphore(value=max_connections)

    for ticker, ticker_tuple in ticker_dict.iteritems():
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

            # Begin Threading for Scale
            threads.append(threading.Thread(target=process, args=(cmd,)))
            not_started = True
            while not_started:
                try:
                    threads[-1].start()
                    not_started = False
                except:
                    time.sleep(1)


def load_model_data(model, factor_date, full_update):
    tableName = "PoolPrepayTracking"  if full_update else  "staging_PoolPrepayTracking"
    # Get Sybase IQ Database connection
    conn = pyodbc.connect('DSN=' + "Agency" + ';UID=' + "scale"+';PWD=' + "xaYc14rJ" + ';DATABASE=' + 'Agency' + ';Autostop=No')
    cursor = conn.cursor()

    # Cleanup data in table
    cleanupSQLStmt = "delete " + tableName + "  where modelId = '" + model + "'" if full_update else " delete  staging_PoolPrepayTracking"
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
    print (updateSQLStmt)
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
    print("Usage 1: %s --factor_update --model 1.00 --factor_date 20160501" % function_name)
    print("Usage 2: %s --new_model --model 2.00 --factor_date 20160501" % function_name)


def main(argv):

    # Global
    global drive
    #drive = 'S:/IT/TMP/'
    drive = 'g:/'

    # Get the User Options for the Run
    full_update = True
    model = ""
    factor_date = ""
    opts, args = getopt.getopt(argv[1:], 'h', ['factor_update', 'new_model', 'model=', 'factor_date='])
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
        if opt == '-h':
            usage(argv[0])

    # Step 1
    # Generate the Pool Collateral data
    generate_pool_data(full_update, model, factor_date)

    # Step 2
    # Run Scale for each data file
    generate_model_output(model, factor_date)

    # Step 3
    # Load the model output into IQ
    load_model_data(model, factor_date, full_update)

if __name__ == "__main__":
    main(sys.argv[0:])

