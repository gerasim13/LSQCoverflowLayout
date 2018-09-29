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
@property (nonatomic, readonly) NSInteger numberOfVisibleItems;
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
@dynamic numberOfVisibleItems;

//_______________________________________________________________________________________________________________

#pragma mark - Lifecycle

- (void)initPostionOffsetInterpolator
{
    CGFloat spacing = self.minimumInteritemSpacing;
    Float32 point1  = spacing * 0.1f;
    Float32 point2  = point1  * 2.2f;
    Float32 point3  = point2  * 2.6f;
    Float32 value1  = spacing * 0.5f;
    Float32 value2  = value1  * 2.2f;
    Float32 value3  = value1  * 2.4f;
    Float32 points[7] = { -point3, -point2, -point1, 0.0f, point1, point2, point3 };
    Float32 values[7] = { -value3, -value2, -value1, 0.0f, value1, value2, value3 };
    SplineInterpolatorCreate(points, values, 7, &_positionoffsetInterpolator);
}

- (void)initRotationInterpolator
{
    Float32 point1 = CGRectGetMaxX([self.collectionView bounds]) * 0.01f;
    Float32 point2 = point1 * 1.5f;
    Float32 point3 = point2 * 1.5f;
    Float32 value1 = 180.0f / self.numberOfVisibleItems;
    Float32 value2 = value1 * 1.8f;
    Float32 value3 = value2 * 2.2f;
    Float32 points[7] = { -point3, -point2, -point1, 0.0f,  point1,  point2,  point3 };
    Float32 values[7] = {  value3,  value2,  value1, 0.0f, -value1, -value2, -value3 };
    SplineInterpolatorCreate(points, values, 7, &_rotationInterpolator);
}

- (void)initScaleInterpolator
{
    CGFloat spacing = self.minimumInteritemSpacing;
    CGFloat point1  = spacing * 0.01f;
    CGFloat point2  = spacing * 0.18f;
    CGFloat point3  = spacing * 0.24f;
    CGFloat point4  = spacing * 0.72f;
    Float32 points[9] = { -point4, -point3, -point2, -point1, 0.0f, point1, point2, point3, point4 };
    Float32 values[9] = {  0.1f,    0.14f,   0.42f,   0.99f,  1.0f, 0.99f,  0.42f,  0.14f,  0.1f   };
    SplineInterpolatorCreate(points, values, 9, &_scaleInterpolator);
}

- (void)initOpacityInterpolator
{
    CGFloat spacing = self.minimumInteritemSpacing;
    CGFloat point1  = spacing * 0.01f;
    CGFloat point2  = spacing * 0.05f;
    CGFloat point3  = spacing * 0.19f;
    CGFloat point4  = spacing * 0.24f;
    CGFloat point5  = spacing * 0.64f;
    Float32 points[11] = { -point5, -point4, -point3, -point2, -point1, 0.0f, point1, point2, point3, point4, point5 };
    Float32 values[11] = {  0.0f,    0.24f,   0.35f,   0.84f,   0.99f,  1.0f, 0.99f,  0.84f,  0.35f,  0.24f,  0.0f   };
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
        range.location = MIN(MAX(floorf(CGRectGetMinX(rect) / space) - self.numberOfVisibleItems / 2, 0), cellsCount);
        range.length   = MIN(MAX(ceilf (CGRectGetMaxX(rect) / space) + self.numberOfVisibleItems / 2, 0), cellsCount);
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
    // Call super method
    [super prepareLayout];
    // Init new interpolators
    SplineInterpolatorDestroy(_positionoffsetInterpolator);
    SplineInterpolatorDestroy(_rotationInterpolator);
    SplineInterpolatorDestroy(_scaleInterpolator);
    SplineInterpolatorDestroy(_opacityInterpolator);
    [self initPostionOffsetInterpolator];
    [self initRotationInterpolator];
    [self initScaleInterpolator];
    [self initOpacityInterpolator];
}

//_______________________________________________________________________________________________________________

#pragma mark - Properties

- (NSInteger)numberOfVisibleItems
{
    if (self.numberOfCells)
    {
        NSIndexPath                      *indexPath  = [NSIndexPath indexPathForItem:0 inSection:0];
        UICollectionViewLayoutAttributes *attributes = [self layoutAttributesForItemAtIndexPath:indexPath];
        CGFloat maxX = CGRectGetMaxX([self.collectionView bounds]);
        if (maxX)
        {
            return maxX / attributes.size.width;
        }
    }
    return kNumberOfVisibleItems;
}

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
    return 40.0f;
//    if (self.numberOfCells)
//    {
//        NSIndexPath                      *indexPath  = [NSIndexPath indexPathForItem:0 inSection:0];
//        UICollectionViewLayoutAttributes *attributes = [self layoutAttributesForItemAtIndexPath:indexPath];
//        return attributes.size.width * 0.2f;
//    }
//    return CGRectGetMaxX([self.collectionView bounds]) / (CGFloat)self.numberOfVisibleItems;
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
        CGRect  bounds  = [self.collectionView bounds];
        CGPoint offset  = [self.collectionView contentOffset];
        CGFloat center  = self.centerOffset;
        CGFloat spacing = self.minimumInteritemSpacing;
        // Delta is distance from center of the view in cellSpacing units...
        CGFloat delta    = ((index + 0.5f) * spacing + center - CGRectGetWidth(bounds) * 0.5f - offset.x) / spacing;
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
        attributes.center = CGPointMake(position + center, CGRectGetMidY(bounds));
        attributes.zIndex = (cellsCount - ABS(_currentIndex - index));
        attributes.alpha  = opacity;
        // Apply 3D transform
        CATransform3D transform = CATransform3DIdentity;
        transform.m34           = 1.0 / -850.0;
        transform = CATransform3DScale(transform, scale, scale, 1.0);
        transform = CATransform3DTranslate(transform, attributes.size.width * (delta > 0.0 ? 0.5 : -0.5), 0.0, 0.0);
        transform = CATransform3DRotate(transform, rotation * M_PI / 180.0, 0.0, 1.0, 0.0);
        transform = CATransform3DTranslate(transform, attributes.size.width * (delta > 0.0 ? -0.5 : 0.5), 0.0, 0.0);
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
