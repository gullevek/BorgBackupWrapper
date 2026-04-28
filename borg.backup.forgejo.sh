#!/usr/bin/env bash

# allow variables in printf format string
# shellcheck disable=SC2059

# Backup forgejo database, all git folders and forgejo settings

MODULE="forgejo"
MODULE_VERSION="1.0.0";

DIR="${BASH_SOURCE%/*}"
if [[ ! -d "$DIR" ]]; then DIR="$PWD"; fi
# init system
. "${DIR}/borg.backup.functions.init.sh";

# init verify, compact and check file
BACKUP_INIT_FILE="borg.backup.${MODULE}.init";
BACKUP_COMPACT_FILE="borg.backup.${MODULE}.compact";
BACKUP_CHECK_FILE="borg.backup.${MODULE}.check";
# lock file
BACKUP_LOCK_FILE="borg.backup.${MODULE}.lock";

# verify valid data
. "${DIR}/borg.backup.functions.verify.sh";
# if info print info and then abort run
. "${DIR}/borg.backup.functions.info.sh";

# NOTE: because a tmp directory is needed it is more recommended
# to run this as root and have only the dump command itself run as FORGEJO_GIT_USER
# set git user
if [ -z "${FORGEJO_GIT_USER}" ]; then
	FORGEJO_GIT_USER="git";
fi;
# set FORGEJO_* if not set
if [ -z "${FORGEJO_WORKING_DIR}" ]; then
	# run forgejo backup (user mktemp?)
	FORGEJO_WORKING_DIR="/var/tmp/forgejo/";
fi;
# general temp folder for temporary data storage, this is not working output folder
if [ -z "${FORGEJO_TEMP_DIR}" ]; then
	FORGEJO_TEMP_DIR="/var/tmp";
fi;
if [ -z "${FORGEJO_BIN}" ]; then
	FORGEJO_BIN="/usr/local/bin/forgejo";
fi;
if [ -z "${FORGEJO_CONFIG}" ]; then
	FORGEJO_CONFIG="/etc/forgejo/app.ini"
fi;
# This one is not advertised in the config file as it is not recommended to change
if [ -z "${FORGEJO_EXPORT_TYPE}" ]; then
	FORGEJO_EXPORT_TYPE="zip";
fi;
if [ ! -f "${FORGEJO_BIN}" ]; then
	echo "[! $(date +'%F %T')] Cannot find forgejo binary";
	. "${DIR}/borg.backup.functions.close.sh" 1;
	exit 1;
fi;
if [ ! -f "${FORGEJO_CONFIG}" ]; then
	echo "[! $(date +'%F %T')] Cannot find forgejo config";
	. "${DIR}/borg.backup.functions.close.sh" 1;
	exit 1;
fi;
# some basic checks with abort
if [ ! -d "${FORGEJO_TEMP_DIR}" ]; then
	echo "Temp directory does not exist: ${FORGEJO_TEMP_DIR}";
	exit;
fi;
# we should check FORGEJO_EXPORT_TYPE too at some point for an allow list
# At the moment warn if not zip
if [ "${FORGEJO_EXPORT_TYPE}" != "zip" ]; then
	echo "[!!!!] The forgejo export type has been changed from 'zip' to '${FORGEJO_EXPORT_TYPE}'. This can either break or make exports take very ling";
fi;
# Filename
FILENAME="forgejo.backup.zip";
# backup set and prefix
BACKUP_SET_PREFIX="${MODULE},";
BACKUP_SET_NAME="${ONE_TIME_TAG}${BACKUP_SET_PREFIX}${BACKUP_SET}";

# borg call
BORG_CALL=$(echo "${_BORG_CALL}" | sed -e "s/##FILENAME##/${FILENAME}/" | sed -e "s/##BACKUP_SET##/${BACKUP_SET_NAME}/");
BORG_PRUNE=$(echo "${_BORG_PRUNE}" | sed -e "s/##BACKUP_SET_PREFIX##/${BACKUP_SET_PREFIX}/");
printf "${PRINTF_SUB_BLOCK}" "BACKUP: git data and database" "$(date +'%F %T')" "${MODULE}";
if [ ${DEBUG} -eq 1 ] || [ ${DRYRUN} -eq 1 ]; then
	echo "sudo -u ${FORGEJO_GIT_USER} ${FORGEJO_BIN} dump -c ${FORGEJO_CONFIG} -w ${FORGEJO_WORKING_DIR} -t ${FORGEJO_TEMP_DIR} --type ${FORGEJO_EXPORT_TYPE} -L -f - | ${BORG_CALL}";
	if [ -z "${ONE_TIME_TAG}" ]; then
		echo "${BORG_PRUNE}";
	fi;
fi;
if [ ${DRYRUN} -eq 0 ]; then
	(
		# below was an old workaround
		#export USER="${LOGNAME}" # workaround for broken forgejo EUID check
		# make sure temp folder is there and is set as git. user
		if [ ! -d "${FORGEJO_WORKING_DIR}" ]; then
			mkdir -p "${FORGEJO_WORKING_DIR}";
		fi;
		chown -R ${FORGEJO_GIT_USER}: "${FORGEJO_WORKING_DIR}";
		# this needs to be run in a folder that can be stat by git user
		cd "${FORGEJO_WORKING_DIR}" || exit 1;
		sudo -u ${FORGEJO_GIT_USER} ${FORGEJO_BIN} dump -c ${FORGEJO_CONFIG} -w ${FORGEJO_WORKING_DIR} -t ${FORGEJO_TEMP_DIR} --type ${FORGEJO_EXPORT_TYPE} -L -f - | ${BORG_CALL};
	) 2>&1 | sed 's/\x1B\[[0-9;]\{1,\}[A-Za-z]//g' # remove all ESC strings
fi;
if [ -z "${ONE_TIME_TAG}" ]; then
	printf "${PRINTF_SUB_BLOCK}" "PRUNE" "$(date +'%F %T')" "${MODULE}";
	echo "Prune repository with keep${KEEP_INFO:1}";
	${BORG_PRUNE};
	# if this is borg version >1.2 we need to run compact after prune
	. "${DIR}/borg.backup.functions.compact.sh" "auto";
	# check in auto mode
	. "${DIR}/borg.backup.functions.check.sh" "auto";
fi;

. "${DIR}/borg.backup.functions.close.sh";

# __END__
