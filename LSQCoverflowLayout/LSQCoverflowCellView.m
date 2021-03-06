//
//  LSQCoverflowCellView.m
//  LSQCoverflowLayout
//
//  Created by Павел Литвиненко on 12.09.14.
//  Copyright (c) 2014 Casual Underground. All rights reserved.
//

#import "LSQCoverflowCellView.h"

@implementation LSQCoverflowCellView
@synthesize imageView;
@synthesize labelView;

- (void)setup
{
    self.layer.cornerRadius = 0.0;
    self.layer.speed        = 1.8;
    self.imageView.opaque   = YES;
}

- (id)initWithFrame:(CGRect)frame
{
    if (self = [super initWithFrame:frame])
    {
        [self setup];
    }
    return self;
}

- (id)initWithCoder:(NSCoder*)aDecoder
{
    if (self = [super initWithCoder:aDecoder])
    {
        [self setup];
    }
    return self;
}

@end
