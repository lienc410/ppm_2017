#ifndef TENORUNIT_H
#define TENORUNIT_H

enum TenorUnit {

	CYear,
	Quarter,
	Month,
	Week,
	BusinessDay,
	Day,
	UnDefined

};

static char getTenorCharFromEnum(TenorUnit u)
{
	switch(u)
	{
	case CYear: return 'Y';
	case Quarter: return 'Q';
	case Month: return 'M';
	case Week: return 'W';
	case BusinessDay: return 'B';
	case Day: return 'D';
	case UnDefined:
	default: return 'X';
	}

}


static TenorUnit getTenorUnitFromChar(char name)
{
	switch(name) {

	case 'Y': return CYear;
	case 'Q': return Quarter;
	case 'M': return Month;
	case 'W': return Week;
	case 'B': return BusinessDay;
	case 'D': return Day;
	case 'X':
	default: return UnDefined;
	}

}



#endif
