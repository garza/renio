//
//  AppDelegate.m
//  #renio
//
//  Created by Tim Burks on 11/3/13.
//  Copyright (c) 2013 Radtastical Inc Inc. All rights reserved.
//

#import "AppDelegate.h"
#import "RadTableViewController.h"
#import "RadDownloadViewController.h"
#import "Conference.h"
#import "RadStyleManager.h"
#import "RadNavigationController.h"
#import "RadRequestRouter.h"
#import "RadHTTP.h"
#import "Nu.h"

@interface AppDelegate () <RadDownloadViewControllerDelegate, UIAlertViewDelegate>
@property (nonatomic, strong) UITabBarController *tabBarController;
@property (nonatomic, strong) RadDownloadViewController *downloadViewController;
@property (nonatomic, strong) NSNumber *remoteUpdateTime;
@end

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    // install renderers
    NuInit();
    [[Nu sharedParser] parseEval:@"(macro render (path *body) `((RadRequestRouter sharedRouter) addHandler:(RadRequestHandler handlerWithPath:,path block:(quote (progn ,@*body)))))"];
    NSString *filepath = [[NSBundle mainBundle] pathForResource:@"routes" ofType:@"nu"];
    @try {
        NSString *routes =
        [NSString stringWithContentsOfFile:filepath
                                  encoding:NSUTF8StringEncoding
                                     error:NULL];
        [[Nu sharedParser] parseEval:routes];
    }
    @catch (NSException *exception) {
        NSLog(@"Fatal: exception in renderer installation %@", [exception description]);
    }
    
    [Conference sharedInstance];
    
    // build user interface
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    self.window.backgroundColor = [UIColor whiteColor];
    [[RadStyleManager sharedInstance] start];
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    self.window.backgroundColor = [UIColor whiteColor];
    self.window.tintColor = [UIColor colorWithRed:0.3 green:0.2 blue:0.1 alpha:1.0];
    self.tabBarController = [[UITabBarController alloc] init];
    self.window.rootViewController = self.tabBarController;
    [self reloadTabs];
    [self.window makeKeyAndVisible];
    return YES;
}

- (void) applicationDidBecomeActive:(UIApplication *)application
{
    // connect to online data store
    [[Conference sharedInstance] connectWithCompletionHandler:^(NSString *message) {
        
        NSNumber *localUpdateTime = [[NSUserDefaults standardUserDefaults] objectForKey:@"updateTime"];
        
        NSDictionary *updated = [[Conference sharedInstance] propertyWithName:@"updated"];
        if (updated) {
            self.remoteUpdateTime = [updated objectForKey:@"time"];
            
            if (!localUpdateTime) {
                [self attemptDownload];
                /*
                UIAlertView *alert = [[UIAlertView alloc]
                                      initWithTitle:@"Important updates are available."
                                      message:@"Download them now?"
                                      delegate:self
                                      cancelButtonTitle:@"NO"
                                      otherButtonTitles:@"YES", nil];
                [alert show];
                 */
                
            } else if ([self.remoteUpdateTime compare:localUpdateTime] == NSOrderedDescending) {
                UIAlertView *alert = [[UIAlertView alloc]
                                      initWithTitle:@"New information is available."
                                      message:@"Download it now?"
                                      delegate:self
                                      cancelButtonTitle:@"NO"
                                      otherButtonTitles:@"YES", nil];
                [alert show];
            }
        }
    } errorHandler:^(RadHTTPResult *result) {
        if (result.statusCode == 0) {
            // no network connection
        } else {
            UIAlertView *alert = [[UIAlertView alloc]
                                  initWithTitle:@"Unable to connect"
                                  message:@"We're unable to connect to the server."
                                  delegate:nil
                                  cancelButtonTitle:@"OK"
                                  otherButtonTitles:nil];
            [alert show];
        }
    }];
    
}

- (void) attemptDownload
{
    self.downloadViewController = [[RadDownloadViewController alloc] init];
    UINavigationController *downloadNavigationController =
    [[RadNavigationController alloc] initWithRootViewController:self.downloadViewController];
    [self.tabBarController presentViewController:downloadNavigationController animated:YES completion:NULL];
}

- (void) alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if (buttonIndex != 0) {
        [self attemptDownload];
    }
}

- (void) downloadDidFinishSuccessfully:(BOOL)downloadResult
{
    if (downloadResult) {
        [[NSUserDefaults standardUserDefaults] setObject:self.remoteUpdateTime forKey:@"updateTime"];
    }
    [self reloadTabs];
}

- (void) reloadTabs
{
    id home = [[RadRequestRouter sharedRouter] pageForPath:@"main"];
    NSMutableArray *pages = [NSMutableArray array];
    for (NSString *path in [home objectForKey:@"tabs"]) {
        id page = [[RadRequestRouter sharedRouter] pageForPath:path];
        if (page) {
            [pages addObject:page];
        }
    }
    
    NSMutableArray *viewControllers = [NSMutableArray array];
    for (id page in pages) {
        UINavigationController *navigationController;
        NSString *controllerClassName = [page objectForKey:@"controller"];
        NSString *storyboardName = [page objectForKey:@"storyboard"];
        if (storyboardName) {
            UIStoryboard *storyboard = [UIStoryboard storyboardWithName:storyboardName
                                                                 bundle:nil];
            navigationController = [storyboard instantiateInitialViewController];
        } else {
            RadTableViewController *viewController;
            if (controllerClassName) {
                Class ControllerClass = NSClassFromString(controllerClassName);
                if (ControllerClass && [ControllerClass isSubclassOfClass:[RadTableViewController class]]) {
                    viewController = [[ControllerClass alloc] init];
                } else {
                    viewController = [[RadTableViewController alloc] init];
                }
            } else {
                viewController = [[RadTableViewController alloc] init];
            }
            if (!viewController.contents) {
                viewController.contents = page;
            }
            navigationController =
            [[RadNavigationController alloc] initWithRootViewController:viewController];
        }
        navigationController.navigationBar.barTintColor = [UIColor colorWithRed:0.3 green:0.2 blue:0.1 alpha:1.0];
        navigationController.navigationBar.tintColor = [UIColor whiteColor];
        [viewControllers addObject:navigationController];
    }
    [self.tabBarController setViewControllers:viewControllers];
}

@end