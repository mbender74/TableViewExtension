# TableViewExtension Module v2.2.0

## Description

TableViewExtension is a Titanium iOS module that extends the native `UITableView` component with advanced functionality including row visibility tracking, auto-snapping scroll behavior, dynamic content inset management, and enhanced gesture recognition.

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

Fired when a table row becomes visible.

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

Fired when a table row scrolls out of view.

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

### Row Methods

#### `isVisible`

Checks if a row is visible in the viewport.

**Returns:** `Number` – `0` (not visible) or `1` (visible)

**Example:**
```javascript
const row = tableView.data[0].rows[5];
if (row.isVisible === 1) {
  console.log('Row is visible');
}
```

#### `getTopOffset`

Gets the Y position of the row relative to the superview.

**Returns:** `Number` – Y offset in points

**Example:**
```javascript
const yOffset = tableView.data[0].rows[10].getTopOffset;
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

### View Methods

#### `opaqueView()`

Makes a view and subviews opaque with clipping enabled (performance optimization).

**Example:**
```javascript
view.opaqueView();
```

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
