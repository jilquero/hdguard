#!/bin/bash

#displays information
function showSpaceInformation
{
    curr_free_space=$(df /home/$USER | awk 'END{A=$4; print int(A)}')

    clear
	echo "-------------HDGUARD-------------"
    echo -e "Disk name:\t\t$disk_name"
    echo -e "Partition name:\t\t$partition_name"
    echo -e "Free space:\t\t$curr_free_space"
    echo -e "Taken / Limit in %:\t$curr_space% / $limit_percentage%"
}
#asks user for clean up politely
function askForCleanup
{
    echo "Space treshold has been exceeded"
    echo "Partition cleanup: [Y/n]"
    echo 

    read -rsn1 option
    case $option in

        [yY])
            showSpaceInformation
            echo
            echo "U sure?"
            sleep 2
            lookForFiles
        ;;

        [nN])
            showSpaceInformation
            echo
            echo "U srlsy gonna ignore this?"
            sleep 2
            clear
            showSpaceInformation
            sleep 58
        ;;

        *)
            showSpaceInformation
            echo
            echo "Option \"$option\" doesnt exist, try again"
            echo
            askForCleanup
        ;;

    esac
}
#creates variables and is main loop of deletion
function lookForFiles
{
    # files_in_partition=(`find /home/$USER -type f -printf '%T@ %s %p\n' | sort -k1 -n -r | grep -v '/\.'| awk '{$1=""; print $0}' | cut -c 2- | sort -nr`)
    declare -a files_in_partition
    declare -a files_chosen_bytes
    declare -a files_chosen_paths
    declare -a files_to_delete_paths
    declare -a files_that_were
    declare -a user_choices

    files_to_delete_bytes=0
    result=0
    sum=0
    abort=0
    charm=0

    while :
    do
        createArrayOfFiles
        if [ ${#files_chosen_paths[@]} -eq 0 ]; then
            showSpaceInformation
            # echo "RIPPP out of possible files to delete :|, u messed up gonna do this all over again"
            echo "OOPS no more files gonna delete this batch and start over"
            sleep 4
            deleteFiles
            files_that_were=()
            createArrayOfFiles
        fi
        chooseFilesToDelete
        checkAmountOfSpace $files_to_delete_bytes
        if [ $abort -eq 1 ]; then
            showSpaceInformation
            echo "Mission abort, repeat mission abort"
            echo "Return to monitoring"
            sleep 4
            showSpaceInformation
            sleep 56
            return
        fi
        if [ $result -eq 1 ]; then
            clear
            echo "U have satified the hungry one"
            break
        fi
    done
    deleteFiles
}
#checks amount of space need to be removed
function checkAmountOfSpace
{
    result=0
    local kbytes_summ=$(($1/1000))
    local kbytes_to_remove=$(($kbytes_used-$limit_kbytes))
    if [ $kbytes_summ -gt $kbytes_to_remove ]; then
        result=1
        echo "$kbytes_summ  $kbytes_to_remove"
    fi
}
#creates an array of files ment for removal
function createArrayOfFiles
{
    files_chosen_bytes=()
    files_chosen_paths=()
    sum=$files_to_delete_bytes
    local IFS_copy=$IFS
    local IFS=","

    if [ ${#files_that_were[@]} -eq 0 ]; then
        files_in_partition=(`find /home/$USER -type f -printf '%T@ %s %p\n' | sort -k1 -n -r | grep -v '/\.'| awk '{$1=""; print $0}' | cut -c 2- | sort -nr | awk '{$1=$1 ","; $NF=$NF ","; print $0}'`)
    fi

    files_bytes=(`echo "${files_in_partition[*]}" | awk '{print $1}' | cut -c 1- `)
    files_paths=(`echo "${files_in_partition[*]}" | awk '{$1=""; print $0}' | cut -c 2-`)
    IFS=$IFS_copy

    for ((i=0; i<${#files_paths[@]}; i=i+1))
    do
        files_chosen_bytes[$i]=${files_bytes[$i]}
        files_chosen_paths[$i]=${files_paths[$i]}
        sum=$(($sum+${files_chosen_bytes[$i]}))
        checkAmountOfSpace $sum
        if [ $result -eq 1 ]; then
            if [ ${#files_chosen_paths[*]}  -eq 1 ];then
                return
            fi
            break
        fi
        if [ ${#files_chosen_paths[*]} -eq 10 ]; then
            break
        fi
    done
}
#displays files that are ment to be deleted :)
function showFileSelection
{
    clear
    echo
    echo -e "Number:\tPath:\t\t\t\tSpace taken in kbytes:"

    for ((i=0; i<${#files_chosen_paths[@]}; i=i+1))
    do
        echo -e "$i: ${files_chosen_paths[$i]//[$'\t\r\n']}\t\t $((${files_chosen_bytes[$i]//[$'\t\r\n']}/1000))"
    done

    echo -e "\nType a number of file u want to delete (or press A to flag all)"
    echo "After u are done press s"
    echo "Numbers so far: ${user_choices[*]}"
    echo $warning
}
#lets the user choose files that he wishes to be deleted
function chooseFilesToDelete
{
    abort=0
    user_choices=()
    warning=""
    while :
    do
        showFileSelection
        tmp_range=$((${#files_chosen_paths[*]}-1))
        temp=1
        while [ $temp -eq 1 ]
        do
            temp=0
            read -rsn1 choice
            case $choice in
                [aAsS])
                    break
                ;;
                *)
                    for i in ${user_choices[@]}
                    do
                        if [ $choice -eq $i ]; then
                            temp=1
                            break
                        fi
                    done
                ;;
            esac
        done

        case $choice in

            [0-$tmp_range])
                user_choices+=($choice)
                warning=""
                showFileSelection
            ;;

            [aA])
                user_choices=()
                for ((i=0; i<${#files_chosen_paths[@]}; i=i+1))
                do
                    user_choices+=($i)
                done
                warning="U have selected all of em"
                showFileSelection
                break
            ;;
            
            [sS])
                warning="Sure thing will do"
                showFileSelection
                break
            ;;

            [bB])
                user_choices=()
                abort=1
                return
            ;;

            *)
                showFileSelection
                warning="U went out of lists range, try again"
            ;;

        esac
    
    done

    for choices in ${user_choices[@]}
    do
        files_to_delete_bytes=$(($files_to_delete_bytes+${files_chosen_bytes[$choices]}))
        files_to_delete_paths+=("${files_chosen_paths[$choices]}")
    done
    for ((i=0; i<${#files_chosen_paths[@]}*2; i=i+1))
    do
        files_in_partition=("${files_in_partition[@]:1}")
    done
    for ((i=0; i<${#files_chosen_paths[@]}; i=i+1))
    do
        files_that_were+=("${files_chosen_paths[$i]//[$'\t\r\n']}")
    done
    clear
}
#self explanatory
function deleteFiles
{
    if [ ${#files_to_delete_paths[@]} != 0 ]; then
        createFileDeleted
        showSpaceInformation
        sleep 1
        for ((i=0; i<${#files_to_delete_paths[@]}; i=i+1))
        do
            echo "Deleting file ${files_to_delete_paths[$i]//[$'\t\r\n']}"
            rm "${files_to_delete_paths[$i]//[$'\t\r\n']}"
            sleep 1
        done
        echo
        echo "Selected files have been removed"
        unset files_to_delete_paths
        sleep 5
    fi
}
#creates file hdguard_data_godzina.deleted
function createFileDeleted
{
    name="hdguard_$(date +”%m-%d-%Y”)_$(date +”%H:%M”).deleted"
    touch $name
    showSpaceInformation
    echo
    echo "Creating file"
    for ((i=0; i<${#files_to_delete_paths[@]}; i=i+1))
    do
        echo "Path: ${files_to_delete_paths[$i]//[$'\t\r\n']}" >> $name
    done
    sleep 5
}
#looks up disk values and partition name
function getThemDiskValues
{
    disk_name=$(inxi -d | grep /dev/sdb | grep -o -P '(?<=model: ).*(?= size)')
    partition_name=$(df /home/$USER | awk '/dev/ { print $1 }')
    max_space_kbytes=$(df /home/$USER | sed -n '2 p' | awk '{print $2*1}')
    limit_kbytes=$(($max_space_kbytes*$limit_percentage/100))
}
#if limit value is not correct either ignore, change or exit
function limitChange
{
    read -rsn1 change
    case $change in

        [yY])
            clear
            echo "Go for it:"
            read -rs limit_percentage
            valueCheck 1 $limit_percentage
        ;;

        [nN])
            if [ $numberOfPassedValues -eq 1 ]; then
                return
            else
                clear
                echo "SADGE"
                sleep 3
                exit
            fi
        ;;

        *)
            clear
            echo "Option \"$option\" doesnt exist, try again [Y/n]"
            limitChange
        ;;

    esac
}
#check if the limit value is correct
function valueCheck
{
    inxiCheck
    kbytes_possible_to_remove=$(find /home/$USER -type f -printf '%s %p\n' | grep -v '/\.' | awk '{print $1/100000}' | sort -nr | awk '{s+=$1}END{printf s}' | awk -F ',' '{print $1}' | awk -F '.' '{print $1}')
    kbytes_used=$(df /home/$USER | awk 'NR==2 {print $3}')
    actual_kbytes=$(($kbytes_used-($kbytes_possible_to_remove*100)))
    numberOfPassedValues=$1
    limit_percentage=$2

    if [ $numberOfPassedValues -eq 0 ]; then
        echo "Error: No argument passed"
        echo "Type: $0 <number>"
        echo "Do u want to set one? [Y/n]"
        limitChange
    elif [ $numberOfPassedValues -gt 1 ]; then
        echo "Error: Too many arguments passed"
        echo "U can only set one value as a limit"
        echo "Do u want to do it? [Y/n]"
        limitChange
    elif ! [ "$limit_percentage" -eq "$limit_percentage" ] 2> /dev/null; then
        echo "Error: Argument must be a number"
        echo "U can only set one value as a limit"
        echo "Do u want to do it? [Y/n]"
        limitChange
    fi

    first=1
    if [ $first -eq 1 ]; then
        getThemDiskValues
        first=0
    fi
#dynamic limit  for files u cant remove
    if [ $limit_kbytes -lt $actual_kbytes ] || [ $limit_percentage -gt 90 ]; then
        possible_treshold=$(echo "$actual_kbytes $max_space_kbytes" | awk '{print ($1/$2)*100}' | awk -F ',' '{print $1+1}')
        echo "Limit value must be less than: 90% and greater or equal to: $possible_treshold"
        echo "Do u want to apply correction? Im gonna ask u over and over :) [Y/n]"
        limitChange
    fi
}
#check if ther is inxi command
function inxiCheck
{
    if [ ! inxi -v INXI &> /dev/null ]; then 
    echo "Blad! Trzeba zainstalować inxi!"
    apt update
    apt --yes install inxi
    exit 1
    fi
}

function main
{
    while :
    do
        valueCheck 1 $limit_percentage
        curr_space=$(df /home/$USER | awk 'END{A=$3/$2*100; print int(A)}' | awk -F ',' '{print $1}')
        showSpaceInformation
        if [ $curr_space -gt $limit_percentage ]; then
            break
        fi
        sleep 60
    done
    askForCleanup
}

clear
valueCheck $# $1

while :
do
    main
done

exit 0