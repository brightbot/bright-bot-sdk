//
//  BrightBot.h
//
//  Created by Zach Hendershot on 7/2013.
//  Copyright (c) 2013 BrightBot Inc. All rights reserved.
//

//#define kBrightBotAPIBase @"http://api.localhost:10080" //:10080"
#define kBrightBotAPIBase @"http://api.brightbot.co"

@interface BBFileContent : NSObject
@property (strong, nonatomic) NSString* guid;
@property (strong, nonatomic) NSString* app_id;
@property (strong, nonatomic) NSString* metadata;
@property (strong, nonatomic) NSString* path;
- (id)initWithResponseDictionary:(NSDictionary*)content;
@end

@interface BBStudent : NSObject
@property (strong, nonatomic) NSString* guid;
@property (strong, nonatomic) NSString* name;
- (id)initWithResponseDictionary:(NSDictionary*)student;
@end

@interface BBTeacher : NSObject
@property (strong, nonatomic) NSString* guid;
@property (strong, nonatomic) NSString* lastModified;
@property (strong, nonatomic) NSString* sisID;
@property (strong, nonatomic) NSString* email;
@property (strong, nonatomic) NSString* firstName;
@property (strong, nonatomic) NSString* middleName;
@property (strong, nonatomic) NSString* lastName;
@property (strong, nonatomic) NSString* title;
- (id)initWithResponseDictionary:(NSDictionary*)teacher;
- (NSString*)description;
- (NSString*)url;
@end

@interface BBSchool : NSObject
@property (strong, nonatomic) NSString* guid;
@property (strong, nonatomic) NSString* lastModified;
@property (strong, nonatomic) NSString* sisID;
@property (strong, nonatomic) NSString* stateID;
@property (strong, nonatomic) NSString* ncesID;
@property (strong, nonatomic) NSString* schoolNumber;
@property (strong, nonatomic) NSString* lowGrade;
@property (strong, nonatomic) NSString* highGrade;
@property (strong, nonatomic) NSString* principalName;
@property (strong, nonatomic) NSString* principalEmail;
@property (strong, nonatomic) NSString* name;
@property (strong, nonatomic) NSString* address;
@property (strong, nonatomic) NSString* city;
@property (strong, nonatomic) NSString* state;
@property (strong, nonatomic) NSString* zip;
@property (strong, nonatomic) NSString* phone;
- (id)initWithResponseDictionary:(NSDictionary*)school;
- (NSString*)description;
- (NSString*)url;
@end

@interface BrightBot : UIView <UIWebViewDelegate>

@property (nonatomic, copy) NSString *api_key;
@property (nonatomic, copy) NSString *private_key;
@property (nonatomic, copy) NSString *teacher_id;
@property (nonatomic, copy) NSString *app_id;
@property (nonatomic, assign) BOOL authenticated;

+ (BrightBot *)sharedInstance;

- (id)initAPI:(NSError **)error;
- (void)getStudents:(void (^)(NSArray* students))success error:(void (^)(NSError *error))error;
- (void)addStudent:(NSDictionary*)the_student success:(void (^)(id data))success error:(void (^)(NSError* error))error;
- (void)modifyStudent:(NSDictionary*)the_student success:(void (^)(void))success error:(void (^)(NSError* error))error;
- (void)removeStudent:(NSDictionary*)the_student success:(void (^)(void))success error:(void (^)(NSError* error))error;
- (void)getFileContents:(NSString*)student_id success:(void (^)(NSArray* fileContents))success error:(void (^)(NSError* error))error;
- (void)addFileContents:(NSString*)student_id data:content_data file:the_file success:(void (^)(void))success error:(void (^)(NSError* error))error;
- (void)authenticate:(NSString *)api_key success:(void (^)(void))success error:(void (^)(NSError* error))error;
- (void)signOut;

@end
