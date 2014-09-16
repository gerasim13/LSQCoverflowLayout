//
//  SplineInterpolator.h
//  LSQCoverflowLayout
//
//  Created by Павел Литвиненко on 12.09.14.
//  Copyright (c) 2014 Casual Underground. All rights reserved.
//

//_______________________________________________________________________________________________________________

#ifndef __LSQCoverflowLayout__SplineInterpolator__
#define __LSQCoverflowLayout__SplineInterpolator__

//_______________________________________________________________________________________________________________

#include <CoreFoundation/CoreFoundation.h>

//_______________________________________________________________________________________________________________

CF_EXTERN_C_BEGIN

//_______________________________________________________________________________________________________________

typedef struct OpaqueSplineInterpolator * SplineInterpolatorRef;

//_______________________________________________________________________________________________________________

void    SplineInterpolatorCreate (Float32 * x, Float32 * y, size_t n, SplineInterpolatorRef * outRef);
void    SplineInterpolatorDestroy(SplineInterpolatorRef inRef);
Float32 SplineInterpolatorProcess(SplineInterpolatorRef inRef, Float32 delta);

//_______________________________________________________________________________________________________________

CF_EXTERN_C_END

//_______________________________________________________________________________________________________________

#endif /* defined(__LSQCoverflowLayout__SplineInterpolator__) */

//_______________________________________________________________________________________________________________
