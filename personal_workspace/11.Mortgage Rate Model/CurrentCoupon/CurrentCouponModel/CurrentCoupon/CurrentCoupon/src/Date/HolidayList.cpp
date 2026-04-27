/*
 * HolidayList.cpp
 *
 *  Created on: Jul 2, 2013
 *      Author: Bin Shao
 */
#include "../Date/Date.h"
#include "../Date/HolidayList.h"

HolidayList::HolidayList() {

	string filePath = "S:\\IT\\BB_SPAPI\\cmo_model_dat\\";
	string fileName = filePath + "US.CAL";
	vector<int> yyyymmdd;
	ifstream ifile(fileName);
	int listSize = 0;

	if (ifile)
	{
		stringstream ss;
		ss << fileName;
		char line[256];
		
		int count = 0;
		int lineSize = 8;
		 
		while (ifile.good()) {
			yyyymmdd.resize(1000);
			mList.resize(1000);
			ifile.getline(line, 256);
			string s(line);
			if (s.size() == lineSize) {
				for (int i = 0; i < lineSize; i++)
					if(line[i] == ' ' || line[i] == '\n' )
						goto NEXT;
				yyyymmdd[count] = atoi(s.c_str());

				int yyyy = yyyymmdd[count]/10000;
				int mm = yyyymmdd[count]/100 - yyyy*100;
				int dd = yyyymmdd[count] - yyyy*10000 - mm*100;

				CDate aDate(yyyy, mm, dd);
				mList[count] = aDate.getSerial();

				count++;
			}
			NEXT:;
		}
		ifile.close();

		listSize = count;
	}

	/*
	for (int i = 0; i < listSize; i++)
	{
		cout << yyyymmdd[i] << endl;
		cout << mList[i] << endl;
	}
	*/
}


bool HolidayList::isHoliday(int serial) {

	bool found = false;

	for (vector<int>::iterator it = mList.begin(); it != mList.end(); it++) {
		if (*it == serial) {
			found = true;
			break;
		}
	}

	return found;

}

int HolidayList::gotoNextBusinessDay(int serial) {
	for (vector<int>::iterator it = mList.begin(); it != mList.end(); it++) {
		if (*it > serial) {
			return *it;
		}
	}

	return serial;
}

int HolidayList::gotoPreviousBusinessDay(int serial) {
	size_t i = 0;
	for (; i < mList.size(); i++) {
		if (mList[i] >= serial) {
			break;
		}
	}

	if (i == 0)
		return serial;
	else
		return mList[i - 1];

}
