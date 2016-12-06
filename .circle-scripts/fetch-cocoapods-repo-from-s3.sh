#!/usr/bin/env bash

set -o nounset
set -o errexit
set -o pipefail

REPOS_LOCATION="$HOME/.cocoapods/repos"
MASTER_REPO_LOCATION="$REPOS_LOCATION/master"
S3_BUCKET="cocoapods-specs"

tempfile=$(mktemp)

cleanup() {
  echo "Download from S3 failed, cleaning up and falling back to standard checkout..."
  rm -rf "$MASTER_REPO_LOCATION"
  rm "$tempfile"
}

trap cleanup ERR

# Only install awscli if it's not in the image. pip will exit with
# non-zero exit code if the package is not installed. Hiding all output
# from package installation to not to confuse users.
if ! pip show awscli > /dev/null 2>&1 ; then
  sudo pip install --ignore-installed awscli > /dev/null 2>&1
fi

rm -rf "$MASTER_REPO_LOCATION"
mkdir -p "$REPOS_LOCATION"

echo "Downloading CocoaPods master repo from $S3_BUCKET S3 bucket..."
# --no-sign-request forces awscli to not to use any credentials.
aws s3 --no-sign-request cp "s3://$S3_BUCKET/latest.tar.gz" "$tempfile" > /dev/null

echo "Uncompressing CocoaPods master repo..."
# We expect the structure with the "master" as the top dir in the archive.
tar -C "$REPOS_LOCATION" -xzf "$tempfile"

echo "Successfully downloaded CocoaPods master repo."
COCOAPODS_GIT_REV="$(cd $MASTER_REPO_LOCATION && git rev-parse HEAD)"
echo "Using specs repo revision $COCOAPODS_GIT_REV."

rm "$tempfile"
