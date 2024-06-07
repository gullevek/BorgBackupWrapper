#!/usr/bin/env bash

# Backup gitea database, all git folders and gitea settings

MODULE="gitea"
MODULE_VERSION="1.2.0";

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
# to run this as root and have only the dump command itself run as GIT_USER
# set git user
if [ -z "${GIT_USER}" ]; then
	GIT_USER="git";
fi;
# set GITEA_* if not set
if [ -z "${GITEA_WORKING_DIR}" ]; then
	# run gitea backup (user mktemp?)
	GITEA_WORKING_DIR="/var/tmp/gitea/";
fi;
# general temp folder for temporary data storage, this is not working output folder
if [ -z "${GITEA_TEMP_DIR}"]; then
	GITEA_TEMP_DIR="/var/tmp";
fi;
if [ -z "${GITEA_BIN}" ]; then
	GITEA_BIN="/usr/local/bin/gitea";
fi;
if [ -z "${GITEA_CONFIG}" ]; then
	GITEA_CONFIG="/etc/gitea/app.ini"
fi;
# This one is not advertised in the config file as it is not recommended to change
if [ -z "${GITEA_EXPORT_TYPE}" ]; then
	GITEA_EXPORT_TYPE="zip";
fi;
if [ ! -f "${GITEA_BIN}" ]; then
	echo "[! $(date +'%F %T')] Cannot find gitea binary";
	. "${DIR}/borg.backup.functions.close.sh" 1;
	exit 1;
fi;
if [ ! -f "${GITEA_CONFIG}" ]; then
	echo "[! $(date +'%F %T')] Cannot find gitea config";
	. "${DIR}/borg.backup.functions.close.sh" 1;
	exit 1;
fi;
# some basic checks with abort
if [ ! -d "${GITEA_TEMP_DIR}" ]; then
	echo "Temp directory does not exist: ${GITEA_TEMP_DIR}";
	exit;
fi;
# we should check GITEA_EXPORT_TYPE too at some point for an allow list
# At the moment warn if not zip
if [ "${GITEA_EXPORT_TYPE}" != "zip" ]; then
	echo "[!!!!] The gitea export type has been changed from 'zip' to '${GITEA_EXPORT_TYPE}'. This can either break or make exports take very ling";
fi;
# Filename
FILENAME="gitea.backup.zip";
# backup set and prefix
BACKUP_SET_PREFIX="${MODULE},";
BACKUP_SET_NAME="${ONE_TIME_TAG}${BACKUP_SET_PREFIX}${BACKUP_SET}";

# borg call
BORG_CALL=$(echo "${_BORG_CALL}" | sed -e "s/##FILENAME##/${FILENAME}/" | sed -e "s/##BACKUP_SET##/${BACKUP_SET_NAME}/");
BORG_PRUNE=$(echo "${_BORG_PRUNE}" | sed -e "s/##BACKUP_SET_PREFIX##/${BACKUP_SET_PREFIX}/");
printf "${PRINTF_SUB_BLOCK}" "BACKUP: git data and database" "$(date +'%F %T')" "${MODULE}";
if [ ${DEBUG} -eq 1 ] || [ ${DRYRUN} -eq 1 ]; then
	echo "sudo -u ${GIT_USER} ${GITEA_BIN} dump -c ${GITEA_CONFIG} -w ${GITEA_WORKING_DIR} -t ${GITEA_TEMP_DIR} --type ${GITEA_EXPORT_TYPE} -L -f - | ${BORG_CALL}";
	if [ -z "${ONE_TIME_TAG}" ]; then
		echo "${BORG_PRUNE}";
	fi;
fi;
if [ ${DRYRUN} -eq 0 ]; then
	(
		# below was an old workaround
		#export USER="${LOGNAME}" # workaround for broken gitea EUID check
		# make sure temp folder is there and is set as git. user
		if [ ! -d "${GITEA_WORKING_DIR}" ]; then
			mkdir -p "${GITEA_WORKING_DIR}";
		fi;
		chown -R ${GIT_USER}. "${GITEA_WORKING_DIR}";
		# this needs to be run in a folder that can be stat by git user
		cd "${GITEA_WORKING_DIR}";
		sudo -u ${GIT_USER} ${GITEA_BIN} dump -c ${GITEA_CONFIG} -w ${GITEA_WORKING_DIR} -t ${GITEA_TEMP_DIR} --type ${GITEA_EXPORT_TYPE} -L -f - | ${BORG_CALL};
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
