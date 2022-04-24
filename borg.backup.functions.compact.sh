#!/usr/bin/env bash

if [ -z "${MODULE}" ]; then
	echo "Script cannot be run on its own";
	exit 1;
fi;

# compact (only if BORG COMPACT is set)
# only for borg 1.2

# reset to normal IFS, so command works here
IFS=${_IFS};
if [ $(version $BORG_VERSION) -ge $(version "1.2.0") ]; then
	printf "${PRINTF_SUB_BLOCK}" "COMPACT" "$(date +'%F %T')" "${MODULE}";
	BORG_COMPACT="${BORG_COMMAND} compact -v ${OPT_PROGRESS} ${REPOSITORY}";
	if [ ${DEBUG} -eq 1 ]; then
			echo "${BORG_COMPACT}";
	fi;
	if [ ${DRYRUN} -eq 0 ]; then
		${BORG_COMPACT};
	fi;
fi;

# __END__
