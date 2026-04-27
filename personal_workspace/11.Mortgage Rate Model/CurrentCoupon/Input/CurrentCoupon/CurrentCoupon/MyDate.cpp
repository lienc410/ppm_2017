// CurrentCouponRate.cpp : Defines the entry point for the console application.
//

#include "MyDate.h"

int Date::DayOfMonth(int y,int m)const  
{  
    int d = 0;  
    switch(m)  
    {  
    case 1:  
    case 3:  
    case 5:  
    case 7:  
    case 8:  
    case 10:  
    case 12:  
        d = 31;  
        break;  
    case 4:  
    case 6:  
    case 9:  
    case 11:  
        d = 30;  
        break;  
    case 2:  
        d = 28 + IsLeapyear(y);  
        break;  
    }  
    return d;  
}  
int Date::ToInt()const  
{  
    int sum =0;  
    for(int y=1;y<year;++y)  
    {  
        sum += 365+IsLeapyear(y);  
    }  
    for(int m=1;m<month;++m)  
        sum += DayOfMonth(year,m);  
    sum += day;  
    return sum;  
}  

Date operator + (const int v,const Date a)  
{  
    Date d = a;  
    if(v==0) return d;
    if(v>0) 
    {  
        d.day += v;    
        while(d.day>d.DayOfMonth(d.year,d.month))
        {  
            d.day -= d.DayOfMonth(d.year,d.month);  
            d.month++; 
            if(d.month>12)                  
            {  
                ++d.year;  
                d.month = 1;  
            }  
        }  
        return d;  
    }  
    else  
        return d-(-v);  
}  
 
Date operator +(const Date a,const int v)  
{  
    Date d = a;  
    if(v==0) return d;  
    if(v>0)  
    {  
        d.day += v;  
        while(d.day>d.DayOfMonth(d.year,d.month))  
        {  
            d.day -= d.DayOfMonth(d.year,d.month);  
            d.month++;  
            if(d.month>12)  
            {  
                ++d.year;  
                d.month = 1;  
            }  
        }  
        return d;  
    }  
    else  
        return d-(-v);  
}  

Date operator +=(Date &a,const int v)  
{  
    if(v==0) return a;  
    if(v>0)  
    {  
        a.day+=v;  
        while(a.day>a.DayOfMonth(a.year,a.month))  
        {  
            a.day -= a.DayOfMonth(a.year,a.month);  
            a.month++;  
            if(a.month>12)  
            {  
                ++a.year;  
                a.month = 1;  
            }  
        }  
        return a;  
    }  
    else  
        return a-=(-v);  
}  

Date operator ++(Date &a)  
{  
    ++a.day;  
    if(a.day>a.DayOfMonth(a.year,a.month))  
    {  
        a.day-=a.DayOfMonth(a.year,a.month);  
        a.month++;  
        if(a.month>12)  
        {  
            ++a.year;  
            a.month = 1;  
        }  
    }  
    return a;  
}  
  

Date operator ++(Date &a,int)  
{  
    Date d = a;  
    ++a.day;  
    if(a.day>a.DayOfMonth(a.year,a.month))  
    {  
        a.day-=a.DayOfMonth(a.year,a.month);  
        a.month++;  
        if(a.month>12)  
        {  
            ++a.year;  
            a.month = 1;  
        }  
    }  
    return d;  
}  

Date operator - (const Date a,const int v)  
{  
    Date d = a;  
    if(v==0) return d;  
    if(v>0)  
    {  
        d.day -= v;  
        while(d.day<=0)  
        {  
            --d.month;  
            if(d.month==0)  
            {  
                d.month=12;  
                --d.year;  
            }  
            d.day+=d.DayOfMonth(d.year,d.month);  
        }  
        return d;  
    }  
    else  
        return d+(-v);  
}  
int operator - (const Date a,const Date b)  
{  
    return a.ToInt()-b.ToInt();  
}  
Date operator -=(Date &a,const int v)  
{  
    if(v==0) return a;  
    if(v>0)  
    {  
        a.day -= v;  
        while(a.day<=0)  
        {  
            --a.month;  
            if(a.month==0)  
            {  
                a.month=12;  
                --a.year;  
            }  
            a.day+=a.DayOfMonth(a.year,a.month);  
        }  
        return a;  
    }  
    else  
        return a+=(-v);  
}  
Date operator --(Date &a)  
{  
    --a.day;  
    while(a.day<=0)  
    {  
        --a.month;  
        if(a.month==0)  
        {  
            a.month = 12;  
            --a.year;  
        }  
        a.day += a.DayOfMonth(a.year,a.month);  
    }  
    return a;  
}  
Date operator --(Date &a,int)  
{  
    Date d = a;  
    --a.day;  
    while(a.day<=0)  
    {  
        --a.month;  
        if(a.month==0)  
        {  
            a.month = 12;  
            --a.year;  
        }  
        a.day += a.DayOfMonth(a.year,a.month);  
    }  
    return d;  
}  

bool operator > (const Date a,const Date b)  
{  
    return a.ToInt()>b.ToInt();  
}  
bool operator >=(const Date a,const Date b)  
{  
    return a.ToInt()>=b.ToInt();  
}  
bool operator < (const Date a,const Date b)  
{  
    return a.ToInt()<b.ToInt();  
}  
bool operator <=(const Date a,const Date b)  
{  
    return a.ToInt()<=b.ToInt();  
}  
bool operator ==(const Date a,const Date b)  
{  
    return a.ToInt()==b.ToInt();  
}  
bool operator !=(const Date a,const Date b)  
{  
    return a.ToInt()!=b.ToInt();  
}  
/*std::ostream & operator <<(std::ostream &os,const Date &d) 
{ 
    os<<d.year<<"-"<<d.month<<"-"<<d.day; 
    return os; 
} 
std::istream & operator >>(std::istream &is,Date &d) 
{ 
    Date old = d; 
    is>>d.year>>d.month>>d.day; 
    if((d.year<=0) ||(d.month>12||d.month<=0) || (d.day<=0||d.day>d.DayOfMonth(d.year,d.month))) 
    { 
        d = old; 
        throw std::exception("Invalid number of date."); 
    } 
    return is; 
} 
*/  