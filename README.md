# sleep-info
A bash script for macOS that details information about sleep: why, why not, when and what's preventing sleep.

![Screendump of sleep_info](https://fileadmin.cs.lth.se/cs/Personal/Peter_Moller/scripts/bilder/sleep_info_2025-06-02.png)

-----

Important components:
---------------------

The command `pmset` is used to gather information about sleep settings and also what prevents the computer form sleeping.

`syslog` is used to gather information about when and why the computer fell asleep/woke up. This requires, however, that the user is in the group `admin` or nothing will be found.
 
