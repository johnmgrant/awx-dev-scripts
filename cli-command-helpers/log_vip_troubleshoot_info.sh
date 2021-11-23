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
	echo -e "- vip cli version:"
	vip -v

	if [[ -z "$IS_SLUG" || "$IS_SLUG" == false ]]; then
		echo -e "\n- vip @$ENV_NAME dev-env info:"
		vip @"$ENV_NAME" dev-env info
	else
		echo -e "\n- vip --slug=$ENV_NAME dev-env info:"
		vip --slug="$ENV_NAME" dev-env info
	fi

	echo -e "\n- lando wp eval 'var_dump(EP_HOST);':"
	lando wp eval 'var_dump(EP_HOST);'

	echo -e "\n- lando wp vip-search status:"
	lando wp vip-search status

	echo -e "\n- lando info:"
	lando info

	echo -e "\n- docker container ls:"
	docker container ls

	echo -e "\n- docker container inspect ${ENV_NAME//[.-]}_vip-search_1:"
	docker container inspect "${ENV_NAME//[.-]}_vip-search_1"

	echo -e "\n- lando ssh -s vip-search --user root --command 'curl http://localhost:9200':"
	lando ssh -s vip-search --user root --command "curl http://localhost:9200"

	echo -e "\n- lando ssh -s vip-search --user root --command curl 'http://localhost:9200/_cluster/health?pretty':"
	lando ssh -s vip-search --user root --command "curl http://localhost:9200/_cluster/health?pretty"
}

log_vip_env_troubleshoot_info() {

	if [ -z "$ENV_NAME" ]; then
		ENV_NAME="local-dev.consumer-cms";
	fi

	local VIP_DEV_ENV_DIR_PATH="$VIP_DEV_ENV_DIR/$ENV_NAME"
	if [[ -z "$VIP_DEV_ENV_DIR" || ! -d "$VIP_DEV_ENV_DIR_PATH" ]]; then
		# Also check for if this is a non-slug created dev-env
		if [ ! -d "$VIP_DEV_ENV_DIR/${ENV_NAME//./$'-'}" ]; then
			return;
		fi
		VIP_DEV_ENV_DIR_PATH="$VIP_DEV_ENV_DIR/${ENV_NAME//./$'-'}"
	fi

	local CURRENT_DIR=$(pwd)
	cd "$VIP_DEV_ENV_DIR_PATH"

	perform_log 2>&1 | tee -a "$HOME/Desktop/vip_dev-env_$ENV_NAME.log"

	# Change back to previous working directory.
	cd $CURRENT_DIR
}

log_vip_env_troubleshoot_info
