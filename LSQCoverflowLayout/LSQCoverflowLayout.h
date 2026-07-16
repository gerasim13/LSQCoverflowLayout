//
//  LSQCoverflowLayout.h
//  LSQCoverflowLayout
//
//  Created by Павел Литвиненко on 11.09.14.
//  Copyright (c) 2014 Casual Underground. All rights reserved.
//

//_______________________________________________________________________________________________________________

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

//_______________________________________________________________________________________________________________

@class LSQCoverflowLayout;

//_______________________________________________________________________________________________________________

@protocol LSQCoverflowLayoutDelegate <NSObject>
- (void)coverflowLayout:(LSQCoverflowLayout*)layout didChangeCurrentIndex:(NSInteger)index;
@end

//_______________________________________________________________________________________________________________

@interface LSQCoverflowLayout : UICollectionViewFlowLayout

@property (nonatomic, readonly) CGSize    collectionViewContentSize;
/// Horizontal center-to-center distance between adjacent covers. Defaults to 40 points.
@property (nonatomic, assign  ) CGFloat   coverSpacing;
@property (nonatomic, assign  ) NSInteger currentIndex;
@property (nonatomic, assign  ) BOOL      snapToCells;

- (void)snapContentOffsetToCell:(NSInteger)index
                       animated:(BOOL)animated;

@end

//_______________________________________________________________________________________________________________
