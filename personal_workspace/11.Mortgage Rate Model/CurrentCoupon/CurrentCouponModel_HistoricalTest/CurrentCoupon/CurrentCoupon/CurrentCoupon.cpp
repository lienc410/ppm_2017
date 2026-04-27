// CurrentCoupon.cpp : Defines the entry point for the console application.
//

#include <iostream>
#include <fstream>
#include <string>
#include <algorithm>
#include "CurrentCoupon.pb.h"
#include "CurrentCouponResult.pb.h"
#include "src/Util/SimpleUtils.h"
#include "src/Util/Exception.h"
#include "MyDate.h"
#include <windows.h>

using namespace google::protobuf;
using namespace ccm::quantlib::input;
using namespace ccm::quantlib;
using namespace std;

# define PRICING_DATE 20141112

typedef struct TBALINE{
	string tickername_long;
	string ticker;
	double coupon;
	string type;
	string month;
	double price;
	int64 settle_date_int;
	int settle_year;
	int settle_month;
	int settle_day;
	Date settle_date;
}tbaLine;

typedef struct{
	Date settleDay;
	double price1;
	double price2;
}settle;

typedef struct yieldLine{
	int PricingDate;
	double FNMA;
	double FNCI;
	double GNMA;
	double GNMAII;
}yieldLine;


vector<tbaLine> ReadCurrentCouponFile(int yyyymmdd)
{
	int year, month, day;

	int64 close_date;
	vector<tbaLine> vec_tba;
	tbaLine line_tba;
	CurrentCoupon currentcoupon_data;

	string inputPath = "S:\\IT\\Production\\CCMQuantLib\\TBAPrices\\";
	string inputFile = inputPath + to_string(yyyymmdd) + "\\CurrentCoupon_" + to_string(yyyymmdd) + ".bin";
	cout<<inputFile<<endl;

	fstream input(inputFile, ios::in | ios::binary);
    if (!input) {
      cout << inputFile << ": File not found.  Need to create a new file." << endl;
    } else if (!currentcoupon_data.ParseFromIstream(&input)) {
      cerr << "Failed to parse data file." << endl;
      //return -1;
    }

	bool statusCode = currentcoupon_data.ParseFromIstream(&(fstream(inputFile.c_str(), ios::in|ios::binary)));
	//cout<< "statusCode: " << statusCode << endl;

	/*=========================================================================================
	PB message defination:

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

	
	if(statusCode){
		close_date = currentcoupon_data.close_date();
		cout<< "close_date: " << close_date << endl;

		//CurrentCoupon_TBA tba = currentcoupon_data.tba;
		

		for (int i1 = 0; i1 < currentcoupon_data.tba_size(); i1++){
			CurrentCoupon_TBA tba = currentcoupon_data.tba(i1);
			
			line_tba.tickername_long = tba.ticker_name();
			line_tba.price = tba.price();
			line_tba.settle_date_int = tba.settle_date();

			SimpleUtils::getYMD(line_tba.settle_date_int, year, month, day);

			line_tba.settle_year = year;
			line_tba.settle_month = month;
			line_tba.settle_day = day;
			
			//cout << year<< "\t"<< month << "\t" << day << "\t";
			line_tba.settle_date.set(month, day, year);

			//line_tba.settle_date.Display();

			vec_tba.push_back(line_tba);

			//cout << i1<<"\t"<<"tickername: "<< vec_tba[i1].tickername;
			//cout << "\t"<<"price: "<< vec_tba[i1].price;
			//cout << "\t"<<"settle_date: "<< vec_tba[i1].settle_date << endl;
		}
	}

	return vec_tba;
}

int WriteCurrentCouponResult(yieldLine FNMAyieldLine){
	int yyyymmdd = FNMAyieldLine.PricingDate;
	CurrentCouponResult outYieldLine;

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

	outYieldLine.set_close_date(FNMAyieldLine.PricingDate);
	outYieldLine.set_ticker_name("FN_CMM_30Yr");
	outYieldLine.set_price(FNMAyieldLine.FNMA);

	string outputPath = "S:\\IT\\Production\\CCMQuantLib\\CurrentCoupon\\" + to_string(yyyymmdd) + "\\";
	LPCSTR outputPath1 = outputPath.c_str();

	//create folder
	CreateDirectory(outputPath1, NULL);

	string outputFile = outputPath + "CurrentCoupon_" + to_string(yyyymmdd) + ".bin";
	cout << outputFile << endl;

	fstream output(outputFile, ios::out | ios::trunc | ios::binary);
	if (!outYieldLine.SerializeToOstream(&output)) {
      cerr << "Failed to write the data file." << endl;
      return -1;
    }

	return 1;
}

double FindCouponNUmber(string str){
	int flag=1,i=0,j=0,h=0;
	double m=0,sum=0,n=0;

	char *numstr = new char[str.length() + 1];
	strcpy(numstr, str.c_str());

	// 1.delete chars before 0～9
	for(;i<strlen(numstr);i++)
	{
		if((numstr[i]<='9'&&numstr[i]>='0')||numstr[i]=='+'||numstr[i]=='-')
		break;
		else
		j++;
	}
	if(numstr[j]=='-')
		flag=-1;
	if(numstr[j]=='+'||numstr[j]=='-')   //j point to the first number(except +/-)
		j++;
	i=j;          

	//2.delete chars after 0～9
	h=j;
	for(;i<strlen(numstr);i++)
	{
			if((numstr[i]<='9'&&numstr[i]>='0')||numstr[i]=='.')
				h++;
			else
			break;
	}
	h-=1;

	//3.integer part
	for( ;numstr[j]!='.'&&j<=h;j++) 
	{
		n=n*10+numstr[j]-'0';
	}


	//4.Fractional part
	if(j<h&&numstr[h]!='.')
	{
		for(j++;j<=h;h--)   
		{  
			m=m*0.1+numstr[h]-'0';
		}
		m*=0.1;

	}

	//5.combine interger and fractional
	sum=n+m;
	sum=sum*flag;
	//cout<<"out put:";
	//cout<<sum<<endl;

	return sum;
}

string DestructTicker(string str){
	char *s = new char[str.length() + 1];    
	//strcpy(s,s1.c_str());
	string result;

	strcpy(s, str.c_str());

    const char *d = "1234567890";
    char *p;

    result = strtok(s,d);
    return result;
}

tbaLine DestructString(string str){
	char *s = new char[str.length() + 1];    
	//strcpy(s,s1.c_str());
	string result;
	tbaLine tba;

	strcpy(s, str.c_str());

    const char *d = "-";
    char *p;

    tba.ticker = strtok(s,d);

	//cout << result <<endl;

	tba.type = strtok(NULL,d);
	tba.month = strtok(NULL,d);

	tba.coupon = FindCouponNUmber(tba.ticker);
	tba.ticker = DestructTicker(tba.ticker);
	/*
	cout <<  tba.ticker <<endl;
	cout <<  tba.coupon <<endl;
	cout <<  tba.type <<endl;
	cout <<  tba.month <<endl;
	*/

    return tba;
}

Date *findTwoMonth(Date *settleSeries_Date, Date targetDate){
	int daysToSettle2 = settleSeries_Date[1] - targetDate;	//15
	int daysToSettle3 = settleSeries_Date[2] - targetDate;	//43

	int front, back;	//left and right index for interpolation
	double daysToFront, daysToBack;
	Date *chosenDate = new Date[2];

	if(daysToSettle2 > 30)	//T + 30 is before the front-month TBA settlement date
	{
		front = 0;
		back = 1;
	}else if(daysToSettle3 < 30)	//T + 30 is after the back-month settlement date
	{
		front = 2;
		back = 3;
	}else		//general case
	{
		front = 1;
		back = 2;
	}

	chosenDate[0] = settleSeries_Date[front];
	chosenDate[1] = settleSeries_Date[back];

	return chosenDate;
}

double CalculateHistorical30YrsCurrentCoupon(settle *sSettle, Date targetDay, float coupon1, float coupon2){
	int front = 0;
	int back = 1;
	int daysToFront, daysToBack;

	double forwardPrice1, forwardPrice2, delayAdjPrice1, delayAdjPrice2, monthlyParRate, yieldConversion;
	double forwardDays = 30, delay = 25;

	daysToFront = sSettle[front].settleDay - targetDay;
	daysToBack = sSettle[back].settleDay - targetDay;
	cout<<"daysToFront: "<< daysToFront<<endl;

	forwardPrice1 = (forwardDays - daysToFront) / (daysToBack - daysToFront) * (sSettle[back].price1 - sSettle[front].price1) + sSettle[front].price1;
	forwardPrice2 = (forwardDays - daysToFront) / (daysToBack - daysToFront) * (sSettle[back].price2 - sSettle[front].price2) + sSettle[front].price2;
	cout<<"fwd1: "<< forwardPrice1<<endl;

	delayAdjPrice1 = forwardPrice1 + (delay - 1) / 360 * coupon1;
	delayAdjPrice2 = forwardPrice2 + (delay - 1) / 360 * coupon2;
	cout<<"delayAdjPrice1: "<<delayAdjPrice1<<endl;
	cout<<"delayAdjPrice2: "<<delayAdjPrice2<<endl;

	monthlyParRate = (100 - delayAdjPrice1) / (delayAdjPrice2 - delayAdjPrice1) * (coupon2 - coupon1) + coupon1;
	cout<<"monthlyParRate: "<<monthlyParRate<<endl;

	yieldConversion = 200 * (pow(1+ monthlyParRate/1200, 6) - 1);

	cout<<"yieldConversion: "<<yieldConversion<<endl;

	return yieldConversion;
} 

Date * Find4UniqueDates(vector<tbaLine> vec_tba){
	int daysToSettle, numOfMonth = 4;
	vector<int64> settleSeries;
	Date *settleSeries_Date = new Date[numOfMonth];
	int year, month, day, flag;


	settleSeries.push_back(vec_tba[1].settle_date_int);

	for(int i3 = 0; i3 < vec_tba.size(); i3++){
		flag = 1;
		for(int j3 = 0; j3 < settleSeries.size(); j3++){
			
			if(vec_tba[i3].settle_date_int != settleSeries[j3])
				flag = flag;
			else
				flag = flag * 0;
		}
		if(flag == 1)
			settleSeries.push_back(vec_tba[i3].settle_date_int);
	}
	
	//sort the series
	sort(settleSeries.begin(), settleSeries.end());

	for(int j3 = 0; j3 < settleSeries.size(); j3++){
		SimpleUtils::getYMD(settleSeries[j3], year, month, day);
		settleSeries_Date[j3].set(month, day, year);
		//settleSeries_Date[j3].Display();
		//cout << settleSeries[j3]<< endl;
	}

	return settleSeries_Date;
}

double CurrentCouponPartialCal(Date *settleSeries_Date, Date targetDate, vector<tbaLine> vec_tempDataSet){
	vector<tbaLine> vec_AfterMonth, tempvec_interpolateInput;
	Date *chosenDate = new Date[2];
	double minCoupon, maxCoupon, coupon_step = 0.5, coupon_Tolerance = 0.01, par = 100;
	vector<double> vec_temp_coupon, diff_from_par;
	tbaLine front_low_line, front_up_line, back_low_line, back_up_line, temp_interp_left, temp_interp_right;
	double yieldConversion;
	int flag_couponCheck = 0, icounter1;

	//
	//3.locate two settle month
	//
	//find 4 unique dates 

	settleSeries_Date = Find4UniqueDates(vec_tempDataSet);
	//find 2 useful month
	chosenDate = findTwoMonth(settleSeries_Date, targetDate);		//front as [0]; back as [1].

	//filter the data set
	for(int i2 = 0; i2 < vec_tempDataSet.size(); i2++){
		//if(vec_FNMA[i2].settle_date == settleSeries_Date[0] || vec_FNMA[i2].settle_date == settleSeries_Date[1])
		if(vec_tempDataSet[i2].settle_date == chosenDate[0])
			vec_AfterMonth.push_back(vec_tempDataSet[i2]);
	}

	/*for(int i3 = 0; i3 < vec_FNMA_AfterMonth.size(); i3++){
		cout << i3 << "\t" << vec_FNMA_AfterMonth[i3].ticker << "\t" << vec_FNMA_AfterMonth[i3].coupon << "\t" << vec_FNMA_AfterMonth[i3].month << "\t" << vec_FNMA_AfterMonth[i3].price << 
			"\t" << vec_FNMA_AfterMonth[i3].settle_date_int << "\t" << vec_FNMA_AfterMonth[i3].settle_year << "\t" << vec_FNMA_AfterMonth[i3].settle_month << "\t" << vec_FNMA_AfterMonth[i3].settle_day <<"\t";
		vec_FNMA_AfterMonth[i3].settle_date.Display();
	}*/
		
	//
	//4.selet 2 coupons
	//

	//chose 2 coupon according to the front month near par price
	double up_coupon, low_coupon, up_diff, low_diff;

	for(int i3 = 0; i3 < vec_AfterMonth.size(); i3++){
			diff_from_par.push_back(vec_AfterMonth[i3].price - par);
	}
	sort(diff_from_par.begin(), diff_from_par.end());

	for(int i3 = 0; i3 < diff_from_par.size() - 1; i3++){
		if(diff_from_par[i3] * diff_from_par[i3+1] <= 0){
			up_diff = diff_from_par[i3+1];
			low_diff = diff_from_par[i3];
			flag_couponCheck = 1;
			break;
		}		
	}

	
/*	if(flag_couponCheck == 0){
		cout << vec_tempDataSet[1].ticker << " coupon data invalid (all higher/lower than par!)" << endl;
		yieldConversion = -2;
		return yieldConversion;
	}	
*/
	if(flag_couponCheck == 0){		//if coupon data invalid (all higher/lower than par), need to do interpolation
		cout << vec_tempDataSet[1].ticker << " coupon data invalid (all higher/lower than par!)" << endl;
		yieldConversion = -2;
		
		if(diff_from_par[0] > 0)	//all higher than par, try smaller coupon
		{
			for(int i3 = 0; i3 < vec_AfterMonth.size(); i3++){
				if(vec_AfterMonth[i3].price - par == diff_from_par[0]){
					up_coupon = vec_AfterMonth[i3].coupon;
					low_coupon = up_coupon - 0.5;		//assign a coupon for interpolation

					if(low_coupon <= 1.5){
						cout << "coupon data invalid: need data for coupon 1.5" << endl;
						yieldConversion = -4;
						//return yieldConversion;						
					}
					break;
				}
			}
		}		
	}
	else							//coupon data valid,good to use
	{
		for(int i3 = 0; i3 < vec_AfterMonth.size(); i3++){
			if(vec_AfterMonth[i3].price - par == up_diff)
				up_coupon = vec_AfterMonth[i3].coupon;
			if(vec_AfterMonth[i3].price - par == low_diff)
				low_coupon = vec_AfterMonth[i3].coupon;
		}
	}
	//cout << "up_coupon: " << up_coupon <<"\tlow_coupon: "<<low_coupon<<endl;
	
	//filter the data set
	for(int i2 = 0; i2 < vec_tempDataSet.size(); i2++){
		if(vec_tempDataSet[i2].coupon == up_coupon && vec_tempDataSet[i2].settle_date == chosenDate[0])
			front_up_line = vec_tempDataSet[i2];
		else if(vec_tempDataSet[i2].coupon == low_coupon && vec_tempDataSet[i2].settle_date == chosenDate[0])
			front_low_line = vec_tempDataSet[i2];
		else if(vec_tempDataSet[i2].coupon == up_coupon && vec_tempDataSet[i2].settle_date == chosenDate[1])
			back_up_line = vec_tempDataSet[i2];
		else if(vec_tempDataSet[i2].coupon == low_coupon && vec_tempDataSet[i2].settle_date == chosenDate[1])
			back_low_line = vec_tempDataSet[i2];
	}
	
/*	if(front_up_line.coupon < 0 || front_low_line.coupon < 0 || back_up_line.coupon < 0 ||back_low_line.coupon < 0)
	{
		cout << vec_tempDataSet[1].ticker << "Missing data!" << endl;
		yieldConversion = -3;		 

		return yieldConversion;
	}
*/
	//
	//	interpolation process for missing data at coupon 1.5
	//
	if(low_coupon <= 1.5){
		front_low_line = front_up_line;
		front_low_line.coupon = front_up_line.coupon - 0.5;
		front_low_line.price = -100000;

		back_low_line = back_up_line;
		back_low_line.coupon = back_up_line.coupon - 0.5;
		back_low_line.price = -100000;

		temp_interp_left.price = diff_from_par[0] + par;
		temp_interp_right.price = diff_from_par[1] + par;
		temp_interp_left.coupon = front_up_line.coupon;
		temp_interp_right.coupon = front_up_line.coupon + 0.5;

		front_low_line.price = (front_low_line.coupon - temp_interp_left.coupon) / (temp_interp_right.coupon - temp_interp_left.coupon) * (temp_interp_right.price - temp_interp_left.price) + temp_interp_left.price;
		back_low_line.price = (back_low_line.coupon - temp_interp_left.coupon) / (temp_interp_right.coupon - temp_interp_left.coupon) * (temp_interp_right.price - temp_interp_left.price) + temp_interp_left.price;
				
	}	
	//
	//	interpolation process for missing data at coupon 2.0
	//
	else if(front_up_line.coupon < 0 || front_low_line.coupon < 0 || back_up_line.coupon < 0 ||back_low_line.coupon < 0)
	{
		cout << "Missing data! Need to interpolate!" << endl;
		yieldConversion = -3;

		//interpolate for front_low_line
		if(front_low_line.coupon < 0){
			front_low_line = front_up_line;
			front_low_line.coupon = front_up_line.coupon - 0.5;
			front_low_line.price = -100000;

			for(int i2 = 0; i2 < vec_tempDataSet.size(); i2++){			
				if(vec_tempDataSet[i2].coupon == front_low_line.coupon)
					tempvec_interpolateInput.push_back(vec_tempDataSet[i2]);
			}

			if(tempvec_interpolateInput.size() < 2){
				cout << "not enough data for interpolation!" << endl;	
				yieldConversion = -5;		 

				//return yieldConversion;
				
				// use coupon+0.5 and coupon+1.0 data to interpolate the coupon data point
				front_low_line = front_up_line;
				front_low_line.coupon = front_up_line.coupon - 0.5;
				front_low_line.price = -100000;

				back_low_line = back_up_line;
				back_low_line.coupon = back_up_line.coupon - 0.5;
				back_low_line.price = -100000;

				temp_interp_left.price = diff_from_par[0] + par;
				temp_interp_right.price = diff_from_par[1] + par;
				temp_interp_left.coupon = front_up_line.coupon;
				temp_interp_right.coupon = front_up_line.coupon + 0.5;

				front_low_line.price = (front_low_line.coupon - temp_interp_left.coupon) / (temp_interp_right.coupon - temp_interp_left.coupon) * (temp_interp_right.price - temp_interp_left.price) + temp_interp_left.price;
				back_low_line.price = (back_low_line.coupon - temp_interp_left.coupon) / (temp_interp_right.coupon - temp_interp_left.coupon) * (temp_interp_right.price - temp_interp_left.price) + temp_interp_left.price;
			}
			else{
				//sort
				for(int i5 = 0; i5 < tempvec_interpolateInput.size(); i5++){
					for(int j5 = 0; j5 < tempvec_interpolateInput.size()-i5-1; j5++){
						if(tempvec_interpolateInput[j5].settle_date > tempvec_interpolateInput[j5+1].settle_date){
							temp_interp_left = tempvec_interpolateInput[j5];
							tempvec_interpolateInput[j5] = tempvec_interpolateInput[j5+1];
							tempvec_interpolateInput[j5+1] =  temp_interp_left;
						}
					}
				}

				// use other two month data to interpolate the data point
				temp_interp_left = tempvec_interpolateInput[0];
				temp_interp_right = tempvec_interpolateInput[tempvec_interpolateInput.size()-1];

				front_low_line.price = (front_low_line.settle_date - temp_interp_left.settle_date) / (temp_interp_right.settle_date - temp_interp_left.settle_date) * (temp_interp_right.price - temp_interp_left.price) + temp_interp_left.price;
			}					
		}
		// interpolate back_low line
		else if(back_low_line.coupon < 0){
			back_low_line = back_up_line;
			back_low_line.coupon = back_up_line.coupon - 0.5;
			back_low_line.price = -100000;

			for(int i2 = 0; i2 < vec_tempDataSet.size(); i2++){			
				if(vec_tempDataSet[i2].coupon == back_low_line.coupon)
					tempvec_interpolateInput.push_back(vec_tempDataSet[i2]);
			}

			if(tempvec_interpolateInput.size() < 2){
				//cout << "not enough data for interpolation!" << endl;	
				yieldConversion = -5;		 

				//return yieldConversion;
				
				// use coupon+0.5 and coupon+1.0 data to interpolate the coupon data point
				front_low_line = front_up_line;
				front_low_line.coupon = front_up_line.coupon - 0.5;
				front_low_line.price = -100000;

				back_low_line = back_up_line;
				back_low_line.coupon = back_up_line.coupon - 0.5;
				back_low_line.price = -100000;

				temp_interp_left.price = diff_from_par[0] + par;
				temp_interp_right.price = diff_from_par[1] + par;
				temp_interp_left.coupon = front_up_line.coupon;
				temp_interp_right.coupon = front_up_line.coupon + 0.5;

				front_low_line.price = (front_low_line.coupon - temp_interp_left.coupon) / (temp_interp_right.coupon - temp_interp_left.coupon) * (temp_interp_right.price - temp_interp_left.price) + temp_interp_left.price;
				back_low_line.price = (back_low_line.coupon - temp_interp_left.coupon) / (temp_interp_right.coupon - temp_interp_left.coupon) * (temp_interp_right.price - temp_interp_left.price) + temp_interp_left.price;
			}
			else{
				//sort
				for(int i5 = 0; i5 < tempvec_interpolateInput.size(); i5++){
					for(int j5 = 0; j5 < tempvec_interpolateInput.size()-i5-1; j5++){
						if(tempvec_interpolateInput[j5].settle_date > tempvec_interpolateInput[j5+1].settle_date){
							temp_interp_left = tempvec_interpolateInput[j5];
							tempvec_interpolateInput[j5] = tempvec_interpolateInput[j5+1];
							tempvec_interpolateInput[j5+1] =  temp_interp_left;
						}
					}
				}

				// use other two month data to interpolate the data point
				temp_interp_left = tempvec_interpolateInput[0];
				temp_interp_right = tempvec_interpolateInput[tempvec_interpolateInput.size()-1];

				back_low_line.price = (back_low_line.settle_date - temp_interp_left.settle_date) / (temp_interp_right.settle_date - temp_interp_left.settle_date) * (temp_interp_right.price - temp_interp_left.price) + temp_interp_left.price;
			}					
		}
	}



	//
	//5.calculate the yield conversion
	//
	settle *sett = new settle[2];
	sett[0].settleDay = front_up_line.settle_date;
	sett[0].price1 = front_low_line.price;
	sett[0].price2 = front_up_line.price;
	sett[0].settleDay .Display();
	cout << "price1: "<< sett[0].price1 << "\t price2: "<< sett[0].price2 << endl << endl;

	sett[1].settleDay = back_low_line.settle_date;
	sett[1].price1 = back_low_line.price;
	sett[1].price2 = back_up_line.price;
	sett[1].settleDay .Display();
	cout << "price1: "<< sett[1].price1 << "\t price2: "<< sett[1].price2 << endl << endl;
	cout << "coupon1: "<< low_coupon << "\t coupon2: "<< up_coupon << endl;
	
	yieldConversion = CalculateHistorical30YrsCurrentCoupon(sett, targetDate, low_coupon, up_coupon);

	return yieldConversion;
}

double *CurrentCouponGenerate(int yyyymmdd){
	//int yyyymmdd = PRICING_DATE;
	int target_year, target_month, target_day, year, month, day;
	vector<tbaLine> vec_tba, vec_FNMA, vec_FNCI, vec_GNMA, vec_GNMAII, vec_AfterMonth, vec_tempDataSet;
	tbaLine tempTbaLine;
	Date targetDate;
	int daysToSettle, numOfMonth = 4;
	vector<int64> settleSeries;
	Date *settleSeries_Date = new Date[numOfMonth];
	double *yieldConversion = new double [4];

	
	SimpleUtils::getYMD(yyyymmdd, target_year, target_month, target_day);
	targetDate.set(target_month, target_day, target_year);
	
	
	//
	//1.get raw data from PB file
	//
	vec_tba = ReadCurrentCouponFile(yyyymmdd);

	if(vec_tba.size()<1){
		for(int i5 = 0; i5 < 4; i5++)
			yieldConversion[i5] = -1;	//not business day
		return yieldConversion;
	}
	
	for(int i1 = 0; i1 < vec_tba.size(); i1++){

		tempTbaLine = DestructString(vec_tba[i1].tickername_long);
	
		vec_tba[i1].ticker = tempTbaLine.ticker;
		vec_tba[i1].coupon = tempTbaLine.coupon;
		vec_tba[i1].type = tempTbaLine.type;
		vec_tba[i1].month = tempTbaLine.month;

		//cout << i1 << "\t" << vec_tba[i1].ticker << "\t" << vec_tba[i1].coupon << "\t" << vec_tba[i1].month << "\t" << vec_tba[i1].price << "\t" << vec_tba[i1].settle_date << endl;
	}

	//
	//2.separate data by agency
	//
	for(int i2 = 0; i2 < vec_tba.size(); i2++){
		if(vec_tba[i2].ticker == "FNMA")
			vec_FNMA.push_back(vec_tba[i2]);
		if(vec_tba[i2].ticker == "FNCI")
			vec_FNCI.push_back(vec_tba[i2]);
		if(vec_tba[i2].ticker == "GNMA")
			vec_GNMA.push_back(vec_tba[i2]);
		if(vec_tba[i2].ticker == "GNMAII")
			vec_GNMAII.push_back(vec_tba[i2]);
	}
	//cout<< "vec_FNMA.size(): " << vec_FNMA.size() <<endl;
	
	//
	//3.locate two settle month
	//4.selet 2 coupons
	//5.calculate the yield conversion
	//
	//3-5 are implemented in CurrentCouponPartialCal()
	
	cout << endl << "==================== FNMA ====================" << endl;
	vec_tempDataSet = vec_FNMA;				//calculate for FNMA
	yieldConversion[0] = CurrentCouponPartialCal(settleSeries_Date, targetDate, vec_tempDataSet);

	//only calculate FNMA historic price
	/*
	cout << endl << "==================== FNCI ====================" << endl;
	vec_tempDataSet = vec_FNCI;				//calculate for FNCI
	yieldConversion[1] = CurrentCouponPartialCal(settleSeries_Date, targetDate, vec_tempDataSet);

	cout << endl << "==================== GNMA ====================" << endl;
	vec_tempDataSet = vec_GNMA;				//calculate for GNMA
	yieldConversion[2] = CurrentCouponPartialCal(settleSeries_Date, targetDate, vec_tempDataSet);

	cout << endl << "==================== GNMAII ====================" << endl;
	vec_tempDataSet = vec_GNMAII;				//calculate for GNMAII
	yieldConversion[3] = CurrentCouponPartialCal(settleSeries_Date, targetDate, vec_tempDataSet);
	*/
	yieldConversion[1] = -1;
	yieldConversion[2] = -1;
	yieldConversion[3] = -1;
	//cin.get();

	return yieldConversion;
}

int main(int argc, char* argv[]){
	//int yyyymmdd = PRICING_DATE;
	int yyyymmdd = 20060103;
	int yyyymmdd_end = 20060103;
	vector<yieldLine> vec_yield;
	double *yieldConversion = new double [4];
	yieldLine yieldOneDayData;
	Date pricingDate,endDate;
	int target_year, target_month, target_day, end_year, end_month, end_day;

	SimpleUtils::getYMD(yyyymmdd, target_year, target_month, target_day);
	pricingDate.set(target_month, target_day, target_year);

	SimpleUtils::getYMD(yyyymmdd_end, end_year, end_month, end_day);
	endDate.set(end_month, end_day, end_year);

	for(int i2 = 0; pricingDate >= endDate; pricingDate --){
		
		yyyymmdd = pricingDate.GetYear() * 10000 + pricingDate.GetMonth() *100 + pricingDate.GetDay();

		yieldConversion = CurrentCouponGenerate(yyyymmdd + i2);
		yieldOneDayData.PricingDate = yyyymmdd + i2;
		yieldOneDayData.FNMA = yieldConversion[0];
		yieldOneDayData.FNCI = yieldConversion[1];
		yieldOneDayData.GNMA = yieldConversion[2];
		yieldOneDayData.GNMAII = yieldConversion[3];

		if(yieldOneDayData.FNMA != -1)
			vec_yield.push_back(yieldOneDayData);
	}

/*
	ofstream fout1("yieldConversion.csv");
	if(fout1.fail())
		cout << "Fail to create file." << endl;

	fout1 << "Pricing Date" << ',' << "FNMA" << ',' << "FNCI" << ',' << "GNMA" << ',' << "GNMAII" << endl;

	for(int i1 = 0; i1 < vec_yield.size(); i1++){
		fout1 << vec_yield[i1].PricingDate << ',' << vec_yield[i1].FNMA << ',' << vec_yield[i1].FNCI << ',' << vec_yield[i1].GNMA << ',' << vec_yield[i1].GNMAII << endl;
	
		//WriteCurrentCouponResult(vec_yield[i1]);
	}



	fout1.close();
*/
	cin.get();
	return 0;
}