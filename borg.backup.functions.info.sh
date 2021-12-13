#!/usr/bin/env bash

if [ ${INFO} -eq 1 ]; then
	echo "--- [INFO  : $(date +'%F %T')] ------------------------------------------->";
	# show command on debug or dry run
	if [ ${DEBUG} -eq 1 ] || [ ${DRYRUN} -eq 1 ]; then
		echo "export BORG_BASE_DIR=\"${BASE_FOLDER}\";borg info ${OPT_REMOTE} ${REPOSITORY}";
	fi;
	# run info command if not a dry drun
	if [ ${DRYRUN} -eq 0 ]; then
		borg info ${OPT_REMOTE} ${REPOSITORY};
	fi;
	if [ "${MODULE}" = "files" ]; then
		if [ $FOLDER_OK -eq 1 ]; then
			echo "--- [Run command]:";
			#IFS="#";
			echo "export BORG_BASE_DIR=\"${BASE_FOLDER}\";${COMMAND} "${FOLDERS_Q[*]};
		else
			echo "[!] No folders where set for the backup";
		fi;
		# remove the temporary exclude file if it exists
		if [ -f "${TMP_EXCLUDE_FILE}" ]; then
			rm -f "${TMP_EXCLUDE_FILE}";
		fi;
	fi;
	echo "=== [END  : $(date +'%F %T')] ==[${MODULE}]====================================>";
	exit;
fi;

# __END__
