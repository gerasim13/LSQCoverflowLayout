//
//  LSQCoverflowCellView.m
//  LSQCoverflowLayout
//
//  Created by Павел Литвиненко on 12.09.14.
//  Copyright (c) 2014 Casual Underground. All rights reserved.
//

#import "LSQCoverflowCellView.h"

@implementation LSQCoverflowCellView

- (void)setup
{
    [self.layer setCornerRadius:12.0];
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
