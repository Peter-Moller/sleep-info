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
# Last change:
# 2015-01-18  Requires OS X 10.10
# 2025-05-28  Moved to macOS 15.5. Sorry: will not deal with older OS:es... 😕

usage()
{
cat << EOF
Usage: $0 options

This script displays information regarding your Macs sleep.

OPTIONS:
  -h      Show this message
EOF
}

TempFile1="/tmp/sleep_info_temp1.txt"
TempFile2="/tmp/sleep_info_temp2.txt"
TempFile3="/tmp/sleep_info_temp3.txt"
AppleSWSupportJSONfile=/tmp/.AppleSWSupport.JSON


while getopts "hus" OPTION
do
    case $OPTION in
        h)  usage
            exit 1;;
        *)  usage
            exit;;
    esac
done


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

# Print a warning if you run older than 15
if [ $(sw_vers -productVersion | cut -d\. -f1) -lt 15 ]; then
    printf "${ESC}${BlackBack};${YellowFont}mThis script is written for macOS ≥ 15. Beware that it may not work correctly on your system${Reset}\n"
    echo
fi

# Find where the script resides (correct version)
# Get the DirName and ScriptName
if [ -L "${BASH_SOURCE[0]}" ]; then
    # Get the *real* directory of the script
    ScriptDirName="$(dirname "$(readlink "${BASH_SOURCE[0]}")")"   # ScriptDirName='/usr/local/bin'
    # Get the *real* name of the script
    ScriptName="$(basename "$(readlink "${BASH_SOURCE[0]}")")"     # ScriptName='moodle_backup.sh'
else
    ScriptDirName="$(dirname "${BASH_SOURCE[0]}")"
    # What is the name of the script?
    ScriptName="$(basename "${BASH_SOURCE[0]}")"
fi
ScriptFullName="${ScriptDirName}/${ScriptName}"

PMSET_ASSERTIONS="$(pmset -g assertions)"
PMSET_G="$(pmset -g)"
SW_VERS="$(sw_vers --productName) $(sw_vers --productVersion)"                                                                   # Ex: SW_VERS='macOS 15.5'
MODEL_IDENTIFIER="$(system_profiler SPHardwareDataType | grep "Model Identifier" | awk '{print $NF}' )"                          # Ex: MODEL_IDENTIFIER=MacBookPro18,3
MODEL_IDENTIFIER_NAME="$(grep ".*:${MODEL_IDENTIFIER}:" "${ScriptDirName}/Mac-models.txt" |  awk -F: '{print $1}')"              # Ex: MODEL_IDENTIFIER_NAME='MacBook Pro (14-inch, 2021)'
MODEL_IDENTIFIER_URL="https:$(grep ".*:${MODEL_IDENTIFIER}:" "${ScriptDirName}/Mac-models.txt" |  awk -F: '{print $4}')"         # Ex: MODEL_IDENTIFIER_URL=https://support.apple.com/kb/SP854


# Find out if we are running on 'AC Power' och 'Battery Power'
PMSET_PS="$(pmset -g ps)"
# Ex, laptop:
# PMSET_PS='Now drawing from '\''Battery Power'\''
#            -InternalBattery-0 (id=24117347)   91%; discharging; 5:57 remaining present: true'
# Ex, Mac mini:
# PMSET_PS='Now drawing from '\''AC Power'\'''
PowerKind="$(echo "$PMSET_PS" | awk -F\' '{print $2}')"                                                                          # Ex: PowerKind='AC Power' or PowerKind='Battery Power'
# If we are on battery, also report status
if [ -n "$(echo "$PMSET_PS" | grep "InternalBattery")" ]; then
    BatteryCycles="$(pmset -g rawbatt | grep -Eo "Cycles=[^;]*")"                                                                # Ex: BatteryCycles=Cycles=184/1000
    BatteryDetailsText="$(pmset -g batt | grep -Eo "[0-9]*%.*remaining|[0-9]*%.*discharging|[0-9]*%.*finishing charge|[0-9]*%.*not charging"); $BatteryCycles"
    # Ex: BatteryDetailsText='89%; discharging; 6:05 remaining; Cycles=184/1000'
    # Ex: BatteryDetailsText='80%; AC attached; not charging; Cycles=185/1000'
    # Ex: BatteryDetailsText='30%; charging; 2:36 remaining; Cycles=56/1000'
    BatteryDesignCapacity=$(ioreg -lrn AppleSmartBattery | grep -E "\"DesignCapacity\" = " | awk '{print $NF}')                  # Ex: BatteryDesignCapacity=4382
    BatteryAppleRawMaxCapacity=$(ioreg -rn AppleSmartBattery | grep -E "\"AppleRawMaxCapacity\" = " | awk '{print $NF}')         # Ex: BatteryAppleRawMaxCapacity=3764
    BatteryNominalChargeCapacity=$(ioreg -lrn AppleSmartBattery | grep -E "\"NominalChargeCapacity\" = " | awk '{print $NF}')    # Ex: BatteryNominalChargeCapacity=3894
    BatteryAppleRawCurrentCapacity=$(ioreg -rn AppleSmartBattery | grep -E "\"AppleRawCurrentCapacity\" = " | awk '{print $NF}') # Ex: BatteryAppleRawCurrentCapacity=3764
    # Calculate percentages
    if [[ $BatteryAppleRawMaxCapacity -gt 0 && $BatteryDesignCapacity -gt 0 ]]; then
        health_percent=$(( 100 * BatteryAppleRawMaxCapacity / BatteryDesignCapacity ))
        BatteryHealth="${health_percent}% of the original $BatteryDesignCapacity mAh remains"
    fi
fi
ScreenSaverActivationTimeSec=$(defaults -currentHost read com.apple.screensaver idleTime 2>/dev/null)                            # Ex: ScreenSaverActivationTimeSec=120
ScreenSaverActivationTime=$(( ${ScreenSaverActivationTimeSec:-0} / 60 ))                                                         # Ex: ScreenSaverActivationTime=2
ComputerName="$(scutil --get ComputerName)"                                                                                      # Ex: ComputerName='Peters MBA'
# If we are on A) battery and B) external powersupply, get some details
if [ -n "$(echo "$PMSET_PS" | grep "InternalBattery")" ] && [ "$PowerKind" = "AC Power" ]; then
    PMSET_ADAPTER="$(pmset -g adapter)"
    # Ex: PMSET_ADAPTER=' Wattage = 5W
    #      Current = 1000mA
    #      Voltage = 5000mV
    #      AdapterID = 2
    #      Family Code = 0xe0004008'
    AdapterDetails="$(echo "$PMSET_ADAPTER" | grep Wattage | awk '{print $NF}'), $(echo "$PMSET_ADAPTER" | grep Voltage | awk '{print $NF}'), $(echo "$PMSET_ADAPTER" | grep Current | awk '{print $NF}')"
    # Ex: AdapterDetails='5W, 5000mV, 1000mA'
fi



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
#   _____   _____    ___   ______   _____       _____  ______      ______   _   _   _   _   _____   _____   _____   _____   _   _   _____ 
#  /  ___| |_   _|  / _ \  | ___ \ |_   _|     |  _  | |  ___|     |  ___| | | | | | \ | | /  __ \ |_   _| |_   _| |  _  | | \ | | /  ___|
#  \ `--.    | |   / /_\ \ | |_/ /   | |       | | | | | |_        | |_    | | | | |  \| | | /  \/   | |     | |   | | | | |  \| | \ `--. 
#   `--. \   | |   |  _  | |    /    | |       | | | | |  _|       |  _|   | | | | | . ` | | |       | |     | |   | | | | | . ` |  `--. \
#  /\__/ /   | |   | | | | | |\ \    | |       \ \_/ / | |         | |     | |_| | | |\  | | \__/\   | |    _| |_  \ \_/ / | |\  | /\__/ /
#  \____/    \_/   \_| |_/ \_| \_|   \_/        \___/  \_|         \_|      \___/  \_| \_/  \____/   \_/    \___/   \___/  \_| \_/ \____/ 


# Get the sleep / wake data. Takes just a few seconds, so should be ok
sleep_wake_history() {
    SleepWakeHistory="$(pmset -g log | grep -E "Entering Sleep state due to |Wake from Deep Idle " | grep -Ev "Maintenance Sleep|Sleep Service Back to Sleep|DarkWake from Deep Idle" | tail -10)"
    # Ex: SleepWakeHistory='2025-05-30 17:39:28 +0200 Sleep                 Entering Sleep state due to 'Idle Sleep':TCPKeepAlive=active Using Batt (Charge:71%) 207 secs  
    #                       2025-05-30 20:48:06 +0200 Wake                  Wake from Deep Idle [CDNVA] : due to smc.70070000 trackpadkeyboard SMC.OutboxNotEmpty/HID Activity Using BATT (Charge:70%)           
    #                       2025-05-31 09:52:51 +0200 Sleep                 Entering Sleep state due to 'Software Sleep pid=16433':TCPKeepAlive=active Using AC (Charge:99%) 2 secs    
    #                       2025-05-31 09:55:00 +0200 Wake                  Wake from Deep Idle [CDNVA] : due to NUB.SPMISw3IRQ nub-spmi0.0x02 rtc/HID Activity Using AC (Charge:99%)           
    #                       2025-05-31 13:37:51 +0200 Sleep                 Entering Sleep state due to 'Clamshell Sleep':TCPKeepAlive=active Using Batt (Charge:84%) 295 secs  
    #                       2025-05-31 16:06:30 +0200 Wake                  Wake from Deep Idle [CDNVA] : due to smc.70070000 lid SMC.OutboxNotEmpty/HID Activity Using BATT (Charge:83%)           
    #                       2025-05-31 17:23:29 +0200 Sleep                 Entering Sleep state due to 'Clamshell Sleep':TCPKeepAlive=active Using Batt (Charge:100%) 10 secs   
    #                       2025-05-31 17:23:53 +0200 Wake                  DarkWake to FullWake from Deep Idle [CDNVAP] : due to Notification Using AC (Charge:100%)           
    #                       2025-05-31 23:14:05 +0200 Sleep                 Entering Sleep state due to 'Software Sleep pid=429':TCPKeepAlive=active Using AC (Charge:100%) 7 secs    
    #                       2025-06-01 09:13:01 +0200 Wake                  DarkWake to FullWake from Deep Idle [CDNVA] : due to UserActivity Assertion Using AC (Charge:100%)           '
}

# Find out why it did fall asleep before
WhyDidItFallAsleep()
{
    # Sleep reasons (according to CoPilot, 2025-05-30):
    # 
    # Sleep Reason         Description
    # -----------------------------------------------------------------
    # Idle Sleep           No user or system activity for a while
    # Clamshell Sleep      Lid closed without external display/input
    # Software Sleep       Manual sleep via Apple menu or power button
    # Power Button Sleep   Triggered by pressing the power button
    # Low Power            Sleep Battery critically low
    # Sleep Timer Expired  System-initiated sleep after a timer

    PreviousSleepLine="$(echo "$SleepWakeHistory" | grep "Entering Sleep state due to" | tail -1)"
    # 2025-05-30 17:39:28 +0200 Sleep                 Entering Sleep state due to 'Idle Sleep':TCPKeepAlive=active Using Batt (Charge:71%) 207 secs 
    PreviousSleepCause="$(echo "$PreviousSleepLine" | cut -d\' -f2)"                   # Ex: PreviousSleepCause='Idle Sleep'
    PreviousSleepTime="$(echo $PreviousSleepLine | awk '{print $1" "$2}' | sed "s/$(date +%F)/today at/; s/$(date -v-1d +%F)/yesterday at/")"        # Ex: PreviousSleepTime='2025-05-30 17:39:28'
}

# Find out why it did wake
WhyDidItWake()
{
    WakeLine="$(echo "$SleepWakeHistory" | grep "Wake from Deep Idle" | tail -1)"
    # Ex: WakeLine='2025-05-30 20:48:06 +0200 Wake                  Wake from Deep Idle [CDNVA] : due to smc.70070000 trackpadkeyboard SMC.OutboxNotEmpty/HID Activity Using BATT (Charge:70%)           ' 
    #     WakeLine='2025-05-30 23:01:52 +0200 Wake                  Wake from Deep Idle [CDNVA] : due to smc.70070000 lid SMC.OutboxNotEmpty/UserActivity Assertion Using AC (Charge:66%)           '
    # 
    # Maybe good article:     https://github.com/apple/darwin-xnu/blob/main/iokit/IOKit/pwr_mgt/IOPM.h
    # Interesting (but old):  http://www.opensource.apple.com/source/xnu/xnu-2422.1.72/iokit/IOKit/pwr_mgt/RootDomain.h
    
    WakeTime="$(echo $WakeLine | awk '{print $1" "$2}' | sed "s/$(date +%F)/today at/; s/$(date -v-1d +%F)/yesterday at/")"                        # Ex: WakeTime='2025-05-30 20:48:06' 
    WakeReason="$(echo $WakeLine | grep -Eo "Wake from Deep Idle .*" | grep -Eo "due to .*" | awk '{print $3" "$4}' | sed 's/smc.70070000 //; s/ Assertion//')"   # Ex: WakeReason=trackpadkeyboard 
    case "${WakeReason/[0-9]/}" in
        wifibt)            WakeReasonText="WiFi or Bluetooth device";;
        lid)               WakeReasonText="lid was opened";;
        trackpadkeyboard)  WakeReasonText="trackpad or keyboard";;
        pwrbtn)            WakeReasonText="powerbutton was pressed";;
        nub-spmi*)         WakeReasonText="time scheduled wake";;
        UserActivity)      WakeReasonText="User woke the computer";;
        *)                 WakeReasonText="unknown"
    esac
}

# Find out information about PreventSystemSleep
What_Prevents_System_Sleep()
{
    # Find out if something is prohibiting system sleep
    PreventSystemSleep="$(echo "$PMSET_ASSERTIONS" | grep "^\ *PreventSystemSleep\ *[01]$" | awk '{print $2}')"
    # If so, report all such instances
    if [ $PreventSystemSleep -eq 1 ]; then
        # 'pmset -g assertions | grep DenySystemSleep'
        # '  pid 26(configd): [0x000543f7000724b7] 00:00:22 DenySystemSleep named: "InternetSharingPreferencePlugin" '
        #     1      2                   3             4            5         6                   7
        echo "• System sleep is prevented by:"
        echo "$PMSET_ASSERTIONS" | grep DenySystemSleep | awk '{print $2" "$7}' | sed -e 's/(/ /' -e 's/):/ /' | tr -d \" > $TempFile1
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
What_Prevents_User_Idle_System_Sleep()
{
    PreventUserIdleSystemSleep="$(echo "$PMSET_G" | grep -v "NSURLSessionTask" | grep "^\ *sleep\ *" | grep -E "sleep prevented by ")"
    if [ -n "$PreventUserIdleSystemSleep" ]; then
        echo "• Idle sleep is prevented by:"
        # Get a list of processes that prevent sleep.
        # pmset -g assertions | grep "PreventUserIdleSystemSleep named:"
        # 2025-05-31 20:01:08 | peter@Peters-MBP:~$ pmset -g assertions | grep "PreventUserIdleSystemSleep named:"
        # pid 737(useractivityd): [0x0000a7090001987a] 00:00:01 PreventUserIdleSystemSleep named: "BTLEAdvertisement.EA7CC365-A76B-4E03-92C2-B501C1C17447"  
        # pid 698(sharingd): [0x0000a6b700019848] 00:01:23 PreventUserIdleSystemSleep named: "Handoff"  
        # pid 418(bluetoothd): [0x0000a70900019879] 00:00:01 PreventUserIdleSystemSleep named: "com.apple.BTStack"  
        # pid 583(backupd): [0x0000700100018815] 03:54:51 PreventUserIdleSystemSleep named: "Backup Job"  
        # pid 368(powerd): [0x0000a68800019794] 00:02:10 PreventUserIdleSystemSleep named: "Powerd - Prevent sleep while display is on"  

        PreventSystemSleepList="$(echo "$PMSET_ASSERTIONS" | grep -E "^\ *pid.*NoIdleSleepAssertion|^\ *pid.*PreventUserIdleSystemSleep" | sed 's/^\ *pid //g; s/(/:/; s/)//; s/ \[[0-9abcdefghx]*\] [^ ]* //; s/Prevent.*named: //; s/"//g')"
        # Ex: PreventSystemSleepList='737:useractivityd:BTLEAdvertisement.EA7CC365-A76B-4E03-92C2-B501C1C17447  
        #                             698:sharingd:Handoff  
        #                             418:bluetoothd:com.apple.BTStack  
        #                             583:backupd:Backup Job  
        #                             368:powerd:Powerd - Prevent sleep while display is on  '

        echo "$PreventSystemSleepList" | while IFS=':' read -r ProcID ProcName Reason
        do
            if [ -z "$Reason" ]; then
                echo "  - \"$ProcName\" (pid ${ProcID}, run by \"$(ps -p ${ProcID} -o user | grep -v USER)\")"
            else
                echo "  - \"$ProcName\" (pid ${ProcID}, run by \"$(ps -p ${ProcID} -o user | grep -v USER)\"), reason: $Reason"
            fi
        done
    else
        echo "• Idle sleep is not prevented by anything"
    fi
}

# Find out what is keeping the display from sleeping (if anything)
PreventDisplaySleep()
{
    PreventUserIdleDisplaySleep="$(echo "$PMSET_ASSERTIONS" | grep -E "PreventUserIdleDisplaySleep\ *[0-9]" | awk '{print $2}')"                          # Ex: PreventUserIdleDisplaySleep=1
    if [ "$PreventUserIdleDisplaySleep" = "1" ]; then
        echo "  However, display sleep is currently prevented by:"
        # Get a list of processes that prevent display sleep. Result will be like: "150 90348"
        PreventUserIdleDisplaySleepPID="$(echo "$PMSET_ASSERTIONS" | grep -E "^\ *pid.*NoDisplaySleepAssertion" | awk '{print $2}' | sed 's/(.*//g')"     # Ex: PreventUserIdleDisplaySleepPID=1342
        for pid in $PreventUserIdleDisplaySleepPID
        do
            local RunningJob="$(echo "$PMSET_ASSERTIONS" | grep -E "^\ *pid ${pid}.*NoDisplaySleepAssertion" | cut -d\" -f2 | grep -E -v "\.|\(")"        # Ex: RunningJob='Video Wake Lock'
            local RunningProcess="$(ps -o comm -p $pid | grep -Ev "COMM")"  
            # Ex: RunningProcess='/Applications/Adobe Illustrator 2025/Adobe Illustrator.app/Contents/MacOS/CEPHtmlEngine/CEPHtmlEngine.app/Contents/MacOS/CEPHtmlEngine'
            local RunningProcessOwner="$(ps -p ${pid} -o user | grep -v USER)"                                                                            # Ex: RunningProcessOwner=peter
            if [ ${#RunningProcess} -lt 41 ]; then
                echo "  - \"$RunningJob\"; process id ${pid}, run by \"$RunningProcessOwner\" (full process is: \"$RunningProcess\")"
            else
                echo "  - \"$RunningJob\"; process id ${pid}, run by \"$RunningProcessOwner\" (full process is:)"
                echo "    \"$RunningProcess\""
            fi
        done
    else
        echo "• Nothing is preventing the display from sleeping"
    fi
}

is_valid_apple_json() {
  [[ ! -s "$AppleSWSupportJSONfile" ]] && return 1
  jq -e '.PublicAssetSets? as $pas | ($pas | type == "object") and ($pas.macOS? | type == "array")' "$AppleSWSupportJSONfile" >/dev/null 2>&1
}

fetch_apple_json() {
    if ! is_valid_apple_json; then
        #echo "Fetching fresh macOS version data from Apple..."
        curl --silent --insecure https://gdmf.apple.com/v2/pmv --output "$AppleSWSupportJSONfile"

        if ! is_valid_apple_json; then
            #echo "Error: Downloaded file is not a valid Apple macOS version JSON."
            rm -f "$AppleSWSupportJSONfile"
            exit 1
        fi
    #else
    #    echo "Using cached macOS version data from $AppleSWSupportJSONfile"
    fi
}

find_OS_versions() {
    if type -p jq &>/dev/null; then
        # Get the processor type:
        if [ "$(uname -m)" = "arm64" ]; then
            HardwareID="$(ioreg -l | grep target-sub-type | cut -d\" -f4)"                                                            # Ex: HardwareID=J314sAP
        else
            HardwareID="$(ioreg -l | grep -i board-id | cut -d\" -f4)"                                                                # Ex: HardwareID='Mac-35C5E08120C7EEAF'
        fi
        fetch_apple_json
        #AppleSWSupportJSON="$(curl --silent --insecure https://gdmf.apple.com/v2/pmv)"                                                # Really big JSON object
        LastestMacOSVersion="$(cat "$AppleSWSupportJSONfile" | jq -r '.PublicAssetSets.macOS[]?.ProductVersion' | sort -V | tail -n 1)"  # Ex: LastestMacOSVersion=15.5
        SupportedVersions="$(cat "$AppleSWSupportJSONfile" | jq -r --arg hw "$HardwareID" '.PublicAssetSets.macOS[] | select(.SupportedDevices[]? == $hw) | .ProductVersion' | sort -V)"
        # Ex: SupportedVersions='12.7.6
        #                        13.7.6
        #                        14.7.6
        #                        15.5'
        if [[ -z "$SupportedVersions" ]]; then
            echo "No supported macOS versions found for this hardware."
        else
            FirstSupportedOS=$(echo "$SupportedVersions" | head -n 1)                                                                 # Ex: FirstSupportedOS=12.7.6
            if [ "$FirstSupportedOS" = "$LastestMacOSVersion" ]; then
                FirstSupportedOS="$LastestMacOSVersion (this is also the latest macOS version released by Apple)"
            fi
            LastSupportedOS=$(echo "$SupportedVersions" | tail -n 1)                                                                  # Ex: LastSupportedOS=15.5
            if [ "$LastSupportedOS" = "$LastestMacOSVersion" ]; then
                LastSupportedOS="$LastestMacOSVersion (this is also the latest macOS version released by Apple)"
            fi
        fi
    else
        OSVersionString="Error: 'jq' is required. Install it with 'brew install jq'."
    fi
}


#   _____   _   _  ______       _____  ______      ______   _   _   _   _   _____   _____   _____   _____   _   _   _____ 
#  |  ___| | \ | | |  _  \     |  _  | |  ___|     |  ___| | | | | | \ | | /  __ \ |_   _| |_   _| |  _  | | \ | | /  ___|
#  | |__   |  \| | | | | |     | | | | | |_        | |_    | | | | |  \| | | /  \/   | |     | |   | | | | |  \| | \ `--. 
#  |  __|  | . ` | | | | |     | | | | |  _|       |  _|   | | | | | . ` | | |       | |     | |   | | | | | . ` |  `--. \
#  | |___  | |\  | | |/ /      \ \_/ / | |         | |     | |_| | | |\  | | \__/\   | |    _| |_  \ \_/ / | |\  | /\__/ /
#  \____/  \_| \_/ |___/        \___/  \_|         \_|      \___/  \_| \_/  \____/   \_/    \___/   \___/  \_| \_/ \____/ 
#
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # 


################################################
### Print header
################################################
printf "${ESC}${BlackBack};${WhiteFont}mSleep info for:${Reset}${ESC}${WhiteBack};${BlackFont}m $ComputerName ${Reset}   ${ESC}${BlackBack};${WhiteFont}mRunning:${ESC}${WhiteBack};${BlackFont}m $SW_VERS ${Reset}   ${ESC}${BlackBack};${WhiteFont}mDate & time:${ESC}${WhiteBack};${BlackFont}m $(date +%F", "%R) ${Reset}\n"


################################################
### Generate data
################################################
printf "Generating data..."
sleep_wake_history
printf "."
find_OS_versions
printf "."
WhyDidItFallAsleep
printf "."
WhyDidItWake
printf "."
printf "${ESC}2K"  # Empty the entire line


################################################
### Print machine information
################################################


echo
printf "${ESC}${BoldFace};${UnderlineFace}mHardware information:$Reset\n"
echo "Model name:         $MODEL_IDENTIFIER_NAME"
echo "Model identifier:   $MODEL_IDENTIFIER"
echo "Tech. spec.:        $MODEL_IDENTIFIER_URL"
echo "First supported OS: $FirstSupportedOS"
echo "Last supported OS:  $LastSupportedOS"

################################################
### Why did it fall asleep before? 
################################################
echo
printf "${ESC}${BoldFace};${UnderlineFace}mRecent sleep/wake history${Reset}${ESC}${ItalicFace};${UnderlineFace}m (from 'pmset -g log'):${Reset}\n"
echo "• Previous sleep cause: \"$PreviousSleepCause\" ($PreviousSleepTime)"
if [ -n "$PreviousSleepLine" ]; then
    printf "• The computer woke up because of \"$WakeReason\" ${ESC}${ItalicFace}m($WakeReasonText)$Reset ($WakeTime)\n"
else
    echo "• No information about when the computer last woke up"
fi

################################################
# Find out hibernation mode
################################################
Hibernation="$(echo "$PMSET_G" | grep -E "^\ *hibernatemode\ *" | awk '{print $2}')"
case $Hibernation in
    0)  HibernationText="0 (memory not backed up to disk during sleep)";;
    3)  HibernationText="3 (copy of memory stored on disk; RAM is powered on during sleep)";;
    25) HibernationText="25 (memory stored on disk and system powered off during sleep)";;
    *)  HibernationText="${Hibernation}: unknown hibernation mode. Caution advised!";;
esac
# Hibernation file size and modification time
HibernationData="$(ls -lsh $(echo "$PMSET_G" | grep hibernatefile | awk '{print $2}') 2>/dev/null)"
# Ex: '2097152 -rw------T  1 root  wheel   2,0G  6 Dec 19:58 /var/vm/sleepimage'
#         1         2      3   4     5       6   7  8    9        10 
HibernationSize="$(echo $HibernationData | awk '{print $6}')"
HibernationLocation="$(echo "$PMSET_G" | grep hibernatefile | awk '{print $2}')"

echo
printf "${ESC}${BoldFace};${UnderlineFace}mHibernation:$Reset\n"
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
printf "${ESC}${BoldFace};${UnderlineFace}mPower Settings:$Reset\n"
echo "The computer is running on: $PowerKind"
[[ -n "$BatteryDetailsText" ]]           && echo "• Battery at $BatteryDetailsText"
[[ -n "$BatteryHealth" ]]                && echo "• Battery capacity: $BatteryHealth"
[[ -n "$AdapterDetails" ]]               && echo "• Adapter details: $(echo "$AdapterDetails" | sed 's/000m//g; s/500m/.5/g')"
# The three below will be either 'n' (minutes) or '0' (no idlesleep)
SystemSleepTimeOut="$(echo "$PMSET_G" | grep -E "^\ *sleep\ *" | awk '{print $2}')"
DisplaySleepTimeOut="$(echo "$PMSET_G" | grep -E "^\ *displaysleep\ *" | awk '{print $2}')"
DiskSleepTimeOut="$(echo "$PMSET_G" | grep -E "^\ *disksleep\ *" | awk '{print $2}')"
# Print accordingly
[[ ! SystemSleepTimeOut -eq 0 ]]         && echo "• The system is set to sleep after $SystemSleepTimeOut minutes"       || echo "• The system is set to NOT sleep when idle"
[[ ! DisplaySleepTimeOut -eq 0 ]]        && echo "• The display is set to sleep after $DisplaySleepTimeOut minutes"     || echo "• The display is set to NOT sleep when idle"
[[ ! DiskSleepTimeOut -eq 0 ]]           && echo "• The disk is set to sleep when idle after $DiskSleepTimeOut minutes" || echo "• The disk is set to NOT sleep when idle"
[[ ! ScreenSaverActivationTime -eq 0 ]]  && echo "• Screen Saver activates after $ScreenSaverActivationTime minutes"

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

################################################
### Print recent sleep/wake history
################################################
echo
printf "${ESC}${BoldFace};${UnderlineFace}mRecent sleep/wake history:$Reset\n"
echo "$SleepWakeHistory" | sed "s/Sleep\ *//; s/Wake\ *//; s/:TCPKeepAlive.*//; s/SMC.OutboxNotEmpty.*//; s/DarkWake to Full//; s/(.*//; s/state //; s/from Deep Idle \[[A-Z]*\] : //; s/ +[0-9][0-9]00//; s/$(date +%F)/Today at/; s/$(date -v-1d +%F)/Yesterday at/" | sed -E 's/[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}//g'

echo
printf "${ESC}${ItalicFace}mNote: to make the computer sleep right away, type \"pmset sleepnow\"$Reset\n"
printf "${ESC}${ItalicFace}mNote: to make the computer ${ESC}${BoldFace}mnot${Reset}${ESC}${ItalicFace}m sleep, type \"caffeinate -i\"$Reset\n"

exit 0
