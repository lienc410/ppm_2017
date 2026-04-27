using System;
using System.Data;
using System.Collections.Generic;
using System.IO;
using System.Data.SqlClient;

using log4net;
using iAnywhere.Data.SQLAnywhere;

using pb = global::Google.ProtocolBuffers;
using pbc = global::Google.ProtocolBuffers.Collections;
using pbd = global::Google.ProtocolBuffers.Descriptors;

namespace ccm.quantlib.input
{
    class currentCouponResultWrite
    {
        private static readonly ILog log = LogManager.GetLogger(typeof(currentCouponResultWrite));
        private SqlConnection conMs;
        private SAConnection conIQ;

        private CurrentCouponResult CurrentCouponResultPB;
        private DateTime asOfDate;
        private string inputFile;
        private string sqlBase;
        private string dateFormat;

        public currentCouponResultWrite(DateTime asOfDate, string inputFile, string conStrMs, string conStrIQ)
        {
            //log.Info("CurrentCouponGen()");
            this.asOfDate = asOfDate;
            this.inputFile = inputFile;
            conMs = new SqlConnection(conStrMs);
            conIQ = new SAConnection(conStrIQ);
            conMs.Open();
            //conIQ.Open();
            //+ "\n\tand m.source = 'YIELDBOOK'";
            dateFormat = "yyyyMMdd";

            sqlBase = "exec AddTimeSeries 'PIV','FN_CMM_30Yr' ,'Rate' ,'MTG'  ,NULL , '" + asOfDate.ToString(dateFormat) + "',";
           
        }

        public int readCerrnetCouponResultFile(){
           // StreamReader stream = new StreamReader(inputFile);

            FileStream fs = File.OpenRead(inputFile);
            {
                CurrentCouponResultPB = CurrentCouponResult.ParseFrom(fs);
                Console.WriteLine(CurrentCouponResultPB.CloseDate);
                Console.WriteLine(CurrentCouponResultPB.TickerName);
                Console.WriteLine(CurrentCouponResultPB.Price); 
            }
       
            /*=========================================================================================
            PB message defination:

            //Current Coupon Model Input
            //Author: 	
            //Desc:   	Serialization encoding for C++
            //Date:   	02/02/2015
            //Release: 	

            package ccm.quantlib.input;

            option optimize_for = SPEED;
 
            message CurrentCouponResult {
                required int64 close_date = 1;
                required string ticker_name = 2;
                required double price = 3;
            }
            =========================================================================================*/
            return 1; 
            
        }

        public void cleanUp()
        {
            conMs.Close();
            //conIQ.Close();
        }

        public void writeDataToDB()
        {
            string sqlCmd = sqlBase + CurrentCouponResultPB.Price + ",NULL ,NULL";
            SqlCommand cmd = conMs.CreateCommand();
            cmd.CommandText = sqlCmd;

            cmd.ExecuteReader();
        }
    }
}
