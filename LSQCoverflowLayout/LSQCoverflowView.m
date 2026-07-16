//
//  LSQCoverflowView.m
//  LSQCoverflowLayout
//
//  Reusable coverflow wrapper with two-sided covers.
//

#import "LSQCoverflowView.h"

#import "LSQCoverflowCellView.h"
#import "LSQCoverflowLayout.h"

static NSString * const LSQCoverflowCellReuseIdentifier = @"LSQCoverflowCellView";
static const CGFloat LSQDefaultCoverWidth = 280.0;
static const CGFloat LSQDefaultFlippedCoverWidth = 436.0;

typedef NS_ENUM(NSInteger, LSQCoverflowViewTransitionKind)
{
    LSQCoverflowViewTransitionKindNone,
    LSQCoverflowViewTransitionKindFlip,
    LSQCoverflowViewTransitionKindClose
};

@interface LSQCoverflowView () <UICollectionViewDataSource,
                                UICollectionViewDelegate,
                                LSQCoverflowLayoutDelegate>

@property (nonatomic, strong, readwrite) UICollectionView *collectionView;
@property (nonatomic, strong, readwrite) LSQCoverflowLayout *layout;
@property (nonatomic, assign, readwrite) NSInteger currentIndex;
@property (nonatomic, assign, readwrite) NSInteger flippedIndex;
@property (nonatomic, assign, readwrite, getter=isFlipped) BOOL flipped;
@property (nonatomic, assign) NSInteger numberOfCovers;
@property (nonatomic, assign, getter=isTransitioning) BOOL transitioning;
@property (nonatomic, assign) NSUInteger transitionGeneration;
@property (nonatomic, assign) NSUInteger activeTransitionGeneration;
@property (nonatomic, assign) LSQCoverflowViewTransitionKind activeTransitionKind;
@property (nonatomic, assign) NSInteger activeTransitionIndex;
@property (nonatomic, copy) LSQCoverflowTransitionCompletion activeTransitionCompletion;
@property (nonatomic, assign, getter=isReloadingData) BOOL reloadingData;
@property (nonatomic, assign) BOOL settlingCurrentIndex;
@property (nonatomic, assign) NSInteger pendingSettledIndex;

- (NSUInteger)beginTransitionKind:(LSQCoverflowViewTransitionKind)kind
                            index:(NSInteger)index
                       completion:(LSQCoverflowTransitionCompletion)completion;
- (BOOL)isActiveTransitionGeneration:(NSUInteger)generation;
- (void)finishActiveTransitionForGeneration:(NSUInteger)generation
                                    finished:(BOOL)finished
                                        cell:(LSQCoverflowCellView *)cell;
- (void)cancelActiveTransition;

@end

@implementation LSQCoverflowView

#pragma mark - Lifecycle

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self)
    {
        [self setup];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (self)
    {
        [self setup];
    }
    return self;
}

- (void)setup
{
    _coverSize = CGSizeMake(LSQDefaultCoverWidth, LSQDefaultCoverWidth);
    _flippedCoverSize = CGSizeMake(LSQDefaultFlippedCoverWidth, LSQDefaultFlippedCoverWidth);
    _currentIndex = -1;
    _flippedIndex = -1;
    _activeTransitionIndex = -1;
    _pendingSettledIndex = -1;

    LSQCoverflowLayout *layout = [[LSQCoverflowLayout alloc] init];
    layout.itemSize = _coverSize;
    layout.snapToCells = YES;
    self.layout = layout;

    UICollectionView *collectionView = [[UICollectionView alloc] initWithFrame:self.bounds
                                                           collectionViewLayout:layout];
    collectionView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    collectionView.backgroundColor = [UIColor clearColor];
    collectionView.clipsToBounds = NO;
    collectionView.showsHorizontalScrollIndicator = NO;
    collectionView.showsVerticalScrollIndicator = NO;
    collectionView.decelerationRate = UIScrollViewDecelerationRateFast;
    collectionView.dataSource = self;
    collectionView.delegate = self;
    [collectionView registerClass:[LSQCoverflowCellView class]
       forCellWithReuseIdentifier:LSQCoverflowCellReuseIdentifier];
    [self addSubview:collectionView];
    self.collectionView = collectionView;
}

- (void)dealloc
{
    LSQCoverflowTransitionCompletion completion = self.activeTransitionCompletion;
    self.activeTransitionCompletion = nil;
    if (completion) completion(NO);
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    self.collectionView.frame = self.bounds;
}

#pragma mark - Properties

- (void)setCoverSize:(CGSize)coverSize
{
    if (coverSize.width <= 0.0 || coverSize.height <= 0.0 || CGSizeEqualToSize(_coverSize, coverSize))
    {
        return;
    }

    _coverSize = coverSize;
    self.layout.itemSize = coverSize;
    [self.layout invalidateLayout];
}

- (void)setFlippedCoverSize:(CGSize)flippedCoverSize
{
    if (flippedCoverSize.width <= 0.0 || flippedCoverSize.height <= 0.0)
    {
        return;
    }
    _flippedCoverSize = flippedCoverSize;
}

- (CGFloat)coverSpacing
{
    return self.layout.coverSpacing;
}

- (void)setCoverSpacing:(CGFloat)coverSpacing
{
    self.layout.coverSpacing = coverSpacing;
}

#pragma mark - Public API

- (void)reloadData
{
    if (self.isReloadingData)
    {
        return;
    }
    self.reloadingData = YES;
    [self cancelActiveTransition];
    ++self.transitionGeneration;
    self.transitioning = NO;
    self.flipped = NO;
    self.flippedIndex = -1;
    self.collectionView.scrollEnabled = YES;
    self.collectionView.userInteractionEnabled = YES;
    self.settlingCurrentIndex = NO;
    self.pendingSettledIndex = -1;

    for (LSQCoverflowCellView *cell in self.collectionView.visibleCells)
    {
        [cell prepareForReuse];
    }

    NSInteger count = 0;
    if ([self.dataSource respondsToSelector:@selector(numberOfCoversInCoverflowView:)])
    {
        count = [self.dataSource numberOfCoversInCoverflowView:self];
    }
    self.numberOfCovers = MAX(0, count);

    NSInteger previousIndex = self.currentIndex;
    self.currentIndex = -1;
    self.layout.currentIndex = -1;
    [self.collectionView reloadData];
    [self.layout invalidateLayout];
    [self.collectionView layoutIfNeeded];

    if (self.numberOfCovers == 0)
    {
        self.collectionView.contentOffset = CGPointZero;
        [self updateAccessibilityForFlippedState];
        self.reloadingData = NO;
        return;
    }

    NSInteger targetIndex = previousIndex < 0 ? 0 : previousIndex;
    self.reloadingData = NO;
    [self setCurrentIndex:targetIndex animated:NO];
}

- (void)setCurrentIndex:(NSInteger)index animated:(BOOL)animated
{
    if (self.numberOfCovers <= 0)
    {
        self.currentIndex = -1;
        self.layout.currentIndex = -1;
        self.collectionView.contentOffset = CGPointZero;
        return;
    }

    if (self.isReloadingData || self.isFlipped || self.isTransitioning || self.settlingCurrentIndex)
    {
        return;
    }

    NSInteger clampedIndex = MIN(MAX(0, index), self.numberOfCovers - 1);
    if (clampedIndex == self.currentIndex)
    {
        return;
    }
    self.settlingCurrentIndex = YES;
    self.pendingSettledIndex = clampedIndex;
    CGFloat targetOffsetX = self.layout.coverSpacing * clampedIndex;
    BOOL shouldAnimate = animated && fabs(self.collectionView.contentOffset.x - targetOffsetX) > 0.5;
    if (shouldAnimate) self.collectionView.userInteractionEnabled = NO;
    self.layout.currentIndex = clampedIndex;
    [self.layout snapContentOffsetToCell:clampedIndex animated:shouldAnimate];
    if (!shouldAnimate)
    {
        [self.collectionView layoutIfNeeded];
        [self finishCurrentIndexSettling];
    }
}

- (void)flipCurrentCoverAnimated:(BOOL)animated
                      completion:(LSQCoverflowTransitionCompletion)completion
{
    NSInteger index = self.currentIndex;
    if (self.isReloadingData || self.isTransitioning || self.isFlipped || self.settlingCurrentIndex ||
        index < 0 || index >= self.numberOfCovers)
    {
        if (completion) completion(NO);
        return;
    }

    LSQCoverflowCellView *initialCell = [self cellForIndex:index];
    if (!initialCell || ![self.dataSource respondsToSelector:@selector(coverflowView:backViewForCoverAtIndex:)])
    {
        if (completion) completion(NO);
        return;
    }

    // Reserve the transition before asking the host for its rear view. A host
    // may synchronously lay out or reload an ancestor while constructing that
    // view. reloadData must be able to cancel this attempt instead of letting
    // the stale cell captured above continue animating after the callback.
    self.transitioning = YES;
    NSUInteger generation = [self beginTransitionKind:LSQCoverflowViewTransitionKindFlip
                                                index:index
                                           completion:completion];
    UIView *backView = [self.dataSource coverflowView:self backViewForCoverAtIndex:index];
    if (![self isActiveTransitionGeneration:generation])
    {
        // A reentrant reload already delivered the terminal cancellation.
        return;
    }

    LSQCoverflowCellView *cell = [self cellForIndex:index];
    BOOL inputStillCurrent = [self isActiveTransitionGeneration:generation] &&
                             backView &&
                             !self.isReloadingData &&
                             self.currentIndex == index &&
                             index >= 0 &&
                             index < self.numberOfCovers &&
                             cell != nil;
    if (!inputStillCurrent)
    {
        [self finishActiveTransitionForGeneration:generation
                                         finished:NO
                                             cell:(cell ?: initialCell)];
        return;
    }

    cell.backContentView = backView;
    self.flipped = YES;
    self.flippedIndex = index;
    self.collectionView.scrollEnabled = NO;
    [self updateAccessibilityForFlippedState];

    if ([self.delegate respondsToSelector:@selector(coverflowView:willFlipCoverAtIndex:)])
    {
        [self.delegate coverflowView:self willFlipCoverAtIndex:index];
    }

    if (![self isActiveTransitionGeneration:generation])
    {
        // The delegate may have synchronously reloaded and even started a new
        // transition on the reused cell. That newer generation owns cleanup.
        return;
    }

    __weak typeof(self) weakSelf = self;
    __weak LSQCoverflowCellView *weakCell = cell;
    [cell flipToBackWithSize:self.flippedCoverSize animated:animated completion:^(BOOL finished) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        [strongSelf finishActiveTransitionForGeneration:generation finished:finished cell:weakCell];
    }];
}

- (void)closeCurrentCoverAnimated:(BOOL)animated
                       completion:(LSQCoverflowTransitionCompletion)completion
{
    NSInteger index = self.flippedIndex;
    if (self.isReloadingData || self.isTransitioning || !self.isFlipped ||
        index < 0 || index >= self.numberOfCovers)
    {
        if (completion) completion(NO);
        return;
    }

    LSQCoverflowCellView *cell = [self cellForIndex:index];
    if (!cell)
    {
        if (completion) completion(NO);
        return;
    }

    self.transitioning = YES;
    NSUInteger generation = [self beginTransitionKind:LSQCoverflowViewTransitionKindClose
                                                index:index
                                           completion:completion];
    if ([self.delegate respondsToSelector:@selector(coverflowView:willCloseCoverAtIndex:)])
    {
        [self.delegate coverflowView:self willCloseCoverAtIndex:index];
    }

    if (![self isActiveTransitionGeneration:generation])
    {
        return;
    }

    __weak typeof(self) weakSelf = self;
    __weak LSQCoverflowCellView *weakCell = cell;
    [cell flipToFrontWithSize:self.coverSize animated:animated completion:^(BOOL finished) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        [strongSelf finishActiveTransitionForGeneration:generation finished:finished cell:weakCell];
    }];
}

#pragma mark - UICollectionViewDataSource

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView
{
    return 1;
}

- (NSInteger)collectionView:(UICollectionView *)collectionView
     numberOfItemsInSection:(NSInteger)section
{
    return self.numberOfCovers;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView
                  cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    LSQCoverflowCellView *cell = [collectionView dequeueReusableCellWithReuseIdentifier:LSQCoverflowCellReuseIdentifier
                                                                           forIndexPath:indexPath];
    UIView *frontView = nil;
    if ([self.dataSource respondsToSelector:@selector(coverflowView:frontViewForCoverAtIndex:)])
    {
        frontView = [self.dataSource coverflowView:self frontViewForCoverAtIndex:indexPath.item];
    }
    cell.frontContentView = frontView;
    cell.accessibilityElementsHidden = self.isFlipped && indexPath.item != self.flippedIndex;
    return cell;
}

#pragma mark - UICollectionViewDelegate

- (void)collectionView:(UICollectionView *)collectionView
didSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
    if (self.isTransitioning || self.isFlipped || self.settlingCurrentIndex)
    {
        return;
    }

    if (indexPath.item == self.currentIndex)
    {
        [self flipCurrentCoverAnimated:YES completion:nil];
    }
    else
    {
        [self setCurrentIndex:indexPath.item animated:YES];
    }
}

#pragma mark - LSQCoverflowLayoutDelegate

- (void)coverflowLayout:(LSQCoverflowLayout *)layout didChangeCurrentIndex:(NSInteger)index
{
    if (self.isReloadingData || self.isFlipped || self.isTransitioning || self.numberOfCovers <= 0)
    {
        return;
    }

    NSInteger clampedIndex = MIN(MAX(0, index), self.numberOfCovers - 1);
    if (self.settlingCurrentIndex)
    {
        self.pendingSettledIndex = clampedIndex;
        return;
    }
    [self commitSettledCurrentIndex:clampedIndex];
}

#pragma mark - Helpers

- (NSUInteger)beginTransitionKind:(LSQCoverflowViewTransitionKind)kind
                            index:(NSInteger)index
                       completion:(LSQCoverflowTransitionCompletion)completion
{
    NSUInteger generation = ++self.transitionGeneration;
    self.activeTransitionGeneration = generation;
    self.activeTransitionKind = kind;
    self.activeTransitionIndex = index;
    self.activeTransitionCompletion = completion;
    return generation;
}

- (BOOL)isActiveTransitionGeneration:(NSUInteger)generation
{
    return self.activeTransitionKind != LSQCoverflowViewTransitionKindNone &&
           self.activeTransitionGeneration == generation;
}

- (void)finishActiveTransitionForGeneration:(NSUInteger)generation
                                    finished:(BOOL)finished
                                        cell:(LSQCoverflowCellView *)cell
{
    if (![self isActiveTransitionGeneration:generation])
    {
        return;
    }

    LSQCoverflowViewTransitionKind kind = self.activeTransitionKind;
    NSInteger index = self.activeTransitionIndex;
    LSQCoverflowTransitionCompletion completion = self.activeTransitionCompletion;
    self.activeTransitionKind = LSQCoverflowViewTransitionKindNone;
    self.activeTransitionGeneration = 0;
    self.activeTransitionIndex = -1;
    self.activeTransitionCompletion = nil;
    self.transitioning = NO;

    if (kind == LSQCoverflowViewTransitionKindFlip)
    {
        if (finished)
        {
            if ([self.delegate respondsToSelector:@selector(coverflowView:didFlipCoverAtIndex:)])
            {
                [self.delegate coverflowView:self didFlipCoverAtIndex:index];
            }
        }
        else
        {
            self.flipped = NO;
            self.flippedIndex = -1;
            self.collectionView.scrollEnabled = YES;
            cell.backContentView = nil;
            [self updateAccessibilityForFlippedState];
        }

        if ([self.delegate respondsToSelector:@selector(coverflowView:didFinishFlipAtIndex:finished:)])
        {
            [self.delegate coverflowView:self didFinishFlipAtIndex:index finished:finished];
        }
    }
    else if (kind == LSQCoverflowViewTransitionKindClose)
    {
        // A cancelled cell transition normalizes itself back to the front.
        self.flipped = NO;
        self.flippedIndex = -1;
        self.collectionView.scrollEnabled = YES;
        [self updateAccessibilityForFlippedState];

        if (finished && [self.delegate respondsToSelector:@selector(coverflowView:didCloseCoverAtIndex:)])
        {
            [self.delegate coverflowView:self didCloseCoverAtIndex:index];
        }
        if ([self.delegate respondsToSelector:@selector(coverflowView:didFinishCloseAtIndex:finished:)])
        {
            [self.delegate coverflowView:self didFinishCloseAtIndex:index finished:finished];
        }
    }

    if (completion) completion(finished);
}

- (void)cancelActiveTransition
{
    if (self.activeTransitionKind == LSQCoverflowViewTransitionKindNone)
    {
        return;
    }

    NSUInteger generation = self.activeTransitionGeneration;
    NSInteger index = self.activeTransitionIndex;
    ++self.transitionGeneration;
    [self finishActiveTransitionForGeneration:generation
                                     finished:NO
                                         cell:[self cellForIndex:index]];
}

- (void)commitSettledCurrentIndex:(NSInteger)index
{
    if (index < 0 || index >= self.numberOfCovers || index == self.currentIndex)
    {
        return;
    }
    self.currentIndex = index;
    if ([self.delegate respondsToSelector:@selector(coverflowView:didChangeCurrentIndex:)])
    {
        [self.delegate coverflowView:self didChangeCurrentIndex:index];
    }
}

- (void)finishCurrentIndexSettling
{
    if (!self.settlingCurrentIndex)
    {
        return;
    }
    NSInteger settledIndex = self.pendingSettledIndex;
    CGFloat spacing = self.layout.coverSpacing;
    if (self.numberOfCovers > 0 && spacing > 0.0)
    {
        NSInteger offsetIndex = (NSInteger)lround(self.collectionView.contentOffset.x / spacing);
        settledIndex = MIN(MAX(0, offsetIndex), self.numberOfCovers - 1);
    }
    self.settlingCurrentIndex = NO;
    self.pendingSettledIndex = -1;
    self.collectionView.userInteractionEnabled = YES;
    [self commitSettledCurrentIndex:settledIndex];
}

#pragma mark - UIScrollViewDelegate

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView
{
    if (self.isFlipped || self.isTransitioning)
    {
        return;
    }
    self.settlingCurrentIndex = YES;
    self.pendingSettledIndex = self.currentIndex;
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate
{
    if (!decelerate)
    {
        [self finishCurrentIndexSettling];
    }
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView
{
    [self finishCurrentIndexSettling];
}

- (void)scrollViewDidEndScrollingAnimation:(UIScrollView *)scrollView
{
    [self finishCurrentIndexSettling];
}

- (LSQCoverflowCellView *)cellForIndex:(NSInteger)index
{
    if (index < 0 || index >= self.numberOfCovers)
    {
        return nil;
    }

    [self.collectionView layoutIfNeeded];
    NSIndexPath *indexPath = [NSIndexPath indexPathForItem:index inSection:0];
    return (LSQCoverflowCellView *)[self.collectionView cellForItemAtIndexPath:indexPath];
}

- (void)updateAccessibilityForFlippedState
{
    for (LSQCoverflowCellView *cell in self.collectionView.visibleCells)
    {
        NSIndexPath *indexPath = [self.collectionView indexPathForCell:cell];
        cell.accessibilityElementsHidden = self.isFlipped && indexPath.item != self.flippedIndex;
    }
}

@end
