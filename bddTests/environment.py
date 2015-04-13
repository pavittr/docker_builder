import os
import subprocess
import shutil
import re
import time

def before_feature(context, feature):
    #Before running outside of the pipeline you must:
    ###Set a environment variables for CCS_REGISTRY_HOST, REGISTRY_URL and login to ice
    #os.environ["CCS_REGISTRY_HOST"] = "registry-ice.ng.bluemix.net"
    #os.environ["REGISTRY_URL"] = "registry-ice.ng.bluemix.net/jgarcows"
    #os.mkdir("workspace")
    os.environ["WORKSPACE"] = "."
    os.chdir("simpleDocker")
    #os.mkdir("archive")
    os.environ["ARCHIVE_DIR"] = "."
    os.environ["IMAGE_NAME"] = "fakeapp"
    context.appName = os.environ["IMAGE_NAME"]
    os.environ["APPLICATION_VERSION"] = "30"
    context.appVer = os.environ["APPLICATION_VERSION"]

    os.environ["FULL_REPOSITORY_NAME"] = os.environ["REGISTRY_URL"]+"/"+os.environ["IMAGE_NAME"]+":"+os.environ["APPLICATION_VERSION"]
    
def after_feature(context, feature):
    #shutil.rmtree("workspace")
    #shutil.rmtree("archive")
    print()
    
def before_tag(context, tag):
    #matches tags to "command"+"count"
    matcher = re.compile("(\D*)(\d+)")
    m = matcher.search(tag)
    if m:
        command = m.group(1)
        count = int(m.group(2))
        if command == "createimages":
            version = int(os.getenv("APPLICATION_VERSION"))-count
            appPrefix = os.getenv("REGISTRY_URL") +"/"+ os.getenv("IMAGE_NAME")+":"
            while count > 0:
                print("\n=================pwd===============")
                print(subprocess.check_output("pwd", shell=True));
                print("ice build -t "+appPrefix+str(version) +" .")
                subprocess.check_output("ice build -t "+appPrefix+str(version) +" .", shell=True)
                print
                version = version + 1
                count = count - 1
            time.sleep(10)
        if command == "useimages":
            version = int(os.getenv("APPLICATION_VERSION"))-count
            appPrefix = os.getenv("IMAGE_NAME")+":"
            while count > 0:
                print("\n=================pwd===============")
                print(subprocess.check_output("pwd", shell=True));
                print("ice run --name "+os.getenv("IMAGE_NAME")+str(version) +"Container "+appPrefix+str(version))
                subprocess.check_output("ice build -t "+appPrefix+str(version) +" .", shell=True)
                print
                version = version + 1
                count = count - 1
            time.sleep(10)

def after_tag(context, tag):
    matcher = re.compile("(\D*)(\d+)")
    m = matcher.search(tag)
    if (m and m.group(1) == "createimages"):
        print(subprocess.check_output("ice images | grep "+os.getenv("IMAGE_NAME")+" | awk '{print $6}' | xargs -n 1 ice rmi", shell=True))
        print
