//
//  simraUITests.m
//  simraUITests
//

#import <XCTest/XCTest.h>

@interface simraUITests : XCTestCase
@property (nonatomic, strong) XCUIApplication *app;
@end

@implementation simraUITests

- (void)setUp {
    [super setUp];

    self.continueAfterFailure = NO;
    self.app = [[XCUIApplication alloc] init];
    [self.app launch];
}

- (void)tearDown {
    self.app = nil;
    [super tearDown];
}

- (void)testInitialScreenLoads {
    XCTAssertTrue(
        [self.app waitForExistenceWithTimeout:10.0],
        @"SimRa should launch successfully."
    );
    XCTAssertGreaterThan(
        self.app.windows.count,
        0,
        @"SimRa should present a window after launch."
    );
}

@end
