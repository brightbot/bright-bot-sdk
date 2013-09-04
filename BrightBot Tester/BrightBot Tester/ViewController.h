//
//  ViewController.h
//  BrightBot Tester
//
//  Created by Zach Hendershot on 7/17/13.
//  Copyright (c) 2013 BrightBot. All rights reserved.
//
#define kAppID @"com.brightbot.test_harness"
NSString *kBBClientID = @"71325ee4154e6102f8ba56e4ddc9aab51ef4e804";
NSString *kBBClientSecret = @"a1739be129859d6253a8ea38282e2843010d80ff";

#import <UIKit/UIKit.h>
#import "BrightBot.h"

@interface ViewController : UIViewController <UIAlertViewDelegate> {
    BrightBot* api;
    NSArray* our_students;
}
@property (retain, nonatomic) IBOutlet UIButton *loginButton;
- (IBAction)addStudent:(id)sender;
- (IBAction)addStudentContent:(id)sender;
- (IBAction)getStudents:(id)sender;
- (IBAction)login:(id)sender;
- (IBAction)getContents:(id)sender;
- (IBAction)addContents:(id)sender;
- (IBAction)removeStudent:(id)sender;
- (IBAction)modifyStudent:(id)sender;
- (IBAction)modifyStudentContent:(id)sender;
- (IBAction)logProgress:(id)sender;
- (IBAction)modifyContents:(id)sender;
- (IBAction)deleteContents:(id)sender;

@end
