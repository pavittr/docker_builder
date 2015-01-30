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

#########################
# Build docker image    #
#########################
# check if there is a Dockerfile and if so build it
if [ -f Dockerfile ]; then 
    echo -e "${label_color}Building ${REGISTRY_URL}/${APPLICATION_NAME}:${APPLICATION_VERSION} ${no_color}"
    builder_boatyard.sh -t ${REPOSITORY}/${APPLICATION_NAME} -v ${APPLICATION_VERSION} -r ${REGISTRY_SERVER} -b ${BUILDER} --user ${DOCKER_REGISTRY_USER} --password ${API_KEY} --email ${DOCKER_REGISTRY_EMAIL} $WORKSPACE
    RESULT=$?
    if [ $RESULT -ne 0 ]; then
        echo -e "${red}Failed to build and publish image successfully${no_color}"
        echo -e "${label_color}Please check your REGISTRY_URL and API_KEY settings for the project"
        exit $RESULT
    else 
        echo -e "${green}(docker-builder) Building Docker Image Complete${no_color}"
    fi 
else 
    echo -e "${red}Dockerfile not found in project${no_color}"
    date >> $archive_dir/timestamp.log
    exit 1
fi  

########################################################################################
# Copy any artifacts that will be needed for deployment and testing to $archive_dir    #
########################################################################################
date >> $archive_dir/timestamp.log