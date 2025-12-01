#!/usr/bin/env bash

# allow variables in printf format string
# shellcheck disable=SC2059

# Backup zabbix config and settings only

MODULE="zabbix"
MODULE_VERSION="1.1.3";

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

# /usr/local/scripts/zabbix/zabbix-dump
if [ -z "${ZABBIX_DUMP_BIN}" ]; then
	ZABBIX_DUMP_BIN="/usr/local/bin/zabbix-dump";
fi;
if [ -n "${ZABBIX_CONFIG}" ] && [ ! -f "${ZABBIX_CONFIG}" ]; then
	echo "[! $(date +'%F %T')] Cannot find zabbix config: ${ZABBIX_CONFIG}";
	. "${DIR}/borg.backup.functions.close.sh" 1;
	exit 1;
fi;
if [ -f "${ZABBIX_CONFIG}" ]; then
	OPT_ZABBIX_CONFIG="-z ${ZABBIX_CONFIG}";
fi;
if [ "${ZABBIX_DATABASE}" = "psql" ]; then
	OPT_ZABBIX_DUMP="-C";
fi;
OPT_ZABBIX_DB_PORT="";
if [ -n "${ZABBIX_DB_PORT}" ]; then
	OPT_ZABBIX_DB_PORT="-P ${ZABBIX_DB_PORT}";
fi;
if [ "${ZABBIX_DATABASE}" != "psql" ] && [ "${ZABBIX_DATABASE}" != "mysql" ]; then
	echo "[! $(date +'%F %T')] Zabbix dump must have database set to either psql or mysql";
	. "${DIR}/borg.backup.functions.close.sh" 1;
	exit 1;
fi;
if [ ! -f "${ZABBIX_DUMP_BIN}" ]; then
	echo "[! $(date +'%F %T')] Zabbix dump script could not be found: ${ZABBIX_DUMP_BIN}";
	. "${DIR}/borg.backup.functions.close.sh" 1;
	exit 1;
fi;
# -i (ignore)/ -f (backup)
if [ ! -z "${ZABBIX_UNKNOWN_TABLES}" ]; then
	OPT_ZABBIX_UNKNOWN_TABLES="-f";
else
	OPT_ZABBIX_UNKNOWN_TABLES="-i";
fi;

# Filename
FILENAME="zabbix-config.c.sql";
# backup set:
BACKUP_SET_PREFIX="${MODULE},settings-";
BACKUP_SET_NAME="${ONE_TIME_TAG}${BACKUP_SET_PREFIX}${BACKUP_SET}";

# borg call
BORG_CALL=$(echo "${_BORG_CALL}" | sed -e "s/##FILENAME##/${FILENAME}/" | sed -e "s/##BACKUP_SET##/${BACKUP_SET_NAME}/");
BORG_PRUNE=$(echo "${_BORG_PRUNE}" | sed -e "s/##BACKUP_SET_PREFIX##/${BACKUP_SET_PREFIX}/");
# if prefix is emtpy remote "-P"
if [ -z "${BACKUP_SET_PREFIX}" ]; then
	BORG_PRUNE=$(echo "${BORG_PRUNE}" | sed -e 's/-P //');
fi;

printf "${PRINTF_SUB_BLOCK}" "BACKUP: zabbix settings" "$(date +'%F %T')" "${MODULE}";
if [ ${DEBUG} -eq 1 ] || [ ${DRYRUN} -eq 1 ]; then
	echo "${ZABBIX_DUMP_BIN} ${OPT_ZABBIX_DB_PORT} -t ${ZABBIX_DATABASE} ${OPT_ZABBIX_UNKNOWN_TABLES} ${OPT_ZABBIX_DUMP} ${OPT_ZABBIX_CONFIG} -o - | ${BORG_CALL}"
	if [ -z "${ONE_TIME_TAG}" ]; then
		echo "${BORG_PRUNE}";
	fi;
fi;
if [ ${DRYRUN} -eq 0 ]; then
	${ZABBIX_DUMP_BIN} ${OPT_ZABBIX_DB_PORT} -t ${ZABBIX_DATABASE} ${OPT_ZABBIX_UNKNOWN_TABLES} ${OPT_ZABBIX_DUMP} ${OPT_ZABBIX_CONFIG} -o - | ${BORG_CALL};
fi;
if [ -z "${ONE_TIME_TAG}" ]; then
	printf "${PRINTF_SUB_BLOCK}" "PRUNE" "$(date +'%F %T')" "${MODULE}";
	${BORG_PRUNE};
	# if this is borg version >1.2 we need to run compact after prune
	. "${DIR}/borg.backup.functions.compact.sh" "auto";
	# check in auto mode
	. "${DIR}/borg.backup.functions.check.sh" "auto";
fi;

. "${DIR}/borg.backup.functions.close.sh";

# __EMD__
