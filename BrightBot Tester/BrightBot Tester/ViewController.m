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

NSArray *our_students;
NSArray *our_contents;

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    
    // Initially configure the BrightBot sharedInstance
    [[BrightBot sharedInstance] configure:kBBClientID
                            client_secret:kBBClientSecret];
    
    if ( [[BrightBot sharedInstance] authenticated] ) {
        [[self loginButton] setTitle:@"Log out" forState:UIControlStateNormal];
    } else {
        [[self loginButton] setTitle:@"Log in" forState:UIControlStateNormal];
    }

}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)dealloc {
    [_loginButton release];
    [super dealloc];
}

- (IBAction)addStudent:(id)sender {
 
    NSDictionary *studentData = @{
        @"name" : @"Zach",
    };
    
    [[BrightBot sharedInstance] addStudent:studentData
    success:^(id data) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Success" message:@"Student was added." delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
        [alert show];
        [alert release];
    }
    error:^(NSError* error) {
        NSLog(@"error retrieving students %@", error);
    }];
}

- (IBAction)addStudentContent:(id)sender {
    
    NSString* filePath = [[NSBundle mainBundle] pathForResource:@"example_profile_pic"
                                                         ofType:@"png" inDirectory:@"data"];
    NSData* the_profile_picture = [[NSFileManager defaultManager] contentsAtPath:filePath];

    NSDictionary *studentData = @{
        @"name" : @"Zach",
        @"profile_picture" : the_profile_picture
    };

    [[BrightBot sharedInstance] addStudent:studentData
        success:^(id data) {
           UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Success" message:@"Student was added." delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
           [alert show];
           [alert release];
        }
         error:^(NSError* error) {
             NSLog(@"error retrieving students %@", error);
         }];
}

- (IBAction)getStudents:(id)sender {
    [[BrightBot sharedInstance] getStudents:^(NSArray* students) {
        for (BBStudent* student in students) {
            NSLog(@"Student %@:%@", student.guid, student.name);
        }
        our_students = students;
    } error:^(NSError* error) {
        NSLog(@"error retrieving students %@", error);
    }];
}

- (IBAction)login:(id)sender {
    if ( ! [[BrightBot sharedInstance] authenticated] ) {
        [[BrightBot sharedInstance] authenticate:^() {
             // Any finalization tasks
             UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Success" message:@"Logged in!" delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
             [alert show];
             [alert release];
             [sender setTitle:@"Log out" forState:UIControlStateNormal];
         }
           error:^(NSError *error) {
               NSLog(@"error authenticating %@", error);
           }];
        
    } else {
        // Is logged in, so log them out
        [[BrightBot sharedInstance] signOut];
        [sender setTitle:@"Log in" forState:UIControlStateNormal];
    }
}

- (IBAction)getContents:(id)sender {
    if (our_students == nil) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error" message:@"Please retrieve students first!." delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
        [alert show];
        [alert release];
    } else {
        // We're good, we have students
        BBStudent *first_student = [our_students objectAtIndex:0];
        
        [[BrightBot sharedInstance] getFileContents:first_student.guid success:^(NSArray* fileContents) {
            for (BBFileContent* fileContent in fileContents) {
                NSLog(@"File Content %@:%@", fileContent.guid, fileContent.metadata);
            }
            our_contents = fileContents;
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

        
        [[BrightBot sharedInstance] addFileContents:first_student.guid data:the_content file:the_file
            success:^(id data) {
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
        
        NSDictionary *studentData = @{
            @"id" : first_student.guid,
        };
        
        [[BrightBot sharedInstance] removeStudent:studentData
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

- (IBAction)modifyStudent:(id)sender {
    if (our_students == nil) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error" message:@"Please retrieve students first!." delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
        [alert show];
        [alert release];
    } else {
        // We're good, we have students
        BBStudent *first_student = [our_students objectAtIndex:0];
        
        NSDictionary *studentData = @{
          @"id" : first_student.guid,
          @"name" : @"NewName"
          };
                
        [[BrightBot sharedInstance] modifyStudent:studentData
            success:^(id data) {
              UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Success" message:@"Student was modified." delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
              [alert show];
              [alert release];
            }
            error:^(NSError* error) {
                NSLog(@"error removing student %@", error);
            }];
    }
    
}

- (IBAction)modifyStudentContent:(id)sender {
    
    if (our_students == nil) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error" message:@"Please retrieve students first!." delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
        [alert show];
        [alert release];
    } else {
        // We're good, we have students
        BBStudent *first_student = [our_students objectAtIndex:0];
        
        NSString* filePath = [[NSBundle mainBundle] pathForResource:@"example_modify_profile_pic"
                                                             ofType:@"png" inDirectory:@"data"];
        NSData* the_profile_picture = [[NSFileManager defaultManager] contentsAtPath:filePath];
        
        NSDictionary *studentData = @{
                                      @"id" : first_student.guid,
                                      @"name" : @"NewName",
                                      @"profile_picture" : the_profile_picture
                                      };
        
        [[BrightBot sharedInstance] modifyStudent:studentData
                                          success:^(id data) {
                                              UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Success" message:@"Student was modified." delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
                                              [alert show];
                                              [alert release];
                                          }
                                            error:^(NSError* error) {
                                                NSLog(@"error removing student %@", error);
                                            }];
    }
}

- (IBAction)logProgress:(id)sender {
    
    if (our_students == nil) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error" message:@"Please retrieve students first!." delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
        [alert show];
        [alert release];
    } else {
        // We're good, we have students
        BBStudent *first_student = [our_students objectAtIndex:0];
        
        BBActivityProgress *progress = [[BBActivityProgress alloc] init];
        progress.activity_tag = @"math1";
        progress.progress = [NSNumber numberWithInt:50];
        progress.goal = [NSNumber numberWithInt:100];
        
        NSArray *progress_items = [NSArray arrayWithObjects:progress, nil];
        
        [[BrightBot sharedInstance] logProgress:first_student.guid
                                     time_spent:[NSNumber numberWithInt:20]
                                           data:progress_items
                                        success:^(void) {
                                          UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Success" message:@"Progress was logged." delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
                                          [alert show];
                                          [alert release];
                                        }
                                          error:^(NSError* error) {
                                            NSLog(@"error removing student %@", error);
                                        }];
    }
    
}

- (IBAction)modifyContents:(id)sender {
    if (our_contents == nil) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error" message:@"Please retrieve file contents first!." delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
        [alert show];
        [alert release];
    } else {
        BBFileContent *first_content = [our_contents objectAtIndex:0];
        
        NSString* the_content = [NSString stringWithFormat:@"{'a':'2'}"];
        
        [[BrightBot sharedInstance] modifyFileContents:first_content.guid
                                                  data:the_content
                                               success:^(id data) {
                                                   UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Success" message:@"File Content was modified." delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
                                                   [alert show];
                                                   [alert release];
                                               }
                                                 error:^(NSError* error) {
                                                     NSLog(@"error removing file content %@", error);
                                                 }];
        
        
    }
    
}

- (IBAction)deleteContents:(id)sender {
    // We're good, we have file contents
    
    if (our_contents == nil) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error" message:@"Please retrieve file contents first!." delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
        [alert show];
        [alert release];
    } else {
        BBFileContent *first_content = [our_contents objectAtIndex:0];
        
        [[BrightBot sharedInstance] removeFileContents:first_content.guid
                                          success:^(void) {
                                              UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Success" message:@"File Content was removed." delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
                                              [alert show];
                                              [alert release];
                                          }
                                            error:^(NSError* error) {
                                                NSLog(@"error removing file content %@", error);
                                            }];

        
    }

    /*
    [[BrightBot sharedInstance] removeFileContents:first_student.guid success:^() {
        NSLog(@"contents deleted");
    } error:^(NSError* error) {
        NSLog(@"error deleting file contents %@", error);
    }];
     */
    
    
}
@end
