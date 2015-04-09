# VERSION 0.2
# DOCKER-VERSION 0.3.4
# To build:
# 1. Install docker (http://docker.io)
# 2. Checkout source: git@github.com:gasi/docker-node-hello.git
# 3. Build container: docker build .

FROM   ubuntu:trusty 

RUN    apt-get update -qq
RUN    apt-get install -q -y --force-yes nodejs
RUN    apt-get install -q -y --force-yes npm
# App
ADD . /src
# Install app dependencies
RUN cd /src; npm install

EXPOSE  8080
CMD ["nodejs", "/src/index.js"]
