//
//  BrightBot.m
//
//  Created by Zach Hendershot on 7/2013.
//  Copyright (c) 2013 BrightBot Inc. All rights reserved.
//

#import "BrightBot.h"
#import <Foundation/NSURL.h>
#import <Foundation/NSURLRequest.h>
#import <Foundation/NSURLResponse.h>
#import <Foundation/NSURLConnection.h>
#import <Foundation/NSJSONSerialization.h>
#import "GTMOAuth2Authentication.h"
#import "GTMOAuth2ViewControllerTouch.h"


@implementation BrightBot 

// Instance vars
void (^authFinish)();
BrightBot *authController;

@synthesize auth = mAuth;
@synthesize BBClientID = mBBClientID;
@synthesize BBClientSecret = mBBClientSecret;

static NSString *const kKeychainItemName = @"BrightBot OAuth";
static NSString *const kServiceProviderName = @"BrightBot Service";

- (IBAction)closeAuth:(id)sender {
    [self dismissViewControllerAnimated:YES completion:nil];
}

+ (NSString *)authNibName {
    // subclasses may override this to specify a custom nib name
    return @"bb_GTMOAuth2ViewTouch";
}

/*
 Authentication and Instantiation Methods
 */

// The BrightBoth authentication object setup
- (GTMOAuth2Authentication *)brightbotAuth {
    
    NSString* urlString = [[NSString alloc] initWithFormat:@"%@/oauth/token", kBrightBotAPIBase];
    NSURL *tokenURL = [NSURL URLWithString:urlString];
    
    
    // We'll make up an arbitrary redirectURI.  The controller will watch for
    // the server to redirect the web view to this URI, but this URI will not be
    // loaded, so it need not be for any actual web page.
    NSString *redirectURI = @"http://www.brightbot.com/OAuthCallback";
    
    BOOL shouldAuthorizeAllRequests;
    // If this is running to the local instance, SSL isn't used.
    if ([kBrightBotAPIBase rangeOfString:@"local"].location == NSNotFound) {
        shouldAuthorizeAllRequests = NO;
    } else {
        shouldAuthorizeAllRequests = YES;
    }
    
    GTMOAuth2Authentication *auth;
    auth = [GTMOAuth2Authentication authenticationWithServiceProvider:kServiceProviderName
                                                             tokenURL:tokenURL
                                                          redirectURI:redirectURI
                                                             clientID:self.BBClientID
                                                         clientSecret:self.BBClientSecret];
    
    auth.shouldAuthorizeAllRequests = shouldAuthorizeAllRequests;
    
    return auth;
}

// The auth finish selector
- (void)viewController:(BrightBot *)viewController
      finishedWithAuth:(GTMOAuth2Authentication *)auth
                 error:(NSError *)error {
    
    if (error != nil) {
        // Authentication failed (perhaps the user denied access, or closed the
        // window before granting access)
        NSLog(@"Authentication error: %@", error);
        NSData *responseData = [[error userInfo] objectForKey:@"data"]; // kGTMHTTPFetcherStatusDataKey
        if ([responseData length] > 0) {
            // show the body of the server's authentication failure response
            NSString *str = [[NSString alloc] initWithData:responseData
                                                   encoding:NSUTF8StringEncoding];
            NSLog(@"%@", str);
        }
        
        self.auth = nil;
        
        // Close the auth controller even if failed.
        
        [authController dismissViewControllerAnimated:YES completion:nil];
    } else {
        // Sign-in succeeded
        
        // Save the authentication object for use elsewhere.
        self.auth = auth;
        
        // Call the method 
        authFinish();
        
        // Close the auth controller
        [authController dismissViewControllerAnimated:NO completion:nil];
    }
}

- (void)configure:(NSString *)client_id client_secret:(NSString *)client_secret {
    self.BBClientID = client_id;
    self.BBClientSecret = client_secret;
    
    // Get the saved authentication, if any, from the keychain.
    GTMOAuth2Authentication *auth = nil;
    
    auth = [self brightbotAuth];
    if (auth) {
        
        // Load from Keychain
        [BrightBot authorizeFromKeychainForName:kKeychainItemName
                                                    authentication:auth
                                                             error:NULL];
    }
    
    // Retain the authentication object, which holds the auth tokens
    //
    // We can determine later if the auth object contains an access token
    // by calling its -canAuthorize method
    self.auth = auth;
}

- (id)init {
    
    return self;
}

+ (BrightBot *)sharedInstance {
    static BrightBot *sharedInstance;
    
    @synchronized(self)
    {
        if (sharedInstance == nil) {

            sharedInstance = [[BrightBot alloc] init];
        }
        
        return sharedInstance;
    }
}

-(void)signOut {
    
    NSHTTPCookieStorage* cookies = [NSHTTPCookieStorage sharedHTTPCookieStorage];
    
    NSArray *allCookies = [cookies cookies];
    
    for(NSHTTPCookie *cookie in allCookies) {
        if([[cookie domain] rangeOfString:@"brightbot"].location != NSNotFound) {
            [cookies deleteCookie:cookie];
        }
    }
    
    [BrightBot removeAuthFromKeychainForName:kKeychainItemName];
    self.auth = nil;
    
}

- (void)authenticate:(void (^)(void))success error:(void (^)(NSError* error))error {
    [self signOut];
    
    GTMOAuth2Authentication *auth = [self brightbotAuth];
    
    // Specify the appropriate scope string, if any, according to the service's API documentation
    auth.scope = @"full_access";
    
    NSString* urlString = [[NSString alloc] initWithFormat:@"%@/oauth/authorize", kBrightBotAPIBase];
    NSURL *authURL = [NSURL URLWithString:urlString];
    
    // Display the authentication view
    
    // Setup the custom view    
    authController = [[BrightBot alloc] initWithAuthentication:auth
                                  authorizationURL:authURL
                                  keychainItemName:kKeychainItemName
                                          delegate:self
                                  finishedSelector:@selector(viewController:finishedWithAuth:error:)];
    
    
    UIViewController *rootVC = [[[[[UIApplication sharedApplication] keyWindow] subviews] objectAtIndex:0] nextResponder];
    [rootVC presentViewController:authController animated:YES completion:nil];
    
    authFinish = [success copy];
}


- (BOOL)authenticated {
    return [self.auth canAuthorize];
}

- (void)getJSON:(NSString*)path success:(void (^)(NSDictionary* json))success
          error:(void (^)(NSError* error))error {
    
    // Get JSON data from path 
    [self getData:path success:^(NSData *data) {
        
        NSDictionary* json = [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];
        success(json);
        
    } error:error ];
}

/*
 Helper Methods
 */

- (NSMutableURLRequest*)setupRequest:(NSString*)path {
    
    
    NSString* urlString          = [[NSString alloc] initWithFormat:@"%@/%@%@", kBrightBotAPIBase, kBrightBotAPIVersion, path];
    NSURL* url                   = [NSURL URLWithString:urlString];
    NSMutableURLRequest* request = [[NSMutableURLRequest alloc] initWithURL:url];
    
    return request;
}

- (void)sendData:(NSString*)path
          method:(NSString*)method
            data:(NSString*)data
         success:(void(^)(NSData* thisData))success
           error:(void(^)(NSError* error))reqError {
    
    NSMutableURLRequest* request = [self setupRequest:path];
    
    [self.auth authorizeRequest:request
              completionHandler:^(NSError *error) {
                  if (error == nil) {
                      // every request could introduce a new refresh token, since the GTM library
                      // doesn't save it properly internally, we're working around it here.
                      [BrightBot saveParamsToKeychainForName:kKeychainItemName
                                                                 authentication:self.auth];
                      
                      // the request has been authorized
                      
                      [request setHTTPMethod:method];
                      [request setValue:@"application/x-www-form-urlencoded"
                     forHTTPHeaderField:@"Content-type"];
                      
                      if ( data != nil ) {
                          NSString *postString = [NSString stringWithFormat:@"data=%@",data];
                          [request setHTTPBody:[postString dataUsingEncoding:NSUTF8StringEncoding]];
                      }
                      
                      [NSURLConnection sendAsynchronousRequest:request
                                                         queue:[NSOperationQueue mainQueue]
                                             completionHandler:^(NSURLResponse* response, NSData* body, NSError* requestError) {
                                                 
                                                 if (!response && requestError) {
                                                     if ([requestError.domain isEqualToString:@"NSURLErrorDomain"] &&
                                                         requestError.code == NSURLErrorUserCancelledAuthentication) {
                                                         reqError([NSError errorWithDomain:@"com.brightbot.sdk" code:0 userInfo:
                                                                   [NSDictionary dictionaryWithObject:@"Authentication failed" forKey:@"message"]]);
                                                     } else { 
                                                         NSLog(@"%@", requestError);
                                                         reqError(requestError);
                                                     }
                                                     return;
                                                 }
                                                 
                                                 success(body);
                                             }];
                  } else {
                      // the request isn't authorized, pass error up
                      reqError(error);
                  }
              }];

    
}


-(void)sendFile:(NSString*)path
         method:(NSString*)method
           data:(NSString*)data
  file_contents:(NSMutableDictionary*)file_contents
        success:(void(^)(NSData* thisData))success
          error:(void(^)(NSError* error))reqError {
    
    NSMutableURLRequest* request = [self setupRequest:path];
    
    [self.auth authorizeRequest:request
              completionHandler:^(NSError *error) {
                  if (error == nil) {
                      // every request could introduce a new refresh token, since the GTM library
                      // doesn't save it properly internally, we're working around it here.
                      [BrightBot saveParamsToKeychainForName:kKeychainItemName
                                                                 authentication:self.auth];
                      
                      // We're going to build this form request ourselves.
                      
                      // the request has been authorized
                      NSString *boundary = @"0Xvdfegrdf876fRD";
                      
                      [request setHTTPMethod:method];
                      
                      // Build the multi-part form submission to the API
                      NSString *contentType = [NSString stringWithFormat:@"multipart/form-data; boundary=%@",boundary];
                      [request addValue:contentType forHTTPHeaderField: @"Content-Type"];
                      
                      NSMutableData *body = [NSMutableData data];
                      
                      // Do this for each file_content file object we have
                      for(id key in file_contents) {
                          NSData *this_file = [file_contents objectForKey:key];
                          
                          [body appendData:[[NSString stringWithFormat:@"--%@\r\n",boundary] dataUsingEncoding:NSUTF8StringEncoding]];
                          [body appendData:[[NSString stringWithFormat:@"Content-Disposition: form-data; name=\"%@\"; filename=\"%@.file\"\r\n",(NSString*)key,(NSString*)key] dataUsingEncoding:NSUTF8StringEncoding]];
                          [body appendData:[@"Content-Type: application/octet-stream\r\n\r\n"
                                            dataUsingEncoding:NSUTF8StringEncoding]];
                          [body appendData:[NSData dataWithData:this_file]];
                      }
                      
                      [body appendData:[[NSString stringWithFormat:@"\r\n--%@\r\n",boundary] dataUsingEncoding:NSUTF8StringEncoding]];
                      [body appendData:[@"Content-Disposition: form-data; name=\"data\";\r\n\r\n"
                                        dataUsingEncoding:NSUTF8StringEncoding]];
                      [body appendData:[data dataUsingEncoding:NSUTF8StringEncoding]];
                      [body appendData:[[NSString stringWithFormat:@"\r\n--%@--\r\n",boundary] dataUsingEncoding:NSUTF8StringEncoding]];
                      
                      [request setHTTPBody:body];
                      
                      [NSURLConnection sendAsynchronousRequest:request
                                                         queue:[NSOperationQueue mainQueue]
                                             completionHandler:^(NSURLResponse* response, NSData* body, NSError* requestError) {
                                                 
                                                 if (!response && requestError) {
                                                     if ([requestError.domain isEqualToString:@"NSURLErrorDomain"] &&
                                                         requestError.code == NSURLErrorUserCancelledAuthentication) {
                                                         reqError([NSError errorWithDomain:@"com.brightbot.sdk" code:0 userInfo:
                                                                [NSDictionary dictionaryWithObject:@"Authentication failed" forKey:@"message"]]);
                                                     } else { 
                                                         NSLog(@"%@", requestError);
                                                         reqError(requestError);
                                                     }
                                                     return;
                                                 }
                                                 
                                                 success(body);
                                             }];

            
                  } else {
                      // the request isn't authorized, pass error up
                      reqError(error);
                  }
              }];    
    
}

- (void)getData:(NSString*)path
        success:(void (^)(NSData* thisData))success
          error:(void (^)(NSError* error))reqError {
    
    NSMutableURLRequest* request = [self setupRequest:path];
    
    [self.auth authorizeRequest:request
         completionHandler:^(NSError *error) {
             if (error == nil) {
                 // every request could introduce a new refresh token, since the GTM library
                 // doesn't save it properly internally, we're working around it here.
                 [BrightBot saveParamsToKeychainForName:kKeychainItemName
                                                            authentication:self.auth];
                 
                 // the request has been authorized
                 
                [NSURLConnection sendAsynchronousRequest:request
                    queue:[NSOperationQueue mainQueue]
                    completionHandler:^(NSURLResponse* response, NSData* body, NSError* requestError) {
                        
                        if (!response && requestError) {
                            if ([requestError.domain isEqualToString:@"NSURLErrorDomain"] &&
                                requestError.code == NSURLErrorUserCancelledAuthentication) {
                                reqError([NSError errorWithDomain:@"BrightBot" code:0 userInfo:
                                       [NSDictionary dictionaryWithObject:@"Authentication failed" forKey:@"message"]]);
                            } else {
                                NSLog(@"%@", requestError);
                                reqError(requestError);
                            }
                            return;
                        }
                        
                    success(body);
                    }];
             } else {
                 // the request isn't authorized, pass error up
                 reqError(error);
             }
         }];

}

/*
    API Call Methods
 */

- (void)logProgress:(NSString*)student_id
         time_spent:(NSNumber*)time_spent
                     data:(NSArray*)progress_items
                     success:(void (^)(void))success
                     error:(void (^)(NSError* error))error {
    
    /*
     params = {
     'activities': '[{"activity_tag":"tag1", "progress":"50", "goal":"100"}]',  # One activity progress
     'time_spent': '30'
     }
     */
    NSMutableString *progress_data = [NSMutableString stringWithString:@"{\"activities\":["];
    for (BBActivityProgress* progress_item in progress_items) {
        [progress_data appendString:[progress_item toJSON]];
    }
    [progress_data appendString:@"], "];
    NSString *time = [NSString stringWithFormat:@"\"time_spent\":%@}", time_spent];
    [progress_data appendString:time];    
    
    NSLog(progress_data);
    NSString* path = [NSString stringWithFormat:@"/progress/%@", student_id];
    
    [self sendData:path method:@"POST"
              data:progress_data
           success:^(NSData *data) {
               
               // No data comes back from this POST request
               success();
               
           } error:error];
}

- (void)getStudents:(void (^)(NSArray* students))success
              error:(void (^)(NSError* error))error {
    
    NSString* path = [NSString stringWithFormat:@"/student"];
    [self getJSON:path
          success:^(NSDictionary* json) {
              
              NSMutableArray* bbStudents = [[NSMutableArray alloc] init];
              for (NSDictionary* jsonStudent in [json objectForKey:@"data"]) {
                  BBStudent* bbStudent = [[BBStudent alloc] initWithResponseDictionary:jsonStudent];
                  [bbStudents addObject:bbStudent];
              }
              success(bbStudents);
          }
            error:error ];

}


- (void)addStudent:(BBStudent*)the_student
           success:(void (^)(id data))success
             error:(void (^)(NSError* error))error {
    
    // Check to see if the_student has NSData (files) in the dictionary
    NSMutableDictionary *student_dictionary = [NSMutableDictionary dictionaryWithDictionary:[the_student toDictionary]];
    NSMutableDictionary *student_files = [NSMutableDictionary dictionaryWithDictionary:@{}];
    
    if (the_student.profile_picture_data != nil) {
        [student_files setObject:the_student.profile_picture_data forKey:@"profile_picture"];
        the_student.profile_picture_data = nil;
    }
    
    NSString* path = [NSString stringWithFormat:@"/student"];
    
    NSError *JSONerror;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:student_dictionary
                                                       options:0
                                                         error:&JSONerror];
    
    if ([student_files count] > 0) {
        
        // We have data files
        [self sendFile:path method:@"POST"
                  data:[[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding]
            file_contents:student_files success:^(NSData *json) {
                
            success(json);
                
        } error:error ];
    } else {
        // No files to send to the server
        
        [self sendData:path method:@"POST"
                  data:[[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding]
               success:^(NSData *data) {
            
            success(data);
                   
        } error:error ];
        
    }
    
}

- (void)modifyStudent:(BBStudent*)the_student
              success:(void (^)(id data))success
                error:(void (^)(NSError* error))error {
    
    
    // Check to see if the_student has NSData (files) in the dictionary
    NSMutableDictionary *student_dictionary = [NSMutableDictionary dictionaryWithDictionary:[the_student toDictionary]];
    NSMutableDictionary *student_files = [NSMutableDictionary dictionaryWithDictionary:@{}];
    
    if (the_student.profile_picture_data != nil) {
        [student_files setObject:the_student.profile_picture_data forKey:@"profile_picture"];
        the_student.profile_picture_data = nil;
    }

    NSString* path = [NSString stringWithFormat:@"/student/%@", the_student.guid];
    
    NSError *JSONerror;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:student_dictionary
                                                       options:0
                                                         error:&JSONerror];
    
    if ( [student_files count] > 0) {
        // We have data files
        
        [self sendFile:path method:@"PUT"
                  data:[[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding]
         file_contents:student_files
               success:^(NSData *data) {
                   
                   // Nothing comes back from PUT requests
                   success(data);
                   
               } error:error ];
    } else {
        
        // No files to send to server
        [self sendData:path
                method:@"PUT" data:[[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding]
               success:^(NSData *data) {
                   
                   // Nothing comes back from PUT requests
                   success(data);
                   
               } error:error ];
        
    }
    
}

- (void)removeStudent:(BBStudent*)the_student
              success:(void (^)(void))success
                error:(void (^)(NSError* error))error {
    
    NSString* path = [NSString stringWithFormat:@"/student/%@", the_student.guid];
    
    [self sendData:path method:@"DELETE"
              data:nil
           success:^(NSData *data) {
               
               // No data comes back from DELETE requests
               success();
               
           } error:error ];
    
}

- (void)getFileContents:(BBStudent*)the_student
                success:(void (^)(NSArray* fileContents))success
                  error:(void (^)(NSError* error))error {
    
    NSString* path = [NSString stringWithFormat:@"/content/%@", the_student.guid];
    
    [self getJSON:path
          success:^(NSDictionary* json) {
              
              NSMutableArray* bbFileContents = [[NSMutableArray alloc] init];
              
              for (NSDictionary* jsonFileContent in [json objectForKey:@"data"]) {
                  BBFileContent* bbContent = [[BBFileContent alloc] initWithResponseDictionary:jsonFileContent];
                  [bbFileContents addObject:bbContent];
              }
              
              success(bbFileContents);
          } error:error ];
    
}

- (void)addFileContents:(BBStudent*)the_student
                   content:(BBFileContent*)content_data
                success:(void (^)(id data))success
                  error:(void (^)(NSError* error))error {
    
    // Transform the passed in content to our internal JSON format
    NSString *transformedContent = [NSString stringWithFormat:@"{\"item_meta\":\"%@\"}", content_data.metadata];
    
    NSString* path = [NSString stringWithFormat:@"/content/%@", the_student.guid];
    
    NSMutableDictionary *file_contents = [NSMutableDictionary
                                 dictionaryWithDictionary:@{
                                 @"content" : content_data.content_data}];
    [self sendFile:path
            method:@"POST"
              data:transformedContent
     file_contents:file_contents
           success:^(NSData *data) {
               
               success(data);
               
           } error:error ];
    
}

- (void)modifyFileContents:(BBFileContent*)content success:(void (^)(id data))success error:(void (^)(NSError* error))error {
    
    // Transform the passed in content to our internal JSON format
    NSString *transformedContent = @"";
    if ( content.metadata != nil ) {
        transformedContent = [NSString stringWithFormat:@"{\"item_meta\":\"%@\"}", content.metadata];
    }
    
    NSMutableDictionary *file_contents = [[NSMutableDictionary alloc] init];
    if ( content.content_data != nil ) {
        file_contents = [NSMutableDictionary
                         dictionaryWithDictionary:@{
                         @"content" : content.content_data}];
    }
    
    NSString* path = [NSString stringWithFormat:@"/content/%@", content.guid];
    
    [self sendFile:path
            method:@"PUT"
              data:transformedContent
     file_contents:file_contents
           success:^(NSData *data) {
               
               success(data);
               
           } error:error ];

}

- (void)removeFileContents:(BBFileContent*)content success:(void (^)(void))success error:(void (^)(NSError* error))error {
    
    NSString* path = [NSString stringWithFormat:@"/content/%@", content.guid];
    
    [self sendData:path method:@"DELETE"
              data:nil
           success:^(NSData *data) {
               
               // No data comes back from DELETE requests
               success();
               
           } error:error ];
}

- (void)dealloc {

}
@end

@implementation BBFileContent
@synthesize guid, metadata, path, content_data, created, updated;
- (id)initWithResponseDictionary:(NSDictionary *)file_content {
    if ((self = [super init])) {
        self.guid           = [file_content objectForKey:@"id"];
        self.metadata       = [file_content objectForKey:@"metadata"];
        self.path           = [file_content objectForKey:@"path"];
        self.content_data   = [file_content objectForKey:@"content_data"];
        self.created        = [file_content objectForKey:@"created"];
        self.updated        = [file_content objectForKey:@"updated"];
    }
    return self;
}
- (NSMutableDictionary*)toDictionary {
    NSMutableDictionary* dict = [[NSMutableDictionary alloc] init];
    [dict setObject:(self.guid          != nil ? self.guid : @"") forKey:@"id"];
    [dict setObject:(self.metadata      != nil ? self.metadata : @"") forKey:@"metadata"];
    [dict setObject:(self.path          != nil ? self.path : @"") forKey:@"path"];
    [dict setObject:(self.created       != nil ? self.created : @"") forKey:@"created"];
    [dict setObject:(self.updated       != nil ? self.updated : @"") forKey:@"updated"];
    return dict;
}
@end
 
@implementation BBStudent
@synthesize guid, name, profile_picture, profile_picture_data, created, updated;
- (id)initWithResponseDictionary:(NSDictionary *)student {
    if ((self = [super init])) {
        self.guid          = [student objectForKey:@"id"];
        self.name          = [student objectForKey:@"name"];
        self.profile_picture = [student objectForKey:@"profile_picture"];
        self.profile_picture_data = [student objectForKey:@"profile_picture_data"];
        self.created        = [student objectForKey:@"created"];
        self.updated        = [student objectForKey:@"updated"];
    }
    return self;
}
- (NSMutableDictionary*)toDictionary {
    NSMutableDictionary* dict = [[NSMutableDictionary alloc] init];
    [dict setObject:(self.guid         != nil ? self.guid : @"") forKey:@"id"];
    [dict setObject:(self.name         != nil ? self.name : @"") forKey:@"name"];
    [dict setObject:(self.profile_picture != nil ? self.profile_picture : @"") forKey:@"profile_picture"];
    [dict setObject:(self.created      != nil ? self.created : @"") forKey:@"created"];
    [dict setObject:(self.updated      != nil ? self.updated : @"") forKey:@"updated"];
    return dict;
}

@end
     
@implementation BBActivityProgress
@synthesize activity_tag, progress, goal;
- (NSString*)toJSON {
    NSMutableDictionary* dict = [[NSMutableDictionary alloc] init];
    [dict setObject:(self.activity_tag  != nil ? self.activity_tag : @"") forKey:@"activity_tag"];
    [dict setObject:(self.progress      != nil ? self.progress : @"") forKey:@"progress"];
    [dict setObject:(self.goal          != nil ? self.goal : @"") forKey:@"goal"];
    
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:dict options:kNilOptions error:nil];
    NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    
    return jsonString;
}
@end