#include "../Util/Exception.h"
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>

void Exception::raise(string location, string message)
{
	cerr << location << ": " << message << endl;
	exit(1);
}

void Exception::raise(string location, ostringstream message)
{
	cerr << location << ": " << message.str() << endl;
	exit(1);
}


void Exception::warning(string location, string message)
{
	cerr << location << ": " << message << endl;	
}

void Exception::exitWithError( const char * format_string, ... )
{
  va_list args;
  char message[512];

  va_start( args, format_string );
  vsprintf( message, format_string, args );
  printf( "\n\nERROR: %s \n", message );
  va_end( args );
  
  exit( -1 );
}


void Exception::validate(string location, bool condition, string message)
{
	if(!condition) {
		raise(location, message);
	}
}
