# Performance Optimization Plan for TableViewExtension

## Current State Analysis

After thorough code review, the following optimization opportunities were identified:

### 1. Scroll-to-Row Snapping (HIGH PRIORITY)
**Problem:** `autoSnappping()` calculates target offset but never actually applies it — calls `targetContentOffset->y = ...` but the system doesn't use this value.

**Issue Location:** `TiUITableView+Snappy.m:scrollViewWillEndDragging()`
```objc
// Current code modifies targetContentOffset but doesn't apply it:
offset->y = CGRectGetMinY(cellRect) - tableview.contentInset.top;
// ... no [tableview setContentOffset:*offset] call!
```

**Impact:** Snapping logic exists but is **completely broken** — rows never snap to boundaries.

**Solution:**
```objc
// Apply the calculated offset:
targetContentOffset->y = offset->y;
// OR force scroll with animation disabled:
[tableView setContentOffset:CGPointMake(0, offset->y) animated:NO];
```

---

### 2. Unnecessary Height Calculation on appendRowBeforeRow (MEDIUM PRIORITY)
**Problem:** `appendRowBeforeRow()` calculates height twice — once manually, then again via `insertRowsAtIndexPaths`.

**Issue Location:** `TiUITableView+Snappy.m:appendRowBeforeRow()`
```objc
// Manual calculation:
cellheight = ceil([row rowHeight:[row sizeWidthForDecorations:[self computeRowWidth] forceResizing:NO]]);
[row replaceValue:[NSNumber numberWithFloat:cellheight] forKey:@"height" notification:NO];

// Then insertRowsAtIndexPaths triggers heightForRowAtIndexPath again!
```

**Impact:** Extra layout pass on every prepend operation.

**Solution:** Remove manual height calculation — let `heightForRowAtIndexPath` handle it (which will use the cache).

---

### 3. Cache Size Limits Could Be More Aggressive (LOW PRIORITY)
**Problem:** Cache limits based solely on memory size, not on actual row count or content complexity.

**Current Logic:**
```objc
NSUInteger cacheLimit = (memoryMB > 3000) ? 3000 : 2000;  // 3GB threshold
```

**Opportunity:** Consider adding:
- Max entries based on visible rows + preload window
- Per-section cache limits for large datasets
- LRU eviction policy for indexPath cache

---

### 4. Preload Queue Throttling Could Be Smarter (MEDIUM PRIORITY)
**Problem:** `preloadRowHeightsIfNeeded()` only preloads every 2nd scroll event.

```objc
scrollEventCount++;
if (scrollEventCount % 2 != 0) return;  // Skip every other scroll
```

**Issue:** This creates a **fixed 50% overhead reduction** but may cause jank on fast scrolls.

**Opportunity:** 
- Increase ahead rows during fast scroll (already done)
- Reduce preload behind rows (currently 3/5, could be 1/2)
- Skip preload entirely if velocity > threshold

---

### 5. Redundant `forceResizing:YES` Calls (LOW PRIORITY)
**Problem:** `cachedHeightForRow()` uses `forceResizing:YES` for initial width calculation.

**Issue Location:** `TiUITableView+SmoothScrolling.m:cachedHeightForRow()`
```objc
CGFloat width = [row sizeWidthForDecorations:[self computeRowWidth] forceResizing:YES];
```

**Opportunity:** 
- Use `forceResizing:NO` on cache hits (already done)
- Profile if `forceResizing:YES` is actually necessary

---

### 6. Memory Warning Cache Clearing Could Be Selective (LOW PRIORITY)
**Problem:** Memory warning clears **all** caches — even template cache which is expensive to rebuild.

**Opportunity:**
- Keep template cache (reusable across rows)
- Clear only indexPath cache
- Add "partial clear" option to `invalidateHeightCache()`

---

### 7. FPS Logging Could Be More Efficient (LOW PRIORITY)
**Problem:** FPS logging happens on every scroll event, even when throttled.

**Current:**
```objc
if (frameCount % kLogInterval == 0) {
    // Log every 60 frames
}
```

**Opportunity:**
- Reduce log frequency to every 120 frames (2 seconds at 60fps)
- Add "verbose logging" flag for debugging

---

### 8. Row Visibility Event Throttling Could Be Adaptive (MEDIUM PRIORITY)
**Problem:** Fixed throttle interval (`gThrottleInterval`) applies to both rowvisible/rownotvisible.

**Opportunity:**
- Different throttle for visible vs not-visible events
- More frequent not-visible events (for resource cleanup)
- Less frequent visible events (for analytics)

---

### 9. Missing `prefetchRowsAtIndexPaths` Optimization (MEDIUM PRIORITY)
**Problem:** Image preloading in `prefetchRowsAtIndexPaths` uses `dispatch_async` but doesn't cancel on scroll.

**Opportunity:**
- Cancel pending image preloads on new scroll
- Use `NSOperationQueue` with priority management
- Limit concurrent preloads to avoid memory spikes

---

### 10. Animation Duration Could Use CADisplayLink (NICE-TO-HAVE)
**Problem:** Fixed animation durations (167ms, 200ms) don't adapt to actual display refresh rate.

**Current:**
```objc
static const CGFloat kDefaultAnimationDuration = 167; // ms
```

**Opportunity:**
```objc
// Calculate frames based on actual display duration
CGFloat displayDuration = [CADisplayLink displayLinkWithTarget:nil selector:@selector(start)].duration;
NSInteger frames = 12; // Target 12 frames
CGFloat animationDurationMs = (frames * displayDuration * 1000.0);
```

---

## Implementation Priority Matrix

| # | Optimization | Priority | Effort | Impact | Status |
|---|--------------|----------|--------|--------|--------|
| 1 | Scroll-to-Row Snapping | **HIGH** | Low | High | ❌ Not implemented |
| 2 | appendRowBeforeRow optimization | MEDIUM | Low | Medium | ❌ Not implemented |
| 3 | Cache size limits | LOW | Medium | Medium | ⚧ Partially done |
| 4 | Preload queue throttling | MEDIUM | Medium | Medium | ⚧ Partially done |
| 5 | forceResizing optimization | LOW | Low | Low | ⚧ Not needed |
| 6 | Selective cache clearing | LOW | Medium | Medium | ❌ Not implemented |
| 7 | FPS logging efficiency | LOW | Low | Low | ⚧ Partially done |
| 8 | Adaptive event throttling | MEDIUM | Medium | Medium | ❌ Not implemented |
| 9 | Prefetch optimization | MEDIUM | High | High | ❌ Not implemented |
| 10 | Dynamic animation duration | NICE-TO-HAVE | Medium | Low | ❌ Not implemented |

---

## Quick Wins (Implement First)

### ✅ Priority 1: Fix Snapping
**Time:** 15 minutes  
**Impact:** High (feature currently broken)  
**Risk:** Low

```objc
// In TiUITableView+Snappy.m:scrollViewWillEndDragging()
if ([TiUtils boolValue:[self.proxy valueForUndefinedKey:@"snappingEnabled"] def:NO]) {
    if (![TiUtils boolValue:[self.proxy valueForUndefinedKey:@"isLoading"] def:NO]) {
        [self autoSnappping:velocity withTargetOffset:targetContentOffset];
        // Apply the calculated offset:
        [tableView setContentOffset:CGPointMake(0, targetContentOffset->y) animated:NO];
    }
}
```

### ✅ Priority 2: Remove Double Height Calculation
**Time:** 10 minutes  
**Impact:** Medium (faster prepend operations)  
**Risk:** Low

```objc
// In TiUITableView+Snappy.m:appendRowBeforeRow()
// Remove manual height calculation — let heightForRowAtIndexPath handle it
```

### ✅ Priority 3: Reduce Preload Behind Rows
**Time:** 5 minutes  
**Impact:** Medium (less memory usage)  
**Risk:** Low

```objc
// In TiUITableView+SmoothScrolling.m:scrollViewDidScroll()
gPreloadBehindRows = (speed > 1000) ? 2 : (speed > 500) ? 2 : 1;
```

---

## Long-term Enhancements

### Cache Improvements
- Per-section cache limits
- LRU eviction for indexPath cache
- Template cache size based on unique row types

### Event System
- Separate throttle for rowvisible/rownotvisible
- Cancel pending preloads on scroll
- Priority-based preload queue

### Animation
- Dynamic duration via CADisplayLink
- Frame-aligned durations for 60/120Hz

---

## Testing Strategy

1. **Snapping Fix:** Test with `snappingEnabled=true`, verify rows snap to top/bottom boundaries
2. **Height Calculation:** Benchmark `appendRowBeforeRow()` before/after optimization
3. **Preload:** Monitor memory usage with fast scroll (should be lower)
4. **FPS:** Verify FPS tracking accuracy on 60Hz vs 120Hz displays

---

## Related Files

- `TiUITableView+Snappy.m` — Snapping, appendRowBeforeRow, row visibility events
- `TiUITableView+SmoothScrolling.m` — Height caching, preload queue, FPS tracking
- `TiUITableViewCell+WithReuse.m` — Cell reuse, opaque selection support
- `TiUIScrollView+Extended.m` — Scroll view extensions

---

## Notes

- ProMotion support (v2.4.0) already implemented and working
- All critical optimizations from the original plan are complete
- Remaining issues are fine-tuning and edge-case improvements
