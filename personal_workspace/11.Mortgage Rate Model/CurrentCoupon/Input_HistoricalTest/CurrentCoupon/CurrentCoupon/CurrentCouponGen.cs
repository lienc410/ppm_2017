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
    class CurrentCouponGen
    {
        private static readonly ILog log = LogManager.GetLogger(typeof(CurrentCouponGen));
        private SqlConnection conMs;
        private SAConnection conIQ;

        private List<TimeSeries> currntCoupon;
        private List<TimeSeries> currntCouponPrice;
        private List<TimeSeries> currntCouponSettleDay;

        private CurrentCoupon currentCouponPB;
        private DateTime asOfDate;
        private string outputFile;
        private string sqlBase;
        private string dateFormat;

        public CurrentCouponGen(DateTime asOfDate, string outputFile, string conStrMs, string conStrIQ)
        {
            //log.Info("CurrentCouponGen()");
            this.asOfDate = asOfDate;
            this.outputFile = outputFile;
            conMs = new SqlConnection(conStrMs);
            conIQ = new SAConnection(conStrIQ);
            conMs.Open();
            conIQ.Open();
            //+ "\n\tand m.source = 'YIELDBOOK'";
            dateFormat = "yyyyMMdd";

            sqlBase = "select d.AsOfDate, m.TickerName, m.SeriesType, d.SeriesNumValue, d.SeriesCharValue,d.InTime"
                + "\nfrom TimeSeriesMeta as m,TimeSeries as d"
                + "\nwhere m.TimeSeriesMetaId = d.TimeSeriesMetaId"
                + "\nand d.AsOfDate = '" + asOfDate.ToString(dateFormat) + "'";

            currntCoupon = new List<TimeSeries>();
            currntCouponPrice = new List<TimeSeries>();
            currntCouponSettleDay = new List<TimeSeries>();
            //barcapVols = new List<TimeSeries>();
           
        }

        public void cleanUp()
        {
            conMs.Close();
            conIQ.Close();
        }

        public void getRawData()
        {
            string sqlCurrentCoupon = sqlBase + "and m.source = 'CITI' \nand (m.TickerName like 'GN%' OR m.TickerName like 'FN%') \nand m.TickerName not like '%GEN' \nand m.SeriesType='SettleDate'	\norder by d.AsOfDate, m.TickerName";
            currntCouponSettleDay = getTimeSeriesData(sqlCurrentCoupon, 1);
                
            sqlCurrentCoupon = sqlBase + "and m.source = 'CITI' \nand (m.TickerName like 'GN%' OR m.TickerName like 'FN%') \nand m.TickerName not like '%GEN' \nand m.SeriesType='Price'	\norder by d.AsOfDate, m.TickerName";
            currntCouponPrice = getTimeSeriesData(sqlCurrentCoupon, -1);

            //sqlCurrentCoupon = sqlBase + "and m.source = 'CITI' \nand (m.TickerName like 'GN%' OR m.TickerName like 'FN%') \nand m.TickerName not like '%GEN' \nand m.SeriesType='SettleDate'	\norder by d.AsOfDate, m.TickerName";
            //currntCouponSettleDay = getTimeSeriesData(sqlCurrentCoupon, 1);

            combineTimeSeries();
            
            //log.Info("currntCouponSettleDay[1].StatusCode: " + currntCouponSettleDay[1].StatusCode);
            //log.Info("iDate: " + iDate);
        }
      
        private List<TimeSeries> getTimeSeriesData(string sqlCmd, int PriceOrDays)
        {
            //log.Info("getTimeSeriesData(string sqlCmd<" + sqlCmd + ">");

            //SACommand cmd = conIQ.CreateCommand();
            SqlCommand cmd = conMs.CreateCommand();
            cmd.CommandText = sqlCmd;
            List<TimeSeries> rs = new List<TimeSeries>();

            try
            {
                //SADataReader dr = cmd.ExecuteReader();
                SqlDataReader dr = cmd.ExecuteReader();

                if (PriceOrDays == -1)      //Settle Price
                {
                    while (dr.Read())
                    {
                        if(!dr.IsDBNull(3))
                        {
                            rs.Add(new TimeSeries(
                                "", "", dr.GetString(1), dr.GetString(2),
                                "", "", dr.GetDateTime(0), dr.GetDateTime(0), dr.GetDouble(3), dr.GetDateTime(0)));
                        }
                    }
                }
                else if (PriceOrDays == 1)  //Settle Date
                {
                    while (dr.Read())
                    {
                        rs.Add(new TimeSeries(
                            dr.GetString(4), "", dr.GetString(1), dr.GetString(2),
                            "", "", dr.GetDateTime(0), dr.GetDateTime(0), 0, dr.GetDateTime(0)));
                    }
                }
                dr.Close();
            }
            catch (SAException ex)
            {
                log.Info(ex.Message);
            }
            return rs;
        }

        private void combineTimeSeries()
        {
            DateTime tempDate;
            for (int i1 = 0; i1 < currntCouponSettleDay.Count; i1++ )
            {
                for (int i2 = 0; i2 < currntCouponPrice.Count; i2++ )
                    if (currntCouponSettleDay[i1].TickerName == currntCouponPrice[i2].TickerName)
                    {
                        tempDate = DateTime.Parse(currntCouponSettleDay[i1].StatusCode);
                        currntCoupon.Add(new TimeSeries(
                        "", "", currntCouponSettleDay[i1].TickerName, "",
                        "", "", tempDate, currntCouponSettleDay[i1].AsOfDate, currntCouponPrice[i2].SeriesNumValue, currntCouponSettleDay[i1].AsOfDate));
                    }
            }
        }

        private double getSingleData(string sqlCmd)
        {
            //log.Info("getSingleData(string sqlCmd<" + sqlCmd + ">");

            //SACommand cmd = conIQ.CreateCommand();
            SqlCommand cmd = conMs.CreateCommand();
            cmd.CommandText = sqlCmd;
            double rs = 0;

            try
            {
                //SADataReader dr = cmd.ExecuteReader();
                SqlDataReader dr = cmd.ExecuteReader();

                while (dr.Read())
                {
                    rs = dr.GetDouble(9);
                }
                dr.Close();
            }
            catch (SAException ex)
            {
                log.Info(ex.Message);
            }

            return rs;
        }

  /*        public void print()
        {
            log.Info("--------------------------------------------- Current Coupon ---------------------------------------------------------------------------");
            foreach (TimeSeries t in currntCoupon) { log.Info(t.SeriesNumValue); }
        }
*/
        public int genPBCurrentCoupon()
        {
            //log.Info("genPBInputX(string outfile<" + outputFile + ">)");

            CurrentCoupon.Builder cCB = CurrentCoupon.CreateBuilder();

            /*=========================================================================================
            //Current Coupon Model Input
            //Author: 	
            //Desc:   	Serialization encoding for C++
            //Date:   	11/18/2014
            //Release: 	

            package ccm.quantlib.input;

            option optimize_for = SPEED;
 
            message CurrentCoupon {
                required int64 close_date = 1;
            
	            message TBA {
		            required string ticker_name=1;
		            required double price = 2;
		            required int64 settle_date = 3;
	            }

	            repeated TBA tba = 100;
            }
            =========================================================================================*/

            cCB.SetCloseDate(Convert.ToInt64(asOfDate.ToString(dateFormat)));
            log.Info("CloseDate<" + Convert.ToInt64(asOfDate.ToString(dateFormat)) + ">");
            
            foreach (TimeSeries t in currntCoupon)
            {
                String EDate = t.ExpirationDate.ToString(dateFormat);
                cCB.AddTba(CurrentCoupon.Types.TBA.CreateBuilder().SetTickerName(t.TickerName).SetPrice(t.SeriesNumValue).SetSettleDate(Convert.ToInt64(t.UpdateTime.ToString(dateFormat))));
            }

            currentCouponPB = cCB.Build();
            byte[] bytes;

            using (MemoryStream stream = new MemoryStream())
            {
                currentCouponPB.WriteTo(stream);
                bytes = stream.ToArray();
            }

            try
            {
                Stream stream = new FileStream(outputFile, FileMode.Create, FileAccess.Write, FileShare.None);
                stream.Write(bytes, 0, bytes.Length);
                stream.Close();
            }
            catch (IOException iox)
            {
                System.Console.WriteLine(iox.Message);
                log.Info(iox.Message);
            }
            return 0;
        }
    }
}
