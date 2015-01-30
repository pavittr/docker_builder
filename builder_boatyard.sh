#!/bin/bash
#********************************************************************************
# Copyright 2014 IBM
#
#   Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
#   Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#********************************************************************************

CURL_OPTIONS="--silent --http1.0"
#
## Usage function
#
function usage () {
echo "Usage: `basename $0` (-t|--tag) tag [(-v|--version) version] [(-b|--builder) image_builder] [(-r|--registry) registry] [-u|--tar_url] tarball_url] [project_directory]"
}
function cleanup () {
echo "Error during build"
exit 2
}

#
## Parse input options; may override value provided in properties file
#
while [ $# -ge 1 ]
do
key="${1}"
shift
case ${key} in
-t|--tag)
TAG="${1}"
shift
;;
-v|--version)
VERSION="${1}"
shift
;;
-b|--builder)
IMAGE_BUILDER="${1}"
shift
;;
-r|--registry)
REGISTRY="${1}"
shift
;;
-u|--tar_url)
TAR_URL="${1}"
shift
;;
-d|--dockerdir)
DOCKER_DIR="${1}"
shift
;;
--user)
REGISTRY_USERNAME="${1}"
shift
;;
--password)
REGISTRY_PASSWORD="${1}"
shift
;;
--email)
REGISTRY_EMAIL="${1}"
shift
;;
-h|--help)
usage
exit 0
;;
-d|--debug)
DEBUG=1
;;
*)
# assume is project_dir
PROJECT_DIR="${key}"
;;
esac
done

# If BOATYARD_BUILDER__URL is defined, set IMAGE_BUILDER from it (ie, override IMAGE_BUILDER from ENV).
# We still allow the command line to override this.
if [ -n "${BOATYARD_BUILDER__URL}" ]; then IMAGE_BUILDER=${BOATYARD_BUILDER__URL}; fi
# If DOCKER_REGISTRY__* is defined, set local variables from it (ie, override value defined in ENV).
# We still allow the command line to override this.
if [ -n "${DOCKER_REGISTRY__IMAGE_PREFIX}" ]; then REGISTRY=${DOCKER_REGISTRY__IMAGE_PREFIX}; fi
if [ -n "${DOCKER_REGISTRY__USER}" ]; then REGISTRY_USERNAME=${DOCKER_REGISTRY__USER}; fi
if [ -n "${DOCKER_REGISTRY__PASSWORD}" ]; then REGISTRY_PASSWORD=${DOCKER_REGISTRY__PASSWORD}; fi
if [ -n "${DOCKER_REGISTRY__EMAIL}" ]; then REGISTRY_EMAIL=${DOCKER_REGISTRY__EMAIL}; fi

# Identify the (IDS) build number
if [[ -z "$VERSION" ]]; then
	VERSION="latest"
fi

# todo: move this into an input so that this script can be more generally used 
# The full image_tag (registry/tag:version)
IMAGE_TAG=${REGISTRY}/${TAG}:${VERSION}
# Verify DOCKER_DIR is defined
if [[ -z "${DOCKER_DIR}" ]]; then DOCKER_DIR=.; fi

## Summarize inputs
#
if [[ "$DEBUG" -eq 1 ]]; then
	echo "Updated DOCKER_DIR=${DOCKER_DIR}"
	echo " IMAGE_BUILDER = ${IMAGE_BUILDER}"
	echo " TAR_URL = ${TAR_URL}"
	echo " REGISTRY_USERNAME = ${REGISTRY_USERNAME}"
	echo " REGISTRY_PASSWORD = ${REGISTRY_PASSWORD}"
	echo " REGISTRY = ${REGISTRY}"
	echo " PROJECT_DIR = ${PROJECT_DIR}"
	echo " DOCKER_DIR = ${DOCKER_DIR}"
	echo " REGISTRY_EMAIL = ${REGISTRY_EMAIL}"
	echo " TAG = ${TAG}"
fi 

BUILD_API="${IMAGE_BUILDER}/api/v1/build"

## Validate input
#
if [ -z "${TAG}" ]; then
usage
exit 1
fi
if [ -z "${IMAGE_BUILDER}" ]; then
usage
exit 1
fi
if [ -z "${REGISTRY}" ]; then
usage
exit 1
fi

#
## Create build request
#
#
# (1) The manifest file in json; include ${TAR_URL} if provided
# Example:
# {
# "image_name": ""
# "tar_url": "" # present only if $TAR_URL is set
# "username": "" # present only if $REGISTRY_USERNAME is set
# "password": "" # present only if $REGISTRY_PASSWORD is set
# "email": "" # present only if $REGISTRY_EMAIL is set
# }

MANIFEST_FILE=/tmp/manifest$$.json
printf "{\n" > ${MANIFEST_FILE}
# "image_name" :
printf " \"image_name\": \"${IMAGE_TAG}\"" >> ${MANIFEST_FILE}
# "tar_url": (maybe)
if [ -n "${TAR_URL}" ]; then
printf ",\n" >> ${MANIFEST_FILE}
printf " \"tar_url\": \"${TAR_URL}\"" >> ${MANIFEST_FILE}
fi
if [ -n "${REGISTRY_USERNAME}" ]; then
printf ",\n" >> ${MANIFEST_FILE}
printf " \"username\": \"${REGISTRY_USERNAME}\"" >> ${MANIFEST_FILE}
fi
if [ -n "${REGISTRY_PASSWORD}" ]; then
printf ",\n" >> ${MANIFEST_FILE}
printf " \"password\": \"${REGISTRY_PASSWORD}\"" >> ${MANIFEST_FILE}
fi
if [ -n "${REGISTRY_EMAIL}" ]; then
printf ",\n" >> ${MANIFEST_FILE}
printf " \"email\": \"${REGISTRY_EMAIL}\"" >> ${MANIFEST_FILE}
fi
printf "\n" >> ${MANIFEST_FILE}
printf "}\n" >> ${MANIFEST_FILE}
# (2) The tgz file, if not already provided
if [ -z "${TAR_URL}" ]; then
TAR_FILE=/tmp/project$$.tgz
pushd ${DOCKER_DIR}
#rjm: I assume this should be taring up the project dir 
cd ${PROJECT_DIR}
tar -z --exclude='.git/*' --create --file=${TAR_FILE} *
popd
fi
#
## POST request
#
if [[ "$DEBUG" -eq 1 ]]; then
	echo "Manifest:"
	echo "============"
	cat ${MANIFEST_FILE}
	echo "============"
fi 

#if [ ${DEBUG} -eq 0 ]; then
if [ -z "${TAR_URL}" ]; then
	if [[ "$DEBUG" -eq 1 ]]; then
		echo "Posting tarball: ${TAR_FILE}"
	fi 
	RESULT=`curl ${CURL_OPTIONS} ${BUILD_API} --form "TarFile=@${TAR_FILE};type=application/x-gzip" --form "Json=@${MANIFEST_FILE};type=application/json"`
else
	if [[ "$DEBUG" -eq 1 ]]; then
		echo "Posting tarball URL: ${TAR_URL}"
	fi 
	RESULT=`curl ${CURL_OPTIONS} --request POST ${BUILD_API} --data @${MANIFEST_FILE}`
fi
if [[ "$DEBUG" -eq 1 ]]; then
	echo "Result:"
	echo "============"
	echo ${RESULT}
	echo "============"
fi 
# if error then exit
if [[ ${RESULT} == *Failed* ]]; then
	echo "Error creating docker image"
	# need to clean up build server
	exit 1
fi
# Identify the job identifier and the query for status
JOB_IDENTIFIER=`echo "$RESULT" | grep JobIdentifier | sed 's/.*: "\(.*\)"/\1/'`
BUILD_STATUS_QUERY="${IMAGE_BUILDER}/api/v1/${JOB_IDENTIFIER}/status"
if [[ "$DEBUG" -eq 1 ]]; then
	echo "status query: ${BUILD_STATUS_QUERY}"
fi 
#BUILD_STATUS=`curl ${CURL_OPTIONS} ${BUILD_STATUS_QUERY} | grep Status | awk '{print $2}' | sed 's/^\"//' | sed 's/\"$//'`
QUERY_STATUS=$(curl ${CURL_OPTIONS} ${BUILD_STATUS_QUERY})
echo "Status: ${QUERY_STATUS}"
BUILD_STATUS=$(echo ${QUERY_STATUS} | grep Status | awk '{print $3}' | sed 's/^\"//' | sed 's/\"$//')
echo `date`">> ${BUILD_STATUS}"
if [[ ${BUILD_STATUS} == *Failed* ]]; then cleanup; fi
until [[ ${BUILD_STATUS} == *Finished* ]]; do
	sleep 30s
	QUERY_STATUS=$(curl ${CURL_OPTIONS} ${BUILD_STATUS_QUERY})
	echo "Status: ${QUERY_STATUS}"
	BUILD_STATUS=$(echo ${QUERY_STATUS} | grep Status | awk '{print $3}' | sed 's/^\"//' | sed 's/\"$//')
	echo `date`">> ${BUILD_STATUS}"
	if [[ ${BUILD_STATUS} == *Failed* ]]; then cleanup; fi
	if [[ "${BUILD_STATUS}" == "" ]]; then cleanup; fi
done
#fi
/bin/rm -f ${MANIFEST_FILE}
# Generate output
# Recall: IMAGE_TAG=${REGISTRY}/${TAG}:${VERSION}
read -d '' OUTPUT << EOF
{
"registry":"$REGISTRY",
"repository":"$TAG",
"tag":"$VERSION",
"image":"$IMAGE_TAG"
}
EOF

if [[ -z $__LOG__/ ]]; 
then
	echo $OUTPUT > $__LOG__/out ]]
else 
	echo -e "${label_color}Image details: ${no_color} $OUTPUT"
fi 
exit 0
