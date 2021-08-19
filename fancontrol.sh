#!/bin/bash
#MAXTEMP is the max combined CPU temp at which you still are using this "manual control" script, instead of letting the machine fend for itself with its automated parameters.
#It's basically the temp at which you're not comfortable ordering your server to stay quiet anymore and let it fight for its life.
MAXTEMP=75

#There you basically define your fan curve. For each fan step temperature (in °C) you define which fan speed it uses when it's equal or under this temp.
#For example: until it reaches step0 at 30°C, it runs at 2% fan speed, if it's above 30°C and under 35°C, it will run at 6% fan speed, ect
#Fan speed values are to be set as "0x" + "hexa decimal value", 00 to 64, corresponding to 00% to 100% fan speed.

#FSTS values are just there for echos blurping out fan % speed. Didn't automated conversion. Lazyness. I'm owning it.

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

#These values are used as steps for the intake temps.
#If Ambient temp is above $AMB_STEP#, it inflates the CPUs' temp average by AMBTEMP_MAX_MOD when checked against TEMP_STEP#s.
#If Ambient temp is above $AMB_MAX, a temp modifier of 69 should be well enough to make the script select auto-fan mode.

AMBTEMP_MAX=30
MAX_MOD=69

AMBTEMP_STEP1=20
AMBTEMP_STEP1_MOD=0

AMBTEMP_STEP2=23
AMBTEMP_STEP2_MOD=10

AMBTEMP_STEP3=26
AMBTEMP_STEP3_MOD=15

AMBTEMP_STEP4=26
AMBTEMP_STEP4_MOD=20

#If your exhaust temp is reaching 65°C, you've been cooking your server. It needs the woosh.
EXHTEMP_MAX=65

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

#Pulling temperature data
#/!\ IMPORTANT - the "0Fh" and "0Eh" values are the proper ones for MY R720, maybe not for your server. To check your values, check the "temppull.sh" file.
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
elif [ $AMBTEMP -ge $AMBTEMP_STEP1 ]; then
        TEMPMOD=$AMBTEMP_STEP1_MOD
elif [ $AMBTEMP -ge $AMBTEMP_STEP2 ]; then
        TEMPMOD=$AMBTEMP_STEP2_MOD
elif [ $AMBTEMP -ge $AMBTEMP_STEP3 ]; then
        TEMPMOD=$AMBTEMP_STEP3_MOD
elif [ $AMBTEMP -ge $AMBTEMP_STEP4 ]; then
        TEMPMOD=$AMBTEMP_STEP4_MOD
fi

EXHTEMP=$(echo "$DATADUMP" |grep 04h |grep degrees |grep -Po '\d{2}' | tail -1)
if [ $EXHTEMP -ge $EXHTEMP_MAX ]; then
        echo "Exhaust temp is critical!! : $EXHTEMP °C!"
        TEMPMOD=$MAX_MOD
        fi
TEMP=$((CPUn+TEMPMOD))
#echo CPU0 : $CPUTEMP0 °C
#echo CPU1 : $CPUTEMP1 °C
echo CPUn average: $CPUn °C
echo Ambient Temp: $AMBTEMP °C


# "ipmitool -I lanplus -H $IPMIHOST -U $IPMIUSER -P $IPMIPW -y $IPMIEK raw 0x30 0x30 0x01 0x01" gives back to the server the right to automate fan speed
# "ipmitool -I lanplus -H $IPMIHOST -U $IPMIUSER -P $IPMIPW -y $IPMIEK raw 0x30 0x30 0x01 0x00" stops the server from adjusting fanspeed by itself, no matter the temp
# "ipmitool -I lanplus -H $IPMIHOST -U $IPMIUSER -P $IPMIPW -y $IPMIEK raw 0x30 0x30 0x02 0xff 0x"hex value 00-64" lets you define fan speed


#-------------------------------------------------
#For G11 servers:
#I was made aware that people on iDrac6 reported only having access to ambient temperature, and not CPU temps.
#In that case, here's how to adapt fan speed to ambiant temperature: (see commented block just under)
#Yes that also means ditching the whole "$AMBTEMP" logic and var part.
#----------<

#IPMIPULLDATA=$(ipmitool -I lanplus -H $IPMIHOST -U $IPMIUSER -P $IPMIPW -y $IPMIEK sdr type temperature)
#TEMP=$(echo "$IPMIPULLDATA" |grep Ambient |grep degrees |grep -Po '\d{2}' | tail -1)

#echo Ambient temperature: $TEMP °C

#----------<
#Keep in mind though that this method is way less indicative of CPU temps. 
#If your load isn't consistent enough to properly profile your server, it might lead to overheating.
#I would also personally advise you to have less "steps", such one or 2 controlled speed, 
#and then above a certain ambiant temperature, let the server go full auto.
#-------------------------------------------------


if [ $TEMP -ge $MAXTEMP ]; then
        echo " $TEMP is > $MAXTEMP. Switching to automatic fan control "
        ipmitool -I lanplus -H $IPMIHOST -U $IPMIUSER -P $IPMIPW -y $IPMIEK raw 0x30 0x30 0x01 0x01
elif [ $TEMP -le $TEMP_STEP0 ]; then
        echo " $TEMP is < $TEMP_STEP0. Switching to manual $FST0 % control "
        ipmitool -I lanplus -H $IPMIHOST -U $IPMIUSER -P $IPMIPW -y $IPMIEK raw 0x30 0x30 0x01 0x00
        ipmitool -I lanplus -H $IPMIHOST -U $IPMIUSER -P $IPMIPW -y $IPMIEK raw 0x30 0x30 0x02 0xff $FAN_SPEED0
elif [ $TEMP -le $TEMP_STEP1 ]; then
        echo " $TEMP is < $TEMP_STEP1. Switching to manual $FST1 % control "
        ipmitool -I lanplus -H $IPMIHOST -U $IPMIUSER -P $IPMIPW -y $IPMIEK raw 0x30 0x30 0x01 0x00
        ipmitool -I lanplus -H $IPMIHOST -U $IPMIUSER -P $IPMIPW -y $IPMIEK raw 0x30 0x30 0x02 0xff $FAN_SPEED1
elif [ $TEMP -le $TEMP_STEP2 ]; then
        echo " $TEMP is < $TEMP_STEP2. Switching to manual $FST2 % control "
        ipmitool -I lanplus -H $IPMIHOST -U $IPMIUSER -P $IPMIPW -y $IPMIEK raw 0x30 0x30 0x01 0x00
        ipmitool -I lanplus -H $IPMIHOST -U $IPMIUSER -P $IPMIPW -y $IPMIEK raw 0x30 0x30 0x02 0xff $FAN_SPEED2
elif [ $TEMP -le $TEMP_STEP3 ]; then
        echo " $TEMP is < $TEMP_STEP3. Switching to manual $FST3 % control "
        ipmitool -I lanplus -H $IPMIHOST -U $IPMIUSER -P $IPMIPW -y $IPMIEK raw 0x30 0x30 0x01 0x00
        ipmitool -I lanplus -H $IPMIHOST -U $IPMIUSER -P $IPMIPW -y $IPMIEK raw 0x30 0x30 0x02 0xff $FAN_SPEED3
elif [ $TEMP -le $TEMP_STEP4 ]; then
        echo " $TEMP is < $TEMP_STEP4. Switching to manual $FST4 % control "
        ipmitool -I lanplus -H $IPMIHOST -U $IPMIUSER -P $IPMIPW -y $IPMIEK raw 0x30 0x30 0x01 0x00
        ipmitool -I lanplus -H $IPMIHOST -U $IPMIUSER -P $IPMIPW -y $IPMIEK raw 0x30 0x30 0x02 0xff $FAN_SPEED4
elif [ $TEMP -le $TEMP_STEP5 ]; then
        echo " $TEMP is < $TEMP_STEP5. Switching to manual $FST5 % control "
        ipmitool -I lanplus -H $IPMIHOST -U $IPMIUSER -P $IPMIPW -y $IPMIEK raw 0x30 0x30 0x01 0x00
        ipmitool -I lanplus -H $IPMIHOST -U $IPMIUSER -P $IPMIPW -y $IPMIEK raw 0x30 0x30 0x02 0xff $FAN_SPEED5
fi
