# TableViewExtension Module v2.4.0

## Description

TableViewExtension is a Titanium iOS module that extends the native `UITableView` component with advanced functionality including:
- **Row Visibility Tracking** – Monitor which table rows enter/leave the viewport
- **Auto-Snapping Scroll** – Snap scrolling to row boundaries for a carousel-like experience; scrolling always stops at the top of a fully visible row
- **Dynamic Content Insets** – Programmatically adjust table insets with animation support
- **Row Prepend** – Insert rows at the top with automatic scroll offset adjustment
- **Pan Gesture Events** – Custom pan gesture recognition on table views

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

## Accessing the TableViewExtension Module

To access this module from JavaScript:

```javascript
// ES6+ (recommended)
import tableviewextension from 'de.marcbender.tableviewextension';

// ES5
var tableviewextension = require('de.marcbender.tableviewextension');
```

## Reference

### TableView Properties

#### `contentInsets`

Gets or sets the content insets of the table view.

**Type:** `Object`

**Properties:**
- `top` (Number) – Top inset in points
- `right` (Number) – Right inset in points
- `bottom` (Number) – Bottom inset in points
- `left` (Number) – Left inset in points

**Example:**
```javascript
const tableView = Ti.UI.createTableView({
  data: rows,
  contentInsets: { top: 0, right: 0, bottom: 48, left: 0 }
});
```

#### `handleTouches`

Enables or disables user interaction on the table view.

**Type:** `Boolean`

**Example:**
```javascript
tableView.handleTouches = false; // Disable scrolling
```

#### `snappingEnabled`

Snap scrolling to row boundaries for a carousel-like experience; scrolling always stops at the top of a fully visible row.

**Type:** `Boolean`

**Example:**
```javascript
tableView.snappingEnabled = true;
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

### ScrollView Properties

#### `scrollToBottomNoAnim()`

Scrolls to the bottom without animation.

**Example:**
```javascript
scrollView.scrollToBottomNoAnim();
```

#### `setContentInsets(insets, options)`

Sets content insets for scroll views (same signature as TableView).

### TableView Methods

#### `setContentInsets(insets, options)`

Sets the content insets with advanced options for animation and scroll behavior.

**Parameters:**
- `insets` (Object) – Content inset values with `top`, `right`, `bottom`, `left`
- `options` (Object) – Configuration object:
  - `animated` (Boolean) – Animate the change (default: `false`)
  - `duration` (Number) – Animation duration in ms (default: `180`)
  - `nobottom` (Boolean) – Skip scrolling to bottom (default: `false`)
  - `noOffset` (Boolean) – Skip content offset adjustment (default: `false`)
  - `newoffset` (Number) – Custom Y offset to scroll to
  - `safearea` (Number) – Additional safe area offset (default: `0`)

**Example:**
```javascript
tableView.setContentInsets(
  { top: 0, right: 0, bottom: 48, left: 0 },
  { animated: true, duration: 300, safearea: 34 }
);
```

#### `appendRowBeforeRow(row)`

Inserts a row at the top of the table with automatic scroll offset adjustment.

**Parameters:**
- `row` (Ti.UI.TableViewRow) – The row to insert

**Example:**
```javascript
const newRow = Ti.UI.createTableViewRow({ title: 'New Item' });
tableView.appendRowBeforeRow(newRow);
```

### TableView Events

#### `rowvisible`

Fired when a table row becomes visible. Throttled to 30fps (60fps on ProMotion displays) to prevent jank.

**Event Properties:**
- `section` (Ti.UI.TableViewSection) – The section
- `index` (Number) – Global row index
- `topOffset` (Number) – Y position in superview
- `row` (Ti.UI.TableViewRow) – The row proxy
- `rowData` (Ti.UI.TableViewRow) – Same as `row`
- `isVisible` (Number) – Always `1`

**Example:**
```javascript
tableView.addEventListener('rowvisible', function(e) {
  console.log(`Row ${e.index} visible at: ${e.topOffset}`);
});
```

#### `rownotvisible`

Fired when a table row scrolls out of view. Throttled to 30fps (60fps on ProMotion displays).

**Event Properties:**
- `section` (Ti.UI.TableViewSection)
- `index` (Number)
- `topOffset` (Number)
- `row` (Ti.UI.TableViewRow)
- `rowData` (Ti.UI.TableViewRow)

**Example:**
```javascript
tableView.addEventListener('rownotvisible', function(e) {
  // Pause media, cleanup resources
});
```

#### `scroll` *(v2.3.0+)*

Fired continuously while the table view is scrolling. Throttled to 30fps (60fps on ProMotion).

**Event Properties:**
- `contentOffset` (Object) – Current scroll position with `x` and `y`
- `contentSize` (Object) – Total scrollable content size with `width` and `height`
- `size` (Object) – Visible table view bounds with `width` and `height`
- `velocity` (Object) – Scroll velocity with `x` and `y` (pixels/second)

**Example:**
```javascript
tableView.addEventListener('scroll', function(e) {
  console.log(`Scroll: y=${e.contentOffset.y}, velocity: ${e.velocity.y}`);
});
```

#### `scrollend` *(v2.3.0+)*

Fired when scrolling ends (user releases or deceleration completes).

**Event Properties:**
- `contentOffset` (Object) – Final scroll position with `x` and `y`
- `contentSize` (Object) – Total scrollable content size
- `size` (Object) – Visible table view bounds
- `velocity` (Object) – Final velocity with `x` and `y`

**Example:**
```javascript
tableView.addEventListener('scrollend', function(e) {
  console.log(`Scroll ended at: y=${e.contentOffset.y}`);
});
```

#### `pan`

Fired during pan gestures (requires `panGesture = true`).

**Event Properties:**
- `translation` (Object) – `{ x, y }` translation values
- `velocity` (Object) – `{ x, y }` velocity values

**Example:**
```javascript
tableView.panGesture = true;
tableView.addEventListener('pan', function(e) {
  console.log(`Pan: ${e.translation.x}, ${e.translation.y}`);
});
```

#### `panend`

Fired when a pan gesture ends.

**Example:**
```javascript
tableView.addEventListener('panend', function() {
  console.log('Pan ended');
});
```

### Row Properties

#### `isVisible`

Checks if a row is visible in the viewport.

**Type:** `Number` – `0` (not visible) or `1` (visible)

**Example:**
```javascript
const row = tableView.data[0].rows[5];
if (row.isVisible === 1) {
  console.log('Row is visible');
}
```

#### `getTopOffset`

Gets the Y position of the row relative to the superview.

**Type:** `Number` – Y offset in points

**Example:**
```javascript
const yOffset = tableView.data[0].rows[10].getTopOffset;
```

#### `opaqueRow`

Makes the row and its subviews opaque for optimized rendering performance, while preserving selection visibility.

**Type:** `Boolean`

**Example:**
```javascript
const row = Ti.UI.createTableViewRow({
  title: 'Optimized Row',
  backgroundColor: '#ffffff',
  backgroundSelectedColor: '#e0e0e0'
});
row.opaqueRow = true; // All subviews become opaque, selection colors show during touch
```

### ScrollView Methods

#### `scrollToBottomNoAnim()`

Scrolls to the bottom without animation.

**Example:**
```javascript
scrollView.scrollToBottomNoAnim();
```

#### `setContentInsets(insets, options)`

Same signature as TableView `setContentInsets`.

**Parameters:**
- `insets` (Object) – Content inset values with `top`, `right`, `bottom`, `left`
- `options` (Object) – Configuration object:
  - `animated` (Boolean) – Animate the change (default: `false`)
  - `duration` (Number) – Animation duration in ms (default: `180`)
  - `safearea` (Number) – Additional safe area offset (default: `0`)

**Example:**
```javascript
scrollView.setContentInsets(
  { top: 0, right: 0, bottom: 48, left: 0 },
  { animated: true, duration: 300, safearea: 34 }
);
```

### View Properties

#### `opaque` *(v2.3.0+)*

The `opaque` property for `Ti.UI.View` was removed in v2.3.0. Use `opaqueRow` on `Ti.UI.TableViewRow` instead for optimized rendering.

## Usage

### Complete Example

```javascript
import tableviewextension from 'de.marcbender.tableviewextension';

const win = Ti.UI.createWindow();
const tableView = Ti.UI.createTableView({
  data: [
    Ti.UI.createTableViewRow({ title: 'Row 1' }),
    Ti.UI.createTableViewRow({ title: 'Row 2' })
  ]
});

// Track visibility
tableView.addEventListener('rowvisible', function(e) {
  console.log(`Row ${e.index} is visible`);
});

// Load more on scroll to top
tableView.addEventListener('scroll', function(e) {
  if (e.contentOffset <= 0) {
    const newRow = Ti.UI.createTableViewRow({ title: 'New Row' });
    tableView.appendRowBeforeRow(newRow);
  }
});

win.add(tableView);
win.open();
```

## Author

Marc Bender – marc_bender@icloud.com

## License

Copyright (c) 2026 by Marc Bender
