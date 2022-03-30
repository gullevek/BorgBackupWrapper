#!/usr/bin/env bash

# unset borg settings
unset BORG_BASE_DIR BORG_UNKNOWN_UNENCRYPTED_REPO_ACCESS_IS_OK BORG_RELOCATED_REPO_ACCESS_IS_OK
# error abort without duration and error notice
if [ $# -ge 1 ] && [ $1 -eq 1 ]; then
	echo "=== [ERROR: $(date +'%F %T')] ==[${MODULE}]====================================>";
else
	DURATION=$[ $(date +'%s')-$START ];
	echo "=== [Run time: $(convert_time ${DURATION})]";
	echo "=== [END  : $(date +'%F %T')] ==[${MODULE}]====================================>";
fi;

# __END__
