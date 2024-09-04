#!/usr/bin/env bash

if [ -z "${MODULE}" ]; then
	echo "Script cannot be run on its own";
	exit 1;
fi;

# run borg check (NOT REPAIR)

RUN_CHECK=0;
if [ $# -ge 1 ] && [ "$1" = "auto" ]; then
	# strip any spaces and convert to int
	CHECK_INTERVAL=$(echo "${CHECK_INTERVAL}" | sed -e 's/ //g');
	# not a valid check interval, do no check
	if [ -z "${CHECK_INTERVAL##*[!0-9]*}" ]; then
		CHECK_INTERVAL=0;
	fi;
	# get current date timestmap
	CURRENT_DATE=$(date +%s);
	# if =1 always ok
	if [ ${CHECK_INTERVAL} -eq 1 ]; then
		RUN_CHECK=1;
		# always add verify data for automatic check
		OPT_CHECK_VERIFY_DATA="--verify-data";
		# set new check time here
		echo ${CURRENT_DATE} > "${BASE_FOLDER}${BACKUP_CHECK_FILE}";
	elif [ ${CHECK_INTERVAL} -gt 1 ]; then
		# else load last timestamp and check if today - last time stamp > days
		if [ -z "${LAST_CHECK_DATE}" ]; then
			LAST_CHECK_DATE=$(cat "${BASE_FOLDER}${BACKUP_CHECK_FILE}" 2>/dev/null | sed -e 's/ //g');
		fi;
		# file date is not a timestamp
		if [ -z "${LAST_CHECK_DATE##*[!0-9]*}" ]; then
			LAST_CHECK_DATE=0;
		fi;
		# if the difference greate than check date, run. CHECK INTERVAL is in days
		if [ $(($CURRENT_DATE-$LAST_CHECK_DATE)) -ge $((${CHECK_INTERVAL}*86400)) ]; then
			RUN_CHECK=1;
			# always add verify data for automatic check
			OPT_CHECK_VERIFY_DATA="--verify-data";
			# set new check time here
			echo ${CURRENT_DATE} > "${BASE_FOLDER}${BACKUP_CHECK_FILE}";
		fi;
	fi;
elif [ ${CHECK} -eq 1 ]; then
	RUN_CHECK=1;
fi;

if [ ${RUN_CHECK} -eq 1 ]; then
	# run borg check command
	IFS=${_IFS};
	printf "${PRINTF_SUB_BLOCK}" "CHECK" "$(date +'%F %T')" "${MODULE}";
	# repare command
	OPT_GLOB="";
	if [[ "${CHECK_PREFIX}" =~ $REGEX_GLOB ]]; then
		OPT_GLOB="-a '${CHECK_PREFIX}'"
	elif [ -n "${CHECK_PREFIX}" ]; then
		OPT_GLOB="-P ${CHECK_PREFIX}";
	fi;
	# debug/dryrun
	if [ ${DEBUG} -eq 1 ] || [ ${DRYRUN} -eq 1 ]; then
		echo "export BORG_BASE_DIR=\"${BASE_FOLDER}\";${BORG_COMMAND} check ${OPT_REMOTE} ${OPT_PROGRESS} ${OPT_CHECK_VERIFY_DATA} ${OPT_GLOB} ${REPOSITORY}";
	fi;
	# run info command if not a dry drun
	if [ ${DRYRUN} -eq 0 ]; then
		# if glob add glob command directly
		if [[ "${CHECK_PREFIX}" =~ $REGEX_GLOB ]]; then
		${BORG_COMMAND} check ${OPT_REMOTE} ${OPT_PROGRESS} ${OPT_CHECK_VERIFY_DATA} -a "${CHECK_PREFIX}" ${REPOSITORY};
		else
			${BORG_COMMAND} check ${OPT_REMOTE} ${OPT_PROGRESS} ${OPT_CHECK_VERIFY_DATA} ${OPT_GLOB} ${REPOSITORY};
		fi;
	fi;
	# print additional info for use --repair command
	# but only for manual checks
	if [ ${VERBOSE} -eq 1 ] && [ ${CHECK} -eq 1 ]; then
		echo "";
		echo "In case of needed repair: "
		echo "export BORG_BASE_DIR=\"${BASE_FOLDER}\";${BORG_COMMAND} check ${OPT_REMOTE} ${OPT_PROGRESS} --repair ${OPT_GLOB} ${REPOSITORY}";
		echo "Before running repair, a copy from the backup should be made because repair might damage a backup"
	fi;
fi;

# __END__
