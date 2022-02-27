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
#0 = None
#1 = Fan speed output
#2 = Simple text + fanspeed output
#3 = Table + fanspeed output
Logtype=3

#CPU fan governor type - keep in mind, it's CPUs, not cores. For dual and quad CPU configs
#0 = uses average CPU temperature accross CPUs
#1 = uses highest CPU temperature
TEMPgov=0

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
TEMP_STEP_COUNT=6
#MAXTEMP is the max combined CPU temp at which you still are using this "manual control" script, instead of letting the machine fend for itself with its automated parameters.
#It's basically the temp at which you're not comfortable ordering your server to stay quiet anymore and let it fight for its life.
MAXTEMP=$TEMP_STEP5

#These values are used as steps for the intake temps.
#If Ambient temp is within range of $AMBTEMP_STEP#, it inflates the CPUs' temp average by AMBTEMP_STEP#_MOD when checked against TEMP_STEP#s.
#If Ambient temp is above $AMBTEMP_MAX, which is step 4, a temp modifier of 69 should be well enough to make the script select auto-fan mode.
#AMBTEMP_STEPX_noCPU_Fanspeed : Some servers don't report their CPU temps. In that case Fan speed can only be adjusted using Ambient temperature.
#In case of lack of CPU temps in IPMI, Fan speed values are to be defined here as for each step in the AMBTEMP_noCPU_FS_STEP# value, in % between 0 and 100.

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

#If your exhaust temp is reaching 65°C, you've been cooking your server. It needs the woosh.
EXHTEMP_MAX=65

#Pulling temperature data
IPMIPULLDATA=$(ipmitool -I lanplus -H $IPMIHOST -U $IPMIUSER -P $IPMIPW -y $IPMIEK sdr type temperature)
DATADUMP=$(echo "$IPMIPULLDATA")
#You can obviously use an other source than iDrac for your temperature readings, like lm-sensors for example. There it's an iDrac-centric example script.
CPUTEMP0=$(echo "$DATADUMP" |grep "$CPUID0" |grep degrees |grep -Po '\d{2}' | tail -1)
CPUTEMP1=$(echo "$DATADUMP" |grep "$CPUID1" |grep degrees |grep -Po '\d{2}' | tail -1)
CPUTEMP2=$(echo "$DATADUMP" |grep "$CPUID2" |grep degrees |grep -Po '\d{2}' | tail -1)
CPUTEMP3=$(echo "$DATADUMP" |grep "$CPUID3" |grep degrees |grep -Po '\d{2}' | tail -1)

#CPU counting and gov
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
        for ((i=0; i<CPUcount; i++)) #General solution to finding the highest number with a shitty shell loop
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

#Ambient temperature modifier when CPU temps are available.
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

#Exhaust temperature modifier when CPU temps are available.
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
#vTemp
if [ $CPUcount != 0 ]; then
        TEMP=$((CPUn+TEMPMOD))
else
        vTEMP=$((AMBTEMP+TEMPMOD))
fi

#Log logic
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
#Log logic end.

# "ipmitool -I lanplus -H $IPMIHOST -U $IPMIUSER -P $IPMIPW -y $IPMIEK raw 0x30 0x30 0x01 0x01" gives back to the server the right to automate fan speed
# "ipmitool -I lanplus -H $IPMIHOST -U $IPMIUSER -P $IPMIPW -y $IPMIEK raw 0x30 0x30 0x01 0x00" stops the server from adjusting fanspeed by itself, no matter the temp
# "ipmitool -I lanplus -H $IPMIHOST -U $IPMIUSER -P $IPMIPW -y $IPMIEK raw 0x30 0x30 0x02 0xff 0x"hex value 00-64" lets you define fan speed

#Command as a var
ipmifanctl=(ipmitool -I lanplus -H "$IPMIHOST" -U "$IPMIUSER" -P "$IPMIPW" -y "$IPMIEK" raw 0x30 0x30)

#function to decluter the logic below 
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
