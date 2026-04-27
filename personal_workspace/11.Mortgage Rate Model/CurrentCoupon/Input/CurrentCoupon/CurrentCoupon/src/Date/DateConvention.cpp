/*
 * DateConvention.cpp
 *
 *  Created on: Jul 2, 2013
 *      Author: Bin Shao
 */

#include "DateConvention.h"

DateConvention::DateConvention() {

	HolidayList holidayList;

	DateConvention(holidayList, RollForwardModified);

}

DateConvention::~DateConvention() {
	// TODO Auto-generated destructor stub
}

