//
//  LSQCoverflowCellView.m
//  LSQCoverflowLayout
//
//  Created by Павел Литвиненко on 12.09.14.
//  Copyright (c) 2014 Casual Underground. All rights reserved.
//

#import "LSQCoverflowCellView.h"

static const NSTimeInterval LSQCoverflowPreparationDuration = 0.3;
static const NSTimeInterval LSQCoverflowFlipDuration = 0.8;
static const NSTimeInterval LSQCoverflowResizeDuration = 0.3;

@interface LSQCoverflowCellTransition : NSObject
@property (nonatomic, copy) LSQCoverflowCellTransitionCompletion completion;
@property (nonatomic, assign, getter=isFinished) BOOL finished;
- (instancetype)initWithCompletion:(LSQCoverflowCellTransitionCompletion)completion;
- (void)finish:(BOOL)finished;
@end

@implementation LSQCoverflowCellTransition

- (instancetype)initWithCompletion:(LSQCoverflowCellTransitionCompletion)completion
{
    self = [super init];
    if (self)
    {
        _completion = [completion copy];
    }
    return self;
}

- (void)finish:(BOOL)finished
{
    if (self.isFinished)
    {
        return;
    }
    self.finished = YES;
    LSQCoverflowCellTransitionCompletion completion = self.completion;
    self.completion = nil;
    if (completion) completion(finished);
}

@end

@interface LSQCoverflowCellView ()

@property (nonatomic, strong, readwrite) UIView *coverContainerView;
@property (nonatomic, assign, readwrite, getter=isFlipped) BOOL flipped;
@property (nonatomic, assign, getter=isTransitioning) BOOL transitioning;
@property (nonatomic, assign) NSUInteger transitionGeneration;
@property (nonatomic, strong) LSQCoverflowCellTransition *activeTransition;
@property (nonatomic, assign) BOOL frontContentWasAccessibilityElement;
@property (nonatomic, assign) BOOL frontContentAccessibilityElementsWereHidden;
@property (nonatomic, assign) BOOL backContentWasAccessibilityElement;
@property (nonatomic, assign) BOOL backContentAccessibilityElementsWereHidden;

- (void)updateContentAccessibilityForFlippedState;
- (void)cancelTransitionPreservingFrontContent:(LSQCoverflowCellTransition *)transition
                                     generation:(NSUInteger)generation;
- (void)resetToFrontStateRemovingContent:(BOOL)removeContent;

@end

@implementation LSQCoverflowCellView

- (void)dealloc
{
    [self.activeTransition finish:NO];
}

- (void)setup
{
    self.layer.cornerRadius = 0.0;
    self.layer.speed = 1.8;
    self.isAccessibilityElement = NO;
    self.clipsToBounds = NO;
    self.contentView.clipsToBounds = NO;

    UIView *containerView = [[UIView alloc] initWithFrame:self.contentView.bounds];
    containerView.backgroundColor = [UIColor clearColor];
    containerView.clipsToBounds = NO;
    containerView.accessibilityViewIsModal = NO;
    // Preserve the historical cell speed without shortening the original Store flip timings.
    containerView.layer.speed = 1.0 / self.layer.speed;
    [self.contentView addSubview:containerView];
    self.coverContainerView = containerView;
}

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

- (void)awakeFromNib
{
    [super awakeFromNib];
    self.imageView.opaque = YES;
}

- (void)layoutSubviews
{
    [super layoutSubviews];

    if (!self.isFlipped && !self.isTransitioning)
    {
        self.coverContainerView.bounds = (CGRect){ CGPointZero, self.contentView.bounds.size };
    }
    self.coverContainerView.center = CGPointMake(CGRectGetMidX(self.contentView.bounds),
                                                 CGRectGetMidY(self.contentView.bounds));
    self.frontContentView.frame = self.coverContainerView.bounds;
    self.backContentView.frame = self.coverContainerView.bounds;
}

#pragma mark - Content

- (void)updateContentAccessibilityForFlippedState
{
    // Do not expose controls from the face that is visually hidden. During a
    // flip neither face is stable enough to receive VoiceOver focus.
    BOOL frontHidden = self.isFlipped || self.isTransitioning;
    BOOL backHidden = !self.isFlipped || self.isTransitioning;
    self.frontContentView.isAccessibilityElement = frontHidden ? NO : self.frontContentWasAccessibilityElement;
    self.frontContentView.accessibilityElementsHidden = frontHidden
        ? YES
        : self.frontContentAccessibilityElementsWereHidden;
    self.backContentView.isAccessibilityElement = backHidden ? NO : self.backContentWasAccessibilityElement;
    self.backContentView.accessibilityElementsHidden = backHidden
        ? YES
        : self.backContentAccessibilityElementsWereHidden;
    UIView *visibleFace = self.isFlipped ? self.backContentView : self.frontContentView;
    self.accessibilityElements = self.isTransitioning || !visibleFace ? @[] : @[visibleFace];
}

- (void)setFrontContentView:(UIView *)frontContentView
{
    if (_frontContentView == frontContentView)
    {
        return;
    }

    _frontContentView.isAccessibilityElement = self.frontContentWasAccessibilityElement;
    _frontContentView.accessibilityElementsHidden = self.frontContentAccessibilityElementsWereHidden;
    [_frontContentView removeFromSuperview];
    _frontContentView = frontContentView;
    if (_frontContentView)
    {
        self.frontContentWasAccessibilityElement = _frontContentView.isAccessibilityElement;
        self.frontContentAccessibilityElementsWereHidden = _frontContentView.accessibilityElementsHidden;
        _frontContentView.frame = self.coverContainerView.bounds;
        _frontContentView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        _frontContentView.hidden = self.isFlipped;
        _frontContentView.alpha = 1.0;
        [self.coverContainerView insertSubview:_frontContentView atIndex:0];
    }
    [self updateContentAccessibilityForFlippedState];
}

- (void)setBackContentView:(UIView *)backContentView
{
    if (_backContentView == backContentView)
    {
        return;
    }

    _backContentView.isAccessibilityElement = self.backContentWasAccessibilityElement;
    _backContentView.accessibilityElementsHidden = self.backContentAccessibilityElementsWereHidden;
    [_backContentView removeFromSuperview];
    _backContentView = backContentView;
    if (_backContentView)
    {
        self.backContentWasAccessibilityElement = _backContentView.isAccessibilityElement;
        self.backContentAccessibilityElementsWereHidden = _backContentView.accessibilityElementsHidden;
        _backContentView.frame = self.coverContainerView.bounds;
        _backContentView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        _backContentView.hidden = !self.isFlipped;
        _backContentView.alpha = 1.0;
        _backContentView.userInteractionEnabled = self.isFlipped;
        [self.coverContainerView addSubview:_backContentView];
    }
    [self updateContentAccessibilityForFlippedState];
}

#pragma mark - Transitions

- (CGSize)validSizeOrCurrentSize:(CGSize)size
{
    if (size.width <= 0.0 || size.height <= 0.0)
    {
        return self.contentView.bounds.size;
    }
    return size;
}

- (void)setCoverContainerSize:(CGSize)size
{
    self.coverContainerView.bounds = (CGRect){ CGPointZero, size };
    self.coverContainerView.center = CGPointMake(CGRectGetMidX(self.contentView.bounds),
                                                 CGRectGetMidY(self.contentView.bounds));
    self.frontContentView.frame = self.coverContainerView.bounds;
    self.backContentView.frame = self.coverContainerView.bounds;
}

- (void)setBackContentSubviewsAlpha:(CGFloat)alpha
{
    for (UIView *subview in self.backContentView.subviews)
    {
        subview.alpha = alpha;
    }
}

- (BOOL)isGenerationCurrent:(NSUInteger)generation
{
    return generation == self.transitionGeneration;
}

- (LSQCoverflowCellTransition *)beginTransitionWithCompletion:(LSQCoverflowCellTransitionCompletion)completion
{
    LSQCoverflowCellTransition *transition =
        [[LSQCoverflowCellTransition alloc] initWithCompletion:completion];
    self.activeTransition = transition;
    return transition;
}

- (BOOL)isTransition:(LSQCoverflowCellTransition *)transition
    currentForGeneration:(NSUInteger)generation
{
    return transition == self.activeTransition &&
           !transition.isFinished &&
           [self isGenerationCurrent:generation];
}

- (void)completeTransition:(LSQCoverflowCellTransition *)transition
                generation:(NSUInteger)generation
                  finished:(BOOL)finished
{
    if (![self isTransition:transition currentForGeneration:generation])
    {
        [transition finish:NO];
        return;
    }
    self.activeTransition = nil;
    [transition finish:finished];
}

- (void)prepareForTransitionGeneration:(NSUInteger)generation
                              animated:(BOOL)animated
                            completion:(void (^)(BOOL current))completion
{
    if (!animated)
    {
        completion([self isGenerationCurrent:generation]);
        return;
    }

    int64_t delay = (int64_t)(LSQCoverflowPreparationDuration * NSEC_PER_SEC);
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, delay), dispatch_get_main_queue(), ^{
        completion([self isGenerationCurrent:generation]);
    });
}

- (void)finishOpeningWithGeneration:(NSUInteger)generation
                          transition:(LSQCoverflowCellTransition *)transition
{
    if (![self isTransition:transition currentForGeneration:generation])
    {
        [transition finish:NO];
        return;
    }

    self.flipped = YES;
    self.transitioning = NO;
    self.frontContentView.hidden = YES;
    self.frontContentView.alpha = 1.0;
    self.backContentView.hidden = NO;
    self.backContentView.alpha = 1.0;
    self.backContentView.userInteractionEnabled = YES;
    [self updateContentAccessibilityForFlippedState];
    [self completeTransition:transition generation:generation finished:YES];
}

- (void)flipToBackWithSize:(CGSize)size
                  animated:(BOOL)animated
                completion:(LSQCoverflowCellTransitionCompletion)completion
{
    if (self.isTransitioning || self.isFlipped || !self.frontContentView || !self.backContentView)
    {
        if (completion) completion(NO);
        return;
    }

    CGSize targetSize = [self validSizeOrCurrentSize:size];
    self.transitioning = YES;
    self.backContentView.userInteractionEnabled = NO;
    [self updateContentAccessibilityForFlippedState];
    NSUInteger generation = ++self.transitionGeneration;
    LSQCoverflowCellTransition *transition = [self beginTransitionWithCompletion:completion];

    if (!animated)
    {
        self.frontContentView.hidden = YES;
        self.backContentView.hidden = NO;
        [self setBackContentSubviewsAlpha:1.0f];
        [self setCoverContainerSize:targetSize];
        [self finishOpeningWithGeneration:generation transition:transition];
        return;
    }

    __weak typeof(self) weakSelf = self;
    [self prepareForTransitionGeneration:generation animated:YES completion:^(BOOL current) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf || !current)
        {
            if (strongSelf)
            {
                [strongSelf cancelTransitionPreservingFrontContent:transition generation:generation];
            }
            else
            {
                [transition finish:NO];
            }
            return;
        }

        if (UIAccessibilityIsReduceMotionEnabled())
        {
            [strongSelf setBackContentSubviewsAlpha:1.0f];
            strongSelf.backContentView.hidden = NO;
            strongSelf.backContentView.alpha = 0.0;
            [UIView animateWithDuration:LSQCoverflowResizeDuration
                                  delay:0.0
                                options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionCurveEaseOut
                             animations:^{
                                 strongSelf.frontContentView.alpha = 0.0;
                                 strongSelf.backContentView.alpha = 1.0;
                                 [strongSelf setCoverContainerSize:targetSize];
                             }
                             completion:^(BOOL finished) {
                                 if (!finished || ![strongSelf isGenerationCurrent:generation])
                                 {
                                     [strongSelf cancelTransitionPreservingFrontContent:transition
                                                                            generation:generation];
                                     return;
                                 }
                                 [strongSelf finishOpeningWithGeneration:generation transition:transition];
                             }];
            return;
        }

        // Original FrontCoverView flips to the rear background first; rear
        // controls fade in only during the following expansion.
        [strongSelf setBackContentSubviewsAlpha:0.0f];
        [UIView transitionWithView:strongSelf.coverContainerView
                          duration:LSQCoverflowFlipDuration
                           options:UIViewAnimationOptionTransitionFlipFromLeft |
                                   UIViewAnimationOptionBeginFromCurrentState |
                                   UIViewAnimationOptionCurveEaseInOut
                        animations:^{
                            strongSelf.frontContentView.hidden = YES;
                            strongSelf.backContentView.hidden = NO;
                        }
                        completion:^(BOOL finished) {
                            if (!finished || ![strongSelf isGenerationCurrent:generation])
                            {
                                [strongSelf cancelTransitionPreservingFrontContent:transition
                                                                       generation:generation];
                                return;
                            }

                            strongSelf.flipped = YES;
                            [UIView animateWithDuration:LSQCoverflowResizeDuration
                                                  delay:0.0
                                                options:UIViewAnimationOptionBeginFromCurrentState |
                                                        UIViewAnimationOptionCurveEaseOut
                                             animations:^{
                                                 [strongSelf setCoverContainerSize:targetSize];
                                                 [strongSelf setBackContentSubviewsAlpha:1.0f];
                                             }
                                             completion:^(BOOL resizeFinished) {
                                                 if (!resizeFinished || ![strongSelf isGenerationCurrent:generation])
                                                 {
                                                     [strongSelf cancelTransitionPreservingFrontContent:transition
                                                                                            generation:generation];
                                                     return;
                                                 }
                                                 [strongSelf finishOpeningWithGeneration:generation transition:transition];
                                             }];
                        }];
    }];
}

- (void)finishClosingWithGeneration:(NSUInteger)generation
                          transition:(LSQCoverflowCellTransition *)transition
{
    if (![self isTransition:transition currentForGeneration:generation])
    {
        [transition finish:NO];
        return;
    }

    self.flipped = NO;
    self.transitioning = NO;
    self.frontContentView.hidden = NO;
    self.frontContentView.alpha = 1.0;
    self.backContentView.hidden = YES;
    self.backContentView.alpha = 1.0;
    [self updateContentAccessibilityForFlippedState];
    self.backContentView = nil;
    [self completeTransition:transition generation:generation finished:YES];
}

- (void)flipToFrontWithSize:(CGSize)size
                   animated:(BOOL)animated
                 completion:(LSQCoverflowCellTransitionCompletion)completion
{
    if (self.isTransitioning || !self.isFlipped || !self.frontContentView)
    {
        if (completion) completion(NO);
        return;
    }

    CGSize targetSize = [self validSizeOrCurrentSize:size];
    self.transitioning = YES;
    self.backContentView.userInteractionEnabled = NO;
    [self updateContentAccessibilityForFlippedState];
    NSUInteger generation = ++self.transitionGeneration;
    LSQCoverflowCellTransition *transition = [self beginTransitionWithCompletion:completion];

    if (!animated)
    {
        [self setBackContentSubviewsAlpha:0.0f];
        [self setCoverContainerSize:targetSize];
        [self finishClosingWithGeneration:generation transition:transition];
        return;
    }

    __weak typeof(self) weakSelf = self;
    if (UIAccessibilityIsReduceMotionEnabled())
    {
        [self setBackContentSubviewsAlpha:1.0f];
        self.frontContentView.hidden = NO;
        self.frontContentView.alpha = 0.0;
        [UIView animateWithDuration:LSQCoverflowResizeDuration
                              delay:0.0
                            options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionCurveEaseOut
                         animations:^{
                             weakSelf.frontContentView.alpha = 1.0;
                             weakSelf.backContentView.alpha = 0.0;
                             [weakSelf setCoverContainerSize:targetSize];
                         }
                         completion:^(BOOL finished) {
                             __strong typeof(weakSelf) strongSelf = weakSelf;
                             if (!strongSelf || !finished || ![strongSelf isGenerationCurrent:generation])
                             {
                                 if (strongSelf)
                                 {
                                     [strongSelf cancelTransitionPreservingFrontContent:transition
                                                                            generation:generation];
                                 }
                                 else
                                 {
                                     [transition finish:NO];
                                 }
                                 return;
                             }
                             [strongSelf finishClosingWithGeneration:generation transition:transition];
                         }];
        return;
    }

    [UIView animateWithDuration:LSQCoverflowResizeDuration
                          delay:0.0
                        options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionCurveEaseOut
                     animations:^{
                         [weakSelf setCoverContainerSize:targetSize];
                         [weakSelf setBackContentSubviewsAlpha:0.0f];
                     }
                     completion:^(BOOL finished) {
                         __strong typeof(weakSelf) strongSelf = weakSelf;
                         if (!strongSelf || !finished || ![strongSelf isGenerationCurrent:generation])
                         {
                             if (strongSelf)
                             {
                                 [strongSelf cancelTransitionPreservingFrontContent:transition
                                                                        generation:generation];
                             }
                             else
                             {
                                 [transition finish:NO];
                             }
                             return;
                         }

                         // The original Loopseque uses FlipFromLeft in both directions.
                         [UIView transitionWithView:strongSelf.coverContainerView
                                          duration:LSQCoverflowFlipDuration
                                           options:UIViewAnimationOptionTransitionFlipFromLeft |
                                                   UIViewAnimationOptionBeginFromCurrentState |
                                                   UIViewAnimationOptionCurveEaseInOut
                                        animations:^{
                                            strongSelf.frontContentView.hidden = NO;
                                            strongSelf.backContentView.hidden = YES;
                                        }
                                        completion:^(BOOL flipFinished) {
                                            if (!flipFinished || ![strongSelf isGenerationCurrent:generation])
                                            {
                                                [strongSelf cancelTransitionPreservingFrontContent:transition
                                                                                       generation:generation];
                                                return;
                                            }
                                            [strongSelf finishClosingWithGeneration:generation transition:transition];
                                        }];
                     }];
}

#pragma mark - Reuse and hit testing

- (void)cancelTransitionPreservingFrontContent:(LSQCoverflowCellTransition *)transition
                                     generation:(NSUInteger)generation
{
    if (![self isTransition:transition currentForGeneration:generation])
    {
        [transition finish:NO];
        return;
    }
    [self resetToFrontStateRemovingContent:NO];
}

- (void)resetToFrontStateRemovingContent:(BOOL)removeContent
{
    LSQCoverflowCellTransition *transition = self.activeTransition;
    ++self.transitionGeneration;
    self.activeTransition = nil;
    self.transitioning = NO;
    [self.layer removeAllAnimations];
    [self.coverContainerView.layer removeAllAnimations];
    [self.frontContentView.layer removeAllAnimations];
    [self.backContentView.layer removeAllAnimations];

    self.flipped = NO;
    self.frontContentView.hidden = NO;
    self.frontContentView.alpha = 1.0;
    self.backContentView.hidden = YES;
    self.backContentView.alpha = 1.0;
    [self setCoverContainerSize:self.contentView.bounds.size];
    [self updateContentAccessibilityForFlippedState];
    self.backContentView = nil;
    if (removeContent)
    {
        self.frontContentView = nil;
    }
    self.accessibilityElementsHidden = NO;
    [transition finish:NO];
}

- (void)resetToFrontState
{
    [self resetToFrontStateRemovingContent:YES];
}

- (void)prepareForReuse
{
    [super prepareForReuse];
    [self resetToFrontState];
}

- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event
{
    if ([super pointInside:point withEvent:event])
    {
        return YES;
    }
    CGPoint containerPoint = [self.coverContainerView convertPoint:point fromView:self];
    return [self.coverContainerView pointInside:containerPoint withEvent:event];
}

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event
{
    CGPoint containerPoint = [self.coverContainerView convertPoint:point fromView:self];
    if ([self.coverContainerView pointInside:containerPoint withEvent:event])
    {
        UIView *hitView = [self.coverContainerView hitTest:containerPoint withEvent:event];
        if (hitView)
        {
            return hitView;
        }
    }
    return [super hitTest:point withEvent:event];
}

@end
