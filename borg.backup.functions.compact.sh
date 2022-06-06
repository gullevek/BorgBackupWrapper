#!/usr/bin/env bash

if [ -z "${MODULE}" ]; then
	echo "Script cannot be run on its own";
	exit 1;
fi;

# compact (only if BORG COMPACT is set)
# only for borg 1.2
if [ $(version $BORG_VERSION) -ge $(version "1.2.0") ]; then
	RUN_COMPACT=0;
	if [ $# -ge 1 ] && [ "$1" = "auto" ]; then
		# strip any spaces and convert to int
		COMPACT_INTERVAL=$(echo "${COMPACT_INTERVAL}" | sed -e 's/ //g');
		# not a valid compact interval, do no compact
		if [ -z "${COMPACT_INTERVAL##*[!0-9]*}" ]; then
			COMPACT_INTERVAL=0;
		fi;
		# get current date timestmap
		CURRENT_DATE=$(date +%s);
		if [ ${COMPACT_INTERVAL} -eq 1 ]; then
			RUN_COMPACT=1;
			# set new compact time here
			echo ${CURRENT_DATE} > "${BASE_FOLDER}${BACKUP_COMPACT_FILE}";
		elif [ ${COMPACT_INTERVAL} -gt 1 ]; then
			# else load last timestamp and check if today - last time stamp > days
			if [ -z "${LAST_COMPACT_DATE}" ]; then
				LAST_COMPACT_DATE=$(cat "${BASE_FOLDER}${BACKUP_COMPACT_FILE}" 2>/dev/null | sed -e 's/ //g');
			fi;
			# file date is not a timestamp
			if [ -z "${LAST_COMPACT_DATE##*[!0-9]*}" ]; then
				LAST_COMPACT_DATE=0;
			fi;
			# if the difference greate than compact date, run. COMPACT INTERVAL is in days
			if [ $(($CURRENT_DATE-$LAST_COMPACT_DATE)) -ge $((${COMPACT_INTERVAL}*86400)) ]; then
				RUN_COMPACT=1;
				# set new compact time here
				echo ${CURRENT_DATE} > "${BASE_FOLDER}${BACKUP_COMPACT_FILE}";
			fi;
		fi;
	elif [ ${COMPACT} -eq 1 ]; then
		RUN_COMPACT=1;
	fi;

	if [ ${RUN_COMPACT} -eq 1 ]; then
		# reset to normal IFS, so command works here
		IFS=${_IFS};
		printf "${PRINTF_SUB_BLOCK}" "COMPACT" "$(date +'%F %T')" "${MODULE}";
		BORG_COMPACT="${BORG_COMMAND} compact -v ${OPT_PROGRESS} ${REPOSITORY}";
		if [ ${DEBUG} -eq 1 ]; then
				echo "${BORG_COMPACT}";
		fi;
		if [ ${DRYRUN} -eq 0 ]; then
			${BORG_COMPACT};
		fi;
	fi;
fi;

# __END__
