# TableViewExtension Module

A Titanium iOS module that extends `UITableView` with advanced scrolling, row visibility tracking, and content inset management.

## Features

- **Row Visibility Tracking** – Monitor which table rows enter/leave the viewport
- **Auto-Snapping Scroll** – Snap scrolling to row boundaries for a carousel-like experience
- **Dynamic Content Insets** – Programmatically adjust table insets with animation support
- **Row Prepend** – Insert rows at the top with automatic scroll offset adjustment
- **Pan Gesture Events** – Custom pan gesture recognition on table views
- **ScrollView Extensions** – Scroll-to-bottom and inset management for scroll views

## Installation

### Local Installation (Development)

1. Build the module:
```bash
cd ios
ti build -p ios --build-only
```

2. Copy the generated ZIP from `ios/dist/de.marcbender.tableviewextension-iphone-2.2.0.zip` into your app's root folder.

3. Add the module to your `tiapp.xml`:
```xml
<modules>
  <module version="2.2.0">de.marcbender.tableviewextension</module>
</modules>
```

### Global Installation

Copy the distribution ZIP to your Titanium SDK modules folder:

- **macOS:** `~/Library/Application Support/Titanium`
- **Linux:** `~/.titanium`
- **Windows:** `C:\ProgramData\Titanium`

## Usage

### Importing the Module

```javascript
// ES6+ (recommended)
import tableviewextension from 'de.marcbender.tableviewextension';

// ES5
var tableviewextension = require('de.marcbender.tableviewextension');
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

**Use Case:** Infinite scroll / loading older items above the current view.

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

### TableView Events

#### `rowvisible`
Fired when a table row becomes visible in the viewport.

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
Fired when a table row scrolls out of the viewport.

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
  e.rowData.height = 'ti.AUTO'; // Allow dynamic height recalculation
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

### View Methods

#### `opaqueView()`
Makes a view and all its subviews opaque with clipping enabled. Useful for performance optimization.

**Example:**
```javascript
const view = Ti.UI.createView({
  layout: 'vertical',
  children: [/* ... */]
});

// Optimize rendering performance
view.opaqueView();
```

## Complete Example

```javascript
import tableviewextension from 'de.marcbender.tableviewextension';

const win = Ti.UI.createWindow({
  title: 'TableViewExtension Demo'
});

// Create table view
const tableView = Ti.UI.createTableView({
  top: 0,
  layout: 'fill'
});

// Generate sample data
const data = [];
for (let i = 1; i <= 100; i++) {
  data.push(Ti.UI.createTableViewRow({
    title: `Item ${i}`,
    hasDetail: true,
    detail: `Detail for item ${i}`
  }));
}

tableView.data = data;

// Track row visibility
tableView.addEventListener('rowvisible', function(e) {
  console.log(`Row ${e.index} visible at offset: ${e.topOffset}`);
  
  // Highlight visible rows
  e.rowData.color = '#e8f5e9';
});

tableView.addEventListener('rownotvisible', function(e) {
  e.rowData.color = null; // Reset color
});

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
| `snappingEnabled` | Boolean | Enable/disable auto-snapping behavior |
| `isLoading` | Boolean | Flag to prevent operations during async loading |
| `scrollSlow` | Boolean | Enable slower deceleration rate for smoother scrolling |
| `enableBounce` | Boolean | Enable/disable bounce effect |
| `alwaysBounceVertical` | Boolean | Always show vertical bounce |
| `directionalLockEnabled` | Boolean | Lock scrolling to one direction |
| `paginEnabled` | Boolean | Enable paging behavior |

## Requirements

- **Titanium SDK:** 13.2.0+
- **Platform:** iOS
- **Architectures:** arm64, x86_64
- **macOS Catalyst:** Supported

## Author

Marc Bender

## License

Copyright (c) 2026 by Marc Bender
