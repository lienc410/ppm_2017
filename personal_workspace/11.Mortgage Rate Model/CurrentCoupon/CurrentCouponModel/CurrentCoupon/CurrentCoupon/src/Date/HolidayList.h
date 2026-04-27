/*
 * HolidayList.h
 *
 *  Created on: Jul 2, 2013
 *      Author: Bin Shao
 */

#ifndef HOLIDAYLIST_H_
#define HOLIDAYLIST_H_

#include <vector>
#include <iostream>
#include <fstream>
#include <sstream>

using namespace std;

class CDate;

class HolidayList {
public:
	HolidayList();

	bool isHoliday(int serial);

	int gotoNextBusinessDay(int serial);
	int gotoPreviousBusinessDay(int serial);

private:
	vector<int> mList;
};

#endif /* HOLIDAYLIST_H_ */
