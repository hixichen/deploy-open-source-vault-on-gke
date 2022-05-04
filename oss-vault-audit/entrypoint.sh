#!/bin/sh

TS_FORMAT="%Y-%m-%dT%H:%M:%S%z "
tail -F ${LOGROTATE_FILE_PATH} &

mkdir -p ${HOME}/crontabs
echo "${CRON_SCHEDULE}  /usr/sbin/logrotate -s ${HOME}/logrotate.status -v /etc/logrotate.conf" >> ${HOME}/crontabs/$USR
exec crond -c ${HOME}/crontabs -d ${CROND_LOGLEVEL:-7} -f 2>&1 | ts "${TS_FORMAT}"