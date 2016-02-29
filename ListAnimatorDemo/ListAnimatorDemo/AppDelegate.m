//
//  AppDelegate.m
//  TestTableView
//
//  Created by David McNerney on 12/26/15.
//  Copyright © 2015 SeatGeek. All rights reserved.
//

#import "AppDelegate.h"
#import "ListAnimatorDemo-Swift.h"
#import "CollectionViewExample.h"

@interface AppDelegate ()

@end

@implementation AppDelegate


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    // Table view tab
    UIViewController *tableViewExample = [TableViewExample new];
    UINavigationController *tableViewNavVC = [[UINavigationController alloc] initWithRootViewController:tableViewExample];

    // Collection view tab
    UIViewController *collectionViewExample = [CollectionViewExample new];
    UINavigationController *collectionViewNavVC = [[UINavigationController alloc] initWithRootViewController:collectionViewExample];

    // Collection view tab

    // Tab bar controller
    UITabBarController *tabController = [UITabBarController new];
    tabController.viewControllers = @[ tableViewNavVC, collectionViewNavVC ];

    // Hook it all up
    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.window.rootViewController = tabController;
    [self.window makeKeyAndVisible];

    // Not sure why this is necessary, without this code the 2nd tab doesn't show until user
    // visits it for the first time.
    tabController.selectedIndex = 1;
    dispatch_async(dispatch_get_main_queue(), ^{
        tabController.selectedIndex = 0;
    });

    return YES;
}

@end
