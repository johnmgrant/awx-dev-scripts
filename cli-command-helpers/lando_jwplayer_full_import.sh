#!/usr/bin/env bash

# Full import command:
# local - bash lando_jwplayer_full_import.sh local-dev.consumer-cms 200 338
if [ $# -lt 3 ]; then
	echo "usage: $0 <env-name> <posts-per-page> <pages>"
	exit 1
fi

ENV_NAME=$1
POSTS_PER_PAGE=$2
PAGES=${3}

run_lando_accuweather_jwplayer_video_import() {

	if [[ 0 -eq "$POSTS_PER_PAGE" ]]; then
		POSTS_PER_PAGE=1;
	elif [[ 1000 -lt "$POSTS_PER_PAGE" ]]; then
		POSTS_PER_PAGE=1000;
	fi

	# Create log file name.
	# local LOG_FILE_NAME="import_jwplayer_videos_page_${CURRENT_PAGE}_videos_${POSTS_PER_PAGE}_import.log"
	local LOG_FILE_NAME="import_jwplayer_videos_page_${PAGES}_videos_${POSTS_PER_PAGE}_import.log"

	# Run the single import command.
	# Removing verbose as it caused issues: --verbose
	lando wp accuweather import_jwplayer_videos --per-page="$POSTS_PER_PAGE" --pages=1 --offset="$VIDEO_OFFSET" --update-existing --format=table | tee -a "$IMPORT_LOG_DIR/$LOG_FILE_NAME"
		
	# sleep for 5 seconds
	sleep 5
}

run_lando_full_jwplayer_video_import() {

	if [[ -z "$ENV_NAME" || -z "$VIP_DEV_ENV_DIR" || ! -d "$HOME/$VIP_DEV_ENV_DIR/$ENV_NAME" ]]; then
		return;
	else
		local CURRENT_DIR=$(pwd)
		cd "$HOME/$VIP_DEV_ENV_DIR/$ENV_NAME"
	fi

	local VIDEO_OFFSET=0
	local CURRENT_PAGE=1
	local IMPORT_LOG_DIR="$HOME/Desktop/jwplayer-full-import-logs"

	if [[ 0 -eq "$PAGE" ]]; then
		PAGE=$CURRENT_PAGE
	fi

	if [ ! -d "$IMPORT_LOG_DIR" ]; then
		mkdir -p $IMPORT_LOG_DIR
	fi

	for (( i=1; i <= PAGES; i++ )); do
		CURRENT_PAGE=$i
		run_lando_accuweather_jwplayer_video_import
		VIDEO_OFFSET=$(( CURRENT_PAGE*POSTS_PER_PAGE ))
	done

	# Change back to previous working directory.
	cd $CURRENT_DIR
}

echo "Beginning JWPlayer Full Import..."
SECONDS=0
run_lando_full_jwplayer_video_import
duration=$SECONDS
echo "Import completed in $(($duration / 3600)) hours, $(($duration / 60)) minutes and $(($duration % 60)) seconds."
