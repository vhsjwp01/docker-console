#!/bin/bash
#set -x

PATH=/bin:/usr/bin:/usr/local/bin:/sbin:/usr/sbin:/usr/local/sbin
TERM=vt100
export TERM PATH

SUCCESS=0
ERROR=1

err_msg=""
exit_code=${SUCCESS}

# WHAT: Find out who the requestor is
# WHY:  Needed later
#
if [ ${exit_code} -eq ${SUCCESS} ]; then
    credentials=""

    while [ "${credentials}" = "" ]; do
        echo -ne "Credentials: "
        stty -echo
        read credentials
        stty echo
    done

fi

# WHAT: Find matches for our requestor
# WHY:  Asked to
#
if [ ${exit_code} -eq ${SUCCESS} ]; then
    credentials_file="/usr/local/etc/docker_console/credentials"

    if [ ! -e "${credentials_file}" ]; then
        err_msg="Cannot locate credentials file \"${credentials_file}\""
        exit_code=${ERROR}
    else
        matches=`egrep "^${credentials}:" "${credentials_file}" | awk -F':' '{print $NF}'`

        if [ "${matches}" = "" ]; then
            err_msg="No matching containers were found for the credentials provided"
            exit_code=${ERROR}
        fi

    fi

fi

# WHAT: Show a list of matching container IDs from which to select
# WHY:  Asked to
#
if [ ${exit_code} -eq ${SUCCESS} ]; then
    let counter=0

    for match in ${matches} ; do
        is_running=`docker ps -f status=running | egrep "${match}" | awk '{print $1 ":" $2}'`

        if [ "${is_running}" != "" ]; then
            container_id[${counter}]="${is_running}"
            let counter=${counter}+1
        fi

    done

    selection=""

    while [ "${selection}" = "" ]; do
        let counter=0

        echo
        echo "=================="
        echo "Running Containers"
        echo "=================="

        for container in ${container_id[*]} ; do
            echo "    [${counter}]: ${container}"
            let counter=${counter}+1
        done

        echo
        read -p "    Select a container ID number: " selection
        selection=`echo "${selection}" | sed -e 's/[^0-9]//g'`

        if [ "${selection}" = "" ]; then
            echo "Invalid selection"
            sleep 2
        fi

    done

    # Connect to a docker console
    docker exec -it `echo "${container_id[$selection]}" | awk -F':' '{print $1}'` /bin/bash
fi

# WHAT: Complain if necessary, then exit
# WHY:  Success or failure, either way we are through!
#
if [ ${exit_code} -ne ${SUCCESS} ]; then

    if [ "${err_msg}" != "" ]; then
        echo "    ERROR:  ${err_msg} ... processing halted"
    fi

fi

exit ${exit_code}
