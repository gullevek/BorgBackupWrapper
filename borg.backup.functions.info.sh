#!/usr/bin/env bash

# allow variables in printf format string
# shellcheck disable=SC2059

if [ -z "${MODULE}" ]; then
	echo "Script cannot be run on its own";
	exit 1;
fi;

if [ "${INFO}" -eq 1 ]; then
	printf "${PRINTF_SUB_BLOCK}" "INFO" "$(date +'%F %T')" "${MODULE}";
	# show command on debug or dry run
	if [ "${DEBUG}" -eq 1 ] || [ "${DRYRUN}" -eq 1 ]; then
		echo "export BORG_BASE_DIR=\"${BASE_FOLDER}\";${BORG_COMMAND} info ${OPT_REMOTE} ${REPOSITORY}";
	fi;
	# run info command if not a dry drun
	if [ "${DRYRUN}" -eq 0 ]; then
		${BORG_COMMAND} info ${OPT_REMOTE} "${REPOSITORY}";
		if [ "${VERBOSE}" -eq 1 ]; then
			# print key information
			echo "------------------------------------------------------------------------------";
			${BORG_COMMAND} key export "${REPOSITORY}";
		fi;
	fi;
	if [ "${MODULE}" = "files" ]; then
		if [ "${FOLDER_OK}" -eq 1 ]; then
			echo "--- [Run command]:";
			#IFS="#";
			echo "export BORG_BASE_DIR=\"${BASE_FOLDER}\";${COMMAND} ${FOLDERS_Q[*]}";
		else
			echo "[!] No folders where set for the backup";
		fi;
		# remove the temporary exclude file if it exists
		if [ -f "${TMP_EXCLUDE_FILE}" ]; then
			rm -f "${TMP_EXCLUDE_FILE}";
		fi;
	fi;
	. "${DIR}/borg.backup.functions.close.sh";
	exit;
fi;

# __END__
