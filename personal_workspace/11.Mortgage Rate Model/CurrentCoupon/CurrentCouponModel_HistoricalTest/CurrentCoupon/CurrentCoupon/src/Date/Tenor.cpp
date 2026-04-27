#include <stdlib.h>
#include <boost/algorithm/string.hpp>
#include "Tenor.h"

Tenor::Tenor() {
	mName = 'Y';
	mNum = 0;
	mUnit = CYear;
}

Tenor::Tenor(const Tenor &src)
{
	mName = src.mName;
	mNum = src.mNum;
	mUnit = src.mUnit;
}

Tenor::Tenor(const string nameInput)
{
	string name = boost::to_upper_copy(nameInput);
	int length = name.length();
	mName = name[length-1];
	string numStr = name.substr(0, length-1);
	mNum = atoi(numStr.c_str());
	mUnit = getTenorUnitFromChar(mName);

}


double Tenor::years()
{
	return (double)mNum/(double)nominalPerYear(mUnit);
}

double Tenor::days()
{
	return years()*365.0;
}


int Tenor::nominalPerYear(TenorUnit unit)
{
	switch(unit) {

	case CYear:
		return 1;

	case Quarter:
		return 4;

	case Month:
		return 12;

	case Day:
		return 365;

	case BusinessDay:
		return 252;

	case Week:
		return 52;

	default:
		return 1;

	}
}

Tenor Tenor::sub(Tenor other)
{
	Tenor o1, o2;

	convertToSmallerUnit(*this, other, o1, o2);

	int num = o1.getNum() - o2.getNum();

	Tenor output(num, o1.getTenorUnit());

	return output;
}


void Tenor::convertToSmallerUnit(Tenor t1, Tenor t2, Tenor &o1, Tenor &o2)
{
	TenorUnit smallerUnit = nominalPerYear(t1.getTenorUnit()) > nominalPerYear(t2.getTenorUnit()) ? t1.getTenorUnit() : t2.getTenorUnit();

	o1 = (smallerUnit==t1.getTenorUnit()) ? t1 : convertToNewUnit(t1, smallerUnit);
	o2 = (smallerUnit==t2.getTenorUnit()) ? t2 : convertToNewUnit(t2, smallerUnit);

}


Tenor Tenor::convertToNewUnit(Tenor originalTenor, TenorUnit newUnit)
{
	double originalYears = originalTenor.years();
	int nominal = nominalPerYear(newUnit);

	int newCount = (int)(originalYears*nominal);

	Tenor output(newCount, newUnit);
	return output;
}
