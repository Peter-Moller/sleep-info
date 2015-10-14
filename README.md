# sleep-info
A bash script for OS X that details information about sleep: why, why not, when and what's preventing sleep

![Screendump of sleep_info](http://fileadmin.cs.lth.se/cs/Personal/Peter_Moller/scripts/bilder/sleep_info 2015-10-14.png)

More information about the script can be found here:
http://cs.lth.se/peter-moller/script/sleep-info-en/

-----

Important components:
---------------------

The command `pmset` is used to gather information about sleep settings and also what prevents the computer form sleeping.

`syslog` is used to gather information about when and why the computer fell asleep/woke up. This requires, however, that the user is in the group `admin` or nothing will be found.
