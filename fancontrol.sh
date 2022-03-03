#!/bin/bash
#the IP address of iDrac
IPMIHOST=192.168.0.42

#iDrac user
IPMIUSER=root

#iDrac password (calvin is the default password)
IPMIPW=calvin

#YOUR IPMI ENCRYPTION KEY - a big string of zeros is the default, and by default isn't mandatory to be specified.
#You can modify it, for example in idrac7's webinterface under iDRAC Settings>Network , in the IPMI Settings section.
IPMIEK=0000000000000000000000000000000000000000

#Side note: you shouldn't ever store credentials in a script. Period. Here it's an example. 
#I suggest you give a look at tools like https://github.com/plyint/encpass.sh 

#IPMI IDs
#/!\ IMPORTANT - the "0Fh"(CPU0),"0Eh"(CPU1), "04h"(inlet) and "01h"(exhaust) values are the proper ones for MY R720, maybe not for your server. 
#To check your values, use the "temppull.sh" script.
CPUID0=0Fh
CPUID1=0Eh
CPUID2="0#h"
CPUID3="0#h"
#Yes, there are 4 CPU servers in the poweredge line. I don't have one, so I left 0#h values for these. As said above, modify accordingly.
AMBIENT_ID=04h
EXHAUST_ID=01h
#-------------------------------------------------
#For G11 servers and some other unlucky ones:
#I was made aware that people on iDrac6, notably the R610, reported only having access to ambient temperature, and not CPU temps neither exhaust temps.
#Example:
#average of all core temps
#CPUTEMP=$(sensors -u | grep input | awk '{ total += $2; count++ } END { print total/count }')
#highest of all core temps
#CPUTEMP=$(sensors -u | grep input | awk '{print $2}' | sort -r | head -n1)
#In that case,  you will have to do with only Ambient temp to define your fan speed, or rely on other sources for the temperatures, like lm-sensors.
#Keep in mind though that this method is way less indicative of CPU temps. 
#If your load isn't consistent enough to properly profile your server, it might lead to overheating.
#-------------------------------------------------

#Logtype:
#0 = Only Alerts
#1 = Fan speed output + alerts
#2 = Simple text + fanspeed output + alerts
#3 = Table + fanspeed output + alerts
Logtype=2

#There you basically define your fan curve. For each fan step temperature (in °C) you define which fan speed it uses when it's equal or under this temp.
#For example: until it reaches step0 at 30°C, it runs at 2% fan speed, if it's above 30°C and under 35°C, it will run at 6% fan speed, ect
#Fan speed values are to be set as for each step in the FST# value, in % between 0 and 100.
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
#If Ambient temp is within range of $AMBTEMP_STEP#, it inflates the CPUs' temp average by AMBTEMP_STEP#_MOD when checked against TEMP_STEP#s.
#If Ambient temp is above $AMBTEMP_MAX, which is step 4, a temp modifier of 69 should be well enough to make the script select auto-fan mode.
#AMBTEMP_STEPX_noCPU_Fanspeed : Some servers don't report their CPU temps. In that case Fan speed can only be adjusted using Ambient temperature.
#In case of lack of CPU temps in IPMI, Fan speed values are to be defined here as for each step in the AMBTEMP_noCPU_FS_STEP# value, in % between 0 and 100.

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

#If your exhaust temp is reaching 65°C, you've been cooking your server. It needs the woosh.
EXHTEMP_MAX=65

#CPU fan governor type - keep in mind, with IPMI it's CPUs, not cores.
#0 = uses average CPU temperature accross CPUs
#1 = uses highest CPU temperature
TEMPgov=0
#Maximum allowed delta in TEMPgov0. If exceeded, switches profile to highest value.
CPUdelta=15

#Ambient fan mode - Delta mode
# => Fall back method when no CPU readings are available.
#Delta mode uses the temperature difference (delta) between intake (ambient) and exhaust to control fan-speed.
#To set the Deltatemp and fan speeds for each, use the parameters for the CPU fan mode profile.
#By default, for safety, the temperature is divided by 3, so for the default first step, 30°C of CPU temp, the delta value is 10°C.
#To modify the ratio, modify the value DeltaR. Default is 3, no ratio is 1.
AMBDeltaMode=true
DeltaR=3
#If in delta mode, ambient temp would warrant an higher fan speed according to the ambient profile, it will use ambient profile's
#recommendation as to protect your hardware from running with a low delta but with an overall too high temperature.
#If you lack Exhaust temps, there is a fallback method to solely ambient.
#If you lack Intake temps, the fall back method swaps Exhaust to intake temps, you need to modify Ambient temp stepping,
#because the values are too low, even if they are safe, since fans would run higher than you might want in that case.
#If you lack both readings, it falls back to auto-fan mode.

#Log loop debug - true or false, logging of loops for debugging script
Logloop=false

#Looplog prefix
l="Loop -"

#IPMI Commands to set fan speeds.
# "ipmitool -I lanplus -H $IPMIHOST -U $IPMIUSER -P $IPMIPW -y $IPMIEK raw 0x30 0x30 0x01 0x01" gives back to the server the right to automate fan speed
# "ipmitool -I lanplus -H $IPMIHOST -U $IPMIUSER -P $IPMIPW -y $IPMIEK raw 0x30 0x30 0x01 0x00" stops the server from adjusting fanspeed by itself, no matter the temp
# "ipmitool -I lanplus -H $IPMIHOST -U $IPMIUSER -P $IPMIPW -y $IPMIEK raw 0x30 0x30 0x02 0xff 0x"hex value 00-64" lets you define fan speed

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
                        echo "$l Ambient modifier for CPU temp step n°$i = +${!inloopmod}°C"
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
                        echo "$l Ambient max temperature to max mod = $AMBTEMP_MAX"
                        echo "$l CPU Ambiant Steps counting = stop"
                fi
                break
        fi
done
#Pulling temperature data
IPMIPULLDATA=$(ipmitool -I lanplus -H $IPMIHOST -U $IPMIUSER -P $IPMIPW -y $IPMIEK sdr type temperature)
DATADUMP=$(echo "$IPMIPULLDATA")
if [ -z "$DATADUMP" ]; then
        echo "No data was pulled from IPMI"
        setfanspeed XX XX auto 1
else
        AUTOEM=false
fi
#You can obviously use an other source than iDrac for your temperature readings, like lm-sensors for example. There it's an iDrac-centric example script.
CPUTEMP0=$(echo "$DATADUMP" |grep "$CPUID0" |grep degrees |grep -Po '\d{2}' | tail -1)
CPUTEMP1=$(echo "$DATADUMP" |grep "$CPUID1" |grep degrees |grep -Po '\d{2}' | tail -1)
CPUTEMP2=$(echo "$DATADUMP" |grep "$CPUID2" |grep degrees |grep -Po '\d{2}' | tail -1)
CPUTEMP3=$(echo "$DATADUMP" |grep "$CPUID3" |grep degrees |grep -Po '\d{2}' | tail -1)

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
        echo "$l Result = $CPUh"
        echo "$l Result = $CPUl"
        echo "$l CPU Find highest = stop"
    fi
fi
if [ $TEMPgov -eq 1 ] || [ $((CPUh-CPUl)) -gt $CPUdelta ]; then
        echo "!! CPU DELTA Exceeded !!"
        echo "Lowest : $CPUl"
        echo "Highest: $CPUh"
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
