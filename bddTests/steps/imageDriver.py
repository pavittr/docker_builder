from behave import *
import subprocess
import os
import urllib2
import time
import re
from environment import *

@given(u'I have a setup pipeline with a Container Image Build Stage')
def step_impl(context):
    assert True
    
@given(u'I have set the number images to keep to a value below the ICS image limit')
def step_impl(context):
    os.environ["IMAGE_LIMIT"]="3"
    
def get_appImage_count(context):
    imageList = subprocess_retry(context, "ice images | grep "+context.appName, True)
    lines = imageList.splitlines()
    Count = int(len(lines))
    print (Count)
    print
    return Count

def get_totImage_count():
    subprocess_retry(context, "ice images | grep "+os.environ["NAMESPACE"]+"/", True)
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
        if "ignorebuildfailure" in context.tags:
            print ("Ignoring build failure condition")
        else:
            raise e
    

@then(u'The new image is built')
def step_impl(context):
    tries = 0
    while tries < 6:
        imageList = subprocess_retry(context, "ice images | grep "+context.appName, True)
        matcher = re.compile(context.appName+":"+get_app_version())
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
    
def check_images_deleted_until_under_limit(context, limit):
    imageList = subprocess_retry(context, "ice images | grep \""+context.appName+":[0-9]\\+\"", True)
    lines = imageList.splitlines()
    assert (len(lines) == limit)
    ver = int(get_app_version())
    count = 0
    while (count < limit):
        matcher = re.compile(context.appName+":"+str(ver))
        m = matcher.search(imageList)
        assert (m)
        ver = ver - 1
        count = count + 1
    

@then(u'unused images will be deleted from oldest to newest until we are under the limit')
def step_impl(context):
    check_images_deleted_until_under_limit(context, int(os.environ["IMAGE_LIMIT"]))
    
@then(u'unused images will be deleted from oldest to newest until we are under the default limit')
def step_impl(context):
    check_images_deleted_until_under_limit(context, 5)
        

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
    appVer = int(get_app_version())
    #figure out what images shouldn't be used (if any) and check they are gone
    if (createdCount > usedCount):
        unusedVersions = range(appVer - createdCount, appVer - usedCount)
        print (unusedVersions)
        print
        assert (unusedVersions)
        for ver in unusedVersions:
            imageList = subprocess_retry(context, "ice images | grep "+context.appName, True)
            matcher = re.compile(context.appName+":"+str(ver))
            m = matcher.search(imageList)
            assert m is None
            
@then(u'no used images will be deleted')
def step_impl(context):
    usedCount = get_used_count(context)
    assert usedCount > 0
    imageList = subprocess_retry(context, "ice images | grep "+context.appName, True)
    version = int(get_app_version())-usedCount
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
        subprocess_retry(context,"ice build -t "+appPrefix+str(get_app_version()) +" .", True)
        increment_app_version()
        count = count + 1

@then(u'The new image will not be built')
def step_impl(context):
    tries = 0
    while tries < 6:
        imageList = subprocess_retry(context, "ice images | grep "+context.appName, True)
        matcher = re.compile(context.appName+":"+get_app_version())
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
    

@given(u'I have set the number images to keep to 1')
def step_impl(context):
    os.environ["IMAGE_LIMIT"]="1"

@given(u'I have images in the form of image_namexx')
def step_impl(context):
    imgName = os.getenv("REGISTRY_URL") +"/"+ os.getenv("IMAGE_NAME")+"xx:"+str(get_app_version())
    subprocess_retry(context,"ice build -t "+imgName +" .", True)
    increment_app_version()
    context.imgxx = imgName

@given(u'I have images with the same name but tagged with an alpha-string (alchemy/imagename:uniquetag)')
def step_impl(context):
    imgName = os.getenv("REGISTRY_URL") +"/"+ os.getenv("IMAGE_NAME")+":tag"
    subprocess_retry(context,"ice build -t "+imgName +" .", True)
    context.img_tag = imgName


def check_for_image(context, fullImgName):
    output = subprocess_retry(context, "ice inspect images | grep "+fullImgName, False)
    return output 

@then(u'the images in the form of image_namexx will not be deleted')
def step_impl(context):
    assert check_for_image(context, context.imgxx)
    subprocess_retry(context, "ice rmi "+context.imgxx, True)


@then(u'the images tagged with an alpha-string will not be deleted')
def step_impl(context):
    assert check_for_image(context, context.img_tag)
    subprocess_retry(context, "ice rmi "+context.img_tag, True)
    
    
@given(u'I want to generate some exceptions')
def step_impl(context):
    pass
    
@then(u'I generate {num} exceptions')
def step_impl(context, num):
    tries = 0
    while tries < int(num):
        subprocess_retry(context, "echo \"Failure "+str(tries)+"\"; [ ]", False)
        tries = tries + 1

@given(u'I have run a series of tests and kept track of any subprocess exceptions')
def step_impl(context):
    pass

@then(u'The number of exceptions will be no more than {num}')
def step_impl(context, num):
    exceptionCount = len(context.exceptions)
    print ("There were "+str(exceptionCount)+" exception(s) found during test execution")
    print
    assert exceptionCount <= int(num)
