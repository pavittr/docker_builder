import os
import subprocess
import shutil
import re
import time


def get_app_version():
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
    ###Set a environment variables for CCS_REGISTRY_HOST, REGISTRY_URL, NAMESPACE and login to ice
    #os.environ["CCS_REGISTRY_HOST"] = "registry-ice.ng.bluemix.net"
    #os.environ["NAMESPACE"] = "jgarcows"
    #os.environ["REGISTRY_URL"] = "registry-ice.ng.bluemix.net/jgarcows"
    #os.mkdir("workspace")
    os.environ["WORKSPACE"] = "."
    os.chdir("simpleDocker")
    #os.mkdir("archive")
    os.environ["ARCHIVE_DIR"] = "."
    os.environ["IMAGE_NAME"] = "bddapp"
    context.appName = os.environ["IMAGE_NAME"]
    set_app_version(31)
    #Cleaning up any hanging on containers
    cleanupContainers()
        
    #Cleaning up any hanging on images
    try:
        print(subprocess.check_output("ice images | grep "+os.getenv("IMAGE_NAME")+" | awk '{print $6}' | xargs -n 1 ice rmi", shell=True))
        print
        print("Waiting 60 seconds after removal of images")
        time.sleep(60)
    except subprocess.CalledProcessError as e:
        print ("No images found, continuing with test setup")
        print (e.cmd)
        print (e.output)
        print
    
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
                print("\n=================pwd===============")
                print(subprocess.check_output("pwd", shell=True));
                try:
                    print("ice build -t "+appPrefix+str(version) +" .")
                    print(subprocess.check_output("ice build -t "+appPrefix+str(version) +" .", shell=True))
                    print
                except subprocess.CalledProcessError as e:
                    print (e.cmd)
                    print (e.output)
                    raise e
                increment_app_version()
                count = count - 1
            time.sleep(10)
            print("ice images")
            print(subprocess.check_output("ice images", shell=True))
        if command == "useimages":
            version = int(get_app_version())-count
            appPrefix = os.getenv("NAMESPACE")+"/"+os.getenv("IMAGE_NAME")+":"
            while count > 0:
                print("Starting container: "+containerName(version))
                try:
                    print(subprocess.check_output("ice run --name "+containerName(version) +" "+appPrefix+str(version), shell=True))
                    print 
                except subprocess.CalledProcessError as e:
                    print (e.cmd)
                    print (e.output)
                    #TODO: it would be really nice to stop all containers I've already started before bailing
                    raise e
                version = version + 1
                count = count - 1
            time.sleep(10)
            print("ice ps")
            print(subprocess.check_output("ice ps", shell=True))
            
            
def containerName(version):
    return os.getenv("IMAGE_NAME")+str(version) +"C"
    
def cleanupContainers():
    psOutput = subprocess.check_output("ice ps", shell=True)
    for m in re.finditer(os.environ["IMAGE_NAME"]+"\d+C", psOutput):
        print("Removing container: "+m.group(0))
        try:
            print(subprocess.check_output("ice stop "+m.group(0), shell=True))
            print
        except subprocess.CalledProcessError as e:
            print (e.cmd)
            print (e.output)
            print
        for i in range(10):
            inspectOutput = subprocess.check_output("ice inspect " + m.group(0), shell=True)
            statusMatcher = re.compile("\"Status\": \"(\S*)\"")
            mInspect = statusMatcher.search(inspectOutput)
            if mInspect:
                print (mInspect.group(0))
                print
                status = mInspect.group(1)
                if (status != "Running"):
                    break
            time.sleep(6)
        try:
            print(subprocess.check_output("ice rm "+m.group(0), shell=True))
            print
        except subprocess.CalledProcessError as e:
            print (e.cmd)
            print (e.output)
            print

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
        version = int(get_app_version())-useCount
        while useCount > 0:
            try:
                print(subprocess.check_output("ice stop "+containerName(version), shell=True))
                print
            except subprocess.CalledProcessError as e:
                print (e.cmd)
                print (e.output)
                print
            for i in range(10):
                inspectOutput = subprocess.check_output("ice inspect " + containerName(version), shell=True)
                statusMatcher = re.compile("\"Status\": \"(\S*)\"")
                m = statusMatcher.search(inspectOutput)
                if m:
                    print (m.group(0))
                    print
                    status = m.group(1)
                    if (status != "Running"):
                        break
                time.sleep(6)
            try:
                print(subprocess.check_output("ice rm "+containerName(version), shell=True))
                print
            except subprocess.CalledProcessError as e:
                print (e.cmd)
                print (e.output)
                print
            version = version + 1
            useCount = useCount - 1
    if (createCount > 0 or removeImages):
        #cleanup images
        try:
            imageList = subprocess.check_output("ice images | grep "+os.getenv("IMAGE_NAME"), shell=True)
        except subprocess.CalledProcessError as e:
            print ("ERROR return code "+ str(e.returncode) +" for ice images")
            print (e.cmd)
            print (e.output)
            print
            return
        lines = imageList.splitlines()
        imageMatcher = re.compile(os.getenv("REGISTRY_URL") +"/"+ os.getenv("IMAGE_NAME")+":\\d+")
        for line in lines:
            m = imageMatcher.search(line)
            if m:
                try:
                    print(subprocess.check_output("ice rmi "+m.group(0), shell=True))
                except subprocess.CalledProcessError as e:
                    print ("ERROR return code "+ str(e.returncode) + " for ice rmi "+m.group(0))
                    print (e.cmd)
                    print (e.output)
                    print
        print("Pausing for 120 seconds to allow images to fully delete")
        time.sleep(120)
    #don't reuse the last app version we used, so move up one always
    increment_app_version()
    
#def after_tag(context, tag):
#    matcher = re.compile("(\D*)(\d+)")
#    m = matcher.search(tag)
#    if (m and m.group(1) == "createimages"):
#        print(subprocess.check_output("ice images | grep "+os.getenv("IMAGE_NAME")+" | awk '{print $6}' | xargs -n 1 ice rmi", shell=True))
#        print
