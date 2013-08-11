//
//  ViewController.m
//  BrightBot Tester
//
//  Created by Zach Hendershot on 7/17/13.
//  Copyright (c) 2013 BrightBot. All rights reserved.
//

#import "ViewController.h"
#import "BrightBot.h"

@interface ViewController ()

@end

@implementation ViewController

BrightBot *api;
NSArray *our_students;

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    
    // Do we have a private_key i.e. logged in teacher?
    NSUserDefaults *standardUserDefaults = [NSUserDefaults standardUserDefaults];
    NSString *private_key = [standardUserDefaults stringForKey:@"private_key"];
    NSString *teacher_id = [standardUserDefaults stringForKey:@"teacher_id"];
    
    if (private_key == nil || teacher_id == nil) {
        api = [BrightBot alloc];
        [api authenticate:self.view success:^(NSMutableDictionary* authValues) {
            // Save the private key & teacher_id for use later
            NSUserDefaults * standardUserDefaults = [NSUserDefaults standardUserDefaults];
            [standardUserDefaults setObject:[authValues objectForKey:@"private_key"] forKey:@"private_key"];
            [standardUserDefaults setObject:[authValues objectForKey:@"teacher_id"] forKey:@"teacher_id"];
            [standardUserDefaults synchronize];
            
            
            [api initAPI:kAPIKey
                    private_key:[authValues objectForKey:@"private_key"]
                    teacher_id:[authValues objectForKey:@"teacher_id"]
                    app_id:kAppID];
            
            
        }
        error:^(NSError* error) {
            NSLog(@"error authenticating %@", error);
        }];

    } else {
        api = [[BrightBot alloc] initAPI:kAPIKey
                            private_key:private_key
                            teacher_id:teacher_id
                            app_id:kAppID];
    }
    
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)dealloc {
    [super dealloc];
}

- (IBAction)addStudent:(id)sender {
    NSString* the_student = [NSString stringWithFormat:@"{\"name\":\"%@\"}", @"Zach"];
    
    [api addStudent:the_student
    success:^(void) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Success" message:@"Student was added." delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
        [alert show];
        [alert release];
    }
    error:^(NSError* error) {
        NSLog(@"error retrieving students %@", error);
    }];
}

- (IBAction)getStudents:(id)sender {
    [api getStudents:^(NSArray* students) {
        for (BBStudent* student in students) {
            NSLog(@"Student %@:%@", student.guid, student.name);
        }
        our_students = students;
    } error:^(NSError* error) {
        NSLog(@"error retrieving students %@", error);
    }];
}

- (IBAction)login:(id)sender {
    [api authenticate:self.view success:^(NSMutableDictionary* authValues) {
        // Save the private key for use later
        NSUserDefaults * standardUserDefaults = [NSUserDefaults standardUserDefaults];
        [standardUserDefaults setObject:[authValues objectForKey:@"private_key"] forKey:@"private_key"];
        [standardUserDefaults setObject:[authValues objectForKey:@"teacher_id"] forKey:@"teacher_id"];
        [standardUserDefaults synchronize];
        
        
        [api initAPI:kAPIKey
                private_key:[authValues objectForKey:@"private_key"]
                teacher_id:[authValues objectForKey:@"teacher_id"]
                app_id:kAppID];
        

    }
    error:^(NSError* error) {
        NSLog(@"error authenticating %@", error);
    }];
}

- (IBAction)getContents:(id)sender {
    if (our_students == nil) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error" message:@"Please retrieve students first!." delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
        [alert show];
        [alert release];
    } else {
        // We're good, we have students
        BBStudent *first_student = [our_students objectAtIndex:0];
        
        [api getFileContents:first_student.guid success:^(NSArray* fileContents) {
            for (BBFileContent* fileContent in fileContents) {
                NSLog(@"File Content %@:%@", fileContent.guid, fileContent.metadata);
            }
        } error:^(NSError* error) {
            NSLog(@"error retrieving file contents %@", error);
        }];
        
    }
}

- (IBAction)addContents:(id)sender {
    if (our_students == nil) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error" message:@"Please retrieve students first!." delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
        [alert show];
        [alert release];
    } else {
        // We're good, we have students
        BBStudent *first_student = [our_students objectAtIndex:0];
        
        NSString* the_content = [NSString stringWithFormat:@"{'a':'1'}"];
        
        NSString* filePath = [[NSBundle mainBundle] pathForResource:@"example_file"
                                                             ofType:@"zip" inDirectory:@"data"];
        NSData* the_file = [[NSFileManager defaultManager] contentsAtPath:filePath];

        
        [api addFileContents:first_student.guid data:the_content file:the_file
            success:^(void) {
                UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Success" message:@"Content was added." delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
                [alert show];
                [alert release];
            }
            error:^(NSError* error) {
              NSLog(@"error adding content %@", error);
            }];
    }
}

- (IBAction)removeStudent:(id)sender {
    if (our_students == nil) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error" message:@"Please retrieve students first!." delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
        [alert show];
        [alert release];
    } else {
        // We're good, we have students
        BBStudent *first_student = [our_students objectAtIndex:0];
        
        NSString* the_student = [NSString stringWithFormat:@"{\"id\":\"%@\"}", first_student.guid];
        
        [api removeStudent:the_student
        success:^(void) {
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Success" message:@"Student was removed." delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
            [alert show];
            [alert release];
        }
          error:^(NSError* error) {
              NSLog(@"error removing student %@", error);
          }];
    }
}
@end
