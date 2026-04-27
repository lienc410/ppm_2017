import random
import sys
import datetime
import os
from datetime import datetime
import EmailUtil


def main(argv):
    #Input user argument Year, Month, Date
    date_str = argv[1] + argv[2] + argv[3];
    #Setting Directory for target file
    try:
        filepath_n = os.path.join('S:', 'IT', 'Dev', 'Scale', 'CreditAvailabilityModel', date_str, 'mcai_2.0.txt')
        file_CAM_N = open(filepath_n, 'r')
    except:
        print("File not Found!")

    #Converting the string input into datetime
    date_n = datetime.strptime(date_str, '%Y%m%d');
    print (date_n);

    #Using user input to calculate the previous file
    #global date_str_pre;
    if argv[2] != 1:
        if int(argv[2]) <= 10:
            date_str_pre = argv[1] + '0' + str(int(argv[2]) - 1) + argv[3];
            #print(date_str_pre);
        elif int(argv[2]) > 10:
            date_str_pre = argv[1] + str(int(argv[2]) - 1) + argv[3];
            #print(date_str_pre);
    elif argv[2] == 1:
        date_str_pre = str(int(argv[1]) - 1) + '12' + argv[3];

    #global asOf_cur_str;
    asOf_cur_str = date_str_pre;
    print("asOf_cur_str = " + asOf_cur_str);

    #Using the result string of the above calculation, seeting the directory for the previous file
    try:
        filepath_o = os.path.join('S:', 'IT', 'Dev', 'Scale', 'CreditAvailabilityModel', date_str_pre, 'mcai_2.0.txt');
        file_CAM_O = open(filepath_o, 'r');
    except:
        print("File not Found!")

    #Read in lines of  files, select asOf of the last row in each file
    line_cam_n = file_CAM_N.readlines();
    line_cam_o = file_CAM_O.readlines();
    lastline_n = line_cam_n[-1];
    lastline_o = line_cam_o[-1];
    asOf_n, index_n = lastline_n.split(",");
    asOf_o, index_o = lastline_o.split(",");

    #Calculating the predicted last asOf of the previous file
    #global asOf_pre_str;
    if argv[2] != 1 and argv[2] != 2:
        if int(argv[2]) <= 11:
            asOf_pre_str = argv[1] + '0' + str(int(argv[2]) - 2) + argv[3];
            #print(asOf_pre_str);
        elif int(argv[2]) == 12:
            asOf_pre_str = argv[1] + str(int(argv[2]) - 2) + argv[3];
            #print(asOf_pre);
    elif argv[2] == 1:
        asOf_pre_str = str(int(argv[1]) - 1) + '12' + argv[3];
    elif argv[2] == 2:
        asOf_pre_str = str(int(argv[1]) - 1) + '11' + argv[3];
    print("asOf_pre_str = " + asOf_pre_str);

    #Converting the asOf string in files to the format of the strings calculated above
    n_year, n_month, n_date = asOf_n.split("-");
    asOf_N_file = n_year + n_month + n_date;
    print("asOf_N = " + asOf_N_file);
    o_year, o_month, o_date = asOf_o.split("-");
    asOf_O_file = o_year + o_month + o_date;
    print("asOf_O = " + asOf_O_file);

    month_cur = "January";
    if int(argv[2]) == 1:
        month_cur = "January";
    elif int(argv[2]) == 2:
        month_cur = "February";
    elif int(argv[2]) == 3:
        month_cur = "March";
    elif int(argv[2]) == 4:
        month_cur = "April";
    elif int(argv[2]) == 5:
        month_cur = "May";
    elif int(argv[2]) == 6:
        month_cur = "June";
    elif int(argv[2]) == 7:
        month_cur = "July";
    elif int(argv[2]) == 8:
        month_cur = "August";
    elif int(argv[2]) == 9:
        month_cur = "September";
    elif int(argv[2]) == 10:
        month_cur = "October";
    elif int(argv[2]) == 11:
        month_cur = "November";
    elif int(argv[2]) == 12:
        month_cur = "December";

    #Comparing the asOf in files with the asOf calculated, and print error message
    if asOf_N_file != asOf_cur_str:
        print("Error in last row in " + asOf_n + " Data not updated!");
        body = """<body>
                  Greetings:
                  <br/>
                  <br/>
                  Error found in the last row with asOf """ + asOf_n + """ Data not updated!
                  </body>"""
        em = EmailUtil.EmailUtil();
        em.sendMessage('john.xiong@PIVcapital.com', "Error Found in Cre_Ava_Mdl_Check in File " + date_str, body);

    for an in range(3):
        rand = random.randint(1,len(line_cam_o));
        asOf, index = line_cam_n[rand].split(",");
        if line_cam_n[rand] != line_cam_o[rand]:
            print("Error in record(s) with asOf " + asOf + " and index " + index);
            body = """<body>
                      Greetings:
                      <br/>
                      <br/>
                      Error(s) found in record(s) with asOf """ + asOf + """ and index """ + index + """
                      </body>""";
            em = EmailUtil.EmailUtil();
            em.sendMessage('john.xiong@PIVcapital.com', "Error Found in Cre_Ava_Mdl_Check in File " + date_str, body);


if __name__ == "__main__":
    main(sys.argv[0:])
