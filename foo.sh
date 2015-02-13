#!/bin/bash 
BUILD_NUMBER=4
CONTAINER_NAME="beta3demoapp"

PUBLIC_IP="unknown"
COUNTER=${BUILD_NUMBER}
let COUNTER-=1
until [  $COUNTER -lt 1 ]; do
    ice inspect ${CONTAINER_NAME}_${COUNTER} > inspect.log 
    RESULT=$?
    if [ $RESULT -eq 0 ]; then
        echo "Found previous container ${CONTAINER_NAME}_${COUNTER}"
        # does it have a public IP address 
        FLOATING_IP=$(cat inspect.log | grep "PublicIpAddress" | awk '{print $2}')
        temp="${FLOATING_IP%\"}"
        FLOATING_IP="${temp#\"}"
        if [ -z "${FOUND}" ]; then 
            # this is the first previous deployment I have found
            if [ -z "${FLOATING_IP}" ]; then 
                echo "${CONTAINER_NAME}_${COUNTER} did not have a floating IP so allocating one"
            else 
                echo "${CONTAINER_NAME}_${COUNTER} had a floating ip ${FLOATING_IP}"
                ice ip unbind ${FLOATING_IP} ${CONTAINER_NAME}_${COUNTER}
                ice ip bind ${FLOATING_IP} ${CONTAINER_NAME}_${BUILD_NUMBER}
                echo "keeping previous deployment: ${CONTAINER_NAME}_${COUNTER}"
            fi 
            FOUND="true"
        else 
            # remove
            echo "removing previous deployment: ${CONTAINER_NAME}_${COUNTER}" 
            echo "ice rm ${CONTAINER_NAME}_${COUNTER}"
        fi  
    fi 
    let COUNTER-=1
done
# check to see that I obtained a floating IP address
ice inspect ${CONTAINER_NAME}_${BUILD_NUMBER} > inspect.log 
FLOATING_IP=$(cat inspect.log | grep "PublicIpAddress" | awk '{print $2}')
if [ "${FLOATING_IP}" = '""' ]; then 
    echo "Requesting IP"
    FLOATING_IP=$(ice ip request | awk '{print $4}')
    echo "> ${FLOATING_IP}"
    RESULT=$?
    if [ $RESULT -ne 0 ]; then
        echo -e "${red}Failed to allocate IP address ${no_color}" 
        exit 1 
    fi
    temp="${FLOATING_IP%\"}"
    echo "$temp"
    FLOATING_IP="${temp#\"}"
    echo "$FLOATING_IP"
    ice ip bind ${FLOATING_IP} ${CONTAINER_NAME}_${BUILD_NUMBER}
    RESULT=$?
    if [ $RESULT -ne 0 ]; then
        echo -e "${red}Failed to bind ${FLOATING_IP} to ${CONTAINER_NAME}_${BUILD_NUMBER} ${no_color}" 
        exit 1 
    fi 
fi 
echo -e "${label_color}Public IP address of ${CONTAINER_NAME}_${BUILD_NUMBER} is ${FLOATING_IP} ${no_color}"
