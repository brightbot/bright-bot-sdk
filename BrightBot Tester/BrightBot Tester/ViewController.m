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

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.

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
 
    NSDictionary *studentData = @{
        @"name" : @"Zach",
    };
    
    [[BrightBot sharedInstance] addStudent:studentData
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
        [[BrightBot sharedInstance] authenticate:kAPIKey
         success:^() {
             // Any finalization tasks
             UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Success" message:@"Logged in!" delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
             [alert show];
             [alert release];
         }
           error:^(NSError *error) {
               NSLog(@"error authenticating %@", error);
           }];
        
    } else {
        // Is logged in
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
        
        [[BrightBot sharedInstance] removeStudent:the_student
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
        
        NSString* the_student = [NSString stringWithFormat:@"{\"id\":\"%@\", \"name\":\"NewName\"}", first_student.guid];
        
        [[BrightBot sharedInstance] modifyStudent:the_student
            success:^(void) {
              UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Success" message:@"Student was modified." delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
              [alert show];
              [alert release];
            }
            error:^(NSError* error) {
                NSLog(@"error removing student %@", error);
            }];
    }
    
}
@end
