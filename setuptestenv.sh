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

# setup some variables that IDS would configure for testing 
export REGISTRY_URL="registry-ice.ng.bluemix.net/icedevops"
export API_URL="https://api-ice.ng.bluemix.net/v1.0"
export BUILDER="http://198.23.108.133"
export APPLICATION_NAME="testapp"
export WORKSPACE="/Users/robbie/experiments/docker-demo/ice-pipeline-demo"
export EXT_DIR="/Users/robbie/experiments/docker-demo/pipelineservice-docker-builder"
export ARCHIVE_DIR="/tmp/archive"
export API_KEY="3d48cd0fbf6c30838eacf6b4a3e34ce13cb72bac7db92d6a"
export DEBUG=1

