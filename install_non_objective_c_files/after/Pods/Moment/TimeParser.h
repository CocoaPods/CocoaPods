//
//  TimeParser.h
//  NLDP
//
//  Created by Kevin Musselman on 6/28/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <time.h>
#include <limits.h>
#include <math.h>

#define DIGILEN (int)(log10 (INT_MAX) +3)


extern int yyparse();
extern char * yytext;
typedef struct yy_buffer_state *YY_BUFFER_STATE;
void yy_switch_to_buffer(YY_BUFFER_STATE);
YY_BUFFER_STATE yy_scan_string (const char *);

struct modifier
{
    int amount[9];
    int specAmount[3];
    int specValue[3];    
    
};

struct modifier mymodifier;
struct modifier fromModifier;

struct tm currentTime;

struct tm *str_time;
int *timePointer[7];

struct tm temp_time;
struct tm set_time;

time_t curtime;
time_t initialTime;


int changeAmount[9];
int fromChangeAmount[9];

int specAmount[3];
int finalSpecAmount[3];


void setCurrentTime(void);
void setTime(int hr, int min, int sec);
void setDate(int day, int month, int year, int wday);

void setBoth(int sec, int min, int hr, int day, int month, int year, int wday); 
char* join_strings(int* strings, char* seperator, int count);
void setDayOfWeek(int weekday, int *amount);
void setFinalTime(struct tm *temp, int amount[], int *change);
void itoa(int n, char s[]);

time_t parseDateTimeString(const char *str);
