#!/usr/bin/env bash

if [ -z "${MODULE}" ]; then
	echo "Script cannot be run on its own";
	exit 1;
fi;

# E: inherit trap ERR
# T: DEBUG and RETURN traps are inherited
# u: unset variables ere error
set -ETu #-e -o pipefail
trap _catch ERR
trap _cleanup SIGINT SIGTERM

_cleanup() {
	# script cleanup here
	echo "Script abort: $? @LINE: $(caller)";
	# unset exported vars
	unset BORG_BASE_DIR BORG_UNKNOWN_UNENCRYPTED_REPO_ACCESS_IS_OK BORG_RELOCATED_REPO_ACCESS_IS_OK;
	# end trap
	trap - SIGINT SIGTERM
}
_catch() {
	local last_exit_code=$?;
	echo "Some part of the script failed with ERROR: $last_exit_code @COMMAND: '$BASH_COMMAND' @LINE: $(caller)" >&2;
}
# on exit unset any exported var
trap "unset BORG_BASE_DIR BORG_UNKNOWN_UNENCRYPTED_REPO_ACCESS_IS_OK BORG_RELOCATED_REPO_ACCESS_IS_OK" EXIT;
# for version compare
function version {
	echo "$@" | awk -F. '{ printf("%d%03d%03d%03d\n", $1,$2,$3,$4); }';
}

# version for all general files
VERSION="4.7.2";

# borg version and borg comamnd
BORG_VERSION="";
BORG_COMMAND="borg";
# default log folder if none are set in config or option
_LOG_FOLDER="/var/log/borg.backup/";
# log file name is set based on BACKUP_FILE, .log is added
LOG_FOLDER="";
# should be there on everything
TEMPDIR="/tmp/";
# HOSTNAME (as set on server)
HOSTNAME=$(hostname);
# creates borg backup based on the include/exclude files
# if base borg folder (backup files) does not exist, it will automatically init it
# base folder
BASE_FOLDER="/usr/local/scripts/borg/";
# base settings and init flag
SETTINGS_FILE="borg.backup.settings";
# include files
INCLUDE_FILE="";
EXCLUDE_FILE="";
# backup folder initialzed verify
BACKUP_INIT_FILE="";
BACKUP_INIT_DATE="";
# file with last compact date
BACKUP_COMPACT_FILE="";
# file with last check timestamp
BACKUP_CHECK_FILE="";
# one time backup prefix tag, if set will use <tag>.<prefix>-Y-M-DTh:m:s type backup prefix
ONE_TIME_TAG="";
DELETE_ONE_TIME_TAG="";
# check command prefix/glob
CHECK_PREFIX="";
# debug/verbose/other flags
VERBOSE=0;
LIST=0;
DEBUG=0;
DRYRUN=0;
INFO=0;
VERIFY=0;
CHECK=0;
CHECK_VERIFY_DATA=0;
COMPACT=0;
INIT=0;
EXIT=0;
PRINT=0;
# flags, set to no to disable
_BORG_UNKNOWN_UNENCRYPTED_REPO_ACCESS_IS_OK="yes";
_BORG_RELOCATED_REPO_ACCESS_IS_OK="yes";
# compatible settings
# NOTE: to keep the old .borg repository name for file module set this to true
# if set to false (future) it will add -file to the repository name like for other
# modules
FILE_REPOSITORY_COMPATIBLE="false";
# other variables
TARGET_SERVER="";
REGEX="";
REGEX_COMMENT="^[\ \t]*#";
REGEX_GLOB='\*';
REGEX_NUMERIC="^[0-9]{1,2}$";
REGEX_ERROR="^Some part of the script failed with ERROR:";
PRUNE_DEBUG="";
INIT_REPOSITORY=0;
FOLDER_OK=0;
TMP_EXCLUDE_FILE="";
# printf strings
PRINTF_INFO_STRING="%-23s: %s\n";
PRINTF_MASTER_BLOCK="=== [%-8s: %19s] ==[%s]====================================>\n";
PRINTF_SUB_BLOCK="|-- [%-8s: %19s] --[%s]------------------------------------>\n";
PRINTF_SUBEXT_BLOCK="|-- [%-8s: %s: %19s] --[%s]------------------------------------>\n";
PRINTF_DB_SUB_BLOCK="|>- [%-8s: %s] ==[%s]=======================>\n";
PRINTF_DB_RUN_TIME_SUB_BLOCK=">>- [%-8s: %s] ==[%s]==[Run time: %s]=======================>\n";
# opt flags
OPT_VERBOSE="";
OPT_PROGRESS="";
OPT_LIST="";
OPT_REMOTE="";
OPT_LOG_FOLDER="";
OPT_EXCLUDE="";
OPT_CHECK_VERIFY_DATA="";
# config variables (will be overwritten from .settings file)
TARGET_USER="";
TARGET_HOST="";
TARGET_PORT="";
TARGET_BORG_PATH="";
TARGET_FOLDER="";
BACKUP_FILE="";
SUB_BACKUP_FILE="";
# OPT is for options set
OPT_BORG_EXECUTEABLE="";
# which overrides BORG_EXECUTABLE that can be set in the settings file
BORG_EXECUTEABLE="";
# lz4, zstd 1-22 (3), zlib 0-9 (6), lzma 0-9 (6)
DEFAULT_COMPRESSION="zstd";
DEFAULT_COMPRESSION_LEVEL=3;
COMPRESSION="";
COMPRESSION_LEVEL="";
SUB_COMPRESSION="";
SUB_COMPRESSION_LEVEL="";
# encryption settings
DEFAULT_ENCRYPTION="keyfile";
ENCRYPTION="";
# force verify always
DEFAULT_FORCE_VERIFY="false";
FORCE_VERIFY="";
FORCE_CHECK=""; # Deprecated name, use FORCE_VERIFY
# compact
DEFAULT_COMPACT_INTERVAL="1";
LAST_COMPACT_DATE="";
COMPACT_INTERVAL="";
SUB_COMPACT_INTERVAL="";
# check
# default interval is none
DEFAULT_CHECK_INTERVAL="";
LAST_CHECK_DATE="";
CHECK_INTERVAL="";
SUB_CHECK_INTERVAL="";
# backup set names
BACKUP_SET="";
SUB_BACKUP_SET="";
# for database backup only
DATABASE_FULL_DUMP="";
DATABASE_USER="";
# only for mysql old config file
MYSQL_DB_CONFIG="";
MYSQL_DB_CONFIG_PARAM="";
# gitea module
GIT_USER="";
GITEA_WORKING_DIR="";
GITEA_TEMP_DIR="";
GITEA_BIN="";
GITEA_CONFIG="";
GITEA_EXPORT_TYPE="";
# zabbix module
ZABBIX_DUMP_BIN="";
ZABBIX_CONFIG="";
ZABBIX_DATABASE="";
ZABBIX_UNKNOWN_TABLES="";
ZABBIX_DB_PORT="";
OPT_ZABBIX_DUMP="";
OPT_ZABBIX_CONFIG="";
OPT_ZABBIX_UNKNOWN_TABLES="";
OPT_ZABBIX_DB_PORT="";
# default keep 7 days, 4 weeks, 6 months, 1 year
# if set 0, ignore/off
# note that for last/hourly it is needed to create a different
# BACKUP SET that includes hour and minute information
# IF BACKUP_SET is empty, this is automatically added
# general keep last, if only this is set only last n will be kept
DEFAULT_KEEP_LAST=0;
DEFAULT_KEEP_HOURS=0;
DEFAULT_KEEP_DAYS=7;
DEFAULT_KEEP_WEEKS=4;
DEFAULT_KEEP_MONTHS=6;
DEFAULT_KEEP_YEARS=1;
KEEP_LAST="";
KEEP_HOURS="";
KEEP_DAYS="";
KEEP_WEEKS="";
KEEP_MONTHS="";
KEEP_YEARS="";
# in the format of nY|M|d|h|m|s
KEEP_WITHIN="";
# sub override init to empty
SUB_KEEP_LAST="";
SUB_KEEP_HOURS="";
SUB_KEEP_DAYS="";
SUB_KEEP_WEEKS="";
SUB_KEEP_MONTHS="";
SUB_KEEP_YEARS="";
SUB_KEEP_WITHIN="";

function usage()
{
	cat <<- EOT
	Usage: ${0##/*/} [-c <config folder>] [-v] [-d]

	-c <config folder>: if this is not given, ${BASE_FOLDER} is used
	-L <log folder>: override config set and default log folder
	-T <tag>: create one time stand alone backup prefixed with tag name
	-D <tag backup set>: remove a tagged backup set, full name must be given
	-b <borg executable>: override default path
	-Z: run compress after prune/backup. Only for borg 1.2 or newer
	-C: run borg check if repository is ok
	-y: in combination with -C: add --verify-data
	-p <archive prefix|glob>: in combinatio with -C: only check archives with prefix or glob
	-P: print list of archives created
	-V: verify if repository exists, if not abort
	-e: exit after verify
	-I: init repository (must be run first)
	-i: print out only info
	-l: list files during backup
	-v: be verbose
	-d: debug output all commands
	-n: only do dry run
	-h: this help page

	Version       : ${VERSION}
	Module Version: ${MODULE_VERSION}
	Module        : ${MODULE}
	EOT
}

# set options
while getopts ":c:L:T:D:b:p:vldniCVeIPyZh" opt; do
	case "${opt}" in
		c|config)
			BASE_FOLDER=${OPTARG};
			;;
		L|Log)
			OPT_LOG_FOLDER=${OPTARG};
			;;
		T|Tag)
			ONE_TIME_TAG=${OPTARG};
			;;
		D|Delete)
			DELETE_ONE_TIME_TAG=${OPTARG};
			;;
		b|borg)
			OPT_BORG_EXECUTEABLE=${OPTARG};
			;;
		Z|Compact)
			# will run compact alone
			COMPACT=1;
			;;
		C|Check)
			# will run borg check
			# alt modes --repository-only, --archives-only,
			# add mode --verify-data
			# note that --repair has to be called manually is it might damange backups
			CHECK=1;
			;;
		y|Verify-Data)
			CHECK_VERIFY_DATA=1;
			;;
		p|prefix-glob)
			CHECK_PREFIX=${OPTARG};
			;;
		V|Verify)
			# will verify if repo is there and abort if not
			VERIFY=1;
			;;
		e|exit)
			# exit after verify or init (default off)
			EXIT=1;
			;;
		I|Init)
			# will check if there is a repo and init it
			# previoous this was default
			VERIFY=1;
			INIT=1;
			;;
		P|Print)
			# use borg list to print list of archves
			PRINT=1;
			;;
		v|verbose)
			VERBOSE=1;
			;;
		l|list)
			LIST=1;
			;;
		i|info)
			INFO=1;
			;;
		d|debug)
			DEBUG=1;
			;;
		n|dryrun)
			DRYRUN=1;
			;;
		h|help)
			usage;
			exit;
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

# add trailing slasd for base folder
[[ "${BASE_FOLDER}" != */ ]] && BASE_FOLDER=${BASE_FOLDER}"/";
# must have settings file there, if not, abort early
if [ ! -f "${BASE_FOLDER}${SETTINGS_FILE}" ]; then
	echo "No settings file could be found: ${BASE_FOLDER}${SETTINGS_FILE}";
	exit 1;
fi;
if [ ! -w "${BASE_FOLDER}" ]; then
	echo "Cannot write to BASE_FOLDER ${BASE_FOLDER}";
	echo "Is the group set to 'backup' and is this group allowed to write?"
	echo "If run as sudo, is this user in the 'backup' group?"
	echo "chgrp -R backup ${BASE_FOLDER}";
	echo "chmod -R g+rwX ${BASE_FOLDER}";
	echo "chmod g+s ${BASE_FOLDER}";
	exit 1;
fi;

# info -i && -C/-I cannot be run together
if [ ${VERIFY} -eq 1 ] || [ ${INIT} -eq 1 ] && [ ${INFO} -eq 1 ]; then
	echo "Cannot have -i info option and -V verify or -I initialize option at the same time";
	exit 1;
fi;
# print -P cannot be run with -i/-C/-I together
if [ ${PRINT} -eq 1 ] && { [ ${INIT} -eq 1 ] || [ ${VERIFY} -eq 1 ] || [ ${INFO} -eq 1 ]; }; then
	echo "Cannot have -P print option and -i info, -V verify or -I initizalize option at the same time";
	exit 1;
fi;
# if tag is set, you can't have init, verify, info, etc
if [ -n "${ONE_TIME_TAG}" ] && { [ ${PRINT} -eq 1 ] || [ ${INIT} -eq 1 ] || [ ${VERIFY} -eq 1 ] || [ ${INFO} -eq 1 ]; }; then
	echo "Cannot have -T '${ONE_TIME_TAG}' option with -i info, -V verify, -I initialize or -P print option at the same time";
	exit 1;
fi;
# verify only alphanumeric, no spaces, only underscore and dash
if [ -n "${ONE_TIME_TAG}" ] && ! [[ "${ONE_TIME_TAG}" =~ ^[A-Za-z0-9_-]+$ ]]; then
	echo "One time tag '${ONE_TIME_TAG}' must be alphanumeric with dashes and underscore only.";
	exit 1;
elif [ -n "${ONE_TIME_TAG}" ]; then
	# all ok, attach '.' at the end
	ONE_TIME_TAG=${ONE_TIME_TAG}".";
fi;
# if -D, cannot be with -T, -i, -C, -I, -P
if [ -n "${DELETE_ONE_TIME_TAG}" ] && { [ -n "${ONE_TIME_TAG}" ] || [ ${PRINT} -eq 1 ] || [ ${INIT} -eq 1 ] || [ ${VERIFY} -eq 1 ] || [ ${INFO} -eq 1 ]; }; then
	echo "Cannot have -D delete tag option with -T one time tag, -i info, -V verify, -I initialize or -P print option at the same time";
	exit 1;
fi;
# -D also must be in valid backup set format
# ! [[ "${DELETE_ONE_TIME_TAG}" =~ ^[A-Za-z0-9_-]+\.${MODULE},(\*-)?[0-9]{4}-[0-9]{2}-[0-9]{2}T\*$ ]]
if [ -n "${DELETE_ONE_TIME_TAG}" ] && ! [[ "${DELETE_ONE_TIME_TAG}" =~ ^[A-Za-z0-9_-]+\.${MODULE},([A-Za-z0-9_-]+-)?[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}$ ]] && ! [[ "${DELETE_ONE_TIME_TAG}" =~ ^[A-Za-z0-9_-]+\.${MODULE},(\*-)?[0-9]{4}-[0-9]{2}-[0-9]{2}T\*$ ]]; then
	echo "Delete one time tag '${DELETE_ONE_TIME_TAG}' is in an invalid format."
	echo "Please verify existing tags with -P option."
	echo "For a globing be sure it is in the format of: TAG.MODULE,*-YYYY-MM-DDT*";
	echo "Note the dash (-) after the first *, also time (T) is a globa (*) must."
	exit 1;
fi;
# -y can't be set without -C
if [ ${CHECK_VERIFY_DATA} -eq 1 ] && [ ${CHECK} -eq 0 ]; then
	echo "-y (verify-data) cannot be run without -C (Check) option";
	exit 1;
fi;
# -p can't be set without -C
if [ -n "${CHECK_PREFIX}" ] && [ ${CHECK} -eq 0 ]; then
	echo "-p (pattern|glob) for check cannot be run without -C (Check) options";
	exit 1;
fi;
# can't have -e if VERIFY or INIT is not set
if [ ${EXIT} -eq 1 ] && [ ${VERIFY} -eq 0 ] && [ ${INIT} -eq 0 ]; then
	echo "-e (exit) can only be used with -V (Verify) and -I (Init)";
	exit 1;
fi;

# verbose & progress
if [ ${VERBOSE} -eq 1 ]; then
	OPT_VERBOSE="-v";
	OPT_PROGRESS="-p";
fi;
# list files
if [ ${LIST} -eq 1 ]; then
	OPT_LIST="--list";
fi;
# If dry run, the stats (-s) option cannot be used
if [ ${DRYRUN} -eq 1 ]; then
	DRY_RUN_STATS="-n";
else
	DRY_RUN_STATS="-s";
fi;
if [ ${CHECK_VERIFY_DATA} -eq 1 ] && [ ${CHECK} -eq 1 ]; then
	OPT_CHECK_VERIFY_DATA="--verify-data";
fi;

# read config file
. "${BASE_FOLDER}${SETTINGS_FILE}";

# if OPTION SET overrides ALL others
if [ -n "${OPT_BORG_EXECUTEABLE}" ]; then
	BORG_COMMAND="${OPT_BORG_EXECUTEABLE}";
	if [ ! -f "${BORG_COMMAND}" ]; then
		echo "borg command not found with option -b: ${BORG_COMMAND}";
		exit;
	fi;
# if in setting file, use this
elif [ -n "${BORG_EXECUTEABLE}" ]; then
	BORG_COMMAND="${BORG_EXECUTEABLE}";
	if [ ! -f "${BORG_COMMAND}" ]; then
		echo "borg command not found with setting: ${BORG_COMMAND}";
		exit;
	fi;
elif ! command -v borg &> /dev/null; then
# elif [ -z ($command -v borg) ]; then
	echo "borg backup seems not to be installed, please verify paths";
	exit;
fi;
# verify that this is a borg executable, no detail check
_BORG_COMMAND_VERIFY=$(${BORG_COMMAND} -V | grep "borg");
if [[ "${_BORG_COMMAND_VERIFY}" =~ ${REGEX_ERROR} ]]; then
	echo "Cannot extract borg info from command, is this a valid borg executable?: ${BORG_COMMAND}";
	exit;
fi;
# extract actually borg version from here
# alt sed to get only numbes: sed -e 's/.* \([0-9]*\.[0-9]*\.[0-9]*\)$/\1/g'
# or use cut -d " " -f 2 and assume NO space in the first part
BORG_VERSION=$(${BORG_COMMAND} -V | sed -e 's/borg.* //') 2>&1 || echo "[!] Borg version not estable";

# load default settings for fileds not set
if [ -z "${COMPRESSION}" ]; then
	COMPRESSION="${DEFAULT_COMPRESSION}";
fi;
if [ -z "${COMPRESSION_LEVEL}" ]; then
	COMPRESSION_LEVEL="${DEFAULT_COMPRESSION_LEVEL}";
fi;
if [ -z "${ENCRYPTION}" ]; then
	ENCRYPTION="${DEFAULT_ENCRYPTION}";
fi;
# check interval override
if [ -z "${COMPACT_INTERVAL}" ]; then
	COMPACT_INTERVAL="${DEFAULT_COMPACT_INTERVAL}";
fi;
if [ -z "${CHECK_INTERVAL}" ]; then
	CHECK_INTERVAL="${DEFAULT_CHECK_INTERVAL}";
fi;
# deprecated name FORCE_CHECK, use FORCE_VERIFY instead
if [ -n "${FORCE_CHECK}" ]; then
	FORCE_VERIFY="${FORCE_CHECK}";
fi;
if [ -z "${FORCE_VERIFY}" ]; then
	FORCE_VERIFY="${DEFAULT_FORCE_VERIFY}";
fi;
if [ -z "${KEEP_LAST}" ]; then
	KEEP_LAST="${DEFAULT_KEEP_LAST}";
fi;
if [ -z "${KEEP_HOURS}" ]; then
	KEEP_HOURS="${DEFAULT_KEEP_HOURS}";
fi;
if [ -z "${KEEP_DAYS}" ]; then
	KEEP_DAYS="${DEFAULT_KEEP_DAYS}";
fi;
if [ -z "${KEEP_WEEKS}" ]; then
	KEEP_WEEKS="${DEFAULT_KEEP_WEEKS}";
fi;
if [ -z "${KEEP_MONTHS}" ]; then
	KEEP_MONTHS="${DEFAULT_KEEP_MONTHS}";
fi;
if [ -z "${KEEP_YEARS}" ]; then
	KEEP_YEARS="${DEFAULT_KEEP_YEARS}";
fi;
# ** SUB LOAD
# a settings file always end in .settings, replace that with lower case MODULE.settings
SETTINGS_FILE_SUB=$(echo "${SETTINGS_FILE}" | sed -e "s/\.settings/\.${MODULE,,}\.settings/");
# if mysql/pgsql run, load sub settings
if [ -f "${BASE_FOLDER}${SETTINGS_FILE_SUB}" ]; then
	. "${BASE_FOLDER}${SETTINGS_FILE_SUB}";
	# if SUB_ set override master
	if [ -n "${SUB_BACKUP_FILE}" ]; then
		BACKUP_FILE=${SUB_BACKUP_FILE}
	fi;
	# if sub backup set it set, override current
	if [ -n "${SUB_BACKUP_SET}" ]; then
		BACKUP_SET=${SUB_BACKUP_SET};
	fi;
	# ovrride compression
	if [ -n "${SUB_COMPRESSION}" ]; then
		COMPRESSION=${SUB_COMPRESSION};
	fi;
	if [ -n "${SUB_COMPRESSION_LEVEL}" ]; then
		COMPRESSION_LEVEL=${SUB_COMPRESSION_LEVEL};
	fi;
	# compact interval override
	if [ -n "${SUB_COMPACT_INTERVAL}" ]; then
		COMPACT_INTERVAL="${SUB_COMPACT_INTERVAL}";
	fi;
	# override check interval
	if [ -n "${SUB_CHECK_INTERVAL}" ]; then
		CHECK_INTERVAL="${SUB_CHECK_INTERVAL}";
	fi;
	# check override for keep time
	if [ -n "${SUB_KEEP_LAST}" ]; then
		KEEP_LAST=${SUB_KEEP_LAST};
	fi;
	if [ -n "${SUB_KEEP_HOURS}" ]; then
		KEEP_HOURS=${SUB_KEEP_HOURS};
	fi;
	if [ -n "${SUB_KEEP_DAYS}" ]; then
		KEEP_DAYS=${SUB_KEEP_DAYS};
	fi;
	if [ -n "${SUB_KEEP_WEEKS}" ]; then
		KEEP_WEEKS=${SUB_KEEP_WEEKS};
	fi;
	if [ -n "${SUB_KEEP_MONTHS}" ]; then
		KEEP_MONTHS=${SUB_KEEP_MONTHS};
	fi;
	if [ -n "${SUB_KEEP_YEARS}" ]; then
		KEEP_YEARS=${SUB_KEEP_YEARS};
	fi;
	if [ -n "${SUB_KEEP_WITHIN}" ]; then
		KEEP_WITHIN=${SUB_KEEP_WITHIN};
	fi;
fi;
# add module name to backup file, always
# except if FILE module and FILE_REPOSITORY_COMPATIBLE="true"
if [ "${FILE_REPOSITORY_COMPATIBLE}" != "true" ] || [ "${MODULE,,}" != "file" ]; then
	BACKUP_FILE=${BACKUP_FILE/.borg/-${MODULE,,}.borg};
fi;
# backup file must be set
if [ -z "${BACKUP_FILE}" ]; then
	echo "No BACKUP_FILE set";
	exit;
fi;
# backup file (folder) must end as .borg
# BACKUP FILE also cannot start with / or have / inside or start with ~
# valid file name check, alphanumeric, -,._ ...
if ! [[ "${BACKUP_FILE}" =~ ^[A-Za-z0-9,._-]+\.borg$ ]]; then
	echo "BACKUP_FILE ${BACKUP_FILE} can only contain A-Z a-z 0-9 , . _ - chracters and must end with .borg";
	exit 1;
fi;
# error if the repository file still has the default name
# This is just for old sets
REGEX="^some\-prefix\-";
if [[ "${BACKUP_FILE}" =~ ${REGEX} ]]; then
	echo "[DEPRECATED] The repository name still has the default prefix: ${BACKUP_FILE}";
	exit 1;
fi;

# check LOG_FOLDER, TARGET_BORG_PATH, TARGET_FOLDER must have no ~/ as start position
if [[ ${LOG_FOLDER} =~ ^~\/ ]]; then
	echo "LOG_FOLDER path cannot start with ~/. Path must be absolute: ${LOG_FOLDER}";
	exit 1;
fi;
if [[ ${TARGET_BORG_PATH} =~ ^~\/ ]]; then
	echo "TARGET_BORG_PATH path cannot start with ~/. Path must be absolute: ${TARGET_BORG_PATH}";
	exit 1;
fi;
if [[ ${TARGET_FOLDER} =~ ^~\/ ]]; then
	echo "TARGET_FOLDER path cannot start with ~/. Path must be absolute: ${TARGET_FOLDER}";
	exit 1;
fi

# COMPACT_INTERVAL must be a number from -1 to 365
# CHECK_INTERVAL must be a number from -1 to 365

# log file set and check
# option folder overrides all other folders
if [ -n "${OPT_LOG_FOLDER}" ]; then
	LOG_FOLDER="${OPT_LOG_FOLDER}";
fi;
# if empty folder set to default folder
if [ -z "${LOG_FOLDER}" ]; then
	LOG_FOLDER="${_LOG_FOLDER}";
fi;
# if folder does not exists create it
if [ ! -d "${LOG_FOLDER}" ]; then
	mkdir "${LOG_FOLDER}";
fi;
# set the output log folder
# LOG=$(printf "%q" "${LOG_FOLDER}/${BACKUP_FILE}.log");
LOG="${LOG_FOLDER}/${BACKUP_FILE}.log";
# fail if not writeable to folder or file
if [[ -f "${LOG}" && ! -w "${LOG}" ]] || [[ ! -f "${LOG}" && ! -w "${LOG_FOLDER}" ]]; then
	echo "Log folder or log file is not writeable: ${LOG}";
	echo "Is the group set to 'backup' and is this group allowed to write?"
	echo "If run as sudo, is this user in the 'backup' group?"
	echo "chgrp -R backup ${LOG}";
	echo "chmod -R g+rwX ${LOG}";
	echo "chmod g+s ${LOG}";
	exit 1;
fi;

# if ENCRYPTION is empty or not in the valid list fall back to none
# NOTE This is currently set in default and doesn't need to be set on empty
# only ivalid should be checked
if
	[ "${ENCRYPTION}" = "authenticated" ] ||
	[ "${ENCRYPTION}" = "repokey" ] ||
	[ "${ENCRYPTION}" = "authenticated-blake2" ] ||
	[ "${ENCRYPTION}" = "repokey-blake2" ] ;
then
	# if "authenticated" or "repokey" a password must be set
	if [[ ! -v BORG_PASSPHRASE ]] && [[ ! -v BORG_PASSCOMMAND ]] && [[ ! -v BORG_PASSPHRASE_FD ]]; then
		echo "Encryption method '${ENCRYPTION}' requires a BORG_PASSPHRASE, BORG_PASSCOMMAND or BORG_PASSPHRASE_FD to be set.";
		exit 1;
	fi;
elif [ "${ENCRYPTION}" = "keyfile" ] || [ "${ENCRYPTION}" = "keyfile-blake2" ]; then
	# if no password, set empty password
	if [[ ! -v BORG_PASSPHRASE ]] && [[ ! -v BORG_PASSCOMMAND ]] && [[ ! -v BORG_PASSPHRASE_FD ]]; then
		export BORG_PASSPHRASE="";
	fi;
elif [ "${ENCRYPTION}" != "none" ]; then
	echo "Encryption method '${ENCRYPTION}' is not valid.";
	exit 1;
fi;

## FUNCTIONS

# METHOD: convert_time
# PARAMS: timestamp in seconds or with milliseconds (nnnn.nnnn)
# RETURN: formated string with human readable time (d/h/m/s)
# CALL  : var=$(convert_time $timestamp);
# DESC  : converts a timestamp or a timestamp with float milliseconds
#         to a human readable format
#         output is in days/hours/minutes/seconds
function convert_time
{
	timestamp=${1};
	# round to four digits for ms
	timestamp=$(printf "%1.4f" "$timestamp");
	# get the ms part and remove any leading 0
	ms=$(echo "${timestamp}" | cut -d "." -f 2 | sed -e 's/^0*//');
	timestamp=$(echo "${timestamp}" | cut -d "." -f 1);
	timegroups=(86400 3600 60 1); # day, hour, min, sec
	timenames=("d" "h" "m" "s"); # day, hour, min, sec
	output=( );
	time_string=;
	for timeslice in "${timegroups[@]}"; do
		# floor for the division, push to output
		output[${#output[*]}]=$(awk "BEGIN {printf \"%d\", ${timestamp}/${timeslice}}");
		timestamp=$(awk "BEGIN {printf \"%d\", ${timestamp}%${timeslice}}");
	done;

	for ((i=0; i<${#output[@]}; i++)); do
		if [ "${output[$i]}" -gt 0 ] || [ -n "$time_string" ]; then
			if [ -n "${time_string}" ]; then
				time_string=${time_string}" ";
			fi;
			time_string=${time_string}${output[$i]}${timenames[$i]};
		fi;
	done;
	if [ -n "${ms}" ] && [ "${ms}" != "nan" ] && [ "${ms}" -gt 0 ]; then
		time_string="${time_string} ${ms}ms";
	fi;
	# just in case the time is 0
	if [ -z "${time_string}" ]; then
		time_string="0s";
	fi;
	echo -n "${time_string}";
}

# __END__
