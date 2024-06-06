#!/usr/bin/env bash

# Backup PostgreSQL
# default is per table dump, can be set to one full dump
# config override set in borg.backup.pgsql.settings
# if run as postgres user, be sure user is in the backup group

# set last edit date + time
MODULE="pgsql"
MODULE_VERSION="1.2.2";


DIR="${BASH_SOURCE%/*}"
if [[ ! -d "$DIR" ]]; then DIR="$PWD"; fi
# init system
. "${DIR}/borg.backup.functions.init.sh";

# include and exclude file
INCLUDE_FILE="borg.backup.${MODULE}.include";
EXCLUDE_FILE="borg.backup.${MODULE}.exclude";
SCHEMA_ONLY_FILE="borg.backup.${MODULE}.schema-only";
DATA_ONLY_FILE="borg.backup.${MODULE}.data-only";
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

if [ ! -z "${DATABASE_USER}" ]; then
	DB_USER=${DATABASE_USER};
else
	DB_USER='postgres';
fi;
# get current pgsql version first
# if first part <10 then user full, else only first part
# eg 9.4 -> 9.4, 12.5 -> 12
PG_VERSION=$(pgv=$(psql -U ${DB_USER} -d template1 -t -A -F "," -X -q -c 'select version();' | sed -e 's/^PostgreSQL \([0-9]\{1,\}\.[0-9]\{1,\}\).*/\1/'); if [[ $(echo "${pgv}" | cut -d "." -f 1) -ge 10 ]]; then echo "${pgv}" | cut -d "." -f 1; else echo "${pgv}" | cut -d "." -f 1,2; fi );
_PATH_PG_VERSION=${PG_VERSION};
_backup_error=$?;
if [ $_backup_error -ne 0 ] || [ -z "${PG_VERSION}" ]; then
	echo "[! $(date +'%F %T')] Cannot get PostgreSQL server version: ${_backup_error}";
	. "${DIR}/borg.backup.functions.close.sh" 1;
	exit $_backup_error;
fi;

# path set per Distribution type and current running DB version
# Redhat: PG_BASE_PATH='/usr/pgsql-';
# AWS 1: PG_BASE_PATH='/usr/lib64/pgsql';
# Debian: PG_BASE_PATH='/usr/lib/postgresql/';
PG_BASE_PATH='/usr/lib/postgresql/';
if [ ! -f "${PG_BASE_PATH}${_PATH_PG_VERSION}/bin/psql" ]; then
	PG_BASE_PATH='/usr/pgsql-';
	if [ ! -f "${PG_BASE_PATH}${_PATH_PG_VERSION}/bin/psql" ]; then
		PG_BASE_PATH='/usr/lib64/pgsql';
		_PATH_PG_VERSION=$(echo "${PG_VERSION}" | sed -e 's/\.//');
		if [ ! -f "${PG_BASE_PATH}${_PATH_PG_VERSION}/bin/psql" ]; then
			echo "[! $(date +'%F %T')] PostgreSQL not found in any paths";
			. "${DIR}/borg.backup.functions.close.sh" 1;
			exit 1;
		fi;
	fi;
fi;
PG_PATH=${PG_BASE_PATH}${_PATH_PG_VERSION}'/bin/';
PG_PSQL=${PG_PATH}'psql';
PG_DUMP=${PG_PATH}'pg_dump';
PG_DUMPALL=${PG_PATH}'pg_dumpall';
# check that command are here
if [ ! -f "${PG_PSQL}" ]; then
	echo "[! $(date +'%F %T')] psql binary not found in ${PG_PATH}";
	. "${DIR}/borg.backup.functions.close.sh" 1;
	exit 1;
fi;
if [ ! -f "${PG_DUMP}" ]; then
	echo "[! $(date +'%F %T')] pg_dump binary not found in ${PG_PATH}";
	. "${DIR}/borg.backup.functions.close.sh" 1;
	exit 1;
fi;
if [ ! -f "${PG_DUMPALL}" ]; then
	echo "[! $(date +'%F %T')] pg_dumpall binary not found in ${PG_PATH}";
	. "${DIR}/borg.backup.functions.close.sh" 1;
	exit 1;
fi;

DB_VERSION=${PG_VERSION};
# TODO override port/host info
DB_PORT='5432';
DB_HOST='local'; # or <host>
CONN_DB_HOST=''; # -h <host>
CONN_DB_PORT=''; # -p <port>

# ALL IN ONE FILE or PER DATABASE FLAG
if [ ! -z "${DATABASE_FULL_DUMP}" ]; then
	SCHEMA_ONLY='';
	schema_flag='data';
	if [ "${DATABASE_FULL_DUMP}" = "schema" ]; then
		SCHEMA_ONLY='-s';
		schema_flag='schema';
	fi;
	LOCAL_START=$(date +'%s');
	printf "${PRINTF_SUBEXT_BLOCK}" "BACKUP" "all databases" "$(date +'%F %T')" "${MODULE}";
	# Filename
	FILENAME-"all.${DB_USER}.NONE.${schema_flag}-${DB_VERSION}_${DB_HOST}_${DB_PORT}.c.sql"
	# backup set:
	BACKUP_SET_PREFIX="${MODULE},all-";
	BACKUP_SET_NAME="${ONE_TIME_TAG}${BACKUP_SET_PREFIX}${schema_flag}-${BACKUP_SET}";
	# borg call
	BORG_CALL=$(echo "${_BORG_CALL}" | sed -e "s/##FILENAME##/${FILENAME}/" | sed -e "s/##BACKUP_SET##/${BACKUP_SET_NAME}/");
	BORG_PRUNE=$(echo "${_BORG_PRUNE}" | sed -e "s/##BACKUP_SET_PREFIX##/${BACKUP_SET_PREFIX}/");
	if [ ${DEBUG} -eq 1 ] || [ ${DRYRUN} -eq 1 ]; then
		echo "export BORG_BASE_DIR=\"${BASE_FOLDER}\";";
		echo "${PG_DUMPALL} -U ${DB_USER} ${CONN_DB_HOST} ${CONN_DB_PORT} ${SCHEMA_ONLY} -c | ${BORG_CALL}";
		if [ -z "${ONE_TIME_TAG}" ]; then
			echo "${BORG_PRUNE}";
		fi;
	fi;
	if [ ${DRYRUN} -eq 0 ]; then
		$(${PG_DUMPALL} -U ${DB_USER} ${CONN_DB_HOST} ${CONN_DB_PORT} ${SCHEMA_ONLY} -c | ${BORG_CALL});
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
	DURATION=$[ $(date +'%s')-$LOCAL_START ];
	printf "${PRINTF_DB_RUN_TIME_SUB_BLOCK}" "DONE" "databases" "${MODULE}" "$(convert_time ${DURATION})";
else
	# dump globals first
	db="pg_globals";
	schema_flag="data";
	LOCAL_START=$(date +'%s');
	printf "${PRINTF_SUBEXT_BLOCK}" "BACKUP" "${db}" "$(date +'%F %T')" "${MODULE}";
	# Filename
	FILENAME="${db}.${DB_USER}.NONE.${schema_flag}-${DB_VERSION}_${DB_HOST}_${DB_PORT}.c.sql"
	# backup set:
	BACKUP_SET_PREFIX="${MODULE},${db}-";
	BACKUP_SET_NAME="${ONE_TIME_TAG}${BACKUP_SET_PREFIX}${schema_flag}-${BACKUP_SET}";
	# borg call
	BORG_CALL=$(echo "${_BORG_CALL}" | sed -e "s/##FILENAME##/${FILENAME}/" | sed -e "s/##BACKUP_SET##/${BACKUP_SET_NAME}/");
	BORG_PRUNE=$(echo "${_BORG_PRUNE}" | sed -e "s/##BACKUP_SET_PREFIX##/${BACKUP_SET_PREFIX}/");
	if [ ${DEBUG} -eq 1 ] || [ ${DRYRUN} -eq 1 ]; then
		echo "export BORG_BASE_DIR=\"${BASE_FOLDER}\";";
		echo "${PG_DUMPALL} -U ${DB_USER} ${CONN_DB_HOST} ${CONN_DB_PORT} --globals-only | ${BORG_CALL}";
		if [ -z "${ONE_TIME_TAG}" ]; then
			echo "${BORG_PRUNE}";
		fi;
	fi;
	if [ ${DRYRUN} -eq 0 ]; then
		${PG_DUMPALL} -U ${DB_USER} ${CONN_DB_HOST} ${CONN_DB_PORT} --globals-only | ${BORG_CALL};
		_backup_error=$?;
		if [ $_backup_error -ne 0 ]; then
			echo "[! $(date +'%F %T')] Backup creation failed for ${db} dump with error code: ${_backup_error}";
			. "${DIR}/borg.backup.functions.close.sh" 1;
			exit $_backup_error;
		fi;
	fi;
	if [ -z "${ONE_TIME_TAG}" ]; then
		printf "${PRINTF_SUBEXT_BLOCK}" "PRUNE" "${db}" "$(date +'%F %T')" "${MODULE}";
		echo "Prune repository with keep${KEEP_INFO:1}";
		${BORG_PRUNE};
	fi;
	printf "${PRINTF_DB_RUN_TIME_SUB_BLOCK}" "BACKUP" "${db}" "${MODULE}" "$(convert_time ${DURATION})";

	# get list of tables
	for owner_db in $(${PG_PSQL} -U ${DB_USER} ${CONN_DB_HOST} ${CONN_DB_PORT} -d template1 -t -A -F "," -X -q -c "SELECT pg_catalog.pg_get_userbyid(datdba) AS owner, datname, pg_catalog.pg_encoding_to_char(encoding) AS encoding FROM pg_catalog.pg_database WHERE datname "\!"~ 'template(0|1)' ORDER BY datname;"); do
		LOCAL_START=$(date +'%s');
		# get the user who owns the DB too
		owner=$(echo ${owner_db} | cut -d "," -f 1);
		db=$(echo ${owner_db} | cut -d "," -f 2);
		encoding=$(echo ${owner_db} | cut -d "," -f 3);
		printf "${PRINTF_DB_SUB_BLOCK}" "DB" "${db}" "${MODULE}";
		printf "${PRINTF_SUBEXT_BLOCK}" "BACKUP" "${db}" "$(date +'%F %T')" "${MODULE}";
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
			while read excl_db; do
				if [ "${db}" = "${excl_db}" ]; then
					exclude=1;
					break;
				fi;
			done<"${BASE_FOLDER}${EXCLUDE_FILE}";
		fi;
		if [ ${include} -eq 1 ] && [ ${exclude} -eq 0 ]; then
			# set dump type
			SCHEMA_ONLY='';
			schema_flag=''; # schema or data
			# schema exclude over data exclude, can't have both
			if [ -s "${BASE_FOLDER}${SCHEMA_ONLY_FILE}" ]; then
				# default is data dump
				SCHEMA_ONLY='';
				schema_flag='data';
				while read schema_db; do
					if [ "${db}" = "${schema_db}" ]; then
						SCHEMA_ONLY='-s';
						schema_flag='schema';
						# skip out
						break;
					fi;
				done<"${BASE_FOLDER}${SCHEMA_ONLY_FILE}";
			elif [ -s "${BASE_FOLDER}${DATA_ONLY_FILE}" ]; then
				# default to schema, unless in data list
				SCHEMA_ONLY='-s';
				schema_flag='schema';
				while read data_db; do
					if [ "${db}" = "${data_db}" ]; then
						SCHEMA_ONLY='';
						schema_flag='data';
						# skip out
						break;
					fi;
				done<"${BASE_FOLDER}${DATA_ONLY_FILE}";
			fi;
			# if nothing is set, default to data
			if [ -z "${schema_flag}" ]; then
				SCHEMA_ONLY=''
				schema_flag="data";
			fi;
			# Filename
			# Database.User.Encoding.pgsql|data|schema-Version_Host_Port_YearMonthDay_HourMinute_Counter.Fromat(c).sql
			FILENAME="${db}.${owner}.${encoding}.${schema_flag}-${DB_VERSION}_${DB_HOST}_${DB_PORT}.c.sql"
			# PER db either data or schema
			BACKUP_SET_PREFIX="${MODULE},${db}-";
			# backup set:
			BACKUP_SET_NAME="${ONE_TIME_TAG}${BACKUP_SET_PREFIX}${schema_flag}-${BACKUP_SET}";
			# borg call
			BORG_CALL=$(echo "${_BORG_CALL}" | sed -e "s/##FILENAME##/${FILENAME}/" | sed -e "s/##BACKUP_SET##/${BACKUP_SET_NAME}/");
			# borg prune
			BORG_PRUNE=$(echo "${_BORG_PRUNE}" | sed -e "s/##BACKUP_SET_PREFIX##/${BACKUP_SET_PREFIX}/");
			if [ ${DEBUG} -eq 1 ] || [ ${DRYRUN} -eq 1 ]; then
				echo "export BORG_BASE_DIR=\"${BASE_FOLDER}\";";
				echo "${PG_DUMP} -U ${DB_USER} ${CONN_DB_HOST} ${CONN_DB_PORT} -c ${SCHEMA_ONLY} --format=c ${db} | ${BORG_CALL}";
				if [ -z "${ONE_TIME_TAG}" ]; then
					echo "${BORG_PRUNE}";
				fi;
			fi;
			if [ ${DRYRUN} -eq 0 ]; then
				${PG_DUMP} -U ${DB_USER} ${CONN_DB_HOST} ${CONN_DB_PORT} -c ${SCHEMA_ONLY} --format=c ${db} | ${BORG_CALL};
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
