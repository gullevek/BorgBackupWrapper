#!/usr/bin/env bash

# Backup gitea database, all git folders and gitea settings

MODULE="gitea"
MODULE_VERSION="1.1.4";

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
if [ -z "${GITEA_TMP}" ]; then
	# run gitea backup (user mktemp?)
	GITEA_TMP="/tmp/gitea/";
fi;
if [ -z "${GITEA_BIN}" ]; then
	GITEA_BIN="/usr/local/bin/gitea";
fi;
if [ -z "${GITEA_CONFIG}" ]; then
	GITEA_CONFIG="/etc/gitea/app.ini"
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
	echo "sudo -u ${GIT_USER} ${GITEA_BIN} dump -c ${GITEA_CONFIG} -w ${GITEA_TMP} -L -f - | ${BORG_CALL}";
	if [ -z "${ONE_TIME_TAG}" ]; then
		echo "${BORG_PRUNE}";
	fi;
fi;
if [ ${DRYRUN} -eq 0 ]; then
	(
		# below was an old workaround
		#export USER="${LOGNAME}" # workaround for broken gitea EUID check
		# make sure temp folder is there and is set as git. user
		if [ ! -d "${GITEA_TMP}" ]; then
			mkdir -p "${GITEA_TMP}";
		fi;
		chown -R ${GIT_USER}. "${GITEA_TMP}";
		# this needs to be run in a folder that can be stat by git user
		cd "${GITEA_TMP}";
		sudo -u ${GIT_USER} ${GITEA_BIN} dump -c ${GITEA_CONFIG} -w ${GITEA_TMP} -L -f - | ${BORG_CALL};
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
