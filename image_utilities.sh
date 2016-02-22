#!/bin/bash

#********************************************************************************
# Copyright 2015 IBM
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

debugme() {
  [[ $DEBUG = 1 ]] && "$@" || :
}

if [ -f ${EXT_DIR}/cf ]; then
   CFCMD=${EXT_DIR}/cf
else
   CFCMD=cf
   debugme ls ${EXT_DIR}
fi
log_and_echo "$DEBUGGING" "cf is $CFCMD"

if [ "${NAMESPACE}X" == "X" ]; then
    log_and_echo "$ERROR" "NAMESPACE must be set in the environment before calling this script."
    exit 1
fi

if [ -z $IMAGE_LIMIT ]; then
    IMAGE_LIMIT=5
fi
if [ $IMAGE_LIMIT -gt 0 ]; then
    ice_retry_save_output inspect images 2> /dev/null
    RESULT=$?
    if [ $RESULT -eq 0 ]; then
        # find the number of images and check if greater than or equal to image limit
        NUMBER_IMAGES=$(grep "${REGISTRY_URL}/${IMAGE_NAME}:[0-9]\+" iceretry.log | grep \"Image\": | wc -l)
        log_and_echo "Number of images: $NUMBER_IMAGES and Image limit: $IMAGE_LIMIT"
        if [ $NUMBER_IMAGES -ge $IMAGE_LIMIT ]; then
            # create array of images name
            ICE_IMAGES_ARRAY=$(grep "${REGISTRY_URL}/${IMAGE_NAME}:[0-9]\+" iceretry.log | awk '/Image/ {printf "%s\n", $2}' | sed 's/"//'g | sed 's/,//'g)
            # loop the list of spaces under the org and find the name of the images that are in used
            $CFCMD spaces > inspect.log 2> /dev/null
            RESULT=$?
            debugme echo "cf spaces output:"
            debugme cat inspect.log
            debugme echo "end cf spaces output"
            if [ $RESULT -eq 0 ]; then
                # save current space first
                $CFCMD target > target.log 2> /dev/null
                debugme cat target.log
                #Use Show only matching chars option in grep to allow spaces in the current space name
                CURRENT_SPACE=$(grep '^Space:' target.log | awk -F: '{print $2;}' | sed 's/^ *//g' | sed 's/ *$//g')
                log_and_echo "$DEBUGGING" "current space is $CURRENT_SPACE"
                FOUND=""
                TESTED_ALL=true
                #Build space array as an array to properly handle spaces in space names
                SPACE_ARRAY=()
                while read line; do 
                    SPACE_ARRAY+=("$line"); 
                done < inspect.log;
                #Array needs to be in quotes to properly handle spaces in space names
                for space in "${SPACE_ARRAY[@]}"
                do
                    # cf spaces gives a couple lines of headers.  skip those until we find the line
                    # 'name', then read the rest of the lines as space names
                    if [ "${FOUND}x" == "x" ]; then
                        if [ "${space}X" == "nameX" ]; then
                            FOUND="y"
                        fi
                        continue
                    else
                        $CFCMD target -s "${space}" > target.log 2> /dev/null
                        RESULT=$?
                        debugme cat target.log
                        if [ $RESULT -eq 0 ]; then
                            log_and_echo "$DEBUGGING" "Checking space ${space}"
                            if [ "$USE_ICE_CLI" = "1" ]; then
                                ice_retry_save_output ps -q -a
                                ICE_PS_IMAGES_ARRAY+=$(awk '{print $1}' iceretry.log | xargs -n 1 ice inspect 2>/dev/null | grep "Image" | grep -oh -e "${NAMESPACE}/${IMAGE_NAME}:[0-9]\+")
                            else
                                ice_retry init &> /dev/null
                                RESULT=$?
                                if [ $RESULT -eq 0 ]; then 
                                    ice_retry_save_output ps -a
                                    ICE_PS_IMAGES_ARRAY+=$(awk '{print $2}' iceretry.log | grep -oh -e "${NAMESPACE}/${IMAGE_NAME}:[0-9]\+")
                                else
                                    $IC_COMMAND init
                                    log_and_echo "$ERROR" "$IC_COMMAND init command failed for space ${space}.  Could not check for used images for space ${space}."
                            fi
                            ICE_PS_IMAGES_ARRAY+=" "
                        else
                            log_and_echo "$ERROR" "Unable to change to space ${space}.  Could not check for used images."
                            TESTED_ALL=false
                        fi
                    fi
                done
                # restore my old space
                $CFCMD target -s "${CURRENT_SPACE}" > target.log 2> /dev/null
                debugme cat target.log
                if [ "$TESTED_ALL" = true ] ; then
                    i=0
                    j=0
                    log_and_echo "$DEBUGGING" "images array: ${ICE_IMAGES_ARRAY}"
                    log_and_echo "$DEBUGGING" "ps images array: ${ICE_PS_IMAGES_ARRAY}"
                    for image in ${ICE_IMAGES_ARRAY[@]}
                    do
                        in_used=0
                        for image_used in ${ICE_PS_IMAGES_ARRAY[@]}
                        do
                            image_used=${CCS_REGISTRY_HOST}/${image_used}
                            if [ $image == $image_used ]; then
                                log_and_echo "$DEBUGGING" "${image} used by ${image_used}"
                                IMAGES_ARRAY_USED[i]=$image
                                ((i++))
                                in_used=1
                                break
                            else
                                log_and_echo "$DEBUGGING" "${image} was not used by ${image_used}"
                            fi 
                        done
                        if [ $in_used -eq 0 ]; then
                            #echo "IMAGES_ARRAY_NOT_USED: ${image}"
                            IMAGES_ARRAY_NOT_USED[j]=$image
                            ((j++))
                        fi
                    done
                    # if number of images greater then image limit, then delete unused images from oldest to newest until we are under the limit or out of unused images
                    len_used=${#IMAGES_ARRAY_USED[*]}
                    len_not_used=${#IMAGES_ARRAY_NOT_USED[*]}
                    log_and_echo "number of images in use: ${len_used} and number of images not in use: ${len_not_used}"
                    log_and_echo "unused images: ${IMAGES_ARRAY_NOT_USED[@]}"
                    log_and_echo "used images: ${IMAGES_ARRAY_USED[@]}"
                    if [ $NUMBER_IMAGES -ge $IMAGE_LIMIT ]; then
                        if [ $len_not_used -gt 0 ]; then
                            while [ $NUMBER_IMAGES -ge $IMAGE_LIMIT ]
                            do
                                ((len_not_used--))
                                ((NUMBER_IMAGES--))
                                if [ "${IMAGE_REMOVE}" == "FALSE" ]; then 
                                    echo "NOT removing image"
                                    echo "$IC_COMMAND rmi ${IMAGES_ARRAY_NOT_USED[$len_not_used]} > /dev/null"
                                    RESULT=1
                                else 
                                    ice_retry rmi ${IMAGES_ARRAY_NOT_USED[$len_not_used]} > /dev/null
                                    RESULT=$?
                                    RESPONSE=${RET_RESPONCE}
                                fi 
                                if [ $RESULT -eq 0 ]; then
                                    log_and_echo "successfully deleted image: $IC_COMMAND rmi ${IMAGES_ARRAY_NOT_USED[$len_not_used]}"
                                else
                                    log_and_echo "$ERROR" "deleting image failed: $IC_COMMAND rmi ${IMAGES_ARRAY_NOT_USED[$len_not_used]}"
                                    log_and_echo "$ERROR" "${RESPONSE}"
                                fi
                                if [ $len_not_used -le 0 ]; then
                                    break
                                fi
                            done
                        else
                            log_and_echo "$LABEL" "No unused images found."
                        fi
                        if [ $len_used -ge $IMAGE_LIMIT ]; then
                            log_and_echo "$WARN" "Warning: Too many images in use.  Unable to meet ${IMAGE_LIMIT} image limit.  Consider increasing IMAGE_LIMIT."
                        fi
                    fi
                else
                    log_and_echo "$ERROR" "Unable to check all spaces for used containers, not removing"
                fi
            else
                log_and_echo "$ERROR" "Unable to read cf spaces.  Could not check for used images."
            fi
        else
            log_and_echo "The number of images are less than the image limit"
        fi
    else
        log_and_echo "$ERROR" "Failed to get image list from $IC_COMMAND.  Check $IC_COMMAND login."
    fi
fi
