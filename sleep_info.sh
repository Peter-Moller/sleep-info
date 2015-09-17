#!/bin/bash

# Show information regarding sleep of Mac OS X Computers
# 
# Copyright 2015 Peter Möller, Dept of Copmuter Science, Lund University
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#     http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# Last change: 2015-01-18
# Requires OS X 10.10
# Version: 2.5


# Good source of information
# https://developer.apple.com/library/Mac/documentation/IOKit/Reference/IOPMLib_header_reference/index.html
 # (IOPMLib provides access to common power management facilities, like initiating system sleep, getting 
 # current idle timer values, registering for sleep/wake notifications, and preventing system sleep)

function usage()
{
cat << EOF
Usage: $0 options

This script displays information regarding your Macs sleep.

OPTIONS:
  -h      Show this message
  -u      Upgrade the script
  -s      Short version (no info about when/why the computer slept/woke)
EOF
}

fetch_new=f
PMSET="/tmp/pmset.txt"
TempFile1="/tmp/sleep_info_temp1.txt"
TempFile2="/tmp/sleep_info_temp2.txt"
TempFile3="/tmp/sleep_info_temp3.txt"
SysLogTemp="/tmp/syslog_temp"
short="f"
VER="2.5"

while getopts "hus" OPTION
do
    case $OPTION in
        h)  usage
            exit 1;;
        u)  fetch_new=t;;
        s)  short=t;;
        *)  usage
            exit;;
    esac
done


# Find where the script resides (so updates update the correct version) -- without trailing slash
DirName="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
# What is the name of the script? (without any PATH)
ScriptName="$(basename $0)"
# Is the file writable?
if [ -w "${DirName}"/"${ScriptName}" ]; then
  Writable="yes"
else
  Writable="no"
fi
# Who owns the script?
ScriptOwner="$(ls -ls ${DirName}/${ScriptName} | awk '{print $4":"$5}')"

# Find out which system version we are running
SW_VERS="$(sw_vers -productName) $(sw_vers -productVersion)"
ComputerName="$(networksetup -getcomputername)"

# Find out if it's a server
# First step: does the name fromsw_vers include "server"?
if [ -z "$(echo "$SW_VERS" | grep -i server)" ]; then
  # If not, it may still be a server. Beginning with OS X 10.8 all versions include the command serverinfo:
  serverinfo --software 1>/dev/null
  # Exit code 0 = server; 1 = NOT server
  ServSoft=$?
  if [ $ServSoft -eq 0 ]; then
    # Is it configured?
    serverinfo --configured 1>/dev/null
    ServConfigured=$?
    if [ $ServConfigured -eq 0 ]; then
      SW_VERS="$SW_VERS ($(serverinfo --productname) $(serverinfo --shortversion))"
    else
      SW_VERS="$SW_VERS ($(serverinfo --productname) $(serverinfo --shortversion) - unconfigured)"
    fi
  fi
fi


# Update [and quit]
# Check for update
function CheckForUpdate() {
  NewScriptAvailable=f
  # First, download the script from the server
  /usr/bin/curl -s -f -e "$ScriptName ver:$VER" -o /tmp/"$ScriptName" http://fileadmin.cs.lth.se/cs/Personal/Peter_Moller/scripts/"$ScriptName" 2>/dev/null
  /usr/bin/curl -s -f -e "$ScriptName ver:$VER" -o /tmp/"$ScriptName".sha1 http://fileadmin.cs.lth.se/cs/Personal/Peter_Moller/scripts/"$ScriptName".sha1 2>/dev/null
  ERR=$?
  # Find, and print, errors from curl (we assume both curl's above generate the same errors, if any)
  if [ "$ERR" -ne 0 ] ; then
  	# Get the appropriate error message from the curl man-page
  	# Start with '       43     Internal error. A function was called with a bad parameter.'
  	# end get it down to: ' 43: Internal error.'
  	ErrorMessage="$(MANWIDTH=500 man curl | egrep -o "^\ *${ERR}\ \ *[^.]*." | perl -pe 's/[0-9](?=\ )/$&:/;s/  */ /g')"
    echo $ErrorMessage
    echo "The file \"$ScriptName\" could not be fetched from \"http://fileadmin.cs.lth.se/cs/Personal/Peter_Moller/scripts/$ScriptName\""
  fi
  # See if the downloaded script checks out 
  # Compare the checksum of the script with the fetched sha1-sum
  # If they diff, something went wrong in the download
  # Then, check if the downloaded script differs from the current
  if [ "$(openssl sha1 /tmp/"$ScriptName" | awk '{ print $2 }')" = "$(less /tmp/"$ScriptName".sha1)" ]; then
    if [ -n "$(diff /tmp/"$ScriptName" "$DirName"/"$ScriptName" 2> /dev/null)" ] ; then
      NewScriptAvailable=t
    fi
  else
    CheckSumError=t
  fi
  }


# Update [and quit]
function UpdateScript() {
  CheckForUpdate
  if [ "$CheckSumError" = "t" ]; then
    echo "Checksum of the fetched \"$ScriptName\" does NOT check out. Look into this! No update performed!"
    exit 1
  fi
  # If new script available, update
  if [ "$NewScriptAvailable" = "t" ]; then
    # But only if the script is writable!
    if [ "$Writable" = "yes" ]; then
      /bin/rm -f "$DirName"/"$ScriptName" 2> /dev/null
      /bin/mv /tmp/"$ScriptName" "$DirName"/"$ScriptName"
      chmod 755 "$DirName"/"$ScriptName"
      /bin/rm /tmp/"$ScriptName".sha1 2>/dev/null
      echo "A new version of \"$ScriptName\" was installed successfully!"
      echo "Script updated. Exiting"

      # Send a signal that someone has updated the script
      # This is only to give me feedback that someone is actually using this. I will *not* use the data in any way nor give it away or sell it!
      /usr/bin/curl -s -f -e "$ScriptName ver:$VER" -o /dev/null http://fileadmin.cs.lth.se/cs/Personal/Peter_Moller/scripts/updated 2>/dev/null
      exit 0
    else
      echo "Script cannot be updated!"
      echo "It is located in \"$DirName\" and is owned by \"$ScriptOwner\""
      echo "You need to sort this out yourself!!"
      echo "Exiting..."
      exit 1
    fi
  else
    echo "You already have the latest version of \"$ScriptName\"!"
    exit 0
  fi
  }


# First: see if we should update the script
[[ "$fetch_new" = "t" ]] && UpdateScript


# (Colors can be found at http://en.wikipedia.org/wiki/ANSI_escape_code, http://graphcomp.com/info/specs/ansi_col.html and other sites)
Reset="\e[0m"
ESC="\e["
RES="0"
BoldFace="1"
ItalicFace="3"
UnderlineFace="4"
SlowBlink="5"
BlackBack="40"
RedBack="41"
YellowBack="43"
BlueBack="44"
WhiteBack="47"
BlackFont="30"
RedFont="31"
GreenFont="32"
YellowFont="33"
BlueFont="34"
CyanFont="36"
WhiteFont="37"

# Reset all colors
BGColor="$RES"
Face="$RES"
FontColor="$RES"

# Print a warning if you run older than 10.10
if [ $(sw_vers -productVersion | cut -d\. -f2) -lt 10 ]; then
	printf "${ESC}${BlackBack};${YellowFont}mThis script is written for OS X 10.10. Beware that it may not work correctly on your system${Reset}\n"
	echo
fi

pmset -g assertions > "$PMSET"
chmod 666 "$PMSET"

# Find out if we are running on 'AC Power' och 'Battery Power'
PowerKind="$(pmset -g ps | awk -F\' '{print $2}')"
# If we are on battery, also report status
if [ -n "$(pmset -g batt | egrep -o [0-9]*%.*charg.*$)" ]; then
	BatteryPowerText=" ($(pmset -g batt | egrep -o [0-9]*%.*charg.*$))"
	# Example: '99%; discharging; 4:38 remaining'
fi
PowerKind="${PowerKind}${BatteryPowerText}"


# Find out why it did fall asleep before
function WhyDidItFallAsleep()
{
	PreviousSleepLine="$(/usr/bin/grep ": System Sleep " $SysLogTemp | tail -1)"
	# PreviousSleepLine='Dec  6 22:21:17 Peters-iMac kernel[0] <Notice>: ARPT: 11790.119234: AirPort_Brcm43xx::powerChange: System Sleep '
	#                     1   2     3         4         5          6       7         8                    9                   10     11
	# Jan  9 23:18:44 Magnus-Anderssons-MacBook-Pro kernel[0] <Debug>: Previous Sleep Cause: 0
	PreviousSleepCause="$(/usr/bin/grep -i "Previous Sleep Cause" $SysLogTemp | tail -1 | awk '{print $NF}')"
	PreviousSleepTime="$(echo $PreviousSleepLine | awk '{print $1" "$2" "$3}')"

	case $PreviousSleepCause in
		1)  PreviousSleepReason="Clamshell Sleep (kIOPMClamshellSleepKey)";;
		2)  PreviousSleepReason="Power Button Sleep (kIOPMPowerButtonSleepKey)";;
		3)  PreviousSleepReason="Software Sleep (kIOPMSoftwareSleepKey)";;
		4)  PreviousSleepReason="OS Switch Sleep (kIOPMOSSwitchHibernationKey)";;
		5)  PreviousSleepReason="Idle Sleep (kIOPMIdleSleepKey)";;
		6)  PreviousSleepReason="Low Power Sleep (kIOPMLowPowerSleepKey)";;
		7)  PreviousSleepReason="Thermal Emergency Sleep (kIOPMThermalEmergencySleepKey)";;
		8)  PreviousSleepReason="Maintenance Sleep (kIOPMMaintenanceSleepKey)";;
		*)  PreviousSleepReason="Unknown"
	esac
}

# Find out why it did wake
function WhyDidItWake()
{
	################################################
	### Find out why the computer woke up
	################################################
	WakeLine="$(/usr/bin/grep -i ">: Wake reason" $SysLogTemp | tail -1)"
	# Example of wake:
	# Jan 12 17:02:47 peter-pc kernel[0] <Debug>: Wake reason: UHC2
	#  1   2     3       4        5         6      7      8      9
	# Dec  4 20:57:04 Peters-iMac kernel[0] <Notice>: Wake reason: XHC1
	# Dec  5 14:27:54 Peters-iMac kernel[0] <Notice>: Wake reason: XHC1
	# Dec  5 16:16:01 Peters-iMac kernel[0] <Notice>: Wake reason: RTC (Alarm)
	# Dec  5 16:47:15 Peters-iMac kernel[0] <Notice>: Wake reason: GIGE (Network)
	# Dec  5 19:09:18 Peters-iMac kernel[0] <Notice>: Wake reason: RTC (Alarm)
	# Dec  5 19:10:19 Peters-iMac kernel[0] <Notice>: Wake reason: GIGE (Network)
	# Dec  5 19:45:07 Peters-iMac kernel[0] <Notice>: Wake reason: GIGE (Network)

	# Example of Dark Wake:
	# Jan 16 00:52:44 Eva-Magnussons-MacBook-Pro-old kernel[0] <Debug>: Wake reason: RTC (Alarm)
	# Jan 16 00:52:44 Eva-Magnussons-MacBook-Pro-old kernel[0] <Debug>: AirPort_Brcm43xx::powerChange: System Wake - Full Wake/ Dark Wake / Maintenance wake
	#  1   2     3                   4                  5         6                7                        8      9  10   11    12   13  14    15       16
	# Jan 16 01:53:07 Eva-Magnussons-MacBook-Pro-old kernel[0] <Debug>: Wake reason: RTC (Alarm)
	#  1   2     3                   4                  5         6      7     8      9     10
	# Jan 16 01:53:07 Eva-Magnussons-MacBook-Pro-old kernel[0] <Debug>: AirPort_Brcm43xx::powerChange: System Wake - Full Wake/ Dark Wake / Maintenance wake
	# Jan 16 02:53:30 Eva-Magnussons-MacBook-Pro-old kernel[0] <Debug>: Wake reason: RTC (Alarm)
	# Jan 16 02:53:30 Eva-Magnussons-MacBook-Pro-old kernel[0] <Debug>: AirPort_Brcm43xx::powerChange: System Wake - Full Wake/ Dark Wake / Maintenance wake
	# Jan 16 03:53:53 Eva-Magnussons-MacBook-Pro-old kernel[0] <Debug>: Wake reason: RTC (Alarm)
	# Jan 16 03:53:53 Eva-Magnussons-MacBook-Pro-old kernel[0] <Debug>: AirPort_Brcm43xx::powerChange: System Wake - Full Wake/ Dark Wake / Maintenance wake
	# 
	# Good article: http://www.cnet.com/news/how-to-find-system-wake-causes-in-os-x/
	# Also:         http://www.opensource.apple.com/source/xnu/xnu-2422.1.72/iokit/IOKit/pwr_mgt/RootDomain.h
	
	WakeReasonTime="$(echo $WakeLine | awk '{print $1" "$2" "$3}')"
	WakeReason="$(echo $WakeLine | sed 's/^.*>: Wake reason: //g' | awk '{print $1}')"
	case "${WakeReason/[0-9]/}" in
		OHC)  WakeReasonText="Open Host Controller, is usually USB or Firewire";;
		EHC)  WakeReasonText="Enhanced Host Controller, another USB interface, can also be wireless/bluetooth";;
		USB)  WakeReasonText="a USB device";;
		UHC)  WakeReasonText="a USB device";;
		LID0) WakeReasonText="the lid of your was opened";;
		PWRB) WakeReasonText="the physical power button on your Mac";;
		RTC)  WakeReasonText="Real Time Clock Alarm; generally from a scheduled sleep/wake.";;
		XHC)  WakeReasonText="a BlueTooth-device is waking your computer";;
		GIGE) WakeReasonText="Ethernet network connection";;
		EC.PowerButton) WakeReasonText="The user pressed the power button";;
		*)    WakeReasonText="Unknown cause"
	esac
}

# Find out information about PreventSystemSleep
function What_Prevents_System_Sleep()
{
	# Find out if something is denying system sleep
	PreventSystemSleep="$(/usr/bin/pmset -g assertions | grep "^\ *PreventSystemSleep\ *[01]$" | awk '{print $2}')"
	# If so, report all such instances
	if [ $PreventSystemSleep -eq 1 ]; then
		# 'pmset -g assertions | grep DenySystemSleep'
		# '  pid 26(configd): [0x000543f7000724b7] 00:00:22 DenySystemSleep named: "InternetSharingPreferencePlugin" '
		#     1      2                   3             4            5         6                   7
		echo "• System sleep is prevented by:"
		/usr/bin/pmset -g assertions | grep DenySystemSleep | awk '{print $2" "$7}' | sed -e 's/(/ /' -e 's/):/ /' | tr -d \" > $TempFile1
		exec 7<$TempFile1
		while read -u 7 ProcID ProcName ClearText
		do
			echo "  - \"$ProcName\" (pid ${ProcID}, run by \"$(ps -p ${ProcID} -o user | grep -v USER)\"), reason: \"$ClearText\"" 
		done
		rm $TempFile1
	else
		#echo "• Nothing is preventing manually initiated system sleep"
		echo "• Manually initiated system sleep is not prevented by anything"
	fi
}

# Find out information about PreventUserIdleSystemSleep
function What_Prevents_User_Idle_System_Sleep()
{
	PreventUserIdleSystemSleep="$(/usr/bin/pmset -g | grep -v "NSURLSessionTask" | grep "^\ *sleep\ *" | egrep "sleep prevented by ")"
	if [ -n "$PreventUserIdleSystemSleep" ]; then
		echo "• Idle sleep is prevented by:"
		# Get a list of processes that prevent sleep.
		# For OS X 10.10:
		# pmset -g assertions | grep "PreventUserIdleSystemSleep named:"
   		# pid 265(coreaudiod): [0x00022bca000115ea] 00:00:46 PreventUserIdleSystemSleep named: "com.apple.audio.context718.preventuseridlesleep" 
   		# pid 39176(iTunes): [0x00022bca00011660] 00:00:46 PreventUserIdleSystemSleep named: "com.apple.iTunes.playback" 
   		# pid 39215(AddressBookSour): [0x000228fd00011641] 00:00:11 PreventUserIdleSystemSleep named: "Address Book Source Sync" 
   		# pid 258(nsurlsessiond): [0x0000581000011051] 00:00:00 PreventUserIdleSystemSleep named: "NSURLSessionTask EB62463F-8223-4C70-9EE6-00582953147D" 
   		# pid 90178(uTorrent): [0x00001d8e00010781] 02:11:05 NoIdleSleepAssertion named: "there are active torrents" 
   		# pid 28(powerd): [0x000000040008013d] 26:33:04 ExternalMedia named: "com.apple.powermanagement.externalmediamounted" 
		# pid 256(coreaudiod): [0x0000f2e5000125a5] 00:10:29 PreventUserIdleSystemSleep named: "com.apple.audio.context314.preventuseridlesleep" 
		#	Created for PID: 59194. 
		# pid 256(coreaudiod): [0x0000e3af00012616] 01:15:23 PreventUserIdleSystemSleep named: "com.apple.audio.context348.preventuseridlesleep" 
		#	Created for PID: 87288. 

   		# Apparently, in OS X 10.10, one has to look out for two ways to signal that the system may not sleep when idle:
   		# 'PreventUserIdleSystemSleep'
   		# 'NoIdleSleepAssertion'

   		## Previously (OS X <10.10), it was:
		##  pid 110: [0x0000006e012c021b] PreventUserIdleSystemSleep named: "com.apple.audio.'AppleHDAEngineOutput:1B,0,1,2:0'.noidlesleep" 

		# Create initial data file with processes that prevent the computer from sleeping
		# Sequence:
		# 1. Replace all CR with × (multiplier char (Hex: C3 97), not lowercase ”x”!)
		# 2. Remove all tabs
		# 3. Replace '×Created' with ' Created'
		# 4. Replace all '×' with \n
		# 5. filter out lines with '^\ *pid.*prevent' and '^\ *pid.*NoIdleSleep'
		#pmset -g assertions | sed -e ':begin' -e '$!N;s/\n/×/; tbegin' | tr -d '\t' | sed -e 's/×Created/ Created/g' -e 's/×/\'$'\n/g' | egrep -i "^\ *pid.*prevent|^\ *pid.*NoIdleSleep" > $TempFile1
		pmset -g assertions | sed -e ':begin' -e '$!N;s/\n/×/; tbegin' | tr -d '\t' | sed -e 's/×Created/ Created/g' -e 's/×/\'$'\n/g' | egrep "^\ *pid.*NoIdleSleepAssertion|^\ *pid.*PreventUserIdleSystemSleep" | sed -e 's/^ *pid //' -e 's/ [0-9]*:[0-9]*:[0-9]* //' -e 's/\[[0-9abcdefghx]*\]//' -e 's/): PreventUserIdleSystemSleep named: / /' -e 's/(/ /' -e 's/[):]//g' > $TempFile1
		# Ex:
		# 53609 iTunes "com.apple.iTunes.playback" 
		# 33254 coreaudiod "com.apple.audio.context998.preventuseridlesleep"  Created for PID: 53609. 
		# 33254 coreaudiod "com.apple.audio.context1231.preventuseridlesleep"  Created for PID: 13525. 
		# 33254 coreaudiod "com.apple.audio.context1229.preventuseridlesleep"  Created for PID: 13525. 

		exec 4<$TempFile1
		while read -u 4 RAD
		do
			CreatedForProc=""
			ProcID="$(echo $RAD | awk '{print $1}')"
			ProcName="$(echo $RAD | awk '{print $2}')"
			CreatedForPID="$(echo $RAD | grep -o "Created for PID [0-9]*\." | awk '{print $NF}' | cut -d\. -f1)"
			if [ -n "$CreatedForPID" ]; then
				ProcID="$CreatedForPID"
				ProcName="$(basename "$(ps -o command -p $ProcID | grep -v COMMAND | sed 's;Internet Plug;Internet_Plug;g' | awk '{print $1}' | sed 's;Internet_Plug;Internet Plug;g')")"
				#Reason="_"
			#else
				#Reason="$(echo $RAD | awk '{print $3}')"
				#CreatedForProc="$(echo $RAD | cut -d\" -f2)"
			fi
			echo "$ProcName $ProcID" >> $TempFile2
		done

		# There may be multiple occurances; reduce!
		less $TempFile2 | sort -u > $TempFile3

		# Finally: report the data
		exec 5<$TempFile3
		while read -u 5 ProcName ProcID
		do
			Reason="$(pmset -g assertions | grep $ProcID | grep -v "Created for PID:" | egrep "PreventUserIdleSystemSleep|NoIdleSleepAssertion" | head -1 | awk -F: '{print $NF}')"
			if [ -z "$Reason" ]; then
				echo "  - \"$ProcName\" (pid ${ProcID}, run by \"$(ps -p ${ProcID} -o user | grep -v USER)\")"
			else
				echo "  - \"$ProcName\" (pid ${ProcID}, run by \"$(ps -p ${ProcID} -o user | grep -v USER)\"), reason: $Reason"
			fi
		done

		rm $TempFile1
		rm $TempFile2
		#rm $TempFile3

	else
		echo "• Idle sleep is not prevented by anything"
	fi
}

function PreventDisplaySleep()
{
	PreventUserIdleDisplaySleep="$(egrep "PreventUserIdleDisplaySleep\ *[0-9]" $PMSET | awk '{print $2}')"
	if [ "$PreventUserIdleDisplaySleep" = "1" ]; then
		echo "  However, display sleep is currently prevented by:"
		# Get a list of processes that prevent display sleep. Result will be like: "150 90348"
		PreventUserIdleDisplaySleepPID="$(egrep "^\ *pid\ .*PreventUserIdleDisplaySleep" $PMSET | awk '{print $2}' | sed 's/://g')"
		for pid in $PreventUserIdleSleepPID
		do
			ExtraText="$(egrep "^\ *pid ${pid}:.*PreventUserIdleDisplaySleep" /tmp/pmset.txt | cut -d\" -f2 | egrep -v "\.|\(")"
			[[ -n "$ExtraText" ]] && ExtraText="${ExtraText}, "
			echo "  - \"$(basename $(ps -p ${pid} | grep ${pid} | awk '{print $4}'))\" (${ExtraText}process id ${pid}, run by \"$(ps -p ${pid} -o user | grep -v USER)\")"
		done
	fi
}


################################################
### Print header
################################################
printf "${ESC}${BlackBack};${WhiteFont}mSleep info for:${Reset}${ESC}${WhiteBack};${BlackFont}m $(uname -n) ${Reset}   ${ESC}${BlackBack};${WhiteFont}mRunning:${ESC}${WhiteBack};${BlackFont}m $SW_VERS ${Reset}   ${ESC}${BlackBack};${WhiteFont}mDate & time:${ESC}${WhiteBack};${BlackFont}m $(date +%F", "%R) ${Reset}\n"


################################################
### Why did it fall asleep before? (only if $short=f)
################################################
if [ "$short" = "f" ]; then
	echo
	printf "${ESC}${BoldFace};${UnderlineFace}mRecent sleep/wake history${Reset}\n"
	# See if the script is run by an admin-user (non-admins can't read sleep/wake from syslog)
	if [ -n "$(/usr/bin/dscl . -read /Groups/admin GroupMembership | /usr/bin/grep -o $USER)" ]; then
		# Create a tempfile to speed up things /syslog is very slow)
		/usr/bin/syslog | egrep -i ": System Sleep|Previous Sleep Cause|>: Wake reason" > $SysLogTemp
		WhyDidItFallAsleep
		WhyDidItWake
		echo "• Previous Sleep Cause: $PreviousSleepReason $([[ -n $PreviousSleepCause ]] && echo "on ${PreviousSleepTime}")"
		if [ -n "$PreviousSleepLine" ]; then
			printf "• The computer woke up on $WakeReasonTime because of \"$WakeReason\" ${ESC}${ItalicFace}m($WakeReasonText)$Reset\n"
		else
			echo "• No information about when the computer last woke up"
		fi
		/bin/rm $SysLogTemp
	else
		echo "Sorry, user \"$USER\" is not an admin-user and can't read sleep/wake reasons from syslog!"
	fi
fi

################################################
# Find out hibernation mode
################################################
Hibernation="$(/usr/bin/pmset -g | grep "^\ *hibernatemode\ *" | awk '{print $2}')"
case $Hibernation in
	0)  HibernationText="0 (memory not backed up to disk during sleep)";;
	3)  HibernationText="3 (copy of memory stored on disk; RAM is powered on during sleep)";;
	25) HibernationText="25 (memory stored on disk and system powered off during sleep)";;
	*)  HibernationText="${Hibernation}: unknown hibernation mode. Caution advised!";;
esac
# Hibernation file size and modification time
HibernationData="$(ls -lsh $(/usr/bin/pmset -g | grep hibernatefile | awk '{print $2}') 2>/dev/null)"
# Ex: '2097152 -rw------T  1 root  wheel   2,0G  6 Dec 19:58 /var/vm/sleepimage'
#         1         2      3   4     5       6   7  8    9        10 
HibernationSize="$(echo $HibernationData | awk '{print $6}')"
HibernationLocation="$(/usr/bin/pmset -g | grep hibernatefile | awk '{print $2}')"

echo
printf "${ESC}${BoldFace};${UnderlineFace}mHibernation$Reset\n"
echo "Hibernation mode: $HibernationText"
if [ -z "$HibernationData" ]; then
	echo "Hibernation file: $HibernationLocation (Note! Hibernationfile has not been created!)"
else
	HibernationDate="$(echo $HibernationData | awk '{print $7" "$8" "$9}')"
	echo "Hibernation file: $HibernationLocation ($HibernationSize), changed ${HibernationDate}"
fi


################################################
### Find out if the system is set to idle sleep
################################################
echo
printf "${ESC}${BoldFace};${UnderlineFace}mPower Settings$Reset\n"
echo "The computer is running on: $PowerKind"
# The three below will be either 'n' (minutes) or '0' (no idlesleep)
SystemSleepTimeOut="$(/usr/bin/pmset -g | grep "^\ *sleep\ *" | awk '{print $2}')"
DisplaySleepTimeOut="$(/usr/bin/pmset -g | grep "^\ *displaysleep\ *" | awk '{print $2}')"
DiskSleepTimeOut="$(/usr/bin/pmset -g | grep "^\ *disksleep\ *" | awk '{print $2}')"
# Print accordingly
[[ ! SystemSleepTimeOut -eq 0 ]] && echo "• The system is set to sleep after $SystemSleepTimeOut minutes" || echo "• The system is set to NOT sleep when idle"
[[ ! DisplaySleepTimeOut -eq 0 ]] && echo "• The display is set to sleep after $DisplaySleepTimeOut minutes" || echo "• The display is set to NOT sleep when idle"
[[ ! DiskSleepTimeOut -eq 0 ]] && echo "• The disk is set to sleep when idle after $DiskSleepTimeOut minutes" || echo "• The disk is set to NOT sleep when idle"

echo
printf "${ESC}${BoldFace};${UnderlineFace}mCurrent sleep preventions:$Reset\n"
# Report in the system is prevented from sleeping
# We only need to report this if the system is set to sleep after some time
if [ ! $SystemSleepTimeOut -eq 0 ]; then
	# Report if something is denying system sleep
	What_Prevents_System_Sleep
	# Report if something is preventing system idle sleep
	What_Prevents_User_Idle_System_Sleep
else
	printf "${ESC}${ItalicFace}mSince the computer is set to not sleep at all, no reporting of sleep preventions is done${Reset}\n"
fi
# Report if something is preventing the display to sleep
PreventDisplaySleep



echo
printf "${ESC}${ItalicFace}mNote: to make the computer sleep right away, type \"pmset sleepnow\"$Reset\n"
printf "${ESC}${ItalicFace}mNote: to make the computer ${ESC}${BoldFace}mnot${Reset}${ESC}${ItalicFace}m sleep, type \"caffeinate -i\"$Reset\n"

exit 0
