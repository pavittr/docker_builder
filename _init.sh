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

#############
# Colors    #
#############
export green='\e[0;32m'
export red='\e[0;31m'
export label_color='\e[0;33m'
export no_color='\e[0m' # No Color

##################################################
# Simple function to only run command if DEBUG=1 # 
### ###############################################
debugme() {
  [[ $DEBUG = 1 ]] && "$@" || :
}
export -f debugme 

set +e

########################
# REGISTRY INFORMATION #
########################
        
# Setup the default registry to be the demo account 
if [ -z $REGISTRY_URL ]; then
    echo -e "${red}Please set REGISTRY_URL in the environment${no_color}"
    exit 1
fi

# Parse out information from the registry url 
export REGISTRY_SERVER=${REGISTRY_URL%/*}
export REPOSITORY=${REGISTRY_URL##*/}
if [ -z "$DOCKER_REGISTRY_PROTOCOL" ]; then
    export DOCKER_REGISTRY_PROTOCOL="https://"
fi
if [ -z "$DOCKER_REGISTRY_EMAIL" ]; then
    export DOCKER_REGISTRY_EMAIL='ignore@us.ibm.com'
fi
if [ -z "$DOCKER_REGISTRY_USER" ]; then
    export DOCKER_REGISTRY_USER=$REPOSITORY
fi

# Setup the default registry to be the demo account 
if [ -z "$API_URL" ]; then
    export API_URL="https://api-ice.ng.bluemix.net/v1.0"
fi

# Location of Boatyard builder
if [[ -z $BUILDER ]]; then
    export BUILDER="http://198.23.108.133"
    #export BUILDER=http://50.22.19.253 
fi

########################
# Bluemix information  #
########################
#  ice --verbose login --cf -H api-ice.stage1.ng.bluemix.net/ -R registry-ice.stage1.ng.bluemix.net/ --api api.stage1.ng.bluemix.net
# CCS host url         : https://api-ice.stage1.ng.bluemix.net//v2/containers
# Registry host        : registry-ice.stage1.ng.bluemix.net/
# Bluemix api url      : api.stage1.ng.bluemix.net
# Bluemix Org          : rjminsha@us.ibm.com (ea3dbb75-8f5d-4960-b3db-dd755e60ce9c)
# Bluemix Space        : dev (570e8a76-a833-45b0-ad50-846947fc9da1)
if [ -n "$BLUEMIX_TARGET" ]; then
    if [ "$BLUEMIX_TARGET" == "staging" ]; then 
        export CCS_API_HOST="api-ice.stage1.ng.bluemix.net" 
        export CCS_REGISTRY_HOST="registry-ice.stage1.ng.bluemix.net"
        export BLUEMIX_API_HOST="api.stage1.ng.bluemix.net"
        if [ -z "$BLUEMIX_USER" ]; then 
            echo -e "${red} Please set BLUEMIX_USER on environment ${no_color} "
            exit 1
        fi 
        if [ -z "$BLUEMIX_PASSWORD" ]; then 
            echo -e "${red} Please set BLUEMIX_USER on environment ${no_color} "
            exit 1 
        fi 
        if [ $REGISTRY_SERVER == $CCS_REGISTRY_HOST ]; then 
            echo "Targeting CCS_API_HOST ${CCS_API_HOST},CCS_REGISTRY_HOST ${CCS_REGISTRY_HOST}, ${BLUEMIX_API_HOST} "
        else
            echo -e "${red}Registry specified in target ( ${REGISTRY_SERVER} ) does not match the registry specified as a parameter ( ${CCS_REGISTRY_HOST} ) ${no_color}"  
            exit 1
        fi 
    else 
        echo -e "${red}Unknown ${BLUEMIX_TARGET} specified"
    fi 
else 
    echo "Reading bluemix target environment from pipeline configuration"
    echo -e "${label_color}TBD: load information from Cloud Fourndry credentials ${no_color}"
fi 

################################
# Application Name and Version #
################################

# The build number for the builder is used for the version in the image tag 
# For deployers this information is stored in the $BUILD_SELECTOR variable and can be pulled out
if [ -z "$APPLICATION_VERSION" ]; then
    export SELECTED_BUILD=$(grep -Eo '[0-9]{1,100}' <<< "${BUILD_SELECTOR}")
    if [ -z $SELECTED_BUILD ]
    then 
        if [ -z $BUILD_NUMBER ]
        then 
            export APPLICATION_VERSION=$(date +%s)
        else 
            export APPLICATION_VERSION=$BUILD_NUMBER    
        fi
    else
        export APPLICATION_VERSION=$SELECTED_BUILD
    fi 
fi 
echo "APPLICATION_VERSION: $APPLICATION_VERSION"

if [ -z $APPLICATION_NAME ]; then 
    echo -e "${red}setting application name to helloworld, please set APPLICATION_NAME in the environment to desired name ${no_color}"
    exit 1
fi 

################################
# Setup archive information    #
################################
if [ -z $WORKSPACE ]; then 
    echo -e "${red}Please set REGISTRY_URL in the environment${no_color}"
    exit 1
fi 

if [ -z $ARCHIVE_DIR ]; then 
    echo "${label_color}ARCHIVE_DIR was not set, setting to WORKSPACE/archive ${no_color}"
    export archive_dir="${WORKSPACE}/archive"
else 
    export archive_dir=${ARCHIVE_DIR}
fi 

if [ -d "$archive_dir" ]; then
  echo "Archiving to $archive_dir"
else 
  echo "Creating archive directory $archive_dir"
  mkdir $archive_dir 
fi 

#######################################
# Authorization and Authentication    #
#######################################

# if [ -z $API_KEY ]; then
#    if [[ "$DEBUG" == 1 ]] || [[ "$BUILD_USER" == "minshallrobbie" ]] || [[ "$CF_APP" == "ice-pipeline-demo" ]] || [[ "$CF_ORG" == "rjminsha@us.ibm.com" ]] || [[ "$GIT_URL" == "https://hub.jazz.net/git/rjminsha/ice-pipeline-demo" ]] || [[ "$GIT_URL" == "https://hub.jazz.net/git/rjminsha/container-pipeline-demo" ]]; then
#        echo -e "${label_color}Using demo API key, please update set API_KEY in the environment${no_color}"
#        export API_KEY="a8fef97b461bd17b0c5c491b6b04d3f38f4b7e398d32c21a"
#    else 
#        echo -e "${red}API_KEY must be set in the environement.  Add this in setenv.sh in the root of your project. ${no_color}"
#        exit 1
#    fi 
#else
#    echo "API_KEY set on the environment"
#fi  

######################
# Install ICE CLI    #
######################
debugme echo "##################"
debugme echo "installing ICE"
debugme echo "##################"
ice help 
RESULT=$?
if [ $RESULT -ne 0 ]; then
    pushd . 
    cd $EXT_DIR
    sudo apt-get -y install python2.7
    python --version 
    python get-pip.py --user
    export PATH=$PATH:~/.local/bin
    pip --version 
    pip install --user icecli-1.0-0129.zip
    #pip install --user icecli-2.0.zip
    ice help
    RESULT=$?
    if [ $RESULT -ne 0 ]; then
        echo -e "${red}Failed to install IBM Container Service CLI ${no_color}"
        debugme echo -e "${label}Is python installed ${no_color}"
        debugme python --version
        debugme which python 
        debugme echo $PATH
        exit $RESULT
    fi 
    popd 
    echo -e "${label_color}Successfully installed IBM Container Service CLI ${no_color}"
fi 

################################
# Login to Container Service   #
################################
if [ -n "$API_KEY" ]; then 
    echo -e "${label_color}Logging on with API_KEY${no_color}"
    ice login --key ${API_KEY}
    RESULT=$?
elif [[ -n "$BLUEMIX_TARGET" ]]; then
     #statements 
#  ice --verbose login --cf -H api-ice.stage1.ng.bluemix.net/ -R registry-ice.stage1.ng.bluemix.net/ --api api.stage1.ng.bluemix.net
#        export CCS_API_HOST="api-ice.stage1.ng.bluemix.net" 
#        export CCS_REGISTRY_HOST="api-ice.stage1.ng.bluemix.net"
#        export BLUEMIX_API_HOST="api.stage1.ng.bluemix.net"
    echo -e "${label_color}Logging via environment properties${no_color}"
    ice login --cf -H ${CCS_API_HOST} -R ${CCS_REGISTRY_HOST} --api ${BLUEMIX_API_HOST}
    RESULT=$?
else 
    echo -e "${red}TBD: support for token passed from pipeline via Cloud Foundry ${no_color}"
    exit 1 
fi 

if [ $RESULT -eq 1 ]; then
    echo -e "${red}Failed to login to IBM Container Service${no_color}"
    exit $RESULT
fi 


###############################
# Configure extension PATH    #
###############################
if [ -n $EXT_DIR ]; then 
    export PATH=$EXT_DIR:$PATH
fi 

########################
# Debug Information    #
########################
if [[ "$DEBUG" -eq 1 ]]; then
    env
    echo "******************************************************************************"
    echo "Registry URL: $REGISTRY_URL"
    echo "Registry Server: $REGISTRY_SERVER"
    echo "My repository: $REPOSITORY"
    echo "APPLICATION_VERSION: $APPLICATION_VERSION"
    echo "APPLICATION_NAME: $APPLICATION_NAME"
    echo "BUILDER: $BUILDER"
    echo "WORKSPACE: $WORKSPACE"
    echo "ARCHIVE_DIR: $ARCHIVE_DIR"
    echo "EXT_DIR: $EXT_DIR"
    echo "PATH: $PATH"
    echo "******************************************************************************"
fi

