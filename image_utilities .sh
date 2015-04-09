#!/bin/bash

# Copyright 2015 IBM

if [ -z $IMAGE_LIMIT ]; then
    IMAGE_LIMIT=5
fi
if [ $IMAGE_LIMIT -gt 0 ]; then
    ice inspect images > inspect.log 2> /dev/null
    RESULT=$?
    if [ $RESULT -eq 0 ]; then
    	# find the number of images and check if greater then image limit
	    NUMBER_IMAGES=$(grep ${REGISTRY_URL}/${NAMESPACE} inspect.log | wc -l)
	    if [ $NUMBER_IMAGES -gt $IMAGE_LIMIT ]; then
	    	# create array of images name
	        ICE_IMAGES_ARRAY=$(grep ${REGISTRY_URL}/${NAMESPACE} inspect.log | awk '/Image/ {printf "%s\n", $2}' | sed 's/"//'g)
            ice ps > inspect.log 2> /dev/null
            RESULT=$?
            if [ $RESULT -eq 0 ]; then
                ICE_PS_IMAGES_ARRAY=$(grep -oh -e ${NAMESPACE}'\S*' inspect.log)
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