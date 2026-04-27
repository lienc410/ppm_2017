'''
Created on Dec 23rd, 2015
@author: Henry
'''

import smtplib
from os.path import basename
from email.mime.application import MIMEApplication
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText

class EmailUtil(object):
    def __init__(self):
        self.setup()

    def sendMessage(self, recipient, subject, body, files=None):
        print ("sendMessage()")

        msg = MIMEMultipart()
        msg['Subject'] = subject
        msg['From'] = self.SENDER
        msg['To'] = recipient

        msg.attach(MIMEText(body, 'html'))
        
        for f in files or []:
            print(f)
            with open(f, "rb") as fil:
                msg.attach(MIMEApplication(fil.read(), Content_Disposition='attachment; filename="%s"' %basename(f), Name=basename(f)))
                fil.close()

        self.SESSION.sendmail(self.SENDER, recipient.split(','), msg.as_string());
                    
    def setup(self):
        print ("setup()");
        
        self.SMTP_SERVER = 'smtp.gmail.com';
        self.SMTP_PORT = 587;
        #self.SENDER = 'henry.vu@PIVcapital.com';
        self.SENDER = 'it-processing@PIVcapital.com';
        #self.PWD = 'bceguiaxmyhmsojk';
        self.PWD = 'bwaqnjpdkafjfxqq';

        self.SESSION = smtplib.SMTP(self.SMTP_SERVER, self.SMTP_PORT);
        self.SESSION.ehlo();
        self.SESSION.starttls();
        self.SESSION.ehlo;
        self.SESSION.login(self.SENDER, self.PWD);
   
    def __del__(self):
        print ("EmailUtil->Destroying");
        