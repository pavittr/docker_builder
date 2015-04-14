from behave import *
import subprocess
import os
import urllib2
import time
import re

@given(u'I have a setup pipeline with a Container Image Build Stage')
def step_impl(context):
    assert True
    
@given(u'I have set the number images to keep to a value below the ICS image limit')
def step_impl(context):
    os.environ["IMAGE_LIMIT"]="3"
    
def get_appImage_count(context):
    try:
        imageList = subprocess.check_output("ice images | grep "+context.appName, shell=True)
    except subprocess.CalledProcessError as e:
        print (e.cmd)
        print (e.output)
        print
        raise e
    print(imageList)
    print
    lines = imageList.splitlines()
    Count = int(len(lines))
    print (Count)
    print
    return Count

def get_totImage_count():
    try:
        imageList = subprocess.check_output("ice images | grep "+os.environ["NAMESPACE"]+"/", shell=True)
    except subprocess.CalledProcessError as e:
        print (e.cmd)
        print (e.output)
        print
        raise e
    print(imageList)
    print
    lines = imageList.splitlines()
    Count = int(len(lines))
    print (Count)
    print
    return Count
    
def get_used_count(context):
    usedCount = 0
    for tag in context.tags:
        matcher = re.compile("useimages(\d+)")
        m = matcher.search(tag)
        if m:
            usedCount = int(m.group(1))
    return usedCount

def get_created_count(context):
    createdCount = 0
    for tag in context.tags:
        matcher = re.compile("createimages(\d+)")
        m = matcher.search(tag)
        if m:
            createdCount = int(m.group(1))
    return createdCount

@given(u'I have less than the image limit in images (used and unused)')
def step_impl(context):
    context.preCount =  get_appImage_count(context)
    assert (context.preCount < int(os.environ["IMAGE_LIMIT"]))

@when(u'The container Image Build job is run')
def step_impl(context):
    try:
        context.utilOutput = subprocess.check_output("../../image_utilities.sh", shell=True)
        print (context.utilOutput)
        print(subprocess.check_output("../../sample_build_script.sh", shell=True))
        print
    except subprocess.CalledProcessError as e:
        print (e.cmd)
        print (e.output)
        print
        raise e
    

@then(u'The new image is built')
def step_impl(context):
    tries = 0
    while tries < 3:
        imageList = subprocess.check_output("ice images | grep "+context.appName, shell=True)
        print(imageList)
        matcher = re.compile(context.appName+":"+os.getenv("APPLICATION_VERSION"))
        m = matcher.search(imageList)
        if (m):
            break
        time.sleep(10)
        tries = tries + 1
    assert (m)
            

@given(u'I have less than the image limit in used images')
def step_impl(context):
    assert True #at the moment this can pass since we have no used images

@given(u'I have more than the image limit in used and unused images')
def step_impl(context):
    context.preCount = get_appImage_count(context)
    assert (context.preCount > int(os.environ["IMAGE_LIMIT"]))

@then(u'unused images will be deleted from oldest to newest until we are under the limit')
def step_impl(context):
    imageList = subprocess.check_output("ice images | grep "+context.appName, shell=True)
    print(imageList)
    print
    lines = imageList.splitlines()
    assert (len(lines) == int(os.environ["IMAGE_LIMIT"]))
    ver = int(os.getenv("APPLICATION_VERSION"))
    count = 0
    while (count < int(os.environ["IMAGE_LIMIT"])):
        matcher = re.compile(context.appName+":"+str(ver))
        m = matcher.search(imageList)
        assert (m)
        ver = ver - 1
        count = count + 1
        

@given(u'I have as many or more than the image limit in currently used images')
def step_impl(context):
    #This will be true if useimages* is set to an appropriate number
    print(context.tags)
    usedCount = get_used_count(context)
    assert (usedCount >= int(os.environ["IMAGE_LIMIT"]))

@then(u'all unused images will be deleted')
def step_impl(context):
    print(context.tags)
    usedCount = get_used_count(context)
    createdCount = get_created_count(context)
    appVer = int(os.getenv("APPLICATION_VERSION"))
    #figure out what images shouldn't be used (if any) and check they are gone
    if (createdCount > usedCount):
        unusedVersions = range(appVer - createdCount, appVer - usedCount)
        print (unusedVersions)
        print
        assert (unusedVersions)
        for ver in unusedVersions:
            imageList = subprocess.check_output("ice images | grep "+context.appName, shell=True)
            print(imageList)
            matcher = re.compile(context.appName+":"+str(ver))
            m = matcher.search(imageList)
            assert m is None
            
@then(u'no used images will be deleted')
def step_impl(context):
    usedCount = get_used_count(context)
    assert usedCount > 0
    try:
        imageList = subprocess.check_output("ice images | grep "+context.appName, shell=True)
    except subprocess.CalledProcessError as e:
        print (e.cmd)
        print (e.output)
        print
        raise e
    print(imageList)
    print
    version = int(os.getenv("APPLICATION_VERSION"))-usedCount
    while usedCount > 0:
        matcher = re.compile(context.appName+":"+str(version))
        assert matcher.search(imageList)
        version = version + 1
        usedCount = usedCount - 1


@then(u'A warning will be issued that the images in use could not be deleted')
def step_impl(context):
    matcher = re.compile("Warning: Too many images in use.")
    m = matcher.search(context.utilOutput)
    assert m
    
@given(u'I have set the number images to keep to a value equal to or greater than the ICS image limit')
def step_impl(context):
    os.environ["IMAGE_LIMIT"]="30"

@given(u'I am currently at the ICS image limit')
def step_impl(context):
    #I need to create images until the number of images is equal to 25
    #This code assumes that there are no images of name IMAGE_NAME:##
    appPrefix = os.getenv("REGISTRY_URL") +"/"+ os.getenv("IMAGE_NAME")+":"
    count = get_totImage_count()
    while (count < 25):
        #create image at count
        print("ice build -t "+appPrefix+str(count) +" .")
        print(subprocess.check_output("ice build -t "+appPrefix+str(count) +" .", shell=True))
        count = count + 1


@then(u'The new image will not be built')
def step_impl(context):
    tries = 0
    while tries < 3:
        imageList = subprocess.check_output("ice images | grep "+context.appName, shell=True)
        print(imageList)
        matcher = re.compile(context.appName+":"+os.getenv("APPLICATION_VERSION"))
        m = matcher.search(imageList)
        if (m):
            break
        time.sleep(10)
        tries = tries + 1
    assert (m is None)
    

@given(u'I have set the number images to keep to a negative number')
def step_impl(context):
    os.environ["IMAGE_LIMIT"]="-1"

@given(u'I have as many or more than the default image limit in used and unused images')
def step_impl(context):
    context.preCount = get_appImage_count(context)
    assert (context.preCount >= 5)

@then(u'no images will be deleted')
def step_impl(context):
    assert (get_appImage_count(context) == context.preCount + 1)

@given(u'There is no user-defined image limit')
def step_impl(context):
    os.environ.pop("IMAGE_LIMIT", None)

@given(u'I have less than the default image limit in currently used images')
def step_impl(context):
    usedCount = get_used_count(context)
    assert (usedCount < 5)

@given(u'I have as many or more than the default image limit in currently used images')
def step_impl(context):
    usedCount = get_used_count(context)
    assert (usedCount >= 5)