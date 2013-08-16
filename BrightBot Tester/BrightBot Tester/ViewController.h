//
//  ViewController.h
//  BrightBot Tester
//
//  Created by Zach Hendershot on 7/17/13.
//  Copyright (c) 2013 BrightBot. All rights reserved.
//
#define kAppID @"com.brightbot.test_harness"
#define kAPIKey @"7f83b1657ff1fc53b92dc18148a1d65dfc2d4b1fa3d677284addd200126d9069"

#import <UIKit/UIKit.h>
#import "BrightBot.h"

@interface ViewController : UIViewController <UIAlertViewDelegate> {
    BrightBot* api;
    NSArray* our_students;
}
@property (retain, nonatomic) IBOutlet UIButton *loginButton;
- (IBAction)addStudent:(id)sender;
- (IBAction)getStudents:(id)sender;
- (IBAction)login:(id)sender;
- (IBAction)getContents:(id)sender;
- (IBAction)addContents:(id)sender;
- (IBAction)removeStudent:(id)sender;
- (IBAction)modifyStudent:(id)sender;

@end
