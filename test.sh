#!/bin/bash


if [ -z $IP_LIMIT ]; then 
    export IP_LIMIT=2
fi 
if [ -z $CONTAINER_LIMIT ]; then 
    export CONTAINER_LIMIT=8
fi 
WARNING_LEVEL="$(echo "$CONTAINER_LIMIT - 2" | bc)"
CONTAINER_COUNT=$(ice ps -q | wc -l | sed 's/^ *//') 
if [ ${CONTAINER_COUNT} -ge ${CONTAINER_LIMIT} ]; then 
    echo -e "${red}You have ${CONTAINER_COUNT} containers running, and may reached the default limit on the number of containers ${no_color}"
elif [ $CONTAINER_COUNT -ge $WARNING_LEVEL ]; then
    echo -e "${label_color}There are ${CONTAINER_COUNT} containers running, which is approaching the limit of ${CONTAINER_LIMIT}${no_color}"
fi 

IP_COUNT_REQUESTED=$(ice ip list --all | grep "Number" | sed 's/.*: \([0-9]*\).*/\1/')
IP_COUNT_AVAILABLE=$(ice ip list | grep "Number" | sed 's/.*: \([0-9]*\).*/\1/')
echo "Number of IP Addresses currently requested: $IP_COUNT_REQUESTED"
echo "Number of requested IP Addresses that are still available: $IP_COUNT_AVAILABLE"
AVAILABLE="$(echo "$IP_LIMIT - $IP_COUNT_REQUESTED + $IP_COUNT_AVAILABLE" | bc)"

if [ ${AVAILABLE} -eq 0 ]; then 
    echo -e "${red}You have reached the default limit for the number of available public IP addresses${no_color}"
else
    echo -e "${label_color}You have ${AVAILABLE} public IP addresses remaining${no_color}"
fi  


