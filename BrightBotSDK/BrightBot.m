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
GTMOAuth2ViewControllerTouch *authController;

@synthesize auth = mAuth;
@synthesize BBClientID = mBBClientID;
@synthesize BBClientSecret = mBBClientSecret;

// TODO need to make sure that the API is initialized before allowing any calls

static NSString *const kKeychainItemName = @"BrightBot OAuth";
static NSString *const kServiceProviderName = @"BrightBot Service";

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
    
    GTMOAuth2Authentication *auth;
    auth = [GTMOAuth2Authentication authenticationWithServiceProvider:kServiceProviderName
                                                             tokenURL:tokenURL
                                                          redirectURI:redirectURI
                                                             clientID:self.BBClientID
                                                         clientSecret:self.BBClientSecret];
    return auth;
}

// The auth finish selector
- (void)viewController:(GTMOAuth2ViewControllerTouch *)viewController
      finishedWithAuth:(GTMOAuth2Authentication *)auth
                 error:(NSError *)error {
    
    if (error != nil) {
        // Authentication failed (perhaps the user denied access, or closed the
        // window before granting access)
        NSLog(@"Authentication error: %@", error);
        NSData *responseData = [[error userInfo] objectForKey:@"data"]; // kGTMHTTPFetcherStatusDataKey
        if ([responseData length] > 0) {
            // show the body of the server's authentication failure response
            NSString *str = [[[NSString alloc] initWithData:responseData
                                                   encoding:NSUTF8StringEncoding] autorelease];
            NSLog(@"%@", str);
        }
        
        self.auth = nil;
        
        // Close the auth controller even if failed.
        [authController dismissViewControllerAnimated:NO completion:nil];
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
        [GTMOAuth2ViewControllerTouch authorizeFromKeychainForName:kKeychainItemName
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
    
    [GTMOAuth2ViewControllerTouch removeAuthFromKeychainForName:kKeychainItemName];
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
    authController = [[[GTMOAuth2ViewControllerTouch alloc] initWithAuthentication:auth
                                                                  authorizationURL:authURL
                                                                  keychainItemName:kKeychainItemName
                                                                          delegate:self
                                                                  finishedSelector:@selector(viewController:finishedWithAuth:error:)] autorelease];
    
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
    
    // Before every request save state in keychain... for now.
    [GTMOAuth2ViewControllerTouch saveParamsToKeychainForName:kKeychainItemName
                                               authentication:self.auth];
    
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


- (void)addStudent:(NSDictionary*)the_student
           success:(void (^)(id data))success
             error:(void (^)(NSError* error))error {
    
    // Check to see if the_student has NSData (files) in the dictionary
    NSMutableDictionary *student_dictionary = [NSMutableDictionary dictionaryWithDictionary:the_student];
    NSMutableDictionary *student_files = [NSMutableDictionary dictionaryWithDictionary:@{}];
    
    for(id key in the_student) {
        id this_value = [the_student objectForKey:key];
        
        if ([this_value isKindOfClass:[NSData class]]) {
            
            // Remove this object from the student textual data and move to a new object
            [student_dictionary removeObjectForKey:key];
            [student_files setObject:this_value forKey:key];
            
        }
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

- (void)modifyStudent:(NSDictionary*)the_student
              success:(void (^)(void))success
                error:(void (^)(NSError* error))error {
    
        
    // Check to see if the_student has NSData (files) in the dictionary
    NSMutableDictionary *student_dictionary = [NSMutableDictionary dictionaryWithDictionary:the_student];
    NSMutableDictionary *student_files = [NSMutableDictionary dictionaryWithDictionary:@{}];
    
    for(id key in the_student) {
        id this_value = [the_student objectForKey:key];
        
        if ([this_value isKindOfClass:[NSData class]]) {
            
            // Remove this object from the student textual data and move to a new object
            [student_dictionary removeObjectForKey:key];
            [student_files setObject:this_value forKey:key];
            
        }
    }
    
    NSString* path = [NSString stringWithFormat:@"/student/%@", the_student[@"id"]];
    
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
                   success();
                   
               } error:error ];
    } else {
        
        // No files to send to server
        [self sendData:path
                method:@"PUT" data:[[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding]
               success:^(NSData *data) {
                   
                   // Nothing comes back from PUT requests
                   success();
                   
               } error:error ];
        
    }
    
}

- (void)removeStudent:(NSDictionary*)the_student
              success:(void (^)(void))success
                error:(void (^)(NSError* error))error {
    
    NSString* path = [NSString stringWithFormat:@"/student/%@", the_student[@"id"]];
    
    [self sendData:path method:@"DELETE"
              data:nil
           success:^(NSData *data) {
               
               // No data comes back from DELETE requests
               success();
               
           } error:error ];
    
}

- (void)getFileContents:(NSString*)student_id
                success:(void (^)(NSArray* fileContents))success
                  error:(void (^)(NSError* error))error {
    
    NSString* path = [NSString stringWithFormat:@"/content/%@", student_id];
    
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

- (void)addFileContents:(NSString*)student_id
                   data:content_data
                   file:the_file
                success:(void (^)(id data))success
                  error:(void (^)(NSError* error))error {
    
    // Transform the passed in content to our internal JSON format
    NSString *transformedContent = [NSString stringWithFormat:@"{\"item_meta\":\"%@\"}", content_data];
    
    NSString* path = [NSString stringWithFormat:@"/content/%@", student_id];
    
    NSMutableDictionary *file_contents = [NSMutableDictionary
                                 dictionaryWithDictionary:@{
                                 @"content" : the_file}];
    [self sendFile:path
            method:@"POST"
              data:transformedContent
     file_contents:file_contents
           success:^(NSData *data) {
               
               success(data);
               
           } error:error ];
    
}


@end

@implementation BBFileContent
@synthesize guid, metadata, path;
- (id)initWithResponseDictionary:(NSDictionary *)student {
    if ((self = [super init])) {
        self.guid           = [student objectForKey:@"id"];
        self.metadata       = [student objectForKey:@"metadata"];
        self.path           = [student objectForKey:@"path"];
    }
    return self;
}
@end
 
@implementation BBStudent
@synthesize guid, name;
- (id)initWithResponseDictionary:(NSDictionary *)student {
    if ((self = [super init])) {
        self.guid          = [student objectForKey:@"id"];
        self.name          = [student objectForKey:@"name"];
    }
    return self;
}
@end


@implementation BBTeacher
@synthesize guid, lastModified, sisID, email, firstName, middleName, lastName, title;
- (id)initWithResponseDictionary:(NSDictionary *)teacher {
    if ((self = [super init])) {
        self.guid         = [teacher objectForKey:@"id"];
        self.lastModified = [teacher objectForKey:@"last_modified"];
        self.sisID        = [teacher objectForKey:@"sis_id"];
        self.email        = [teacher objectForKey:@"email"];
        self.firstName    = [[teacher objectForKey:@"name"] objectForKey:@"first"];
        self.middleName   = [[teacher objectForKey:@"name"] objectForKey:@"middle"];
        self.lastName     = [[teacher objectForKey:@"name"] objectForKey:@"last"];
        self.title        = [teacher objectForKey:@"title"];
    }
    return self;
}
- (NSString*)description {
    NSMutableDictionary* dict = [[NSMutableDictionary alloc] init];
    [dict setObject:(self.guid         != nil ? self.guid : @"") forKey:@"guid"];
    [dict setObject:(self.lastModified != nil ? self.lastModified : @"") forKey:@"lastModified"];
    [dict setObject:(self.sisID        != nil ? self.sisID : @"") forKey:@"sisID"];
    [dict setObject:(self.email        != nil ? self.email : @"") forKey:@"email"];
    [dict setObject:(self.firstName    != nil ? self.firstName : @"") forKey:@"firstName"];
    [dict setObject:(self.middleName   != nil ? self.middleName : @"") forKey:@"middleName"];
    [dict setObject:(self.lastName     != nil ? self.lastName : @"") forKey:@"lastName"];
    [dict setObject:(self.title        != nil ? self.title : @"") forKey:@"title"];
    return [dict description];
}
- (NSString*)url {
    return [NSString stringWithFormat:@"/teachers/%@", self.guid];
}
@end

@implementation BBSchool
@synthesize guid, lastModified, sisID, stateID, ncesID, schoolNumber, lowGrade, highGrade, principalName, principalEmail, name, address, city, state, zip, phone;
- (id) initWithResponseDictionary:(NSDictionary *)school {
    if ((self = [super init])) {
        self.guid =           [school objectForKey:@"guid"];
        self.lastModified =   [school objectForKey:@"last_modified"];
        self.sisID =          [school objectForKey:@"sis_id"];
        self.stateID =        [school objectForKey:@"state_id"];
        self.ncesID =         [school objectForKey:@"nces_id"];
        self.schoolNumber =   [school objectForKey:@"school_number"];
        self.lowGrade =       [school objectForKey:@"low_grade"];
        self.highGrade =      [school objectForKey:@"high_grade"];
        self.principalName =  [[school objectForKey:@"principal"] objectForKey:@"name"];
        self.principalEmail = [[school objectForKey:@"principal"] objectForKey:@"email"];
        self.name =           [school objectForKey:@"name"];
        self.address =        [[school objectForKey:@"location"] objectForKey:@"address"];
        self.city =           [[school objectForKey:@"location"] objectForKey:@"city"];
        self.state =          [[school objectForKey:@"location"] objectForKey:@"state"];
        self.zip =            [[school objectForKey:@"location"] objectForKey:@"zip"];
        self.phone =          [school objectForKey:@"phone"];
    }
    return self;
}
- (NSString*)description {
    NSMutableDictionary* dict = [[NSMutableDictionary alloc] init];
    [dict setObject:(self.guid           != nil ? self.guid : @"") forKey:@"guid"];
    [dict setObject:(self.lastModified   != nil ? self.lastModified : @"") forKey:@"lastModified"];
    [dict setObject:(self.sisID          != nil ? self.sisID : @"") forKey:@"sisID"];
    [dict setObject:(self.stateID        != nil ? self.stateID : @"") forKey:@"stateID"];
    [dict setObject:(self.ncesID         != nil ? self.ncesID : @"") forKey:@"ncesID"];
    [dict setObject:(self.schoolNumber   != nil ? self.schoolNumber : @"") forKey:@"schoolNumber"];
    [dict setObject:(self.lowGrade       != nil ? self.lowGrade : @"") forKey:@"lowGrade"];
    [dict setObject:(self.highGrade      != nil ? self.highGrade : @"") forKey:@"highGrade"];
    [dict setObject:(self.principalName  != nil ? self.principalName : @"") forKey:@"principalName"];
    [dict setObject:(self.principalEmail != nil ? self.principalEmail : @"") forKey:@"principalEmail"];
    [dict setObject:(self.name           != nil ? self.name : @"") forKey:@"name"];
    [dict setObject:(self.address        != nil ? self.address : @"") forKey:@"address"];
    [dict setObject:(self.city           != nil ? self.city : @"") forKey:@"city"];
    [dict setObject:(self.state          != nil ? self.state : @"") forKey:@"state"];
    [dict setObject:(self.zip            != nil ? self.zip : @"") forKey:@"zip"];
    [dict setObject:(self.phone          != nil ? self.phone : @"") forKey:@"phone"];
    return [dict description];
}
- (NSString*)url {
    return [NSString stringWithFormat:@"/schools/%@", self.guid];
}
@end

