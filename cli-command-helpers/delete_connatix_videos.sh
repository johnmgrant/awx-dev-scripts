#!/bin/bash

# Default environment.
FUNC=""
COMMNAND=''
TARGETED_ENV='dev-env exec --slug 3013-production'

############################################################
# Usage                                                    #
############################################################
_command_usage() {
	printf "\n\t- %% %s <env-option> <env-command>" "$FUNC"
	printf "\n\t- Where <env-option> can be:"
    printf "\n\t\t- 0 => Use second input as option."
    printf "\n\t\t- 1 => Use Default environment (dev-cms)."
    printf "\n\t\t- 2 => Use Preprod environment."
    printf "\n\t\t- 3 => Use Production environment."
    printf "\n\t\t- * => Use Local Develop Environment."
	printf "\n\t- %% %s [-h]\n" "$FUNC"
}

############################################################
# Help                                                     #
############################################################
_help() {
	# Display Help
	printf "\nCommand used to remove Connatix Content from a WordPress VIP Go environment."
	printf "\n--------------------------------------------------------------------------------------------------------------\n"
	printf "\nSoftware Dependencies:"
	printf "\n\tNode:\t\t\tv16.0.0+"
	printf "\n\tnpm:\t\t\tv8.1.4+"
	printf "\n\t@automattic/vip:\t2.3.0+"
	printf "\n\tDocker:\t\t\tv20.10.8+"
	printf "\n\nSyntax:"
	_command_usage
	printf "Options:"
	printf "\n\t-h Print this Help."
	printf "\n\nExamples:"
	printf "\n\t- %% ./%s" "$FUNC"
	printf "\n\t- %% ./%s 0 '%s'" "$FUNC" "dev-env exec --slug 3013-production"
	printf "\n\t- %% bash %s 1" "$FUNC"
	printf "\n--------------------------------------------------------------------------------------------------------------\n"
}

_set_func_called() {
    if [ -z "$FUNC" ]; then
        FUNC="$1"
    fi
}

# The mapping is as follows:
# - 0 => Use second input as option.
# - 1 => Use Local Develop Environment.
# - 2 => Use Preprod environment.
# - 3 => Use Production environment.
# - * => Use Default environment (dev-cms).
environment_specifier() {
    if [ $# -lt 1 ]; then
        printf "\nUsage:"
        _command_usage
        COMMNAND="usage";
        return 1;
    fi

    # Check if help is an option only if this is not a redundant call.
    if [ "$1" != "x" ]; then
        while getopts ":h" option; do
            case $option in
            h) # Display Help
                _help
                COMMNAND="help";
                return 0
                ;;
            *)
                ;;
            esac
        done
    fi

    # Set the TARGETED_ENV variable.
    case "$1" in
    0)
        PASSED_ENV="$2"
        if [ -n "$PASSED_ENV" ]; then
            TARGETED_ENV="$PASSED_ENV"
        fi
        ;;

    1)
        TARGETED_ENV='@3013.develop'
        ;;

    2)
        TARGETED_ENV='@3013.preprod'
        ;;

    3)
        TARGETED_ENV='@3013.production'
        ;;

    *)
        ;;
    esac
}

delete_all_connatix_videos() {
    _set_func_called "$0"
    environment_specifier "$@"
    if [ -n "$COMMNAND" ]; then
        return 0;
    fi
    printf "Deleting Connatix Videos on env[%s]\n" "$TARGETED_ENV"

    i=0
    until [ "$i" -gt 93 ]
    do
        printf "Loop number %s on env[%s]\n" "$i" "$TARGETED_ENV"
        vip "$TARGETED_ENV" -- wp post delete --force $(vip $TARGETED_ENV -- wp post list --posts_per_page=999 --post_type='connatix-videos' --format=ids)
        ((i=i+1))
    done
}

delete_all_connatix_playlists() {
    _set_func_called "$0"
    environment_specifier "$@"
    if [ -n "$COMMNAND" ]; then
        return 0;
    fi

    printf "Deleting Connatix Playlists on env[%s]\n" "$TARGETED_ENV"
    vip "$TARGETED_ENV" -- wp post delete --force $(vip $TARGETED_ENV -- wp post list --posts_per_page=999 --post_type='connatix-playlists' --format=ids)
}

delete_all_connatix_players() {
    _set_func_called "$0"
    environment_specifier "$@"
    if [ -n "$COMMNAND" ]; then
        return 0;
    fi

    printf "Deleting Connatix Players on env[%s]\n" "$TARGETED_ENV"
    vip "$TARGETED_ENV" -- wp term delete 'connatix-player' $(vip $TARGETED_ENV -- wp term list 'connatix-player' --format=ids)
}

delete_all_connatix_content() {
    _set_func_called "$0"
    environment_specifier "$@"
    if [ -n "$COMMNAND" ]; then
        return 0;
    fi

    printf "Deleting all Connatix Data on env[%s]\n" "$TARGETED_ENV\n"
    delete_all_connatix_players 'x'
    delete_all_connatix_playlists 'x'
    delete_all_connatix_videos 'x'
}
