//
//  BrightBot.h
//
//  Created by Zach Hendershot on 7/2013.
//  Copyright (c) 2013 BrightBot Inc. All rights reserved.
//

#import "GTMOAuth2Authentication.h"
#import "GTMOAuth2ViewControllerTouch.h"

#define kBrightBotAPIBase @"http://api.brightbot-local.co:10080" //:10080"
//#define kBrightBotAPIBase @"https://api.brightbot.co"
#define kBrightBotAPIVersion @"v1"

@interface BBFileContent : NSObject
@property (strong, nonatomic) NSString* guid;
@property (strong, nonatomic) NSString* metadata;
@property (strong, nonatomic) NSString* path;
@property (strong, nonatomic) NSData* content_data;
@property (strong, nonatomic) NSNumber* created;
@property (strong, nonatomic) NSNumber* updated;
- (id)initWithResponseDictionary:(NSDictionary*)content;
- (NSMutableDictionary*)toDictionary;
@end

@interface BBStudent : NSObject
@property (strong, nonatomic) NSString* guid;
@property (strong, nonatomic) NSString* name;
@property (strong, nonatomic) NSNumber* created;
@property (strong, nonatomic) NSNumber* updated;
@property (strong, nonatomic) NSString* profile_picture;
@property (strong, nonatomic) NSData* profile_picture_data;
- (id)initWithResponseDictionary:(NSDictionary*)student;
- (NSMutableDictionary*)toDictionary;
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
    IBOutlet UIButton *closeButton;
}

@property (nonatomic, retain) GTMOAuth2Authentication *auth;
@property (nonatomic, retain) NSString *BBClientID;
@property (nonatomic, retain) NSString *BBClientSecret;

- (IBAction)closeAuth:(id)sender;
+ (NSString *)authNibName;

+ (BrightBot *)sharedInstance;
- (BOOL)authenticated;
- (void)configure:(NSString *)client_id client_secret:(NSString *)client_secret;
- (void)logProgress:(NSString*)student_id time_spent:(NSNumber*)time_spent data:(NSArray*)progress_items success:(void (^)(void))success error:(void (^)(NSError* error))error;
- (void)getStudents:(void (^)(NSArray* students))success error:(void (^)(NSError *error))error;
- (void)addStudent:(BBStudent*)the_student success:(void (^)(id data))success error:(void (^)(NSError* error))error;
- (void)modifyStudent:(BBStudent*)the_student success:(void (^)(id data))success error:(void (^)(NSError* error))error;
- (void)removeStudent:(BBStudent*)the_student success:(void (^)(void))success error:(void (^)(NSError* error))error;
- (void)getFileContents:(BBStudent*)the_student success:(void (^)(NSArray* fileContents))success error:(void (^)(NSError* error))error;
- (void)addFileContents:(BBStudent*)the_student content:(BBFileContent*)content_data success:(void (^)(id data))success error:(void (^)(NSError* error))error;
- (void)modifyFileContents:(BBFileContent*)content success:(void (^)(id data))success error:(void (^)(NSError* error))error;
- (void)removeFileContents:(BBFileContent*)content success:(void (^)(void))success error:(void (^)(NSError* error))error;
- (void)authenticate:(void (^)(void))success error:(void (^)(NSError* error))error;
- (void)signOut;

@end
