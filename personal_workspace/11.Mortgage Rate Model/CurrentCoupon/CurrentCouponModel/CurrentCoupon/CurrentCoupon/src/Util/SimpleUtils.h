#ifndef SIMPLEUTILS_H
#define SIMPLEUTILS_H
#include <string>
#include <vector>
#include "../Date/DayCount.h"
#include "../Date/DateFrequency.h"
using namespace std;

class SimpleUtils {

public:

	static void getYMD(int yyyymmdd, int &y, int &m, int &d);

	static bool isZero(double x);

	static void throwError(string message);

	static DayCount getDayCount(string name);

	static DateFrequency getDateFrequency(string name);

	static int getMonthFromString(const string& name);

	static vector<string> getFields(string s, string delimiter=",");

	static bool isNaN(double x);

};



#endif
