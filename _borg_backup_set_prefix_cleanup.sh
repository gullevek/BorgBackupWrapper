#!/usr/bin/env bash

# this will fix backup sets name
# must have a target call for
# file
# gitea
# mysql
# pgsql
# zabbix-settings-

# debug and dry run
DEBUG=0;
DRYRUN=0;
# options
OPT_REMOTE="";
# basic settings needed
TARGET_USER="";
TARGET_HOST="";
TARGET_PORT="";
TARGET_BORG_PATH="";
TARGET_FOLDER="";
# base folder
BASE_FOLDER="/usr/local/scripts/borg/";
# those are the valid modules
MODULE_LIST="file gitea mysql pgsql zabbix"

# basic options
# -c for config file override
# -n for dry run test
while getopts ":c:nd" opt; do
	case "${opt}" in
		c|config)
			BASE_FOLDER=${OPTARG};
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

if [ ! -z "${TARGET_BORG_PATH}" ]; then
	OPT_REMOTE="--remote-path="$(printf "%q" "${TARGET_BORG_PATH}");
fi;
export BORG_BASE_DIR="${BASE_FOLDER}";
export BORG_UNKNOWN_UNENCRYPTED_REPO_ACCESS_IS_OK="yes";
export BORG_RELOCATED_REPO_ACCESS_IS_OK="yes";

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
	# set sudo prefix for postgres so the cache folder stays the same
	# if run as root then the foloders below have to have the user set to postgres again
	# .config/borg/security/<postgresql repo id>
	# .cache/borg/<postgresql repo id>
	CMD_PREFIX="";
	if [ "${MODULE}" = "pgsql" ]; then
		CMD_PREFIX="sudo -E -u postgres ";
	fi;
	echo "==== REPOSITORY: ${REPOSITORY}";
	borg list ${OPT_REMOTE} --format '{archive}{NL}' ${REPOSITORY}|grep -v "${MODULE},"|
	while read i; do
		# for gitea, zabbix we do not ADD we RENAME
		if [ "${MODULE}" = "gitea" ]; then
			# if just date, add gitea,
			# else rename
			if [ ! -z "${i##gitea*}" ]; then
				target_name="${MODULE},${i}";
			else
				target_name=$(echo $i | sed -e 's/gitea-/gitea,/');
			fi;
		elif [ "${MODULE}" = "zabbix" ]; then
			# if zabbix is missing, prefix
			if [ ! -z "${i##zabbix*}" ]; then
				target_name="${MODULE},${i}";
			else
				target_name=$(echo $i | sed -e 's/zabbix-settings-/zabbix,settings-/');
			fi;
		else
			target_name="${MODULE},${i}";
		fi;
		echo "- Rename from: ${i} to: ${target_name}";
		if [ ${DEBUG} -eq 1 ]; then
			echo "${CMD_PREFIX}borg rename ${OPT_REMOTE} -p -v ${REPOSITORY}::${i} ${target_name}";
		fi;
		if [ ${DRYRUN} -eq 0 ]; then
			${CMD_PREFIX}borg rename ${OPT_REMOTE} -p -v ${REPOSITORY}::${i} ${target_name};
		fi;
	done;
done;

# __END__
