//
//  BrightBot.h
//
//  Created by Zach Hendershot on 7/2013.
//  Copyright (c) 2013 BrightBot Inc. All rights reserved.
//
#define kBrightBotAPIBase @"http://api.localhost:10080" //:10080"

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
@property (nonatomic, retain) UIWebView *webView;
@property (nonatomic, copy) NSString *teacher_id;
@property (nonatomic, copy) NSString *app_id;

- (id)initAPI:(NSString *)api_key private_key:(NSString *)private_key teacher_id:(NSString *)teacher_id;
- (void)getStudents:(void (^)(NSArray* students))success error:(void (^)(NSError *error))error;
- (void)addStudent:(NSString*)the_student success:(void (^)(void))success error:(void (^)(NSError* error))error;
- (void)removeStudent:(NSString*)the_student success:(void (^)(void))success error:(void (^)(NSError* error))error;
- (void)getFileContents:(NSString*)student_id success:(void (^)(NSArray* fileContents))success error:(void (^)(NSError* error))error;
- (void)addFileContents:(NSString*)student_id data:content_data file:the_file success:(void (^)(void))success error:(void (^)(NSError* error))error;
- (void)authenticate:(UIView *)theView success:(void (^)(NSMutableDictionary* authValues))success error:(void (^)(NSError* error))error;

@end
