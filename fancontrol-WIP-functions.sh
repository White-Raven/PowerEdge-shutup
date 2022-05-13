#!/bin/bash

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

#Non-IPMI data source for CPU:
NICPU_toggle=false
#Command, or you way to pull data per device (here, using coretemp driver's coretemp-isa-#### )
NICPUdatadump_command=(sensors -A)
#Top level Device scan
NICPUdatadump_device="coretemp-isa-"
#Top level device count of numbers. For example coretemp-isa-0000 and coretemp-isa-0001 on a R720, coretemp-isa-#### would be 4.
NICPUdatadump_device_num=4
#"Core #" label for grep
NICPUdatadump_core=Core
#Where to cut in the line
NICPUdatadump_cut="-c16-18"
#Temperature offset : Some drivers report higher or lower temps than real world. Your offset must be an integer (ex: 0, -5, 12)
NICPUdatadump_offset=0
#IPMI data can be still used for Ambient and Exhaust data, but if you want to ignore pulling IPMI data all together, you can toggle it to false.
IPMIDATA_toggle=true
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


#Log loop debug - true or false, logging of loops for debugging script
Logloop=true

#Looplog prefix
l="Loop -"

#Log functions - true or false, logging of functions for debugging script
LogFunc=true
BoolInt=false

#Looplog prefix
f="Func -"

function setfanspeed() {
    exit 0
}



# Dynamically create an array by name
function arr() {
    [[ ! "$1" =~ ^[a-zA-Z_]+[a-zA-Z0-9_]*$ ]] && { echo "Invalid bash variable arr()" 1>&2 ; return 1 ; }
    declare -g -a $1=\(\)   
}

# Insert incrementing by incrementing index eg. array+=(data)
function arr_insert() { 
    [[ ! "$1" =~ ^[a-zA-Z_]+[a-zA-Z0-9_]*$ ]] && { echo "Invalid bash variable arr_insert()" 1>&2 ; return 1 ; }
    declare -p "$1" > /dev/null 2>&1
    [[ $? -eq 1 ]] && { echo "Bash variable [${1}] doesn't exist" 1>&2 ; return 1 ; }
    declare -n r=$1
    r[${#r[@]}]=$2
}

# Update an index by position
function arr_set() {
    [[ ! "$1" =~ ^[a-zA-Z_]+[a-zA-Z0-9_]*$ ]] && { echo "Invalid bash variable arr_set()" 1>&2 ; return 1 ; }
    declare -p "$1" > /dev/null 2>&1
    [[ $? -eq 1 ]] && { echo "Bash variable [${1}] doesn't exist" 1>&2 ; return 1 ; }
    declare -n r=$1 
    r[$2]=$3
}

# Get the array content ${array[@]}
function arr_get() {
    [[ ! "$1" =~ ^[a-zA-Z_]+[a-zA-Z0-9_]*$ ]] && { echo "Invalid bash variable arr_get()" 1>&2 ; return 1 ; }
    declare -p "$1" > /dev/null 2>&1
    [[ $? -eq 1 ]] && { echo "Bash variable [${1}] doesn't exist" 1>&2 ; return 1 ; }
    declare -n r=$1 
    echo ${r[@]}
}

# Get the value stored at a specific index eg. ${array[0]}  
function arr_at() {
    [[ ! "$1" =~ ^[a-zA-Z_]+[a-zA-Z0-9_]*$ ]] && { echo "Invalid bash variable arr_at()" 1>&2 ; return 1 ; }
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

# Get the array index count eg. ${#array[@]}
function arr_count() {
    [[ ! "$1" =~ ^[a-zA-Z_]+[a-zA-Z0-9_]*$ ]] && { echo "Invalid bash variable arr_count()" 1>&2 ; return 1 ; }
    declare -p "$1" > /dev/null 2>&1
    [[ $? -eq 1 ]] && { echo "Bash variable [${1}] doesn't exist" 1>&2 ; return 1 ; }
    declare -n r=$1
    echo ${#r[@]}
}

# Dynamically create an assossiative array by name
function aarr() {
    [[ ! "$1" =~ ^[a-zA-Z_]+[a-zA-Z0-9_]*$ ]] && { echo "Invalid bash variable arr()" 1>&2 ; return 1 ; }
    declare -g -A $1
}

# Update an assossiative array by key
function aarr_set() {
    [[ ! "$1" =~ ^[a-zA-Z_]+[a-zA-Z0-9_]*$ ]] && { echo "Invalid bash variable arr_set()" 1>&2 ; return 1 ; }
    declare -p "$1" > /dev/null 2>&1
    [[ $? -eq 1 ]] && { echo "Bash variable [${1}] doesn't exist" 1>&2 ; return 1 ; }
    declare -n r=$1 
    r[$2]=$3
}

# Get the array content ${array[@]}
function aarr_get() {
    [[ ! "$1" =~ ^[a-zA-Z_]+[a-zA-Z0-9_]*$ ]] && { echo "Invalid bash variable arr_get()" 1>&2 ; return 1 ; }
    declare -p "$1" > /dev/null 2>&1
    [[ $? -eq 1 ]] && { echo "Bash variable [${1}] doesn't exist" 1>&2 ; return 1 ; }
    declare -n r=$1 
    echo ${r[@]}
}
# Get the array content ${array[@]}
function aarr_getkeys() {
    [[ ! "$1" =~ ^[a-zA-Z_]+[a-zA-Z0-9_]*$ ]] && { echo "Invalid bash variable arr_get()" 1>&2 ; return 1 ; }
    declare -p "$1" > /dev/null 2>&1
    [[ $? -eq 1 ]] && { echo "Bash variable [${1}] doesn't exist" 1>&2 ; return 1 ; }
    declare -n r=$1 
    echo ${!r[@]}
}

# Get the value stored at a specific key, for assossiative arrays eg. ${array[X]}  
function aarr_at() {
    [[ ! "$1" =~ ^[a-zA-Z_]+[a-zA-Z0-9_]*$ ]] && { echo "Invalid bash variable aarr_at()" 1>&2 ; return 1 ; }
    declare -p "$1" > /dev/null 2>&1
    [[ $? -eq 1 ]] && { echo "Bash variable [${1}] doesn't exist" 1>&2 ; return 1 ; }
    [[ ! "$2" =~ ^[a-zA-Z_]+[a-zA-Z0-9_]*$ ]] && { echo "Invalid index variable aarr_at()" 1>&2 ; return 1 ; }
    declare -n r=$1 
    echo ${r[$2]}
}

# Get the value stored at a specific label, for assossiative arrays eg. ${array[X]}  
function aarr_test() {
    unset $aarr_test
    [[ ! "$1" =~ ^[a-zA-Z_]+[a-zA-Z0-9_]*$ ]] && { echo "Invalid bash variable aarr_at()" 1>&2 ; return 1 ; }
    declare -p "$1" > /dev/null 2>&1
    [[ $? -eq 1 ]] && { echo "Bash variable [${1}] doesn't exist" 1>&2 ; return 1 ; }
    [[ ! "$2" =~ ^[a-zA-Z_]+[a-zA-Z0-9_]*$ ]] && { echo "Invalid index variable aarr_at()" 1>&2 ; return 1 ; }
    declare -n r=$1 
    if [ ${r[$2]+_} ]; then 
        echo true
    else 
        echo false
    fi
}

#>int_check "#1 name" "#2type(scope/max/min)" "#3 value" "#4 custom error" "#5 low/max/min" "#6 high"  
function int_check() {
    if $LogFunc && $BoolInt; then
        echo "$f Function start  > int_check(${1} ${2} ${3} ${4} ${5} ${6})"
    fi
    int_check_ERROR=false
    if [[ ! -z $3 ]]; then
        if [[ $3 =~ $ren ]]; then
            if [[ $2 == "scope" ]]; then
                if [[ $3 -lt $5 ]] || [[ $3 -gt $6 ]]; then
                    echo "Butterfinger failsafe: $1 is outside of scope! ($5 - $6)"
                    sint_check_ERROR=true
                fi
            elif [[ $2 == "max" ]]; then
                if [[ $3 -ge $5 ]]; then
                    echo "Butterfinger failsafe: $1 can't be higher than $5 !"
                    int_check_ERROR=true
                fi
            elif [[ $2 == "min" ]]; then
                if [[ $3 -le $5 ]]; then
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
    if $LogFunc && $BoolInt; then
        echo "$f Function start  > bool_check(${1} ${2})"
    fi
    unset $bool_check
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
#///>arraybuild curve "#1 temp array name" "#2 temp array source variable name (minus step number)" "#3 temp array offset value" 
#///   "#4 fanspeed array toggle" "#5 fanspeed array name" "#6 fanspeed array source variable name (minus step number)"
#///   "#7 modifier array toggle" "#8 modifier array name" "#9 modifier array source variable name (minus step number)"
#///   "#10 fanspeed offset toggle" "#11 fanspeed offset name" "#12 fanspeed offset source variable name (minus step number)" "#13 maxtemp name (ex = )"

#>arraybuild "#1 Curve ID"
function arraybuildcurve() {
    $LogFunc && echo "$f Function start  > §arraybuildcurve(${1})"
    arr "Curve_ts_${1}"
    if $(aarr_at "C${1}_settings" "fs_toggle") ; then 
        arr "Curve_fs_${1}"
    fi
    if $(aarr_at "C${1}_settings" "mod_toggle") ; then
        arr "Curve_mod_${1}"
    fi
    if $(aarr_at "C${1}_settings" "os_toggle") ; then
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
            if $(aarr_at "C${1}_settings" "fs_toggle"); then
                int_check "$inloopspeed" scope "${!inloopspeed}" false 0 100 
                arr_insert "Curve_fs_${1}" "${!inloopspeed}"
            fi
            if $(aarr_at "C${1}_settings" "mod_toggle"); then
                int_check "$inloopmodifier" scope "${!inloopmodifier}" false 0 100 
                arr_insert "Curve_mod_${1}" "${!inloopmodifier}"
            fi
            if $(aarr_at "C${1}_settings" "os_toggle"); then
                int_check scope "$inloopspoffset" scope "${!inloopspoffset}" false 0 100 
                arr_insert "Curve_os_${1}" "${!inloopspoffset}"
            fi
            if $LogFunc || $Logloop ; then
                    echo "$f$l Step n°$((g+1))"
                    echo "$f$l $inloopstep = ${!inloopstep}°C"
                    $(aarr_at "C${1}_settings" "fs_toggle") && echo "$f$l $inloopspeed   = ${!inloopspeed}%"
                    $(aarr_at "C${1}_settings" "mod_toggle") && echo "$f$l $inloopmodifier  = ${!inloopmodifier}°C"
                    $(aarr_at "C${1}_settings" "os_toggle") && echo "$f$l $inloopspoffset   = ${!inloopspoffset}°C"  
            fi
        else
            if [ $g -le 0 ]; then
                echo "Butterfinger failsafe: Curve n°${1} active but no stepping present!!"
                setfanspeed XX XX "$E_value" 1
            fi
            if [[ $(arr_count "Curve_ts_${1}") != $g ]]; then
            echo "Butterfinger failsafe: Curve_ts_${1} array count isn't equal to loop count!!"
            setfanspeed XX XX "$E_value" 1
            fi
            if $(aarr_at "C${1}_settings" "fs_toggle"); then
                if [[ $(arr_count "Curve_ts_${1}") != $(arr_count "Curve_fs_${1}") ]]; then
                echo "Butterfinger failsafe: Curve_fs_${1} array count isn't equal to Curve_ts_${1} array count!!"
                setfanspeed XX XX "$E_value" 1
                fi
            fi
            if $(aarr_at "C${1}_settings" "mod_toggle"); then
                if [[ $(arr_count "Curve_ts_${1}") != $(arr_count "Curve_mod_${1}") ]]; then
                echo "Butterfinger failsafe: Curve_mod_${1} array count isn't equal to Curve_ts_${1} array count!!"
                setfanspeed XX XX "$E_value" 1
                fi
            fi
            if $(aarr_at "C${1}_settings" "os_toggle"); then
                if [[ $(arr_count "Curve_ts_${1}") != $(arr_count "Curve_os_${1}") ]]; then
                echo "Butterfinger failsafe: Curve_os_${1} array count isn't equal to Curve_ts_${1} array count!!"
                setfanspeed XX XX "$E_value" 1
                fi
            fi
            aarr_set "C${1}_settings" "max_temp" "$(arr_at "Curve_ts_${1}" "$((g-1))")"
            if $LogFunc ; then
                    echo "$f Loop count $(printf "%-7s" $(aarr_at "C${1}_settings" "label"))  = $g"
                    echo "$f Max step            = $(aarr_at "C${1}_settings" "max_temp")°C"
                    echo "$f Array building      = stop"
                    echo "$f Curve $1 Steps       = $(arr_get "Curve_ts_${1}")°C"
                    $(aarr_at "C${1}_settings" "fs_toggle") && echo "$f Curve $1 Fan Speeds  = $(arr_get "Curve_fs_${1}")%"
                    $(aarr_at "C${1}_settings" "mod_toggle") && echo "$f Curve $1 Modifiers   = $(arr_get "Curve_mod_${1}")°C"
                    $(aarr_at "C${1}_settings" "os_toggle") && echo "$f Curve $1 Offsets     = $(arr_get "Curve_os_${1}")°C"
            fi
            break
        fi
    done
    $LogFunc && echo "$f Function end."
}
# arraybuildsettings "#1 curve id"
function arraybuildsettings() {
    $LogFunc && echo "$f Function start  > arraybuildsettings(${1})"
    arraybuild_ERROR=false
    fs_toggle="C${1}_fs_toggle"
    mod_toggle="C${1}_mod_toggle"
    os_toggle="C${1}_os_toggle"
    governor="C${1}_governor"
    delta="C${1}_delta"
    offset="C${1}_offset"
    label="C${1}_label"
    if [[ ! -z "${!fs_toggle}" ]] && [[ ! -z "${!mod_toggle}" ]] && [[ ! -z "${!os_toggle}" ]] && [[ ! -z "${!governor}" ]] && [[ ! -z "${!delta}" ]] && [[ ! -z "${!offset}" ]] && [[ ! -z "${!label}" ]]; then
        aarr "C${1}_settings"
        bool_check "$fs_toggle" "${!fs_toggle}" true
        if $bool_check ; then
            aarr_set "C${1}_settings" "fs_toggle" "${!fs_toggle}"
        else
            echo "Error with fs"
            arraybuild_ERROR=true
        fi
        bool_check "$mod_toggle" "${!mod_toggle}" true
        if $bool_check ; then
            aarr_set "C${1}_settings" "mod_toggle" "${!mod_toggle}"
        else
            echo "Error with mod"
            arraybuild_ERROR=true
        fi
        bool_check "$os_toggle" "${!os_toggle}" true
        if $bool_check ; then
            aarr_set "C${1}_settings" "os_toggle" "${!os_toggle}"
        else
            echo "Error with os"
            arraybuild_ERROR=true
        fi
        if [[ "${!governor}" == 0 ]] || [[ "${!governor}" == 1 ]] || [[ "${!governor}" == "ae" ]]  ; then
            aarr_set "C${1}_settings" "governor" "${!governor}"
        else
            echo "Error with governor"
            arraybuild_ERROR=true
        fi
        int_check "$delta" scope "${!delta}" false "0" "50"
        if $bool_check ; then
            aarr_set "C${1}_settings" "delta" "${!delta}"
        else
            echo "Error with delta"
            arraybuild_ERROR=true
        fi
        int_check "$offset" scope "${!offset}" false "-50" "50"
        if $bool_check ; then
            aarr_set "C${1}_settings" "offset" "${!offset}"
        else
            echo "Error with offset"
            arraybuild_ERROR=true
        fi
        if [[ ! "${!label}" =~ [^A-Za-z0-9\&_-] ]] ; then
            aarr_set "C${1}_settings" "label" "${!label}"
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
    echo "$(aarr_get "C${1}_settings")"
    $LogFunc && echo "$f Function end."
}

#>arraybuilddata "#1 temp array name" "#2 temp array source variable name (minus step number)" "#3 temp array offset value"
function arraybuilddata() {
echo "nothing yet"
}

#governor "#1 Curve id"
function governor() {
    unset $templow
    unset $temphigh
    $LogFunc && echo "$f Function start  > governor(${1})"
    if [[ "$(aarr_at "C${1}_settings" "governor")" == "ae" ]]; then
        echo "todo"
    elif [[ "$(aarr_at "C${1}_settings" "governor")" == "1" ]] || [[ "$(aarr_at "C${1}_settings" "governor")" == "0" ]] ; then
        if $Logloop ; then
                echo "$l New loop => Finding highest and lowest $1"
        fi
        for ((h=0; h<$(arr_count "C${1}_readings"); h++)) #General solution to finding the highest number with a shitty shell loop
            do
                inlooptemp=$(arr_at "C${1}_readings" "$h")
                if $Logloop ; then
                        echo "$l Checking for $(printf "%-7s" "$(aarr_at "C${1}_settings" "label")$h")= $inlooptemp°C"
                fi
                if [ "$h" -eq 0 ]; then
                      temphigh=$inlooptemp
                      templow=$inlooptemp
                else
                    if [ $inlooptemp -gt $temphigh ]; then
                        if $Logloop ; then
                                echo "$l Checking for $(printf "%-7s" "$(aarr_at "C${1}_settings" "label")$h")= $inlooptemp°C"
                        fi
                        temphigh=$inlooptemp
                    fi
                    if [ $inlooptemp -lt $templow ]; then
                        if $Logloop ; then
                                echo "$l Checking for $(printf "%-7s" "$(aarr_at "C${1}_settings" "label")$h")= $inlooptemp°C"
                        fi
                        templow=$inlooptemp
                    fi
                fi
            done
        if $Logloop ; then
            echo "$l Lowest = $templow°C"
            echo "$l Highest = $temphigh°C"
            echo "$l "$(aarr_at "C${1}_settings" "label")" Find highest = stop"
        fi

        if [ "$(aarr_at "C${1}_settings" "governor")" -eq 1 ] || [ $((temphigh-templow)) -gt "$(aarr_at "C${1}_settings" "delta")" ]; then
            echo "!! $(aarr_at "C${1}_settings" "label") DELTA Exceeded !!"
            echo "Lowest : $templow°C"
            echo "Highest: $temphigh°C"
            echo "Delta Max: "$(aarr_at "C${1}_settings" "delta")" °C"
            echo "Switching $(aarr_at "C${1}_settings" "label") profile..."
            declare C${1}_delta_E=1
            declare C${1}_ER=$temphigh
            aarr_set "C${1}_settings" "vTemp" "$temphigh"
        fi
    else
        echo "!! $1 : Missing or invalid governor parameter!!"
        setfanspeed "XX" "XX" "$E_value" 0
    fi
    $LogFunc && echo "$f Function end."
}


#>tempcomp "#1 curve id"
function tempcomp() {
    $LogFunc && echo "$f Function start  > tempcomp($(aarr_at "C${1}_settings" "label"))"
    looptemp="$(aarr_at "C${1}_settings" "vTemp")"
    if [[ "$looptemp" -gt "$(aarr_at "C${1}_settings" "max_temp")" ]] ; then
        echo "!! $(aarr_at "C${1}_settings" "label") : Temperature Critical trigger!!"
        setfanspeed "$looptemp" "$(aarr_at "C${1}_settings" "max_temp")" "$E_value" 0
    else
        if $Logloop ; then
            echo "$l New loop => From $(aarr_at "C${1}_settings" "label") using $(printf "%-18s" "$(aarr_at "C${1}_settings" "label") temp steps")"
        fi
        for ((t=0; t<$(arr_count "Curve_ts_$1"); t++))
        do
            if $Logloop ; then
                echo "$l Test $looptemp =< Curve_ts_$1[$t]($(arr_at "Curve_ts_$1" "$t"))"
            fi
            if [ $looptemp -le "$(arr_at "Curve_ts_$1" "$t")" ]; then
                [[ $Logloop ]] && echo "$l Result $looptemp is =< Curve_ts_$1[$t]($(arr_at "Curve_ts_$1" "$t"))"
                if "$(aarr_at "C${1}_settings" "fs_toggle")"; then
                    declare "C${1}_fs_op"=$(arr_at "Curve_fs_$1" "$t")
                    [[ $Logloop ]] && echo "$l Defining variable C${1}_fs_op with fanspeed $(arr_at "Curve_fs_$1" "$t") %"
                fi
                if "$(aarr_at "C${1}_settings" "mod_toggle")"; then
                    declare "C${1}_mod_op"=$(arr_at "Curve_mod_$1" "$t")
                    [[ $Logloop ]] && echo "$l Defining variable C${1}_mod_op with temp modifier $(arr_at "Curve_mod_$1" "$t")" 
                fi
                if "$(aarr_at "C${1}_settings" "os_toggle")"; then
                    declare "C${1}_os_op"=$(arr_at "Curve_os_$1" "$t")
                    [[ $Logloop ]] && echo "$l Defining variable C${1}_os_op with speed offset $(arr_at "Curve_os_$1" "$t") %"
                fi
                [[ $Logloop ]] && echo "$l Loop using $(aarr_at "C${1}_settings" "label") Temp Steps - Stop Loop." 
                break
            else
                if $Logloop ; then
                    echo "$l Test failed -> next iteration;"
                fi
            fi
        done
    fi
    $LogFunc && echo "$f Function end."
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

#commands to test stuff
aarr_set "C0_settings" "vTemp" "49"
aarr_set "C1_settings" "vTemp" "22"
tempcomp "0"
tempcomp "1"
arr "C0_readings"
for ((z=0; z<40 ; z++))
    do
        rand=$(( $RANDOM % 15 + 1 ))
        arr_set "C0_readings" "${z}" "$((rand+39))"
    done

governor "0"

aarr "test"
aarr_set "test" "index" "testvariable"
aarr_set "test" "index2" "testvariable2"
echo $(aarr_at "test" "index")
echo $(aarr_at "test" "notexist")
aarr_test "test" "index"
aarr_test "test" "notexist"
aarr_get "test"