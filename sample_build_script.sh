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


# The following colors have been defined to help with presentation of logs: green, red, label_color, no_color.  
echo -e "${label_color}Starting build script${no_color}"

# The IBM Container Service CLI (ice), Git client (git), IDS Inventory CLI (ids-inv) and Python 2.7.3 (python) have been installed.
# Based on the organization and space selected in the Job credentials are in place for both IBM Container Service and IBM Bluemix 
#####################
# Run unit tests    #
#####################
echo -e "${label_color}No unit tests cases have been checked in ${no_color}"

######################################
# Build Container via Dockerfile     #
######################################

# FULL_REPOSITORY_NAME={CONTAINER_SERVICE_HOST}/{USER_NAMESPACE}/{IMAGE_NAME}:{VERSION}

if [ -f Dockerfile ]; then 
    echo -e "${label_color}Building ${FULL_REPOSITORY_NAME} ${no_color}"
    BUILD_COMMAND=""
    if [ "${USE_CACHED_LAYERS}" == "true" ]; then 
        BUILD_COMMAND="build --pull --tag ${FULL_REPOSITORY_NAME} ${WORKSPACE}"
        ice_retry ${BUILD_COMMAND}
        RESULT=$?
    else 
        BUILD_COMMAND="build --no-cache --tag ${FULL_REPOSITORY_NAME} ${WORKSPACE}"
        ice_retry ${BUILD_COMMAND}
        RESULT=$?
    fi 

    if [ $RESULT -ne 0 ]; then
        echo -e "${red}Error building image ${no_color}"
        echo "Build command: ice ${BUILD_COMMAND}"
        ice_retry info 
        ice_retry images
        "${EXT_DIR}"/print_help.sh
        exit 1
    else
        echo -e "${green}Container build of ${FULL_REPOSITORY_NAME} was successful ${no_color}"
    fi  
else 
    echo -e "${red}Dockerfile not found in project${no_color}"
    exit 1
fi  

######################################################################################
# Copy any artifacts that will be needed for deployment and testing to $WORKSPACE    #
######################################################################################
echo "IMAGE_NAME=${FULL_REPOSITORY_NAME}" >> ${WORKSPACE}/build.properties
