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

@synthesize api_key = _api_key;
@synthesize private_key = _private_key;
@synthesize teacher_id = _teacher_id;
@synthesize app_id = _app_id;
@synthesize webView;

// Instance vars
void (^authFinish)(NSMutableDictionary*);

// TODO need to make sure that the API is initialized before allowing any calls

- (id)initAPI:(NSString *)api_key private_key:(NSString *)private_key teacher_id:(NSString *)teacher_id app_id:(NSString *)app_id {
    if ((self = [super init])) {
        self.api_key = api_key;
        self.private_key = private_key;
        self.teacher_id = teacher_id;
        self.app_id = app_id;
    }
    
    return self;
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
    [request setValue:@"1" forHTTPHeaderField:@"x-brightbot-version"];
    
    return request;
}

- (void)putData:(NSString*)path data:(NSString*)data success:(void(^)(NSData* thisData))success
          error:(void(^)(NSError* error))error {
    
    NSMutableURLRequest* request = [self setupRequest:path];
        
    [request setHTTPMethod:@"PUT"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-type"];
    [request setHTTPBody:[data dataUsingEncoding:NSUTF8StringEncoding]];
    
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

- (void)deleteData:(NSString*)path data:(NSString*)data success:(void(^)(NSData* thisData))success
          error:(void(^)(NSError* error))error {
    
    NSMutableURLRequest* request = [self setupRequest:path];
    
    [request setHTTPMethod:@"DELETE"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-type"];
    [request setHTTPBody:[data dataUsingEncoding:NSUTF8StringEncoding]];
    
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


-(void)postFile:(NSString*)path data:(NSString*)data file:(NSData*)this_file success:(void(^)(NSData* thisData))success
          error:(void(^)(NSError* error))error {
    
    NSMutableURLRequest* request = [self setupRequest:path];
    
    NSString *boundary = @"0Xvdfegrdf876fRD";
    
    [request setHTTPMethod:@"POST"];
    
    // Build the multi-part form submission to the API
    NSString *contentType = [NSString stringWithFormat:@"multipart/form-data; boundary=%@",boundary];
    [request addValue:contentType forHTTPHeaderField: @"Content-Type"];
    
    NSMutableData *body = [NSMutableData data];
    [body appendData:[[NSString stringWithFormat:@"--%@\r\n",boundary] dataUsingEncoding:NSUTF8StringEncoding]];
    [body appendData:[@"Content-Disposition: form-data; name=\"content\"; filename=\"content.zip\"\r\n"
                      dataUsingEncoding:NSUTF8StringEncoding]];
    [body appendData:[@"Content-Type: application/octet-stream\r\n\r\n"
                      dataUsingEncoding:NSUTF8StringEncoding]];
    [body appendData:[NSData dataWithData:this_file]];
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
    
    NSString* path = [NSString stringWithFormat:@"/students/%@", self.teacher_id];
    [self getJSON:path success:^(NSDictionary* json) {
        NSMutableArray* bbStudents = [[NSMutableArray alloc] init];
        for (NSDictionary* jsonStudent in [json objectForKey:@"data"]) {
            BBStudent* bbStudent = [[BBStudent alloc] initWithResponseDictionary:jsonStudent];
            [bbStudents addObject:bbStudent];
        }
        success(bbStudents);
    } error:error ];

}


- (void)addStudent:(NSString*)the_student success:(void (^)(void))success error:(void (^)(NSError* error))error {
    
    NSString* path = [NSString stringWithFormat:@"/students/%@", self.teacher_id];
    
    [self putData:path data:the_student success:^(NSData *data) {
        success();
    } error:error ];
    
}

- (void)removeStudent:(NSString*)the_student success:(void (^)(void))success error:(void (^)(NSError* error))error {
    
    NSString* path = [NSString stringWithFormat:@"/students/%@", self.teacher_id];
    
    [self deleteData:path data:the_student success:^(NSData *data) {
        success();
    } error:error ];
    
}

- (void)getFileContents:(NSString*)student_id success:(void (^)(NSArray* fileContents))success error:(void (^)(NSError* error))error {
    
    NSString* path = [NSString stringWithFormat:@"/content/%@/%@", self.teacher_id, student_id];
    [self getJSON:path success:^(NSDictionary* json) {
        NSMutableArray* bbFileContents = [[NSMutableArray alloc] init];
        for (NSDictionary* jsonFileContent in [json objectForKey:@"data"]) {
            BBFileContent* bbContent = [[BBFileContent alloc] initWithResponseDictionary:jsonFileContent];
            [bbFileContents addObject:bbContent];
        }
        success(bbFileContents);
    } error:error ];
    
}

- (void)addFileContents:(NSString*)student_id data:content_data file:the_file success:(void (^)(void))success error:(void (^)(NSError* error))error {
    
    // Transform the passed in content to our internal JSON format
    NSString *transformedContent = [NSString stringWithFormat:@"{\"app_id\":\"%@\", \"item_meta\":\"%@\"}", self.app_id, content_data];
    
    NSString* path = [NSString stringWithFormat:@"/content/%@/%@", self.teacher_id, student_id];
    [self postFile:path data:transformedContent file:the_file success:^(NSData *json) {
        success();
    } error:error ];
    
}

- (void)authenticate:(UIView *)theView success:(void (^)(NSMutableDictionary* authValues))success error:(void (^)(NSError* error))error {
    
    UIWebView *webview=[[UIWebView alloc]initWithFrame:CGRectMake(0, 0,  320, 460)];
    
    NSString* urlString = [[NSString alloc] initWithFormat:@"%@/api_login", kBrightBotAPIBase];

    NSURL *nsurl=[NSURL URLWithString:urlString];
    NSURLRequest *nsrequest=[NSURLRequest requestWithURL:nsurl];
    [webview setDelegate:self];
    [webview loadRequest:nsrequest];
        
    [theView addSubview:webview];
    
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
        
        NSMutableDictionary *authParams = [NSMutableDictionary dictionary];
        [authParams setObject:self.private_key forKey:@"private_key"];
        [authParams setObject:self.teacher_id forKey:@"teacher_id"];
        authFinish(authParams);
        
        // Close up shop, auth done
        [ourWebView removeFromSuperview];
        
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
    [super didReceiveMemoryWarning]; // Releases the view if it doesn't have a superview
    // Release anything that's not essential, such as cached data
}

- (void)dealloc {
    [webView release];
    [super dealloc];
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

