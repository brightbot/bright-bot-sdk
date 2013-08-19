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
#import <CommonCrypto/CommonHMAC.h>
#import "NSDataBase64.h"

@implementation BrightBot 

// Instance vars
void (^authFinish)();
UIViewController *authController;
UIWebView *thisWebView;

// TODO need to make sure that the API is initialized before allowing any calls

- (id)init
{
    self = [super init];
    if(self) {

        NSUserDefaults *standardUserDefaults = [NSUserDefaults standardUserDefaults];
        NSString *private_key = [standardUserDefaults stringForKey:@"bb.private_key"];
        NSString *teacher_id = [standardUserDefaults stringForKey:@"bb.teacher_id"];
        NSString *api_key = [standardUserDefaults stringForKey:@"bb.api_key"];

        self.api_key = api_key;
        self.private_key = private_key;
        self.teacher_id = teacher_id;
        self.app_id = [[NSBundle mainBundle] bundleIdentifier]; // Grab the bundle of the current app

        if (private_key && teacher_id && api_key) {
            [self setAuthenticated:YES];
        } else {
            [self setAuthenticated:NO];
        }
    }

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

// JSON fetch boilerplate
- (void)getJSON:(NSString*)path success:(void (^)(NSDictionary* json))success
                                  error:(void (^)(NSError* error))error {
    [self getData:path success:^(NSData *data) {
        NSDictionary* json = [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];
        success(json);
    } error:error ];
}

- (NSString *)generateHashedString:(NSString*)key data:(NSString*)data {

    const char *cKey  = [key cStringUsingEncoding:NSASCIIStringEncoding];
    const char *cData = [data cStringUsingEncoding:NSASCIIStringEncoding];
    
    unsigned char cHMAC[CC_SHA256_DIGEST_LENGTH];
    
    CCHmac(kCCHmacAlgSHA256, cKey, strlen(cKey), cData, strlen(cData), cHMAC);
    
    NSData *HMAC = [[NSData alloc] initWithBytes:cHMAC
                                          length:sizeof(cHMAC)];
    
    return [HMAC base64Encoding];
}

- (NSMutableURLRequest*)setupRequest:(NSString*)path {
    NSString* urlString          = [[NSString alloc] initWithFormat:@"%@%@", kBrightBotAPIBase, path];
    
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    NSTimeZone *timeZone = [NSTimeZone timeZoneWithName:@"UTC"];
    [dateFormatter setTimeZone:timeZone];
    [dateFormatter setDateFormat:@"yyyy-MMMM-d'T'HH:mm:ssZZZZZ"];
    NSString *currentDate = [dateFormatter stringFromDate:[NSDate date]];
    
    NSString* encryptData        = [NSString stringWithFormat:@"%@%@%@", self.api_key, path, currentDate];
    
    // Build signature to pass onto server
    NSString *signature          = [self generateHashedString:self.private_key data:encryptData];
    
    NSLog(@"Signature %@", signature);
    NSLog(@"API Key %@", self.api_key);
    
    
    NSURL* url                   = [NSURL URLWithString:urlString];
    NSMutableURLRequest* request = [[NSMutableURLRequest alloc] initWithURL:url];
    
    // Setup the request properly
    [request setValue:signature forHTTPHeaderField:@"x-brightbot-signature"];
    [request setValue:self.api_key forHTTPHeaderField:@"x-brightbot-api-key"];
    [request setValue:currentDate forHTTPHeaderField:@"x-brightbot-timestamp"];
    [request setValue:self.teacher_id forHTTPHeaderField:@"x-brightbot-teacher"];
    [request setValue:@"1" forHTTPHeaderField:@"x-brightbot-version"];
    
    return request;
}

- (void)sendData:(NSString*)path method:(NSString*)method data:(NSString*)data success:(void(^)(NSData* thisData))success
           error:(void(^)(NSError* error))error {
    NSMutableURLRequest* request = [self setupRequest:path];
    
    [request setHTTPMethod:method];
    [request setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-type"];
    
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
               error([NSError errorWithDomain:@"BrightBot" code:0 userInfo:
                      [NSDictionary dictionaryWithObject:@"Authentication failed" forKey:@"message"]]);
           } else { // TODO handle 1) api offline, 2) error response in json
               NSLog(@"%@", requestError);
               error(requestError);
           }
           return;
        }
        success(body);
    }];
    
    
}


-(void)sendFile:(NSString*)path method:(NSString*)method data:(NSString*)data file_contents:(NSMutableDictionary*)file_contents success:(void(^)(NSData* thisData))success
          error:(void(^)(NSError* error))error {
    
    NSMutableURLRequest* request = [self setupRequest:path];
    
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
                   error([NSError errorWithDomain:@"BrightBot" code:0 userInfo:
                          [NSDictionary dictionaryWithObject:@"Authentication failed" forKey:@"message"]]);
               } else { // TODO handle 1) api offline, 2) error response in json
                   NSLog(@"%@", requestError);
                   error(requestError);
               }
               return;
           }
           success(body);
       }];

}

// URL fetch boilerplate
- (void)getData:(NSString*)path success:(void (^)(NSData* thisData))success
                                                                 error:(void (^)(NSError* error))error {
    NSMutableURLRequest* request = [self setupRequest:path];
    
    [NSURLConnection sendAsynchronousRequest:request
                                       queue:[NSOperationQueue mainQueue]
                           completionHandler:^(NSURLResponse* response, NSData* body, NSError* requestError) {
       if (!response && requestError) {
           if ([requestError.domain isEqualToString:@"NSURLErrorDomain"] &&
               requestError.code == NSURLErrorUserCancelledAuthentication) {
               error([NSError errorWithDomain:@"BrightBot" code:0 userInfo:
                      [NSDictionary dictionaryWithObject:@"Authentication failed" forKey:@"message"]]);
           } else { // TODO handle 1) api offline, 2) error response in json
               NSLog(@"%@", requestError);
               error(requestError);
           }
           return;
       }
       success(body);
   }];
}

// Photo fetch boilerplate
/*- (void)getPhoto:(NSString*)path success:(void (^)(UIImage* photo))success
                                   error:(void (^)(NSError* error))error {
    [self getData:path accept:@"image/jpeg" success:^(NSData *data) {
        success([UIImage imageWithData:data]);
    } error:error ];
}*/

/*
- (void)getSchools:(void (^)(NSArray* schools))success error:(void (^)(NSError *error))error {
    // NSString *path = [NSString stringWithFormat:@"/districts/%@/schools?limit=5000", self.districtID];
    NSString *path = @"/schools?limit=5000";
    [self getJSON:path success:^(NSDictionary* json) {
        NSMutableArray* cleverSchools = [[NSMutableArray alloc] init];
        for (NSDictionary* jsonSection in [json objectForKey:@"data"]) {
            CleverSchool* school = [[CleverSchool alloc] initWithResponseDictionary:[jsonSection objectForKey:@"data"]];
            [cleverSchools addObject:school];
        }
        success(cleverSchools);
    } error:error];
}
*/

/*
- (void)getStudentsFromPath:(NSString*)path success:(void (^)(NSArray* students))success
                      error:(void (^)(NSError* error))error {
    [self getJSON:path success:^(NSDictionary* json) {
        NSMutableArray* cleverStudents = [[NSMutableArray alloc] init];
        for (NSDictionary* jsonStudent in [json objectForKey:@"data"]) {
            CleverStudent* cleverStudent = [[CleverStudent alloc] initWithResponseDictionary:[jsonStudent objectForKey:@"data"]];
            [cleverStudents addObject:cleverStudent];
        }
        success(cleverStudents);
    } error:error ];
}
*/

- (void)getStudents:(void (^)(NSArray* students))success error:(void (^)(NSError* error))error {
    
    if ( ![self authenticated] ) {
        // Set error if a pointer for the error was given
        if (error != NULL) {
            NSError *err = [NSError errorWithDomain:@"com.brightbot.sdk"
                                         code:100
                                     userInfo:[NSDictionary dictionaryWithObject:[NSString stringWithFormat:@"Not Authenticated"]  forKey:NSLocalizedDescriptionKey]];
            error(err);
        }
    } else {
        NSString* path = [NSString stringWithFormat:@"/students"];
        [self getJSON:path success:^(NSDictionary* json) {
            NSMutableArray* bbStudents = [[NSMutableArray alloc] init];
            for (NSDictionary* jsonStudent in [json objectForKey:@"data"]) {
                BBStudent* bbStudent = [[BBStudent alloc] initWithResponseDictionary:jsonStudent];
                [bbStudents addObject:bbStudent];
            }
            success(bbStudents);
        } error:error ];
    }

}


- (void)addStudent:(NSDictionary*)the_student success:(void (^)(id data))success error:(void (^)(NSError* error))error {
    if ( ![self authenticated] ) {
        // Set error if a pointer for the error was given
        if (error != NULL) {
            error = [NSError errorWithDomain:@"com.brightbot.sdk"
                                        code:100
                                    userInfo:[NSDictionary dictionaryWithObject:[NSString stringWithFormat:@"Not Authenticated"]  forKey:NSLocalizedDescriptionKey]];
        }
    } else {
    
        // Check to see if the_student has NSData (files) in the dictionary
        NSMutableDictionary *student_dictionary = [NSMutableDictionary dictionaryWithDictionary:the_student];
        NSMutableDictionary *student_files = [NSMutableDictionary
                                     dictionaryWithDictionary:@{}];
        
        for(id key in the_student) {
            id this_value = [the_student objectForKey:key];
            
            if ([this_value isKindOfClass:[NSData class]]) {
              
                // Remove this object from the student textual data and move to a new object
                [student_dictionary removeObjectForKey:key];
                [student_files setObject:this_value forKey:key];
                
            }
        }
        
        NSString* path = [NSString stringWithFormat:@"/students"];
        
        NSError *JSONerror;
        NSData *jsonData = [NSJSONSerialization dataWithJSONObject:student_dictionary
                                                           options:0
                                                             error:&JSONerror];
        
        if ([student_files count] > 0) {
            // We have data files
            
            [self sendFile:path method:@"POST" data:[[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding]
                file_contents:student_files success:^(NSData *json) {
                success(json);
            } error:error ];
        } else {
            [self sendData:path method:@"POST" data:[[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding] success:^(NSData *data) {
                success(data);
            } error:error ];
        }
    }
    
}

- (void)modifyStudent:(NSDictionary*)the_student success:(void (^)(void))success error:(void (^)(NSError* error))error {
    
    if ( ![self authenticated] ) {
        // Set error if a pointer for the error was given
        if (error != NULL) {
            error = [NSError errorWithDomain:@"com.brightbot.sdk"
                                        code:100
                                    userInfo:[NSDictionary dictionaryWithObject:[NSString stringWithFormat:@"Not Authenticated"]  forKey:NSLocalizedDescriptionKey]];
        }
    } else {
        
        // Check to see if the_student has NSData (files) in the dictionary
        NSMutableDictionary *student_dictionary = [NSMutableDictionary dictionaryWithDictionary:the_student];
        NSMutableDictionary *student_files = [NSMutableDictionary
                                              dictionaryWithDictionary:@{}];
        
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
        
        if ([student_files count] > 0) {
            // We have data files
            
            [self sendFile:path method:@"PUT" data:[[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding]
             file_contents:student_files success:^(NSData *json) {
                 success();
             } error:error ];
        } else {
            [self sendData:path method:@"PUT" data:[[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding]  success:^(NSData *data) {
                success();
            } error:error ];
        }
    }
    
}

- (void)removeStudent:(NSDictionary*)the_student success:(void (^)(void))success error:(void (^)(NSError* error))error {

    if ( ![self authenticated] ) {
        // Set error if a pointer for the error was given
        if (error != NULL) {
            error = [NSError errorWithDomain:@"com.brightbot.sdk"
                                        code:100
                                    userInfo:[NSDictionary dictionaryWithObject:[NSString stringWithFormat:@"Not Authenticated"]  forKey:NSLocalizedDescriptionKey]];
        }
    } else {
    
        NSString* path = [NSString stringWithFormat:@"/student/%@", the_student[@"id"]];
        
        [self sendData:path method:@"DELETE" data:nil success:^(NSData *data) {
                success();
            } error:error ];
    }
    
}

- (void)getFileContents:(NSString*)student_id success:(void (^)(NSArray* fileContents))success error:(void (^)(NSError* error))error {
    
    if ( ![self authenticated] ) {
        // Set error if a pointer for the error was given
        if (error != NULL) {
            error = [NSError errorWithDomain:@"com.brightbot.sdk"
                                        code:100
                                    userInfo:[NSDictionary dictionaryWithObject:[NSString stringWithFormat:@"Not Authenticated"]  forKey:NSLocalizedDescriptionKey]];
        }
    } else {
        NSString* path = [NSString stringWithFormat:@"/content/%@", student_id];
        [self getJSON:path success:^(NSDictionary* json) {
            NSMutableArray* bbFileContents = [[NSMutableArray alloc] init];
            for (NSDictionary* jsonFileContent in [json objectForKey:@"data"]) {
                BBFileContent* bbContent = [[BBFileContent alloc] initWithResponseDictionary:jsonFileContent];
                [bbFileContents addObject:bbContent];
            }
            success(bbFileContents);
        } error:error ];
    }
    
}

- (void)addFileContents:(NSString*)student_id data:content_data file:the_file success:(void (^)(void))success error:(void (^)(NSError* error))error {
    
    if ( ![self authenticated] ) {
        // Set error if a pointer for the error was given
        if (error != NULL) {
            error = [NSError errorWithDomain:@"com.brightbot.sdk"
                                        code:100
                                    userInfo:[NSDictionary dictionaryWithObject:[NSString stringWithFormat:@"Not Authenticated"]  forKey:NSLocalizedDescriptionKey]];
        }
    } else {
        // Transform the passed in content to our internal JSON format
        NSString *transformedContent = [NSString stringWithFormat:@"{\"app_id\":\"%@\", \"item_meta\":\"%@\"}", self.app_id, content_data];
        
        NSString* path = [NSString stringWithFormat:@"/content/%@", student_id];
        
        NSMutableDictionary *file_contents = [NSMutableDictionary
                                     dictionaryWithDictionary:@{
                                     @"content" : the_file,
                                     }];
        [self sendFile:path method:@"POST" data:transformedContent file_contents:file_contents success:^(NSData *json) {
            success();
        } error:error ];
    }
    
}

-(void)signOut {
    
    NSString* urlString = [[NSString alloc] initWithFormat:@"%@/api_logout", kBrightBotAPIBase];
    NSURL *nsUrl=[NSURL URLWithString:urlString];
    
    // Hidden webview to handle redirect
    thisWebView = [[UIWebView alloc] initWithFrame:CGRectZero];
    [thisWebView setDelegate:self];
    [thisWebView loadRequest:[NSURLRequest requestWithURL:nsUrl]];
    
    // Remove from the NSUserDefaults objects
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"bb.private_key"];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"bb.teacher_id"];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"bb.api_key"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    // Clear out the local instance vars
    self.api_key = nil;
    self.private_key = nil;
    self.teacher_id = nil;
    
    [self setAuthenticated:NO];
}

- (void)authenticate:(NSString *)api_key success:(void (^)(void))success error:(void (^)(NSError* error))error {
    // Save off the API key
    self.api_key = api_key;
    
    // Apple specifies that a root view controller should exist for every app, so we rely on it here.
    UIViewController *rootVC = [[[[[UIApplication sharedApplication] keyWindow] subviews] objectAtIndex:0] nextResponder];
    authController = [[UIViewController alloc] init];
    authController.modalPresentationStyle = UIModalPresentationFormSheet;
    authController.modalTransitionStyle = UIModalTransitionStyleCoverVertical;
    [rootVC presentViewController:authController animated:YES completion:nil];
    
    CGRect webFrame = CGRectMake(0, 0, 0, 0);
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
        // iPhone Code
        webFrame = CGRectMake(0, 0,  320, 460);
        authController.view.superview.frame = CGRectMake(0,0, 320, 460); //it's important to do this after presentModalViewController
        authController.view.superview.center = (UIInterfaceOrientationIsPortrait(rootVC.interfaceOrientation) ?
                                                CGPointMake(160, 220) : CGPointMake(220, 160));
    } else {
        // iPad Code
        webFrame = CGRectMake(0, 0, 480, 320);
        authController.view.superview.frame = CGRectMake(0,0, 540, 540); //it's important to do this after presentModalViewController
        authController.view.superview.center = (UIInterfaceOrientationIsPortrait(rootVC.interfaceOrientation) ?
                                                CGPointMake(384, 512) : CGPointMake(512, 384));
    }
    
    thisWebView = [[UIWebView alloc] initWithFrame:webFrame];
    
    NSString* urlString = [[NSString alloc] initWithFormat:@"%@/api_login", kBrightBotAPIBase];
    
    NSURL *nsUrl=[NSURL URLWithString:urlString];
    NSURLRequest *nsrequest=[NSURLRequest requestWithURL:nsUrl];
    [thisWebView setDelegate:self];
    [thisWebView loadRequest:nsrequest];
    
    thisWebView.center = authController.view.center;
    
    [authController.view addSubview:thisWebView];
    
    // Save the handler to call later
    authFinish = [success copy];
    
}

// Used to intercept the navigation requests of this implemention of UIWebViewDelegant interface
// Really used to watch for the bb-auth URL call so that we can save data and close auth webview
- (BOOL)webView:(UIWebView *)ourWebView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType {
    
    NSURL *url = request.URL;
    NSLog(@"URL Nav %@", url);
    
    if ([[url scheme] isEqualToString:@"bb-auth"]) {
        
        NSString *q = [url query];
        NSArray *pairs = [q componentsSeparatedByString:@"&"];
        NSMutableDictionary *kvPairs = [NSMutableDictionary dictionary];
        for (NSString *pair in pairs) {
            NSArray *bits = [pair componentsSeparatedByString:@"="];
            NSString *key = [[bits objectAtIndex:0] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
            NSString *value = [[bits objectAtIndex:1] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
            [kvPairs setObject:value forKey:key];
        }
        
        // Setup the variables we got from the auth function
        self.private_key = [kvPairs objectForKey:@"access_token"];
        self.teacher_id = [kvPairs objectForKey:@"teacher_id"];
        
        // Save these in NSUserDefaults, TODO this is not secure but works well enough for now
        NSUserDefaults * standardUserDefaults = [NSUserDefaults standardUserDefaults];
        [standardUserDefaults setObject:self.private_key forKey:@"bb.private_key"];
        [standardUserDefaults setObject:self.teacher_id forKey:@"bb.teacher_id"];
        [standardUserDefaults setObject:self.api_key forKey:@"bb.api_key"];
        [standardUserDefaults synchronize];
        
        [self setAuthenticated:YES];
        
        authFinish();
        
        // Close up shop, auth done
        [authController dismissViewControllerAnimated:NO completion:nil];
        authController = nil;
        [thisWebView setDelegate:nil];
        thisWebView = nil;
        
        return YES;
    }
    return YES;
}

/*
- (void)getStudentsFor:(id)cleverObject success:(void (^)(NSArray* students))success
                                          error:(void (^)(NSError *error))error {
    // Students doesn't have a second level students endpoint
    if ([cleverObject isKindOfClass:[CleverStudent class]]) {
        error([NSError errorWithDomain:@"clever-ios" code:0 userInfo:nil]);
    }
    [self getStudentsFromPath:[NSString stringWithFormat:@"%@/%@", [cleverObject url], @"students?limit=100"] success:success error:error];
}
*/

/*
- (void)getPhotoFor:(CleverStudent*)student success:(void (^)(UIImage* image))success error:(void (^)(NSError *error))error {
    NSString *path = [NSString stringWithFormat:@"/students/%@/photo", student.guid];
    [self getPhoto:path success:^(UIImage *photo) {
        success(photo);
    } error:error];
}*/

- (void)didReceiveMemoryWarning {
    //[super didReceiveMemoryWarning]; // Releases the view if it doesn't have a superview
    // Release anything that's not essential, such as cached data
}

@end

@implementation BBFileContent
@synthesize guid, app_id, metadata, path;
- (id)initWithResponseDictionary:(NSDictionary *)student {
    if ((self = [super init])) {
        self.guid           = [student objectForKey:@"id"];
        self.app_id         = [student objectForKey:@"app_id"];
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

