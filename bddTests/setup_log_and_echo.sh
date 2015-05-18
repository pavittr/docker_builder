
if [[ ! "$(declare -f -F log_and_echo)" ]]; then
    echo "Setting up log_and_echo to just echo with color"
    INFO="INFO_LEVEL"
    LABEL="LABEL_LEVEL"
    WARN="WARN_LEVEL"
    ERROR="ERROR_LEVEL"

    INFO_LEVEL=4
    WARN_LEVEL=2
    ERROR_LEVEL=1
    OFF_LEVEL=0
    
    log_and_echo() {
        local MSG_TYPE="$1"
        if [ "$INFO" == "$MSG_TYPE" ]; then
            shift
            local pre=""
            local post=""
        elif [ "$LABEL" == "$MSG_TYPE" ]; then
            shift
            local pre="${label_color}"
            local post="${no_color}"
        elif [ "$WARN" == "$MSG_TYPE" ]; then
            shift
            local pre="${label_color}"
            local post="${no_color}"
        elif [ "$ERROR" == "$MSG_TYPE" ]; then
            shift
            local pre="${red}"
            local post="${no_color}"
        else
            #NO MSG type specified; fall through to INFO level
            #Do not shift
            local pre=""
            local post=""
        fi
        local L_MSG=`echo -e "$*"`
        echo -e "${pre}${L_MSG}${post}"
    }
    export -f log_and_echo
	# export message types for log_and_echo
	# ERRORs will be collected
	export INFO
	export LABEL
	export WARN
	export ERROR

	#export logging levels for log_and_echo
	# messages will be logged if LOGGER_LEVEL is set to or above the LEVEL
	# default LOGGER_LEVEL is WARN_LEVEL
	export INFO_LEVEL
	export WARN_LEVEL
	export ERROR_LEVEL
	export OFF_LEVEL
fi