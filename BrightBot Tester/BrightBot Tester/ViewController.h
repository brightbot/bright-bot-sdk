//
//  ViewController.h
//  BrightBot Tester
//
//  Created by Zach Hendershot on 7/17/13.
//  Copyright (c) 2013 BrightBot. All rights reserved.
//
#define kAppID @"com.brightbot.test_harness"
NSString *kBBClientID = @"d3a9730bebe8b0595466fed04de5fb559fc93fa8";
NSString *kBBClientSecret = @"1f0b998fe5fcb48b5adeb359e773cdda3237ba0f";

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

@end
