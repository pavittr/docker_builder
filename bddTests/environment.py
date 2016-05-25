import os
import subprocess
import shutil
import re
import time


def get_app_version():
    env = os.environ["APPLICATION_VERSION"]
    if env is None:
        os.environ["APPLICATION_VERSION"] = "31"
    return os.environ["APPLICATION_VERSION"]
    
def set_app_version(ver):
    os.environ["APPLICATION_VERSION"] = str(ver)
    os.environ["FULL_REPOSITORY_NAME"] = os.environ["REGISTRY_URL"]+"/"+os.environ["IMAGE_NAME"]+":"+get_app_version()
    
def increment_app_version():
    #This will increment APPLICATION_VERSION by one
    #Whenever we build in python, we should call this to make sure our build script is on the right number
    curVer = int(os.environ["APPLICATION_VERSION"])
    os.environ["APPLICATION_VERSION"] = str(curVer+1)
    os.environ["FULL_REPOSITORY_NAME"] = os.environ["REGISTRY_URL"]+"/"+os.environ["IMAGE_NAME"]+":"+get_app_version()

def before_feature(context, feature):
    #Before running outside of the pipeline you must:
    ###Set a environment variables for CCS_REGISTRY_HOST, REGISTRY_URL, NAMESPACE and login to cf ic
    #os.environ["CCS_REGISTRY_HOST"] = "registry-ice.ng.bluemix.net"
    #os.environ["NAMESPACE"] = "jgarcows"
    #os.environ["REGISTRY_URL"] = "registry-ice.ng.bluemix.net/jgarcows"
    #os.mkdir("workspace")
    os.environ["WORKSPACE"] = "."
    os.chdir("simpleDocker")
    #os.mkdir("archive")
    os.environ["ARCHIVE_DIR"] = "."
    os.environ["IMAGE_NAME"] = "newbdd"
    context.appName = os.environ["IMAGE_NAME"]
    set_app_version(31)
    #setup a list of exceptions found during environment cf ic commands
    context.exceptions = []
    #Cleaning up any hanging on containers
    cleanupContainers(context)
    cleanupImages(context, True)
        
def subprocess_retry(context, command, showOutput, retryCount=2):
    try:
        print(time.strftime("<%I:%M:%S> ")+command)
        print
        output = subprocess.check_output(command, shell=True)
        if (showOutput):
            print(time.strftime("<%I:%M:%S> ")+output)
            print
        return output
    except subprocess.CalledProcessError as e:
        context.exceptions.append(e)
        print(e.cmd)
        print(e.output)
        if (retryCount > 0):
            print(time.strftime("<%I:%M:%S> ")+"Non-zero return code; recording failure and retrying in 10 seconds")
            print
            time.sleep(10)
            return subprocess_retry(context, command, showOutput, retryCount-1)
        else:
            print(time.strftime("<%I:%M:%S> ")+"Non-zero return code; exceeded retry count: recording failure and continuing")
            return e.output
    
def after_feature(context, feature):
    #shutil.rmtree("workspace")
    #shutil.rmtree("archive")
    os.chdir("..")
    print()

    
def before_tag(context, tag):
    #matches tags to "command"+"count"
    matcher = re.compile("(\D*)(\d+)")
    m = matcher.search(tag)
    if m:
        command = m.group(1)
        count = int(m.group(2))
        if command == "createimages":
            appPrefix = os.getenv("REGISTRY_URL") +"/"+ os.getenv("IMAGE_NAME")+":"
            while count > 0:
                version = get_app_version()
                subprocess_retry(context,"cf ic build -t "+appPrefix+str(version) +" .", False)
                increment_app_version()
                count = count - 1
            print(time.strftime("<%I:%M:%S> ")+"Waiting 120 seconds after building images")
            time.sleep(120)
            subprocess_retry(context,"cf ic images", True)
        if command == "useimages":
            version = int(get_app_version())-count
            appPrefix = os.getenv("NAMESPACE")+"/"+os.getenv("IMAGE_NAME")+":"
            while count > 0:
                print("Starting container: "+containerName(version))
                subprocess_retry(context,"cf ic run --name "+containerName(version) +" "+appPrefix+str(version), False)
                version = version + 1
                count = count - 1
            print(time.strftime("<%I:%M:%S> ")+"Waiting 120 seconds after starting images")
            time.sleep(120)
            subprocess_retry(context,"cf ic ps -a", True)
            
            
def containerName(version):
    return os.getenv("IMAGE_NAME")+str(version) +"C"
    
def cleanupImages(context, pause=False):
    #cleanup images
    imageList = subprocess_retry(context, "cf ic images", False)
    lines = imageList.splitlines()
    imageMatcher = re.compile("("+os.getenv("REGISTRY_URL") +"/"+ os.getenv("IMAGE_NAME")+"\S*)\s*(\S+)")
    imagesFound = False
    for line in lines:
        m = imageMatcher.search(line)
        if m:
            subprocess_retry(context, "cf ic rmi "+m.group(1)+":"+m.group(2), True)
            imagesFound = True
    if imagesFound:
        if pause:
            print("Waiting 120 seconds to allow images to be deleted")
            time.sleep(120)
        print("Finished cleaning up images.")
        print
    
    
def cleanupContainers(context):
    psOutput = subprocess_retry(context, "cf ic ps -a", False)
    psLines = psOutput.splitlines()
    cNameMatcher = re.compile(os.environ["IMAGE_NAME"]+"\d+C")
    stoppedMatcher = re.compile("crashed|shutdown", re.IGNORECASE)
    for line in psLines:
        mName = cNameMatcher.search(line)
        if mName:
            mStopped = stoppedMatcher.search(line)
            if mStopped:
                print("Container "+mName.group(0)+" is \""+mStopped.group(0)+"\", not trying to stop")
            else:
                print("Stopping container: "+mName.group(0))
                subprocess_retry(context, "cf ic stop "+mName.group(0), True)
    statusMatcher = re.compile("\"Status\": \"(\S*)\"")
    for m in re.finditer(os.environ["IMAGE_NAME"]+"\d+C", psOutput):
        for i in range(30):
            inspectOutput = subprocess_retry(context, "cf ic inspect " + m.group(0), False)
            mInspect = statusMatcher.search(inspectOutput)
            if mInspect:
                print (mInspect.group(0))
                print
                status = mInspect.group(1)
                if (status != "Running"):
                    break
            time.sleep(6)
        subprocess_retry(context, "cf ic rm --force "+m.group(0), True)

def after_scenario(context, scenario):
    matcher = re.compile("(\D*)(\d+)")
    useCount = 0
    createCount = 0
    removeImages = False
    for tag in scenario.tags:
        m = matcher.search(tag)
        if (m and m.group(1) == "createimages"):
            createCount = int(m.group(2))
        elif (m and m.group(1) == "useimages"):
            useCount = int(m.group(2))
        elif (tag == "removeimages"):
            removeImages = True
    if (useCount > 0):
        #make sure I clean-up containers
        cleanupContainers(context)
    if (createCount > 0 or removeImages):
        #cleanup images
        cleanupImages(context)
    #don't reuse the app version created by the build script, so move up one always
    increment_app_version()
    
