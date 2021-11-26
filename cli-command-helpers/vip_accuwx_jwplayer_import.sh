#!/bin/bash

########################################################################################################################
########################################################################################################################
# Program Functions                                                                                                    #
########################################################################################################################
########################################################################################################################

############################################################
# Usage                                                    #
############################################################
vip_jwplayer_full_import_usage() {
	echo -e "\n\t- % $0 <env-name> <posts-per-page> <pages> [offset] [is-local-env] [use-lando] [is-slug-env]"
	echo -e "\t- % $0 [-h]\n"
}

############################################################
# Help                                                     #
############################################################
vip_jwplayer_full_import_help() {
	# Display Help
	echo
	echo "Command used to break out JWPlayer Video Import into a WordPress VIP Go environment."
	echo -e "\n--------------------------------------------------------------------------------------------------------------\n"
	echo "Software Dependencies:"
	echo -e "\n\tNode:\t\t\tv14.18.0+"
	echo -e "\tnpm:\t\t\tv8.1.4+"
	echo -e "\t@automattic/vip:\t2.3.0+"
	echo -e "\tLando:\t\t\tv3.4.2+"
	echo -e "\tDocker:\t\t\tv20.10.8+"
	echo
	echo "Syntax:"
	vip_jwplayer_full_import_usage
	echo "Options:"
	echo -e "\n\t-h Print this Help."
	echo
	echo "Examples:"
	echo -e "\n\t- % ./$0 1234.production /path-to-vaultpress-db-dump-tar/<env-site-name>.com-sqls-roots-YYYY-MM-DD-HH.tar.gz"
	echo -e "\t- % bash $0 1234.production /path-to-vaultpress-db-dump-tar/<env-site-name>.com-sqls-roots-YYYY-MM-DD-HH.tar.gz"
	echo -e "\n--------------------------------------------------------------------------------------------------------------\n"
}

# Defines function to grab a time stamp #
write_log_and_append_tee() {
	local STDOUT_TO_IN=""
	if [ -n "${1}" ]; then
		# If it's from a "<message>" then set it
		STDOUT_TO_IN="${1}"
		if [ ! -z "$STDOUT_TO_IN" ]; then
			echo "****${date '+%Y-%m-%d\ %H:%M:%S'} ${STDOUT_TO_IN}" | tee -a ${LOG_FILE_PATH}
		else
			echo | tee -a ${LOG_FILE_PATH}
		fi
	else
		# This reads a string from stdin and stores it as variable called STDOUT_TO_IN
		while IFS= read -r STDOUT_TO_IN; do
			if [ ! -z "$STDOUT_TO_IN" ]; then
				echo "[$( date '+%Y-%m-%d\ %H:%M:%S' )] ${STDOUT_TO_IN}" | tee -a ${LOG_FILE_PATH}
			else
				echo | tee -a ${LOG_FILE_PATH}
			fi
		done
	fi
}

############################################################
# Run JWPlayer Video Import Retry                          #
############################################################
run_vip_jwplayer_video_import_request_retry() {
	while true; do
		CURRENT_COMMAND_OUTPUT="$( ${CURRENT_COMMAND[@]} )"

		if [[ "${CURRENT_COMMAND_OUTPUT[@]}" == *"Imported $POSTS_PER_PAGE videos with"* ]]; then
			# The command succeeded, so continue the higher loop.
			echo "Retry was successful on attempt $RETRY_COUNTER!\n"
			break
		fi

		if [[ "$RETRY_COUNTER" < 5 ]]; then
			# The command output still wasn't a success, so sleep and try again.
			echo -e "\nThere was a JWPlayer timeout error... Retrying after 10s...\n"
			sleep 10
		else
			echo "${CURRENT_COMMAND_OUTPUT[@]}"
			echo -e "\nThere was a JWPlayer timeout error for 5 retries... Exiting import!\n"
			exit 1
		fi

		RETRY_COUNTER=$(( RETRY_COUNTER+1 ))
	done
}

############################################################
# Run JWPlayer Video Import                                #
############################################################
run_vip_jwplayer_video_import() {

	if [[ -z "$CMD_START" || -z "$LOG_FILE_PATH" ]]; then
		echo -e "\nError! This should be run from `maybe_run_vip_jwplayer_video_import` function instead!\n"
		exit 1;
	fi

	echo -e "Beginning JWPlayer video import...\n"

	# Run the single import command.
	local CMD_WP_CLI_CMD=( wp accuweather import_jwplayer_videos )
	for (( CURRENT_PAGE; CURRENT_PAGE <= PAGES; CURRENT_PAGE++ )); do

		local CMD_OPTIONS=( --per-page="$POSTS_PER_PAGE" --offset="$VIDEO_OFFSET" --pages=1 --update-existing --format=table )
		if [ ! -z $CMD_VERBOSE ]; then
			CMD_OPTIONS=( ${CMD_OPTIONS[@]} $CMD_VERBOSE )
		fi

		local CURRENT_COMMAND=( ${CMD_START[@]} ${CMD_WP_CLI_CMD[@]} ${CMD_OPTIONS[@]} )

		# Log the output to the file
		echo -e "\nImport command request: ${CURRENT_COMMAND[@]}\nPage: $CURRENT_PAGE\n"
		local CURRENT_COMMAND_OUTPUT="$( ${CURRENT_COMMAND[@]} )"

		# If there is a JWPlayer timeout, retry request up to 5 times after 10s sleep.
		if [[ "${CURRENT_COMMAND_OUTPUT[@]}" == *"jwp-timeout-fail"* ]]; then
			echo "There was a JWPlayer timeout error... Retrying after 10s.."
			sleep 10

			local RETRY_COUNTER=1
			{
				run_vip_jwplayer_video_import_request_retry
			} || {
				echo "Error during retry or retry failed after 3 attempts."
				exit 1;
			}
		fi

		# Send output to STDOUT on success.
		echo "${CURRENT_COMMAND_OUTPUT[@]}"

		# sleep for 5 seconds
		sleep 5

		VIDEO_OFFSET=$(( ( CURRENT_PAGE + 1 ) * POSTS_PER_PAGE ))
	done
}

############################################################
# Maybe Run JWPlayer Video Import                          #
############################################################
maybe_run_vip_jwplayer_video_import() {

	if [[ -z "$ENV_NAME" || "$PAGE_OFFSET" -gt "$PAGES" ]]; then
		[[ "$PAGE_OFFSET" -gt "$PAGES" ]] && echo true || echo false
		return;
	fi

	local IMPORT_LOG_DIR="${HOME}/Desktop/jwplayer-full-import-logs"

	if [[ 0 -eq "$PAGES" || "$PAGES" -lt 0 ]]; then
		PAGES=1
	fi

	if [ ! -d "$IMPORT_LOG_DIR" ]; then
		mkdir -p $IMPORT_LOG_DIR
	fi

	if [ 0 -eq "$POSTS_PER_PAGE" ]; then
		POSTS_PER_PAGE=1;
	elif [ 1000 -lt "$POSTS_PER_PAGE" ]; then
		POSTS_PER_PAGE=1000;
	fi

	if [[ ! -z "$PAGE_OFFSET" ]]; then
		CURRENT_PAGE="$PAGE_OFFSET"
		VIDEO_OFFSET=$(( PAGE_OFFSET*POSTS_PER_PAGE ))
	fi

	local FILE_ENV_NAME="$ENV_NAME"
	if [ $IS_LOCAL = true ]; then
		FILE_ENV_NAME="${ENV_NAME//./$'_'}_dev-env"

		if [ $USE_LANDO = true ]; then
			# Change the directory to lando env
			local VIP_DEV_ENV_DIR_PATH="$VIP_DEV_ENV_DIR/$ENV_NAME"
			if [ ! -d "$VIP_DEV_ENV_DIR_PATH" ]; then
				# Also check for if this is a non-slug created dev-env
				if [ ! -d "$VIP_DEV_ENV_DIR/${ENV_NAME//./$'-'}" ]; then
					echo -e "\nPath: $VIP_DEV_ENV_DIR_PATH did not exist and"
					echo "Path: $VIP_DEV_ENV_DIR/${ENV_NAME//./$'-'} did not exist either"
					echo -e "Please check the dev-env to ensure it has been created & started at least once.\n"
					exit 1;
				fi
				VIP_DEV_ENV_DIR_PATH="$VIP_DEV_ENV_DIR/${ENV_NAME//./$'-'}"
			fi
			cd "$VIP_DEV_ENV_DIR_PATH"

			# Form the lando command
			CMD_START=( lando )

			# Removed verbose as it caused issues unless run directly in environment (i.e. lando or ssh into container)
			local CMD_VERBOSE="--verbose"
		else
			# Use VIP CLI command: https://github.com/Automattic/vip
			local CMD_ENV_NAME="@$ENV_NAME"
			if [ $IS_SLUG = true ]; then
				CMD_ENV_NAME="--slug=$ENV_NAME"
			fi

			# Form the vip command
			CMD_START=( vip "$CMD_ENV_NAME" dev-env exec -- )
		fi
	fi

	# Create log file name.
	local FILE_DATE=$( date '+%Y-%m-%d' )
	local FILE_TIME=$( date '+%Hh-%Mm-%Ss' )
	local LOG_FILE_NAME="import_jwplayer_videos_page_${PAGES}_videos_${POSTS_PER_PAGE}_import_$FILE_TIME.log"
	local LOG_DIR_PATH="$IMPORT_LOG_DIR/$FILE_ENV_NAME/$FILE_DATE"
	if [ ! -d "$LOG_DIR_PATH" ]; then
		mkdir -p $LOG_DIR_PATH
	fi

	LOG_FILE_PATH="$LOG_DIR_PATH/$LOG_FILE_NAME"

	SECONDS=0
	run_vip_jwplayer_video_import 2>&1 | write_log_and_append_tee

	duration=$SECONDS
	hours=$(($duration / 3600))
	minutes=$((($duration %3600) / 60))
	seconds=$(($duration % 60))
	echo -e "\nVideo Import completed in $hours hours, $minutes minutes and $seconds seconds.\n" | tee -a "$LOG_FILE_PATH"
}

########################################################################################################################
########################################################################################################################
# Main Program                                                                                                         #
########################################################################################################################
########################################################################################################################


############################################################
# Process the input options. Add options as needed.        #
############################################################

# Get the options
while getopts ":h" option; do
	case $option in
	h) # display Help
		vip_jwplayer_full_import_help
		exit;;
	# n) # Enter a name
	# 	Name=$OPTARG;;
	# \?) # Invalid option
	# 	echo "Error: Invalid option"
	# 	exit;;
	*)
		echo -e "\nUsage:"
		vip_jwplayer_full_import_usage
		exit;;
	esac
done

# Get positional options:
#
# Examples:
#
# local - `bash vip_accuwx_jwplayer_import.sh local-dev.consumer-cms 200 338 0 true true`
#
# prod  - `bash vip_accuwx_jwplayer_import.sh 1234.production 200 338 0`
#
if [ $# -lt 3 ]; then
	echo -e "\nUsage:"
	vip_jwplayer_full_import_usage
	exit 1;
fi

# Set positional options
ENV_NAME=$1
POSTS_PER_PAGE=$2
PAGES=${3}
PAGE_OFFSET=${4-0}
IS_LOCAL=${5-false}
USE_LANDO=${6-false}
IS_SLUG=${7-false}

{
	maybe_run_vip_jwplayer_video_import &&
	echo "JWPlayer video import completed succesfully!"
	exit;
} || {
	echo "JWPlayer video import script encoutered an uncaught error during import..."
	exit 1;
}
