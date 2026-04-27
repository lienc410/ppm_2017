using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

using log4net;

namespace ccm.quantlib.input
{
    class TimeSeries
    {
        private static readonly ILog log = LogManager.GetLogger(typeof(TimeSeries));

        //private int timeSeriesMetaId;
        private string statusCode;
        private string source;
        private string tickerName;
        private string seriesType;
        private string category;
        private string modelType;
        private DateTime updateTime;
        private DateTime asOfDate;
        private double seriesNumValue;
        private DateTime expirationDate;

        //public int TimeSeriesMetaId { get { return timeSeriesMetaId; } set { timeSeriesMetaId = value; } }
        public string StatusCode { get { return statusCode; } set { statusCode = value; } }
        public string Source { get { return source; } set { source = value; } }
        public string TickerName { get { return tickerName; } set { tickerName = value; } }
        public string SeriesType { get { return seriesType; } set { seriesType = value; } }
        public string Category { get { return category; } set { category = value; } }
        public string ModelType { get { return modelType; } set { modelType = value; } }
        public DateTime UpdateTime { get { return updateTime; } set { updateTime = value; } }
        public DateTime AsOfDate { get { return asOfDate; } set { asOfDate = value; } }
        public double SeriesNumValue { get { return seriesNumValue; } set { seriesNumValue = value; } }
        public DateTime ExpirationDate { get { return expirationDate; } set { expirationDate = value; } }

        public TimeSeries(
            //int timeSeriesMetaId,
            string statusCode,
            string source,
            string tickerName,
            string seriesType,
            string category,
            string modelType,
            DateTime updateTime,
            DateTime asOfDate,
            double seriesNumValue,
            DateTime expirationDate
        )
        {
            //this.timeSeriesMetaId = timeSeriesMetaId;
            this.statusCode = statusCode;
            this.source = source;
            this.tickerName = tickerName;
            this.seriesType = seriesType;
            this.category = category;
            this.modelType = modelType;
            this.updateTime = updateTime;
            this.asOfDate = asOfDate;
            this.seriesNumValue = seriesNumValue;
            this.expirationDate = expirationDate;
        }

        public void print()
        {
            log.Info(
                //"\n\tTimeSeriesMetaId<" + timeSeriesMetaId
                //+ 

                ">\n\tstatusCode<" + statusCode
                + ">\n\tsource<" + source
                + ">\n\ttickerName<" + tickerName
                + ">\n\tseriesType<" + seriesType
                + ">\n\tcategory<" + category
                + ">\n\tmodelType<" + modelType
                + ">\n\tupdateTime<" + updateTime
                + ">\n\tasOfDate<" + asOfDate
                + ">\n\tseriesNumValue<" + seriesNumValue
                + ">\n\texpirationDate<" + expirationDate
                + ">"
                );
        }
    }
}