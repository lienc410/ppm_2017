#ifndef TENOR_H_
#define TENOR_H_

#include <string>
#include "../Date/TenorUnit.h"
using namespace std;

class Tenor {
public:
	Tenor();
	Tenor(const Tenor &src);
	Tenor(const string name);
	Tenor(int num, TenorUnit unit) { mNum = num; mUnit = unit; }

	int getNum() { return mNum; }
	char getName() { return mName; }
	TenorUnit getTenorUnit() { return mUnit; }
	Tenor sub(Tenor other);


	double years();
	double days();

	int nominalPerYear(TenorUnit unit);

	void convertToSmallerUnit(Tenor t1, Tenor t2, Tenor &o1, Tenor &o2);

	Tenor convertToNewUnit(Tenor original, TenorUnit newUnit);

private:
	char mName;
	int mNum;
	TenorUnit mUnit;


};

#endif /* TENOR_H_ */
