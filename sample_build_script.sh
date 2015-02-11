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

#####################
# Run unit tests    #
#####################
echo "${label_color}No unit tests cases have been checked in ${no_color}"

######################################
# Build Container via Dockerfile     #
######################################
if [ -f Dockerfile ]; then 
    echo -e "${label_color}Building ${REGISTRY_URL}/${APPLICATION_NAME}:${APPLICATION_VERSION} ${no_color}"
    ice build --tag ${REGISTRY_URL}/${APPLICATION_NAME}:${APPLICATION_VERSION} ${WORKSPACE}
    RESULT=$?
    if [ $RESULT -ne 0 ]; then
        echo -e "${red}Error building image ${no_color}"
        echo "Build command: ice build --tag ${REGISTRY_URL}/${APPLICATION_NAME}:${APPLICATION_VERSION} ${WORKSPACE}"
        ice info 
        ice images
    else
        echo "${label_color}Container build successful"
        ice images 
    fi  
else 
    echo -e "${red}Dockerfile not found in project${no_color}"
    date >> ${ARCHIVE_DIR}/timestamp.log
    exit 1
fi  

########################################################################################
# Copy any artifacts that will be needed for deployment and testing to $archive_dir    #
########################################################################################
echo "Loggging build information (IMAGE_NAME) to build.properties"
date >> ${ARCHIVE_DIR}/timestamp.log
echo "IMAGE_NAME=${REGISTRY_URL}/${APPLICATION_NAME}:${APPLICATION_VERSION}" >> ${ARCHIVE_DIR}/build.properties 
more ${ARCHIVE_DIR}/build.properties