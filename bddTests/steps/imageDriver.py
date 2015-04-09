from behave import *
import subprocess
import os
import urllib2
import time
import re

@given(u'I have a setup pipeline with a Container Image Build Stage')
def step_impl(context):
    assert True
    
@given(u'I have set the number images to keep to a value below the ICS container limit')
def step_impl(context):
    os.environ["IMAGE_LIMIT"]="3"

def get_image_count(context):
    wcOutput = subprocess.check_output("ice images | grep "+context.appName+" | wc", shell=True)
    print (wcOutput)
    Count = int(wcOutput.split()[0])
    print (Count)
    print
    return Count

@given(u'I have less than the image limit in images (used and unused)')
def step_impl(context):
    context.preCount =  get_image_count(context)
    assert (context.preCount < 3)

@when(u'The container Image Build job is run')
def step_impl(context):
    try:
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
        time.sleep(10)
        tries = tries + 1;
        postCount = get_image_count(context)
        if (postCount == context.preCount + 1):
            break
    assert postCount == context.preCount + 1
            

@given(u'I have less than the image limit in used images')
def step_impl(context):
    assert True #at the moment this can pass since we have no used images

@given(u'I have more than the image limit in used and unused images')
def step_impl(context):
    context.preCount = get_image_count(context)
    assert (context.preCount > 3)

@then(u'unused images will be deleted from oldest to newest until we are under the limit')
def step_impl(context):
    imageList = subprocess.check_output("ice images | grep "+context.appName, shell=True)
    print(imageList)
    print
    lines = imageList.splitlines()
    assert (len(lines) == 3)
    ver = int(os.getenv("APPLICATION_VERSION"))
    count = 0
    while (count < 3):
        matcher = re.compile(context.appNam+":"+str(ver))
        m = matcher.search(imageList)
        assert (m)
        ver = ver - 1
        count = count + 1

@given(u'I have as many or more than the image limit in currently used images')
def step_impl(context):
    assert False

@then(u'all unused images will be deleted')
def step_impl(context):
    assert False

@then(u'A warning will be issued that the images in use could not be deleted')
def step_impl(context):
    assert False

@given(u'I have set the number images to keep to a value equal to or greater than the ICS container limit')
def step_impl(context):
    assert False

@given(u'I am currently at the ICS container limit')
def step_impl(context):
    assert False

@then(u'The job will fail because the ICS container limit is reached')
def step_impl(context):
    assert False

@given(u'I have set the number images to keep to a negative number')
def step_impl(context):
    assert False

@then(u'no images will be deleted')
def step_impl(context):
    assert False

@given(u'There is no user-defined image limit')
def step_impl(context):
    assert False

@given(u'I have less than the default image limit in currently used images')
def step_impl(context):
    assert False

@given(u'The default max limit has been reached')
def step_impl(context):
    assert False