#!/usr/bin/env bash

# Backup zabbix config and settings only

MODULE="zabbix"
MODULE_VERSION="1.0.0";

DIR="${BASH_SOURCE%/*}"
if [[ ! -d "$DIR" ]]; then DIR="$PWD"; fi
# init system
. "${DIR}/borg.backup.functions.init.sh";

# init check file
BACKUP_INIT_CHECK="borg.backup.zabbix.init";

# check valid data
. "${DIR}/borg.backup.functions.check.sh";
# if info print info and then abort run
. "${DIR}/borg.backup.functions.info.sh";

# /usr/local/scripts/zabbix/zabbix-dump
if [ -z "${ZABBIX_DUMP_BIN}" ]; then
	ZABBIX_DUMP_BIN="/usr/local/bin/zabbix-dump";
fi;
if [ ! -z "${ZABBIX_CONFIG}" ] && [ ! -f "${ZABBIX_CONFIG}" ]; then
	echo "[! $(date +'%F %T')] Cannot find zabbix config: ${ZABBIX_CONFIG}";
	exit;
fi;
if [ -f "${ZABBIX_CONFIG}" ]; then
	OPT_ZABBIX_CONFIG="-z ${ZABBIX_CONFIG}";
fi;
if [ "${ZABBIX_DATABASE}" = "psql" ]; then
	OPT_ZABBIX_DUMP="-C";
fi;
if [ "${ZABBIX_DATABASE}" != "psql" ] && [ "${ZABBIX_DATABASE}" != "mysql" ]; then
	echo "[! $(date +'%F %T')] Zabbix dump must have database set to either psql or mysql";
	exit 1;
fi;
if [ ! -f "${ZABBIX_DUMP}" ]; then
	echo "[! $(date +'%F %T')] Zabbix dump script could not be found: ${ZABBIX_DUMP}";
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
BACKUP_SET="zabbix-settings-${BACKUP_SET}";
BACKUP_SET_PREFIX="zabbix-settings-";

# borg call
BORG_CALL=$(echo "${_BORG_CALL}" | sed -e "s/##FILENAME##/${FILENAME}/" | sed -e "s|##REPOSITORY##|${REPOSITORY}|" | sed -e "s/##BACKUP_SET##/${BACKUP_SET}/");
BORG_PRUNE=$(echo "${_BORG_PRUNE}" | sed -e "s|##REPOSITORY##|${REPOSITORY}|" | sed -e "s/##BACKUP_SET_PREFIX##/${BACKUP_SET_PREFIX}/");
# if prefix is emtpy remote "-P"
if [ -z "${BACKUP_SET_PREFIX}" ]; then
	BORG_PRUNE=$(echo "${BORG_PRUNE}" | sed -e 's/-P //');
fi;

echo "--- [zabbix settings: $(date +'%F %T')] --[${MODULE}]------------------------------------>";
if [ ${DEBUG} -eq 1 ] || [ ${DRYRUN} -eq 1 ]; then
	echo "${ZABBIX_DUMP_BIN} -t ${ZABBIX_DATABASE} ${OPT_ZABBIX_UNKNOWN_TABLES} ${OPT_ZABBIX_DUMP} ${OPT_ZABBIX_CONFIG} -o - | ${BORG_CALL}"
	echo "${BORG_PRUNE}";
fi;
if [ ${DRYRUN} -eq 0 ]; then
	${ZABBIX_DUMP_BIN} -t ${ZABBIX_DATABASE} ${OPT_ZABBIX_UNKNOWN_TABLES} ${OPT_ZABBIX_DUMP} ${OPT_ZABBIX_CONFIG} -o - | ${BORG_CALL};
fi;
echo "Prune repository with keep${KEEP_INFO:1}";
${BORG_PRUNE};
