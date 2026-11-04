//
//  LSQCoverflowLayoutTests.m
//  LSQCoverflowLayoutTests
//

#import <XCTest/XCTest.h>

#import "LSQCoverflowCellView.h"
#import "LSQCoverflowLayout.h"
#import "LSQCoverflowView.h"

@interface LSQCoverflowView (TestHooks)
- (BOOL)isTransitioning;
- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath;
- (void)coverflowLayout:(LSQCoverflowLayout *)layout didChangeCurrentIndex:(NSInteger)index;
- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView;
- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate;
- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView;
- (void)scrollViewDidEndScrollingAnimation:(UIScrollView *)scrollView;
@end

@interface LSQCoverflowTestDataSource : NSObject <LSQCoverflowViewDataSource>

@property (nonatomic, assign) NSInteger count;
@property (nonatomic, assign) NSInteger frontRequestCount;
@property (nonatomic, assign) NSInteger backRequestCount;
@property (nonatomic, assign) BOOL reloadDuringBackRequest;
@property (nonatomic, assign) BOOL backRequestReloadTriggered;
@property (nonatomic, assign) BOOL returnNilBackView;

@end

@implementation LSQCoverflowTestDataSource

- (NSInteger)numberOfCoversInCoverflowView:(LSQCoverflowView *)coverflowView
{
    return self.count;
}

- (UIView *)coverflowView:(LSQCoverflowView *)coverflowView
frontViewForCoverAtIndex:(NSInteger)index
{
    ++self.frontRequestCount;
    UIView *view = [[UIView alloc] initWithFrame:CGRectMake(0.0, 0.0, 280.0, 280.0)];
    view.accessibilityLabel = [NSString stringWithFormat:@"front-%ld", (long)index];
    return view;
}

- (UIView *)coverflowView:(LSQCoverflowView *)coverflowView
 backViewForCoverAtIndex:(NSInteger)index
{
    ++self.backRequestCount;
    if (self.reloadDuringBackRequest && !self.backRequestReloadTriggered)
    {
        self.backRequestReloadTriggered = YES;
        [coverflowView reloadData];
    }
    if (self.returnNilBackView)
    {
        return nil;
    }
    UIView *view = [[UIView alloc] initWithFrame:CGRectMake(0.0, 0.0, 436.0, 436.0)];
    view.accessibilityLabel = [NSString stringWithFormat:@"back-%ld", (long)index];
    return view;
}

@end

@interface LSQCoverflowTestDelegate : NSObject <LSQCoverflowViewDelegate>

@property (nonatomic, strong) NSMutableArray *events;
@property (nonatomic, assign) NSInteger flipTerminalCount;
@property (nonatomic, assign) NSInteger closeTerminalCount;
@property (nonatomic, assign) BOOL lastFlipFinished;
@property (nonatomic, assign) BOOL lastCloseFinished;
@property (nonatomic, copy) void (^willFlipAction)(LSQCoverflowView *coverflowView, NSInteger index);

@end


@implementation LSQCoverflowTestDelegate

- (instancetype)init
{
    self = [super init];
    if (self)
    {
        _events = [NSMutableArray array];
    }
    return self;
}

- (void)coverflowView:(LSQCoverflowView *)coverflowView didChangeCurrentIndex:(NSInteger)index
{
    [self.events addObject:[NSString stringWithFormat:@"index:%ld", (long)index]];
}

- (void)coverflowView:(LSQCoverflowView *)coverflowView willFlipCoverAtIndex:(NSInteger)index
{
    [self.events addObject:[NSString stringWithFormat:@"willFlip:%ld", (long)index]];
    if (self.willFlipAction)
    {
        self.willFlipAction(coverflowView, index);
    }
}

- (void)coverflowView:(LSQCoverflowView *)coverflowView didFlipCoverAtIndex:(NSInteger)index
{
    [self.events addObject:[NSString stringWithFormat:@"didFlip:%ld", (long)index]];
}

- (void)coverflowView:(LSQCoverflowView *)coverflowView willCloseCoverAtIndex:(NSInteger)index
{
    [self.events addObject:[NSString stringWithFormat:@"willClose:%ld", (long)index]];
}

- (void)coverflowView:(LSQCoverflowView *)coverflowView didCloseCoverAtIndex:(NSInteger)index
{
    [self.events addObject:[NSString stringWithFormat:@"didClose:%ld", (long)index]];
}

- (void)coverflowView:(LSQCoverflowView *)coverflowView
 didFinishFlipAtIndex:(NSInteger)index
             finished:(BOOL)finished
{
    ++self.flipTerminalCount;
    self.lastFlipFinished = finished;
    [self.events addObject:[NSString stringWithFormat:@"finishFlip:%ld:%@",
                            (long)index,
                            finished ? @"YES" : @"NO"]];
}

- (void)coverflowView:(LSQCoverflowView *)coverflowView
didFinishCloseAtIndex:(NSInteger)index
             finished:(BOOL)finished
{
    ++self.closeTerminalCount;
    self.lastCloseFinished = finished;
    [self.events addObject:[NSString stringWithFormat:@"finishClose:%ld:%@",
                            (long)index,
                            finished ? @"YES" : @"NO"]];
}

@end

@interface LSQCoverflowLayoutTests : XCTestCase

@property (nonatomic, strong) UIWindow *window;
@property (nonatomic, strong) LSQCoverflowTestDataSource *dataSource;
@property (nonatomic, strong) LSQCoverflowTestDelegate *delegate;

@end


@implementation LSQCoverflowLayoutTests

- (void)setUp
{
    [super setUp];
    self.window = [[UIWindow alloc] initWithFrame:CGRectMake(0.0, 0.0, 1024.0, 768.0)];
    self.dataSource = [[LSQCoverflowTestDataSource alloc] init];
    self.delegate = [[LSQCoverflowTestDelegate alloc] init];
}

- (void)tearDown
{
    self.window = nil;
    self.dataSource = nil;
    self.delegate = nil;
    [super tearDown];
}

- (LSQCoverflowView *)coverflowViewWithCount:(NSInteger)count
{
    self.dataSource.count = count;
    LSQCoverflowView *view = [[LSQCoverflowView alloc] initWithFrame:CGRectMake(0.0, 0.0, 1024.0, 600.0)];
    view.dataSource = self.dataSource;
    view.delegate = self.delegate;
    [self.window addSubview:view];
    [view reloadData];
    [view layoutIfNeeded];
    [view.collectionView layoutIfNeeded];
    return view;
}

- (void)waitForTransitionCallbacksForInterval:(NSTimeInterval)interval
{
    XCTestExpectation *expectation = [self expectationWithDescription:@"stale transition callbacks drained"];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(interval * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        [expectation fulfill];
    });
    [self waitForExpectationsWithTimeout:interval + 1.0 handler:nil];
}

#pragma mark - Cell content and state

- (void)testCellReplacesFrontAndBackContentViews
{
    LSQCoverflowCellView *cell = [[LSQCoverflowCellView alloc] initWithFrame:CGRectMake(0.0, 0.0, 280.0, 280.0)];
    UIView *firstFront = [[UIView alloc] init];
    UIView *secondFront = [[UIView alloc] init];
    UIView *firstBack = [[UIView alloc] init];
    UIView *secondBack = [[UIView alloc] init];

    cell.frontContentView = firstFront;
    cell.backContentView = firstBack;
    XCTAssertEqual(firstFront.superview, cell.coverContainerView);
    XCTAssertEqual(firstBack.superview, cell.coverContainerView);

    cell.frontContentView = secondFront;
    cell.backContentView = secondBack;
    XCTAssertNil(firstFront.superview);
    XCTAssertNil(firstBack.superview);
    XCTAssertEqual(secondFront.superview, cell.coverContainerView);
    XCTAssertEqual(secondBack.superview, cell.coverContainerView);
}

- (void)testCellNonAnimatedFlipAndReuseResetAreDeterministic
{
    LSQCoverflowCellView *cell = [[LSQCoverflowCellView alloc] initWithFrame:CGRectMake(0.0, 0.0, 280.0, 280.0)];
    UIView *front = [[UIView alloc] init];
    front.isAccessibilityElement = YES;
    UIView *back = [[UIView alloc] init];
    UIButton *backButton = [UIButton buttonWithType:UIButtonTypeSystem];
    backButton.frame = CGRectMake(390.0, 200.0, 44.0, 44.0);
    [back addSubview:backButton];
    cell.frontContentView = front;
    cell.backContentView = back;
    XCTAssertFalse(front.accessibilityElementsHidden);
    XCTAssertTrue(front.isAccessibilityElement);
    XCTAssertTrue(back.accessibilityElementsHidden);
    XCTAssertEqualObjects(cell.accessibilityElements, (@[front]));

    __block BOOL opened = NO;
    [cell flipToBackWithSize:CGSizeMake(436.0, 296.0) animated:NO completion:^(BOOL finished) {
        opened = finished;
    }];
    XCTAssertTrue(opened);
    XCTAssertTrue(cell.isFlipped);
    XCTAssertTrue(front.hidden);
    XCTAssertFalse(back.hidden);
    XCTAssertTrue(front.accessibilityElementsHidden);
    XCTAssertFalse(front.isAccessibilityElement);
    XCTAssertFalse(back.accessibilityElementsHidden);
    XCTAssertEqualObjects(cell.accessibilityElements, (@[back]));
    XCTAssertEqualWithAccuracy(CGRectGetWidth(cell.coverContainerView.bounds), 436.0, 0.001);
    XCTAssertEqualWithAccuracy(CGRectGetHeight(cell.coverContainerView.bounds), 296.0, 0.001);
    XCTAssertEqualWithAccuracy(CGRectGetWidth(back.frame), 436.0, 0.001);
    XCTAssertEqualWithAccuracy(CGRectGetHeight(back.frame), 296.0, 0.001);
    CGPoint buttonPoint = [backButton convertPoint:CGPointMake(22.0, 22.0) toView:cell];
    XCTAssertFalse(CGRectContainsPoint(cell.bounds, buttonPoint));
    XCTAssertEqual([cell hitTest:buttonPoint withEvent:nil], backButton);

    __block BOOL closed = NO;
    [cell flipToFrontWithSize:CGSizeMake(280.0, 280.0) animated:NO completion:^(BOOL finished) {
        closed = finished;
    }];
    XCTAssertTrue(closed);
    XCTAssertFalse(cell.isFlipped);
    XCTAssertFalse(front.hidden);
    XCTAssertFalse(front.accessibilityElementsHidden);
    XCTAssertTrue(front.isAccessibilityElement);
    XCTAssertEqualObjects(cell.accessibilityElements, (@[front]));
    XCTAssertNil(cell.backContentView);
    XCTAssertNil(back.superview);

    UIView *interruptedBack = [[UIView alloc] init];
    cell.backContentView = interruptedBack;
    [cell flipToBackWithSize:CGSizeMake(436.0, 296.0) animated:NO completion:nil];
    [cell prepareForReuse];
    XCTAssertFalse(cell.isFlipped);
    XCTAssertNil(cell.frontContentView);
    XCTAssertNil(cell.backContentView);
    XCTAssertNil(front.superview);
    XCTAssertNil(interruptedBack.superview);
    XCTAssertEqualWithAccuracy(CGRectGetWidth(cell.coverContainerView.bounds), 280.0, 0.001);
}

#pragma mark - Wrapper bounds and transitions

- (void)testWrapperSupportsIndependentFrontAndBackAspectRatios
{
    LSQCoverflowView *view = [self coverflowViewWithCount:1];
    CGSize frontSize = CGSizeMake(240.0, 180.0);
    CGSize backSize = CGSizeMake(436.0, 296.0);
    view.coverSize = frontSize;
    view.flippedCoverSize = backSize;
    [view reloadData];
    [view layoutIfNeeded];
    [view.collectionView layoutIfNeeded];

    NSIndexPath *indexPath = [NSIndexPath indexPathForItem:0 inSection:0];
    LSQCoverflowCellView *cell = (LSQCoverflowCellView *)[view.collectionView cellForItemAtIndexPath:indexPath];
    XCTAssertNotNil(cell);
    XCTAssertTrue(CGSizeEqualToSize(view.layout.itemSize, frontSize));
    XCTAssertTrue(CGSizeEqualToSize(cell.coverContainerView.bounds.size, frontSize));
    XCTAssertTrue(CGSizeEqualToSize(cell.frontContentView.frame.size, frontSize));

    __block BOOL opened = NO;
    [view flipCurrentCoverAnimated:NO completion:^(BOOL finished) {
        opened = finished;
    }];
    XCTAssertTrue(opened);
    XCTAssertTrue(view.isFlipped);
    XCTAssertTrue(CGSizeEqualToSize(cell.coverContainerView.bounds.size, backSize));
    XCTAssertTrue(CGSizeEqualToSize(cell.backContentView.frame.size, backSize));

    __block BOOL closed = NO;
    [view closeCurrentCoverAnimated:NO completion:^(BOOL finished) {
        closed = finished;
    }];
    XCTAssertTrue(closed);
    XCTAssertFalse(view.isFlipped);
    XCTAssertTrue(CGSizeEqualToSize(cell.coverContainerView.bounds.size, frontSize));
    XCTAssertTrue(CGSizeEqualToSize(cell.frontContentView.frame.size, frontSize));
    XCTAssertNil(cell.backContentView);
}

- (void)testConfigurableVerticalAnchorKeepsFixedViewportAndRestoresCenteredLayout
{
    self.dataSource.count = 1;
    CGSize frontSize = CGSizeMake(250.0, 240.0);
    CGSize rearSize = CGSizeMake(360.0, 290.0);
    CGFloat viewportHeight = 320.0;
    LSQCoverflowView *view = [[LSQCoverflowView alloc] initWithFrame:CGRectMake(0.0, 0.0,
                                                                              1024.0, viewportHeight)];
    view.dataSource = self.dataSource;
    view.delegate = self.delegate;
    view.coverSize = frontSize;
    view.flippedCoverSize = rearSize;
    view.coverVerticalAnchor = 0.0;
    [self.window addSubview:view];
    [view reloadData];
    [view layoutIfNeeded];
    [view.collectionView layoutIfNeeded];

    NSIndexPath *indexPath = [NSIndexPath indexPathForItem:0 inSection:0];
    LSQCoverflowCellView *cell = (LSQCoverflowCellView *)[view.collectionView cellForItemAtIndexPath:indexPath];
    XCTAssertNotNil(cell);
    XCTAssertEqualWithAccuracy(CGRectGetHeight(view.bounds), viewportHeight, 0.001);
    XCTAssertEqualWithAccuracy(view.layout.coverVerticalAnchor, 0.0, 0.001);
    XCTAssertEqualWithAccuracy(cell.center.y - CGRectGetHeight(cell.bounds) * 0.5, 0.0, 0.001);
    XCTAssertEqualWithAccuracy(CGRectGetMinY(cell.coverContainerView.frame), 0.0, 0.001);
    XCTAssertEqualWithAccuracy(CGRectGetHeight(cell.coverContainerView.frame), frontSize.height, 0.001);
    XCTAssertEqualWithAccuracy(CGRectGetWidth(cell.coverContainerView.frame), frontSize.width, 0.001);

    __block BOOL opened = NO;
    [view flipCurrentCoverAnimated:NO completion:^(BOOL finished) {
        opened = finished;
    }];
    XCTAssertTrue(opened);
    XCTAssertEqualWithAccuracy(CGRectGetHeight(view.bounds), viewportHeight, 0.001);
    XCTAssertEqualWithAccuracy(CGRectGetMinY(cell.coverContainerView.frame), 0.0, 0.001);
    XCTAssertEqualWithAccuracy(CGRectGetHeight(cell.coverContainerView.frame), rearSize.height, 0.001);
    XCTAssertEqualWithAccuracy(CGRectGetWidth(cell.coverContainerView.frame), rearSize.width, 0.001);

    UIButton *bottomButton = [UIButton buttonWithType:UIButtonTypeSystem];
    bottomButton.frame = CGRectMake(10.0, 242.0, 44.0, 44.0);
    [cell.backContentView addSubview:bottomButton];
    CGPoint bottomButtonPoint = [bottomButton convertPoint:CGPointMake(22.0, 22.0) toView:cell];
    XCTAssertFalse(CGRectContainsPoint(cell.bounds, bottomButtonPoint));
    XCTAssertEqual([cell hitTest:bottomButtonPoint withEvent:nil], bottomButton);

    __block BOOL closed = NO;
    [view closeCurrentCoverAnimated:NO completion:^(BOOL finished) {
        closed = finished;
    }];
    XCTAssertTrue(closed);
    XCTAssertEqualWithAccuracy(CGRectGetMinY(cell.coverContainerView.frame), 0.0, 0.001);
    XCTAssertEqualWithAccuracy(CGRectGetHeight(cell.coverContainerView.frame), frontSize.height, 0.001);

    view.coverVerticalAnchor = 0.5;
    [view.collectionView layoutIfNeeded];
    XCTAssertEqualWithAccuracy(cell.center.y - CGRectGetHeight(cell.bounds) * 0.5,
                               (viewportHeight - frontSize.height) * 0.5, 0.001);
    XCTAssertEqualWithAccuracy(CGRectGetMinY(cell.coverContainerView.frame), 0.0, 0.001);
}

- (void)testDecodedLayoutPreservesArchivedFlowConfigurationAndLegacyAnchorDefault
{
    LSQCoverflowLayout *layout = [[LSQCoverflowLayout alloc] init];
    layout.scrollDirection = UICollectionViewScrollDirectionVertical;
    layout.minimumInteritemSpacing = 73.0;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    NSData *archive = [NSKeyedArchiver archivedDataWithRootObject:layout];
    LSQCoverflowLayout *decoded = [NSKeyedUnarchiver unarchiveObjectWithData:archive];
#pragma clang diagnostic pop

    XCTAssertNotNil(decoded);
    XCTAssertEqual(decoded.scrollDirection, UICollectionViewScrollDirectionVertical);
    XCTAssertEqualWithAccuracy(decoded.minimumInteritemSpacing, 73.0, 0.001);
    XCTAssertEqualWithAccuracy(decoded.coverSpacing, 73.0, 0.001);
    XCTAssertEqualWithAccuracy(decoded.coverVerticalAnchor, 0.5, 0.001);
}

- (void)testCoverSpacingDefaultsToHistoricalValueAndReflowsCurrentCover
{
    LSQCoverflowView *view = [self coverflowViewWithCount:5];
    XCTAssertEqualWithAccuracy(view.coverSpacing, 40.0, 0.001);
    XCTAssertEqualWithAccuracy(view.layout.coverSpacing, 40.0, 0.001);
    XCTAssertEqualWithAccuracy(view.layout.minimumInteritemSpacing, 40.0, 0.001);

    [view setCurrentIndex:3 animated:NO];
    XCTAssertEqual(view.currentIndex, 3);
    XCTAssertEqualWithAccuracy(view.collectionView.contentOffset.x, 120.0, 0.001);

    view.coverSpacing = 64.0;
    [view.collectionView layoutIfNeeded];
    XCTAssertEqualWithAccuracy(view.coverSpacing, 64.0, 0.001);
    XCTAssertEqualWithAccuracy(view.layout.coverSpacing, 64.0, 0.001);
    XCTAssertEqualWithAccuracy(view.layout.minimumInteritemSpacing, 64.0, 0.001);
    XCTAssertEqual(view.currentIndex, 3);
    XCTAssertEqualWithAccuracy(view.collectionView.contentOffset.x, 192.0, 0.001);
    XCTAssertEqualWithAccuracy(view.layout.collectionViewContentSize.width, 1280.0, 0.001);

    // Preserve compatibility for callers that configure the inherited flow-layout property.
    view.layout.minimumInteritemSpacing = 52.0;
    [view.collectionView layoutIfNeeded];
    XCTAssertEqualWithAccuracy(view.coverSpacing, 52.0, 0.001);
    XCTAssertEqualWithAccuracy(view.collectionView.contentOffset.x, 156.0, 0.001);
}

- (void)testChangingCoverSpacingWhileFlippedPreservesFlipState
{
    LSQCoverflowView *view = [self coverflowViewWithCount:3];
    [view setCurrentIndex:1 animated:NO];
    [view flipCurrentCoverAnimated:NO completion:nil];
    XCTAssertTrue(view.isFlipped);
    XCTAssertEqual(view.flippedIndex, 1);
    XCTAssertEqual(self.dataSource.backRequestCount, 1);

    view.coverSpacing = 56.0;
    [view.collectionView layoutIfNeeded];
    XCTAssertTrue(view.isFlipped);
    XCTAssertEqual(view.flippedIndex, 1);
    XCTAssertEqual(view.currentIndex, 1);
    XCTAssertFalse(view.collectionView.scrollEnabled);
    XCTAssertEqual(self.dataSource.backRequestCount, 1);
    XCTAssertEqualWithAccuracy(view.collectionView.contentOffset.x, 56.0, 0.001);

    [view closeCurrentCoverAnimated:NO completion:nil];
    XCTAssertFalse(view.isFlipped);
    XCTAssertEqual(view.currentIndex, 1);
    XCTAssertEqualWithAccuracy(view.collectionView.contentOffset.x, 56.0, 0.001);
}

- (void)testEmptyCoverflowKeepsSentinelStateAndRejectsTransitions
{
    LSQCoverflowView *view = [self coverflowViewWithCount:0];
    XCTAssertEqual(view.currentIndex, -1);
    XCTAssertEqual(view.flippedIndex, -1);
    XCTAssertFalse(view.isFlipped);

    [view setCurrentIndex:99 animated:NO];
    XCTAssertEqual(view.currentIndex, -1);

    __block BOOL flipResult = YES;
    [view flipCurrentCoverAnimated:NO completion:^(BOOL finished) {
        flipResult = finished;
    }];
    XCTAssertFalse(flipResult);

    __block BOOL closeResult = YES;
    [view closeCurrentCoverAnimated:NO completion:^(BOOL finished) {
        closeResult = finished;
    }];
    XCTAssertFalse(closeResult);
    XCTAssertEqual(self.dataSource.backRequestCount, 0);
}

- (void)testOneCoverClampsIndicesAndEmitsOrderedFlipCloseCallbacks
{
    LSQCoverflowView *view = [self coverflowViewWithCount:1];
    XCTAssertEqual(view.currentIndex, 0);
    [view setCurrentIndex:-10 animated:NO];
    XCTAssertEqual(view.currentIndex, 0);
    [view setCurrentIndex:100 animated:NO];
    XCTAssertEqual(view.currentIndex, 0);

    [self.delegate.events removeAllObjects];
    __block BOOL opened = NO;
    [view flipCurrentCoverAnimated:NO completion:^(BOOL finished) {
        opened = finished;
    }];
    XCTAssertTrue(opened);
    XCTAssertTrue(view.isFlipped);
    XCTAssertEqual(view.flippedIndex, 0);
    XCTAssertFalse(view.collectionView.scrollEnabled);
    XCTAssertEqual(self.dataSource.backRequestCount, 1);

    __block BOOL secondOpen = YES;
    [view flipCurrentCoverAnimated:NO completion:^(BOOL finished) {
        secondOpen = finished;
    }];
    XCTAssertFalse(secondOpen);
    XCTAssertEqual(self.dataSource.backRequestCount, 1);

    __block BOOL closed = NO;
    [view closeCurrentCoverAnimated:NO completion:^(BOOL finished) {
        closed = finished;
    }];
    XCTAssertTrue(closed);
    XCTAssertFalse(view.isFlipped);
    XCTAssertEqual(view.flippedIndex, -1);
    XCTAssertTrue(view.collectionView.scrollEnabled);
    XCTAssertEqualObjects(self.delegate.events,
                          (@[ @"willFlip:0", @"didFlip:0", @"finishFlip:0:YES",
                              @"willClose:0", @"didClose:0", @"finishClose:0:YES" ]));
}

- (void)testInterruptedFlipCompletesOnceAndEmitsTerminalFailure
{
    LSQCoverflowView *view = [self coverflowViewWithCount:1];
    [self.delegate.events removeAllObjects];

    __block NSInteger completionCount = 0;
    __block BOOL completionResult = YES;
    [view flipCurrentCoverAnimated:YES completion:^(BOOL finished) {
        ++completionCount;
        completionResult = finished;
    }];
    [view reloadData];

    XCTAssertEqual(completionCount, 1);
    XCTAssertFalse(completionResult);
    XCTAssertEqual(self.delegate.flipTerminalCount, 1);
    XCTAssertFalse(self.delegate.lastFlipFinished);
    XCTAssertFalse(view.isFlipped);
    XCTAssertTrue(view.collectionView.scrollEnabled);
    XCTAssertTrue([self.delegate.events containsObject:@"finishFlip:0:NO"]);
    XCTAssertFalse([self.delegate.events containsObject:@"didFlip:0"]);

    [self waitForTransitionCallbacksForInterval:0.4];
    XCTAssertEqual(completionCount, 1);
    XCTAssertEqual(self.delegate.flipTerminalCount, 1);
}

- (void)testReloadReenteredByBackProviderCancelsFlipAndKeepsCurrentFront
{
    LSQCoverflowView *view = [self coverflowViewWithCount:3];
    self.dataSource.reloadDuringBackRequest = YES;
    [self.delegate.events removeAllObjects];

    __block NSInteger completionCount = 0;
    __block BOOL completionResult = YES;
    [view flipCurrentCoverAnimated:NO completion:^(BOOL finished) {
        ++completionCount;
        completionResult = finished;
    }];

    [view layoutIfNeeded];
    [view.collectionView layoutIfNeeded];
    LSQCoverflowCellView *currentCell = (LSQCoverflowCellView *)[view.collectionView
        cellForItemAtIndexPath:[NSIndexPath indexPathForItem:0 inSection:0]];
    XCTAssertTrue(self.dataSource.backRequestReloadTriggered);
    XCTAssertEqual(completionCount, 1);
    XCTAssertFalse(completionResult);
    XCTAssertEqual(self.delegate.flipTerminalCount, 1);
    XCTAssertFalse(self.delegate.lastFlipFinished);
    XCTAssertFalse(view.isFlipped);
    XCTAssertFalse(view.isTransitioning);
    XCTAssertEqual(view.currentIndex, 0);
    XCTAssertTrue(view.collectionView.scrollEnabled);
    XCTAssertNotNil(currentCell);
    XCTAssertNotNil(currentCell.frontContentView);
    XCTAssertFalse(currentCell.frontContentView.hidden);
    XCTAssertFalse(currentCell.isFlipped);
}

- (void)testNilBackProviderFinishesOnceWithoutStartingVisualFlip
{
    LSQCoverflowView *view = [self coverflowViewWithCount:1];
    self.dataSource.returnNilBackView = YES;
    [self.delegate.events removeAllObjects];

    __block NSInteger completionCount = 0;
    __block BOOL completionResult = YES;
    [view flipCurrentCoverAnimated:NO completion:^(BOOL finished) {
        ++completionCount;
        completionResult = finished;
    }];

    XCTAssertEqual(completionCount, 1);
    XCTAssertFalse(completionResult);
    XCTAssertEqual(self.delegate.flipTerminalCount, 1);
    XCTAssertFalse(view.isFlipped);
    XCTAssertFalse(view.isTransitioning);
    XCTAssertFalse([self.delegate.events containsObject:@"willFlip:0"]);
    XCTAssertTrue([self.delegate.events containsObject:@"finishFlip:0:NO"]);
}

- (void)testWillFlipReloadMayStartNewGenerationWithoutOldCleanupErasingItsRear
{
    LSQCoverflowView *view = [self coverflowViewWithCount:1];
    __block NSInteger oldCompletionCount = 0;
    __block BOOL oldCompletionResult = YES;
    __block NSInteger newCompletionCount = 0;
    __block BOOL newCompletionResult = NO;
    __weak LSQCoverflowTestDelegate *weakDelegate = self.delegate;
    self.delegate.willFlipAction = ^(LSQCoverflowView *reenteredView, NSInteger index) {
        weakDelegate.willFlipAction = nil;
        [reenteredView reloadData];
        [reenteredView flipCurrentCoverAnimated:NO completion:^(BOOL finished) {
            ++newCompletionCount;
            newCompletionResult = finished;
        }];
    };

    [view flipCurrentCoverAnimated:NO completion:^(BOOL finished) {
        ++oldCompletionCount;
        oldCompletionResult = finished;
    }];

    LSQCoverflowCellView *currentCell = (LSQCoverflowCellView *)[view.collectionView
        cellForItemAtIndexPath:[NSIndexPath indexPathForItem:0 inSection:0]];
    XCTAssertEqual(oldCompletionCount, 1);
    XCTAssertFalse(oldCompletionResult);
    XCTAssertEqual(newCompletionCount, 1);
    XCTAssertTrue(newCompletionResult);
    XCTAssertTrue(view.isFlipped);
    XCTAssertNotNil(currentCell.backContentView);
    XCTAssertFalse(currentCell.backContentView.hidden);
}

- (void)testInterruptedCloseCompletesOnceAndEmitsTerminalFailure
{
    LSQCoverflowView *view = [self coverflowViewWithCount:1];
    [view flipCurrentCoverAnimated:NO completion:nil];
    XCTAssertTrue(view.isFlipped);
    [self.delegate.events removeAllObjects];
    self.delegate.closeTerminalCount = 0;

    __block NSInteger completionCount = 0;
    __block BOOL completionResult = YES;
    [view closeCurrentCoverAnimated:YES completion:^(BOOL finished) {
        ++completionCount;
        completionResult = finished;
    }];
    [view reloadData];

    XCTAssertEqual(completionCount, 1);
    XCTAssertFalse(completionResult);
    XCTAssertEqual(self.delegate.closeTerminalCount, 1);
    XCTAssertFalse(self.delegate.lastCloseFinished);
    XCTAssertFalse(view.isFlipped);
    XCTAssertTrue(view.collectionView.scrollEnabled);
    XCTAssertTrue([self.delegate.events containsObject:@"finishClose:0:NO"]);
    XCTAssertFalse([self.delegate.events containsObject:@"didClose:0"]);

    [self waitForTransitionCallbacksForInterval:0.4];
    XCTAssertEqual(completionCount, 1);
    XCTAssertEqual(self.delegate.closeTerminalCount, 1);
}

- (void)testInternallyTriggeredFlipWithNilCompletionStillEmitsTerminalFailure
{
    LSQCoverflowView *view = [self coverflowViewWithCount:1];
    [self.delegate.events removeAllObjects];

    [view collectionView:view.collectionView
didSelectItemAtIndexPath:[NSIndexPath indexPathForItem:0 inSection:0]];
    [view reloadData];

    XCTAssertEqual(self.delegate.flipTerminalCount, 1);
    XCTAssertFalse(self.delegate.lastFlipFinished);
    XCTAssertTrue([self.delegate.events containsObject:@"finishFlip:0:NO"]);
    XCTAssertFalse([self.delegate.events containsObject:@"didFlip:0"]);
}

- (void)testCurrentIndexPublishesOnlyWhenScrollingSettles
{
    LSQCoverflowView *view = [self coverflowViewWithCount:5];
    XCTAssertEqual(view.currentIndex, 0);
    [self.delegate.events removeAllObjects];

    [view scrollViewWillBeginDragging:view.collectionView];
    view.collectionView.contentOffset = CGPointMake(view.layout.minimumInteritemSpacing * 3.0, 0.0);
    [view coverflowLayout:view.layout didChangeCurrentIndex:1];
    [view coverflowLayout:view.layout didChangeCurrentIndex:3];

    XCTAssertEqual(view.currentIndex, 0);
    XCTAssertEqual(self.delegate.events.count, 0);
    [view scrollViewDidEndDragging:view.collectionView willDecelerate:YES];
    XCTAssertEqual(view.currentIndex, 0);

    [view scrollViewDidEndDecelerating:view.collectionView];
    XCTAssertEqual(view.currentIndex, 3);
    XCTAssertEqualObjects(self.delegate.events, (@[ @"index:3" ]));
}

- (void)testProgrammaticAnimatedIndexPublishesAtAnimationEnd
{
    LSQCoverflowView *view = [self coverflowViewWithCount:5];
    [self.delegate.events removeAllObjects];

    [view setCurrentIndex:4 animated:YES];
    XCTAssertEqual(view.currentIndex, 0);
    XCTAssertEqual(self.delegate.events.count, 0);

    view.collectionView.contentOffset = CGPointMake(view.layout.minimumInteritemSpacing * 4.0, 0.0);
    [view coverflowLayout:view.layout didChangeCurrentIndex:4];
    XCTAssertEqual(view.currentIndex, 0);
    [view scrollViewDidEndScrollingAnimation:view.collectionView];

    XCTAssertEqual(view.currentIndex, 4);
    XCTAssertEqualObjects(self.delegate.events, (@[ @"index:4" ]));
}

- (void)testManyCoversClampCurrentIndexAndHideSideCoversFromAccessibilityWhileFlipped
{
    LSQCoverflowView *view = [self coverflowViewWithCount:5];
    [view setCurrentIndex:99 animated:NO];
    XCTAssertEqual(view.currentIndex, 4);
    [view setCurrentIndex:-99 animated:NO];
    XCTAssertEqual(view.currentIndex, 0);
    [self.delegate.events removeAllObjects];
    [view setCurrentIndex:2 animated:NO];
    XCTAssertEqual(view.currentIndex, 2);
    XCTAssertEqualObjects(self.delegate.events, (@[ @"index:2" ]));

    [self.delegate.events removeAllObjects];
    [view flipCurrentCoverAnimated:NO completion:nil];
    XCTAssertTrue(view.isFlipped);
    XCTAssertEqual(view.flippedIndex, 2);

    for (LSQCoverflowCellView *cell in view.collectionView.visibleCells)
    {
        NSIndexPath *indexPath = [view.collectionView indexPathForCell:cell];
        if (indexPath.item == view.flippedIndex)
        {
            XCTAssertFalse(cell.accessibilityElementsHidden);
        }
        else
        {
            XCTAssertTrue(cell.accessibilityElementsHidden);
        }
    }
}

@end
