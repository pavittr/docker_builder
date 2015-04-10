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
        NUMBER_IMAGES=$(grep ${REGISTRY_URL} inspect.log | wc -l)
        echo "Number of images: $NUMBER_IMAGES and Image limit: $IMAGE_LIMIT"
        if [ $NUMBER_IMAGES -gt $IMAGE_LIMIT ]; then
            # create array of images name
            ICE_IMAGES_ARRAY=$(grep ${REGISTRY_URL} inspect.log | awk '/Image/ {printf "%s\n", $2}' | sed 's/"//'g)
            # loop the list of spaces under the org and find the name of the images that are in used
            cf spaces > inspect.log 2> /dev/null
            RESULT=$?
            if [ $RESULT -eq 0 ]; then
                # save current space first
                CURRENT_SPACE=`cf target | grep "Space:" | awk '{printf "%s", $2}'`
                FOUND=""
                cat inspect.log | while read space
                do
                    # cf spaces gives a couple lines of headers.  skip those until we find the line
                    # 'name', then read the rest of the lines as space names
                    if [ "${FOUND}x" == "x" ]; then
                        if [ "${space}X" == "nameX" ]; then
                            FOUND="y"
                        fi
                        continue
                    else
                        cf target -s ${space} 2> /dev/null
                        if [ $? -eq 0 ]; then

                            ice ps -q | awk '{print $1}' | xargs -n 1 ice inspect | grep "Image" | grep -oh -e nfritz_alchemy'\S*' | while read line
                            do
                                ICE_PS_IMAGES_ARRAY+="${line%\",}"
                            done
                        fi
                    fi
                done
                # restore my old space
                cf target -s ${CURRENT_SPACE} 2> /dev/null
                i=0
                j=0
                #echo $ICE_IMAGES_ARRAY
                #echo $ICE_PS_IMAGES_ARRAY
                for image in ${ICE_IMAGES_ARRAY[@]}
                do
                    #echo "IMAGES_ARRAY_NOT_USED-1: ${image}"
                    in_used=0
                    for image_used in ${ICE_PS_IMAGES_ARRAY[@]}
                    do
                        image_used=${REGISTRY_URL}/${image_used}
                        #echo "IMAGES_ARRAY_USED-2: ${image_used}"
                        if [ $image == $image_used ]; then
                            #echo "IMAGES_ARRAY_USED: ${image}"
                            IMAGES_ARRAY_USED[i]=$image
                            ((i++))
                            in_used=1
                            break
                        fi
                        #echo "IMAGES_ARRAY_NOT_USED: ${image}"
                        #j+=$j
                        #IMAGES_ARRAY_NOT_USED[j]=$image
                    done
                    if [ $in_used -eq 0 ]; then
                        #echo "IMAGES_ARRAY_NOT_USED: ${image}"
                        IMAGES_ARRAY_NOT_USED[j]=$image
                        ((j++))
                    fi
                done
                # if number of unused images greater then image limit, then delete unused images from oldest to newest until we are under the limit
                len_used=${#IMAGES_ARRAY_USED[*]}
                len_not_used=${#IMAGES_ARRAY_NOT_USED[*]}
                echo "number of images in used: ${len_used} and number of images not used: ${len_not_used}"
                echo "unused images: ${IMAGES_ARRAY_NOT_USED[@]}"
                echo "used images: ${IMAGES_ARRAY_USED[@]}"
                if [ $NUMBER_IMAGES -ge $IMAGE_LIMIT ]; then
                    while [ $NUMBER_IMAGES -ge $IMAGE_LIMIT ]
                    do
                        ((len_not_used--))
                        ((NUMBER_IMAGES--))
                        ice rmi ${IMAGES_ARRAY_NOT_USED[$len_not_used]} > /dev/null
                        RESULT=$?
                        if [ $RESULT -eq 0 ]; then
                            echo "deleting image success: ice rmi ${IMAGES_ARRAY_NOT_USED[$len_not_used]}"
                        else
                        	echo "deleting image failed: ice rmi ${IMAGES_ARRAY_NOT_USED[$len_not_used]}"
                        fi
                        if [ $len_not_used -le 0 ]; then
                            break
                        fi
                    done
                fi
            fi
        else
            echo "The number of images are less than the image limit"
        fi
    fi
fi
