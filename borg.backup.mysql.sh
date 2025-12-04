#!/usr/bin/env bash

# allow variables in printf format string
# shellcheck disable=SC2059

# Backup MySQL/MariaDB
# default is per table dump, can be set to one full dump
# config override set in borg.backup.mysql.settings
# if run as mysql user, be sure user is in the backup group

# set last edit date + time
MODULE="mysql"
MODULE_VERSION="1.1.5";

DIR="${BASH_SOURCE%/*}"
if [[ ! -d "$DIR" ]]; then DIR="$PWD"; fi
# init system
. "${DIR}/borg.backup.functions.init.sh";

# include and exclude file
INCLUDE_FILE="borg.backup.${MODULE}.include";
EXCLUDE_FILE="borg.backup.${MODULE}.exclude";
SCHEMA_ONLY_FILE="borg.backup.${MODULE}.schema-only";
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

# if there is an DB extra config
# on current installs there should be a root or mysql user with unix socket connection
# the script should by run as the mysql or root user (sudo -u mysql ...)
if [ -f "${MYSQL_DB_CONFIG}" ]; then
	# MYSQL_DB_CONFIG='/root/.my.cnf';
	MYSQL_DB_CONFIG_PARAM="--defaults-extra-file=${MYSQL_DB_CONFIG}";
fi;
MYSQL_BASE_PATH='/usr/bin/';
MYSQL_DUMP=${MYSQL_BASE_PATH}'mysqldump';
MYSQL_CMD=${MYSQL_BASE_PATH}'mysql';
# no dump or mysql, bail
if [ ! -f "${MYSQL_DUMP}" ]; then
	echo "[! $(date +'%F %T')] mysqldump binary not found";
	. "${DIR}/borg.backup.functions.close.sh" 1;
	exit 1;
fi;
if [ ! -f "${MYSQL_CMD}" ]; then
	echo "[! $(date +'%F %T')] mysql binary not found";
	. "${DIR}/borg.backup.functions.close.sh" 1;
	exit 1;
fi;
# verify that the user can actually do, else abort here
# note: this is the only way to not error
_MYSQL_VERIFY=$(mysqladmin ${MYSQL_DB_CONFIG_PARAM} ping 2>&1);
_MYSQL_OK=$(echo "${_MYSQL_VERIFY}" | grep "is alive");
if [ -z "${_MYSQL_OK}" ]; then
	echo "[! $(date +'%F %T')] Current user has no access right to mysql database";
	. "${DIR}/borg.backup.functions.close.sh" 1;
	exit 1;
fi;
# below is for file name only
# set DB_VERSION (Distrib n.n.n-type)
# OLD:     mysql  Ver 14.14 Distrib 5.7.35, for Linux (x86_64) using  EditLine wrapper
# NEW:     mysql  Ver 15.1 Distrib 10.5.12-MariaDB, for debian-linux-gnu (x86_64) using  EditLine wrapper
# VARIANT: mysql from 11.8.3-MariaDB, client 15.2 for debian-linux-gnu (x86_64) using  EditLine wrapper
_DB_VERSION_TYPE=$("${MYSQL_CMD}" --version);
_DB_VERSION=$(echo "${_DB_VERSION_TYPE}" | sed 's/.*\(Distrib\|from\) \([0-9]\{1,\}\.[0-9]\{1,\}\)\.[0-9]\{1,\}.*/\2/');
DB_VERSION=$(echo "${_DB_VERSION}" | cut -d " " -f 1);
# temporary until correct type detection is set
DB_TYPE="mysql";
# try to get type from -string, if empty set mysql
# if [[ ${_DB_VERSION_TYPE##*-*} ]]; then
# 	DB_TYPE="mysql";
# else
# 	DB_TYPE=$(echo "${_DB_TYPE}" | sed -e 's/.*[0-9]-\([A-Za-z]\{1,\}\).*/\1/');
# fi;
DB_PORT='3306';
DB_HOST='local';

# those dbs have to be dropped with skip locks (single transaction)
NOLOCKDB="information_schema performance_schema"
NOLOCKS="--single-transaction"
# those tables need to be dropped with EVENTS
EVENTDB="mysql"
EVENTS="--events"

# ALL IN ONE FILE or PER DATABASE FLAG
if [ -n "${DATABASE_FULL_DUMP}" ]; then
	SCHEMA_ONLY='';
	schema_flag='data';
	if [ "${DATABASE_FULL_DUMP}" = "schema" ]; then
		SCHEMA_ONLY='--no-data';
		schema_flag='schema';
	fi;
	LOCAL_START=$(date +'%s');
	printf "${PRINTF_SUBEXT_BLOCK}" "BACKUP" "all databases" "$(date +'%F %T')" "${MODULE}";
	# We only do a full backup and not per table backup here
	# Filename
	FILENAME="all-${schema_flag}-${DB_TYPE}_${DB_VERSION}_${DB_HOST}_${DB_PORT}.sql"
	# backup set:
	BACKUP_SET_PREFIX="${MODULE},all-";
	BACKUP_SET_NAME="${ONE_TIME_TAG}${BACKUP_SET_PREFIX}${schema_flag}-${BACKUP_SET}";
	# borg call
	BORG_CALL=$(echo "${_BORG_CALL}" | sed -e "s/##FILENAME##/${FILENAME}/" | sed -e "s/##BACKUP_SET##/${BACKUP_SET_NAME}/");
	BORG_PRUNE=$(echo "${_BORG_PRUNE}" | sed -e "s/##BACKUP_SET_PREFIX##/${BACKUP_SET_PREFIX}/");
	if [ ${DEBUG} -eq 1 ] || [ ${DRYRUN} -eq 1 ]; then
		echo "export BORG_BASE_DIR=\"${BASE_FOLDER}\";";
		echo "${MYSQL_DUMP} ${MYSQL_DB_CONFIG_PARAM} --all-databases --create-options --add-drop-database --events ${SCHEMA_ONLY} | ${BORG_CALL}";
		if [ -z "${ONE_TIME_TAG}" ]; then
			echo "${BORG_PRUNE}";
		fi;
	fi;
	if [ ${DRYRUN} -eq 0 ]; then
		${MYSQL_DUMP} ${MYSQL_DB_CONFIG_PARAM} --all-databases --create-options --add-drop-database --events ${SCHEMA_ONLY} | ${BORG_CALL};
		_backup_error=$?;
		if [ $_backup_error -ne 0 ]; then
			echo "[! $(date +'%F %T')] Backup creation failed for full dump with error code: ${_backup_error}";
			. "${DIR}/borg.backup.functions.close.sh" 1;
			exit $_backup_error;
		fi;
	fi;
	if [ -z "${ONE_TIME_TAG}" ]; then
		printf "${PRINTF_SUBEXT_BLOCK}" "PRUNE" "all databases" "$(date +'%F %T')" "${MODULE}";
		echo "Prune repository with keep${KEEP_INFO:1}";
		${BORG_PRUNE};
	fi;
	DURATION=$(( $(date +'%s') - LOCAL_START ));
	printf "${PRINTF_DB_RUN_TIME_SUB_BLOCK}" "DONE" "all databases" "${MODULE}" "$(convert_time ${DURATION})";
else
	${MYSQL_CMD} ${MYSQL_DB_CONFIG_PARAM} -B -N -e "show databases" |
	while read -r db; do
		LOCAL_START=$(date +'%s');
		printf "${PRINTF_DB_SUB_BLOCK}" "DB" "${db}" "${MODULE}";
		printf "${PRINTF_SUBEXT_BLOCK}" "BACKUP" "${db}" "$(date +'%F %T')" "${MODULE}";
		# exclude checks
		include=0;
		if [ -s "${BASE_FOLDER}${INCLUDE_FILE}" ]; then
			while read incl_db; do
				if [ "${db}" = "${incl_db}" ]; then
					include=1;
					break;
				fi;
			done<"${BASE_FOLDER}${INCLUDE_FILE}";
		else
			include=1;
		fi;
		exclude=0;
		if [ -f "${BASE_FOLDER}${EXCLUDE_FILE}" ]; then
			while read -r excl_db; do
				if [ "${db}" = "${excl_db}" ]; then
					exclude=1;
					break;
				fi;
			done<"${BASE_FOLDER}${EXCLUDE_FILE}";
		fi;
		if [ ${include} -eq 1 ] && [ ${exclude} -eq 0 ]; then
			# lock check
			nolock='';
			for nolock_db in $NOLOCKDB;
			do
				if [ "$nolock_db" = "$db" ];
				then
					nolock=$NOLOCKS;
				fi;
			done;
			# event check
			event='';
			for event_db in $EVENTDB;
			do
				if [ "$event_db" = "$db" ];
				then
					event=$EVENTS;
				fi;
			done;
			# set dump type
			SCHEMA_ONLY=''; # empty for all
			schema_flag='data'; # or data
			if [ -s "${BASE_FOLDER}${SCHEMA_ONLY_FILE}" ]; then
				while read -r schema_db; do
					if [ "${db}" = "${schema_db}" ]; then
						SCHEMA_ONLY='--no-data';
						schema_flag='schema';
						# skip out
						break;
					fi;
				done<"${BASE_FOLDER}${SCHEMA_ONLY_FILE}";
			fi;
			# prepare borg calls
			FILENAME="${db}-${schema_flag}-${DB_TYPE}_${DB_VERSION}_${DB_HOST}_${DB_PORT}.sql"
			# backup set:
			BACKUP_SET_PREFIX="${MODULE},${db}-"
			BACKUP_SET_NAME="${ONE_TIME_TAG}${BACKUP_SET_PREFIX}${schema_flag}-${BACKUP_SET}";
			# borg call
			BORG_CALL=$(echo "${_BORG_CALL}" | sed -e "s/##FILENAME##/${FILENAME}/" | sed -e "s/##BACKUP_SET##/${BACKUP_SET_NAME}/");
			BORG_PRUNE=$(echo "${_BORG_PRUNE}" | sed -e "s/##BACKUP_SET_PREFIX##/${BACKUP_SET_PREFIX}/");
			# debug or dry run
			if [ ${DEBUG} -eq 1 ] || [ ${DRYRUN} -eq 1 ]; then
				echo "export BORG_BASE_DIR=\"${BASE_FOLDER}\";";
				echo "${MYSQL_DUMP} ${MYSQL_DB_CONFIG_PARAM} $nolock $event --opt ${SCHEMA_ONLY} --add-drop-database --databases ${db} | ${BORG_CALL};"
			fi;
			# backup
			if [ ${DRYRUN} -eq 0 ]; then
				$MYSQL_DUMP ${MYSQL_DB_CONFIG_PARAM} $nolock $event --opt ${SCHEMA_ONLY} --add-drop-database --databases ${db} | ${BORG_CALL};
				_backup_error=$?;
				if [ $_backup_error -ne 0 ]; then
					echo "[! $(date +'%F %T')] Backup creation failed for ${db} dump with error code: ${_backup_error}";
					. "${DIR}/borg.backup.functions.close.sh" 1;
					exit $_backup_error;
				fi;
			fi;
			if [ -z "${ONE_TIME_TAG}" ]; then
				printf "${PRINTF_SUBEXT_BLOCK}" "PRUNE" "${db}" "$(date +'%F %T')" "${MODULE}";
				echo "Prune repository prefixed ${BACKUP_SET_PREFIX} with keep${KEEP_INFO:1}";
				${BORG_PRUNE};
			fi;
		else
			echo "- [E] ${db}";
		fi;
		DURATION=$(( $(date +'%s') - LOCAL_START ));
		printf "${PRINTF_DB_RUN_TIME_SUB_BLOCK}" "DONE" "${db}" "${MODULE}" "$(convert_time ${DURATION})";
	done;
fi;
# run compact at the end if not a dry run
if [ -z "${ONE_TIME_TAG}" ]; then
	# if this is borg version >1.2 we need to run compact after prune
	. "${DIR}/borg.backup.functions.compact.sh" "auto";
	# check in auto mode
	. "${DIR}/borg.backup.functions.check.sh" "auto";
fi;

. "${DIR}/borg.backup.functions.close.sh";

# __END__
