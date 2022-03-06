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

#Side note: you shouldn't ever store credentials in a script. Period. Here it's an example. 
#I suggest you give a look at tools like https://github.com/plyint/encpass.sh 

#IPMI IDs
CPUID0=0Fh
CPUID1=0Eh
CPUID2="0#h"
CPUID3="0#h"
AMBIENT_ID=04h
EXHAUST_ID=01h

#Non-IPMI data source for CPU:
NICPU_toggle=false
NICPUdatadump_command=(sensors -A)
NICPUdatadump_device="coretemp-isa-"
NICPUdatadump_device_num=4
NICPUdatadump_core=Core
NICPUdatadump_cut="-c16-18"
NICPUdatadump_offset=0
IPMIDATA_toggle=true

#Logtype:
#0 = Only Alerts
#1 = Fan speed output + alerts
#2 = Simple text + fanspeed output + alerts
#3 = Table + fanspeed output + alerts
Logtype=2

#There you basically define your fan curve.
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

#These values are used as steps for the intake temps.

AMBTEMP_STEP0=20
AMBTEMP_MOD_STEP0=0
AMBTEMP_noCPU_FS_STEP0=8

AMBTEMP_STEP1=21
AMBTEMP_MOD_STEP1=10
AMBTEMP_noCPU_FS_STEP1=15

AMBTEMP_STEP2=24
AMBTEMP_MOD_STEP2=15
AMBTEMP_noCPU_FS_STEP2=20

AMBTEMP_STEP3=26
AMBTEMP_MOD_STEP3=20
AMBTEMP_noCPU_FS_STEP3=30

MAX_MOD=69

EXHTEMP_MAX=65

#CPU fan governor type 
TEMPgov=0
CPUdelta=15

AMBDeltaMode=true
DeltaR=3

#Log loop debug
Logloop=false
l="Loop -"

#Hexadecimal conversion and IPMI command into a function 
ipmifanctl=(ipmitool -I lanplus -H "$IPMIHOST" -U "$IPMIUSER" -P "$IPMIPW" -y "$IPMIEK" raw 0x30 0x30)
function setfanspeed () { 
        TEMP_Check=$1
        TEMP_STEP=$2
        FS=$3
        if [[ $FS == "auto" ]]; then
                if [ "$Logtype" != 0 ] && [ "$4" -eq 0 ]; then
                        echo "> $TEMP_Check °C is higher or equal to $TEMP_STEP °C. Switching to automatic fan control"
                fi
                [ "$4" -eq 1 ] && echo "> ERROR : Keeping fans on auto as safety measure"
                "${ipmifanctl[@]}" 0x01 0x01
                exit $4
        else
                HEX_value=$(printf '%#04x' "$FS")
                [ "$Logtype" != 0 ] && echo "> $TEMP_Check °C is lower or equal to $TEMP_STEP °C. Switching to manual $FS % control"
                "${ipmifanctl[@]}" 0x01 0x00
                "${ipmifanctl[@]}" 0x02 0xff "$HEX_value"
                exit $4
         fi
}
#Failsafe = Parameter check
re='^[0-9]+$'
ren='^[+-]?[0-9]+?$'
if [ "$Logloop" != false ] && [ "$Logloop" != true ]; then
        echo "Logloop parameter invalid, must be true or false!"
        setfanspeed XX XX auto 1
fi
if [ "$AMBDeltaMode" != false ] && [ "$AMBDeltaMode" != true ]; then
        echo "AMBDeltaMode parameter invalid, must be true or false!"
        setfanspeed XX XX auto 1
fi
if [[ "$DeltaR" =~ $ren ]]; then
        if [ "$DeltaR" -le "0" ]; then
                echo "DeltaR parameter invalid, must be greater than 0!"
                setfanspeed XX XX auto 1
        fi
else
        echo "DeltaR parameter invalid, not a number!"
        setfanspeed XX XX auto 1
fi
if [[ "$CPUdelta" =~ $ren ]]; then
        if [ "$CPUdelta" -le "0" ]; then
                echo "CPUdelta parameter invalid, must be greater than 0!"
                setfanspeed XX XX auto 1
        fi
else
        echo "CPUdelta parameter invalid, not a number!"
        setfanspeed XX XX auto 1
fi
if [ "$TEMPgov" != 1 ] && [ "$TEMPgov" != 0 ]; then
        echo "TEMPgov parameter invalid, can only be 0 or 1!"
        setfanspeed XX XX auto 1
fi
if [[ "$Logtype" =~ $ren ]]; then
        if [ "$Logtype" -lt 0 ] || [ "$Logtype" -gt 3 ]; then
                echo "Logtype parameter invalid, must be in 0-3 range!"
                setfanspeed XX XX auto 1
        fi
else
        echo "Logtype parameter invalid, not a number!"
        setfanspeed XX XX auto 1
fi
if [[ "$EXHTEMP_MAX" =~ $ren ]]; then
        if [ "$EXHTEMP_MAX" -lt 0 ]; then
                echo "EXHTEMP_MAX parameter invalid, can't be negative!"
                setfanspeed XX XX auto 1
        fi
else
        echo "EXHTEMP_MAX parameter invalid, not a number!"
        setfanspeed XX XX auto 1
fi
if [[ $MAX_MOD =~ $ren ]]; then
        if [ "$MAX_MOD" -lt 0 ]; then
                echo "MAX_MOD parameter invalid, can't be negative!"
                setfanspeed XX XX auto 1
        fi
else
        echo "MAX_MOD parameter invalid, not a number!"
        setfanspeed XX XX auto 1
fi
#Counting CPU Fan speed steps and setting max value
if $Logloop ; then
        echo "$l New loop => Counting CPU Fan speed steps and setting max value"
fi
for ((i=0; i>=0 ; i++))
do
        inloopstep="TEMP_STEP$i"
        inloopspeed="FST$i"
        if [[ ! -z "${!inloopspeed}" ]] && [[ ! -z "${!inloopstep}" ]]; then
                if $Logloop ; then
                        echo "$l CPU Temperature step n°$i = ${!inloopstep}°C"
                        echo "$l Fan speed step n°$i = ${!inloopspeed}%"
                fi
                if ! [[ "${!inloopstep}" =~ $ren ]]; then
                        echo "Butterfinger failsafe: CPU Temperature step n°$i isn't a number!"
                        setfanspeed XX XX auto 1
                fi
                if [[ "${!inloopspeed}" =~ $ren ]]; then
                        if [[ "${!inloopspeed}" -lt 0 ]]; then
                                echo "Butterfinger failsafe: Fan speed step n°$i is negative!"
                                setfanspeed XX XX auto 1
                        fi

                else
                        echo "Butterfinger failsafe: Fan speed step n°$i isn't a number!"
                        setfanspeed XX XX auto 1
                fi
        else
                inloopmaxstep="TEMP_STEP$((i-1))"
		if [ $((i-1)) -le 0 ]; then
                        echo "Butterfinger failsafe: no CPU stepping found!!"
                        setfanspeed XX XX auto 1
                fi
                MAXTEMP="${!inloopmaxstep}"
                TEMP_STEP_COUNT=$i
                if $Logloop ; then
                        echo "$l CPU temperature step count = $i"
                        echo "$l CPU max temperature to auto mode = $MAXTEMP°C"
                        echo "$l CPU Temp Steps counting = stop"
                fi
                break
        fi
done
#Counting Ambiant Fan speed and MOD steps and setting max value
if $Logloop ; then
        echo "$l New loop => Counting Ambiant Fan speed and MOD steps and setting max value"
fi
for ((i=0; i>=0 ; i++))
do
        inloopstep="AMBTEMP_STEP$i"
        inloopspeed="AMBTEMP_noCPU_FS_STEP$i"
        inloopmod="AMBTEMP_MOD_STEP$i"
        if [[ ! -z "${!inloopspeed}" ]] && [[ ! -z "${!inloopmod}" ]] && [[ ! -z "${!inloopstep}" ]]; then
                if $Logloop ; then
                        echo "$l Ambient temperature step n°$i = ${!inloopstep}°C"
                        echo "$l Ambient modifier for CPU temp step n°$i = ${!inloopmod}°C"
                        echo "$l Ambient NO CPU fan speed step n°$i = ${!inloopspeed}%"
                fi
                if ! [[ "${!inloopstep}" =~ $ren ]]; then
                        echo "Butterfinger failsafe: Ambient temperature step n°$i isn't a number!"
                        setfanspeed XX XX auto 1
                fi
                if [[ "${!inloopmod}" =~ $ren ]]; then
                        if [[ "${!inloopmod}" -lt 0 ]]; then
                                echo "Beware: Ambient modifier for CPU temp step n°$i is negative!"
                                echo "Proceeding..."
                        fi

                else
                        echo "Butterfinger failsafe: Ambient modifier for CPU temp step n°$i isn't a number!"
                        setfanspeed XX XX auto 1
                fi
                if [[ "${!inloopspeed}" =~ $ren ]]; then
                        if [[ "${!inloopspeed}" -lt 0 ]]; then
                                echo "Butterfinger failsafe: Ambient NO CPU fan speed step n°$i is negative!"
                                setfanspeed XX XX auto 1
                        fi

                else
                        echo "Butterfinger failsafe: Ambient NO CPU fan speed step n°$i isn't a number!"
                        setfanspeed XX XX auto 1
                fi
        else
                inloopmaxstep="AMBTEMP_STEP$((i-1))"
		if [ $((i-1)) -le 0 ]; then
                        echo "Butterfinger failsafe: no Ambient stepping found!!"
                        setfanspeed XX XX auto 1
                fi
                AMBTEMP_MAX="${!inloopmaxstep}"
                AMB_STEP_COUNT=$i
                if $Logloop ; then
                        echo "$l Ambient temperature step count = $i"
                        echo "$l Ambient max temperature to max mod = $AMBTEMP_MAX°C"
                        echo "$l CPU Ambiant Steps counting = stop"
                fi
                break
        fi
done
#Pulling temperature data from IPMI
if $IPMIDATA_toggle ; then
	IPMIPULLDATA=$(ipmitool -I lanplus -H $IPMIHOST -U $IPMIUSER -P $IPMIPW -y $IPMIEK sdr type temperature)
	DATADUMP=$(echo "$IPMIPULLDATA")
	if [ -z "$DATADUMP" ]; then
		echo "No data was pulled from IPMI"
		setfanspeed XX XX auto 1
	else
		AUTOEM=false
	fi
else
	if $NICPU_toggle ; then
		AUTOEM=false
	else
		echo "Both IPMI data and Non-IPMI-CPU data are toggled off"
		setfanspeed XX XX auto 1
	fi
fi
#Parsing CPU Temp data into values to be later checked in count, continuity and value validity.
if $NICPU_toggle ; then
	echo "Non-IPMI data source. An error can be thrown without incidence."
	if $Logloop ; then
		echo "$l New loop => Pulling data dynamically from Non-IPMI source"
	fi
	for ((j=0; j>=0 ; j++))
	do
		[ -z "$socketcount" ] && socketcount=0
		datadump=$("$NICPUdatadump_command" "$NICPUdatadump_device$(printf "%0"$NICPUdatadump_device_num"d" "$socketcount")")
		if [[ ! -z $datadump ]]; then
			if $Logloop ; then
				echo "$l Detected CPU socket $socketcount !!"
				echo "$l New loop => Parsing CPU Core data"
			fi
			socketcount=$((socketcount+1))
			for ((i=0; i>=0 ; i++))
			do
				[ -z "$corecount" ] && corecount=0
				Corecountloop_data=$( echo "$datadump" | grep -A 0 "$NICPUdatadump_core $i"| cut "$NICPUdatadump_cut")
				if [[ ! -z $Corecountloop_data ]]; then
					declare CPUTEMP$corecount="$((Corecountloop_data+NICPUdatadump_offset))"
					if $Logloop ; then
						echo "$l Defining CPUTEMP$corecount with value : $((CPUTEMP$corecount))"
					fi
					corecount=$((corecount+1))
				else
					if $Logloop ; then
						echo "$l CPU Core data parsing on CPU Socket $((socketcount-1)) = stop"
					fi
					break
				fi
			done
		else
			echo "Non-IPMI detection : done."
			if $Logloop ; then
				echo "$l Result : $corecount Total CPU temperature sources added."
				echo "$l CPU Data parsing from Non-IPMI source = stop"
			fi
			break
		fi
	done
else
	CPUTEMP0=$(echo "$DATADUMP" |grep "$CPUID0" |grep degrees |grep -Po '\d{2}' | tail -1)
	CPUTEMP1=$(echo "$DATADUMP" |grep "$CPUID1" |grep degrees |grep -Po '\d{2}' | tail -1)
	CPUTEMP2=$(echo "$DATADUMP" |grep "$CPUID2" |grep degrees |grep -Po '\d{2}' | tail -1)
	CPUTEMP3=$(echo "$DATADUMP" |grep "$CPUID3" |grep degrees |grep -Po '\d{2}' | tail -1)
fi
#CPU counting
if [ -z "$CPUTEMP0" ]; then
        CPUcount=0
else
        if [[ ! -z "$CPUTEMP0" ]]; then #Infinite CPU number adding, if you pull individual CPU cores from lm-sensors or something
                for ((i=0; i>=0 ; i++))
                    do
                        CPUcountloop="CPUTEMP$i"
                        if [[ ! -z "${!CPUcountloop}" ]]; then
                                if $Logloop ; then
                                        echo "$l CPU detection = CPU$i detected / Value = ${!CPUcountloop}"
                                fi
                                if ! [[ "${!CPUcountloop}" =~ $re ]] ; then
                                   echo "!!error: Reading is not a number or negative!!"
                                   echo "Falling back to ambient mode..."
                                   CPUcount=0
                                   break
                                fi
                                currcputemp="${!CPUcountloop}"
                                CPUcount=$((i+1))
                                TEMPadd=$((TEMPadd+currcputemp))
                        else
                                if [[ $((CPUcount % 2)) -eq 0 ]] || [[ $CPUcount -eq 1 ]]; then
                                        if $Logloop ; then
                                                if [ "$CPUcount" -eq "1" ]; then
                                                        echo "$l CPU count : $CPUcount CPU detected!"
                                                else
                                                        echo "$l CPU count is even : $CPUcount CPU detected!"
                                                fi
                                                echo "$l CPU counting = stop"
                                        fi
                                        CPUn=$((TEMPadd/CPUcount))
                                        break
                                else
                                        CPUcount=0
                                        echo "CPU count is odd, please check your configuration";
                                        echo "Falling back to ambient mode..."
                                        break
                                fi
                        fi
                done

        fi
fi
#CPU Find lowest and highest CPU temps
if [ "$CPUcount" -gt 1 ]; then
        if $Logloop ; then
                echo "$l New loop => Finding highest and lowest CPU temps"
        fi
        for ((i=0; i<CPUcount; i++)) #General solution to finding the highest number with a shitty shell loop
            do if [[ $i -le $CPUcount ]]; then
                CPUtemploop="CPUTEMP$i"
                if $Logloop ; then
                        echo "$l Checking for CPU$i = ${!CPUtemploop}°C"
                fi
                if [ "$i" -eq 0 ]; then
                      CPUh=${!CPUtemploop}
                      CPUl=${!CPUtemploop}
                else
                    if [ ${!CPUtemploop} -gt $CPUh ]; then
                        if $Logloop ; then
                                echo "$l New high! CPU$i = ${!CPUtemploop}°C"
                        fi
                        CPUh=${!CPUtemploop}
                    fi
                    if [ ${!CPUtemploop} -lt $CPUl ]; then
                        if $Logloop ; then
                                echo "$l New low! CPU$i = ${!CPUtemploop}°C"
                        fi
                        CPUl=${!CPUtemploop}
                    fi
                fi
            fi
        done
    if $Logloop ; then
        echo "$l Lowest = $CPUl°C"
        echo "$l Highest = $CPUh°C"
        echo "$l CPU Find highest = stop"
    fi
fi
if [ $TEMPgov -eq 1 ] || [ $((CPUh-CPUl)) -gt $CPUdelta ]; then
        echo "!! CPU DELTA Exceeded !!"
        echo "Lowest : $CPUl°C"
        echo "Highest: $CPUh°C"
        echo "Delta Max: $CPUdelta °C"
        echo "Switching CPU profile..."
        CPUdeltatest=1
        CPUn=$CPUh
fi
#Ambient temperature modifier when CPU temps are available.
AMBTEMP=$(echo "$DATADUMP" |grep "$AMBIENT_ID" |grep degrees |grep -Po '\d{2}' | tail -1)
if [ $CPUcount != 0 ]; then
        if [[ ! -z "$AMBTEMP" ]]; then
                if $Logloop ; then
                        echo "$l New loop => Ambient temperature modifier"
                fi
                if [ "$AMBTEMP" -ge $AMBTEMP_MAX ]; then
                        echo "Intake temp is very high!! : $AMBTEMP °C!"
                        TEMPMOD=$MAX_MOD
                else
                        for ((i=0; i<AMB_STEP_COUNT; i++))
                        do
                                AMBTEMP_STEPloop="AMBTEMP_STEP$i"
                                if $Logloop ; then
                                        echo "$l Checking for Ambient temperature($AMBTEMP) =< Ambient temperature step n°$i(${!AMBTEMP_STEPloop})"
                                fi
                                if [ "$AMBTEMP" -le "${!AMBTEMP_STEPloop}" ]; then
                                        AMBTEMP_MOD_STEPloop="AMBTEMP_MOD_STEP$i"
                                        TEMPMOD="${!AMBTEMP_MOD_STEPloop}"
                                        if $Logloop ; then
                                                echo "$l Result Checking for Ambient temperature($AMBTEMP) is =< Ambient temperature step n°$i(${!AMBTEMP_STEPloop})"
                                                echo "$l Ambient temperature modifier for CPU fans speed set to +${!AMBTEMP_MOD_STEPloop}°C"
                                                echo "$l Ambient temperature Modifier check - Stop"
                                        fi
                                        break
                                fi
                        done
                fi
	fi
fi
#Exhaust temperature modifier when CPU temps are available and Checks for Delta Mode and Ambient mode
EXHTEMP=$(echo "$DATADUMP" |grep "$EXHAUST_ID" |grep degrees |grep -Po '\d{2}' | tail -1)
if [ $CPUcount != 0 ]; then
        if [[ ! -z "$EXHTEMP" ]]; then
                if [ "$EXHTEMP" -ge $EXHTEMP_MAX ]; then
                        echo "Exhaust temp is critical!! : $EXHTEMP °C!"
                        TEMPMOD=$MAX_MOD
                fi
        fi
else
        if $AMBDeltaMode ; then
                if [[ -z "$EXHTEMP" ]] && [[ ! -z "$AMBTEMP" ]]; then
                        echo "DELTA MODE ERROR => MISSING EXHAUST READING"
                        echo "FALL BACK TO DEFAULT AMBIENT MODE"
                        AMBDeltaMode=false
                        EMAMBmode=false
                elif [[ ! -z "$EXHTEMP" ]] && [[ -z "$AMBTEMP" ]]; then
                        echo "DELTA MODE ERROR => MISSING AMBIENT READING"
                        echo "FALL BACK TO EMERGENCY AMBIENT MODE"
                        echo "!!EMERGENCY MODE => USING AMBIANT PROFILE WITH EXHAUST TEMP!!"
                        AMBDeltaMode=false
                        EMAMBmode=true
                elif [[ -z "$EXHTEMP" ]] && [[ -z "$AMBTEMP" ]]; then
                        echo "DELTA MODE ERROR => MISSING AMBIENT READING"
                        echo "DELTA MODE ERROR => MISSING EXHAUST READING"
                        echo "!!EMERGENCY MODE => FALL BACK TO AUTO FAN PROFILE!!"
                        AMBDeltaMode=false
                        AUTOEM=true
                elif [[ -z "$DeltaR" ]] || [[ "$DeltaR" -le 0 ]]; then
                        echo "DELTA MODE ERROR => DELTA RATIO INVALID"
                        echo "!!EMERGENCY MODE => FALL BACK TO AUTO FAN PROFILE!!"
                        AMBDeltaMode=false
                        AUTOEM=true
                fi
        else
                if [[ ! -z "$EXHTEMP" ]] && [[ -z "$AMBTEMP" ]]; then
                        echo "!!MISSING AMBIENT READING!!"
                        echo "FALL BACK TO EMERGENCY AMBIENT MODE"
                        echo "!!EMERGENCY MODE => USING AMBIANT PROFILE WITH EXHAUST TEMP!!"
                        EMAMBmode=true
                elif [[ -z "$EXHTEMP" ]] && [[ -z "$AMBTEMP" ]]; then
                        echo "NO TEMPERATURE READINGS"
                        echo "!!EMERGENCY MODE => FALL BACK TO AUTO FAN PROFILE!!"
                        AUTOEM=true
                else
                        EMAMBmode=false
                        if [[ ! -z "$EXHTEMP" ]]; then
                                if [ "$EXHTEMP" -ge $EXHTEMP_MAX ]; then
                                        echo "Exhaust temp is critical!! : $EXHTEMP °C!"
                                        TEMPMOD=$MAX_MOD
                                fi
                        fi
                fi
        fi
fi
#vTemp
if [ -z "$TEMPMOD" ]; then
	TEMPMOD=0
fi
if [ $CPUcount != 0 ]; then
        vTEMP=$((CPUn+TEMPMOD))
else
        if [[ ! -z "$EXHTEMP" ]] && [[ ! -z "$AMBTEMP" ]]; then
                if $AMBDeltaMode ; then
                        if [ "$AMBTEMP" -ge "$EXHTEMP" ]; then
                                echo "!! Intake = $AMBTEMP°C / Exhaust = $EXHTEMP°C !!"
                                echo "?Insufficient or reverse airflow?"
                                echo "!!EMERGENCY MODE => FALL BACK TO AUTO FAN PROFILE!!"
                                AUTOEM=true
                        else
                                vTEMP=$((EXHTEMP-AMBTEMP))
                        fi
                else
                        if $EMAMBmode ; then
                                vTEMP=$EXHTEMP
                        else
                                vTEMP=$((AMBTEMP+TEMPMOD))
                        fi
                fi
        else
                if $EMAMBmode ; then
                        vTEMP=$EXHTEMP
                else
                        vTEMP=$((AMBTEMP+TEMPMOD))
                fi
        fi
fi
#Emergency mode trigger
if $AUTOEM ; then
        setfanspeed XX XX auto 1
fi
#Logtype logic
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
        [[ "$CPUcount" != 0 ]] && [[ "$TEMPMOD" != 0 ]] && echo "TEMPMOD = +$TEMPMOD °C"
        if [ "$CPUcount" -ge 1 ]; then 
                [ -z "$CPUdeltatest" ] && echo "CPUdelta = $CPUdelta °C" || echo "CPUdelta EX! = $CPUdelta °C"
        fi
        if [ "$CPUcount" != 0 ]; then
                echo  "vTEMP = $vTEMP °C" 
        else
                if $AMBDeltaMode ; then
                        echo "Delta Ratio = : $DeltaR "
                        echo "Delta A/E = $vTEMP °C"
                else
                        echo "Virtual Temp = +$vTEMP °C"
                fi
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
        if [ "$CPUcount" -ge 1 ]; then 
                [ -z "$CPUdeltatest" ] && printf '%s\t%4s\t%12s\n' "CPUdelta" "OK" "$CPUdelta °C" || printf '%s\t%4s\t%12s\n' "CPUdelta" "EX" "$CPUdelta °C"
        fi
        if [ "$CPUcount" != 0 ]; then
                [[ "$TEMPMOD" != 0 ]] && printf '%s\t%4s\t%12s\n' "TEMPMOD" "OK" "+$TEMPMOD °C" || printf '%s\t%4s\t%12s\n' "TEMPMOD" "NO" "NaN "
        fi
        if [ "$CPUcount" != 0 ]; then
                [[ "$vTEMP" != "$CPUn" ]] && printf '%s\t%4s\t%12s\n' "vTEMP" "OK" "$vTEMP °C" || printf '%s\t%4s\t%12s\n' "vTEMP" "EQ" "$vTEMP °C" 
        else
                if $AMBDeltaMode ; then
                        printf '%s\t%4s\t%12s\n' "Delta Ratio" "OK" ":$DeltaR "
                        printf '%s\t%4s\t%12s\n' "Delta A/E" "OK" "+$vTEMP °C"
                else
                        printf '%s\t%4s\t%12s\n' "vTEMP" "OK" "$vTEMP °C"
                fi
        fi
        ) | column -t -s $'\t'
fi
#Logtype logic end.

#Temp comparisons
if [ $CPUcount -eq 0 ]; then
        if $AMBDeltaMode ; then
                echo "!! A/E DELTA TEMPERATURE MODE !!"
                if [ $vTEMP -ge $((MAXTEMP / DeltaR)) ]; then
                        echo "!! A/E DELTA : Delta check = Temperature Critical trigger!!"
                        setfanspeed "$DeltaR x $vTEMP" $MAXTEMP auto 0
                else
                        if $Logloop ; then
                                echo "$l New loop => Defining fan speeds according to Delta A/E to CPU temp steps : $DeltaR"
                        fi
                        for ((i=0; i<TEMP_STEP_COUNT; i++))
                        do
                                TEMP_STEPloop="TEMP_STEP$i"
                                TEMP_STEPloop="${!TEMP_STEPloop}"
                                FSTloop="FST$i"
                                if $Logloop ; then
                                        echo "$l Test vTEMP(=EXHTEMP-AMBTEMP)($EXHTEMP-$AMBTEMP=$vTEMP) =< TEMP_STEP$i($TEMP_STEPloop) by ratio $DeltaR"
                                fi
                                if [ $vTEMP -le "$((TEMP_STEPloop / DeltaR))" ]; then
                                        if $Logloop ; then
                                                echo "$l Test vTEMP(=EXHTEMP-AMBTEMP)($EXHTEMP-$AMBTEMP=$vTEMP) is =< TEMP_STEP$i($TEMP_STEPloop) by ratio $DeltaR"
                                                echo "$l Buffering command #setfanspeed $DeltaR x $vTEMP°C $TEMP_STEPloop°C ${!FSTloop}%"
                                                echo "$l CPU temperature Fan Speed control - Stop"
                                        fi
                                        DAEloop_arg1="$DeltaR x $vTEMP"
                                        DAEloop_arg2=$TEMP_STEPloop
                                        DAEloop_arg3="${!FSTloop}"
                                        break
                                fi
                        done
                        if [ "$AMBTEMP" -ge $AMBTEMP_MAX ]; then
                                echo "!! A/E DELTA : Ambient check = Temperature Critical trigger!!"
                                setfanspeed "$AMBTEMP" $AMBTEMP_MAX auto 0
                        else        
                                if $Logloop ; then
                                        echo "$l New loop => Checking fan speeds according to values provided by Ambiant temp steps"
                                fi
                                for ((i=0; i<AMB_STEP_COUNT; i++))
                                do 
                                        TEMP_STEPloop="AMBTEMP_STEP$i"
                                        FSTloop="AMBTEMP_noCPU_FS_STEP$i"
                                        if $Logloop ; then
                                                echo "$l Test AMBTEMP($AMBTEMP) =< AMBTEMP_STEP$i(${!TEMP_STEPloop})"
                                        fi
                                        if [ "$AMBTEMP" -le "${!TEMP_STEPloop}" ]; then
                                                if $Logloop ; then
                                                        echo "$l Result AMBTEMP($AMBTEMP) is =< AMBTEMP_STEP$i(${!TEMP_STEPloop})"
                                                        echo "$l Buffering #setfanspeed $AMBTEMP°C ${!TEMP_STEPloop}°C ${!FSTloop}%"
                                                        echo "$l Ambient temperature Fan Speed control - Stop"
                                                fi
                                                AMBloop_arg1=$AMBTEMP
                                                AMBloop_arg2="${!TEMP_STEPloop}"
                                                AMBloop_arg3="${!FSTloop}"
                                                break
                                        fi
                                done
                        fi
                        if [ $AMBloop_arg3 -gt $DAEloop_arg3 ]; then
                                echo "Ambient temp fan step : $AMBloop_arg3 %"
                                echo "Delta A/E fan step : $DAEloop_arg3 %"
                                echo "Ambient temperature ($AMBloop_arg1°C) requires higher cooling than Delta A/E profile."
                                setfanspeed "$AMBloop_arg1" "$AMBloop_arg2" "$AMBloop_arg3" 0
                                if $Logloop ; then
                                        echo "$l Result Compare: Ambient profile selected"
                                fi
                        else
                                if $Logloop ; then
                                        echo "$l Result Compare: Delta A/E profile selected"
                                fi
                                setfanspeed "$DAEloop_arg1" "$DAEloop_arg2" "$DAEloop_arg3" 0
                        fi
                fi
        else
                echo "!! AMBIANT TEMPERATURE MODE !!"
                if [ $vTEMP -ge $AMBTEMP_MAX ]; then
                        echo "!! Ambient check = Temperature Critical trigger !!"
                        setfanspeed $vTEMP $AMBTEMP_MAX auto 0
                else        
                        if $Logloop ; then
                                echo "$l New loop => Defining fan speeds according to values provided by Ambiant temp steps"
                        fi
                        for ((i=0; i<AMB_STEP_COUNT; i++))
                        do 
                                TEMP_STEPloop="AMBTEMP_STEP$i"
                                FSTloop="AMBTEMP_noCPU_FS_STEP$i"
                                if $Logloop ; then
                                        echo "$l Test vTEMP($vTEMP) =< AMBTEMP_STEP$i(${!TEMP_STEPloop})"
                                fi
                                if [ $vTEMP -le "${!TEMP_STEPloop}" ]; then
                                        if $Logloop ; then
                                                echo "$l Result vTEMP($vTEMP) is =< AMBTEMP_STEP$i(${!TEMP_STEPloop})"
                                                echo "$l sending command #setfanspeed $vTEMP°C ${!TEMP_STEPloop}°C ${!FSTloop}%"
                                                echo "$l Ambient temperature Fan Speed control - Stop"
                                        fi
                                        setfanspeed $vTEMP "${!TEMP_STEPloop}" "${!FSTloop}" 0
                                        break
                                fi
                        done
                fi
        fi
else
        if [ $vTEMP -ge $MAXTEMP ]; then
                setfanspeed "$vTEMP" $MAXTEMP auto 0
                echo "!! CPU MODE : Temperature Critical trigger!!"
        else
                if $Logloop ; then
                        echo "$l New loop => Defining fan speeds according to values provided by CPU temp steps"
                fi
                for ((i=0; i<TEMP_STEP_COUNT; i++))
                do
                        TEMP_STEPloop="TEMP_STEP$i"
                        FSTloop="FST$i"
                        if $Logloop ; then
                                echo "$l Test vTEMP(=CPUn+TEMPMOD)($CPUn+$TEMPMOD=$vTEMP) =< TEMP_STEP$i(${!TEMP_STEPloop})"
                        fi
                        if [ $vTEMP -le "${!TEMP_STEPloop}" ]; then
                                if $Logloop ; then
                                        echo "$l Result TEMP(=CPUn+TEMPMOD)($CPUn+$TEMPMOD=$vTEMP) is =< TEMP_STEP$i(${!TEMP_STEPloop})"
                                        echo "$l Sending command #setfanspeed $vTEMP°C ${!TEMP_STEPloop}°C ${!FSTloop}%"
                                        echo "$l CPU temperature Fan Speed control - Stop"
                                fi
                                setfanspeed $vTEMP "${!TEMP_STEPloop}" "${!FSTloop}" 0
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
