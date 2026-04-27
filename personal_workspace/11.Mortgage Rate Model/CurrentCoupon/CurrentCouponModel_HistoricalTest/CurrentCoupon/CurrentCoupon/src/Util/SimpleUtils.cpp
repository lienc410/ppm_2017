#include "SimpleUtils.h"
#include <stdlib.h>
#include <math.h>
#include <iostream>
#include "../Date/DayCount.h"
#include <boost/algorithm/string.hpp>
using namespace std;

void SimpleUtils::getYMD(int yyyymmdd, int &y, int &m, int &d)
{
	y = yyyymmdd/10000;
	m = (yyyymmdd%10000)/100;
	d = yyyymmdd%100;
}

bool SimpleUtils::isZero(double x)
{
	double eps = 1.0e-16;

	return fabs(x)< eps ? true : false;
}


void SimpleUtils::throwError(string message)
{
	cerr << message << endl;
	exit(1);
}

DayCount SimpleUtils::getDayCount(string name)
{
	if(boost::to_upper_copy(name)=="30/360") {
		return DayCount_30_360;
	} else if (boost::to_upper_copy(name)=="ACT/360") {
		return DayCount_ACT_360;
	} else if (boost::to_upper_copy(name)=="ACT/ACT") {
		return DayCount_ACT_ACT;
	} else if (boost::to_upper_copy(name)=="ACT/365") {
		return DayCount_ACT_365;
	} 

	return DayCount_30_360;
}

DateFrequency SimpleUtils::getDateFrequency(string name)
{
	if(name.compare("Q")==0)
		return Quarterly;
	else if (name.compare("S")==0)
		return SemiAnnually;
	else if (name.compare("A")==0)
		return Annually;
	else if (name.compare("M")==0)
		return Monthly;
	
	return Monthly;
}

int SimpleUtils::getMonthFromString(const string &name)
{
	string uName = boost::to_upper_copy(name);
	int month=0;
	if(uName.compare("JAN")==0) {
		month=1;
	} else if (uName.compare("FEB")==0) {
		month=2;
	} else if (uName.compare("MAR")==0) {
		month=3;
	} else if (uName.compare("APR")==0) {
		month=4;
	} else if (uName.compare("MAY")==0) {
		month=5;
	} else if (uName.compare("JUN")==0) {
		month=6;
	} else if (uName.compare("JUL")==0) {
		month=7;
	} else if (uName.compare("AUG")==0) {
		month=8;
	} else if (uName.compare("SEP")==0) {
		month=9;
	} else if (uName.compare("OCT")==0) {
		month=10;
	} else if (uName.compare("NOV")==0) {
		month=11;
	} else if (uName.compare("DEC")==0) {
		month=12;
	}

	return month;
}

vector<string> SimpleUtils::getFields(string s, string delimiter) {

//	string delimiter = ",";
	size_t pos = 0;
	string token;
	vector<string> fields;
	while ((pos = s.find(delimiter)) != string::npos) {
		token = s.substr(0, pos);
		fields.push_back(token);
		s.erase(0, pos + delimiter.length());
	}
	fields.push_back(s);

	return fields;
}


bool SimpleUtils::isNaN(double x)
{
	return x!=x;
}