#!/usr/bin/env bash

# start time in seconds
START=$(date +'%s');
# start logging from here
exec &> >(tee -a "${LOG}");
echo "=== [START : $(date +'%F %T')] ==[${MODULE}]====================================>";
# show info for version always
echo "Script version: ${VERSION}";
# show type
echo "Backup module : ${MODULE}";
echo "Module version: ${MODULE_VERSION}";
# show base folder always
echo "Base folder   : ${BASE_FOLDER}";

# if force check is true set CHECK to 1unless INFO is 1
# Needs bash 4.0 at lesat for this
if [ "${FORCE_CHECK,,}" = "true" ] && [ ${INFO} -eq 0 ]; then
	CHECK=1;
	if [ ${DEBUG} -eq 1 ]; then
		echo "Force repository check";
	fi;
fi;

# remote borg path
if [ ! -z "${TARGET_BORG_PATH}" ]; then
	if [[ "${TARGET_BORG_PATH}" =~ \ |\' ]]; then
		echo "Space found in ${TARGET_BORG_PATH}. Aborting";
		echo "There are issues with passing on paths with spaces"
		echo "as parameters"
		exit;
	fi;
	OPT_REMOTE="--remote-path="$(printf "%q" "${TARGET_BORG_PATH}");
fi;

if [ -z "${TARGET_FOLDER}" ]; then
	echo "[! $(date +'%F %T')] No target folder has been set yet";
	exit 1;
else
	# There are big issues with TARGET FOLDERS with spaces
	# we should abort anything with this
	if [[ "${TARGET_FOLDER}" =~ \ |\' ]]; then
		echo "Space found in ${TARGET_FOLDER}. Aborting";
		echo "There is some problem with passing paths with spaces as";
		echo "repository base folder"
		exit;
	fi;

	# This does not care for multiple trailing or leading slashes
	# it just makes sure we have at least one set
	# for if we have a single slash, remove it
	TARGET_FOLDER=${TARGET_FOLDER%/}
	TARGET_FOLDER=${TARGET_FOLDER#/}
	# and add slash front and back and escape the path
	TARGET_FOLDER=$(printf "%q" "/${TARGET_FOLDER}/");
fi;

# if we have user/host then we build the ssh command
TARGET_SERVER='';
# allow host only (if full setup in .ssh/config)
# user@host OR ssh://user@host:port/ IF TARGET_PORT is set
# user/host/port
if [ ! -z "${TARGET_USER}" ] && [ ! -z "${TARGET_HOST}" ] && [ ! -z "${TARGET_PORT}" ]; then
	TARGET_SERVER="ssh://${TARGET_USER}@${TARGET_HOST}:${TARGET_PORT}/";
# host/port
elif [ ! -z "${TARGET_HOST}" ] && [ ! -z "${TARGET_PORT}" ]; then
	TARGET_SERVER="ssh://${TARGET_HOST}:${TARGET_PORT}/";
# user/host
elif [ ! -z "${TARGET_USER}" ] && [ ! -z "${TARGET_HOST}" ]; then
	TARGET_SERVER="${TARGET_USER}@${TARGET_HOST}:";
# host
elif [ ! -z "${TARGET_HOST}" ]; then
	TARGET_SERVER="${TARGET_HOST}:";
fi;
# we dont allow special characters, so we don't need to special escape it
REPOSITORY="${TARGET_SERVER}${TARGET_FOLDER}${BACKUP_FILE}";
echo "Repository    : ${REPOSITORY}";

# check compression if given is valid and check compression level is valid if given
if [ ! -z "${COMPRESSION}" ]; then
	# valid compression
	if [ "${COMPRESSION}" = "lz4" ] || [ "${COMPRESSION}" = "zlib" ] || [ "${COMPRESSION}" = "lzma" ] || [ "${COMPRESSION}" = "zstd" ]; then
		OPT_COMPRESSION="-C=${COMPRESSION}";
		# if COMPRESSION_LEVEL, check it is a valid regex
		# for zlib, zstd, lzma
		if [ ! -z "${COMPRESSION_LEVEL}" ] && ([ "${COMPRESSION}" = "zlib" ] || [ "${COMPRESSION}" = "lzma" ] || [ "${COMPRESSION}" = "zstd" ]); then
			MIN_COMPRESSION=0;
			MAX_COMPRESSION=0;
			case "${COMPRESSION}" in
				zlib|lzma)
					MIN_COMPRESSION=0;
					MAX_COMPRESSION=9;
					;;
				zstd)
					MIN_COMPRESSION=1;
					MAX_COMPRESSION=22;
					;;
				*)
					MIN_COMPRESSION=0;
					MAX_COMPRESSION=0;
					;;
			esac;
			# if [ "${COMPRESSION}" = "zlib" ] || [ "${COMPRESSION}" = "lzma" ]
			# 	MIN_COMPRESSION=0;
			# 	MAX_COMPRESSION=9;
			# elif [ "${COMPRESSION}" = "zstd" ]; then
			# 	MIN_COMPRESSION=1;
			# 	MAX_COMPRESSION=22;
			# fi;
			error_message="[! $(date +'%F %T')] Compression level for ${COMPRESSION} needs to be a numeric value between ${MIN_COMPRESSION} and ${MAX_COMPRESSION}: ${COMPRESSION_LEVEL}";
			if ! [[ "${COMPRESSION_LEVEL}" =~ ${REGEX_NUMERIC} ]]; then
				echo ${error_message};
				exit 1;
			elif [ ${COMPRESSION_LEVEL} -lt ${MIN_COMPRESSION} ] || [ ${COMPRESSION_LEVEL} -gt ${MAX_COMPRESSION} ]; then
				echo ${error_message};
				exit 1;
			else
				OPT_COMPRESSION=${OPT_COMPRESSION}","${COMPRESSION_LEVEL};
			fi;
		fi;
	else
		echo "[! $(date +'%F %T')] Compress setting need to be lz4, zstd, zlib or lzma. Or empty for no compression: ${COMPRESSION}";
		exit 1;
	fi;
fi;

# home folder, needs to be set if there is eg a HOME=/ in the crontab
if [ ! -w "${HOME}" ] || [ "${HOME}" = '/' ]; then
	HOME=$(eval echo "$(whoami)");
fi;

# build options and info string,
# also flag BACKUP_SET check if hourly is set
KEEP_OPTIONS=();
KEEP_INFO="";
BACKUP_SET_CHECK=0;
if [ ${KEEP_LAST} -gt 0 ]; then
	KEEP_OPTIONS+=("--keep-last=${KEEP_LAST}");
	KEEP_INFO="${KEEP_INFO}, last: ${KEEP_LAST}";
fi;
if [ ${KEEP_HOURS} -gt 0 ]; then
	KEEP_OPTIONS+=("--keep-hourly=${KEEP_HOURS}");
	KEEP_INFO="${KEEP_INFO}, hourly: ${KEEP_HOURS}";
	BACKUP_SET_CHECK=1;
fi;
if [ ${KEEP_DAYS} -gt 0 ]; then
	KEEP_OPTIONS+=("--keep-daily=${KEEP_DAYS}");
	KEEP_INFO="${KEEP_INFO}, daily: ${KEEP_DAYS}";
fi;
if [ ${KEEP_WEEKS} -gt 0 ]; then
	KEEP_OPTIONS+=("--keep-weekly=${KEEP_WEEKS}");
	KEEP_INFO="${KEEP_INFO}, weekly: ${KEEP_WEEKS}";
fi;
if [ ${KEEP_MONTHS} -gt 0 ]; then
	KEEP_OPTIONS+=("--keep-monthly=${KEEP_MONTHS}");
	KEEP_INFO="${KEEP_INFO}, monthly: ${KEEP_MONTHS}";
fi;
if [ ${KEEP_YEARS} -gt 0 ]; then
	KEEP_OPTIONS+=("--keep-yearly=${KEEP_YEARS}");
	KEEP_INFO="${KEEP_INFO}, yearly: ${KEEP_YEARS}";
fi;
if [ ! -z "${KEEP_WITHIN}" ]; then
	# check for invalid string. can only be number + H|d|w|m|y
	if [[ "${KEEP_WITHIN}" =~ ^[0-9]+[Hdwmy]{1}$ ]]; then
		KEEP_OPTIONS+=("--keep-within=${KEEP_WITHIN}");
		KEEP_INFO="${KEEP_INFO}, within: ${KEEP_WITHIN}";
		if [[ "${KEEP_WITHIN}" == *"H"* ]]; then
			BACKUP_SET_CHECK=1;
		fi;
	else
		echo "[! $(date +'%F %T')] KEEP_WITHIN has invalid string.";
		exit 1;
	fi;
fi;
# abort if KEEP_OPTIONS is empty
if [ -z "${KEEP_OPTIONS}" ]; then
	echo "[! $(date +'%F %T')] It seems no KEEP_* entries where set in a valid format.";
	exit 1;
fi;
# set BACKUP_SET if empty, set to Year-month-day
if [ -z "${BACKUP_SET}" ]; then
	BACKUP_SET="{now:%Y-%m-%d}";
fi;
# backup set check, and there is no hour entry (%H) in the archive string
# we add T%H:%M:%S in this case, before the last }
if [ ${BACKUP_SET_CHECK} -eq 1 ] && [[ "${BACKUP_SET}" != *"%H"* ]]; then
	BACKUP_SET=$(echo "${BACKUP_SET}" | sed -e "s/}/T%H:%M:%S}/");
fi;

# for folders list split set to "#" and keep the old setting as is
_IFS=${IFS};
IFS="#";
# turn off for non file
if [ "${MODULE}" != "file" ]; then
	IFS=${_IFS};
fi;
# general borg settings
# set base path to config directory to keep cache/config separated
export BORG_BASE_DIR="${BASE_FOLDER}";
# ignore non encrypted access
export BORG_UNKNOWN_UNENCRYPTED_REPO_ACCESS_IS_OK=${_BORG_UNKNOWN_UNENCRYPTED_REPO_ACCESS_IS_OK};
# ignore moved repo access
export BORG_RELOCATED_REPO_ACCESS_IS_OK=${_BORG_RELOCATED_REPO_ACCESS_IS_OK};
# and for debug print that tout
if [ ${DEBUG} -eq 1 ]; then
	echo "export BORG_UNKNOWN_UNENCRYPTED_REPO_ACCESS_IS_OK=${_BORG_UNKNOWN_UNENCRYPTED_REPO_ACCESS_IS_OK};";
	echo "export BORG_RELOCATED_REPO_ACCESS_IS_OK=${_BORG_RELOCATED_REPO_ACCESS_IS_OK};";
	echo "export BORG_BASE_DIR=\"${BASE_FOLDER}\";";
fi;
# prepare debug commands only
COMMAND_EXPORT="export BORG_BASE_DIR=\"${BASE_FOLDER}\";"
COMMAND_INFO="${COMMAND_EXPORT}borg info ${OPT_REMOTE} ${REPOSITORY}";
# if the is not there, call init to create it
# if this is user@host, we need to use ssh command to check if the file is there
# else a normal check is ok
# unless explicit given, check is skipped
if [ ${CHECK} -eq 1 ] || [ ${INIT} -eq 1 ]; then
	echo "--- [CHECK : $(date +'%F %T')] --[${MODULE}]------------------------------------>";
	if [ ! -z "${TARGET_SERVER}" ]; then
		if [ ${DEBUG} -eq 1 ]; then
			echo "borg info ${OPT_REMOTE} ${REPOSITORY} 2>&1|grep \"Repository ID:\"";
		fi;
		# use borg info and check if it returns "Repository ID:" in the first line
		REPO_CHECK=$(borg info ${OPT_REMOTE} ${REPOSITORY} 2>&1|grep "Repository ID:");
		# this is currently a hack to work round the error code in borg info
		# this checks if REPO_CHECK holds this error message and then starts init
		regex="^Some part of the script failed with an error:";
		if [[ -z "${REPO_CHECK}" ]] || [[ "${REPO_CHECK}" =~ ${regex} ]]; then
			INIT_REPOSITORY=1;
		fi;
	elif [ ! -d "${REPOSITORY}" ]; then
		INIT_REPOSITORY=1;
	fi;
	# if check but no init and repo is there but init file is missing set it
	if [ ${CHECK} -eq 1 ] && [ ${INIT} -eq 0 ] && [ ${INIT_REPOSITORY} -eq 0 ] &&
		[ ! -f "${BASE_FOLDER}${BACKUP_INIT_CHECK}" ]; then
		# write init file
		echo "[!] Add missing init check file";
		echo "$(date +%s)" > "${BASE_FOLDER}${BACKUP_INIT_CHECK}";
	fi;
	# end if checked but repository is not here
	if [ ${CHECK} -eq 1 ] && [ ${INIT} -eq 0 ] && [ ${INIT_REPOSITORY} -eq 1 ]; then
		echo "[! $(date +'%F %T')] No repository. Please run with -I flag to initialze repository";
		exit 1;
	fi;
	if [ ${EXIT} -eq 1 ] && [ ${CHECK} -eq 1 ] && [ ${INIT} -eq 0 ]; then
		echo "Repository exists";
		echo "For more information run:"
		echo "${COMMAND_INFO}";
		echo "=== [END  : $(date +'%F %T')] ==[${MODULE}]====================================>";
		exit;
	fi;
fi;
if [ ${INIT} -eq 1 ] && [ ${INIT_REPOSITORY} -eq 1 ]; then
	echo "--- [INIT  : $(date +'%F %T')] --[${MODULE}]------------------------------------>";
	if [ ${DEBUG} -eq 1 ] || [ ${DRYRUN} -eq 1 ]; then
		echo "borg init ${OPT_REMOTE} -e ${ENCRYPTION} ${OPT_VERBOSE} ${REPOSITORY}";
	fi
	if [ ${DRYRUN} -eq 0 ]; then
		# should trap and exit properly here
		borg init ${OPT_REMOTE} -e ${ENCRYPTION} ${OPT_VERBOSE} ${REPOSITORY};
		# write init file
		echo "$(date +%s)" > "${BASE_FOLDER}${BACKUP_INIT_CHECK}";
		echo "Repository initialized";
		echo "For more information run:"
		echo "${COMMAND_INFO}";
	fi
	echo "=== [END  : $(date +'%F %T')] ==[${MODULE}]====================================>";
	# exit after init
	exit;
elif [ ${INIT} -eq 1 ] && [ ${INIT_REPOSITORY} -eq 0 ]; then
	echo "[! $(date +'%F %T')] Repository already initialized";
	echo "For more information run:"
	echo "${COMMAND_INFO}";
	exit 1;
fi;

# check for init file
if [ ! -f "${BASE_FOLDER}${BACKUP_INIT_CHECK}" ]; then
	echo "[! $(date +'%F %T')] It seems the repository has never been initialized."
	echo "Please run -I to initialize or if already initialzed run with -C for init update."
	exit 1;
fi;

# PRINT OUT current data, only do this if REPO exists
if [ ${PRINT} -eq 1 ]; then
	echo "--- [PRINT : $(date +'%F %T')] --[${MODULE}]------------------------------------>";
	FORMAT="{archive} {comment:6} {start} - {end} [{id}] ({username}@{hostname}){NL}"
	# show command on debug or dry run
	if [ ${DEBUG} -eq 1 ] || [ ${DRYRUN} -eq 1 ]; then
		echo "export BORG_BASE_DIR=\"${BASE_FOLDER}\";borg list ${OPT_REMOTE} --format ${FORMAT} ${REPOSITORY}";
	fi;
	# run info command if not a dry drun
	if [ ${DRYRUN} -eq 0 ]; then
		borg list ${OPT_REMOTE} --format "${FORMAT}" ${REPOSITORY} ;
	fi;
	if [ ${VERBOSE} -eq 1 ]; then
		echo "";
		echo "Base command info:"
		echo "export BORG_BASE_DIR=\"${BASE_FOLDER}\";borg [COMMAND] ${OPT_REMOTE} ${REPOSITORY}::[BACKUP] [PATH]";
		echo "Replace [COMMAND] with list for listing or extract for restoring backup data."
		echo "Replace [BACKUP] with archive name."
		echo "If no [PATH] is given then all files will be restored."
		echo "Before extracting -n (dry run) is recommended to use."
		echo "If archive size is needed the info command with archive name has to be used."
		echo "When listing (list) data the --format command can be used."
		echo "Example: \"{mode} {user:6} {group:6} {size:8d} {csize:8d} {dsize:8d} {dcsize:8d} {mtime} {path}{extra} [{health}]{NL}\""
	else
		echo "export BORG_BASE_DIR=\"${BASE_FOLDER}\";borg [COMMAND] ${OPT_REMOTE} [FORMAT] ${REPOSITORY}::[BACKUP] [PATH]";
	fi;
	exit;
fi;

# __END__
