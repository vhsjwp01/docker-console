#!/bin/bash
#set -x

PATH=/bin:/usr/bin:/usr/local/bin:/sbin:/usr/sbin:/usr/local/sbin
TERM=vt100
export TERM PATH

SUCCESS=0
ERROR=1

LOGFILE="/var/log/docker-console.log"

err_msg=""
exit_code=${SUCCESS}

# WHAT: Prompt for ${credentials}:${container_id} tuple
# WHY:  Needed later
#
if [ ${exit_code} -eq ${SUCCESS} ]; then
    registration=""

    while [ "${registration}" = "" ]; do
        echo -ne "Registration: "
        stty -echo
        read registration
        stty echo
    done

fi

# WHAT: Make sure the container_id referenced in the registration credentials exist
# WHY:  To keep credentials list sane
#
if [ ${exit_code} -eq ${SUCCESS} ]; then
    this_container=`echo "${registration}" | awk -F':' '{print $NF}'`
    running_containers=`docker ps -f status=running | egrep -v "^CONTAINER" | awk '{print $1}'`

    for running_container in ${running_containers} ; do
        container_match=""

        if [ "${this_container}" = "${running_container}" ]; then
            container_match="yes"
        fi

    done

    if [ "${container_match}" = "" ]; then
        echo REGISTRATION-FAILED
        err_msg="No such running container ID \"${this_container}\""
        exit_code=${ERROR}
    fi

fi

# WHAT: Add to credentials list if possible
# WHY:  Asked to
#
if [ ${exit_code} -eq ${SUCCESS} ]; then

    if [ ! -e "${credentials_file}" ]; then
        echo REGISTRATION-FAILED
        err_msg="Cannot locate credentials file \"${credentials_file}\""
        exit_code=${ERROR}
    else
        let is_present=`egrep -c "^${registration}$" "${credentials_file}"`

        if [ ${is_present} -eq 0 ]; then
            echo "${registration}" >> "${credentials_file}"
            echo REGISTRATION-SUCCESS
            echo "`date` - SUCCESS:  Registered console access for container ${this_container}" >> ${LOGFILE}
        else
            echo ALREADY-REGISTERED
            echo "`date` - NOTICE:  Received request for previously registered container ${this_container}" >> ${LOGFILE}
        fi

    fi

fi

# WHAT: Complain if necessary, then exit
# WHY:  Success or failure, either way we are through!
#
if [ ${exit_code} -ne ${SUCCESS} ]; then

    if [ "${err_msg}" != "" ]; then
        echo "`date` - ERROR:  ${err_msg} ... processing halted" >> ${LOGFILE}
    fi

fi

exit ${exit_code}
