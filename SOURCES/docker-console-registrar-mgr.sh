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

session_id=$$

trap "echo \"`date` - REMOTE HOST: ${REMOTE_HOST} - docker-console-registrar client disconnected, PID ${session_id}\" >> ${LOGFILE}" 0 1 2 3 15

# WHAT: Prompt for ${username}+${password}:${container_id} tuple
# WHY:  Needed later
#
if [ ${exit_code} -eq ${SUCCESS} ]; then

    # Firstly, log this connection
    echo "`date` - REMOTE HOST: ${REMOTE_HOST} - docker-console-registrar client connected, PID ${session_id}" >> ${LOGFILE}

    registration=""

    while [ "${registration}" = "" ]; do
        echo -ne "Registration: "
        read registration
        registration=`echo "${registration}" | sed -e 's?[^a-zA-Z0-9:]??g'`
    done

fi

# WHAT: Make sure we have three pieces of colon (:) delimited information
# WHY:  Sanity
#
if [ ${exit_code} -eq ${SUCCESS} ]; then
    let pieces_count=`echo "${registration}" | sed -e 's?:?\ ?g' | wc -w`

    if [ ${pieces_count} -ne 2 ]; then
        echo REGISTRATION-FAILED
        err_msg="Incorrect registration information provided"
        exit_code=${ERROR}
    else
        auth_hash=`echo "${registration}" | awk -F':' '{print $1}'`
        container_id=`echo "${registration}" | awk -F':' '{print $2}'`
    fi
fi

# WHAT: Make sure the container_id referenced in the registration credentials exist
# WHY:  To keep credentials list sane
#
if [ ${exit_code} -eq ${SUCCESS} ]; then
    let is_running=`docker ps -f status=running | awk '{print $1}' | egrep -c "^${container_id}$"`

    if [ ${is_running} -eq 0 ]; then
        echo REGISTRATION-FAILED
        err_msg="No such running container ID \"${container_id}\""
        exit_code=${ERROR}
    fi

fi

# WHAT: Add to credentials list if possible
# WHY:  Asked to
#
if [ ${exit_code} -eq ${SUCCESS} ]; then
    credentials_file="/etc/docker_console.creds"

    if [ ! -e "${credentials_file}" ]; then
        echo REGISTRATION-FAILED
        err_msg="Cannot locate credentials file \"${credentials_file}\""
        exit_code=${ERROR}
    else
        let is_present=`egrep -c "^${registration}$" "${credentials_file}"`

        if [ ${is_present} -eq 0 ]; then
            echo "${registration}" >> "${credentials_file}"
            echo REGISTRATION-SUCCESS
            echo "`date` - REMOTE HOST: ${REMOTE_HOST} - SUCCESS:  Docker Consle Registrar Manager registered console access for container ${container_id}, PID ${session_id}" >> ${LOGFILE}
        else
            echo ALREADY-REGISTERED
            echo "`date` - REMOTE HOST: ${REMOTE_HOST} - NOTICE:  Docker Console Registrar Manager received request for previously registered container ${container_id}, PID ${session_id}" >> ${LOGFILE}
        fi

    fi

fi

# WHAT: Complain if necessary, then exit
# WHY:  Success or failure, either way we are through!
#
if [ ${exit_code} -ne ${SUCCESS} ]; then

    if [ "${err_msg}" != "" ]; then
        echo "`date` - REMOTE HOST: ${REMOTE_HOST} - ERROR:  ${err_msg} ... Docker Console Registrar Manager processing halted, PID ${session_id}" >> ${LOGFILE}
    fi

fi

exit ${exit_code}
