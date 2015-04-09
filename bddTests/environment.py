import os
import subprocess
import shutil
import re
import time

def before_feature(context, feature):
    #os.environ["REGISTRY_URL"] = "registry-ice.ng.bluemix.net/jgarcows"
    #os.mkdir("workspace")
    os.environ["WORKSPACE"] = "."
    os.chdir("simpleDocker")
    #os.mkdir("archive")
    #os.environ["ARCHIVE_DIR"] = "archive"
    os.environ["APPLICATION_NAME"] = "fakeapp"
    context.appName = os.environ["APPLICATION_NAME"]
    os.environ["APPLICATION_VERSION"] = "30"
    context.appVer = os.environ["APPLICATION_VERSION"]
    
def after_feature(context, feature):
    #shutil.rmtree("workspace")
    #shutil.rmtree("archive")
    print()
    
def before_tag(context, tag):
    setMatcher = re.compile("set(.)images")
    m = setMatcher.search(tag)
    if m:
        count = int(m.group(1))
        version = int(os.getenv("APPLICATION_VERSION"))-1
        appPrefix = os.getenv("REGISTRY_URL") +"/"+ os.getenv("APPLICATION_NAME")+":"
        while count > 0:
            print("\n=================pwd===============")
            print(subprocess.check_output("pwd", shell=True));
            print(subprocess.check_output("ice build -t "+appPrefix+str(version) +" .", shell=True))
            print
            version = version - 1
            count = count - 1
        time.sleep(10)

def after_tag(context, tag):
    setMatcher = re.compile("set(.)images")
    m = setMatcher.search(tag)
    if m:
        print(subprocess.check_output("ice images | grep "+os.getenv("APPLICATION_NAME")+" | awk '{print $6}' | xargs -n 1 ice rmi", shell=True))
        print
