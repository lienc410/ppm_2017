#ifndef EXCEPTION_H
#define EXCEPTION_H
#include <stdio.h>
#include <iostream>
#include <string>
#include <sstream>
using namespace std;

class Exception 
{
public:
	static void raise(string location, string message);
	static void raise(string location, ostringstream message);
	static void warning(string location, string message);
	static void exitWithError( const char * format_string, ... );
	static void validate(string location, bool condition, string message);
};



#endif