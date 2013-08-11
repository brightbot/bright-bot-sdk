# clever-ios

## Overview

Issuing HTTP requests and parsing JSON is a cumbersome process in iOS and Objective-C. `clever-ios` abstracts away all of the HTTP/JSON plumbing and lets you consume the Clever API quickly and easily using familiar iOS constructs and patterns. These iOS classes closely mirror the REST endpoints documented [here](http://getclever.com/developers/docs), but note that not all endpoints are currently supported. Pull requests are welcome!

## Getting started

There are two options for including the SDK in your project:

1. Download the source from [github](https://github.com/Clever/clever-ios/zipball/master), and unzip it into a folder within your Xcode project.

2. If you're using git, add the `clever-ios` repository as a submodule among your project's other source files:

```bash
$ git submodule add git@github.com:Clever/clever-ios.git clever-ios
```

The `Clever` class is the entrypoint for making requests to the API. You can instantiate it by including `Clever.h` and calling the `initWithAPIKey` method:

```objective-c
#import "Clever.h"

...

Clever* api = [[Clever alloc] initWithAPIKey:"DEMO_KEY"];
```

We recommend making this instance a property within you application's UIApplicationDelegate, since it will be used extensively.

## Getting data

Once you have an instance of the `Clever` class you can start querying the API for the data your API key has been authorized to access. For example, to get a list of all the schools that have granted you access to their data, use the `getSchools` method:

```objective-c
[clever getSchools:^(NSArray* schools) {
    for (school in schools) {
        NSLog(@"%@", school);
    }
} error:^(NSError* error) {
    NSLog(@"error retrieving students %@", error);
}];
```

Similarly, you can query for all the sections and students visible to your API key using the `getSections` and `getStudents` methods, respectively. Each of these methods returns Objective-C objects with properties corresponding to the JSON fields seen in the raw API. For example the `getStudents` function returns an array of `CleverStudent` objects with the following properties:

* guid
* lastModified
* studentNumber
* stateID
* sisID
* firstName
* middleName
* lastName
* address
* city
* state
* zip
* lat
* lon
* gender
* dob
* grade
* frlStatus
* race

## Digging deeper

The `Clever` class provides useful functions to dig deeper into the data, for example you can pass a student object to `getContactsFor` to get contacts for a student (parents/guardians phone, email, etc.). A student's photo is accessible using the `getPhotoFor` method. The best reference for SDK methods is the `Clever` interface definition itself, reproduced here from `Clever.h`:

```objective-c
@interface Clever : NSObject

- (id)initWithAPIKey:(NSString *)key;
- (void)getContactsFor:(CleverStudent*)student success:(void (^)(NSArray* studentContacts))success error:(void (^)(NSError *error))error;
- (void)getTeacherFor:(CleverSection*)section success:(void (^)(CleverTeacher* teacher))success error:(void (^)(NSError *error))error;
- (void)getSchools:(void (^)(NSArray* schools))success error:(void (^)(NSError *error))error;
- (void)getSections:(void (^)(NSArray* sections))success error:(void (^)(NSError *error))error;
- (void)getSectionsFor:(CleverSchool*)school success:(void (^)(NSArray* sections))success error:(void (^)(NSError *error))error;
- (void)getStudents:(void (^)(NSArray* students))success error:(void (^)(NSError *error))error;
- (void)getStudentsFor:(id)cleverObject success:(void (^)(NSArray* students))success error:(void (^)(NSError *error))error;
- (void)getPhotoFor:(CleverStudent*)student success:(void (^)(UIImage* image))success error:(void (^)(NSError *error))error;

@end
```

## Questions/Comments

Don't hesitate to file an issue, make a feature request, or contact us at [clever-ios@getclever.com](mailto:clever-ios@getclever.com)!
