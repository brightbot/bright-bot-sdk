# BrightBot SDK

## Overview

The BrightBot SDK abstracts all the complex functionality of interacting with a OAuth-enabled REST web API in iOS. The BrightBot API is an easy to use web service that allows developers to build rich in-app interactions with classrooms in an education setting. BrightBot takes away some of the complexity of managing students, teachers, and the content they generate to provide a platform that can be integrated easily into your existing application. 

## Getting started

There are two options for including the SDK in your project:

* Download the source from [github](https://github.com/brightbot/bright-bot-sdk), and unzip it into a folder within your Xcode project.

* If you're using git, you can add the `bright-bot-sdk` repository as a submodule among your project's other source files:

```bash
$ git submodule add git@github.com:brightbot/bright-bot-sdk.git bright-bot-sdk
```
* Add the related source files and controllers to you Xcode project by dragging them into your project:
GTMOAuth2Authentication.h/m
GTMOAuth2SignIn.h/m
GTMHTTPFetcher.h/m
GTMOAuth2ViewControllerTouch.h/m
GTMOAuth2ViewTouch.xib
BrightBot.h/.m

![Xcode source files](http://cl.ly/image/243S0U0E2G3e/Screen%20Shot%202013-08-21%20at%2012.41.16%20PM.png "Source Files")

> ### ARC Compatibility
> When the controller source files are compiled directly into a project that has ARC enabled, then ARC must be disabled specifically for the controller source files.

> To disable ARC for source files in Xcode 4, select the project and the target in Xcode. Under the target "Build Phases" tab, expand the Compile Sources build phase, select the library source files, then press Enter to open an edit field, and type -fno-objc-arc as the compiler flag for those files. This only applies to the source files that start with GTM*.

* Add the standard Security.framework and SystemConfiguration.framework to your project

* Ensure that under the "Build Phases" tab, the GTM*.m and BrightBot.m files are listed under "Compile Sources"

The `BrightBot` class is the main class you'll interact with as a BrightBot developer. 
You can instantiate it by including `BrightBot.h` and calling the `configure` method with the BrightBot sharedInstance:

```objective-c
#import "BrightBot.h"

...

BrightBot* api = [[BrightBot sharedInstance] configure:@"<Your Client ID>" 
	client_secret:@"<Your Client Secret>"];
```

## Authenticating

You can figure out of the current user is authenticated through the `authenticated` method:

```objective-c

if ( ! [[BrightBot sharedInstance] authenticated] ) {

	...

}

```

If the user need to authenticate with the BrightBot system, you can call the `authenticate` method:

```objective-c

[[BrightBot sharedInstance] authenticate:^() {
			// User was authenticated
        }
     	error:^(NSError *error) {
			// User failed to authenticate
		}];

```

If you want to programatically log the user out of the system, use the `signOut` method:

```objective-c

[[BrightBot sharedInstance] signOut];

```

## Getting data

Once you have an authenticated instance of the `BrightBot` class you can query the API and send data to the API. One simple example is the 'getStudents' methods that returns the current user's list of students. The `getStudents` method returns an `NSArray` of `BBStudent` objects on success:

```objective-c

[[BrightBot sharedInstance] getStudents:^(NSArray* students) {
        for (BBStudent* student in students) {
            NSLog(@"Student %@:%@", student.guid, student.name);
        }
    } error:^(NSError* error) {
        NSLog(@"error retrieving students %@", error);
    }];

```

There are other SDK methods that allow you to add students, modify students, and add file content to students. Please feel free to explore the SDK!
