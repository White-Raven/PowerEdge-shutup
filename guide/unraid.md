# PowerEdge-shutup on Unraid

How to get it up and running easily on Unraid.

## Requirements
- iDrac Entreprise (afaik it won't work with express)
- [IPMItool](https://github.com/ipmitool/ipmitool)
- G11*, G12 or G13** Dell Poweredge server
- Unraid duh

*See also [me/PowerEdge-IPMItools](https://github.com/White-Raven/PowerEdge-IPMItools) for more applications and resources.*

## Cron Jobs and Unraid

Let's start with that. Cron jobs are just a linux way to tell your computer "Run this at this interval". 
"This" being any kind of simple single command to a slew of cascading scripts spanning thousands of lines of code.

Unraid makes it easy to create and manage cron jobs. No need to fiddle with the CLI, making it very userfriendly for beginners.

This script basically is a basic "enter credential, ip and ready to run" with cron jobs already, so if we even have a GUI for it it's perfect.

You can install the User Scripts plugin by Andrew Zawadzki in the Community Applications.

If you are on an Unraid version older than 6.10, and you don't have the Community App 'store' installed, head to your plugins, "Install Plugin" tab, and paste in:
```
https://raw.githubusercontent.com/Squidly271/community.applications/master/plugins/community.applications.plg
```

If you are on Unraid 6.10 or newer, the Community App section should still appear whether or not you have it installed. Head up to there and click on the install button.

## Add new Cron Jobs in Unraid

Once User Scripts in installed, head to your "Setting" section in Unraid's webui. You should find User Scripts under the USER UTILITIES sub section.

Adding in a new script then is as simple as clicking the "Add New Script" button, name it (keep it clean with A-Z 0-9, don't splurge in symbols).

You should see your new script in the list. Click on the inline Cog left to its name, and in the pop-up, "Edit Script".

You're now presented to a text area in which you can paste in and edit your script, which for this guide would be the [fancontrol.sh](https://github.com/White-Raven/PowerEdge-shutup/blob/main/fancontrol.sh) script I provide.

Remmember, you need to punch in your own informations, from the IP of your dedicated iDrac nic, to the login and password, eventually the IPMI ids corresponding to your hardware.

You can also obviously adjust the fan curves, for both CPU driven control or Ambient driven control. Note the Ambient/Inlet temp is also used in CPU temp driven mode, as a modifier.

<details>
<summary>
<b>Also available here. Check link before for commented version with detailed info!</b>
</summary>
<p>

```bash
#!/bin/bash
#the IP address of iDrac
IPMIHOST=192.168.0.42

#iDrac user
IPMIUSER=root

#iDrac password (calvin is the default password)
IPMIPW=calvin

#YOUR IPMI ENCRYPTION KEY
IPMIEK=0000000000000000000000000000000000000000

#IPMI IDs
#To check your values, use the "temppull.sh" script.
CPUID0=0Fh
CPUID1=0Eh
CPUID2="0#h"
CPUID3="0#h"
AMBIENT_ID=04h
EXHAUST_ID=01h

#Logtype:
#0 = None
#1 = Fan speed output
#2 = Simple text + fanspeed output
#3 = Table + fanspeed output
Logtype=3

#CPU fan governor type - keep in mind, it's CPUs, not cores. For dual and quad CPU configs
#0 = uses average CPU temperature accross CPUs
#1 = uses highest CPU temperature
TEMPgov=0

#TEMP_STEPX in °C
#FSTX in 0-100%
        
TEMP_STEP0=30
FST0=2
TEMP_STEP1=35
FST1=6
TEMP_STEP2=40
FST2=8
TEMP_STEP3=50
FST3=10
TEMP_STEP4=60
FST4=12
TEMP_STEP5=75
FST5=20
TEMP_STEP_COUNT=6
MAXTEMP=$TEMP_STEP5

#AMBTEMP_STEPX in °C
#AMBTEMP_STEPX_MOD in added °C offset for CPU profile
#AMBTEMP_noCPU_FS_STEPX in 0-100% for Ambient temp fan profile
        
AMBTEMP_STEP0=20
AMBTEMP_STEP0_MOD=0
AMBTEMP_noCPU_FS_STEP0=8
AMBTEMP_STEP1=23
AMBTEMP_STEP1_MOD=10
AMBTEMP_noCPU_FS_STEP1=15
AMBTEMP_STEP2=26
AMBTEMP_STEP2_MOD=15
AMBTEMP_noCPU_FS_STEP2=20
AMBTEMP_STEP3=26
AMBTEMP_STEP3_MOD=20
AMBTEMP_noCPU_FS_STEP3=30

AMBTEMP_MAX=$AMBTEMP_STEP3
MAX_MOD=69

AMB_STEP_COUNT=4
EXHTEMP_MAX=65
        
IPMIPULLDATA=$(ipmitool -I lanplus -H $IPMIHOST -U $IPMIUSER -P $IPMIPW -y $IPMIEK sdr type temperature)
DATADUMP=$(echo "$IPMIPULLDATA")
if [ -z "$DATADUMP" ]; then
        echo "No data was pulled from IPMI".
   exit 1
fi
CPUTEMP0=$(echo "$DATADUMP" |grep "$CPUID0" |grep degrees |grep -Po '\d{2}' | tail -1)
CPUTEMP1=$(echo "$DATADUMP" |grep "$CPUID1" |grep degrees |grep -Po '\d{2}' | tail -1)
CPUTEMP2=$(echo "$DATADUMP" |grep "$CPUID2" |grep degrees |grep -Po '\d{2}' | tail -1)
CPUTEMP3=$(echo "$DATADUMP" |grep "$CPUID3" |grep degrees |grep -Po '\d{2}' | tail -1)
if [ -z "$CPUTEMP0" ]; then
        CPUcount=0
elif [ -z "$CPUTEMP1" ]; then
        CPUcount=1
        CPUn=$CPUTEMP0
elif [ -z "$CPUTEMP2" ]; then
        CPUcount=2
        if [ $TEMPgov -eq 0 ]; then
                TEMPadd=$((CPUTEMP0+CPUTEMP1))
                CPUn=$((TEMPadd/CPUcount))
        fi
else
        CPUcount=4
        if [ $TEMPgov -eq 0 ]; then
                TEMPadd=$((CPUTEMP0+CPUTEMP1+CPUTEMP2+CPUTEMP3))
                CPUn=$((TEMPadd/CPUcount))
        fi
fi
if [ $TEMPgov -eq 1 ] && [ "$CPUcount" -gt 1 ]; then
        for ((i=0; i<CPUcount; i++)) 
            do if [[ $i -le $CPUcount ]]; then
                CPUtemploop="CPUTEMP$i"
                if [ "$i" -eq 0 ]; then
                      CPUn=${!CPUtemploop}
                else
                    if [ ${!CPUtemploop} -gt $CPUn ]; then
                        CPUn=${!CPUtemploop}
                    fi
                fi
            fi
        done
fi
AMBTEMP=$(echo "$DATADUMP" |grep "$AMBIENT_ID" |grep degrees |grep -Po '\d{2}' | tail -1)
if [ $CPUcount != 0 ]; then
        if [[ ! -z "$AMBTEMP" ]]; then
                if [ "$AMBTEMP" -ge $AMBTEMP_MAX ]; then
                        echo "Intake temp is very high!! : $AMBTEMP °C!"
                        TEMPMOD=$MAX_MOD
                elif [ "$AMBTEMP" -le $AMBTEMP_STEP0 ]; then
                        TEMPMOD=$AMBTEMP_STEP0_MOD
                elif [ "$AMBTEMP" -le $AMBTEMP_STEP1 ]; then
                        TEMPMOD=$AMBTEMP_STEP1_MOD
                elif [ "$AMBTEMP" -le $AMBTEMP_STEP2 ]; then
                        TEMPMOD=$AMBTEMP_STEP2_MOD
                elif [ "$AMBTEMP" -le $AMBTEMP_STEP3 ]; then
                        TEMPMOD=$AMBTEMP_STEP3_MOD
                fi
        fi
fi
EXHTEMP=$(echo "$DATADUMP" |grep "$EXHAUST_ID" |grep degrees |grep -Po '\d{2}' | tail -1)
if [[ ! -z "$EXHTEMP" ]]; then
        if [ "$EXHTEMP" -ge $EXHTEMP_MAX ]; then
                echo "Exhaust temp is critical!! : $EXHTEMP °C!"
                TEMPMOD=$MAX_MOD
        else
                if [ $CPUcount -eq 0 ]; then
                        TEMPMOD=0
                fi
        fi
fi
if [ $CPUcount != 0 ]; then
        TEMP=$((CPUn+TEMPMOD))
else
        vTEMP=$((AMBTEMP+TEMPMOD))
fi
if [ $Logtype -eq 2 ]; then
        for ((i=0; i<CPUcount; i++))
         do if [[ $i -le $CPUcount ]]; then
                CPUtemploopecho="CPUTEMP$i"
                 echo "CPU$i = ${!CPUtemploopecho} °C"
            fi
         done
        [ "$CPUcount" -eq 0 ] && echo "No CPU sensors = Ambient Mode"
        [ "$TEMPgov" -eq 0 ] && [ "$CPUcount" -gt 1 ] && echo "$CPUcount CPU average = $CPUn °C"
        [ "$TEMPgov" -eq 1 ] && [ "$CPUcount" -gt 1 ] && echo "$CPUcount CPU highest = $CPUn °C"
        [[ ! -z "$AMBTEMP" ]] && echo "Ambient = $AMBTEMP °C" 
        [[ ! -z "$EXHTEMP" ]] && echo "Exhaust = $EXHTEMP °C"
        [[ "$TEMPMOD" != 0 ]] && echo "TEMPMOD = +$TEMPMOD °C"
        if [ "$CPUcount" != 0 ]; then
                echo  "vTEMP = $TEMP °C" 
        else
                echo "vTEMP = $vTEMP °C"
        fi
fi
if [ $Logtype -eq 3 ]; then
        (
         printf 'SOURCE\tFETCH\tTEMPERATURE\n' 
         for ((i=0; i<CPUcount; i++))
         do if [[ $i -le $CPUcount ]]; then
                CPUtemploopecho="CPUTEMP$i"
                 printf '%s\t%4s\t%12s\n' "CPU$i" "OK" "${!CPUtemploopecho} °C"
            fi
         done
        [ "$CPUcount" -eq 0 ] && printf '%s\t%4s\t%12s\n' "CPU" "NO" "Ambient Mode"
        [ "$TEMPgov" -eq 0 ] && [ "$CPUcount" -gt 1 ] && printf '%s\t%4s\t%12s\n' "$CPUcount CPU average" "OK" "$CPUn °C"
        [ "$TEMPgov" -eq 1 ] && [ "$CPUcount" -gt 1 ] && printf '%s\t%4s\t%12s\n' "$CPUcount CPU highest" "OK" "$CPUn °C"
        [[ ! -z "$AMBTEMP" ]] && printf '%s\t%4s\t%12s\n' "Ambient" "OK" "$AMBTEMP °C" || printf '%s\t%4s\t%12s\n' "Ambient" "NO" "NaN " 
        [[ ! -z "$EXHTEMP" ]] && printf '%s\t%4s\t%12s\n' "Exhaust" "OK" "$EXHTEMP °C" || printf '%s\t%4s\t%12s\n' "Exhaust" "NO" "NaN " 
        [[ "$TEMPMOD" != 0 ]] && printf '%s\t%4s\t%12s\n' "TEMPMOD" "OK" "+$TEMPMOD °C" || printf '%s\t%4s\t%12s\n' "TEMPMOD" "NO" "NaN "
        if [ "$CPUcount" != 0 ]; then
                [[ "$TEMP" != "$CPUn" ]] && printf '%s\t%4s\t%12s\n' "vTEMP" "OK" "$TEMP °C" || printf '%s\t%4s\t%12s\n' "vTEMP" "EQ" "$TEMP °C" 
        else
                printf '%s\t%4s\t%12s\n' "vTEMP" "OK" "$vTEMP °C"
        fi
        ) | column -t -s $'\t'
fi
ipmifanctl=(ipmitool -I lanplus -H "$IPMIHOST" -U "$IPMIUSER" -P "$IPMIPW" -y "$IPMIEK" raw 0x30 0x30)
function setfanspeed () { 
        TEMP_Check=$1
        TEMP_STEP=$2
        FS=$3
        if [[ $FS == "auto" ]]; then
                [ "$Logtype" != 0 ] && echo "> $TEMP_Check °C is higher or equal to $TEMP_STEP °C. Switching to automatic fan control"
                "${ipmifanctl[@]}" 0x01 0x01
        else
                HEX_value=$(printf '%#04x' "$FS")
                [ "$Logtype" != 0 ] && echo "> $TEMP_Check °C is lower or equal to $TEMP_STEP °C. Switching to manual $FS % control"
                "${ipmifanctl[@]}" 0x01 0x00
                "${ipmifanctl[@]}" 0x02 0xff "$HEX_value"
         fi
}
if [ $CPUcount -eq 0 ]; then
        echo "!! AMBIANT TEMPERATURE MODE !!"
        if [ $vTEMP -ge $AMBTEMP_MAX ]; then
                setfanspeed $vTEMP $AMBTEMP_MAX auto
        else        
                for ((i=0; i<AMB_STEP_COUNT; i++))
                do 
                        TEMP_STEPloop="AMBTEMP_STEP$i"
                        FSTloop="AMBTEMP_noCPU_FS_STEP$i"
                        if [ $vTEMP -le "${!TEMP_STEPloop}" ]; then
                                setfanspeed $vTEMP "${!TEMP_STEPloop}" "${!FSTloop}"
                                break
                        fi
                done
        fi
else
        if [ $TEMP -ge $MAXTEMP ]; then
                setfanspeed "$TEMP" $MAXTEMP auto
        else        
                for ((i=0; i<TEMP_STEP_COUNT; i++))
                do
                        TEMP_STEPloop="TEMP_STEP$i"
                        FSTloop="FST$i"
                        if [ $TEMP -le "${!TEMP_STEPloop}" ]; then
                                setfanspeed $TEMP "${!TEMP_STEPloop}" "${!FSTloop}"
                                break
                        fi
                done
        fi
fi
```

</p>
</details>

## Cron job yet?

Good, you added your script. Still, at this moment, it doesn't run by itself.

It's normal, for now it's just a script on a file, with no wit to it, it's not YET a cron job. You now have to give it a schedule (if you so desire).

Unraid makes it easy again.
Click on the droplist that should be showing "Schedule Disabled" as its selected option.
You should find a pre-made array of ready to go schedules as follow:

Schedule Disabled|
------------ |
Scheduled Hourly |
Scheduled Weekly |
Scheduled Monthly |
At Startup of Array | 
At Stopping of Array |
At First Array Start Only |
**Custom** |

The ones linked to array events execute on the array's "active time", aka after the array started, and before it shuts down, keep that in mind.

**But** that's not what we want for a script managing cooling. Polling data and adjusting fan speed must be on a schedule way tighter than hourly, so we will use the **Custom** option.

Selection the "Custom" option will pop a little text box to the right of the droplist, of which the formatting is important and follow standard cron job format.

Cron expressions speak in minutes, hours, day of the month, month, day of the week and year.

Before going more in depth, let's cut to the chase, if you want your script to run every minute, punch in: ```* * * * *```

**Keep in mind** that as stated before user scripts only run on Array uptime, meaning that setting up a script that puts back fan control on auto when you shut down the array is more than advised.

To do so, create a separate script, scheduled on "At stopping of Array", punching in your own infos and credentials, that goes as follow:
```bash
#!/bin/bash
IPMIHOST=192.168.0.42
#iDrac user
IPMIUSER=root
#iDrac password (calvin is the default password)
IPMIPW=calvin
#YOUR IPMI ENCRYPTION KEY - a big string of zeros is the default, and by default isn't mandatory to be specified.
#You can modify it, for example in idrac7's webinterface under iDRAC Settings>Network , in the IPMI Settings section.
IPMIEK=0000000000000000000000000000000000000000

#The command will just put fans back to auto.
ipmitool -I lanplus -H $IPMIHOST -U $IPMIUSER -P $IPMIPW -y $IPMIEK raw 0x30 0x30 0x01 0x01
```
With that, you're more or less set for the fan control.


## More cron
Well, you can do a lot with cron expressions, that's the gist of it.

<details>
<summary>
<b>Everything you need should be here</b>
</summary>
<p>

Instead of boring you with text, here's the alphabet of them:

Field Name |	Mandatory |	Allowed Values |	Allowed Special Characters |
------ | ------- | ------- | ------- |
Minutes |	YES |	0 - 59 |	, - \* / |
Hours |	YES |	0 - 23 |	, - \* / |
Day of month |	YES |	1 - 31 |	, - \* ? / L W |
Month |	YES |	1 - 12 (representing Jan - Dec), JAN - DEC (case-insensitive), JANUARY - DECEMBER (case-insensitive) |	, - \* / |
Day of week |	YES |	0 - 6, 7 (representing Sun - Sat and Sun again), SUN - SAT (case-insensitive), SUNDAY - SATURDAY (case-insensitive) |	, - \* ? / L # |
Year |	NO |	empty or 1970-2099 |	, - \* / |

And here a cheatsheet, you'll probably find what you're looking for in it, or be able to make it from it.
 
Cron Expression	examples | Meaning |
--------- | --------- |
\* \* \* \* \* 2022 |	Execute a cron job every minute during the year 2022 |
\* \* \* \* \* |	Execute a cron job every minute |
\*/5 \* \* \* \* |	Execute a cron job every 5 minutes |
0 \* \* \* \* |	Execute a cron job every hour |
0 12 \* \* \* |	Fire at 12:00 PM (noon) every day |
15 10 \* \* \* |	Fire at 10:15 AM every day |
15 10 \* \* ? |	Fire at 10:15 AM every day |
15 10 \* \* \* 2022-2024 |	Fire at 10:15 AM every day during the years 2022, 2023 and 2024 |
\* 14 \* \* \* |	Fire every minute starting at 2:00 PM and ending at 2:59 PM, every day |
0/5 14,18 \* \* \* |	Fire every 5 minutes starting at 2:00 PM and ending at 2:55 PM, AND fire every 5 minutes starting at 6:00 PM and ending at 6:55 PM, every day |
0-5 14 \* \* \* |	Fire every minute starting at 2:00 PM and ending at 2:05 PM, every day |
10,44 14 \* 3 3 |	Fire at 2:10 PM and at 2:44 PM every Wednesday in the month of March. |
15 10 \* \* 1-5 |	Fire at 10:15 AM every Monday, Tuesday, Wednesday, Thursday and Friday |
15 10 15 \* \* |	Fire at 10:15 AM on the 15th day of every month |
15 10 L \* \* |	Fire at 10:15 AM on the last day of every month |
15 10 \* \* 5L |	Fire at 10:15 AM on the last Friday of every month |
15 10 \* \* 5#3 |	Fire at 10:15 AM on the third Friday of every month |
0 12 1/5 \* \* |	Fire at 12:00 PM (noon) every 5 days every month, starting on the first day of the month. |
11 11 11 11 \* |	Fire every November 11th at 11:11 AM. |
11 11 11 11 \* 2022	| Fire at 11:11 AM on November 11th in the year 2022. |
0 0 \* \* 3 |	Fire at midnight of each Wednesday. |
0 0 1,2 \* \* |	Fire at midnight of 1st, 2nd day of each month |
0 0 1,2 \* 3 |	Fire at midnight of 1st, 2nd day of each month, and each Wednesday. |

</p>
</details>
