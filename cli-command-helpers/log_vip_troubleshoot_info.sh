#!/usr/bin/env bash

# Script to Log VIP dev-env information for troubleshooting:
#
# EXAMPLE:
#   - 
#
if [ $# -lt 1 ]; then
	echo "usage: $0 <env-name> [is-slug]"
	exit 1
fi

ENV_NAME=$1
IS_SLUG=${2-false}

perform_log() {
	vip -v

	if [[ -z "$IS_SLUG" || "$IS_SLUG" = false ]]; then
		vip @"$ENV_NAME" dev-env info
	else
		vip --slug="$ENV_NAME" dev-env info
	fi
	
	lando wp eval 'var_dump(EP_HOST);' 
	lando wp vip-search status
	lando info
	docker container ls
}

log_vip_env_troubleshoot_info() {

	if [ -z "$ENV_NAME" ]; then
		ENV_NAME="local-dev.consumer-cms";
	fi

	if [[ -z "$VIP_DEV_ENV_DIR" || ! -d "$VIP_DEV_ENV_DIR/$ENV_NAME" ]]; then
		return;
	else
		local CURRENT_DIR=$(pwd)
		cd "$VIP_DEV_ENV_DIR/$ENV_NAME"
	fi

	perform_log 2>&1 | tee -a "$HOME/Desktop/vip-dev-env.log"

	# Change back to previous working directory.
	cd $CURRENT_DIR
}

log_vip_env_troubleshoot_info