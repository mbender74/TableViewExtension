# TableViewExtension Module for Titanium Mobile iOS

A Titanium iOS module that extends `Ti.UI.TableView` with advanced scrolling optimizations, row visibility tracking, content inset management, intelligent height caching, and selection-aware opaque row rendering.

## Features

### Core Features
- **Row Visibility Tracking** – Monitor which table rows enter/leave the viewport
- **Auto-Snapping Scroll** – Snap scrolling to row boundaries for a carousel-like experience; scrolling always stops at the top of a fully visible row
- **Dynamic Content Insets** – Programmatically adjust table insets with animation support
- **Row Prepend** – Insert rows at the top with automatic scroll offset adjustment
- **Pan Gesture Events** – Custom pan gesture recognition on table views
- **ScrollView Extensions** – Scroll-to-bottom and inset management for scroll views

### Performance Optimizations (v2.3.0+)
- **Intelligent Height Caching** – Template-based and indexPath-based caching with NSCache
- **Adaptive Preload Queue** – Background height calculation with concurrent GCD queue
- **Dynamic Cache Limits** – Adjusts based on device memory (3GB+ devices get more)
- **Scroll Event Throttling** – 30fps throttling to prevent jank
- **Image Preloading** – Thread-safe async image loading from nested view hierarchies
- **Memory Warning Handling** – Automatic cache clearing on low memory, plus cache teardown on module shutdown
- **Section Header/Footer Caching** – Estimated heights for better scrolling
- **FPS Tracking** – Real-time scroll performance monitoring
- **Cell Reuse Statistics** – Track cell creation vs reuse rates
- **Cache Invalidation on Reuse** – Stale cached heights are cleared when cells are recycled

### ProMotion 120Hz Support (v2.4.0+)
- **Adaptive Throttle** – Automatically detects ProMotion displays and increases event throttle from 30fps to 60fps
- **Frame-aligned Animations** – Animation durations aligned to 60/120Hz frame boundaries
- **Dynamic FPS Tracking** – Sample window adapts to display refresh rate for accurate FPS reporting

### Opaque Row Rendering (v2.3.0+)
- **Selection-Aware Opacity** – `opaqueRow` makes subviews opaque for best scroll performance, but temporarily goes transparent during touch so `backgroundSelectedColor` / `backgroundFocusedColor` is visible
- **Preserves Custom Colors** – When a row has no explicit `backgroundColor`, subviews keep their own `backgroundColor` (no forced color override)
- **No Green Default** – Rows without `backgroundColor` no longer fallback to an arbitrary green color

## Installation

### Local Installation (Development)

1. Build the module:
```bash
cd ios
ti build -p ios --build-only
```

2. Copy the generated ZIP from `ios/dist/de.marcbender.tableviewextension-iphone-2.4.0.zip` into your app's root folder.

3. Add the module to your `tiapp.xml`:
```xml
<modules>
  <module version="2.4.0">de.marcbender.tableviewextension</module>
</modules>
```

### ProMotion 120Hz Support (Optional)

To enable ProMotion optimization for 120Hz displays (iPhone 13 Pro+, iPhone 17+, iPad Pro), add the following key to your `tiapp.xml`:

```xml
<ti:app>
    <ios>
        <plist>
            <dict>
                <key>CADisableMinimumFrameDurationOnPhone</key>
                <true/>
            </dict>
        </plist>
    </ios>
</ti:app>
```

**Without this key**, the module runs at ~60fps (system default). **With this key**, the module automatically detects the display refresh rate and adapts scroll throttling, FPS tracking, and event rates dynamically (up to 120fps).

> **Note:** iPad Pro does not require this key — ProMotion works automatically there. Only iPhones need `CADisableMinimumFrameDurationOnPhone`.

### Global Installation

Copy the distribution ZIP to your Titanium SDK modules folder:

- **macOS:** `~/Library/Application Support/Titanium`
- **Linux:** `~/.titanium`
- **Windows:** `C:\ProgramData\Titanium`

## Usage

### Importing the Module

Nothing to import — just add it to `tiapp.xml` (see above).

### Enabling Performance Optimizations

```javascript
const tableView = Ti.UI.createTableView({
  data: rows,
  
  // Enable all smooth scrolling optimizations (recommended)
  smoothScrolling: true,
  
  // Or enable individual features:
  enableHeightCaching: true,
  estimatedRowHeight: 80,           // For lazy layout
  prefetchEnabled: true,            // Background preload queue
  imagePreloadEnabled: true,        // Async image loading
  memoryWarningHandling: true,      // Auto-clear on low memory
  sectionHeaderFooterCaching: true  // Header/footer caching
});
```

## API Reference

### TableView Properties

#### `contentInsets`
Gets or sets the content insets of the table view.

**Type:** `Object`

**Properties:**
- `top` (Number) – Top inset in points
- `bottom` (Number) – Bottom inset in points
- `left` (Number) – Left inset in points
- `right` (Number) – Right inset in points

**Example:**
```javascript
const tableView = Ti.UI.createTableView({
  data: rows,
  contentInsets: { top: 0, right: 0, bottom: 48, left: 0 }
});

// Or set dynamically
tableView.setContentInsets({ top: 0, right: 0, bottom: 60, left: 0 }, {
  animated: true,
  duration: 300
});
```

#### `handleTouches`
Enables or disables user interaction (touch events) on the table view.

**Type:** `Boolean`

**Example:**
```javascript
// Disable scrolling and touch interaction
tableView.handleTouches = false;

// Re-enable interaction
tableView.handleTouches = true;
```

#### `smoothScrolling` *(v2.3.0+)*
Convenience property that enables all performance optimizations at once.

**Type:** `Boolean`

**Example:**
```javascript
tableView.smoothScrolling = true;
// Enables: height caching, estimated heights (80pt), prefetching
```

#### `enableHeightCaching` *(v2.3.0+)*
Enables intelligent row height caching with template-based optimization.

**Type:** `Boolean`

**Example:**
```javascript
tableView.enableHeightCaching = true;
```

#### `estimatedRowHeight` *(v2.3.0+)*
Sets the estimated row height for lazy layout calculations.

**Type:** `Number` (points)

**Example:**
```javascript
tableView.estimatedRowHeight = 80; // Default recommended value
```

#### `prefetchEnabled` *(v2.3.0+)*
Enables background preload queue for proactive height calculation.

**Type:** `Boolean`

**Example:**
```javascript
tableView.prefetchEnabled = true;
```

#### `imagePreloadEnabled` *(v2.3.0+)*
Enables async image preloading from nested view hierarchies.

**Type:** `Boolean`

**Example:**
```javascript
tableView.imagePreloadEnabled = true;
```

#### `MemoryWarningHandling` *(v2.3.0+)*
Enables automatic cache clearing on memory warnings.

**Type:** `Boolean`

**Example:**
```javascript
tableView.memoryWarningHandling = true;
```

#### `sectionHeaderFooterCaching` *(v2.3.0+)*
Enables estimated heights for section headers and footers.

**Type:** `Boolean`

**Example:**
```javascript
tableView.sectionHeaderFooterCaching = true;
// Default: header=44pt, footer=22pt
```

### TableView Methods

#### `setContentInsets(insets, options)`
Sets the content insets with advanced options for animation and scroll behavior.

**Parameters:**
- `insets` (Object) – Content inset values with `top`, `right`, `bottom`, `left` properties
- `options` (Object) – Optional configuration object

**Options:**
- `animated` (Boolean) – Whether to animate the inset change (default: `false`)
- `duration` (Number) – Animation duration in milliseconds (default: `180`)
- `nobottom` (Boolean) – Skip scrolling to bottom after setting insets (default: `false`)
- `noOffset` (Boolean) – Skip adjusting the content offset entirely (default: `false`)
- `newoffset` (Number) – Custom Y offset to scroll to after setting insets
- `safearea` (Number) – Additional safe area offset to add (default: `0`)

**Example:**
```javascript
// Basic usage
tableView.setContentInsets({ top: 0, right: 0, bottom: 48, left: 0 }, {});

// Animated with safe area (e.g., for tab bar)
tableView.setContentInsets(
  { top: 0, right: 0, bottom: 48, left: 0 },
  {
    animated: true,
    duration: 300,
    safearea: 34
  }
);

// Scroll to specific offset
tableView.setContentInsets(
  { top: 0, right: 0, bottom: 0, left: 0 },
  {
    animated: true,
    newoffset: 200,
    nobottom: true
  }
);

// Set insets without scrolling
tableView.setContentInsets(
  { top: 10, right: 5, bottom: 10, left: 5 },
  { noOffset: true }
);
```

#### `appendRowBeforeRow(row)`
Inserts a new row at the top of the table and adjusts the scroll offset to maintain the user's visual position.

**Parameters:**
- `row` (Ti.UI.TableViewRow) – The row to insert at the top

**Example:**
```javascript
const newRow = Ti.UI.createTableViewRow({
  title: 'New Item',
  hasDetail: true,
  detail: 'Just added'
});

// Insert at top, maintaining scroll position
tableView.appendRowBeforeRow(newRow);
```

**Use Case:** Infinite scroll / loading older items above the current view — infinite lazy loading on top (like normal lazy loading on bottom).

```javascript
tableView.addEventListener('scroll', function(e) {
  if (e.contentOffset <= 0) {
    // User scrolled to top, load more items
    const newRows = loadOlderItems();
    newRows.forEach(row => {
      tableView.appendRowBeforeRow(row);
    });
  }
});
```

#### `invalidateHeightCache()` *(v2.3.0+)*
Clears the entire height cache. Call this after significant data changes.

**Example:**
```javascript
// After bulk data update
tableView.invalidateHeightCache();
```

#### `getCacheStats()` *(v2.3.0+)*
Returns cache performance statistics.

**Returns:** `Object` with:
- `hits` (Number) – Total cache hits
- `misses` (Number) – Total cache misses
- `templateHits` (Number) – Template cache hits
- `count` (Number) – Current cache entry count
- `totalCost` (Number) – Total cache cost in bytes
- `hitRate` (Number) – Hit rate percentage
- `avgCalculationTime` (Number) – Average height calculation time in ms
- `totalCalculationTime` (Number) – Total time spent on height calculations

**Example:**
```javascript
const stats = tableView.getCacheStats();
Ti.API.info(`Cache hit rate: ${stats.hitRate.toFixed(1)}%`);
Ti.API.info(`Average calc time: ${stats.avgCalculationTime.toFixed(2)}ms`);
```

#### `getPerformanceStats()` *(v2.3.0+)*
Returns comprehensive performance statistics.

**Returns:** `Object` with:
- `fps` (Number) – Current scroll FPS
- `frameCount` (Number) – Total frames processed
- `cacheEntries` (Number) – Current cache entry count
- `cellReuseCount` (Number) – Cells reused
- `cellCreateCount` (Number) – Cells created
- `cellReuseRate` (Number) – Reuse rate percentage

**Example:**
```javascript
const perf = tableView.getPerformanceStats();
Ti.API.info(`FPS: ${perf.fps.toFixed(1)}`);
Ti.API.info(`Cell reuse rate: ${perf.cellReuseRate.toFixed(1)}%`);
```

#### `logPerformance()` *(v2.3.0+)*
Logs current performance metrics to console (NSLog). Use this to monitor scroll performance in real-time.

**Example:**
```javascript
// Log performance every 5 seconds
setInterval(() => {
  tableView.logPerformance();
}, 5000);

// Console output:
// [TableViewExtension/Smooth] === Performance Report ===
// [TableViewExtension/Smooth] Scroll FPS: 59.8 (frames: 3600)
// [TableViewExtension/Smooth] Cache Hit Rate: 94.2% (1234/1310, 890 template)
// [TableViewExtension/Smooth] Avg Height Calc: 2.34ms (total: 234.56ms)
// [TableViewExtension/Smooth] Cache Size: 456 entries (1.8KB), Templates: 23 (0.1KB)
// [TableViewExtension/Smooth] Cell Reuse: 890 reused, 66 created (93.1% reuse rate)
// [TableViewExtension/Smooth] ============================
```

**Metrics Explained:**
- **FPS**: Current scroll frames per second (60 = perfect)
- **Cache Hit Rate**: Percentage of cached height lookups (higher = better)
- **Avg Height Calc**: Average time to calculate row height (lower = better)
- **Cache Size**: Current memory usage for height cache
- **Cell Reuse**: Cell creation vs reuse statistics (higher reuse = better)

### TableView Events

#### `rowvisible`
Fired when a table row becomes visible in the viewport. Throttled to 30fps to prevent jank.

**Event Properties:**
- `section` (Ti.UI.TableViewSection) – The section containing the row
- `index` (Number) – Global index of the row across all sections
- `topOffset` (Number) – Y position of the row in the superview
- `row` (Ti.UI.TableViewRow) – The row proxy that became visible
- `rowData` (Ti.UI.TableViewRow) – Same as `row`, included for compatibility
- `isVisible` (Number) – Always `1` (visible)

**Example:**
```javascript
tableView.addEventListener('rowvisible', function(e) {
  Ti.API.info(`Row ${e.index} is now visible at offset: ${e.topOffset}`);
  
  // Lazy load images when rows become visible
  if (e.rowData.image && !e.rowData.image.loaded) {
    e.rowData.image.loaded = true;
    e.rowData.image.url = e.rowData.image.placeholder;
  }
  
  // Track analytics for visible content
  trackView(e.rowData.contentId);
});
```

#### `rownotvisible`
Fired when a table row scrolls out of the viewport. Throttled to 30fps.

**Event Properties:**
- `section` (Ti.UI.TableViewSection) – The section containing the row
- `index` (Number) – Global index of the row
- `topOffset` (Number) – Y position of the row in the superview
- `row` (Ti.UI.TableViewRow) – The row proxy that became invisible
- `rowData` (Ti.UI.TableViewRow) – Same as `row`

**Example:**
```javascript
// Pause media playback when rows scroll out of view
tableView.addEventListener('rownotvisible', function(e) {
  if (e.rowData.mediaPlayer) {
    e.rowData.mediaPlayer.pause();
  }
});

// Cleanup or unload heavy resources
tableView.addEventListener('rownotvisible', function(e) {
  e.rowData.height = 'Ti.UI.SIZE'; // Allow dynamic height recalculation
});
```

#### `scroll` *(v2.3.0+)*
Fired continuously while the table view is scrolling. Throttled to 30fps for performance.

**Event Properties:**
- `contentOffset` (Object) – Current scroll position with `x` and `y` properties
- `contentSize` (Object) – Total scrollable content size with `width` and `height` properties
- `size` (Object) – Visible table view bounds with `width` and `height` properties
- `velocity` (Object) – Scroll velocity with `x` and `y` properties (pixels/second)

**Example:**
```javascript
tableView.addEventListener('scroll', function(e) {
  Ti.API.info(`Scroll position: x=${e.contentOffset.x}, y=${e.contentOffset.y}`);
  Ti.API.info(`Velocity: x=${e.velocity.x}, y=${e.velocity.y}`);
  
  // Detect scroll direction
  if (e.velocity.y > 0) {
    Ti.API.info('Scrolling down');
  } else if (e.velocity.y < 0) {
    Ti.API.info('Scrolling up');
  }
  
  // Infinite scroll: load more when near bottom
  const scrollBottom = e.contentOffset.y + e.size.height;
  const threshold = e.contentSize.height - scrollBottom;
  if (threshold < 200) {
    loadMoreItems();
  }
});
```

#### `scrollend` *(v2.3.0+)*
Fired when scrolling ends (user releases or deceleration completes).

**Event Properties:**
- `contentOffset` (Object) – Final scroll position with `x` and `y` properties
- `contentSize` (Object) – Total scrollable content size with `width` and `height` properties
- `size` (Object) – Visible table view bounds with `width` and `height` properties
- `velocity` (Object) – Final velocity with `x` and `y` properties

**Example:**
```javascript
tableView.addEventListener('scrollend', function(e) {
  Ti.API.info(`Scroll ended at: y=${e.contentOffset.y}`);
  
  // Save scroll position
  saveScrollPosition(e.contentOffset.y);
  
  // Resume paused operations
  resumeImageLoading();
  
  // Check if scrolled to bottom
  const scrollBottom = e.contentOffset.y + e.size.height;
  if (scrollBottom >= e.contentSize.height - 10) {
    Ti.API.info('Scrolled to bottom!');
  }
});
```

#### `pan`
Fired during a pan gesture on the table view.

**Event Properties:**
- `translation` (Object) – Translation point with `x` and `y` properties
- `velocity` (Object) – Velocity point with `x` and `y` properties

**Example:**
```javascript
tableView.panGesture = true; // Enable pan gesture

tableView.addEventListener('pan', function(e) {
  Ti.API.info(`Pan: ${e.translation.x}, ${e.translation.y}`);
  Ti.API.info(`Velocity: ${e.velocity.x}, ${e.velocity.y}`);
  
  // Parallax effect
  const backgroundView = tableView.backgroundView;
  if (backgroundView) {
    backgroundView.transform = Ti.UI.create2DMatrix()
      .translate(0, e.translation.y * 0.3);
  }
});
```

#### `panend`
Fired when a pan gesture ends.

**Example:**
```javascript
tableView.addEventListener('panend', function() {
  Ti.API.info('Pan gesture ended');
  // Reset parallax or trigger actions based on final velocity
});
```

### Row Properties

#### `isVisible`
Checks if a table row is currently visible in the viewport.

**Type:** `Number` (`0` = not visible, `1` = visible)

**Example:**
```javascript
const row = tableView.data[0].rows[5];
const visible = row.isVisible;

if (visible === 1) {
  Ti.API.info('Row is currently visible');
}
```

#### `getTopOffset`
Gets the Y position of the row relative to the table view's superview.

**Type:** `Number` (points)

**Example:**
```javascript
const row = tableView.data[0].rows[10];
const yOffset = row.getTopOffset;
Ti.API.info(`Row is at Y position: ${yOffset}`);
```

#### `setSubView`
Sets a view as the row content with automatic height calculation.

**Type:** `Ti.UI.View`

**Example:**
```javascript
const row = Ti.UI.createTableViewRow();

const containerView = Ti.UI.createView({
  layout: 'vertical',
  children: [
    Ti.UI.createLabel({ text: 'Title', font: { fontSize: 18 } }),
    Ti.UI.createLabel({ text: 'Description', font: { fontSize: 14 } })
  ]
});

// Automatically calculates row height based on view content
row.setSubView(containerView);
```

#### `opaqueRow`
Makes the row and its subviews opaque for optimized rendering performance, while preserving selection visibility.

**How it works:**

- **Row WITH explicit `backgroundColor`** — the row's color is applied to all subviews (`cell`, `contentView`, `textLabel`, `imageView`, `accessoryView`, etc.) so everything is fully opaque. During touch/selection, subviews briefly become transparent so `backgroundSelectedColor` shows through, then snap back to opaque after the selection animation ends.

- **Row WITHOUT explicit `backgroundColor`** — subviews keep their own `backgroundColor` and only get `opaque=YES` if they already have a solid background. The `contentView` is left untouched. This is ideal when inner `View`, `Label`, or `ImageView` provide their own colors.

**Type:** `Boolean`

**Example — row with explicit backgroundColor:**
```javascript
const row = Ti.UI.createTableViewRow({
  title: 'Optimized Row',
  backgroundColor: '#ffffff',
  backgroundSelectedColor: '#e0e0e0',
  height: 80
});

// All subviews become opaque white; during selection they briefly
// go transparent so backgroundSelectedColor is visible
row.opaqueRow = true;
```

**Example — row with inner view colors (no row backgroundColor):**
```javascript
const row = Ti.UI.createTableViewRow({
  height: Ti.UI.SIZE,
  className: 'yellow'
});

const view = Ti.UI.createView({
  backgroundColor: 'yellow',
  layout: 'horizontal',
  height: 69
});

const label = Ti.UI.createLabel({
  text: 'LiteRTLM Chat',
  color: '#e94560',
  backgroundColor: 'yellow'
});

const image = Ti.UI.createImageView({
  image: '/assets/images/tab2.png'
});

view.add(image);
view.add(label);
row.add(view);

// Only the yellow view/label become opaque; row background stays clear
row.opaqueRow = true;
```

**Performance Impact:**
- Reduces GPU compositing overhead (eliminates blended layers in Debug Color Blended Layers)
- Improves scroll FPS by 5-15% for complex rows
- Selection-aware: `backgroundSelectedColor` / `backgroundFocusedColor` remain visible during touch

### ScrollView Methods

#### `scrollToBottomNoAnim()`
Scrolls the scroll view to the bottom without animation.

**Example:**
```javascript
const scrollView = Ti.UI.createScrollView({
  layout: 'vertical',
  showVerticalScrollIndicator: true
});

// Add content...
for (let i = 0; i < 50; i++) {
  scrollView.add(Ti.UI.createLabel({
    text: `Item ${i}`,
    height: 40,
    top: 10
  }));
}

// Scroll to bottom immediately (no animation)
scrollView.scrollToBottomNoAnim();
```

#### `setContentInsets(insets, options)`
Sets content insets for scroll views (same signature as TableView).

**Example:**
```javascript
scrollView.setContentInsets(
  { top: 0, right: 0, bottom: 48, left: 0 },
  { animated: true, duration: 200 }
);
```

### View Properties

#### `opaque` *(v2.3.0+)*

The `opaque` property for `Ti.UI.View` was removed in v2.3.0. Use `opaqueRow` on `Ti.UI.TableViewRow` instead for optimized rendering.

## Performance Tuning Guide

### Row Height Types

The module handles different row height types optimally:

| Height Type | Behavior | Performance |
|-------------|----------|-------------|
| `height: 69` (fixed) | Fast path - skips all caching | ⚡ Fastest |
| `height: Ti.UI.SIZE` | Uses cache or calculates | 📊 Cached |
| `height: Ti.UI.FILL` | Uses cache or calculates | 📊 Cached |
| `height: "50%"` | Uses cache or calculates | 📊 Cached |

### Cache Strategy

**Template Cache**: Stores heights by row configuration (height, width, className). Identical row templates reuse cached heights instantly, skipping expensive layout calculations.

**IndexPath Cache**: Stores heights by specific row position. Provides O(1) lookup for already-displayed rows.

**Lazy Population**: Template cache hits are only stored in indexPath cache on first access, reducing memory usage by ~20%.

### Adaptive Preload Queue

The preload queue automatically adjusts based on scroll velocity:

| Scroll Speed | Preload Ahead | Preload Behind |
|--------------|---------------|----------------|
| Fast (>1000px/s) | 10 rows | 5 rows |
| Medium (500-1000px/s) | 7 rows | 4 rows |
| Slow (<500px/s) | 5 rows | 3 rows |

### Dynamic Cache Limits

Cache size adapts to device memory:

| Device Memory | Height Cache | Template Cache |
|---------------|--------------|----------------|
| 3GB+ | 3000 entries / 30MB | 750 entries / 7.5MB |
| <3GB | 2000 entries / 20MB | 500 entries / 5MB |

### Event Throttling

- **rowvisible**: 30fps (32ms interval)
- **rownotvisible**: 30fps (32ms interval)
- **scroll processing**: 30fps (32ms interval)
- **velocity tracking**: Every 3rd frame

This reduces main-thread overhead by ~50% while maintaining smooth scrolling.

### Memory Management

- **Memory Warning**: Automatically clears all caches
- **Thread Safety**: All cache operations use `os_unfair_lock`
- **No Blocking**: Preload queue uses `dispatch_group_notify` (non-blocking)

## Complete Example

```javascript
const win = Ti.UI.createWindow({
  title: 'TableViewExtension Demo'
});

// Create table view with all optimizations enabled
const tableView = Ti.UI.createTableView({
  top: 0,
  layout: 'fill',
  smoothScrolling: true  // Enable all performance features
});

// Generate sample data with mixed height types
const data = [];
for (let i = 1; i <= 100; i++) {
  if (i % 3 === 0) {
    // Fixed height rows (fastest)
    data.push(Ti.UI.createTableViewRow({
      title: `Fixed Row ${i}`,
      height: 60,
      hasDetail: true,
      detail: `Fixed height row ${i}`
    }));
  } else if (i % 3 === 1) {
    // Dynamic height rows (cached)
    data.push(Ti.UI.createTableViewRow({
      title: `Dynamic Row ${i}`,
      height: Ti.UI.SIZE,
      hasDetail: true,
      detail: `Dynamic height row ${i} with variable content`
    }));
  } else {
    // Complex rows with nested views (image preloading)
    const row = Ti.UI.createTableViewRow({
      height: Ti.UI.SIZE
    });
    
    const containerView = Ti.UI.createView({
      layout: 'vertical',
      children: [
        Ti.UI.createLabel({ 
          text: `Complex Row ${i}`,
          font: { fontSize: 16, fontWeight: 'bold' }
        }),
        Ti.UI.createImageView({
          width: 100,
          height: 100,
          image: `images/thumb-${i}.jpg`  // Will be preloaded
        }),
        Ti.UI.createLabel({ 
          text: `Description for row ${i}`,
          font: { fontSize: 14 }
        })
      ]
    });
    
    row.setSubView(containerView);
    data.push(row);
  }
}

tableView.data = data;

// Track row visibility
tableView.addEventListener('rowvisible', function(e) {
  console.log(`Row ${e.index} visible at offset: ${e.topOffset}`);
  
  // Highlight visible rows
  e.rowData.backgroundColor = '#f0f8ff';
});

tableView.addEventListener('rownotvisible', function(e) {
  e.rowData.backgroundColor = null; // Reset
});

// Monitor performance
setInterval(() => {
  const stats = tableView.getPerformanceStats();
  console.log(`FPS: ${stats.fps.toFixed(1)}, Cache: ${stats.cacheEntries} entries`);
  console.log(`Cell reuse: ${stats.cellReuseRate.toFixed(1)}%`);
}, 5000);

// Load more items when scrolling to top
let page = 1;
tableView.addEventListener('scroll', function(e) {
  if (e.contentOffset <= 10 && !tableView.isLoading) {
    tableView.isLoading = true;
    
    // Simulate network request
    setTimeout(() => {
      const newItems = [];
      for (let i = 100 - page * 10 + 1; i <= 100 - page * 10 + 10; i++) {
        newItems.push(Ti.UI.createTableViewRow({
          title: `Item ${i}`,
          height: 60,  // Fixed height for new rows
          hasDetail: true,
          detail: `Loaded item ${i}`
        }));
      }
      
      newItems.forEach(row => {
        tableView.appendRowBeforeRow(row);
      });
      
      tableView.isLoading = false;
      page++;
    }, 500);
  }
});

// Handle content insets for keyboard
Ti.App.addEventListener('keyboardappear', function(e) {
  tableView.setContentInsets(
    { top: 0, right: 0, bottom: e.height, left: 0 },
    { animated: true, duration: 250 }
  );
});

Ti.App.addEventListener('keyboardhide', function() {
  tableView.setContentInsets(
    { top: 0, right: 0, bottom: 0, left: 0 },
    { animated: true, duration: 250 }
  );
});

win.add(tableView);
win.open();
```

## Configuration Properties

### TableView Internal Properties

| Property | Type | Description |
|----------|------|-------------|
| `snappingEnabled` | Boolean | Snap scrolling to row boundaries for a carousel-like experience; scrolling always stops at the top of a fully visible row |
| `isLoading` | Boolean | Flag to prevent operations during async loading |
| `scrollSlow` | Boolean | Enable slower deceleration rate for smoother scrolling |
| `enableBounce` | Boolean | Enable/disable bounce effect |
| `alwaysBounceVertical` | Boolean | Always show vertical bounce |
| `directionalLockEnabled` | Boolean | Lock scrolling to one direction |
| `pagingEnabled` | Boolean | Enable paging behavior |
| `smoothScrolling` | Boolean | Enable all performance optimizations (v2.3.0+) |
| `enableHeightCaching` | Boolean | Enable intelligent height caching (v2.3.0+) |
| `estimatedRowHeight` | Number | Estimated height for lazy layout (v2.3.0+) |
| `prefetchEnabled` | Boolean | Enable background preload queue (v2.3.0+) |
| `imagePreloadEnabled` | Boolean | Enable async image preloading (v2.3.0+) |
| `memoryWarningHandling` | Boolean | Enable auto-clear on low memory (v2.3.0+) |
| `sectionHeaderFooterCaching` | Boolean | Enable header/footer caching (v2.3.0+) |

### Row Properties

| Property | Type | Description |
|----------|------|-------------|
| `opaqueRow` | Boolean | Make row and all subviews opaque for optimized rendering |

## Technical Details

### Architecture

- **Height Caching**: Two-level cache (template + indexPath) with NSCache
- **Preload Queue**: Concurrent GCD queue with dispatch_group
- **Thread Safety**: os_unfair_lock for all cache operations
- **Memory Management**: Dynamic limits based on device RAM
- **Event Throttling**: Separate timers for visible/not-visible events

### Performance Metrics

- **Cache Hit Rate**: Typically 90-95% for mixed content
- **Average Height Calculation**: 2-5ms for complex rows
- **FPS Tracking**: Rolling 60-frame average
- **Cell Reuse Rate**: Typically 85-95% for large datasets

### iOS Compatibility

- **Minimum**: iOS 12.0
- **Recommended**: iOS 15.0+ (for prefetching API)
- **Architectures**: arm64, x86_64
- **macOS Catalyst**: Supported

## Requirements

- **Titanium SDK:** 13.2.0+
- **Platform:** iOS
- **Architectures:** arm64, x86_64
- **macOS Catalyst:** Supported

## Changelog

### v2.4.0 (Current) — ProMotion 120Hz Support
- ✨ **ProMotion auto-detection** — Automatically detects 120Hz displays via CADisplayLink
- ✨ **Adaptive throttle** — Event throttle increases from 30fps to 60fps on ProMotion devices
- ✨ **Frame-aligned animations** — Animation durations (167ms, 200ms) aligned to 60/120Hz frame boundaries
- ✨ **Dynamic FPS tracking** — Sample window adapts to display refresh rate (60 or 120 samples)
- 🔧 **Velocity tracking** — Adjusted interval for ProMotion (every 6 frames instead of 3)

### v2.3.1 — Bugfixes & appendRowBeforeRow
- 🔧 **Fixed `appendRowBeforeRow`** — Proxy method enabled, `insertRow:before:` implemented, scroll offset adjustment improved
- 🔧 **Fixed `snappingEnabled`** — `scrollViewWillEndDragging` delegate was commented out
- 🔧 **Fixed `pagingEnabled`** — Custom paging logic removed, native UIKit paging takes over
- 🔧 **Fixed `paginEnabled` → `pagingEnabled`** — Property name now correct

### v2.3.0
- ✨ **`smoothScrolling` convenience property** — enables all performance optimizations at once
- ✨ **Selection-Aware `opaqueRow`** — `backgroundSelectedColor` / `backgroundFocusedColor` remain visible during touch while keeping rows fully opaque for scrolling
- ✨ **`opaqueRow` without explicit `backgroundColor`** — subviews retain their own colors; no arbitrary color override
- ✨ **Cache invalidation on cell reuse** — stale cached heights are cleared automatically when cells are recycled
- 🔄 **Removed `opaque` property for `Ti.UI.View`** — use `opaqueRow` on `Ti.UI.TableViewRow` instead
- 🔄 **Removed `opaqueView()` legacy method**
- 🔧 **Fixed `hasExplicitRowBg` check** — no longer falls back to TableView `backgroundColor`, preventing rows without explicit `backgroundColor` from being painted with the table color
- 🔧 **Fixed cache accounting underflow** — counters only decremented when key actually exists in cache
- 🔧 **Removed redundant lock/unlock pair** in template cache fast path
- 🔧 **Thread-safe image preloading** — `imageWithContentsOfFile:` instead of non-thread-safe `imageNamed:`
- 🔧 **Removed green default** in `setOpaqueRow:` when row has no `backgroundColor`
- 🔧 **Consolidated all cell swizzling** into `TiUITableViewCell+WithReuse.m` to prevent order-dependent collisions
- 🔧 **Cache teardown on module unload / memory warning** — frees `sharedHeightCache`, `sharedTemplateCache`, `cacheLock`, and preload queue
- 🔧 **Removed dead fixed-height code** from `cachedHeightForRow:indexPath:` (already handled upstream)
- 🔧 **Removed `UICollectionView+autoSnapping.swift`** — no longer needed
- 🔧 **Fixed `paginEnabled` → `pagingEnabled`** — Property name now correct (was missing a 'g')
- 🔧 **Fixed `snappingEnabled`** — `scrollViewWillEndDragging` delegate was commented out, snapping now works
- 🔧 **Fixed `pagingEnabled`** — Custom paging logic removed, native UIKit paging takes over (previous conflict caused jumping back)

### v2.2.0
- Added row visibility tracking
- Added auto-snapping scroll
- Added dynamic content insets
- Added row prepend functionality
- Added pan gesture events
- Added intelligent height caching with template-based optimization
- Added adaptive preload queue with concurrent GCD
- Added dynamic cache limits based on device memory
- Added scroll event throttling (30fps)
- Added async image preloading from nested views
- Added memory warning handling
- Added section header/footer caching
- Added FPS tracking and performance statistics
- Added cell reuse statistics
- Added `opaque` property for Ti.UI.View (recursive subview support)
- Added `opaqueRow` property for Ti.UI.TableViewRow
- Added recursive subview processing for `opaqueView()`
- Added `scroll` event with velocity tracking
- Added `scrollend` event for scroll completion

## Author

Marc Bender

## License

Copyright (c) 2026 by Marc Bender
