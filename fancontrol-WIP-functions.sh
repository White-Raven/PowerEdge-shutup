#!/bin/bash
Logloop=true


#Failsafe mode
#(Possible values being a number between 80 and 100, or "auto")
E_value="auto"

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
#Keep in mind though that this method is way less indicative of CPU temps. 
#If your load isn't consistent enough to properly profile your server, it might lead to overheating.
#In that case, you will have to do with only Ambient temp to define your fan speed, or rely on other sources for CPU temps.
#-------------------------------------------------


# CPU curve using new array population function
# DO NOT try to deactivate this curve or replace its ID, it will break the default profiles and failsafes.
C0_toggle=true
C0_fs_toggle=true
C0_mod_toggle=false
C0_os_toggle=false
C0_governor=0
C0_delta=15
C0_offset=0
C0_label="CPU"
#step 0
C0_TEMP0=30
C0_FS0=2
C0_MOD0=
C0_OS0=
#step 1
C0_TEMP1=35
C0_FS1=6
C0_MOD1=
C0_OS1=
#step 2
C0_TEMP2=40
C0_FS2=8
C0_MOD2=
C0_OS2=
#step 3
C0_TEMP3=50
C0_FS3=10
C0_MOD3=
C0_OS3=
#step 4
C0_TEMP4=60
C0_FS4=12
C0_MOD4=
C0_OS4=
#step 5
C0_TEMP5=75
C0_FS5=20
C0_MOD5=
C0_OS5=

# Ambient curve using new array population function
# DO NOT try to deactivate this curve or replace its ID, it will break the default profiles and failsafes.
C1_toggle=true
C1_fs_toggle=true
C1_mod_toggle=true
C1_os_toggle=false
C1_governor="ae"
C1_delta=15
C1_offset=0
C1_label="AMB"
#step 0
C1_TEMP0=20
C1_FS0=6
C1_MOD0=0
C1_OS0=0
#step 1
C1_TEMP1=22
C1_FS1=12
C1_MOD1=10
C1_OS1=0
#step 2
C1_TEMP2=24
C1_FS2=20
C1_MOD2=15
C1_OS2=5
#step 3
C1_TEMP3=26
C1_FS3=30
C1_MOD3=20
C1_OS3=10

#EXTRA CURVE Preparation routines
function curve_pre() {
    for ((k=0; k>=0 ; k++))
        do
            curve_toggle="C${k}_toggle"
            if [[ -z "${!curve_toggle}" ]] ; then
                Curve_ID=${k}
            fi
        done
}
function curve_post() {
    declare C${1}_delta=$Curve_Delta
    declare C${1}_toggle=$Curve_Toggle
    declare C${1}_offset=$Temperature_Offset
    declare C${1}_fs_toggle=$Curve_FanSpeed_Toggle
    declare C${1}_mod_toggle=$Curve_Modifier_Toggle
    declare C${1}_os_toggle=$Curve_Offset_Toggle
    Curve_Toggle=false
    unset Curve_FanSpeed_Toggle
    unset Curve_Modifier_Toggle
    unset Curve_Offset_Toggle
    unset Temperature_Offset
}


#EXTRA CURVE CONFIG -- For each new curve, copy the entire block    v   v   v   v   v   v   v   v   v   v
Curve_Toggle=false

Curve_Delta=15
Temperature_Offset=0
#>Curve effects
#The curve contains stepping to set fan speed
Curve_FanSpeed_Toggle=false
#The curve contains stepping to apply a modifier to an other curve's readings
Curve_Modifier_Toggle=false
#The curve contains stepping to apply a fan speed offset to an other curve's result
Curve_Offset_Toggle=false



#--------------</!\ vvv DO NOT MODIFY vvv /!\--------------0
if [[ $Curve_Toggle == "true" ]]; then                     #
    curve_pre
#--------------</!\ ^^^ DO NOT MODIFY ^^^ /!\--------------0 
    #step 0   
    declare C${Curve_ID}_TEMP0=40
    declare C${Curve_ID}_FS0=4
    declare C${Curve_ID}_MOD0=0
    declare C${Curve_ID}_OS0=0
    #step 1
    declare C${Curve_ID}_TEMP1=60
    declare C${Curve_ID}_FS1=15
    declare C${Curve_ID}_MOD1=10
    declare C${Curve_ID}_OS1=5

#--------------</!\ vvv DO NOT MODIFY vvv /!\--------------0
    curve_post $Curve_ID
fi
#--------------</!\ ^^^ DO NOT MODIFY ^^^ /!\--------------0
#EXTRA CURVE CONFIG -- For each new curve, copy the entire block    ^   ^   ^   ^   ^   ^   ^   ^   ^   ^


function setfanspeed() {
    exit 0
}



# Dynamically create an array by name
function arr() {
    [[ ! "$1" =~ ^[a-zA-Z_]+[a-zA-Z0-9_]*$ ]] && { echo "Invalid bash variable" 1>&2 ; return 1 ; }
    declare -g -a $1=\(\)   
}

# Insert incrementing by incrementing index eg. array+=(data)
function arr_insert() { 
    [[ ! "$1" =~ ^[a-zA-Z_]+[a-zA-Z0-9_]*$ ]] && { echo "Invalid bash variable" 1>&2 ; return 1 ; }
    declare -p "$1" > /dev/null 2>&1
    [[ $? -eq 1 ]] && { echo "Bash variable [${1}] doesn't exist" 1>&2 ; return 1 ; }
    declare -n r=$1
    r[${#r[@]}]=$2
}

# Update an index by position
function arr_set() {
    [[ ! "$1" =~ ^[a-zA-Z_]+[a-zA-Z0-9_]*$ ]] && { echo "Invalid bash variable" 1>&2 ; return 1 ; }
    declare -p "$1" > /dev/null 2>&1
    [[ $? -eq 1 ]] && { echo "Bash variable [${1}] doesn't exist" 1>&2 ; return 1 ; }
    declare -n r=$1 
    r[$2]=$3
}

# Get the array content ${array[@]}
function arr_get() {
    [[ ! "$1" =~ ^[a-zA-Z_]+[a-zA-Z0-9_]*$ ]] && { echo "Invalid bash variable" 1>&2 ; return 1 ; }
    declare -p "$1" > /dev/null 2>&1
    [[ $? -eq 1 ]] && { echo "Bash variable [${1}] doesn't exist" 1>&2 ; return 1 ; }
    declare -n r=$1 
    echo ${r[@]}
}

# Get the value stored at a specific index eg. ${array[0]}  
function arr_at() {
    [[ ! "$1" =~ ^[a-zA-Z_]+[a-zA-Z0-9_]*$ ]] && { echo "Invalid bash variable" 1>&2 ; return 1 ; }
    declare -p "$1" > /dev/null 2>&1
    [[ $? -eq 1 ]] && { echo "Bash variable [${1}] doesn't exist" 1>&2 ; return 1 ; }
    [[ ! "$2" =~ ^(0|[-]?[1-9]+[0-9]*)$ ]] && { echo "Array index must be a number" 1>&2 ; return 1 ; }
    declare -n r=$1 
    local max=${#r[@]}
    # Array has items and index is in range
    if [[ $max -gt 0 && $i -ge 0 && $i -lt $max ]]
    then 
        echo ${r[$2]}
    fi
}

# Get the value stored at a specific index eg. ${array[0]}  
function arr_count() {
    [[ ! "$1" =~ ^[a-zA-Z_]+[a-zA-Z0-9_]*$ ]] && { echo "Invalid bash variable " 1>&2 ; return 1 ; }
    declare -p "$1" > /dev/null 2>&1
    [[ $? -eq 1 ]] && { echo "Bash variable [${1}] doesn't exist" 1>&2 ; return 1 ; }
    declare -n r=$1
    echo ${#r[@]}
}

#>int_check "#1 name" "#2type(scope/max/min)" "#3 value" "#4 custom error" "#5 low/max/min" "#6 high"  
function int_check() {
    int_check_ERROR=false
    if [[ ! -z $3 ]]; then
        if [[ $3 =~ $ren ]]; then
            if [[ $2 == "scope" ]]; then
                if [[ $3 -lt $5 ]] || [[ $3 -gt $6 ]]; then
                    echo "Butterfinger failsafe: $1 is outside of scope! ($5 - $6)"
                    sint_check_ERROR=true
                fi
            elif [[ $2 == "max" ]]; then
                if [[ $3 -gt $5 ]]; then
                    echo "Butterfinger failsafe: $1 can't be higher than $5 !"
                    int_check_ERROR=true
                fi
            elif [[ $2 == "min" ]]; then
                if [[ $3 -lt $5 ]]; then
                    echo "Butterfinger failsafe: $1 can't be lower than $5 !"
                    int_check_ERROR=true
                fi
            else
                echo "Check type parameter is invalid."
                int_check_ERROR=true
            fi
        else
            echo "Butterfinger failsafe: $1 isn't a number!"
            int_check_ERROR=true
        fi
    else
        echo "Butterfinger failsafe: $1 value missing!"
        int_check_ERROR=true
    fi
    bool_check "$1 int_check" "$4" false
    if $int_check_ERROR; then
        if [[ $1 == "E_value" ]]; then
            E_value="auto"
        fi
        setfanspeed XX XX "$E_value" 1
    fi
}
function bool_check() {
    if [[ $2 == "true" ]] || [[ $2 == "false" ]]; then
        bool_check=true
    else
        echo "/!\  $1 Boolean check failed! Value=$2 /!\ "
        bool_check=false
    fi
    if [[ $bool_check ]] && [[ ! $3 ]] ; then
        setfanspeed XX XX "$E_value" 1
    fi
}
#>arraybuild curve "#1 temp array name" "#2 temp array source variable name (minus step number)" "#3 temp array offset value" 
#   "#4 fanspeed array toggle" "#5 fanspeed array name" "#6 fanspeed array source variable name (minus step number)"
#   "#7 modifier array toggle" "#8 modifier array name" "#9 modifier array source variable name (minus step number)"
#   "#10 fanspeed offset toggle" "#11 fanspeed offset name" "#12 fanspeed offset source variable name (minus step number)" "#13 maxtemp name (ex = )"
function arraybuildcurve() {
    arr "Curve_ts_${1}"
    if $(arr_at "C${1}_settings" "0") ; then 
        arr "Curve_fs_${1}"
    fi
    if $(arr_at "C${1}_settings" "1") ; then
        arr "Curve_mod_${1}"
    fi
    if $(arr_at "C${1}_settings" "2") ; then
        arr "Curve_os_${1}"
    fi
    for ((g=0; g>=0; g++))
    do
        inloopstep="C${1}_TEMP${g}"
        inloopspeed="C${1}_FS${g}"
        inloopmodifier="C${1}_MOD${g}"
        inloopspoffset="C${1}_OS${g}"
        if [[ ! -z "${!inloopstep}" ]]; then
            int_check "$inloopstep" scope "${!inloopstep}" false 20 105
            arr_insert "Curve_ts_${1}" "${!inloopstep}"
            if $(arr_at "C${1}_settings" "0"); then
                int_check "$inloopspeed" scope "${!inloopspeed}" false 0 100 
                arr_insert "Curve_fs_${1}" "${!inloopspeed}"
            fi
            if $(arr_at "C${1}_settings" "1"); then
                int_check "$inloopmodifier" scope "${!inloopmodifier}" false 0 100 
                arr_insert "Curve_mod_${1}" "${!inloopmodifier}"
            fi
            if $(arr_at "C${1}_settings" "2"); then
                int_check scope "$inloopspoffset" scope "${!inloopspoffset}" false 0 100 
                arr_insert "Curve_os_${1}" "${!inloopspoffset}"
            fi
        else
            if [ $g -le 0 ]; then
                echo "Butterfinger failsafe: $2 Curve active but no stepping present!!"
                setfanspeed XX XX "$E_value" 1
            fi
            if [[ $(arr_count "Curve_ts_${1}") != $g ]]; then
            echo "Butterfinger failsafe: $1 array count isn't equal to loop count!!"
            setfanspeed XX XX "$E_value" 1
            fi
            if $(arr_at "C${1}_settings" "0"); then
                if [[ $(arr_count "Curve_ts_${1}") != $(arr_count "Curve_fs_${1}") ]]; then
                echo "Butterfinger failsafe: Curve_fs_${1} array count isn't equal to Curve_ts_${1} array count!!"
                setfanspeed XX XX "$E_value" 1
                fi
            fi
            if $(arr_at "C${1}_settings" "1"); then
                if [[ $(arr_count "Curve_ts_${1}") != $(arr_count "Curve_mod_${1}") ]]; then
                echo "Butterfinger failsafe: Curve_mod_${1} array count isn't equal to Curve_ts_${1} array count!!"
                setfanspeed XX XX "$E_value" 1
                fi
            fi
            if $(arr_at "C${1}_settings" "2"); then
                if [[ $(arr_count "Curve_ts_${1}") != $(arr_count "Curve_os_${1}") ]]; then
                echo "Butterfinger failsafe: Curve_os_${1} array count isn't equal to Curve_ts_${1} array count!!"
                setfanspeed XX XX "$E_value" 1
                fi
            fi
            arr_set "C${1}_settings" "7" "$(arr_at "Curve_ts_${1}" "$((g-1))")"
            if $Logloop ; then
                    echo "$l $(arr_at "C${1}_settings" "6") loop count       = $g"
                    echo "$l Max step            = $(arr_at "C${1}_settings" "7")°C"
                    echo "$l Array building      = stop"
                    echo "$l Curve $1 Steps      = $(arr_get "Curve_ts_${1}")"
                    $(arr_at "C${1}_settings" "0") && echo "$l Curve $1 Fan Speeds = $(arr_get "Curve_fs_${1}")"
                    $(arr_at "C${1}_settings" "1") && echo "$l Curve $1 Modifiers  = $(arr_get "Curve_mod_${1}")"
                    $(arr_at "C${1}_settings" "2") && echo "$l Curve $1 Offsets    = $(arr_get "Curve_os_${1}")"
            fi
            break
        fi
    done
}
# arraybuildsettings "#1 curve id"
function arraybuildsettings() {
    arraybuild_ERROR=false
    fs_toggle="C${1}_fs_toggle"
    mod_toggle="C${1}_mod_toggle"
    os_toggle="C${1}_os_toggle"
    governor="C${1}_governor"
    delta="C${1}_delta"
    offset="C${1}_offset"
    label="C${1}_label"
    if [[ ! -z "${!fs_toggle}" ]] && [[ ! -z "${!mod_toggle}" ]] && [[ ! -z "${!os_toggle}" ]] && [[ ! -z "${!governor}" ]] && [[ ! -z "${!delta}" ]] && [[ ! -z "${!offset}" ]] && [[ ! -z "${!label}" ]]; then
        arr "C${1}_settings"
        bool_check "$fs_toggle" "${!fs_toggle}" true
        if $bool_check ; then
            arr_set "C${1}_settings" "0" "${!fs_toggle}"
        else
            echo "Error with fs"
            arraybuild_ERROR=true
        fi
        bool_check "$mod_toggle" "${!mod_toggle}" true
        if $bool_check ; then
            arr_set "C${1}_settings" "1" "${!mod_toggle}"
        else
            echo "Error with mod"
            arraybuild_ERROR=true
        fi
        bool_check "$os_toggle" "${!os_toggle}" true
        if $bool_check ; then
            arr_set "C${1}_settings" "2" "${!os_toggle}"
        else
            echo "Error with os"
            arraybuild_ERROR=true
        fi
        if [[ "${!governor}" == 0 ]] || [[ "${!governor}" == 1 ]] || [[ "${!governor}" == "ae" ]]  ; then
            arr_set "C${1}_settings" "3" "${!governor}"
        else
            echo "Error with governor"
            arraybuild_ERROR=true
        fi
        int_check "$delta" scope "${!delta}" false 0 50
        if $bool_check ; then
            arr_set "C${1}_settings" "4" "${!delta}"
        else
            echo "Error with delta"
            arraybuild_ERROR=true
        fi
        int_check "$offset" scope "${!offset}" false 0 50
        if $bool_check ; then
            arr_set "C${1}_settings" "5" "${!offset}"
        else
            echo "Error with offset"
            arraybuild_ERROR=true
        fi
        if [[ ! "${!label}" =~ [^A-Za-z0-9\&_-] ]] ; then
            arr_set "C${1}_settings" "6" "${!label}"
        else
            echo "${!label}"
            echo "Error with label"
            arraybuild_ERROR=true
        fi        
    else
        echo "Missing Parameters"
    fi
    if $arraybuild_ERROR; then
        echo "/!\ Error while building Curve$1 's settings /!\ "
        setfanspeed XX XX "$E_value" 1
    fi
}

#>arraybuilddata "#1 temp array name" "#2 temp array source variable name (minus step number)" "#3 temp array offset value"
function arraybuilddata() {
echo "nothing yet"
}

#governor "#1 Origin label" "#2 temp array id" "#4 mode (average(0)/highest(1)/1v2(ae))" "#4 Delta y/n" "#5 Delta value" 
function governor() {
    if [[ $3 == "ae" ]]; then
        echo "todo"
    elif [[ $3 == "1" ]] || [[ $3 == "0" ]] ; then
        if $Logloop ; then
                echo "$l New loop => Finding highest and lowest $1"
        fi
        for ((h=0; h<$(arr_count "C${2}_readings"); h++)) #General solution to finding the highest number with a shitty shell loop
            do
                inlooptemp=$(arr_at "C${2}_readings" "$h")
                if $Logloop ; then
                        echo "$l Checking for $6$h = ${!inlooptemp}°C"
                fi
                if [ "$h" -eq 0 ]; then
                      temphigh=${!inlooptemp}
                      templow=${!inlooptemp}
                else
                    if [ ${!inlooptemp} -gt $temphigh ]; then
                        if $Logloop ; then
                                echo "$l New high! $6$h = ${!inlooptemp}°C"
                        fi
                        temphigh=${!inlooptemp}
                    fi
                    if [ ${!inlooptemp} -lt $templow ]; then
                        if $Logloop ; then
                                echo "$l New low! $6$h = ${!inlooptemp}°C"
                        fi
                        templow=${!inlooptemp}
                    fi
                fi
            done
        if $Logloop ; then
            echo "$l Lowest = $templow°C"
            echo "$l Highest = $temphigh"
            echo "$l $6 Find highest = stop"
        fi

        if [ $TEMPgov -eq 1 ] || [ $((temphigh-templow)) -gt "$(arr_at "C${2}_settings" "4")" ]; then
            echo "!! $6 DELTA Exceeded !!"
            echo "Lowest : $templow°C"
            echo "Highest: $temphigh°C"
            echo "Delta Max: $CPUdelta °C"
            echo "Switching $6 profile..."
            declare C${2}_delta_E=1
            declare C${2}_ER=$temphigh
        fi
    else
        echo "!! $1 : Missing or invalid governor parameter!!"
        setfanspeed "${!2}" "${!4}" "$E_value" 0
    fi
}


#>tempcomp "#1 origin "CPU MOD"" "#2 value $vTEMP" "#3 operator ge/gt" "#4 valuemax $MAXTEMP" "#5 originlabel" "#6 curve id" "#7 tempcurvelabel "CPU temp steps""
function tempcomp() { 
    if [[ "$3" == "gt" ]] ; then
        [[ "${!2}" -gt "$(arr_at "C${6}_settings" "6")" ]] && crittemp=true || crittemp=false
    elif [[ "$3" == "ge" ]]; then
        [[ "${!2}" -ge "$(arr_at "C${6}_settings" "6")" ]] && crittemp=true || crittemp=false
    elif [[ "$3" != "ge" ]] && [[ "$3" != "gt" ]] ; then
        echo "!! $1 : Invalid critical parameter!!"
        setfanspeed XX XX "$E_value" 1
    fi
    if $crittemp; then
        echo "!! $1 : Temperature Critical trigger!!"
        setfanspeed "${!2}" "$(arr_at "C${1}_settings" "6")" "$E_value" 0
    else
        if $Logloop ; then
            echo "$l New loop => From $1 using $7"
        fi
        for ((t=0; t<$(arr_count "Curve_ts_${6}"); t++))
        do
            if $Logloop ; then
                echo "$l Test $2 =< Curve_ts_$6[$t]($(arr_at "Curve_ts_${6}" "$t"))"
            fi
            if [ $2 -le "$(arr_at "Curve_ts_${6}" "$t")" ]; then
                [[ $Logloop ]] && echo "$l Result $2 is =< Curve_ts_$6[$t]($(arr_at "Curve_ts_${6}" "$t"))"
                curve_fs_toggle="C${6}_fs_toggle"
                curve_mod_toggle="C${6}_mod_toggle"
                curve_os_toggle="C${6}_os_toggle"
                if "$(arr_at "C${6}_settings" "0")"; then
                    declare "C${6}_fs_op"=$(arr_at "Curve_fs_$6" "$t")
                    [[ $Logloop ]] && echo "$l Defining variable C${6}_fs_op with fanspeed $(arr_at "Curve_fs_$6" "$t") %"
                fi
                if "$(arr_at "C${6}_settings" "1")"; then
                    declare "C${6}_mod_op"=$(arr_at "Curve_mod_$6" "$t")
                    [[ $Logloop ]] && echo "$l Defining variable C${6}_mod_op with temp modifier $(arr_at "Curve_mod_$6" "$t")" 
                fi
                if "$(arr_at "C${6}_settings" "2")"; then
                    declare "C${6}_os_op"=$(arr_at "Curve_os_$6" "$t")
                    [[ $Logloop ]] && echo "$l Defining variable C${6}_os_op with speed offset $(arr_at "Curve_os_$6" "$t") %"
                fi
                [[ $Logloop ]] && echo "$l Origin $1 using $7 - Stop Loop." 
                break
            else
                if $Logloop ; then
                    echo "$l Test failed -> next iteration;"
                fi
            fi
        done
    fi
}

for ((k=0; k>=0 ; k++))
    do
        curve_toggle="C${k}_toggle"
        if [[ ! -z "${!curve_toggle}" ]] ; then
            if [[ "${!curve_toggle}" == "true" ]]; then
                arraybuildsettings "${k}" 
                arraybuildcurve "${k}"
            else
                echo "Disabled Curve"
                break
            fi     
        else
            if [[ ${k} == "0" ]]; then
                echo "/!\ No active curve detected /!\ "
                setfanspeed XX XX "$E_value" 1
            fi
            echo "End"
            break
        fi
    done


tempcomp "CPU MOD" 49 gt "C${id}_MAX" "" "0" "CPU temp steps"
tempcomp "AMB check" 22 gt "C${id}_MAX" "" "1" "CPU temp steps"

