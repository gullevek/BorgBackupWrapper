#!/usr/bin/env bash

# this will fix backup sets name
# must have a target call for
# file
# gitea
# mysql
# pgsql
# zabbix-settings-

export BORG_BASE_DIR="borg/";
DEBUG=0;
DRYRUN=0;
TARGET_USER="";
TARGET_HOST="";
TARGET_PORT="";
TARGET_BORG_PATH="";
TARGET_FOLDER="";
BASE_FOLDER="/usr/local/scripts/borg/";
# those are the valid modules
MODULE_LIST="file gitea mysql pgsql zabbix"

# basic options
# -c for config file override
# -n for dry run test
while getopts ":c:nd" opt; do
	case "${opt}" in
		c|config)
			BASE_FOLDER=${OPTARG}"/";
			;;
		d|debug)
			DEBUG=1;
			;;
		n|dryrun)
			DRYRUN=1;
			;;
		:)
			echo "Option -$OPTARG requires an argument."
			;;
		\?)
			echo -e "\n Option does not exist: ${OPTARG}\n";
			usage;
			exit 1;
			;;
	esac;
done;

[[ "${BASE_FOLDER}" != */ ]] && BASE_FOLDER=${BASE_FOLDER}"/";
if [ ! -d "${BASE_FOLDER}" ]; then
	echo "Base folder not found: ${BASE_FOLDER}";
	exit 1;
fi;
SETTINGS_FILE="borg.backup.settings";
if [ ! -f "${BASE_FOLDER}${SETTINGS_FILE}" ]; then
	echo "Could not find: ${BASE_FOLDER}${SETTINGS_FILE}";
	exit;
fi;
. "${BASE_FOLDER}${SETTINGS_FILE}";
ORIG_BACKUPFILE=${BACKUP_FILE};
for MODULE in ${MODULE_LIST}; do
	echo "************* MODULE: ${MODULE}";
	BACKUP_FILE=${ORIG_BACKUPFILE};
	BACKUP_FILE=${BACKUP_FILE/.borg/-${MODULE,,}.borg};
	TARGET_FOLDER=${TARGET_FOLDER%/}
	TARGET_FOLDER=${TARGET_FOLDER#/}
	# and add slash front and back and escape the path
	TARGET_FOLDER=$(printf "%q" "/${TARGET_FOLDER}/");
	if [ ! -z "${TARGET_USER}" ] && [ ! -z "${TARGET_HOST}" ] && [ ! -z "${TARGET_PORT}" ]; then
		TARGET_SERVER="ssh://${TARGET_USER}@${TARGET_HOST}:${TARGET_PORT}/";
	# host/port
	elif [ ! -z "${TARGET_HOST}" ] && [ ! -z "${TARGET_PORT}" ]; then
		TARGET_SERVER="ssh://${TARGET_HOST}:${TARGET_PORT}/";
	# user/host
	elif [ ! -z "${TARGET_USER}" ] && [ ! -z "${TARGET_HOST}" ]; then
		TARGET_SERVER="${TARGET_USER}@${TARGET_HOST}:";
	# host
	elif [ ! -z "${TARGET_HOST}" ]; then
		TARGET_SERVER="${TARGET_HOST}:";
	fi;
	# we dont allow special characters, so we don't need to special escape it
	REPOSITORY="${TARGET_SERVER}${TARGET_FOLDER}${BACKUP_FILE}";
	echo "==== REPOSITORY: ${REPOSITORY}";
	borg list --format '{archive}{NL}' ${REPOSITORY}|grep -v "${MODULE},"|
	while read i; do
		# for gitea, zabbix we do not ADD we RENAME
		if [ "${MODILE}" = "gitea" ]; then
			target_name=$(echo $i | sed -e 's/gitea-/gitea,/');
		elif [ "${MODILE}" = "zabbix" ]; then
			target_name=$(echo $i | sed -e 's/zabbix-settings-/zabbix,settings-/');
		else
			target_name="${MODULE},${i}";
		fi;
		echo "- Rename from: ${i} to: ${target_name}";
		if [ ${DEBUG} -eq 1 ]; then
			echo "borg rename -p -v ${REPOSITORY}::${i} ${target_name}";
		fi;
		if [ ${DRYRUN} -eq 0 ]; then
			borg rename -p -v ${REPOSITORY}::${i} ${target_name};
		fi;
	done;
done;

# __END__
