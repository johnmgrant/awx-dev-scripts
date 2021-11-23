#!/usr/bin/env bash

if [ $# -lt 2 ]; then
	echo "usage: $0 <env-name> <path-to-sql-tar.gz> [is-slugged-environment]"
	exit 1
fi

ENV_NAME=$1
SQL_TAR_FILE_PATH=$2
IS_SLUG_ENV=$3

PRODUCTION_SITE="www.accuweather.com"

# Replace this with the RW host hostname/ address
LOCAL_SITE="192.168.0.242:8086"

log_error_exit() {
    echo "Error: $1"
    exit 1
}

update_table_data_entries() {
	vip "$VIP_ENV_NAME" dev-env exec -- wp option update home "http://$ENV_SLUG_NAME.vipdev.lndo.site"
	vip "$VIP_ENV_NAME" dev-env exec -- wp option update siteurl "http://$ENV_SLUG_NAME.vipdev.lndo.site"
	vip "$VIP_ENV_NAME" dev-env exec -- wp option update blogname "AccuwWeather Consumer CMS Local Dev 1"
	vip "$VIP_ENV_NAME" dev-env exec -- wp option update admin_email "$WORK_EMAIL"
	vip "$VIP_ENV_NAME" dev-env exec -- wp option patch update aw_site_settings preview_link_base_url $LOCAL_SITE
	vip "$VIP_ENV_NAME" dev-env exec -- wp option patch update apple_news_settings api_autosync no
	vip "$VIP_ENV_NAME" dev-env exec -- wp option patch update apple_news_settings api_autosync_update no
	vip "$VIP_ENV_NAME" dev-env exec -- wp option patch update apple_news_settings api_autosync_delete no
	vip "$VIP_ENV_NAME" dev-env exec -- wp option patch update aw_jwplayer cron_import_settings enable_cron_import 0
	vip "$VIP_ENV_NAME" dev-env exec -- wp option patch update aw_jwplayer playlist_import_options import_enabled 0
	vip "$VIP_ENV_NAME" dev-env exec -- wp network meta update 1 admin_email "$WORK_EMAIL"
	vip "$VIP_ENV_NAME" dev-env exec -- wp site meta update 1 site_name "AccuwWeather Consumer CMS Local Dev 1"
	vip "$VIP_ENV_NAME" dev-env exec -- wp site meta update 1 siteurl "http://$ENV_SLUG_NAME.vipdev.lndo.site"
	vip "$VIP_ENV_NAME" dev-env exec -- wp cache flush
}

do_handle_data_import() {

	# Ensure that '.' is replaced with '-' in ENV_NAME
	local ENV_SLUG_NAME="${ENV_NAME//./$'-'}"
	if [[ -z "$IS_SLUG_ENV" || "$IS_SLUG_ENV" == true ]]; then
		ENV_SLUG_NAME="$ENV_NAME"
	fi

	if [[ -z "$ENV_NAME" || -z "$VIP_DEV_ENV_DIR" || -z "$HOSTNAME_CONSUMER_CMS_PROD" || ! -d "$VIP_DEV_ENV_DIR/$ENV_SLUG_NAME" ]]; then
		echo "Error: There is a missing dependency!"
		echo "Param 1: $ENV_NAME"
		echo "Param 2: $VIP_DEV_ENV_DIR"
		echo "Param 3: $HOSTNAME_CONSUMER_CMS_PROD"
		echo "Global Path: $VIP_DEV_ENV_DIR/$ENV_SLUG_NAME"
		exit 1
	else
		local CURRENT_DIR=$( PWD )
		cd "$VIP_DEV_ENV_DIR/$ENV_SLUG_NAME"
		echo "Working from $PWD"
	fi

	local VIP_ENV_NAME="$VIP_ENV_NAME"
	if [[ -z "$IS_SLUG_ENV" || "$IS_SLUG_ENV" == true ]]; then
		VIP_ENV_NAME="--slug=$ENV_NAME"
	fi

	if [[ -f "$SQL_TAR_FILE_PATH" || "$SQL_TAR_FILE_PATH" != *"$HOSTNAME_CONSUMER_CMS_PROD-sqls-roots-"*".tar.gz" ]]; then
		if [ ! -d db_dump ]; then
			mkdir db_dump
		fi
		cd db_dump
	else
		log_error_exit "Error: The SQL Tar File Path is invalid or does not exist."
	fi

	# Extract sql files
	{
		local TAR_NAME=${SQL_TAR_FILE_PATH#"${SQL_TAR_FILE_PATH%*"$HOSTNAME_CONSUMER_CMS_PROD-sqls-roots-"*".tar.gz"}"}
		local TAR_DIR="${SQL_TAR_FILE_PATH%"$TAR_NAME"}"

		if [[ -d "$TAR_DIR" && ! -z "$TAR_NAME" ]]; then
			{
				local PREVIOUS_DIR=$( PWD )
				local EXTRACTED_TAR_NAME="${TAR_NAME%*".tar.gz"}"

				echo "Beginning extraction of $TAR_NAME tar from directory $TAR_DIR..."
				cd $TAR_DIR &&
				mkdir $EXTRACTED_TAR_NAME &&
				tar -xvf $TAR_NAME -C $EXTRACTED_TAR_NAME &&
				mv "$EXTRACTED_TAR_NAME" "$PREVIOUS_DIR/" &&
				cd "$PREVIOUS_DIR/$EXTRACTED_TAR_NAME/sql"
			} || {
				log_error_exit "Failed to extract sql files..."
			}
		else
			log_error_exit "An error occured and the tar dir was incorrectly extracted!"
		fi
	} || {
		log_error_exit "An error occured while attempting to extract the tar file..."
	}

	# Remove files that do not need to be imported locally.
	echo "Removing uneeded production sql files..."
	{
		rm wp_site.sql
		rm wp_blogs.sql
		rm wp_links.sql
		rm wp_signups.sql
		rm wp_blog_versions.sql
		rm wp_registration_log.sql
		rm wp_a8c_cron_control_jobs.sql
		rm wp_vip_search_index_queue.sql
	} || {
		log_error_exit "Failed to remove expected sql files..."
	}

	for sql_file in *.sql; do
		{
			# Thes can take some time to complete, so don’t let your computer go to sleep until it’s done!
			printf 'y\n' | vip "$VIP_ENV_NAME" dev-env import sql "$sql_file" --search-replace="$HOSTNAME_CONSUMER_CMS_PROD,$ENV_SLUG_NAME.vipdev.lndo.site" --search-replace="$PRODUCTION_SITE,$LOCAL_SITE" --in-place
		} || {
			log_error_exit "Failed to import $sql_file."
		}
	done

	cd ../../../
	rm -rf db_dump/
	update_data_tables

	cd $CURRENT_DIR
}

echo "Beginning VIP dev-env data import..."
SECONDS=0
{
	do_handle_data_import &&
	echo "\n---\nVIP dev-env data import completed succesfully!"
} || {
	error_exit "VIP dev-env data import script encoutered an error during import..."
}
duration=$SECONDS
echo "Import completed in $(($duration / 60)) minutes and $(($duration % 60)) seconds."
