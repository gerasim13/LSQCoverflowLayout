//
//  SplineInterpolator.cpp
//  LSQCoverflowLayout
//
//  Created by Павел Литвиненко on 12.09.14.
//  Copyright (c) 2014 Casual Underground. All rights reserved.
//

//_______________________________________________________________________________________________________________

#include "SplineInterpolator.h"
#include "BSpline.h"
#include <iostream>
#include <limits>

//_______________________________________________________________________________________________________________

struct OpaqueSplineInterpolator : BSpline<Float32>
{
    public:
    
    OpaqueSplineInterpolator(Float32 * x,
                             Float32 * y,
                             size_t n) : BSpline<Float32>(x, (int)n, y, 0)
    {
        //this->Debug(true);
    }
    
    ~OpaqueSplineInterpolator()
    {
    }
};

//_______________________________________________________________________________________________________________

void SplineInterpolatorCreate(Float32 * x,
                              Float32 * y,
                              size_t n,
                              SplineInterpolatorRef * interpolator)
{
    *interpolator = new OpaqueSplineInterpolator(x, y, n);
}

void SplineInterpolatorDestroy(SplineInterpolatorRef interpolator)
{
    delete interpolator;
}

Float32 SplineInterpolatorProcess(SplineInterpolatorRef spline,
                                  Float32 delta)
{
    return spline->evaluate(delta);
}

//_______________________________________________________________________________________________________________
