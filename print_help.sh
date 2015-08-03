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

log_and_echo "$LABEL" "We are sorry you are having trouble."

if [ -n "$ERROR_LOG_FILE" ]; then
    if [ -e "${ERROR_LOG_FILE}" ]; then
        ERROR_COUNT=`wc "${ERROR_LOG_FILE}" | awk '{print $1}'` 
        if [ ${ERROR_COUNT} -eq 1 ]; then
            log_and_echo "$LABEL" "There was ${ERROR_COUNT} error message recorded during execution:"
        else
            log_and_echo "$LABEL" "There were ${ERROR_COUNT} error messages recorded during execution:"
        fi
        log_and_echo "$INFO" "$(cat "${ERROR_LOG_FILE}")"
    fi
fi

log_and_echo "$INFO" "There are a number of ways that you can get help:"
log_and_echo "$INFO" "1. Post a question on  https://developer.ibm.com/answers/ and 'Ask a question' with tags 'docker', 'containers' and 'devops-services'"
log_and_echo "$INFO" "2. Open a Work Item in our public devops project: https://hub.jazz.net/project/alchemy/Alchemy-Ostanes "
log_and_echo "$INFO" "" 
log_and_echo "$INFO" "You can also review and fork our sample scripts on https://github.com/Osthanes "