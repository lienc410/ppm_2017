using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Configuration;

using ccm.quantlib.input;
using log4net;

namespace ccm.quantlib.input
{
    class Program
    {
        private static readonly ILog log = LogManager.GetLogger(typeof(Program));
        static int Main(string[] args)
        {
            log4net.Config.BasicConfigurator.Configure();

            log.Info("Main(....)");

            if (args.Length != 1 || args[0].Length != 10)
            {
                Console.WriteLine("Please enter the input date in mm/dd/yyyy!");
                //return 1;
            }

            string conMs = "user id=report;password=gm4SJDw4;server=50.28.74.235\\PIV-MSSQL,1433;Trusted_Connection=false;database=PIV;connection timeout=30";
            string conIQ = "Data Source=Agency;UID=report;PWD=gm4SJDw4";

            string inputPath = "S:\\IT\\Production\\CCMQuantLib\\TBAPrices\\";
            
            //DateTime inputDate = DateTime.Parse(args[0]);
            DateTime inputDate = DateTime.Parse("12/31/2014");
            DateTime endDate = DateTime.Parse("1/01/2003");

            for (int i1 = 0; inputDate >= endDate; i1-- )
            {
                
                string dateString = inputDate.ToString("yyyyMMdd");

                //Get current coupon data input
                string inputPath1 = inputPath + dateString + "\\";
                if (!System.IO.Directory.Exists(inputPath1))
                    System.IO.Directory.CreateDirectory(inputPath1);
                string inputFile1 = inputPath1 + "CurrentCoupon_" + dateString + ".bin";


                CurrentCouponGen currentCouponDataGen = new CurrentCouponGen(inputDate, inputFile1, conMs, conIQ);
                currentCouponDataGen.getRawData();
                currentCouponDataGen.genPBCurrentCoupon();


                //currentCouponDataGen.print();
                currentCouponDataGen.cleanUp();

                inputDate = inputDate.AddDays(-1);
            }
            return 0;
        }
    }
}
