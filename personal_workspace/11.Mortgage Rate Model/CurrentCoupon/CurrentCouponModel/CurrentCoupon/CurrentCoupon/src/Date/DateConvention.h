/*
 * DateConvention.h
 *
 *  Created on: Jul 2, 2013
 *      Author: Bin Shao
 */

#ifndef DATECONVENTION_H_
#define DATECONVENTION_H_

#include "../Date/HolidayList.h"


enum RollConvention {
	RollNone,
	RollForward,
	RollBackward,
	RollForwardModified,  // roll forward but go to the last business day of the month if reach the end of month
	RollBackwardModified  // roll back but go to the first business day of the month if reach the start of month

};



class DateConvention {
public:
	DateConvention();
	virtual ~DateConvention();

	DateConvention(HolidayList holidayList, RollConvention rollConvention)
	{
		mHolidayList = holidayList;
		mRollConvention = rollConvention;
	}


	RollConvention getRollConvention() { return mRollConvention; }
	HolidayList getHolidayList() { return mHolidayList; }

private:
	RollConvention mRollConvention;
	HolidayList mHolidayList;

};

#endif /* DATECONVENTION_H_ */
