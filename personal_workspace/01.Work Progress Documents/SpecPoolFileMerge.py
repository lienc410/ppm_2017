import sys
import pyodbc
import os

def main(argv):
    
    # Get Sybase IQ Database connection
    # DSN: Agency
    conn = pyodbc.connect('DSN=' + "Agency" + ';UID=' + "report"+';PWD=' + "gm4SJDw4" + ';DATABASE=' + 'Agency' + ';Autostop=No')
    cursor = conn.cursor()
    
    #full_sql_file = os.path.join('C:\Users\lien.chen\PycharmProjects\SpecPoolFileMerge\SpecPoolFileMerge.sql')
    cursor.execute("select top 1 from scale.FHL_PoolHist")
    rows = cursor.fetchall()
    for row in rows:
    print(row.user_id, row.user_name)




    #for row in cursor.execute("select top 10 * from scale.FHL_PoolHist"):
    #    print(row)