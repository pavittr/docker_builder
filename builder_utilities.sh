#!/bin/bash

#*******************************************************************************
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
#*******************************************************************************

# preferred method for using this code is to source this file, then call the
# pipeline_validate_full function.  To manually test, this script can be
# called as "pipeline_validate.sh --test myteststring".  Do not use the
# --test parameter in a source call, as it will exit() when done.

# predefined empty objects (no reserved words, no special handling case, etc)
NOSPECIAL="none"
NORESERVED=("")
# rules for the registry (namespace) name, taken from
# docker: registry/config.go:validateRemoteName()
# also, cannot begin or end with a hyphen, or have consecutive hyphens
# in docker 1.6, min will be 2, max will be 255
DEFNSMIN=4
DEFNSMAX=30
DEFNSRESERVED=$NORESERVED
DEFNSCHARS="a-z0-9._-"
NSSPECIAL="ns"
# rules for a tag, taken from docker: graph/tags.go:ValidateTagName()
DEFTAGMIN=1
DEFTAGMAX=128
DEFTAGRESERVED=$NORESERVED
DEFTAGCHARS="A-Za-z0-9._-"
TAGSPECIAL=$NOSPECIAL
# rules for a repo/image name, taken from docker: registry/config.go and
# graph/tags.go:validateRepoName()
# must not be 64 bytes and all hexadecimal
# no max length in code, putting -1 here as flag
DEFREPOMIN=1
DEFREPOMAX=-1
DEFREPORESERVED=("scratch")
DEFREPOCHARS="a-z0-9._-"
REPOSPECIAL="repo"

# parse a potentially full pipeline, of the form
# "host/namespace/repository:version"  Parsed values will be returned in env
# vars REGISTRY, IMAGENAME, and IMAGEVER, respectively.  If a piece is
# null, the respective env var will be as well. 
pipeline_parsefull() {
    if [ -z "$1" ]; then
                # nothing to parse, clear vars and return
        HOST=""
		REGISTRY=""
		IMAGENAME=""
		IMAGEVER=""
                return 1
	fi
	if [[ $1 =~ (.*)/(.*)/(.*):(.*) ]]; then
        HOST=${BASH_REMATCH[1]}
		REGISTRY=${BASH_REMATCH[2]}
		IMAGENAME=${BASH_REMATCH[3]}
		IMAGEVER=${BASH_REMATCH[4]}
	elif [[ $1 =~ (.*)/(.*):(.*) ]]; then
        REGISTRY=${BASH_REMATCH[1]}
        IMAGENAME=${BASH_REMATCH[2]}
        IMAGEVER=${BASH_REMATCH[3]}
    elif [[ $1 =~ (.*)/(.*) ]]; then
		REGISTRY=${BASH_REMATCH[1]}
		IMAGENAME=${BASH_REMATCH[2]}
		IMAGEVER=""
	elif [[ $1 =~ (.*):(.*) ]]; then
		REGISTRY=""
		IMAGENAME=${BASH_REMATCH[1]}
		IMAGEVER=${BASH_REMATCH[2]}
	else
		REGISTRY=""
		IMAGENAME=$1
		IMAGEVER=""
	fi
	return 0
}

# helper function to check for a string in an array of strings
pipeline_elementin() {
	local test=$1
	local arr=$2
	for i in "${arr[@]}"
	do
		if [ "$i" == "$test" ]; then
			return 1
		fi
	done
	return 0
}

# main worker function, validate a string against a set of passed parameters
# 1) the string to check
# 2) min length, must be integer number
# 3) max length, must be integer number, -1 for no max
# 4) list of valid characters for this string (e.g. "0-9a-z_.-")
# 5) special case processing, if any - supports "ns" and "repo", others ignored
# 6) string array of reserved words to check against
pipeline_validatename() { 
	local DEFAULTMIN=4
	local DEFAULTMAX=24
	local DEFAULTRESERVED=("")
	local DEFAULTCHARS="0-9a-z_.-"
	local min
	local max
	local reservednames
	local goodchars
	local special
	# get parms that modify behavior, or defaults if not passed
	# parm 2, max length, must be an integer number
	case $2 in
		''|*[!0-9]*) min=$DEFAULTMIN ;;
		*) min=$2 ;;
	esac
	# parm 3, max length, must be an integer number
        case $3 in
                ''|*[!0-9-]*) max=$DEFAULTMAX ;;
                *) max=$3 ;;
        esac
	# parm 4, string of valid chars for this name
	if [ -z "$4" ]; then
		goodchars=$DEFAULTCHARS
	else
		goodchars=$4
	fi
        # parm 5, what special processing needed for this string
        if [ -z "$5" ]; then
                special=$NOSPECIAL
        else
                special=$5
        fi
        # parm 6, array of reserved names for this name
        if [ -z "$6" ]; then
                reservednames=$DEFAULTRESERVED
        else
                reservednames=$6
        fi
	# get the actual string to test
	if [ -z "$1" ]; then
		# nothing to test, return
		echo "Fail - string is null"
		return 1
	else
		local name=$1
		local len=${#name}
		# check length min<=n<=max
		# if max is 0, no max
		if [ "$len" -lt "$min" ]; then
			echo "Fail - too short, must be at least $min characters long"
			return 2
		else
			if [ ! "$max" -eq "-1" ]; then
				if [ "$len" -gt "$max" ]; then
					echo "Fail - too long, cannot be more than $max characters long"
					return 3
				fi
			fi
		fi
		# do special processing, if any. do this before
		# valid char check, because can do more informative
		# error messages this way
		case $special in
			$NSSPECIAL) 
				# namespace quirks - cannot begin or
				# end with a hyphen, or have 2+ hyphens
				# in a row
				if [[ $name == "-"* ]]; then
					echo "Fail - namespace cannot begin with a hyphen"
					return 6
				elif [[ $name == *"-" ]]; then
					echo "Fail - namespace cannot end with a hyphen"
					return 7
				elif [[ $name == *"--"* ]]; then
					echo "Fail - namespace cannot contain two consecutive hyphens"
					return 8
				fi
				# also check for uppercase here, to make
				# the error message more useful
				echo $name | grep [A-Z]
				if [[ "$?" -eq "0" ]]; then
					echo "Fail - namespace may not contain uppercase letters"
					return 4
				fi
				;;
			$REPOSPECIAL) 
				# reponame quirks - if it is 64 chars
				# long, it must not be all valid hex
				# characters
				if [ $len -eq 64 ]; then
					if [[ ${name} =~ ^[[:xdigit:]]*$ ]]; then
						echo "Fail - name cannot be 64 hexadecimal digits as it may conflict with potential ids"
						return 9
					fi
				fi
                                # also check for uppercase here, to make
                                # the error message more useful
                                echo $name | grep [A-Z]
                                if [[ "$?" -eq "0" ]]; then
                                        echo "Fail - name may not contain uppercase letters"
                                        return 4
                                fi
				;;
			*)  ;;
		esac

		# check valid characters
		grep -qv "[^$goodchars]" <<< $name
		if [ ! $? -eq 0 ]; then
			echo "Fail - must only contain characters in the set \"$goodchars\""
			return 4
		fi

		# check reserved names
		pipeline_elementin $name $reservednames
		if [ ! $? -eq 0 ]; then
			echo "Fail - $name is a reserved word in this context"
			return 5
		fi
	
		echo "Success"
		return 0
	fi
}

# convenience function to validate a namespace against appropriate defaults
pipeline_validate_namespace() {
	pipeline_validatename $1 $DEFNSMIN $DEFNSMAX $DEFNSCHARS $NSSPECIAL $DEFNSRESERVED
}

# convenience function to validate an image name against appropriate defaults
pipeline_validate_imagename() {
	pipeline_validatename $1 $DEFREPOMIN $DEFREPOMAX $DEFREPOCHARS $REPOSPECIAL $DEFREPORESERVED 
}

# convenience function to validate an image version against appropriate defaults
pipeline_validate_imagever() {
	pipeline_validatename $1 $DEFTAGMIN $DEFTAGMAX $DEFTAGCHARS $TAGSPECIAL $DEFTAGRESERVED
}

# main function to call - first parses passed string into parts, then
# validates those parts appropriately for 
# "namespace/repository:version" format.
pipeline_validate_full() {
	local rc=0
	local rcc
	local outstr
        pipeline_parsefull $1
        if [ ! -z "$REGISTRY" ]; then
		outstr=$(pipeline_validate_namespace $REGISTRY)
		rcc=$?
                echo "Registry \"$REGISTRY\" $outstr"
		if [ $rc -eq 0 ]; then
			rc=$rcc
		fi
        fi
        if [ ! -z "$IMAGENAME" ]; then
		outstr=$(pipeline_validate_imagename $IMAGENAME)
		rcc=$?
                echo "Image name \"$IMAGENAME\" $outstr"
                if [ $rc -eq 0 ]; then
                        rc=$rcc
                fi
	else
		# null image name is parseable, but not valid, catch it here
		echo "Image name null!"
                if [ $rc -eq 0 ]; then
                        rc=1
                fi
        fi
        if [ ! -z "$IMAGEVER" ]; then
		outstr=$(pipeline_validate_imagever $IMAGEVER)
		rcc=$?
                echo "Image version \"$IMAGEVER\" $outstr"
                if [ $rc -eq 0 ]; then
                        rc=$rcc
                fi
        fi
	return $rc
}

# internal function, selfcheck unit test to make sure things are working
# as expected
unittest() {
	# test name validation
	pipeline_validatename >/dev/null
	if [ ! $? -eq 1 ]; then
		echo "ut fail (incorrect pass) on null parameter"
		return 1
	fi
	pipeline_validatename "thr" >/dev/null
	if [ ! $? -eq 2 ]; then
		echo "ut fail (incorrect pass) on short string"
		return 2
	fi
	pipeline_validatename "test" >/dev/null
	if [ ! $? -eq 0 ]; then
		echo "ut fail (incorrect fail) on 4 character string"
		return 3
	fi
	pipeline_validatename "123456789012345678901234" >/dev/null
		if [ ! $? -eq 0 ]; then
		echo "ut fail (incorrect fail) on 24 character string"
		return 4
	fi
	pipeline_validatename "1234567890123456789012345" >/dev/null
	if [ ! $? -eq 3 ]; then
		echo "ut fail (incorrect pass) on 25 character string"
		return 5
	fi
	pipeline_validatename "Test" >/dev/null
	if [ ! $? -eq 4 ]; then
		echo "ut fail (incorrect pass) on mixed case string"
		return 6
	fi
	pipeline_validatename "te-st.te_st" >/dev/null
	if [ ! $? -eq 0 ]; then
		echo "ut fail (incorrect fail) on valid character test"
		return 7
	fi
	pipeline_validatename "blahblah,.#@" >/dev/null
	if [ ! $? -eq 4 ]; then
		echo "ut fail (incorrect pass) on invalid character test"
		return 8
	fi
	pipeline_validatename "testingThis" >/dev/null 
	if [ ! $? -eq 4 ]; then
	        echo "ut fail (incorrect pass) on mixed case comment test"
	        return 9
	fi

	# test ns/repo/ver parser
	pipeline_parsefull >/dev/null
	if [ ! $? -eq 1 ]; then
		echo "ut fail (incorrect pass) on parse null string test"
		return 20
	fi
	local namespace="namespace"
	local repository="repository"
	local version="version"
	pipeline_parsefull "$namespace/$repository:$version" >/dev/null
	if [ ! $? -eq 0 ]; then
		echo "ut fail (incorrect fail) on parse n/r:v test"
		return 21
	elif [ ! "$REGISTRY" == "$namespace" ]; then
		echo "ut fail (incorrect parse) on namespace, parse n/r:v test"
		return 22
	elif [ ! "$IMAGENAME" == "$repository" ]; then
		echo "ut fail (incorrect parse) on repository, parse n/r:v test"
		return 23
	elif [ ! "$IMAGEVER" == "$version" ]; then
		echo "ut fail (incorrect parse) on version, parse n/r:v test"
		return 24
	fi
        pipeline_parsefull "$namespace/$repository" >/dev/null
        if [ ! $? -eq 0 ]; then
                echo "ut fail (incorrect fail) on parse n/r:v test"
                return 25
        elif [ ! "$REGISTRY" == "$namespace" ]; then
                echo "ut fail (incorrect parse) on namespace, parse n/r test"
                return 26
        elif [ ! "$IMAGENAME" == "$repository" ]; then
                echo "ut fail (incorrect parse) on repository, parse n/r test"
                return 27
        elif [ ! "$IMAGEVER@" == "@" ]; then
                echo "ut fail (incorrect parse) on version, parse n/r test"
                return 28
        fi
        pipeline_parsefull "$repository:$version" >/dev/null
        if [ ! $? -eq 0 ]; then
                echo "ut fail (incorrect fail) on parse r:v test"
                return 29
        elif [ ! "$REGISTRY@" == "@" ]; then
                echo "ut fail (incorrect parse) on namespace, parse r:v test"
                return 30
        elif [ ! "$IMAGENAME" == "$repository" ]; then
                echo "ut fail (incorrect parse) on repository, parse r:v test"
                return 31
        elif [ ! "$IMAGEVER" == "$version" ]; then
                echo "ut fail (incorrect parse) on version, parse r:v test"
                return 32
        fi
        pipeline_parsefull "$repository" >/dev/null
        if [ ! $? -eq 0 ]; then
                echo "ut fail (incorrect fail) on parse r test"
                return 33
        elif [ ! "$REGISTRY@" == "@" ]; then
                echo "ut fail (incorrect parse) on namespace, parse r test"
                return 34
        elif [ ! "$IMAGENAME" == "$repository" ]; then
                echo "ut fail (incorrect parse) on repository, parse r test"
                return 35
        elif [ ! "$IMAGEVER@" == "@" ]; then
                echo "ut fail (incorrect parse) on version, parse r test"
                return 36
        fi

	pipeline_validate_full "t-e_s.t/t-e_s.t:T-e_s.t" >/dev/null
	if [ ! $? -eq 0 ]; then
		echo "ut fail (incorrect fail) on validate n/r:v test"
		return 50
	fi
        pipeline_validate_full "t-e_s.t/t-e_s.t" >/dev/null
        if [ ! $? -eq 0 ]; then
                echo "ut fail (incorrect fail) on validate n/r test"
                return 51
        fi
        pipeline_validate_full "t-e_s.t:T-e_s.t" >/dev/null
        if [ ! $? -eq 0 ]; then
                echo "ut fail (incorrect fail) on validate r:v test"
                return 52
        fi
        pipeline_validate_full "t-e_s.t" >/dev/null
        if [ ! $? -eq 0 ]; then
                echo "ut fail (incorrect fail) on validate r test"
                return 53
        fi
        pipeline_validate_full "T-e_s.t/T-e_s.t:T-e_s.t" >/dev/null
        if [ ! $? -eq 4 ]; then
                echo "ut fail (incorrect pass) on validate !n/!r:v test"
                return 54
        fi
        pipeline_validate_full "t-e_s.t/T-e_s.t:T-e_s.t" >/dev/null
        if [ ! $? -eq 4 ]; then
                echo "ut fail (incorrect pass) on validate n/!r:v test"
                return 55
        fi
        pipeline_validate_full "t-e_s.t/scratch:T-e_s.t" >/dev/null
        if [ ! $? -eq 5 ]; then
                echo "ut fail (incorrect pass) on validate n/!r:v test (reserved word)"
                return 56
        fi
        pipeline_validate_full "-t-e_s.t/t-e_s.t" >/dev/null
        if [ ! $? -eq 6 ]; then
                echo "ut fail (incorrect pass) on validate !n/r test (beginning hyphen)" 
                return 57
        fi
        pipeline_validate_full "t-e_s.t-/t-e_s.t" >/dev/null
        if [ ! $? -eq 7 ]; then
                echo "ut fail (incorrect pass) on validate !n/r test (ending hyphen)"
                return 58
        fi
        pipeline_validate_full "t---e_s.t/t-e_s.t" >/dev/null
        if [ ! $? -eq 8 ]; then
                echo "ut fail (incorrect pass) on validate !n/r test (multiple hyphen)"
                return 57
        fi
        pipeline_validate_full "abcdef7890123456789012345678901234567890123456789012345678901234" >/dev/null
        if [ ! $? -eq 9 ]; then
                echo "ut fail (incorrect pass) on validate !r test (64 byte hex)"
                return 58
        fi
        pipeline_validate_full "abcdef78901234567890123456789012345678901234567890123456789012zz" >/dev/null
        if [ ! $? -eq 0 ]; then
                echo "ut fail (incorrect fail) on validate r test (64 byte non-hex)"
                return 59
        fi
        pipeline_validate_full "test/:test"  >/dev/null
        if [ ! $? -eq 1 ]; then
                echo "ut fail (incorrect pass) on validate n/:v test"
                return 60
        fi
        pipeline_validate_full "t/test:test"  >/dev/null
        if [ ! $? -eq 2 ]; then
                echo "ut fail (incorrect pass) on validate !n/r:v test (namespace too short)"
                return 61
        fi
        pipeline_validate_full "12345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890/test:test"  >/dev/null
        if [ ! $? -eq 3 ]; then
                echo "ut fail (incorrect pass) on validate !n/r:v test (namespace too long)"
                return 62
        fi
        pipeline_validate_full "test/test:t1234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890"  >/dev/null
        if [ ! $? -eq 3 ]; then
                echo "ut fail (incorrect pass) on validate n/r:!v test (tag too long)"
                return 63
        fi

        pipeline_validate_full "host.example.com/t-e_s.t/t-e_s.t:T-e_s.t" > /dev/null
        if [ ! $? -eq 0 ]; then
                echo "ut fail (incorrect fail) on validate h/n/!r:v test"
                return 55
        fi

	return 0
}

unittest
if [ ! $? -eq 0 ]; then
	echo "Unit test failed, aborting"
else
	# allow run the script with --test parameter to check script directly
	if [ "$1" == "--test" ]; then
		shift
		rc=0
		for i in $@
		do
			echo parsing $i
			pipeline_validate_full $i
			rcc=$?
	                if [ $rc -eq 0 ]; then
	                        rc=$rcc
	                fi
			shift
		done
		# only exit if running directly, if done in source will
		# kill the parent shell
		echo "Return code is $rc"
		exit $rc
	fi
fi
