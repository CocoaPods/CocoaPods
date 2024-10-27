//
//  TimeParser.c
//  NLDP
//
//  Created by Kevin Musselman on 6/28/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#include "TimeParser.h"


void setCurrentTime()
{
    
    curtime = time(NULL);
    str_time= localtime(&curtime);
    
    timePointer[0] = &(str_time->tm_sec); 
    timePointer[1] = &(str_time->tm_min); 
    timePointer[2] = &(str_time->tm_hour); 
    timePointer[3] = &(str_time->tm_mday); 
    timePointer[4] = &(str_time->tm_wday);
    timePointer[5] = &(str_time->tm_mon);
    timePointer[6] = &(str_time->tm_year); 
    
    initialTime = time(NULL);
    temp_time = *(localtime(&initialTime));
    temp_time.tm_sec = -1;
    temp_time.tm_min = -1;
    temp_time.tm_hour = -1;
    temp_time.tm_mday = -1;
    temp_time.tm_wday = -1;
    temp_time.tm_mon = -1;
    temp_time.tm_year = -1;
    
    set_time.tm_sec = -1;
    set_time.tm_min = -1;
    set_time.tm_hour = -1;
    set_time.tm_mday = -1;
    set_time.tm_wday = -1;
    set_time.tm_mon = -1;
    set_time.tm_year = -1;
    
    fromModifier.specAmount[0] = mymodifier.specAmount[0] = finalSpecAmount[0] = specAmount[0] = 0;
    fromModifier.specAmount[1] = mymodifier.specAmount[1] = finalSpecAmount[1] = specAmount[1] = 0;
    fromModifier.specAmount[2] = mymodifier.specAmount[2] = finalSpecAmount[2] = specAmount[2] = 0;
    mymodifier.specValue[0] = -1;
    mymodifier.specValue[1] = -1;
    mymodifier.specValue[2] = -1;
    fromModifier.specValue[0] = -1;
    fromModifier.specValue[1] = -1;
    fromModifier.specValue[2] = -1;
    int len=sizeof(changeAmount)/sizeof(int);
    for(int i=0; i< len; i++)
    {
        changeAmount[i] = 0;
        fromChangeAmount[i] = 0;
        mymodifier.amount[i] = 0;
        fromModifier.amount[i] = 0;
    }
    
//    str_time->tm_year = 139;
//    time_t finalTime = mktime(str_time);    
//    str_time= localtime(&finalTime);
//    printf("after year change = %s\n", asctime(str_time));
    
}

void setTime(int sec, int min, int hr)
{
    str_time->tm_hour = hr;
    str_time->tm_min = min;
    str_time->tm_sec = sec;
}
void setDate(int day, int month, int year, int wday)
{
    str_time->tm_mday = day;
    str_time->tm_wday = wday;
    str_time->tm_mon = month;
    str_time->tm_year = year;
}

void setBoth(int sec, int min, int hr, int day, int month, int year, int wday)
{
    setDate(day, month, year, wday);
    setTime(sec, min, hr);
    
}

char* join_strings(int* strings, char* seperator, int count) {
    char* str = NULL;             /* Pointer to the joined strings  */
    char intstr[DIGILEN];
    size_t total_length = 0;      /* Total length of joined strings */
    int i = 0;                    /* Loop counter                   */
    
    /* Find total length of joined strings */
    
    
    for (i = 0; i < count; i++)
    {
        sprintf(intstr, "%d", strings[i]);   
        total_length += strlen(intstr);
    }
    total_length++;     /* For joined string terminator */
    total_length += strlen(seperator) * (count - 1); // for seperators
    
    str = (char*) malloc(total_length);  /* Allocate memory for joined strings */
    str[0] = '\0';                      /* Empty string we can append to      */
    
    /* Append all the strings */
    for (i = 0; i < count; i++) {
        sprintf(intstr, "%d", strings[i]);  
        strcat(str, intstr);
        if (i < (count - 1)) strcat(str, seperator);
    }
    
    return str;
}


void setFinalTime(struct tm *temp, int amount[], int *change)
{

//    printf("set final time BEFORE=  temp time= %s\n", asctime(str_time));   
    time_t tempTime = mktime(str_time);

    str_time= localtime(&tempTime);

    if(temp->tm_year >= 0)
    {
        str_time->tm_year = temp->tm_year;
        amount[2] = 0;
    }
    *timePointer[6] += change[6];
    
    tempTime = mktime(str_time);
        
    str_time= localtime(&tempTime);


    int mon = str_time->tm_mon;
    if(temp->tm_mon >= 0)
    {
        amount[2] = 0;
        if(temp->tm_mon >=12)
        {
            str_time->tm_mon = mon = temp->tm_mon-12;
            str_time->tm_year +=1;
            
        }
        else
        {
            if(str_time->tm_mon > temp->tm_mon && (temp->tm_year < 0 && change[6]==0))
            {
                if(amount[0] <= 0)
                    str_time->tm_year += (amount[0]+1);
                else  
                    str_time->tm_year += amount[0];                    
            }
            else if(str_time->tm_mon < temp->tm_mon)
            {
                if(amount[0] <= 0)
                    str_time->tm_year += (amount[0]);
                else  
                    str_time->tm_year += (amount[0]-1);
            }
            else if(str_time->tm_mon == temp->tm_mon)
            {
                str_time->tm_year += amount[0];  
            }
            str_time->tm_mon = mon = temp->tm_mon;
        }
   
    }
//    printf("set final time after=  temp time= %s\n", asctime(str_time));    
    
    *timePointer[5] += change[5];


    tempTime = mktime(str_time);
    str_time= localtime(&tempTime);
    
    if(str_time->tm_mon != (mon+change[5]))
        str_time->tm_mon = (mon+change[5]);
    

    /*******  change[7] is the number of weeks ******/
    if(change[7])
    {

        str_time->tm_mday += 7*change[7];
        str_time->tm_mday -= str_time->tm_wday;
        tempTime = mktime(str_time);
        str_time= localtime(&tempTime);
//             printf("main time after month/year change = %s\n", asctime(str_time));        
    }
    
    if(temp->tm_mday >=0)
    {
        if(change[7])
        {
            str_time->tm_mday += temp->tm_mday;
        }
        else
            str_time->tm_mday = temp->tm_mday;
        
        tempTime = mktime(str_time);
        str_time= localtime(&tempTime);
//        printf("the set day %d and is %s \n", temp->tm_mday, asctime(str_time));
    }
    if(amount[1]>0 && temp->tm_mday >=0 && temp->tm_wday <0) temp->tm_wday = 0;//str_time->tm_wday; 
    setDayOfWeek(temp->tm_wday, amount);

//    printf("amount2 = %d and change3 = %d", amount[2], change[3]);
    if(amount[2]!= 0  && change[3]==0)
    {
        switch(change[8])
        {
            case 'm':
            {
//                printf("in the morning");            
                if(temp->tm_hour >= 0)
                {
                    if((temp->tm_hour < str_time->tm_hour || (temp->tm_hour == str_time->tm_hour && temp->tm_min < str_time->tm_min)))
                        str_time->tm_mday += 1;
                        
                }
                else if(str_time->tm_hour > 12)
                    str_time->tm_mday += 1;
            }
            break;
            case 'a':
            {
//                printf("in the afternoon");
                if(temp->tm_hour >= 0)
                {
                    if((temp->tm_hour < str_time->tm_hour || (temp->tm_hour == str_time->tm_hour && temp->tm_min < str_time->tm_min)))
                        str_time->tm_mday += 1;
                    
                }
                else if(str_time->tm_hour > 17)
                    str_time->tm_mday += 1;
            }
            break;
            case 'e':
            {
//                printf("in the evening %d", temp->tm_hour);
                if(temp->tm_hour >= 0)
                {
                    if((temp->tm_hour < str_time->tm_hour || (temp->tm_hour == str_time->tm_hour && temp->tm_min < str_time->tm_min)))
                        str_time->tm_mday += 1;
                    
                }
                else if(str_time->tm_hour > 20)
                    str_time->tm_mday += 1;
            }    
            break;
            case 'n':
            {
            }    
            break;
            default:
                break;
        }
    }

    if(temp->tm_hour >= 0)
        str_time->tm_hour = temp->tm_hour;
    if(temp->tm_min >= 0)
        str_time->tm_min = temp->tm_min;
    if(temp->tm_sec >= 0)
        str_time->tm_sec = temp->tm_sec;
    
    
    change[6] = 0;
    change[5] = 0;
    
    for(int i=0; i<7; i++){
        *timePointer[i] += change[i];
    }
    tempTime = mktime(str_time);
    str_time= localtime(&tempTime);
    
    temp->tm_sec = -1;
    temp->tm_min = -1;
    temp->tm_hour = -1;
    temp->tm_mday = -1;
    temp->tm_wday = -1;
    temp->tm_mon = -1;
    temp->tm_year = -1;
    amount[0] = 0;
    amount[1] = 0;
    amount[2] = 0;
    

    for(int i=0; i< 9; i++)
    {
        change[i] = 0;
    }

    time_t finalTime = mktime(str_time);
    str_time= localtime(&finalTime);
}


void setDayOfWeek(int weekday, int *amount)
{

    if(weekday >= 0)
    {
//   printf("weekday = %d and amount = %d", weekday, amount[1]);
        amount[2] = 0;
        if(str_time->tm_wday > weekday)
        {
            int dif = str_time->tm_wday - weekday;
            if (amount[1]==0) {
                str_time->tm_mday += (7-dif);
            }
            else if(amount[1]>0)
            {
                str_time->tm_mday += (7-dif)+(amount[1]-1)*7;
            }
            else if(amount[1] < 0)
            {
                str_time->tm_mday += ((amount[1]+1)*7)-dif;
            }
            
        }
        else if(str_time->tm_wday < weekday)
        {
            int dif =  weekday - str_time->tm_wday;
            if (amount[1]==0) {
                str_time->tm_mday += dif;
            }
            else if(amount[1]>0)
            {
                str_time->tm_mday += (dif+(amount[1]-1)*7);
            }
            else if(amount[1] < 0)
            {
                str_time->tm_mday += (dif-7)+((amount[1]+1)*7);
            }
        }
        else if(str_time->tm_wday == weekday)
        {
            str_time->tm_mday += (amount[1]*7);  
        }
        
        str_time->tm_wday = weekday;
        time_t tempTime = mktime(str_time);
        str_time= localtime(&tempTime);
        
//        printf("the string after wday = %s \n ", asctime(str_time));
        
    }
    
}

/* reverse:  reverse string s in place */
static void reverse(char s[])
{
    int i, j;
    char c;
    
    for (i = 0, j = strlen(s)-1; i<j; i++, j--) {
        c = s[i];
        s[i] = s[j];
        s[j] = c;
    }
}

void itoa(int n, char s[])
{
    int i, sign;
    
    if ((sign = n) < 0)  /* record sign */
        n = -n;          /* make n positive */
    i = 0;
    do {       /* generate digits in reverse order */
        s[i++] = n % 10 + '0';   /* get next digit */
    } while ((n /= 10) > 0);     /* delete it */
    if (sign < 0)
        s[i++] = '-';
    s[i] = '\0';
    reverse(s);
}


time_t parseDateTimeString(const char *str)
{
    yy_switch_to_buffer(yy_scan_string(str));
    yyparse();
    time_t tempTime = mktime(str_time);
    str_time= localtime(&tempTime);
    
    
    setFinalTime(&set_time, finalSpecAmount, fromChangeAmount);
    
    tempTime = mktime(str_time);
    str_time= localtime(&tempTime);
    if(fromModifier.specValue[1])
    {
        setDayOfWeek(fromModifier.specValue[1], fromModifier.specAmount);
    }
    
    return mktime(str_time);
    
}
