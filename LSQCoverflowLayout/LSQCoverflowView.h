//
//  LSQCoverflowView.h
//  LSQCoverflowLayout
//
//  Reusable coverflow wrapper with two-sided covers.
//

#import <UIKit/UIKit.h>

@class LSQCoverflowLayout;
@class LSQCoverflowView;

typedef void (^LSQCoverflowTransitionCompletion)(BOOL finished);

@protocol LSQCoverflowViewDataSource <NSObject>

@required
- (NSInteger)numberOfCoversInCoverflowView:(LSQCoverflowView *)coverflowView;
- (UIView *)coverflowView:(LSQCoverflowView *)coverflowView
frontViewForCoverAtIndex:(NSInteger)index;
- (UIView *)coverflowView:(LSQCoverflowView *)coverflowView
 backViewForCoverAtIndex:(NSInteger)index;

@end

@protocol LSQCoverflowViewDelegate <NSObject>

@optional
- (void)coverflowView:(LSQCoverflowView *)coverflowView
didChangeCurrentIndex:(NSInteger)index;
- (void)coverflowView:(LSQCoverflowView *)coverflowView
willFlipCoverAtIndex:(NSInteger)index;
- (void)coverflowView:(LSQCoverflowView *)coverflowView
 didFlipCoverAtIndex:(NSInteger)index;
- (void)coverflowView:(LSQCoverflowView *)coverflowView
willCloseCoverAtIndex:(NSInteger)index;
- (void)coverflowView:(LSQCoverflowView *)coverflowView
didCloseCoverAtIndex:(NSInteger)index;
/// Terminal callback. Unlike didFlipCoverAtIndex:, this also fires with NO when interrupted.
- (void)coverflowView:(LSQCoverflowView *)coverflowView
 didFinishFlipAtIndex:(NSInteger)index
             finished:(BOOL)finished;
/// Terminal callback. Unlike didCloseCoverAtIndex:, this also fires with NO when interrupted.
- (void)coverflowView:(LSQCoverflowView *)coverflowView
didFinishCloseAtIndex:(NSInteger)index
             finished:(BOOL)finished;

@end

@interface LSQCoverflowView : UIView

@property (nonatomic, weak) id<LSQCoverflowViewDataSource> dataSource;
@property (nonatomic, weak) id<LSQCoverflowViewDelegate> delegate;

@property (nonatomic, strong, readonly) UICollectionView *collectionView;
@property (nonatomic, strong, readonly) LSQCoverflowLayout *layout;

@property (nonatomic, assign) CGSize coverSize;
@property (nonatomic, assign) CGSize flippedCoverSize;
/// Horizontal center-to-center distance between adjacent covers. Defaults to 40 points.
@property (nonatomic, assign) CGFloat coverSpacing;
@property (nonatomic, assign, readonly) NSInteger currentIndex;
@property (nonatomic, assign, readonly) NSInteger flippedIndex;
@property (nonatomic, assign, readonly, getter=isFlipped) BOOL flipped;

- (void)reloadData;
- (void)setCurrentIndex:(NSInteger)index animated:(BOOL)animated;

- (void)flipCurrentCoverAnimated:(BOOL)animated
                      completion:(LSQCoverflowTransitionCompletion)completion;
- (void)closeCurrentCoverAnimated:(BOOL)animated
                       completion:(LSQCoverflowTransitionCompletion)completion;

@end
