#!/usr/bin/env bash

MODULE="gitea"
MODULE_VERSION="0.1.0";

DIR="${BASH_SOURCE%/*}"
if [[ ! -d "$DIR" ]]; then DIR="$PWD"; fi
# init system
. "${DIR}/borg.backup.functions.init.sh";

# init check file
BACKUP_INIT_CHECK="borg.backup.gitea.init";

# check valid data
. "${DIR}/borg.backup.functions.check.sh";
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
	exit 1;
fi;
if [ ! -f "${GITEA_CONFIG}" ]; then
	echo "[! $(date +'%F %T')] Cannot find gitea config";
	exit 1;
fi;
# Filename
FILENAME="gitea.backup.zip";
# backup set and prefix
BACKUP_SET_NAME="gitea-${BACKUP_SET}";
BACKUP_SET_PREFIX="gitea-";

# borg call, replace ##...## parts
_BORG_CALL="borg create ${OPT_REMOTE} -v ${OPT_LIST} ${OPT_PROGRESS} ${OPT_COMPRESSION} -s --stdin-name ##FILENAME## ${REPOSITORY}::##BACKUP_SET## -";
_BORG_PRUNE="borg prune ${OPT_REMOTE} -v -s --list ${PRUNE_DEBUG} -P ##BACKUP_SET_PREFIX## ${KEEP_OPTIONS[*]} ${REPOSITORY}";
# borg call
BORG_CALL=$(echo "${_BORG_CALL}" | sed -e "s/##FILENAME##/${FILENAME}/" | sed -e "s|##REPOSITORY##|${REPOSITORY}|" | sed -e "s/##BACKUP_SET##/${BACKUP_SET}/");
BORG_PRUNE=$(echo "${_BORG_PRUNE}" | sed -e "s|##REPOSITORY##|${REPOSITORY}|" | sed -e "s/##BACKUP_SET_PREFIX##/${BACKUP_SET_PREFIX}/");
echo "--- [git data and database: $(date +'%F %T')] --[${MODULE}]------------------------------------>";
if [ ${DEBUG} -eq 1 ] || [ ${DRYRUN} -eq 1 ]; then
	echo "sudo -u ${GIT_USER} ${GITEA_BIN} dump -c ${GITEA_CONFIG} -w ${GITEA_TMP} -L -f - | ${BORG_CALL}";
	echo "${BORG_PRUNE}";
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
	)
fi;
echo "Prune repository with keep${KEEP_INFO:1}";
${BORG_PRUNE};

. "${DIR}/borg.backup.functions.close.sh";

# __END__
