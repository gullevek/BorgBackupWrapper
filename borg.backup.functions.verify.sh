#!/usr/bin/env bash

# allow variables in printf format string
# shellcheck disable=SC2059

if [ -z "${MODULE}" ]; then
	echo "Script cannot be run on its own";
	exit 1;
fi;

# start time in seconds
START=$(date +'%s');
# set init date, or today if not file is set
BACKUP_INIT_DATE='';
if [ -f "${BASE_FOLDER}${BACKUP_INIT_FILE}" ]; then
	BACKUP_INIT_DATE=$(printf '%(%c)T' "$(cat "${BASE_FOLDER}${BACKUP_INIT_FILE}" 2>/dev/null)");
fi;
# start logging from here
exec &> >(tee -a "${LOG}");
printf "${PRINTF_MASTER_BLOCK}" "START" "$(date +'%F %T')" "${MODULE}";
# show info for version always
printf "${PRINTF_INFO_STRING}" "Script version" "${VERSION}";
# show type
printf "${PRINTF_INFO_STRING}" "Backup module" "${MODULE}";
printf "${PRINTF_INFO_STRING}" "Module version" "${MODULE_VERSION}";
# borg version
printf "${PRINTF_INFO_STRING}" "Borg version" "${BORG_VERSION}";
# host name
printf "${PRINTF_INFO_STRING}" "Hostname" "${HOSTNAME}";
# show base folder always
printf "${PRINTF_INFO_STRING}" "Base folder" "${BASE_FOLDER}";
# Module init date (when init file was writen)
printf "${PRINTF_INFO_STRING}" "Module init date" "${BACKUP_INIT_DATE}";
# print last compact date if positive integer
# only if borg > 1.2
if [ "$(version "$BORG_VERSION")" -ge "$(version "1.2.0")" ]; then
	if [ "${COMPACT_INTERVAL##*[!0-9]*}" ]; then
		printf "${PRINTF_INFO_STRING}" "Module compact interval" "${COMPACT_INTERVAL}";
		if [ -f "${BASE_FOLDER}${BACKUP_COMPACT_FILE}" ]; then
			LAST_COMPACT_DATE=$(cat "${BASE_FOLDER}${BACKUP_COMPACT_FILE}" 2>/dev/null);
			printf "${PRINTF_INFO_STRING}" "Module last compact" \
				"$(printf '%(%c)T' "${LAST_COMPACT_DATE}") ($(convert_time $(($(date +%s) - LAST_COMPACT_DATE))) ago)";
		else
			printf "${PRINTF_INFO_STRING}" "Module last compact" "No compact run yet"
		fi;
	fi;
fi;
# print last check date if positive integer
if [ "${CHECK_INTERVAL##*[!0-9]*}" ]; then
	printf "${PRINTF_INFO_STRING}" "Module check interval" "${CHECK_INTERVAL}";
	# get last check date
	if [ -f "${BASE_FOLDER}${BACKUP_CHECK_FILE}" ]; then
		LAST_CHECK_DATE=$(cat "${BASE_FOLDER}${BACKUP_CHECK_FILE}" 2>/dev/null);
		printf "${PRINTF_INFO_STRING}" "Module last check" \
			"$(printf '%(%c)T' "${LAST_CHECK_DATE}") ($(convert_time $(($(date +%s) - LAST_CHECK_DATE))) ago)";
	else
		printf "${PRINTF_INFO_STRING}" "Module last check" "No check run yet";
	fi;
fi;

# if force verify is true set VERIFY to 1 unless INFO is 1
# Needs bash 4.0 at lesat for this
if [ "${FORCE_VERIFY,,}" = "true" ] && [ "${INFO}" -eq 0 ]; then
	VERIFY=1;
	if [ "${DEBUG}" -eq 1 ]; then
		echo "Force repository verify";
	fi;
fi;

# remote borg path
if [ -n "${TARGET_BORG_PATH}" ]; then
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
if [ -n "${TARGET_USER}" ] && [ -n "${TARGET_HOST}" ] && [ -n "${TARGET_PORT}" ]; then
	TARGET_SERVER="ssh://${TARGET_USER}@${TARGET_HOST}:${TARGET_PORT}/";
# host/port
elif [ -n "${TARGET_HOST}" ] && [ -n "${TARGET_PORT}" ]; then
	TARGET_SERVER="ssh://${TARGET_HOST}:${TARGET_PORT}/";
# user/host
elif [ -n "${TARGET_USER}" ] && [ -n "${TARGET_HOST}" ]; then
	TARGET_SERVER="${TARGET_USER}@${TARGET_HOST}:";
# host
elif [ -n "${TARGET_HOST}" ]; then
	TARGET_SERVER="${TARGET_HOST}:";
fi;
# we dont allow special characters, so we don't need to special escape it
REPOSITORY="${TARGET_SERVER}${TARGET_FOLDER}${BACKUP_FILE}";
printf "${PRINTF_INFO_STRING}" "Repository" "${REPOSITORY}";

# check if given compression name and level are valid
OPT_COMPRESSION='';
if [ -n "${COMPRESSION}" ]; then
	# valid compression
	if [ "${COMPRESSION}" = "lz4" ] || [ "${COMPRESSION}" = "zlib" ] || [ "${COMPRESSION}" = "lzma" ] || [ "${COMPRESSION}" = "zstd" ]; then
		OPT_COMPRESSION="-C=${COMPRESSION}";
		# if COMPRESSION_LEVEL, check it is a valid regex
		# for zlib, zstd, lzma
		if [ -n "${COMPRESSION_LEVEL}" ] && { [ "${COMPRESSION}" = "zlib" ] || [ "${COMPRESSION}" = "lzma" ] || [ "${COMPRESSION}" = "zstd" ]; }; then
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
				echo "${error_message}";
				exit 1;
			elif [ "${COMPRESSION_LEVEL}" -lt "${MIN_COMPRESSION}" ] || [ "${COMPRESSION_LEVEL}" -gt "${MAX_COMPRESSION}" ]; then
				echo "${error_message}";
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

# keep optionfs (for files)
KEEP_OPTIONS=();
# keep info string (for files)
KEEP_INFO="";
# override standard keep for tagged backups
if [ -n "${ONE_TIME_TAG}" ]; then
	BACKUP_SET="{now:%Y-%m-%dT%H:%M:%S}";
	# set empty to avoid problems
	KEEP_OPTIONS=("");
else
	# build options and info string,
	# also flag BACKUP_SET check if hourly is set
	BACKUP_SET_VERIFY=0;
	if [ "${KEEP_LAST}" -gt 0 ]; then
		KEEP_OPTIONS+=("--keep-last=${KEEP_LAST}");
		KEEP_INFO="${KEEP_INFO}, last: ${KEEP_LAST}";
	fi;
	if [ "${KEEP_HOURS}" -gt 0 ]; then
		KEEP_OPTIONS+=("--keep-hourly=${KEEP_HOURS}");
		KEEP_INFO="${KEEP_INFO}, hourly: ${KEEP_HOURS}";
		BACKUP_SET_VERIFY=1;
	fi;
	if [ "${KEEP_DAYS}" -gt 0 ]; then
		KEEP_OPTIONS+=("--keep-daily=${KEEP_DAYS}");
		KEEP_INFO="${KEEP_INFO}, daily: ${KEEP_DAYS}";
	fi;
	if [ "${KEEP_WEEKS}" -gt 0 ]; then
		KEEP_OPTIONS+=("--keep-weekly=${KEEP_WEEKS}");
		KEEP_INFO="${KEEP_INFO}, weekly: ${KEEP_WEEKS}";
	fi;
	if [ "${KEEP_MONTHS}" -gt 0 ]; then
		KEEP_OPTIONS+=("--keep-monthly=${KEEP_MONTHS}");
		KEEP_INFO="${KEEP_INFO}, monthly: ${KEEP_MONTHS}";
	fi;
	if [ "${KEEP_YEARS}" -gt 0 ]; then
		KEEP_OPTIONS+=("--keep-yearly=${KEEP_YEARS}");
		KEEP_INFO="${KEEP_INFO}, yearly: ${KEEP_YEARS}";
	fi;
	if [ -n "${KEEP_WITHIN}" ]; then
		# check for invalid string. can only be number + H|d|w|m|y
		if [[ "${KEEP_WITHIN}" =~ ^[0-9]+[Hdwmy]{1}$ ]]; then
			KEEP_OPTIONS+=("--keep-within=${KEEP_WITHIN}");
			KEEP_INFO="${KEEP_INFO}, within: ${KEEP_WITHIN}";
			if [[ "${KEEP_WITHIN}" == *"H"* ]]; then
				BACKUP_SET_VERIFY=1;
			fi;
		else
			echo "[! $(date +'%F %T')] KEEP_WITHIN has invalid string.";
			exit 1;
		fi;
	fi;
	# abort if KEEP_OPTIONS is empty
	if [ "${#KEEP_OPTIONS[@]}" -eq "0" ]; then
		echo "[! $(date +'%F %T')] It seems no KEEP_* entries where set in a valid format.";
		exit 1;
	fi;
	# set BACKUP_SET if empty, set to Year-month-day
	if [ -z "${BACKUP_SET}" ]; then
		BACKUP_SET="{now:%Y-%m-%d}";
	fi;
	# backup set check, and there is no hour entry (%H) in the archive string
	# we add T%H:%M:%S in this case, before the last }
	if [ ${BACKUP_SET_VERIFY} -eq 1 ] && [[ "${BACKUP_SET}" != *"%H"* ]]; then
		BACKUP_SET=$(echo "${BACKUP_SET}" | sed -e "s/}/T%H:%M:%S}/");
	fi;
fi;

# check if we have lock file, check pid in lock file, if no matching pid found
# running remove lock file
if [ -f "${BASE_FOLDER}${BACKUP_LOCK_FILE}" ]; then
	LOCK_PID=$(cat "${BASE_FOLDER}${BACKUP_LOCK_FILE}" 2>/dev/null);
	# check if lock file pid has an active program attached to it
	if [ -f "/proc/${LOCK_PID}/cmdline" ]; then
		echo "Script is already running on PID: ${$}";
		. "${DIR}/borg.backup.functions.close.sh" 1;
		exit 1;
	else
		echo "[#] Clean up stale lock file for PID: ${LOCK_PID}";
		rm "${BASE_FOLDER}${BACKUP_LOCK_FILE}";
	fi;
fi;
echo "${$}" > "${BASE_FOLDER}${BACKUP_LOCK_FILE}";

# for folders list split set to "#" and keep the old setting as is
_IFS=${IFS};
IFS="#";
# turn off for non file
if [ "${MODULE}" != "file" ]; then
	IFS=${_IFS};
fi;

# borg call, replace ##...## parts during run
# used in all modules, except 'file'
_BORG_CALL="${BORG_COMMAND} create ${OPT_REMOTE} -v ${OPT_LIST} ${OPT_PROGRESS} ${OPT_COMPRESSION} -s --stdin-name ##FILENAME## ${REPOSITORY}::##BACKUP_SET## -";
_BORG_PRUNE="${BORG_COMMAND} prune ${OPT_REMOTE} -v --list ${OPT_PROGRESS} ${DRY_RUN_STATS} -P ##BACKUP_SET_PREFIX## ${KEEP_OPTIONS[*]} ${REPOSITORY}";

# general borg settings
# set base path to config directory to keep cache/config separated
export BORG_BASE_DIR="${BASE_FOLDER}";
# ignore non encrypted access
export BORG_UNKNOWN_UNENCRYPTED_REPO_ACCESS_IS_OK="${_BORG_UNKNOWN_UNENCRYPTED_REPO_ACCESS_IS_OK}";
# ignore moved repo access
export BORG_RELOCATED_REPO_ACCESS_IS_OK="${_BORG_RELOCATED_REPO_ACCESS_IS_OK}";
# and for debug print that tout
if [ "${DEBUG}" -eq 1 ]; then
	echo "export BORG_UNKNOWN_UNENCRYPTED_REPO_ACCESS_IS_OK=${_BORG_UNKNOWN_UNENCRYPTED_REPO_ACCESS_IS_OK};";
	echo "export BORG_RELOCATED_REPO_ACCESS_IS_OK=${_BORG_RELOCATED_REPO_ACCESS_IS_OK};";
	echo "export BORG_BASE_DIR=\"${BASE_FOLDER}\";";
fi;
# prepare debug commands only
COMMAND_EXPORT="export BORG_BASE_DIR=\"${BASE_FOLDER}\";"
COMMAND_INFO="${COMMAND_EXPORT}${BORG_COMMAND} info ${OPT_REMOTE} ${REPOSITORY}";
# if the is not there, call init to create it
# if this is user@host, we need to use ssh command to verify if the file is there
# else a normal verify is ok
# unless explicit given, verify is skipped
# MARK: VERIFY / INFO
if [ "${VERIFY}" -eq 1 ] || [ "${INIT}" -eq 1 ]; then
	printf "${PRINTF_SUB_BLOCK}" "VERIFY" "$(date +'%F %T')" "${MODULE}";
	if [ "${DEBUG}" -eq 1 ]; then
		echo "${BORG_COMMAND} info ${OPT_REMOTE} ${REPOSITORY} 2>&1	";
	fi;
	# use borg info and verify if it returns "Repository ID:" in the first line
	REPO_VERIFY=$(${BORG_COMMAND} info ${OPT_REMOTE} "${REPOSITORY}" 2>&1);
	__last_error=$?;
	# on any error in verify command force new INIT
	if [[ $__last_error -ne 0 ]]; then
		echo "[!] Repository verify error: ${REPO_VERIFY}";
		INIT_REPOSITORY=1;
	fi;
	# if verrify but no init and repo is there but init file is missing set it
	if [ "${VERIFY}" -eq 1 ] && [ "${INIT}" -eq 0 ] && [ "${INIT_REPOSITORY}" -eq 0 ] &&
		[ ! -f "${BASE_FOLDER}${BACKUP_INIT_FILE}" ]; then
		# write init file
		echo "[!] Add missing init verify file";
		date +%s > "${BASE_FOLDER}${BACKUP_INIT_FILE}";
	fi;
	# end if verified but repository is not here
	if [ "${VERIFY}" -eq 1 ] && [ "${INIT}" -eq 0 ] && [ "${INIT_REPOSITORY}" -eq 1 ]; then
		echo "[! $(date +'%F %T')] No repository. Please run with -I flag to initialze repository";
		. "${DIR}/borg.backup.functions.close.sh" 1;
		exit 1;
	fi;
	if [ "${EXIT}" -eq 1 ] && [ "${VERIFY}" -eq 1 ] && [ "${INIT}" -eq 0 ]; then
		echo "Repository exists";
		echo "For more information run:"
		echo "${COMMAND_INFO}";
		. "${DIR}/borg.backup.functions.close.sh";
		exit;
	fi;
fi;
# MARK: INIT
if [ "${INIT}" -eq 1 ] && [ "${INIT_REPOSITORY}" -eq 1 ]; then

	printf "${PRINTF_SUB_BLOCK}" "INIT" "$(date +'%F %T')" "${MODULE}";
	if [ "${DEBUG}" -eq 1 ] || [ "${DRYRUN}" -eq 1 ]; then
		echo "${BORG_COMMAND} init ${OPT_REMOTE} -e ${ENCRYPTION} ${OPT_VERBOSE} ${REPOSITORY}";
		echo "${BORG_COMMAND} key export ${REPOSITORY}";
		echo "${BORG_COMMAND} key export --paper ${REPOSITORY}";
	fi
	if [ "${DRYRUN}" -eq 0 ]; then
		# should trap and exit properly here
		${BORG_COMMAND} init ${OPT_REMOTE} -e "${ENCRYPTION}" ${OPT_VERBOSE} "${REPOSITORY}";
		# show the key file
		if [ "${ENCRYPTION}" = "keyfile" ]; then
			echo "--- [ENCRYPTION KEY] --[START]-------------------------------------------------->";
			echo "Store the key and password in a safe place";
			echo "export BORG_BASE_DIR=\"${BASE_FOLDER}\";borg key export [--paper] ${REPOSITORY}";
			echo "----[BORG KEY] -------------------------------->";
			${BORG_COMMAND} key export "${REPOSITORY}";
			echo "----[BORG KEY:paper] -------------------------->";
			${BORG_COMMAND} key export --paper "${REPOSITORY}";
			echo "--- [ENCRYPTION KEY] --[END  ]-------------------------------------------------->";
		fi;
		# write init file
		date +%s > "${BASE_FOLDER}${BACKUP_INIT_FILE}";
		echo "Repository initialized";
		echo "For more information run:"
		echo "${COMMAND_INFO}";
	fi
	. "${DIR}/borg.backup.functions.close.sh";
	# exit after init
	exit;
elif [ "${INIT}" -eq 1 ] && [ "${INIT_REPOSITORY}" -eq 0 ]; then
	echo "[!] ($(date +'%F %T')) Repository already initialized";
	echo "For more information run:"
	echo "${COMMAND_INFO}";
	. "${DIR}/borg.backup.functions.close.sh" 1;
	exit 1;
fi;

# verify for init file
if [ ! -f "${BASE_FOLDER}${BACKUP_INIT_FILE}" ]; then
	echo "[!] ($(date +'%F %T')) It seems the repository has never been initialized."
	echo "Please run -I to initialize or if already initialzed run with -C for init update."
	. "${DIR}/borg.backup.functions.close.sh" 1;
	exit 1;
fi;

# MARK: LIST / PRINT
# PRINT OUT current data, only do this if REPO exists
if [ "${PRINT}" -eq 1 ]; then
	printf "${PRINTF_SUB_BLOCK}" "PRINT" "$(date +'%F %T')" "${MODULE}";
	FORMAT="{archive:<45} {comment:6} {start} - {end} [{id}] ({username}@{hostname}){NL}"
	# show command on debug or dry run
	if [ "${DEBUG}" -eq 1 ] || [ "${DRYRUN}" -eq 1 ]; then
		echo "export BORG_BASE_DIR=\"${BASE_FOLDER}\";${BORG_COMMAND} list ${OPT_REMOTE} --format ${FORMAT} ${REPOSITORY}";
	fi;
	# run info command if not a dry drun
	if [ "${DRYRUN}" -eq 0 ]; then
		${BORG_COMMAND} list ${OPT_REMOTE} --format "${FORMAT}" "${REPOSITORY}" ;
	fi;
	if [ "${VERBOSE}" -eq 1 ]; then
		echo "";
		echo "Base command info:"
		echo "export BORG_BASE_DIR=\"${BASE_FOLDER}\";${BORG_COMMAND} [COMMAND] ${OPT_REMOTE} ${REPOSITORY}::[BACKUP] [PATH]";
		echo "Replace [COMMAND] with list for listing or extract for restoring backup data."
		echo "Replace [BACKUP] with archive name."
		echo "If no [PATH] is given then all files will be restored."
		echo "Before extracting -n (dry run) is recommended to use."
		echo "If archive size is needed the info command with archive name has to be used."
		echo "When listing files in an archive set (::SET) the --format command can be used."
		echo "Example: \"{mode} {user:6} {group:6} {size:8d} {csize:8d} {dsize:8d} {dcsize:8d} {mtime} {path}{extra} [{health}]{NL}\""
	else
		echo "export BORG_BASE_DIR=\"${BASE_FOLDER}\";${BORG_COMMAND} [COMMAND] ${OPT_REMOTE} [FORMAT] ${REPOSITORY}::[BACKUP] [PATH]";
	fi;
	. "${DIR}/borg.backup.functions.close.sh";
	exit;
fi;

# run borg compact command and exit
if [ "${COMPACT}" -eq 1 ]; then
	. "${DIR}/borg.backup.functions.compact.sh";
	. "${DIR}/borg.backup.functions.close.sh";
	exit;
fi;

# run borg check command and exit
if [ "${CHECK}" -eq 1 ]; then
	. "${DIR}/borg.backup.functions.check.sh";
	. "${DIR}/borg.backup.functions.close.sh";
	exit;
fi;

# DELETE ONE TIME TAG
if [ -n "${DELETE_ONE_TIME_TAG}" ]; then
	printf "${PRINTF_SUB_BLOCK}" "DELETE" "$(date +'%F %T')" "${MODULE}";
	# if a "*" is inside we don't do ONE archive, but globbing via -a option
	DELETE_ARCHIVE=""
	OPT_GLOB="";
	# this is more or less for debug only
	if [[ "${DELETE_ONE_TIME_TAG}" =~ $REGEX_GLOB ]]; then
		OPT_GLOB="-a '${DELETE_ONE_TIME_TAG}'"
	else
		DELETE_ARCHIVE="::"${DELETE_ONE_TIME_TAG};
	fi
	# if this is borg <1.2 OPT_LIST does not work
	if [ "$(version "$BORG_VERSION")" -lt "$(version "1.2.0")" ]; then
		OPT_LIST="";
	fi;
	# if exists, delete and exit
	# show command on debug or dry run
	if [ "${DEBUG}" -eq 1 ]; then
		echo "${BORG_COMMAND} delete ${OPT_REMOTE} ${OPT_LIST} -s ${OPT_GLOB} ${REPOSITORY}${DELETE_ARCHIVE}";
	fi;
	# run delete command if not a dry drun
	# NOTE seems to be glob is not working if wrapped into another variable
	if [[ "${DELETE_ONE_TIME_TAG}" =~ $REGEX_GLOB ]]; then
		${BORG_COMMAND} delete ${OPT_REMOTE} ${OPT_LIST} ${DRY_RUN_STATS} -a "${DELETE_ONE_TIME_TAG}" ${REPOSITORY};
	else
		${BORG_COMMAND} delete ${OPT_REMOTE} ${OPT_LIST} ${DRY_RUN_STATS} ${REPOSITORY}${DELETE_ARCHIVE};
	fi;
	# if not a dry run, compact repository after delete
	# not that compact only works on borg 1.2
	if [ "$(version "$BORG_VERSION")" -ge "$(version "1.2.0")" ]; then
		if [ "${DRYRUN}" -eq 0 ]; then
			${BORG_COMMAND} compact ${OPT_REMOTE} "${REPOSITORY}";
		fi;
		if [ "${DEBUG}" -eq 1 ]; then
			echo "${BORG_COMMAND} compact ${OPT_REMOTE} ${REPOSITORY}";
		fi;
	fi;
	. "${DIR}/borg.backup.functions.close.sh";
	exit;
fi;

# __END__
