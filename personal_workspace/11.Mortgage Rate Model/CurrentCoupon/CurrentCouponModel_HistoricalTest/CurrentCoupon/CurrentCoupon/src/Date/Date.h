#ifndef CDATE_H_
#define CDATE_H_

#include "../Date/DateConvention.h"
#include "../Date/DayCount.h"
#include "../Date/Tenor.h"
#include "../Date/Tenor.h"
//#include "../string"
#include "../Date/HolidayList.h"
using namespace std;

/*
enum Month { January=1, February, March, April, May, June, July, August, September, October, November, December};
enum Weekday { Monday=1, Tuesday, Wednesday, Thursday, Friday, Saturday, Sunday};
*/


class CDate {

public:

	static const int Year1900Base = 693900;
	static const int DaysIn4Centuries = 146097;
	static const int DaysIn4Years = 1461;
	
	static const int January = 1;
	static const int February = 2;
	static const int March = 3;
	static const int April = 4;
	static const int May = 5;
	static const int June = 6;
	static const int July = 7;
	static const int August = 8;
	static const int September = 9;
	static const int October = 10;
	static const int November = 11;
	static const int December = 12;
	
	static const int Monday = 1;
	static const int Tuesday = 2;
	static const int Wednesday = 3;
	static const int Thursday = 4;
	static const int Friday = 5;
	static const int Saturday = 6;
	static const int Sunday = 7;
	
	CDate(const CDate &src);

	CDate(int y, int m, int d);

	CDate(int serial);

	~CDate() { mYear = 0; mMonth=0; mDay=0; mSerial=0; }

	int getYear() {
		return mYear;
	}
	int getMonth() {
		return mMonth;
	}
	int getDay() {
		return mDay;
	}
	int getSerial() {
		return mSerial;
	}

	void setYear(int year) {

		mYear = year;
		mSerial = ymd2Serial(mYear, mMonth, mDay);

	}

	void setMonth(int month) {

		mMonth = month;
		mSerial = ymd2Serial(mYear, mMonth, mDay);

	}

	void setDay(int day) {

		mDay = day;
		mSerial = ymd2Serial(mYear, mMonth, mDay);

	}


	void setYearMonthDay(int year, int month, int day) {
		mYear = year;
		mMonth = month;
		mDay = day;
		mSerial = ymd2Serial(mYear, mMonth, mDay);
	}

	void addYears(int years) {

		if (years != 0)
			setYear(getYear() + years);

	}

	void addMonths(int months) {

		if (months != 0) {
			months += mYear * 12 + mMonth - 1;

			setYearMonthDay(months / 12, (months % 12) + 1, mDay);
		}

	}

	void addDays(int days) {
		setSerial(getSerial() + days);
	}

	void addBusinessDays(int days);

	void setSerial(int serial) {
		mSerial = serial;
		serial2YMD(serial, mYear, mMonth, mDay);
	}

	void updateSerial() {
		mSerial = ymd2Serial(mYear, mMonth, mDay);
	}

	void updateYMD() {
		serial2YMD(mSerial, mYear, mMonth, mDay);
	}

	void addTenor(double amount, TenorUnit unit);

	void addTenor(Tenor tenor);

	void addTenorStr(string tenorStr);

	void addUnits(int amount, TenorUnit unit);

	void gotoFirstDayOfMonth();

	void gotoEndOfMonth();

	void gotoIMM(int year, int month);

	void gotoNextIMM(bool monthly);

	void gotoPreviousIMM(bool monthly) ;

	int getYYYYMMDD() { return mYear*10000+mMonth*100+mDay; }

	bool isBusinessDay();

	void gotoFirstBusinessDayOfMonth();

	void gotoLastBusinessDayOfMonth();

	static bool isLeapYear(int year) {
		return (year % 4) == 0 && ((year % 100) != 0 || (year % 400) == 0);
	}

	static int getNumberOfDaysInYear(int year) {
		return isLeapYear(year) ? 366 : 365;
	}

	static int getNumberOfDaysInFebruary(int year) {
		return isLeapYear(year) ? 29 : 28;
	}

	static int getDayOfWeek(int serial) {
		return ((serial + 5) % 7) + 1;
	}

	static bool isWeekEnd(int serial) {
		int dayOfWeek = getDayOfWeek(serial);
		return (dayOfWeek == Saturday || dayOfWeek == Sunday);
	}

	static void serial2YMD(int serial, int &year, int &month, int &day);

	static int ymd2Serial(int year, int month, int day);

	static double getBasisFractionBetweenSerials(int begin, int end,
			TenorUnit unit, DayCount dayCount);

	static void addYears(int &serial, int years);

	static void addMonths(int &serial, int months);

	static void addDays(int &serial, int days);

	static int addTenorToSerial(int serial, int num, TenorUnit unit, HolidayList holidayList, RollConvention rollConvention);

	static int addTenorToSerial(int serial, Tenor tenor, HolidayList holidayList, RollConvention rollConvention);

	static int getYYYYMMDD(int serial) { CDate date(serial); return date.getYYYYMMDD(); }


private:
	int mYear;
	int mMonth;
	int mDay;

	int mSerial;
	
};

#endif /* DATE_H_ */
