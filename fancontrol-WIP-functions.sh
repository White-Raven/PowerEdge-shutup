#!/bin/bash
function setfanspeed () {
    exit 0
}
Logloop=true
E_value="auto"
# CPU curve using new array population function
C0_toggle=true
C0_offset=0
C0_fs_toggle=true
C0_mod_toggle=false
C0_os_toggle=false

C0_TEMP0=30
C0_FS0=2
C0_TEMP1=35
C0_FS1=6
C0_TEMP2=40
C0_FS2=8
C0_TEMP3=50
C0_FS3=10
C0_TEMP4=60
C0_FS4=12
C0_TEMP5=75
C0_FS5=20

# Ambient curve using new array population function
C1_toggle=true
C1_offset=0
C1_fs_toggle=true
C1_mod_toggle=true
C1_os_toggle=false

C1_TEMP0=20
C1_FS0=8
C1_MOD0=0
C1_TEMP1=21
C1_FS1=15
C1_MOD1=10
C1_TEMP2=24
C1_FS2=20
C1_MOD2=15
C1_TEMP3=26
C1_FS3=30
C1_MOD3=20

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

#>valuescope
#1 name
#2 low
#3 high
#4 value
function valuescope () {
if [[ ! -z $4 ]]; then
    if [[ $4 =~ $ren ]]; then
        if [[ $4 -lt $2 ]] || [[ $4 -gt $3 ]]; then
            echo "Butterfinger failsafe: $1 is outside of scope!"
            setfanspeed XX XX $E_value 1
        fi
    else
        echo "Butterfinger failsafe: $1 isn't a number!"
        setfanspeed XX XX $E_value 1
    fi
else
    echo "Butterfinger failsafe: $1 value missing!"
    setfanspeed XX XX $E_value 1
fi
}
#>arraybuild curve
#1 temp array name
#2 temp array source variable name (minus step number)
#3 temp array offset value
#4 fanspeed array toggle
#5 fanspeed array name
#6 fanspeed array source variable name (minus step number)
#7 modifier array toggle
#8 modifier array name
#9 modifier array source variable name (minus step number)
#10 fanspeed offset toggle
#11 fanspeed offset name
#12 fanspeed offset source variable name (minus step number)
#13 maxtemp name (ex = )
function arraybuildcurve () {
arr $1
if ${!4}; then
    arr $5
fi
if ${!7} ; then
    arr $8
fi
if ${!10}; then
    arr ${11}
fi
for ((g=0; g>=0; g++))
do
    inloopstep="$2$g"
    inloopspeed="$6$g"
    inloopmodifier="$9$g"
    inloopspoffset="${12}$g"
    if [[ ! -z "${!inloopstep}" ]]; then
        if ! [[ "${!inloopstep}" =~ $ren ]]; then
                echo "Butterfinger failsafe: $2$g isn't a number!"
                setfanspeed XX XX $E_value 1
        else
            arr_insert $1 "${!inloopstep}"
            if ${!4}; then
                valuescope "$inloopspeed" 0 100 "${!inloopspeed}"
                arr_insert $5 "${!inloopspeed}"
            fi
            if ${!7}; then
                valuescope "$inloopmodifier" 0 100 "${!inloopmodifier}"
                arr_insert $8 "${!inloopmodifier}"
            fi
            if ${!10}; then
                valuescope "$inloopspoffset" 0 100 "${!inloopspoffset}"
                arr_insert ${11} "${!inloopspoffset}"
            fi
        fi
    else
        if [ $g -le 0 ]; then
            echo "Butterfinger failsafe: $2 Curve active but no stepping present!!"
            setfanspeed XX XX $E_value 1
        fi
        temparraycount=$(arr_count "$1")
        if [[ $temparraycount != $g ]]; then
        echo "Butterfinger failsafe: $1 array count isn't equal to loop count!!"
        setfanspeed XX XX $E_value 1
        fi
        if ${!4}; then
            if [[ $temparraycount != $(arr_count "$5") ]]; then
            echo "Butterfinger failsafe: $5 array count isn't equal to $1 array count!!"
            setfanspeed XX XX $E_value 1
            fi
        fi
        if ${!7}; then
            if [[ $temparraycount != $(arr_count "$8") ]]; then
            echo "Butterfinger failsafe: $8 array count isn't equal to $1 array count!!"
            setfanspeed XX XX $E_value 1
            fi
        fi
        if ${!10}; then
            if [[ $temparraycount != $(arr_count "${11}") ]]; then
            echo "Butterfinger failsafe: ${11} array count isn't equal to $1 array count!!"
            setfanspeed XX XX $E_value 1
            fi
        fi
        inloopmaxstep="$2$((g-1))"
        declare ${13}="${!inloopmaxstep}"
        if $Logloop ; then
                echo "$l $2 count = $g"
                echo "$l ${13} = ${!13}°C"
                echo "$l $1 array building = stop"
                echo "inloopstep $(arr_get $1)"
                ${!4} && echo "inloopspeed $(arr_get $5)"
                ${!7} && echo "inloopmodifier $(arr_get $8)"
                ${!10} && echo "inloopspoffset $(arr_get ${11})"
        fi
        break
    fi
done
}

#>arraybuild data
#temp array name
#temp array source variable name (minus step number)
#temp array offset value
function arraybuilddata () {
echo "nothing yet"
}

function governor () {
echo "nothing yet"
}


#>tempcomp
#1 origin CPU MOD
#2 value $vTEMP
#3 operator ge/gt
#4 valuemax $MAXTEMP
#5 originlabel
#6 curve id
#7 tempcurvelabel "CPU temp steps"
function tempcomp () { 
    if [ $3 == "gt" ]; then
        [[ "${!2}" -gt "${!4}" ]] && crittemp=true || crittemp=false
    elif [[ $3 == "ge" ]]; then
        [[ "${!2}" -ge "${!4}" ]] && crittemp=true || crittemp=false
    fi
    if $crittemp; then
            echo "!! $1 : Temperature Critical trigger!!"
            setfanspeed "${!2}" "${!4}" "$E_value" 0
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
                if "${!curve_fs_toggle}"; then
                    declare "C${6}_fs_op"=$(arr_at "Curve_fs_$6" "$t")
                    [[ $Logloop ]] && echo "$l Defining variable C${6}_fs_op with fanspeed $(arr_at "Curve_fs_$6" "$t") %"
                fi
                if "${!curve_mod_toggle}"; then
                    declare "C${6}_mod_op"=$(arr_at "Curve_mod_$6" "$t")
                    [[ $Logloop ]] && echo "$l Defining variable C${6}_mod_op with temp modifier $(arr_at "Curve_fs_$6" "$t")" 
                fi
                if "${!curve_os_toggle}"; then
                    declare "C${6}_os_op"=$(arr_at "Curve_os_$6" "$t")
                    [[ $Logloop ]] && echo "$l Defining variable C${6}_os_op with speed offset $(arr_at "Curve_fs_$6" "$t") %"
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
        curve_prefix="C${k}_"
        curve_toggle="C${k}_toggle"
        curve_fs_toggle="C${k}_fs_toggle"
        curve_mod_toggle="C${k}_mod_toggle"
        curve_os_toggle="C${k}_os_toggle"
        echo "${!curve_toggle}"
        echo "${!curve_fs_toggle}"
        echo "${!curve_mod_toggle}"
        echo "${!curve_os_toggle}"
        if [[ ! -z "${!curve_toggle}" ]] ; then
            if "${!curve_toggle}"; then
                if [[ ! -z "${!curve_fs_toggle}" ]] && [[ ! -z "${!curve_mod_toggle}" ]] && [[ ! -z "${!curve_os_toggle}" ]]; then
                arraybuildcurve "Curve_ts_${k}" "C${k}_TEMP" "C${k}_offset" "C${k}_fs_toggle" "Curve_fs_${k}" "C${k}_FS" "C${k}_mod_toggle" "Curve_mod_${k}" "C${k}_MOD" "C${k}_os_toggle" "Curve_os_${k}" "C${k}_OS" "C${k}_MAX"
                else
                    echo "Missing Parameters"
                    break
                fi
            else
                echo "Disabled Curve"
                break
            fi     
        else
            echo "End"
            break
        fi
    done

vTEMP=45
MAXTEMP=75
tempcomp "CPU MOD" $vTEMP gt $MAXTEMP "" 0 "CPU temp steps"