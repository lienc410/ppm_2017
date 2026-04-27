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
        filepath_n = os.path.join('S:', 'IT', 'Dev', 'Scale', 'HpaModel', date_str, 'hpa_' + argv[4] + '.txt')
        file_hpa_N = open(filepath_n, 'r')
    except:
        print("File not Found!")

    #Converting the string input into datetime
    date_n = datetime.strptime(date_str, '%Y%m%d');
    #print(date_n);

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
    #print("date_str_pre = " + date_str_pre);

    #Using the result string of the above calculation, seeting the directory for the previous file
    try:
        filepath_o = os.path.join('S:', 'IT', 'Dev', 'Scale', 'HpaModel', date_str_pre, 'hpa_' + argv[4] + '.txt');
        file_hpa_O = open(filepath_o, 'r');
    except:
        print("File not Found!")

    #Read in lines of  files, select asOf of the last row in each file
    line_hpa_n = file_hpa_N.readlines();
    line_hpa_o = file_hpa_O.readlines();
    len_cur = len(line_hpa_n);
    len_pre = len(line_hpa_o);
    len_diff = len_cur - len_pre;

    #Compare row number difference and report if they are different
    if len_diff > 0:
        print("Error in current file of " + date_str + "! It has " + str(len_diff) + " more rows than the previous file.");
        body = """<body>
                  Greetings:
                  <br/>
                  <br/>
                  Error in current file of  """ + date_str + """! It has """ + str(len_diff) + """ more rows than the previous file.
                  </body>""";
        em = EmailUtil.EmailUtil();
        em.sendMessage('john.xiong@PIVcapital.com', "Error Found in Cre_Ava_Mdl_Check with File " + date_str, body);
    elif len_diff < 0:
        print("Error in current file of " + date_str + "! It has " + str(abs(len_diff)) + " fewer rows than the previous file.");
        body = """<body>
                  Greetings:
                  <br/>
                  <br/>
                  Error in current file of  """ + date_str + """! It has """ + str(abs(len_diff)) + """ fewer rows than the previous file.
                  </body>""";
        em = EmailUtil.EmailUtil();
        em.sendMessage('john.xiong@PIVcapital.com', "Error Found in Cre_Ava_Mdl_Check with File " + date_str, body);

    for an in range(3):
        rand = random.randint(1,len_cur);
        asOf, index, hpa_2YR = line_hpa_n[rand].split(",");
        if line_hpa_n[rand] != line_hpa_o[rand]:
            print("Error in record(s) with asOf " + asOf + " and index " + index + " and HPA_2YR " + hpa_2YR);
            body = """<body>
                      Greetings:
                      <br/>
                      <br/>
                      Error(s) found in record(s) with asOf """ + asOf + """ and index """ + index + """ and HPA_2YR """ + hpa_2YR + """
                      </body>""";
            em = EmailUtil.EmailUtil();
            em.sendMessage('john.xiong@PIVcapital.com', "Error Found in Cre_Ava_Mdl_Check with File " + date_str, body);


if __name__ == "__main__":
    main(sys.argv[0:])
