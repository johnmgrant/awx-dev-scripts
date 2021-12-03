#!/usr/bin/env bash

# Script to Log VIP dev-env information for troubleshooting:
#
# EXAMPLE:
#   - bash log_vip_troubleshoot_info <env-slug> true
#      - Use this form if `vip --slug=<env-slug> dev-env create` was used.
#   - `bash log_vip_troubleshoot_info <env-app-id.env-level>`
#      - Use this form if `vip @<env-app-id.env-level> dev-env create` was used.
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
	if [ ! -d "$VIP_DEV_ENV_DIR_PATH" ]; then
		# Also check for if this is a non-slug created dev-env
		if [ ! -d "$VIP_DEV_ENV_DIR/${ENV_NAME//./$'-'}" ]; then
			return;
		fi
		VIP_DEV_ENV_DIR_PATH="$VIP_DEV_ENV_DIR/${ENV_NAME//./$'-'}"
	fi

	CURRENT_DIR=$( pwd )
	cd "$VIP_DEV_ENV_DIR_PATH" || {
		echo -e "\nError occured when switching to path: $VIP_DEV_ENV_DIR_PATH\n"
		exit 1;
	}

	perform_log 2>&1 | tee -a "$HOME/Desktop/vip_dev-env_$ENV_NAME.log"

	# Change back to previous working directory.
	# This doesn't seem to be needed, but I'll leave anyway until I learn why.
	cd "$CURRENT_DIR" || {
		echo -e "\nError occured when switching to path: $CURRENT_DIR\n"
		exit 1;
	}
}

# If vip command is installed, add the local path.
if [ -d "$HOME"/.local/share/vip ]; then
	export VIP_CLI_DIR=$HOME/.local/share/vip

    # If developer environments exist, add that dir as an export as well.
    if [ -d "$VIP_CLI_DIR"/dev-environment ]; then
		export VIP_DEV_ENV_DIR=$VIP_CLI_DIR/dev-environment
    fi
fi

log_vip_env_troubleshoot_info
