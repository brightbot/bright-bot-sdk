//
//  BrightBot.h
//
//  Created by Zach Hendershot on 7/2013.
//  Copyright (c) 2013 BrightBot Inc. All rights reserved.
//

#import "GTMOAuth2Authentication.h"
#import "GTMOAuth2ViewControllerTouch.h"

//#define kBrightBotAPIBase @"http://api.brightbot-local.co:10080" //:10080"
#define kBrightBotAPIBase @"https://api.brightbot.co"
#define kBrightBotAPIVersion @"v1"

@interface BBFileContent : NSObject
@property (strong, nonatomic) NSString* guid;
@property (strong, nonatomic) NSString* metadata;
@property (strong, nonatomic) NSString* path;
@property (strong, nonatomic) NSNumber* created;
@property (strong, nonatomic) NSNumber* updated;
- (id)initWithResponseDictionary:(NSDictionary*)content;
@end

@interface BBStudent : NSObject
@property (strong, nonatomic) NSString* guid;
@property (strong, nonatomic) NSString* name;
@property (strong, nonatomic) NSNumber* created;
@property (strong, nonatomic) NSNumber* updated;
@property (strong, nonatomic) NSString* profile_picture;
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
@end

@interface BBActivityProgress : NSObject
@property (strong, nonatomic) NSString* activity_tag;
@property (strong, nonatomic) NSNumber* progress;
@property (strong, nonatomic) NSNumber* goal;
- (NSString*)toJSON;
@end

@interface BrightBot : GTMOAuth2ViewControllerTouch {
    GTMOAuth2Authentication *mAuth;
    NSString *mBBClientID;
    NSString *mBBClientSecret;
    NSString *fileUrl;
    IBOutlet UIButton *closeButton;
}

@property (nonatomic, retain) GTMOAuth2Authentication *auth;
@property (nonatomic, retain) NSString *BBClientID;
@property (nonatomic, retain) NSString *BBClientSecret;

- (NSString*) fileUrl;

- (IBAction)closeAuth:(id)sender;
+ (NSString *)authNibName;

+ (BrightBot *)sharedInstance;
- (BOOL)authenticated;
- (void)configure:(NSString *)client_id client_secret:(NSString *)client_secret;
- (void)logProgress:(NSString*)student_id time_spent:(NSNumber*)time_spent data:(NSArray*)progress_items success:(void (^)(void))success error:(void (^)(NSError* error))error;
- (void)getStudents:(void (^)(NSArray* students))success error:(void (^)(NSError *error))error;
- (void)addStudent:(NSDictionary*)the_student success:(void (^)(id data))success error:(void (^)(NSError* error))error;
- (void)modifyStudent:(NSDictionary*)the_student success:(void (^)(id data))success error:(void (^)(NSError* error))error;
- (void)removeStudent:(NSDictionary*)the_student success:(void (^)(void))success error:(void (^)(NSError* error))error;
- (void)getFileContents:(NSString*)student_id success:(void (^)(NSArray* fileContents))success error:(void (^)(NSError* error))error;
- (void)addFileContents:(NSString*)student_id data:(NSString*)content_data file:the_file success:(void (^)(id data))success error:(void (^)(NSError* error))error;
- (void)modifyFileContents:(NSString*)content_id file:the_file success:(void (^)(id data))success error:(void (^)(NSError* error))error;
- (void)modifyFileContents:(NSString*)content_id data:(NSString*)content_data success:(void (^)(id data))success error:(void (^)(NSError* error))error;
- (void)modifyFileContents:(NSString*)content_id data:(NSString*)content_data file:the_file success:(void (^)(id data))success error:(void (^)(NSError* error))error;

- (void)removeFileContents:(NSString*)content_id success:(void (^)(void))success error:(void (^)(NSError* error))error;
- (void)authenticate:(void (^)(void))success error:(void (^)(NSError* error))error;
- (void)signOut;

@end
