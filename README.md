# LSQCoverflowLayout

Spline-driven `UICollectionViewLayout` used by Loopseque, plus a reusable
`LSQCoverflowView` wrapper for two-sided covers.

## CocoaPods

```ruby
pod 'LSQCoverflowLayout', :path => '/path/to/LSQCoverflowLayout'
```

The wrapper asks its data source for front views while populating the
collection. It asks for the current cover's back view only when that cover is
opened. Tapping a side cover centers it; tapping the current cover runs the
original Loopseque Store sequence:

1. `willFlipCoverAtIndex:` and a 0.3-second preparation interval.
2. A 0.8-second flip from the left.
3. A 0.3-second expansion from `coverSize` to `flippedCoverSize`.

Closing shrinks first and then uses the same flip-from-left transition as the
original app. Scrolling is disabled while the back is open, but side covers
remain visible. Hosts own all content and business logic.

Every transition that starts has one terminal result. The optional
`didFinishFlipAtIndex:finished:` and `didFinishCloseAtIndex:finished:` delegate
callbacks fire for both success and cancellation (including a reload during an
animation), even when the caller passed a nil completion block. The older
`didFlipCoverAtIndex:` and `didCloseCoverAtIndex:` callbacks remain success-only.

Set `coverSpacing` on `LSQCoverflowView` (or directly on
`LSQCoverflowLayout`) to change the horizontal center-to-center step between
covers. It defaults to the historical 40 points. Runtime changes preserve the
logical scroll position, including while a cover is flipped.
