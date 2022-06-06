#!/usr/bin/env bash

# Plain file backup

# set last edit date + time
MODULE="file";
MODULE_VERSION="1.2.2";

DIR="${BASH_SOURCE%/*}"
if [[ ! -d "$DIR" ]]; then DIR="$PWD"; fi
. "${DIR}/borg.backup.functions.init.sh";

# include and exclude file
INCLUDE_FILE="borg.backup.${MODULE}.include";
EXCLUDE_FILE="borg.backup.${MODULE}.exclude";
# init verify, compact and check file
BACKUP_INIT_FILE="borg.backup.${MODULE}.init";
BACKUP_COMPACT_FILE="borg.backup.${MODULE}.compact";
BACKUP_CHECK_FILE="borg.backup.${MODULE}.check";
# lock file
BACKUP_LOCK_FILE="borg.backup.${MODULE}.lock";

# verify valid data
. "${DIR}/borg.backup.functions.verify.sh";

# exit if include file is missing
if [ ! -f "${BASE_FOLDER}${INCLUDE_FILE}" ]; then
	echo "[! $(date +'%F %T')] The include folder file ${INCLUDE_FILE} is missing";
	. "${DIR}/borg.backup.functions.close.sh" 1;
	exit 1;
fi;
printf "${PRINTF_SUB_BLOCK}" "INCLUDE" "$(date +'%F %T')" "${MODULE}";
# folders to backup
FOLDERS=();
# this if for debug output with quoted folders
FOLDERS_Q=();
# include list
while read include_folder; do
	# strip any leading spaces from that folder
	include_folder=$(echo "${include_folder}" | sed -e 's/^[ \t]*//');
	# check that those folders exist, warn on error,
	# but do not exit unless there are no valid folders at all
	# skip folders that are with # in front (comment)
	if [[ "${include_folder}" =~ ${REGEX_COMMENT} ]]; then
		echo "# [C] Comment: '${include_folder}'";
	else
		# skip if it is empty
		if [ ! -z "${include_folder}" ]; then
			# if this is a glob, do a double check that the base folder actually exists (?)
			if [[ "${include_folder}" =~ $REGEX_GLOB ]]; then
				# if this is */ then allow it
				# remove last element beyond the last /
				# if there is no path, just allow it (general rule)
				_include_folder=${include_folder%/*};
				# if still a * inside -> add as is, else check for folder
				if [[ "${include_folder}" =~ $REGEX_GLOB ]]; then
					FOLDER_OK=1;
					echo "+ [I] Backup folder with folder path glob '${include_folder}'";
					# glob (*) would be escape so we replace it with a temp part and then reinsert it
					FOLDERS_Q+=($(printf "%q" "$(echo "${include_folder}" | sed 's/\*/_STARGLOB_/g')" | sed 's/_STARGLOB_/\*/g'));
					FOLDERS+=("${include_folder}");
				elif [ ! -d "${_include_folder}" ]; then
					echo "- [I] Backup folder with glob '${include_folder}' does not exist or is not accessable";
				else
					FOLDER_OK=1;
					echo "+ [I] Backup folder with glob '${include_folder}'";
					# we need glob fix
					FOLDERS_Q+=($(printf "%q" "$(echo "${include_folder}" | sed 's/\*/_STARGLOB_/g')" | sed 's/_STARGLOB_/\*/g'));
					FOLDERS+=("${include_folder}");
				fi;
			# normal folder
			elif [ ! -d "${include_folder}" ] && [ ! -e "${include_folder}" ]; then
				echo "- [I] Backup folder or file '${include_folder}' does not exist or is not accessable";
			else
				FOLDER_OK=1;
				# if it is a folder, remove the last / or the symlink check will not work
				if [ -d "${include_folder}" ]; then
					_include_folder=${include_folder%/*};
				else
					_include_folder=${include_folder};
				fi;
				# Warn if symlink & folder -> only smylink will be backed up
				if [ -h "${_include_folder}" ]; then
					echo "~ [I] Target '${include_folder}' is a symbolic link. No real data will be backed up";
				else
					echo "+ [I] Backup folder or file '${include_folder}'";
				fi;
				FOLDERS_Q+=($(printf "%q" "${include_folder}"));
				FOLDERS+=("${include_folder}");
			fi;
		fi;
	fi;
done<"${BASE_FOLDER}${INCLUDE_FILE}";

# exclude list
if [ -f "${BASE_FOLDER}${EXCLUDE_FILE}" ]; then
	printf "${PRINTF_SUB_BLOCK}" "EXCLUDE" "$(date +'%F %T')" "${MODULE}";
	# check that the folders in that exclude file are actually valid,
	# remove non valid ones and warn
	#TMP_EXCLUDE_FILE=$(mktemp --tmpdir ${EXCLUDE_FILE}.XXXXXXXX); # non mac
	TMP_EXCLUDE_FILE=$(mktemp "${TEMPDIR}${EXCLUDE_FILE}".XXXXXXXX);
	while read exclude_folder; do
		# strip any leading spaces from that folder
		exclude_folder=$(echo "${exclude_folder}" | sed -e 's/^[ \t]*//');
		# folder or any type of file is ok
		# because of glob files etc, exclude only comments (# start)
		if [[ "${exclude_folder}" =~ ${REGEX_COMMENT} ]]; then
			echo "# [C] Comment: '${exclude_folder}'";
		else
			# skip if it is empty
			if [ ! -z "${exclude_folder}" ]; then
				# if it DOES NOT start with a / we assume free folder and add as is
				if [[ "${exclude_folder}" != /* ]]; then
					echo "${exclude_folder}" >> ${TMP_EXCLUDE_FILE};
					echo "+ [E] General exclude: '${exclude_folder}'";
				# if this is a glob, do a double check that the base folder actually exists (?)
				elif [[ "${exclude_folder}" =~ $REGEX_GLOB ]]; then
					# remove last element beyond the last /
					# if there is no path, just allow it (general rule)
					_exclude_folder=${exclude_folder%/*};
					if [ ! -d "${_exclude_folder}" ]; then
						echo "- [E] Exclude folder with glob '${exclude_folder}' does not exist or is not accessable";
					else
						echo "${exclude_folder}" >> ${TMP_EXCLUDE_FILE};
						echo "+ [E] Exclude folder with glob '${exclude_folder}'";
					fi;
				# do a warning for a possible invalid folder
				# but we do not a exclude if the data does not exist
				elif [ ! -d "${exclude_folder}" ] && [ ! -e "${exclude_folder}" ]; then
					echo "- [E] Exclude folder or file '${exclude_folder}' does not exist or is not accessable";
				else
					echo "${exclude_folder}" >> ${TMP_EXCLUDE_FILE};
					# if it is a folder, remove the last / or the symlink check will not work
					if [ -d "${exclude_folder}" ]; then
						_exclude_folder=${exclude_folder%/*};
					else
						_exclude_folder=${exclude_folder};
					fi;
					# warn if target is symlink folder
					if [ -h "${_exclude_folder}" ]; then
						echo "~ [I] Target '${exclude_folder}' is a symbolic link. No real data will be excluded from backup";
					else
						echo "+ [E] Exclude folder or file '${exclude_folder}'";
					fi;
				fi;
			fi;
		fi;
	done<"${BASE_FOLDER}${EXCLUDE_FILE}";
	# avoid blank file add by checking if the tmp file has a size >0
	if [ -s "${BASE_FOLDER}${EXCLUDE_FILE}" ]; then
		OPT_EXCLUDE="--exclude-from=${TMP_EXCLUDE_FILE}";
	fi;
fi;

# set a special file prefix
BACKUP_SET_PREFIX="${MODULE},";
# add the repository set before we add the folders
# base command
COMMAND="${BORG_COMMAND} create -v ${OPT_LIST} ${OPT_PROGRESS} ${OPT_COMPRESSION} -s ${OPT_REMOTE} ${OPT_EXCLUDE} ";
# add repoistory, after that the folders will be added on call
COMMAND=${COMMAND}${REPOSITORY}::${ONE_TIME_TAG}${BACKUP_SET_PREFIX}${BACKUP_SET};
# if info print info and then abort run
. "${DIR}/borg.backup.functions.info.sh";

if [ $FOLDER_OK -eq 1 ]; then
	printf "${PRINTF_SUB_BLOCK}" "BACKUP" "$(date +'%F %T')" "${MODULE}";
	# show command
	if [ ${DEBUG} -eq 1 ]; then
		echo $(echo ${COMMAND} | sed -e 's/[ ][ ]*/ /g') ${FOLDERS_Q[*]};
	fi;
	# execute backup command
	if [ ${DRYRUN} -eq 0 ]; then
		# need to redirect std error to std out so all data is printed to the correct pipe
		# for the IFS="#" to work we need to replace options spaces with exactly ONE #
		$(echo "${COMMAND}" | sed -e 's/[ ][ ]*/#/g') ${FOLDERS[*]} 2>&1 || echo "[!] Borg backup aborted.";
	fi;
	# remove the temporary exclude file if it exists
	if [ -f "${TMP_EXCLUDE_FILE}" ]; then
		rm -f "${TMP_EXCLUDE_FILE}";
	fi;
else
	echo "[! $(date +'%F %T')] No folders where set for the backup";
	. "${DIR}/borg.backup.functions.close.sh" 1;
	exit 1;
fi;

# clean up, always verbose, but only if we do not run one time tag
if [ -z "${ONE_TIME_TAG}" ]; then
	printf "${PRINTF_SUB_BLOCK}" "PRUNE" "$(date +'%F %T')" "${MODULE}";
	# build command
	COMMAND="${BORG_COMMAND} prune ${OPT_REMOTE} -v --list ${OPT_PROGRESS} ${DRY_RUN_STATS} -P ${BACKUP_SET_PREFIX} ${KEEP_OPTIONS[*]} ${REPOSITORY}";
	echo "Prune repository with keep${KEEP_INFO:1}";
	if [ ${DEBUG} -eq 1 ]; then
		echo "${COMMAND//#/ }" | sed -e 's/[ ][ ]*/ /g';
	fi;
	# for the IFS="#" to work we need to replace options spaces with exactly ONE #
	$(echo "${COMMAND}" | sed -e 's/[ ][ ]*/#/g') 2>&1 || echo "[!] Borg prune aborted";
	# if this is borg version >1.2 we need to run compact after prune
	. "${DIR}/borg.backup.functions.compact.sh" "auto";
	# check in auto mode
	. "${DIR}/borg.backup.functions.check.sh" "auto";
else
	echo "[#] No prune with tagged backup";
fi;

. "${DIR}/borg.backup.functions.close.sh";

# __END__
