#!/bin/bash
# https://blog.sourcetreeapp.com/2012/02/08/custom-actions-more-power-to-you/

ORIGIN_REMOTE_PATH="remotes/origin/"

COMMIT_SHA="$1"
TARGET_BRANCH_PATH=$( git name-rev --name-only "$COMMIT_SHA" )
TARGET_BRANCH_NAME=${TARGET_BRANCH_PATH#"${ORIGIN_REMOTE_PATH}"}

if [ -f ".gitmodules" ]; then
	git submodule deinit .
fi

git checkout "$TARGET_BRANCH_NAME"

if [ -f ".gitmodules" ]; then
	git submodule update --init --recursive
fi
