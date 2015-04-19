//
//  LrcShowTests.m
//  LrcShowTests
//
//  Created by Hiro on 4/19/15.
//  Copyright (c) 2015 Juzbox. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <XCTest/XCTest.h>
#import "LSLyrics.h"

@interface LrcShowTests : XCTestCase

@end

@implementation LrcShowTests

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testExample {
    // This is an example of a functional test case.
    LSLyricsElements *lines = [[LSLyricsElements alloc] initWithContent:ContentLines];
    LSLyricsElements *line1 = [[LSLyricsElements alloc] initWithContent:ContentElements];
    LSLyricsElements *line2 = [[LSLyricsElements alloc] initWithContent:ContentElements];
    [line1 addObject:[[LSLyricsElement alloc] initWithString:@"test1"]];
    [line1 addObject:[[LSLyricsElement alloc] initWithString:@"test2"]];
    [line2 addObject:[[LSLyricsElement alloc] initWithString:@"test1"]];
    [line2 addObject:[[LSLyricsElement alloc] initWithString:@"test2"]];
    [lines addObject:line1];
    [lines addObject:line2];
    NSLog(@"%@", [lines joinedElement]);
    XCTAssert(YES, @"Pass");
}

- (void)testPerformanceExample {
    // This is an example of a performance test case.
    [self measureBlock:^{
        // Put the code you want to measure the time of here.
    }];
}

@end
