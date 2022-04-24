#!/usr/bin/env bash

if [ -z "${MODULE}" ]; then
	echo "Script cannot be run on its own";
	exit 1;
fi;

# unset borg settings
unset BORG_BASE_DIR BORG_UNKNOWN_UNENCRYPTED_REPO_ACCESS_IS_OK BORG_RELOCATED_REPO_ACCESS_IS_OK
# error abort without duration and error notice
if [ $# -ge 1 ] && [ "$1" = "1" ]; then
	printf "${PRINTF_MASTER_BLOCK}" "ERROR" "$(date +'%F %T')" "${MODULE}";
else
	# delete lock file
	if [ -f "${BASE_FOLDER}${BACKUP_LOCK_FILE}" ]; then
		rm "${BASE_FOLDER}${BACKUP_LOCK_FILE}";
	fi;
	# running time calculation
	DURATION=$[ $(date +'%s')-$START ];
	echo "=== [Run time: $(convert_time ${DURATION})]";
	printf "${PRINTF_MASTER_BLOCK}" "END" "$(date +'%F %T')" "${MODULE}";
fi;

# __END__
