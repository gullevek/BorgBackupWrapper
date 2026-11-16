#!/usr/bin/env bash

# allow variables in printf format string
# shellcheck disable=SC2059,SC2028
# Dump installed packages list and backup them

MODULE="packages"
MODULE_VERSION="1.0.1";

DIR="${BASH_SOURCE%/*}"
if [[ ! -d "$DIR" ]]; then DIR="$PWD"; fi
# init system
. "${DIR}/borg.backup.functions.init.sh";

# init verify, compact and check file
BACKUP_INIT_FILE="borg.backup.${MODULE}.init";
BACKUP_COMPACT_FILE="borg.backup.${MODULE}.compact";
BACKUP_CHECK_FILE="borg.backup.${MODULE}.check";
# lock file
BACKUP_LOCK_FILE="borg.backup.${MODULE}.lock";

# verify valid data
. "${DIR}/borg.backup.functions.verify.sh";
# if info print info and then abort run
. "${DIR}/borg.backup.functions.info.sh";

# must be a root user, or user that can dump package list
# if [ "$(id -u)" -ne 0 ]; then
# 	echo "[! $(date +'%F %T')] This script must be run as root";
# 	. "${DIR}/borg.backup.functions.close.sh" 1;
# 	exit 1;
# fi;

has() { command -v "$1" >/dev/null 2>&1; }

# decide what package backup to call, depending on the distribution
# debian/ubuntu
# - apt-mark showmanual
# - dpkg --get-selections
# rpm based (redhat, etc)
# - dnf history userinstalled
# - dnf list installed
# others -> error

if [ -r /etc/os-release ]; then
    . /etc/os-release
else
    echo "[! $(date +'%F %T')] Cannot read /etc/os-release" >&2
	. "${DIR}/borg.backup.functions.close.sh" 1;
    exit 1
fi

FILENAME_ALL="installed_packages.txt";
FILENAME_MANUAL="installed_packages.manual.txt";
BACKUP_SET_PREFIX="${MODULE},";
BACKUP_SET_NAME="${ONE_TIME_TAG}${BACKUP_SET_PREFIX}${BACKUP_SET}";
BORG_CALL="${_BORG_CALL_FILES//##BACKUP_SET##/${BACKUP_SET_NAME}}";
OS_ID="${ID:-unknown}"
OS_LIKE="${ID_LIKE:-}"
# detect OS TYOE
case " $OS_ID $OS_LIKE " in
    *" debian "*|*" ubuntu "*)
        FAMILY=debian ;;
    *" rhel "*|*" fedora "*|*" centos "*)
        FAMILY=redhat ;;
    *)
        FAMILY=unknown ;;
esac
# backup start with --read-special
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT
case "$FAMILY" in
    debian)
        if ! has dpkg; then
            echo "[! $(date +'%F %T')] dpkg not found" >&2;
			. "${DIR}/borg.backup.functions.close.sh" 1;
			exit 1
        fi
		if [ ${DEBUG} -eq 1 ] || [ ${DRYRUN} -eq 1 ]; then
			echo "dpkg --get-selections > $TMP_DIR/${FILENAME_ALL}";
			echo "apt-mark showmanual | sort > $TMP_DIR/${FILENAME_MANUAL}";
		fi;
		if [ ${DRYRUN} -eq 0 ]; then
			dpkg --get-selections > "$TMP_DIR"/"${FILENAME_ALL}";
			apt-mark showmanual | sort > "$TMP_DIR"/"${FILENAME_MANUAL}";
		fi;
		;;
	redhat)
        if ! has rpm; then
            echo "[! $(date +'%F %T')] rpm not found" >&2;
			. "${DIR}/borg.backup.functions.close.sh" 1;
			exit 1
        fi
		if [ ${DEBUG} -eq 1 ] || [ ${DRYRUN} -eq 1 ]; then
			echo "rpm -qa --qf '%{NAME}.%{ARCH}\n' | sort > $TMP_DIR/${FILENAME_ALL}";
		fi;
		if [ ${DRYRUN} -eq 0 ]; then
			rpm -qa --qf '%{NAME}.%{ARCH}\n' | sort > "$TMP_DIR"/"${FILENAME_ALL}";
		fi;
        if has dnf; then
			if [ ${DEBUG} -eq 1 ] || [ ${DRYRUN} -eq 1 ]; then
				echo "dnf -q repoquery --userinstalled --qf '%{name}\n' 2>/dev/null | sort -u > $TMP_DIR/${FILENAME_MANUAL}";
			fi;
			if [ ${DRYRUN} -eq 0 ]; then
				dnf -q repoquery --userinstalled --qf '%{name}\n' 2>/dev/null \
					| sort -u > "$TMP_DIR"/"${FILENAME_MANUAL}";
			fi;
        elif has yumdb; then
			if [ ${DEBUG} -eq 1 ] || [ ${DRYRUN} -eq 1 ]; then
				echo "yumdb search reason user 2>/dev/null | grep -v '^[[:space:]]' | grep -v '^$' | grep -v '^Loaded plugins' | sort -u > $TMP_DIR/${FILENAME_MANUAL}";
			fi;
			if [ ${DRYRUN} -eq 0 ]; then
				yumdb search reason user 2>/dev/null \
					| grep -v '^[[:space:]]' | grep -v '^$' \
					| grep -v '^Loaded plugins' \
					| sort -u \
					| sort -u > "$TMP_DIR"/"${FILENAME_MANUAL}";
			fi;
        fi;
		wait
		;;
	*)
        echo "[! $(date +'%F %T')] Unsupported distribution: $OS_ID ($OS_LIKE)" >&2
		. "${DIR}/borg.backup.functions.close.sh" 1;
        exit 1
        ;;
esac;

# Run backup
if [ ${DEBUG} -eq 1 ] || [ ${DRYRUN} -eq 1 ]; then
	echo "${BORG_CALL} ${TMP_DIR}/./${FILENAME_ALL} ${TMP_DIR}/./${FILENAME_MANUAL}";
fi;
if [ ${DRYRUN} -eq 0 ]; then
	${BORG_CALL} "${TMP_DIR}/./${FILENAME_ALL}" "${TMP_DIR}/./${FILENAME_MANUAL}";
fi;

# borg call
BORG_PRUNE="${_BORG_PRUNE//##BACKUP_SET_PREFIX##/${BACKUP_SET_PREFIX}}"
printf "${PRINTF_SUB_BLOCK}" "BACKUP: installed packages" "$(date +'%F %T')" "${MODULE}";
if [ -z "${ONE_TIME_TAG}" ]; then
	printf "${PRINTF_SUB_BLOCK}" "PRUNE" "$(date +'%F %T')" "${MODULE}";
	echo "Prune repository with keep${KEEP_INFO:1}";
	${BORG_PRUNE};
	# if this is borg version >1.2 we need to run compact after prune
	. "${DIR}/borg.backup.functions.compact.sh" "auto";
	# check in auto mode
	. "${DIR}/borg.backup.functions.check.sh" "auto";
fi;

. "${DIR}/borg.backup.functions.close.sh";

# __END__
