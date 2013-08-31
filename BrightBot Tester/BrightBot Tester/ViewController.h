//
//  ViewController.h
//  BrightBot Tester
//
//  Created by Zach Hendershot on 7/17/13.
//  Copyright (c) 2013 BrightBot. All rights reserved.
//
#define kAppID @"com.brightbot.test_harness"
NSString *kBBClientID = @"c928441e497c5db3e199557fc4d6c056a87eac53";
NSString *kBBClientSecret = @"ada83f3c6821adb804647d5ad77bb1dbac4d960d";

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

@end
