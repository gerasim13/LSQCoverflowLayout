//
//  LSQCoverflowLayout.m
//  LSQCoverflowLayout
//
//  Created by Павел Литвиненко on 11.09.14.
//  Copyright (c) 2014 Casual Underground. All rights reserved.
//

//_______________________________________________________________________________________________________________

#import "LSQCoverflowLayout.h"
#import "SplineInterpolator.h"
#import <libkern/OSAtomic.h>

//_______________________________________________________________________________________________________________

@interface LSQCoverflowLayout ()
{
    SplineInterpolatorRef _positionoffsetInterpolator;
    SplineInterpolatorRef _rotationInterpolator;
    SplineInterpolatorRef _scaleInterpolator;
    SplineInterpolatorRef _opacityInterpolator;
    NSInteger             _currentIndex;
}

@property (nonatomic, readonly) NSInteger numberOfCells;
@property (nonatomic, readonly) CGFloat   centerOffset;

@end

//_______________________________________________________________________________________________________________

static const CGFloat kHeaderHeight         = 28.0;
static const CGFloat kFooterHeight         = 38.0;
static const UInt32  kNumberOfVisibleItems = 7;

static NSString * const kSuplementaryViewTypeHeader = @"Header Suplementary";
static NSString * const kSuplementaryViewTypeFooter = @"Footer Suplementary";

//_______________________________________________________________________________________________________________

@implementation LSQCoverflowLayout
@synthesize snapToCells  = _snapToCells;
@synthesize currentIndex = _currentIndex;

@dynamic collectionViewContentSize;
@dynamic centerOffset;
@dynamic numberOfCells;

//_______________________________________________________________________________________________________________

#pragma mark - Lifecycle

- (void)initPostionOffsetInterpolator
{
    Float32 point1 = 0.14f;
    Float32 point2 = CGRectGetWidth([self.collectionView bounds]) * 0.001f;
    Float32 point3 = point2 * 2.2f;
    Float32 point4 = point3 * 2.6f;
    Float32 value1 = self.minimumInteritemSpacing * 0.4f;
    Float32 value2 = value1 * 2.2f;
    Float32 value3 = value1 * 0.2f;
    Float32 points[9] = { -point4, -point3, -point2, -point1, 0.0, point1, point2, point3, point4 };
    Float32 values[9] = { -value3, -value2, -value1, -0.4,    0.0, 0.4,    value1, value2, value3 };
    SplineInterpolatorCreate(points, values, 9, &_positionoffsetInterpolator);
}

- (void)initRotationInterpolator
{
    Float32 point1 = CGRectGetWidth([self.collectionView bounds]) * 0.001f;
    Float32 point2 = point1 * 2.18f;
    Float32 point3 = point2 * 3.64f;
    Float32 point4 = point3 * 3.64f;
    Float32 value1 = 180.0f / kNumberOfVisibleItems;
    Float32 value2 = value1 * 1.8f;
    Float32 value3 = value2 * 1.6f;
    Float32 value4 = value3 * 1.2f;
    Float32 points[9] = { -point4, -point3, -point2, -point1, 0.0,  point1,  point2,  point3,  point4 };
    Float32 values[9] = {  value4,  value3,  value2,  value1, 0.0, -value1, -value2, -value3, -value4 };
    SplineInterpolatorCreate(points, values, 9, &_rotationInterpolator);
}

- (void)initScaleInterpolator
{
    Float32 point1 = CGRectGetWidth([self.collectionView bounds]) * 0.001f;
    Float32 point2 = point1 * 2.8f;
    Float32 point3 = point2 * 9.4f;
    Float32 point4 = point3 * 12.4f;
    Float32 points[9] = { -point4, -point3, -point2, -point1, 0.0, point1, point2, point3, point4 };
    Float32 values[9] = { 0.1, 0.74, 0.92, 0.99, 1.0, 0.99, 0.92, 0.74, 0.1 };
    SplineInterpolatorCreate(points, values, 9, &_scaleInterpolator);
}

- (void)initOpacityInterpolator
{
    float point1 = CGRectGetWidth([self.collectionView bounds]) * 0.001f;
    float point2 = point1 * 1.8f;
    float point3 = point2 * 2.12f;
    float point4 = point3 * 2.44f;
    float point5 = point4 * 4.32f;
    Float32 points[11] = { -point5, -point4, -point3, -point2, -point1, 0.0, point1, point2, point3, point4, point5 };
    Float32 values[11] = { 0.0, 0.04, 0.35, 0.84,  0.94, 1.0, 0.94, 0.84, 0.35, 0.04, 0.0 };
    SplineInterpolatorCreate(points, values, 11, &_opacityInterpolator);
}

- (instancetype)init
{
    if (self = [super init])
    {
        self.scrollDirection = UICollectionViewScrollDirectionHorizontal;
        self.currentIndex    = -1;
    }
    return self;
}

- (void)dealloc
{
    SplineInterpolatorDestroy(_positionoffsetInterpolator);
    SplineInterpolatorDestroy(_rotationInterpolator);
    SplineInterpolatorDestroy(_scaleInterpolator);
    SplineInterpolatorDestroy(_opacityInterpolator);
}

- (void)snapContentOffsetToCell:(NSInteger)index
                       animated:(BOOL)animated
{
    CGPoint point1 = [self targetContentOffsetForCellAtIndex:index];
    CGPoint point2 = [self snappedContentOffset:point1];
    [self.collectionView setContentOffset:point2 animated:animated];
}

//_______________________________________________________________________________________________________________

#pragma mark - SubclassingHooks

- (BOOL)shouldInvalidateLayoutForBoundsChange:(CGRect)newBounds
{
    return YES;
}

- (CGSize)collectionViewContentSize
{
    return CGSizeMake(self.numberOfCells * self.minimumInteritemSpacing + self.centerOffset * 2.0,
                      CGRectGetHeight([self.collectionView bounds]));
}

- (CGPoint)targetContentOffsetForProposedContentOffset:(CGPoint)proposedContentOffset
                                 withScrollingVelocity:(CGPoint)velocity
{
    CGPoint point = [super targetContentOffsetForProposedContentOffset:proposedContentOffset
                                                 withScrollingVelocity:velocity];
    return [self snappedContentOffset:point];
}

- (NSArray*)layoutAttributesForElementsInRect:(CGRect)rect
{
    NSUInteger      cellsCount = self.numberOfCells;
    NSArray        *original   = [super layoutAttributesForElementsInRect:rect];
    NSMutableArray *attribs    = [[NSMutableArray alloc] initWithArray:original copyItems:YES];
    if (cellsCount > 0)
    {
        // Calculate range
        NSRange range;
        CGFloat space  = self.minimumInteritemSpacing;
        range.location = MIN(MAX(floorf(CGRectGetMinX(rect) / space) - kNumberOfVisibleItems / 2, 0), cellsCount);
        range.length   = MIN(MAX(ceilf (CGRectGetMaxX(rect) / space) + kNumberOfVisibleItems / 2, 0), cellsCount);
        // Iterate over all attributes
        for (; range.location < range.length; ++range.location)
        {
            UICollectionViewLayoutAttributes *attributes = [self layoutAttributesForElementAtIndex:range.location];
            if (CGRectIntersectsRect(rect, attributes.frame))
            {
                [attribs addObject:attributes];
            }
        }
        // Footer and header
        NSIndexPath *indexPath = [NSIndexPath indexPathForItem:0 inSection:0];
        UICollectionViewLayoutAttributes *footer = [self layoutAttributesForSupplementaryViewOfKind:(NSString*)kSuplementaryViewTypeHeader
                                                                                        atIndexPath:indexPath];
        UICollectionViewLayoutAttributes *header = [self layoutAttributesForSupplementaryViewOfKind:(NSString*)kSuplementaryViewTypeFooter
                                                                                        atIndexPath:indexPath];
        if (footer) [attribs addObject:footer];
        if (header) [attribs addObject:header];
    }
    // Return attributes
    return [NSArray arrayWithArray:attribs];
}

- (void)prepareLayout
{
    SplineInterpolatorDestroy(_positionoffsetInterpolator);
    SplineInterpolatorDestroy(_rotationInterpolator);
    SplineInterpolatorDestroy(_scaleInterpolator);
    SplineInterpolatorDestroy(_opacityInterpolator);
    // Init new interpolators
    [self initPostionOffsetInterpolator];
    [self initRotationInterpolator];
    [self initScaleInterpolator];
    [self initOpacityInterpolator];
    // Call super method
    [super prepareLayout];
}

//_______________________________________________________________________________________________________________

#pragma mark - Properties

- (NSInteger)numberOfCells
{
    if ([self.collectionView numberOfSections] > 0)
    {
        return [self.collectionView numberOfItemsInSection:0];
    }
    return 0;
}

- (CGFloat)centerOffset
{
    return (CGRectGetWidth([self.collectionView bounds]) - self.minimumInteritemSpacing) * 0.5;
}

- (CGSize)headerReferenceSize
{
    return CGSizeMake(CGRectGetWidth([self.collectionView bounds]), kHeaderHeight);
}

- (CGSize)footerReferenceSize
{
    return CGSizeMake(CGRectGetWidth([self.collectionView bounds]), kFooterHeight);
}

- (CGFloat)minimumInteritemSpacing
{
    return CGRectGetWidth([self.collectionView bounds]) / (float)kNumberOfVisibleItems;
}

- (void)setCurrentIndex:(NSInteger)index
{
    if (_currentIndex != (_currentIndex = index) && _currentIndex >= 0)
    {
        // Notify delegate
        if ([[self.collectionView delegate] respondsToSelector:@selector(coverflowLayout:didChangeCurrentIndex:)])
        {
            id<LSQCoverflowLayoutDelegate> delegate = (id<LSQCoverflowLayoutDelegate>)[self.collectionView delegate];
            [delegate coverflowLayout:self didChangeCurrentIndex:_currentIndex];
        }
    }
}

//_______________________________________________________________________________________________________________

#pragma mark - Private Methods

- (UICollectionViewLayoutAttributes*)layoutAttributesForElementAtIndex:(NSUInteger)index
{
    NSIndexPath                      *indexPath  = [NSIndexPath indexPathForItem:index inSection:0];
    UICollectionViewLayoutAttributes *attributes = [[self layoutAttributesForItemAtIndexPath:indexPath] copy];
    // Modify attributes
    if (attributes.representedElementCategory == UICollectionElementCategoryCell)
    {
        CGPoint offset  = [self.collectionView contentOffset];
        CGFloat center  = self.centerOffset;
        CGFloat spacing = self.minimumInteritemSpacing;
        // Delta is distance from center of the view in cellSpacing units...
        CGFloat delta    = ((index + 0.5f) * spacing + center - CGRectGetWidth([self.collectionView bounds]) * 0.5f - offset.x) / spacing;
        CGFloat position = ((index + 0.5f) * spacing + SplineInterpolatorProcess(_positionoffsetInterpolator, delta));
        CGFloat rotation = SplineInterpolatorProcess(_rotationInterpolator, delta);
        CGFloat scale    = SplineInterpolatorProcess(_scaleInterpolator   , delta);
        CGFloat opacity  = SplineInterpolatorProcess(_opacityInterpolator , delta);
        // Update current index
        // Analysis disable once CompareOfFloatsByEqualityOperator
        NSUInteger cellsCount = self.numberOfCells;
        NSUInteger cellIndex  = roundf(delta) == 0.0 ? index : _currentIndex;
        NSUInteger lastIndex  = cellsCount > 0 ? cellsCount - 1 : 0;
        self.currentIndex     = cellsCount > cellIndex ? cellIndex : lastIndex;
        // Update basic attriutes
        attributes.center = CGPointMake(position + center, CGRectGetMidY([self.collectionView bounds]));
        attributes.zIndex = (cellsCount - ABS(_currentIndex - index));
        attributes.alpha  = opacity;
        // Apply 3D transform
        CATransform3D transform = CATransform3DIdentity;
        transform.m34           = 1.0 / -850.0;
        transform = CATransform3DScale(transform, scale, scale, 1.0);
        transform = CATransform3DTranslate(transform, self.itemSize.width * (delta > 0.0 ? 0.5 : -0.5), 0.0, 0.0);
        transform = CATransform3DRotate(transform, rotation * M_PI / 180.0, 0.0, 1.0, 0.0);
        transform = CATransform3DTranslate(transform, self.itemSize.width * (delta > 0.0 ? -0.5 : 0.5), 0.0, 0.0);
        attributes.transform3D = transform;
    }
    // Return attributes
    return attributes;
}

- (CGPoint)targetContentOffsetForCellAtIndex:(NSUInteger)index
{
    CGPoint point = [self.collectionView contentOffset];
    point.x       = self.minimumInteritemSpacing * index;
    return [self targetContentOffsetForProposedContentOffset:point withScrollingVelocity:CGPointMake(0.5, 0.0)];
}

- (CGPoint)snappedContentOffset:(CGPoint)offset
{
    if (_snapToCells)
    {
        CGFloat space = self.minimumInteritemSpacing;
        UInt32  count = (UInt32)self.numberOfCells;
        offset.x = roundf(offset.x / space) * space;
        offset.x = fminf (offset.x, (count - 1) * space);
    }
    return offset;
}

@end

//_______________________________________________________________________________________________________________
