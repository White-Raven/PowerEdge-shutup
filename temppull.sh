#!/bin/bash
#the IP address of your target iDrac
IPMIHOST=192.168.0.42

#iDrac user
IPMIUSER=root

#iDrac password (calvin is the default password)
IPMIPW=calvin

#YOUR IPMI ENCRYPTION KEY
IPMIEK=0000000000000000000000000000000000000000

#Side note: you shouldn't ever store credentials in a script. Period. Here it's an example. 
#I suggest you give a look at tools like https://github.com/plyint/encpass.sh 

ipmitool -I lanplus -H $IPMIHOST -U $IPMIUSER -P $IPMIPW -y $IPMIEK sdr type temperature

# Should return something like that:
#Inlet Temp | 04h | ok | 7.1 | 19 degrees C
#Exhaust Temp | 01h | ok | 7.1 | 36 degrees C
#Temp | 0Eh | ok | 3.1 | 41 degrees C
#Temp | 0Fh | ok | 3.2 | 40 degrees C

#It lets you know the "id" to grep for in the fancontrol.sh script.
