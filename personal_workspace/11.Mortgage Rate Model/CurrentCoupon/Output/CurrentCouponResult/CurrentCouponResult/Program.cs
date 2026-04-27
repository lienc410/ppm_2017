using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Configuration;
using System.IO;


using ccm.quantlib.input;
using log4net;

namespace ccm.quantlib.input
{
    class Program
    {
        static int Main(string[] args)
        {
            log4net.Config.BasicConfigurator.Configure();
            int flag;

            if (args.Length != 1 || args[0].Length != 10)
            {
                Console.WriteLine("Please enter the input date in mm/dd/yyyy!");
                //return 1;
            }

            //string conMs = "user id=dev;password=ufmg71dkiw;server=50.28.74.237\\PIV-MSSQL,1433;Trusted_Connection=false;database=PIV0203;connection timeout=30";
            //string conIQ = "Data Source=PIV;UID=dev;PWD=ufmg71dkiw";

            string conMs = "user id=report;password=gm4SJDw4;server=50.28.74.235\\PIV-MSSQL,1433;Trusted_Connection=false;database=PIV;connection timeout=30";
            string conIQ = "Data Source=PIV;UID=report;PWD=gm4SJDw4";

            DateTime inputDate = DateTime.Parse("05/01/2009");
            DateTime endDate = DateTime.Parse("01/01/2006");

            string dateString;
            string inputPath;
            string inputFile;

            for (int i1 = 0; inputDate >= endDate; i1-- )
            {
                dateString = inputDate.ToString("yyyyMMdd");
                inputPath = "S:\\IT\\Production\\CCMQuantLib\\CurrentCoupon\\" + dateString + "\\";

                if (!Directory.Exists(inputPath))
                {
                    //Console.WriteLine(inputPath);
                    Console.WriteLine("File not found.");
                }
                else 
                {
                    //Get current coupon data input
                    if (!System.IO.Directory.Exists(inputPath))
                        Console.WriteLine("The data does not exist!");
                    inputFile = inputPath + "CurrentCoupon_" + dateString + ".bin";
                    Console.WriteLine(inputFile);

                    currentCouponResultWrite currentCouponDataGen = new currentCouponResultWrite(inputDate, inputFile, conMs, conIQ);
                    currentCouponDataGen.readCerrnetCouponResultFile();

                    currentCouponDataGen.writeDataToDB();
                    currentCouponDataGen.cleanUp();
                }


                inputDate = inputDate.AddDays(-1);
            }


            return 0;
        }
    }
}
