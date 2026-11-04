//
//  LSQCoverflowLayout.m
//  LSQCoverflowLayout
//
//  Created by Павел Литвиненко on 11.09.14.
//  Copyright (c) 2014 Casual Underground. All rights reserved.
//

#import "LSQCoverflowLayout.h"
#import "SplineInterpolator.h"

#import <math.h>

@interface LSQCoverflowLayout ()
{
    SplineInterpolatorRef _positionoffsetInterpolator;
    SplineInterpolatorRef _rotationInterpolator;
    SplineInterpolatorRef _scaleInterpolator;
    SplineInterpolatorRef _opacityInterpolator;
    NSInteger _currentIndex;
    CGFloat _coverSpacing;
    CGFloat _coverVerticalAnchor;

    BOOL _hasCachedInterpolatorGeometry;
    CGSize _cachedBoundsSize;
    CGSize _cachedItemSize;
    CGFloat _cachedSpacing;
    NSInteger _cachedVisibleItems;
}

@property (nonatomic, readonly) NSInteger numberOfCells;
@property (nonatomic, readonly) NSInteger numberOfVisibleItems;
@property (nonatomic, readonly) CGFloat centerOffset;

- (void)applyDefaultConfiguration;

@end

static const CGFloat LSQHeaderHeight = 28.0;
static const CGFloat LSQFooterHeight = 38.0;
static const CGFloat LSQDefaultCoverSpacing = 40.0;
static const NSInteger LSQDefaultNumberOfVisibleItems = 7;
static NSString * const LSQSupplementaryViewTypeHeader = @"Header Suplementary";
static NSString * const LSQSupplementaryViewTypeFooter = @"Footer Suplementary";

@implementation LSQCoverflowLayout

@synthesize snapToCells = _snapToCells;
@synthesize currentIndex = _currentIndex;

@dynamic collectionViewContentSize;
@dynamic centerOffset;
@dynamic numberOfCells;
@dynamic numberOfVisibleItems;

#pragma mark - Lifecycle

- (instancetype)init
{
    self = [super init];
    if (self)
    {
        [self applyDefaultConfiguration];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super initWithCoder:coder];
    if (self)
    {
        _coverSpacing = [super minimumInteritemSpacing];
        _coverVerticalAnchor = 0.5f;
        _currentIndex = -1;
    }
    return self;
}

- (void)applyDefaultConfiguration
{
    self.scrollDirection = UICollectionViewScrollDirectionHorizontal;
    _coverSpacing = LSQDefaultCoverSpacing;
    _coverVerticalAnchor = 0.5f;
    [super setMinimumInteritemSpacing:_coverSpacing];
    _currentIndex = -1;
}

- (void)dealloc
{
    [self destroyInterpolators];
}

#pragma mark - Interpolators

- (void)destroyInterpolators
{
    SplineInterpolatorDestroy(_positionoffsetInterpolator);
    SplineInterpolatorDestroy(_rotationInterpolator);
    SplineInterpolatorDestroy(_scaleInterpolator);
    SplineInterpolatorDestroy(_opacityInterpolator);
    _positionoffsetInterpolator = NULL;
    _rotationInterpolator = NULL;
    _scaleInterpolator = NULL;
    _opacityInterpolator = NULL;
}

- (void)initPositionOffsetInterpolator
{
    CGFloat spacing = self.coverSpacing;
    Float32 point1 = spacing * 0.1f;
    Float32 point2 = point1 * 2.2f;
    Float32 point3 = point2 * 2.6f;
    Float32 value1 = spacing * 0.5f;
    Float32 value2 = value1 * 2.2f;
    Float32 value3 = value1 * 2.4f;
    Float32 points[7] = { -point3, -point2, -point1, 0.0f, point1, point2, point3 };
    Float32 values[7] = { -value3, -value2, -value1, 0.0f, value1, value2, value3 };
    SplineInterpolatorCreate(points, values, 7, &_positionoffsetInterpolator);
}

- (void)initRotationInterpolator
{
    // Width, not CGRectGetMaxX(bounds): bounds.origin tracks contentOffset.
    Float32 point1 = MAX(CGRectGetWidth(self.collectionView.bounds), 1.0f) * 0.01f;
    Float32 point2 = point1 * 1.5f;
    Float32 point3 = point2 * 1.5f;
    Float32 value1 = 180.0f / MAX(self.numberOfVisibleItems, 1);
    Float32 value2 = value1 * 1.8f;
    Float32 value3 = value2 * 2.2f;
    Float32 points[7] = { -point3, -point2, -point1, 0.0f, point1, point2, point3 };
    Float32 values[7] = { value3, value2, value1, 0.0f, -value1, -value2, -value3 };
    SplineInterpolatorCreate(points, values, 7, &_rotationInterpolator);
}

- (void)initScaleInterpolator
{
    CGFloat spacing = self.coverSpacing;
    Float32 point1 = spacing * 0.01f;
    Float32 point2 = spacing * 0.18f;
    Float32 point3 = spacing * 0.24f;
    Float32 point4 = spacing * 0.72f;
    Float32 points[9] = { -point4, -point3, -point2, -point1, 0.0f, point1, point2, point3, point4 };
    Float32 values[9] = { 0.1f, 0.14f, 0.42f, 0.99f, 1.0f, 0.99f, 0.42f, 0.14f, 0.1f };
    SplineInterpolatorCreate(points, values, 9, &_scaleInterpolator);
}

- (void)initOpacityInterpolator
{
    CGFloat spacing = self.coverSpacing;
    Float32 point1 = spacing * 0.01f;
    Float32 point2 = spacing * 0.05f;
    Float32 point3 = spacing * 0.19f;
    Float32 point4 = spacing * 0.24f;
    Float32 point5 = spacing * 0.64f;
    Float32 points[11] = { -point5, -point4, -point3, -point2, -point1, 0.0f,
                           point1, point2, point3, point4, point5 };
    Float32 values[11] = { 0.0f, 0.24f, 0.35f, 0.84f, 0.99f, 1.0f,
                           0.99f, 0.84f, 0.35f, 0.24f, 0.0f };
    SplineInterpolatorCreate(points, values, 11, &_opacityInterpolator);
}

- (void)rebuildInterpolatorsIfNeeded
{
    CGSize boundsSize = self.collectionView.bounds.size;
    CGSize itemSize = self.itemSize;
    CGFloat spacing = self.coverSpacing;
    NSInteger visibleItems = self.numberOfVisibleItems;
    BOOL geometryChanged = !_hasCachedInterpolatorGeometry ||
                           !CGSizeEqualToSize(boundsSize, _cachedBoundsSize) ||
                           !CGSizeEqualToSize(itemSize, _cachedItemSize) ||
                           spacing != _cachedSpacing ||
                           visibleItems != _cachedVisibleItems;
    if (!geometryChanged)
    {
        return;
    }

    [self destroyInterpolators];
    [self initPositionOffsetInterpolator];
    [self initRotationInterpolator];
    [self initScaleInterpolator];
    [self initOpacityInterpolator];

    _cachedBoundsSize = boundsSize;
    _cachedItemSize = itemSize;
    _cachedSpacing = spacing;
    _cachedVisibleItems = visibleItems;
    _hasCachedInterpolatorGeometry = YES;
}

#pragma mark - UICollectionViewLayout hooks

- (void)prepareLayout
{
    [super prepareLayout];
    [self rebuildInterpolatorsIfNeeded];

    NSInteger count = self.numberOfCells;
    if (count == 0)
    {
        self.currentIndex = -1;
        return;
    }

    CGFloat spacing = MAX(self.coverSpacing, 1.0);
    NSInteger nearestIndex = (NSInteger)llround(self.collectionView.contentOffset.x / spacing);
    self.currentIndex = MIN(MAX(0, nearestIndex), count - 1);
}

- (BOOL)shouldInvalidateLayoutForBoundsChange:(CGRect)newBounds
{
    return YES;
}

- (CGSize)collectionViewContentSize
{
    CGFloat width = CGRectGetWidth(self.collectionView.bounds);
    CGFloat height = CGRectGetHeight(self.collectionView.bounds);
    NSInteger count = self.numberOfCells;
    if (count <= 0)
    {
        return CGSizeMake(width, height);
    }

    return CGSizeMake(width + (count - 1) * self.coverSpacing, height);
}

- (CGPoint)targetContentOffsetForProposedContentOffset:(CGPoint)proposedContentOffset
                                 withScrollingVelocity:(CGPoint)velocity
{
    CGPoint point = [super targetContentOffsetForProposedContentOffset:proposedContentOffset
                                                 withScrollingVelocity:velocity];
    return [self snappedContentOffset:point];
}

- (NSArray *)layoutAttributesForElementsInRect:(CGRect)rect
{
    [self rebuildInterpolatorsIfNeeded];

    NSArray *originalAttributes = [super layoutAttributesForElementsInRect:rect];
    NSMutableArray *attributes = [NSMutableArray array];
    NSMutableSet *includedCellIndexPaths = [NSMutableSet set];

    for (UICollectionViewLayoutAttributes *original in originalAttributes)
    {
        if (original.representedElementCategory == UICollectionElementCategoryCell &&
            original.indexPath.section == 0)
        {
            if ([includedCellIndexPaths containsObject:original.indexPath])
            {
                continue;
            }
            UICollectionViewLayoutAttributes *transformed = [self layoutAttributesForElementAtIndex:original.indexPath.item];
            if (transformed)
            {
                [attributes addObject:transformed];
                [includedCellIndexPaths addObject:transformed.indexPath];
            }
        }
        else
        {
            [attributes addObject:[original copy]];
        }
    }

    NSInteger count = self.numberOfCells;
    if (count > 0)
    {
        CGFloat spacing = MAX(self.coverSpacing, 1.0);
        NSInteger padding = MAX(1, self.numberOfVisibleItems / 2);
        NSInteger firstIndex = MAX(0, (NSInteger)floor(CGRectGetMinX(rect) / spacing) - padding);
        NSInteger endIndex = MIN(count, (NSInteger)ceil(CGRectGetMaxX(rect) / spacing) + padding);
        for (NSInteger index = firstIndex; index < endIndex; ++index)
        {
            NSIndexPath *indexPath = [NSIndexPath indexPathForItem:index inSection:0];
            if ([includedCellIndexPaths containsObject:indexPath])
            {
                continue;
            }

            UICollectionViewLayoutAttributes *transformed = [self layoutAttributesForElementAtIndex:index];
            if (transformed && CGRectIntersectsRect(rect, transformed.frame))
            {
                [attributes addObject:transformed];
                [includedCellIndexPaths addObject:indexPath];
            }
        }

        // Preserve the historical custom supplementary hooks for existing hosts.
        NSIndexPath *indexPath = [NSIndexPath indexPathForItem:0 inSection:0];
        UICollectionViewLayoutAttributes *footer =
            [self layoutAttributesForSupplementaryViewOfKind:LSQSupplementaryViewTypeHeader
                                                 atIndexPath:indexPath];
        UICollectionViewLayoutAttributes *header =
            [self layoutAttributesForSupplementaryViewOfKind:LSQSupplementaryViewTypeFooter
                                                 atIndexPath:indexPath];
        if (footer) [attributes addObject:footer];
        if (header) [attributes addObject:header];
    }

    return attributes;
}

#pragma mark - Properties

- (NSInteger)numberOfVisibleItems
{
    CGFloat width = CGRectGetWidth(self.collectionView.bounds);
    CGFloat itemWidth = self.itemSize.width;
    if (width > 0.0 && itemWidth > 0.0)
    {
        return MAX(1, (NSInteger)(width / itemWidth));
    }
    return LSQDefaultNumberOfVisibleItems;
}

- (NSInteger)numberOfCells
{
    if (self.collectionView.numberOfSections > 0)
    {
        return [self.collectionView numberOfItemsInSection:0];
    }
    return 0;
}

- (CGFloat)centerOffset
{
    return MAX(0.0, (CGRectGetWidth(self.collectionView.bounds) - self.coverSpacing) * 0.5);
}

- (CGSize)headerReferenceSize
{
    return CGSizeMake(CGRectGetWidth(self.collectionView.bounds), LSQHeaderHeight);
}

- (CGSize)footerReferenceSize
{
    return CGSizeMake(CGRectGetWidth(self.collectionView.bounds), LSQFooterHeight);
}

- (CGFloat)coverSpacing
{
    return _coverSpacing;
}

- (void)setCoverSpacing:(CGFloat)coverSpacing
{
    if (!isfinite(coverSpacing) || coverSpacing <= 0.0 || _coverSpacing == coverSpacing)
    {
        return;
    }

    UICollectionView *collectionView = self.collectionView;
    CGFloat logicalOffset = 0.0;
    if (collectionView && _coverSpacing > 0.0)
    {
        logicalOffset = collectionView.contentOffset.x / _coverSpacing;
    }

    _coverSpacing = coverSpacing;
    [super setMinimumInteritemSpacing:coverSpacing];
    _hasCachedInterpolatorGeometry = NO;

    if (collectionView)
    {
        CGPoint contentOffset = collectionView.contentOffset;
        CGFloat maximumOffset = MAX(0.0, (self.numberOfCells - 1) * coverSpacing);
        contentOffset.x = MIN(MAX(0.0, logicalOffset * coverSpacing), maximumOffset);
        collectionView.contentOffset = contentOffset;
    }

    [self invalidateLayout];
}

- (void)setCoverVerticalAnchor:(CGFloat)coverVerticalAnchor
{
    if (!isfinite(coverVerticalAnchor))
    {
        return;
    }
    CGFloat clampedAnchor = MIN(1.0f, MAX(0.0f, coverVerticalAnchor));
    if (_coverVerticalAnchor == clampedAnchor)
    {
        return;
    }
    _coverVerticalAnchor = clampedAnchor;
    [self invalidateLayout];
}

// Keep UICollectionViewFlowLayout's inherited spacing API compatible with the
// semantic cover-spacing property.
- (CGFloat)minimumInteritemSpacing
{
    return self.coverSpacing;
}

- (void)setMinimumInteritemSpacing:(CGFloat)minimumInteritemSpacing
{
    self.coverSpacing = minimumInteritemSpacing;
}

- (void)setCurrentIndex:(NSInteger)index
{
    NSInteger count = self.numberOfCells;
    NSInteger adjustedIndex = index;
    if (count <= 0 || index < 0)
    {
        adjustedIndex = -1;
    }
    else
    {
        adjustedIndex = MIN(index, count - 1);
    }

    if (_currentIndex == adjustedIndex)
    {
        return;
    }
    _currentIndex = adjustedIndex;

    if (_currentIndex >= 0 &&
        [self.collectionView.delegate respondsToSelector:@selector(coverflowLayout:didChangeCurrentIndex:)])
    {
        id<LSQCoverflowLayoutDelegate> delegate = (id<LSQCoverflowLayoutDelegate>)self.collectionView.delegate;
        [delegate coverflowLayout:self didChangeCurrentIndex:_currentIndex];
    }
}

#pragma mark - Snapping

- (void)snapContentOffsetToCell:(NSInteger)index animated:(BOOL)animated
{
    NSInteger count = self.numberOfCells;
    if (count <= 0)
    {
        self.collectionView.contentOffset = CGPointZero;
        self.currentIndex = -1;
        return;
    }

    NSInteger clampedIndex = MIN(MAX(0, index), count - 1);
    CGPoint target = [self targetContentOffsetForCellAtIndex:clampedIndex];
    [self.collectionView setContentOffset:[self snappedContentOffset:target] animated:animated];
}

- (UICollectionViewLayoutAttributes *)layoutAttributesForElementAtIndex:(NSInteger)index
{
    if (index < 0 || index >= self.numberOfCells ||
        !_positionoffsetInterpolator || !_rotationInterpolator ||
        !_scaleInterpolator || !_opacityInterpolator)
    {
        return nil;
    }

    NSIndexPath *indexPath = [NSIndexPath indexPathForItem:index inSection:0];
    UICollectionViewLayoutAttributes *attributes = [[super layoutAttributesForItemAtIndexPath:indexPath] copy];
    if (!attributes || attributes.representedElementCategory != UICollectionElementCategoryCell)
    {
        return attributes;
    }

    CGRect bounds = self.collectionView.bounds;
    CGPoint offset = self.collectionView.contentOffset;
    CGFloat center = self.centerOffset;
    CGFloat spacing = MAX(self.coverSpacing, 1.0);
    CGFloat delta = ((index + 0.5f) * spacing + center - CGRectGetWidth(bounds) * 0.5f - offset.x) / spacing;
    CGFloat position = (index + 0.5f) * spacing + SplineInterpolatorProcess(_positionoffsetInterpolator, delta);
    CGFloat rotation = SplineInterpolatorProcess(_rotationInterpolator, delta);
    CGFloat scale = SplineInterpolatorProcess(_scaleInterpolator, delta);
    CGFloat opacity = SplineInterpolatorProcess(_opacityInterpolator, delta);

    CGFloat itemHeight = attributes.size.height;
    CGFloat viewportAnchorY = CGRectGetMinY(bounds) + self.coverVerticalAnchor * CGRectGetHeight(bounds);
    CGFloat itemCenterY = viewportAnchorY + (0.5f - self.coverVerticalAnchor) * itemHeight;
    attributes.center = CGPointMake(position + center, itemCenterY);
    attributes.zIndex = MAX(0, self.numberOfCells - labs(self.currentIndex - index));
    attributes.alpha = opacity;

    CATransform3D transform = CATransform3DIdentity;
    transform.m34 = 1.0 / -850.0;
    transform = CATransform3DScale(transform, scale, scale, 1.0);
    transform = CATransform3DTranslate(transform,
                                       attributes.size.width * (delta > 0.0 ? 0.5 : -0.5),
                                       0.0,
                                       0.0);
    transform = CATransform3DRotate(transform, rotation * M_PI / 180.0, 0.0, 1.0, 0.0);
    transform = CATransform3DTranslate(transform,
                                       attributes.size.width * (delta > 0.0 ? -0.5 : 0.5),
                                       0.0,
                                       0.0);
    attributes.transform3D = transform;
    return attributes;
}

- (CGPoint)targetContentOffsetForCellAtIndex:(NSInteger)index
{
    CGPoint point = self.collectionView.contentOffset;
    point.x = self.coverSpacing * index;
    return [self targetContentOffsetForProposedContentOffset:point
                                      withScrollingVelocity:CGPointMake(0.5, 0.0)];
}

- (CGPoint)snappedContentOffset:(CGPoint)offset
{
    if (!self.snapToCells)
    {
        return offset;
    }

    NSInteger count = self.numberOfCells;
    CGFloat spacing = self.coverSpacing;
    if (count <= 0 || spacing <= 0.0)
    {
        offset.x = 0.0;
        return offset;
    }

    CGFloat maximumOffset = (count - 1) * spacing;
    offset.x = round(offset.x / spacing) * spacing;
    offset.x = MIN(MAX(0.0, offset.x), maximumOffset);
    return offset;
}

@end
