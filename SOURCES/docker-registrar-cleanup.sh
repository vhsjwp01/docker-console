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

# WHAT: Clean up credentials file
# WHY:  Asked to
#
if [ ${exit_code} -eq ${SUCCESS} ]; then
    credentials_file="/etc/docker_console.creds"
    registered_containers=`egrep -v "^#" "${credentials_file}" | awk -F':' '{print $NF}'`
    running_containers=`docker ps -f status=running | egrep -v "^CONTAINER" | awk '{print $1}'`

    for running_container in ${running_containers} ; do
        container_match=""

        for registered_container in ${registered_containers} ; do

            if [ "${registered_container}" = "${running_container}" ]; then
                container_match="yes"
            fi

        done

        if [ "${container_match}" = "" ]; then
            echo "`date` - NOTICE - Expunging credentials for dead container id ${running_container} from ${credentials_file}" >> ${LOGFILE}
            sed -i -e "/:${running_container}\$/d" "${credentials_file}"
        fi

    done

fi

