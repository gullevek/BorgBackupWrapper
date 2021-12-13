#!/usr/bin/env bash

set -ETu #-e -o pipefail
trap cleanup SIGINT SIGTERM ERR

cleanup() {
	# script cleanup here
	echo "Some part of the script failed with an error: $? @LINE: $(caller)";
	# unset exported vars
	unset BORG_BASE_DIR BORG_UNKNOWN_UNENCRYPTED_REPO_ACCESS_IS_OK BORG_RELOCATED_REPO_ACCESS_IS_OK;
	# end trap
	trap - SIGINT SIGTERM ERR
}
# on exit unset any exported var
trap "unset BORG_BASE_DIR BORG_UNKNOWN_UNENCRYPTED_REPO_ACCESS_IS_OK BORG_RELOCATED_REPO_ACCESS_IS_OK" EXIT;

# version for all general files
VERSION="3.0.0";

# default log folder if none are set in config or option
_LOG_FOLDER="/var/log/borg.backup/";
# log file name is set based on BACKUP_FILE, .log is added
LOG_FOLDER="";
# should be there on everything
TEMPDIR="/tmp/";
# creates borg backup based on the include/exclude files
# if base borg folder (backup files) does not exist, it will automatically init it
# base folder
BASE_FOLDER="/usr/local/scripts/borg/";
# base settings and init flag
SETTINGS_FILE="borg.backup.settings";
# include files
INCLUDE_FILE="";
EXCLUDE_FILE="";
# backup folder initialzed check
BACKUP_INIT_CHECK="";
# debug/verbose
VERBOSE=0;
LIST=0;
DEBUG=0;
DRYRUN=0;
INFO=0;
CHECK=0;
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
FILE_REPOSITORY_COMPATIBLE="true";
# other variables
TARGET_SERVER="";
REGEX="";
REGEX_COMMENT="^[\ \t]*#";
REGEX_GLOB='\*';
REGEX_NUMERIC="^[0-9]{1,2}$";
PRUNE_DEBUG="";
INIT_REPOSITORY=0;
FOLDER_OK=0;
TMP_EXCLUDE_FILE="";
# opt flags
OPT_VERBOSE="";
OPT_PROGRESS="";
OPT_LIST="";
OPT_REMOTE="";
OPT_LOG_FOLDER="";
OPT_EXCLUDE="";
# config variables (will be overwritten from .settings file)
TARGET_USER="";
TARGET_HOST="";
TARGET_PORT="";
TARGET_BORG_PATH="";
TARGET_FOLDER="";
BACKUP_FILE="";
SUB_BACKUP_FILE="";
# lz4, zstd 1-22 (3), zlib 0-9 (6), lzma 0-9 (6)
COMPRESSION="zstd";
COMPRESSION_LEVEL=3;
SUB_COMPRESSION="";
SUB_COMPRESSION_LEVEL="";
# encryption settings
ENCRYPTION="none";
# force check always
FORCE_CHECK="false";
BACKUP_SET="";
SUB_BACKUP_SET="";
# for database backup only
DATABASE_FULL_DUMP="";
DATABASE_USER="";
# only for mysql old config file
MYSQL_DB_CONFIG="";
MYSQL_DB_CONFIG_PARAM="";
# default keep 7 days, 4 weeks, 6 months
# if set 0, ignore
# note that for last/hourly it is needed to create a different
# BACKUP SET that includes hour and minute information
# IF BACKUP_SET is empty, this is automatically added
# general keep last, if only this is set only last n will be kept
KEEP_LAST=0;
KEEP_HOURS=0;
KEEP_DAYS=7;
KEEP_WEEKS=4;
KEEP_MONTHS=6;
KEEP_YEARS=1;
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
	-P: print list of archives created
	-C: check if repository exists, if not abort
	-E: exit after check
	-I: init repository (must be run first)
	-v: be verbose
	-i: print out only info
	-l: list files during backup
	-d: debug output all commands
	-n: only do dry run
	-h: this help page

	Version       : ${VERSION}
	Module Version: ${MODULE_VERSION}
	Module        : ${MODULE}
	EOT
}

# set options
while getopts ":c:L:vldniCEIPh" opt; do
	case "${opt}" in
		c|config)
			BASE_FOLDER=${OPTARG};
			;;
		L|log)
			OPT_LOG_FOLDER=${OPTARG};
			;;
		C|Check)
			# will check if repo is there and abort if not
			CHECK=1;
			;;
		E|Exit)
			# exit after check
			EXIT=1;
			;;
		I|Init)
			# will check if there is a repo and init it
			# previoous this was default
			CHECK=1;
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
	echo "chgrp -R backup ${BASE_FOLDER}";
	echo "chmod -R g+rws ${BASE_FOLDER}";
	exit 1;
fi;

# info -i && -C/-I cannot be run together
if [ ${CHECK} -eq 1 ] || [ ${INIT} -eq 1 ] && [ ${INFO} -eq 1 ]; then
	echo "Cannot have -i info option and -C check or -I initialize option at the same time";
	exit 1;
fi;
# print -P cannot be run with -i/-C/-I together
if [ ${PRINT} -eq 1 ] || [ ${INIT} -eq 1 ] && [ ${CHECK} -eq 1 ] && [ ${INFO} -eq 1 ]; then
	echo "Cannot have -P print option and -i info, -C check or -I initizalize option at the same time";
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
if [ ${DRYRUN} -eq 1 ]; then
	PRUNE_DEBUG="--dry-run";
fi;

# read config file
. "${BASE_FOLDER}${SETTINGS_FILE}";
# ** SUB LOAD
# a settings file always end in .settings, replace that with lower case MODULE.settings
SETTINGS_FILE_SUB=$(echo "${SETTINGS_FILE}" | sed -e "s/\.settings/\.${MODULE,,}\.settings/");
# if mysql/pgsql run, load sub settings
if [ -f "${BASE_FOLDER}${SETTINGS_FILE_SUB}" ]; then
	. "${BASE_FOLDER}${SETTINGS_FILE_SUB}";
	# if SUB_ set override master
	if [ ! -z "${SUB_BACKUP_FILE}" ]; then
		BACKUP_FILE=${SUB_BACKUP_FILE}
	fi;
	# if sub backup set it set, override current
	if [ ! -z "${SUB_BACKUP_SET}" ]; then
		BACKUP_SET=${SUB_BACKUP_SET};
	fi;
	# ovrride compression
	if [ ! -z "${SUB_COMPRESSION}" ]; then
		COMPRESSION=${SUB_COMPRESSION};
	fi;
	if [ ! -z "${SUB_COMPRESSION_LEVEL}" ]; then
		COMPRESSION_LEVEL=${SUB_COMPRESSION_LEVEL};
	fi;
	# check override for keep time
	if [ ! -z "${SUB_KEEP_LAST}" ]; then
		KEEP_LAST=${SUB_KEEP_LAST};
	fi;
	if [ ! -z "${SUB_KEEP_HOURS}" ]; then
		KEEP_HOURS=${SUB_KEEP_HOURS};
	fi;
	if [ ! -z "${SUB_KEEP_DAYS}" ]; then
		KEEP_DAYS=${SUB_KEEP_DAYS};
	fi;
	if [ ! -z "${SUB_KEEP_WEEKS}" ]; then
		KEEP_WEEKS=${SUB_KEEP_WEEKS};
	fi;
	if [ ! -z "${SUB_KEEP_YEARS}" ]; then
		KEEP_YEARS=${SUB_KEEP_YEARS};
	fi;
	if [ ! -z "${SUB_KEEP_LAST}" ]; then
		KEEP_LAST=${SUB_KEEP_LAST};
	fi;
	if [ ! -z "${SUB_KEEP_WITHIN}" ]; then
		KEEP_WITHIN=${SUB_KEEP_WITHIN};
	fi;
fi;
# add module name to backup file, always
# except if FILE module and FILE_REPOSITORY_COMPATIBLE="true"
if ([ "${FILE_REPOSITORY_COMPATIBLE}" = "false" ] && [ "${MODULE,,}" = "file" ]) || [ "${MODULE,,}" != "file" ]; then
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

# log file set and check
# option folder overrides all other folders
if [ ! -z "${OPT_LOG_FOLDER}" ]; then
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
	echo "chgrp -R backup ${LOG}";
	echo "chmod -R g+rws ${LOG}";
	exit 1;
fi;

# if ENCRYPTION is empty or not in the valid list fall back to none
if [ -z "${ENCRYPTION}" ]; then
	ENCRYPTION="none";
#else
	# TODO check for invalid encryption string
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
	timestamp=$(printf "%1.4f" $timestamp);
	# get the ms part and remove any leading 0
	ms=$(echo ${timestamp} | cut -d "." -f 2 | sed -e 's/^0*//');
	timestamp=$(echo ${timestamp} | cut -d "." -f 1);
	timegroups=(86400 3600 60 1); # day, hour, min, sec
	timenames=("d" "h" "m" "s"); # day, hour, min, sec
	output=( );
	time_string=;
	for timeslice in ${timegroups[@]}; do
		# floor for the division, push to output
		output[${#output[*]}]=$(awk "BEGIN {printf \"%d\", ${timestamp}/${timeslice}}");
		timestamp=$(awk "BEGIN {printf \"%d\", ${timestamp}%${timeslice}}");
	done;

	for ((i=0; i<${#output[@]}; i++)); do
		if [ ${output[$i]} -gt 0 ] || [ ! -z "$time_string" ]; then
			if [ ! -z "${time_string}" ]; then
				time_string=${time_string}" ";
			fi;
			time_string=${time_string}${output[$i]}${timenames[$i]};
		fi;
	done;
	if [ ! -z ${ms} ] && [ ${ms} -gt 0 ]; then
		time_string=${time_string}" "${ms}"ms";
	fi;
	# just in case the time is 0
	if [ -z "${time_string}" ]; then
		time_string="0s";
	fi;
	echo -n "${time_string}";
}

# __END__
