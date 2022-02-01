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

<details>
<summary>
<b>Also available here. Check link before for commented version with detailed info!</b>
</summary>
<p>

```bash
#!/bin/bash
TEMP_STEP0=30
FAN_SPEED0=0x02
FST0=2

TEMP_STEP1=35
FAN_SPEED1=0x06
FST1=6

TEMP_STEP2=40
FAN_SPEED2=0x08
FST2=8

TEMP_STEP3=50
FAN_SPEED3=0x0a
FST3=10

TEMP_STEP4=60
FAN_SPEED4=0x0c
FST4=12

TEMP_STEP5=75
FAN_SPEED5=0x14
FST5=20

MAXTEMP=$TEMP_STEP5

AMBTEMP_STEP1=20
AMBTEMP_STEP1_MOD=0

AMBTEMP_STEP2=23
AMBTEMP_STEP2_MOD=10

AMBTEMP_STEP3=26
AMBTEMP_STEP3_MOD=15

AMBTEMP_STEP4=26
AMBTEMP_STEP4_MOD=20

AMBTEMP_MAX=$AMBTEMP_STEP4
MAX_MOD=69

EXHTEMP_MAX=65

#the IP address of iDrac
IPMIHOST=192.168.0.42

#iDrac user
IPMIUSER=root

#iDrac password (calvin is the default password)
IPMIPW=calvin

#YOUR IPMI ENCRYPTION KEY 
IPMIEK=0000000000000000000000000000000000000000


IPMIPULLDATA=$(ipmitool -I lanplus -H $IPMIHOST -U $IPMIUSER -P $IPMIPW -y $IPMIEK sdr type temperature)
DATADUMP=$(echo "$IPMIPULLDATA")
CPUTEMP0=$(echo "$DATADUMP" |grep 0Fh |grep degrees |grep -Po '\d{2}' | tail -1)
CPUTEMP1=$(echo "$DATADUMP" |grep 0Eh |grep degrees |grep -Po '\d{2}' | tail -1)
TEMPadd=$((CPUTEMP0+CPUTEMP1))
CPUn=$((TEMPadd/2))
AMBTEMP=$(echo "$DATADUMP" |grep 04h |grep degrees |grep -Po '\d{2}' | tail -1)
if [ $AMBTEMP -ge $AMBTEMP_MAX ]; then
        echo "Intake temp is very high!! : $AMBTEMP °C!"
        TEMPMOD=$MAX_MOD
elif [ $AMBTEMP -le $AMBTEMP_STEP1 ]; then
        TEMPMOD=$AMBTEMP_STEP1_MOD
elif [ $AMBTEMP -le $AMBTEMP_STEP2 ]; then
        TEMPMOD=$AMBTEMP_STEP2_MOD
elif [ $AMBTEMP -le $AMBTEMP_STEP3 ]; then
        TEMPMOD=$AMBTEMP_STEP3_MOD
elif [ $AMBTEMP -le $AMBTEMP_STEP4 ]; then
        TEMPMOD=$AMBTEMP_STEP4_MOD
fi
EXHTEMP=$(echo "$DATADUMP" |grep 01h |grep degrees |grep -Po '\d{2}' | tail -1)
if [ $EXHTEMP -ge $EXHTEMP_MAX ]; then
        echo "Exhaust temp is critical!! : $EXHTEMP °C!"
        TEMPMOD=$MAX_MOD
fi
TEMP=$((CPUn+TEMPMOD))
#echo CPU0 : $CPUTEMP0 °C
#echo CPU1 : $CPUTEMP1 °C
echo CPUn average: $CPUn °C
echo Ambient Temp: $AMBTEMP °C
ipmifanctl=(ipmitool -I lanplus -H $IPMIHOST -U $IPMIUSER -P $IPMIPW -y $IPMIEK raw 0x30 0x30)
if [ $TEMP -ge $MAXTEMP ]; then
        echo " $TEMP is > $MAXTEMP. Switching to automatic fan control "
        "${ipmifanctl[@]}" 0x01 0x01
else
        "${ipmifanctl[@]}" 0x01 0x00
        if [ $TEMP -le $TEMP_STEP0 ]; then
                echo " $TEMP is < $TEMP_STEP0. Switching to manual $FST0 % control "
                "${ipmifanctl[@]}" 0x02 0xff $FAN_SPEED0
        elif [ $TEMP -le $TEMP_STEP1 ]; then
                echo " $TEMP is < $TEMP_STEP1. Switching to manual $FST1 % control "
                "${ipmifanctl[@]}" 0x02 0xff $FAN_SPEED1
        elif [ $TEMP -le $TEMP_STEP2 ]; then
                echo " $TEMP is < $TEMP_STEP2. Switching to manual $FST2 % control "
                "${ipmifanctl[@]}" 0x02 0xff $FAN_SPEED2
        elif [ $TEMP -le $TEMP_STEP3 ]; then
                echo " $TEMP is < $TEMP_STEP3. Switching to manual $FST3 % control "
                "${ipmifanctl[@]}" 0x02 0xff $FAN_SPEED3
        elif [ $TEMP -le $TEMP_STEP4 ]; then
                echo " $TEMP is < $TEMP_STEP4. Switching to manual $FST4 % control "
                "${ipmifanctl[@]}" 0x02 0xff $FAN_SPEED4
        elif [ $TEMP -le $TEMP_STEP5 ]; then
                echo " $TEMP is < $TEMP_STEP5. Switching to manual $FST5 % control "
                "${ipmifanctl[@]}" 0x02 0xff $FAN_SPEED5
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
