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

#the IP addresse of iDrac
IPMIHOST=10.10.7.71

#iDrac user
IPMIUSER=root

#iDrac password (calvin is the default password)
IPMIPW=calvin

#YOUR IPMI ENCRYPTION KEY
IPMIEK=0000000000000000000000000000000000000000

#Pulling temperature data
#/!\ IMPORTANT - the "0Fh" and "0Eh" values are the proper ones for MY R720, maybe not for your server. To check your values, check the "temppull.sh" file.
IPMIPULLDATA=$(ipmitool -I lanplus -H $IPMIHOST -U $IPMIUSER -P $IPMIPW -y $IPMIEK sdr type temperature)
CPUTEMP0=$(echo "$IPMIPULLDATA" |grep 0Fh |grep degrees |grep -Po '\d{2}' | tail -1)
CPUTEMP1=$(echo "$IPMIPULLDATA" |grep 0Eh |grep degrees |grep -Po '\d{2}' | tail -1)
TEMPadd=$((CPUTEMP0+CPUTEMP1))
TEMP=$((TEMPadd/2))


#echo CPU0 : $CPUTEMP0 °C
#echo CPU1 : $CPUTEMP1 °C
#echo CPUn average: $TEMP °C

# "ipmitool -I lanplus -H $IPMIHOST -U $IPMIUSER -P $IPMIPW -y $IPMIEK raw 0x30 0x30 0x01 0x01" gives back to the server the right to automate fan speed
# "ipmitool -I lanplus -H $IPMIHOST -U $IPMIUSER -P $IPMIPW -y $IPMIEK raw 0x30 0x30 0x01 0x00" stops the server from adjusting fanspeed by itself, no matter the temp
# "ipmitool -I lanplus -H $IPMIHOST -U $IPMIUSER -P $IPMIPW -y $IPMIEK raw 0x30 0x30 0x02 0xff 0x"hex value 00-64" lets you define fan speed

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
