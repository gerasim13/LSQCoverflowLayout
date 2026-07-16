//
//  LSQCoverflowCellView.h
//  LSQCoverflowLayout
//
//  Created by Павел Литвиненко on 12.09.14.
//  Copyright (c) 2014 Casual Underground. All rights reserved.
//

#import <UIKit/UIKit.h>

typedef void (^LSQCoverflowCellTransitionCompletion)(BOOL finished);

@interface LSQCoverflowCellView : UICollectionViewCell

@property (nonatomic, weak) IBOutlet UIImageView *imageView;
@property (nonatomic, weak) IBOutlet UILabel     *labelView;

/// Content supplied by the host. Replacing either side detaches the old view.
@property (nonatomic, strong) UIView *frontContentView;
@property (nonatomic, strong) UIView *backContentView;

/// Keeps the face animation independent from the collection layout's 3D transform.
@property (nonatomic, strong, readonly) UIView *coverContainerView;
@property (nonatomic, assign, readonly, getter=isFlipped) BOOL flipped;

- (void)flipToBackWithSize:(CGSize)size
                  animated:(BOOL)animated
                completion:(LSQCoverflowCellTransitionCompletion)completion;

- (void)flipToFrontWithSize:(CGSize)size
                   animated:(BOOL)animated
                 completion:(LSQCoverflowCellTransitionCompletion)completion;

@end
