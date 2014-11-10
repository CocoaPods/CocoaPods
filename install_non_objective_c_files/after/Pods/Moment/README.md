Moment
======

Natural Language Date/Time Parser Using Lex/Yacc/C  

Moment handles simple and complex expressions.  Because it's written in C, it can easily be transferred to many other languages. 
<pre>
To use it:
Add the 4 files to your project.
Include "TimeParser.h"
Then call the method parseDateTimeString(StringToParse), which returns a time_t type.  
You can then turn it into struct tm * with the localtime function. 
</pre>

Here is what it looks like in objective c:<br/>
<code>
NSString *when = @"2 days from now at 3pm";<br/>
char *whenstr = (char *)[when UTF8String];<br/>
time_t finalTime = parseDateTimeString(whenstr);<br/>
str_time= localtime(&finalTime);<br/>
</code>

To get it to work in x-code all you have to do is add the files. X code automatically generates the C files for you.

<h3>Example Expressions:</h3>

<h4>Simple</h4>
<ul>


<li>thursday</li>
<li>november</li>
<li>friday 13:00</li>
<li>mon 2:35</li>
<li>4pm</li>
<li>6 in the morning</li>
<li>friday 1pm</li>
<li>sat 7 in the evening</li>
<li>yesterday</li>
<li>today</li>
<li>tomorrow</li>
<li>this tuesday</li>
<li>next month</li>
<li>this morning</li>
<li>last night</li>
<li>this second</li>
<li>yesterday at 4:00</li>
<li>last friday at 20:00</li>
<li>last week tuesday</li>
<li>tomorrow at 6:45pm</li>
<li>afternoon yesterday</li>
<li>thursday last week</li>

</ul>
<h4>Complex</h4>
<ul>
<li>3 years ago</li>
<li>5 months before now</li>
<li>7 hours ago</li>
<li>7 days from now</li>
<li>1 week hence</li>
<li>in 3 hours</li>
<li>1 year ago tomorrow</li>
<li>3 months ago saturday at 5:00 pm</li>
<li>7 hours before tomorrow at noon</li>
<li>3rd wednesday in november</li>
<li>3rd month next year</li>
<li>3rd thursday this september</li>
<li>4th day last week</li>
</ul>

<h4>Specific Dates</h4>
<ul>
<li>January 5</li>
<li>dec 25</li>
<li>may 27th</li>
<li>October 2006</li>
<li>jan 3 2010</li>
<li>March 14, 2004</li>
<li>March 14th, 2004</li>
<li>3 jan 2000</li>
<li>17 april 85</li>
<li>5/27/1979</li>
<li>27/5/1979</li>
<li>1979-05-27</li>
<li>Friday</li>
<li>5</li>
<li>4:00</li>
<li>17:00</li>
<li>0800</li>
</ul>
