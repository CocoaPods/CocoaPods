/* date convert #1 */


%{


#include <time.h>
#include "y.tab.h"

#define YY_NO_INPUT

extern time_t curtime;
extern struct tm temp_time;

extern struct tm *str_time;

void yyerror(char *);

void parseMonthDayStr(char *text, char *tok);
void parseDayMonthStr(char *text, char *tok);
void parseYearMonthDayStr(char *text, char *tok);

%}

%option nounput

dateTimeTerms    (sec(ond)?|min(ute)?|hour|hr|day|week|month|year)s?

regularTime     ((0?[1-9])|(1[1|2]))((:[0-5][0-9](" "?(a|p)\.?m\.?)?)|(" "?(a|p)\.?m\.?))
militaryTime    (([0-1][0-9])|([2][0-3])):?([0-5][0-9])
specificTimes   noon|midnight
generalTime     (morning|afternoon|evening|night)s?



months  (jan(uary|uaries)?|feb(ruary|ruaries)?|mar(ch|ches)?|apr(il)?|may|june?|jul(y|ies)?|aug(ust)?|sep(t)?(ember)?|oct(ober)?|nov(ember)?|dec(ember)?)(s?)\.?
days    sun|mon|tues|wed(nes)?|thurs|fri|sat(ur)?


genericNum    (([0][1-9])|([1][0-2])|([1-9]))
daydate       (([1][3-9])|([2][0-9])|(3[01]))
yeardate      ([12]([0-9]{3}))

setModifier             on



times                   {regularTime}|{militaryTime}
onDay                   (on)" "{days}(day)?



%%

in" "the          { return INTHE;  }
now               { return NOW;    };

tomorrow          { yylval.number = 8;  return DAYOFWEEK;   }
yesterday         { yylval.number = -1; return DAYOFWEEK;   }  
today             { yylval.number = 0;  return DAYOFWEEK;   }
from              { yylval.number = 1;  return FROM;        }
last              { yylval.number = -1; return LASTNEXT;    }
next              { yylval.number = 1;  return LASTNEXT;    }
ago|past          { yylval.number = -1; return HENCEAGO;    }
hence             { yylval.number = 1;  return HENCEAGO;    }
before            { yylval.number = -1; return BEFOREAFTER; }
after             { yylval.number = 1;  return BEFOREAFTER; }
in                { yylval.number = 1;  return IN;          }
this              { yylval.number = 0;  return THIS;        }



{dateTimeTerms}   { 
        switch(yytext[0])
        {
            case 's':
            {
                yylval.number=0;
            }
            break;
            case 'm':
            {
                if(yytext[1]=='i')
                    yylval.number=1;
                else
                    yylval.number = 5;
            }
            break;
            case 'h':
            {
                yylval.number=2;
            }
            break;
            case 'd':
            {
                yylval.number=3;
            }
            break;
            case 'w':
            {
                yylval.number=4;
            }
            break;
            case 'y':
            {
                yylval.number=6;
            }
            break;
        }
        return TYPENAMES;

}


{generalTime}      { 

        yylval.number = yytext[0];
        return GENERALTIME;

}
{specificTimes}   {
        if(yytext[0]=='m')
        {
            yylval.string= strdup("00:00");
        }
        else
        {
            yylval.string = strdup("12:00");
        }
        return WHENTIME;

    }

{regularTime}     { 
            
            int i, j=strlen(yytext);

            char apm[3] = ":am";
            for(i = 1; yytext[i] != '\0'; i++){
                if(yytext[i] == 'a'){
                    j = i;
                    break;
                }
                else if(yytext[i]== 'p')
                {
                    apm[1] = 'p';
                    j=i;
                    break;
                 
                }
            }
            

            char hr[j+4];
            
            strncpy(hr, yytext, j);
            hr[j] = '\0';
            strcat(hr, apm);

            yylval.string=strdup(hr); 
            return WHENTIME;  
}

{militaryTime}    {

            char *new = strdup(yytext);

            char hr[7] = "";
            strncat(hr, new, 2);
            hr[2] = ':';
            strncat(hr, &new[2], 2);

            hr[2] = ':';
            strncat(hr, &new[1], 2);
            hr[5] = '\0';

            yylval.string = strdup(hr);
            return MILITARYTIME;
        }
{onDay}           { yylval.string=strdup(yytext); return DAYOFWEEK; }
{months}          { 
                    switch(yytext[0])
                    {
                        case 'j':
                        {
                            if(yytext[1]=='a')
                            {
                                yylval.number=0; 
                            }
                            else if(yytext[2]=='n')
                            {
                                yylval.number=5;
                            }
                            else
                            {
                                yylval.number = 6;
                            }
                        }
                        break;
                        case 'f':
                            yylval.number=1;
                        break;
                        case 'm':
                        {
                            if(yytext[2]=='r')
                            {
                                yylval.number=2; 
                            }
                            else
                            {
                                yylval.number=4;
                            }
                        }
                        break;
                        case 'a':
                        {
                            if(yytext[1]=='p')
                            {
                                yylval.number=3; 
                            }
                            else
                            {
                                yylval.number=7;
                            }
                        }
                        break;                        
                        case 's':
                        {
                            yylval.number=8;
                        }
                        break;
                        case 'o':
                        {
                            yylval.number=9;
                        }
                        break;
                        case 'n':
                        {
                            yylval.number=10;
                        }
                        break;
                        case 'd':
                        {
                            yylval.number=11;
                        }
                        break;
                    }
                    return MONTHNUM;     
}

{days}(\.|days?)?      { 

                    switch(yytext[0])
                    {
                        case 's':
                        {
                            if(yytext[1]=='a')
                            {
                                yylval.number=7; 
                            }
                            else
                            {
                                yylval.number=1;
                            }
                        }
                        break;
                        case 'm':
                            yylval.number=2;
                        break;
                        case 't':
                        {
                            if(yytext[1]=='h')
                            {
                                yylval.number=5; 
                            }
                            else
                            {
                                yylval.number=3;
                            }
                        }
                        break;
                        case 'w':
                        {
                            yylval.number=4;
                        }
                        break;                        
                        case 'f':
                        {
                            yylval.number=6;
                        }
                        break;
                    }
                    return DAYOFWEEK;
                  }

{daydate}"/"{genericNum}"/"{yeardate}    {                      /***** ex. 23/05/2012  *****/
        parseDayMonthStr(yytext, "/");
        return SETDATE;
}

{genericNum}"/"{daydate}"/"{yeardate}      {                    /***** ex. 11/23/2011  *****/
        parseMonthDayStr(yytext, "/");
        return SETDATE;
}

{genericNum}"/"{genericNum}"/"{yeardate}    {                   /***** ex. 11/11/2012  *****/
        parseMonthDayStr(yytext, "/");
        return SETDATE;
}
{daydate}"-"{genericNum}"-"{yeardate}    {                      /***** ex. 23-05-2012  *****/
        parseDayMonthStr(yytext, "-");
        return SETDATE;
}

{genericNum}"-"{daydate}"-"{yeardate}      {                    /***** ex. 11-23-2011  *****/
        parseMonthDayStr(yytext, "-");
        return SETDATE;
}

{genericNum}"-"{genericNum}"-"{yeardate}    {                   /***** ex. 11-11-2012  *****/
        parseMonthDayStr(yytext, "-");
        return SETDATE;
}

{yeardate}"/"{genericNum}"/"({genericNum}|{daydate})    {                   /***** ex. 2012/11/11  *****/
    parseYearMonthDayStr(yytext, "/");
    return SETDATE;
}

{yeardate}"-"{genericNum}"-"({genericNum}|{daydate})    {                   /***** ex. 2012-11-11  *****/
    parseYearMonthDayStr(yytext, "-");
    return SETDATE;
}

[0-9]+(st|nd|rd|th)  {
        size_t thesize = strlen(yytext)-2;
        char *to = (char*) malloc(thesize);
        strncpy(to, yytext, thesize);
        yylval.number=atoi(to); 

        return DTPOSITION;
}

[0-9]+      {
        
        yylval.number= atoi(yytext);
        return INTEGER;
}




at|@    {yylval.string = yytext; return ARTICLEPREP; } 
the         ;
[ \t,]       ;       /* skip whitespace */
\+|plus       { yylval.number = 1; return PLUS;}


.           yyerror("Unknown character");

%%

void parseMonthDayStr(char *text, char *tok)
{

    char *parts = strtok(yytext, tok);
    temp_time.tm_mon= atoi(parts)-1;
    parts = strtok (NULL, tok);
    if(parts != NULL)
    {
        temp_time.tm_mday = atoi(parts);
        parts = strtok (NULL, tok);        
        if(parts != NULL)
            temp_time.tm_year = atoi(parts)-1900;
    }
}
void parseDayMonthStr(char *text, char *tok)
{

    char *parts = strtok(yytext, tok);
    temp_time.tm_mday= atoi(parts);
    parts = strtok (NULL, tok);
    if(parts != NULL)
    {
        temp_time.tm_mon = atoi(parts)-1;
        parts = strtok (NULL, tok);        
        if(parts != NULL)
            temp_time.tm_year = atoi(parts)-1900;
    }
}

void parseYearMonthDayStr(char *text, char *tok)
{

    char *parts = strtok(yytext, tok);
    temp_time.tm_year= atoi(parts)-1900;
    parts = strtok (NULL, tok);
    if(parts != NULL)
    {
        temp_time.tm_mon = atoi(parts)-1;
        parts = strtok (NULL, tok);        
        if(parts != NULL)
            temp_time.tm_mday = atoi(parts);
    }
}
int yywrap(void) {
    return 1;
}
