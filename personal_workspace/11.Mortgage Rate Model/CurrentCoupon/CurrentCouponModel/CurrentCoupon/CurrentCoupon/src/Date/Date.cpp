#include "../Date/Date.h"

CDate::CDate(const CDate &src) {
	mYear = src.mYear;
	mMonth = src.mMonth;
	mDay = src.mDay;

	updateSerial();
}


CDate::CDate(int y, int m, int d) {
	mYear = y;
	mMonth = m;
	mDay = d;

	updateSerial();
}

CDate::CDate(int serial) {
	mSerial = serial;

	updateYMD();
}

void CDate::addUnits(int amount, TenorUnit unit) {
	switch (unit) {

	case CYear:
		addYears(amount);
		break;
	case Quarter:
		addMonths(amount * 3);
		break;
	case Month:
		addMonths(amount);
		break;
	case Week:
		addDays(amount * 7);
		break;
	case BusinessDay:
		addBusinessDays(amount);
		break;
	case Day:
		addDays(amount);
		break;

	}

}

void CDate::gotoFirstDayOfMonth()
{
	mDay = 1;
	updateSerial();
}

void CDate::gotoEndOfMonth()
{
	addMonths(1);
	mDay = 1;
	updateSerial();
	addDays(-1);
}

//3rd Wednesday of the month
void CDate::gotoIMM(int year, int month) {
	int start = ymd2Serial(year, month, 1);
	int offset = 0;
	int day = getDayOfWeek(start);

	switch (day) {

	case Monday:
		offset = 16;
		break;

	case Tuesday:
		offset = 15;
		break;

	case Wednesday:
		offset = 14;
		break;

	case Thursday:
		offset = 20;
		break;

	case Friday:
		offset = 19;
		break;

	case Saturday:
		offset = 18;
		break;

	case Sunday:
		offset = 17;
		break;

	default:
		offset = 0;
		break;

	}

	mSerial = start + offset;
	mYear = year;
	mMonth = month;
	mDay = offset + 1;

}

void CDate::gotoNextIMM(bool monthly) {
	int start = getSerial();

	updateYMD();

	if (monthly) {

		gotoIMM(mYear, mMonth);
		if (getSerial() <= start) {

			if (mMonth < December) {

				gotoIMM(mYear, mMonth + 1);

			} else {

				gotoIMM(mYear + 1, January);
			}

		}

	} else {

		switch (mMonth) {

		case January:
		case February:
			gotoIMM(mYear, March);
			break;

		case April:
		case May:
			gotoIMM(mYear, June);
			break;

		case July:
		case August:
			gotoIMM(mYear, September);
			break;

		case October:
		case November:
			gotoIMM(mYear, December);
			break;

		case December:
			gotoIMM(mYear, December);
			if (getSerial() <= start)
				gotoIMM(mYear + 1, March);

			break;

		default:
			gotoIMM(mYear, mMonth);
			if (getSerial() <= start)
				gotoIMM(mYear, mMonth + 3);

			break;

		}

	}
}

void CDate::gotoPreviousIMM(bool monthly) {
	int start = getSerial();

	updateYMD();

	if (monthly) {

		gotoIMM(mYear, mMonth);
		if (getSerial() >= start) {

			if (mMonth > January) {

				gotoIMM(mYear, mMonth - 1);

			} else {

				gotoIMM(mYear - 1, December);
			}

		}

	} else {

		switch (mMonth) {

		case January:
		case February:
			gotoIMM(mYear - 1, December);
			break;

		case March:
			gotoIMM(mYear, March);
			if (getSerial() >= start)
				gotoIMM(mYear - 1, December);
			break;

		case April:
		case May:
			gotoIMM(mYear, March);
			break;

		case July:
		case August:
			gotoIMM(mYear, June);
			break;

		case October:
		case November:
			gotoIMM(mYear, September);
			break;

		case December:
			gotoIMM(mYear, December);
			if (getSerial() <= start)
				gotoIMM(mYear + 1, March);

			break;

		default:
			gotoIMM(mYear, mMonth);
			if (getSerial() >= start)
				gotoIMM(mYear, mMonth + 3);

			break;

		}

	}
}

void CDate::addTenor(Tenor tenor) {
	addUnits(tenor.getNum(), tenor.getTenorUnit());
}

void CDate::addTenor(double amount, TenorUnit unit) {
	addUnits((int) amount, unit);
}

void CDate::addTenorStr(string tenorStr) {
	Tenor tenor(tenorStr);
	addTenor(tenor);
}

void CDate::serial2YMD(int serial, int &year, int &month, int &day) {

	serial = (serial + Year1900Base) * 4 - 1;
	int y = serial / DaysIn4Centuries;
	serial -= DaysIn4Centuries * y;
	int d = (serial / 4) * 4 + 3;
	serial = d / DaysIn4Years;
	d = ((d - DaysIn4Years * serial) + 4) / 4 * 5 - 3;
	int m = d / 153;
	d = (d - 153 * m + 5) / 5;
	y = 100 * y + serial;
	if (m < 10) {
		day = d;
		month = m + 3;
		year = y;
	} else {
		day = d;
		month = m - 9;
		year = y + 1;
	}
}

int CDate::ymd2Serial(int year, int month, int day) {

	if (month <= February) {
		month += 9;
		year--;
	} else {
		month -= 3;
	}

	int century = year / 100;
	year -= century * 100;

	return ((century * DaysIn4Centuries) >> 2) + ((year * DaysIn4Years) >> 2)
			+ (month * 153 + 2) / 5 + day - Year1900Base;
}

double CDate::getBasisFractionBetweenSerials(int begin, int end, TenorUnit unit,
		DayCount dayCount) {
	if (begin == end)
		return 0.0;

	switch (unit) {

	case CYear:

		switch (dayCount) {

		case DayCount_ACT_360:

			return (end - begin) / 360.0;

		case DayCount_ACT_365:

			return (end - begin) / 365.0;

		case DayCount_30_360:

			return (end - begin) / 360.0;

		case DayCount_ACT_ACT:

			return (end - begin) / 365.25;

		}

	}

	return 0.0;

}

int CDate::addTenorToSerial(int serial, int num, TenorUnit unit,
		HolidayList holidayList, RollConvention rollConvention) {
	CDate CDate(serial);

	switch (unit) {

	case CYear:
		CDate.addYears(num);
		break;

	case Month:
		CDate.addMonths(num);
		break;

	case Day:
		CDate.addDays(num);
		break;

	case BusinessDay:
		CDate.addBusinessDays(num);
		break;

	case Week:
		CDate.addDays(num * 7);
		break;

	}

	return CDate.getSerial();
}

int CDate::addTenorToSerial(int serial, Tenor tenor, HolidayList holidayList,
		RollConvention rollConvention) {
	CDate CDate(serial);

	int num = tenor.getNum();
	TenorUnit unit = tenor.getTenorUnit();

	switch (unit) {

	case CYear:
		CDate.addYears(num);
		break;

	case Month:
		CDate.addMonths(num);
		break;

	case Day:
		CDate.addDays(num);
		break;

	case BusinessDay:
		CDate.addBusinessDays(num);
		break;

	case Week:
		CDate.addDays(num * 7);
		break;

	}

	return CDate.getSerial();
}


void CDate::addYears(int &serial, int years)
{
	CDate date(serial);
	date.addYears(years);
	serial = date.getSerial();
}

void CDate::addMonths(int &serial, int months)
{
	CDate date(serial);
	date.addMonths(months);
	serial = date.getSerial();
}

void CDate::addDays(int &serial, int days)
{
	CDate date(serial);
	date.addDays(days);
	serial = date.getSerial();
}

void CDate::addBusinessDays(int days) 
{
	HolidayList mHolidayList;
	if (days > 0)
		for (int i=0; i<days; i++)
		{ 
			setSerial(getSerial() + 1);

			while (isWeekEnd(getSerial()) || mHolidayList.isHoliday(getSerial())) 
				addDays(1);
		}
	else if (days < 0)
		for (int i=0; i>days; i--)
		{ 
			setSerial(getSerial() - 1);

			while (isWeekEnd(getSerial()) || mHolidayList.isHoliday(getSerial())) 
					addDays(-1);
		}

}

bool CDate::isBusinessDay()
{
	HolidayList mHolidayList;
	return !(isWeekEnd(getSerial()) || mHolidayList.isHoliday(getSerial())); 
}

void CDate::gotoFirstBusinessDayOfMonth()
{
	gotoFirstDayOfMonth();
	while (!isBusinessDay())
		addDays(1);
}

void CDate::gotoLastBusinessDayOfMonth()
{
	gotoEndOfMonth();
	while (!isBusinessDay())
		addDays(-1);
}
