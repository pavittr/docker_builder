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

if [ "${NAMESPACE}X" == "X" ]; then
    echo "NAMESPACE must be set in the environment before calling this script."
    exit 1
fi

if [ -z $IMAGE_LIMIT ]; then
    IMAGE_LIMIT=5
fi
if [ $IMAGE_LIMIT -gt 0 ]; then
    ice inspect images > inspect.log 2> /dev/null
    RESULT=$?
    if [ $RESULT -eq 0 ]; then
        # find the number of images and check if greater then image limit
        NUMBER_IMAGES=$(grep ${REGISTRY_URL}/${IMAGE_NAME} inspect.log | wc -l)
        echo "Number of images: $NUMBER_IMAGES and Image limit: $IMAGE_LIMIT"
        if [ $NUMBER_IMAGES -gt $IMAGE_LIMIT ]; then
            # create array of images name
            ICE_IMAGES_ARRAY=$(grep ${REGISTRY_URL}/${IMAGE_NAME} inspect.log | awk '/Image/ {printf "%s\n", $2}' | sed 's/"//'g)
            # loop the list of spaces under the org and find the name of the images that are in used
            cf spaces > inspect.log 2> /dev/null
            RESULT=$?
            if [ $RESULT -eq 0 ]; then
                # save current space first
                CURRENT_SPACE=`cf target | grep "Space:" | awk '{printf "%s", $2}'`
                FOUND=""
                SPACE_ARRAY=$(cat inspect.log)
                for space in ${SPACE_ARRAY[@]}
                do
                    # cf spaces gives a couple lines of headers.  skip those until we find the line
                    # 'name', then read the rest of the lines as space names
                    if [ "${FOUND}x" == "x" ]; then
                        if [ "${space}X" == "nameX" ]; then
                            FOUND="y"
                        fi
                        continue
                    else
                        cf target -s ${space} > /dev/null
                        if [ $? -eq 0 ]; then
                            ICE_PS_IMAGES_ARRAY+=$(ice ps -q | awk '{print $1}' | xargs -n 1 ice inspect | grep "Image" | grep -oh -e ${NAMESPACE}/${IMAGE_NAME}:[0-9]*)
                            ICE_PS_IMAGES_ARRAY+=" "
                        fi
                    fi
                done
                # restore my old space
                cf target -s ${CURRENT_SPACE} > /dev/null
                i=0
                j=0
                #echo "images array:"
                #echo $ICE_IMAGES_ARRAY
                #echo "ps images array"
                #echo $ICE_PS_IMAGES_ARRAY
                for image in ${ICE_IMAGES_ARRAY[@]}
                do
                    #echo "IMAGES_ARRAY_NOT_USED-1: ${image}"
                    in_used=0
                    for image_used in ${ICE_PS_IMAGES_ARRAY[@]}
                    do
                        image_used=${CCS_REGISTRY_HOST}/${image_used}
                        #echo "IMAGES_ARRAY_USED-2: ${image_used}"
                        if [ $image == $image_used ]; then
                            #echo "IMAGES_ARRAY_USED: ${image}"
                            IMAGES_ARRAY_USED[i]=$image
                            ((i++))
                            in_used=1
                            break
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
                echo "number of images in use: ${len_used} and number of images not in use: ${len_not_used}"
                echo "unused images: ${IMAGES_ARRAY_NOT_USED[@]}"
                echo "used images: ${IMAGES_ARRAY_USED[@]}"
                if [ $NUMBER_IMAGES -ge $IMAGE_LIMIT ]; then
                    if [ $len_not_used -ge 0 ]; then
                        while [ $NUMBER_IMAGES -ge $IMAGE_LIMIT ]
                        do
                            ((len_not_used--))
                            ((NUMBER_IMAGES--))
                            ice rmi ${IMAGES_ARRAY_NOT_USED[$len_not_used]} > /dev/null
                            RESULT=$?
                            if [ $RESULT -eq 0 ]; then
                                echo "deleting image success: ice rmi ${IMAGES_ARRAY_NOT_USED[$len_not_used]}"
                            else
                                echo -e "${red}deleting image failed: ice rmi ${IMAGES_ARRAY_NOT_USED[$len_not_used]}${no_color}"
                            fi
                            if [ $len_not_used -le 0 ]; then
                                break
                            fi
                        done
                    else
                        echo -e "${label_color}No unused images found.${no_color}"
                    fi
                    if [ $len_used -ge $IMAGE_LIMIT ]; then
                        echo -e "${label_color}Warning: More than ${IMAGE_LIMIT} images are currently in use.  Consider increasing IMAGE_LIMIT.${no_color}"
                    fi
                fi
            else
                echo -e "${red}Unable to read cf spaces.  Could not check for used images.{$no_color}"
            fi
        else
            echo "The number of images are less than the image limit"
        fi
    else
        echo -e "${red}Failed to get image list from ice.  Check ice login.${no_color}"
    fi
fi
