# Plan: Super Weiches Scrolling für Ti.UI.TableView

## Ziel

Ti.UI.TableView im TableViewExtension-Modul so erweitern, dass **butterweiches 60/120fps Scrolling** erreicht wird, selbst bei großen Datenmengen und komplexen Zellen.

---

## Bestehende Funktionalität (erhalten!)

Diese Features sind aktuell und müssen **unverändert** weiterarbeiten:

| Feature | Datei | Methode/Event |
|---------|-------|---------------|
| Row Visibility Tracking | TiUITableView+Snappy.m | `rowvisible`, `rownotvisible` Events |
| Auto-Snapping | TiUITableView+Snappy.m | `autoSnappping:` |
| Content Insets | TiUITableView+Snappy.m | `setContentInset:withObject:` |
| Row Prepend | TiUITableView+Snappy.m | `appendRowBeforeRow:` |
| Pan Gesture | TiUITableView+Snappy.m | `handlePanGesture:`, `pan`/`panend` Events |
| Scroll Slow/Bounce | TiUITableView+Snappy.m | `setScrollSlow_`, `setEnableBounce_` |
| Row Properties | TiUITableViewRowProxy+WithVisibility.m | `isVisible`, `getTopOffset`, `setSubView` |
| ScrollView Extensions | TiUIScrollView+Extended.m | `scrollToBottomNoAnim`, `setContentInsets_` |
| Cell Reuse Logging | TiUITableViewCell+WithReuse.m | Method Swizzling `prepareForReuse` |

---

## Analyse: Aktuelle Probleme im Titanium SDK

### 1. Row-Height Berechnung pro Zelle
**Problem:** `tableView:heightForRowAtIndexPath:` wird für **jede** Zelle aufgerufen und berechnet die Höhe synchron auf dem Main-Thread.

```objc
// TiUITableView.m:2703-2708
- (CGFloat)tableView:(UITableView *)ourTableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    TiUITableViewRowProxy *row = [self rowForIndexPath:index];
    CGFloat width = [row sizeWidthForDecorations:[self computeRowWidth] forceResizing:YES];
    CGFloat height = [row rowHeight:width];  // ← Teuer! Auto-Layout + forceResizing
    height = [self tableRowHeight:height];
    return height < 1 ? tableview.rowHeight : height;
}
```

**Folge:** Bei 100+ Zellen mit `height: Ti.UI.SIZE` wird die Höhe 100× berechnet → ruckelig.

### 2. Geschaltete estimatedRowHeight
**Problem:** `estimatedRowHeight = 0` deaktiviert iOS Self-Sizing Optimierungen.

```objc
// TiUITableView.m:448-450
tableview.estimatedRowHeight = 0;
tableview.estimatedSectionFooterHeight = 0;
tableview.estimatedSectionHeaderHeight = 0;
```

**Folge:** UITableView muss alle Höhen vor dem Scrollen kennen → kein Lazy Layout.

### 3. Kein Row-Height Caching
**Problem:** Jede `heightForRowAtIndexPath:` Anfrage berechnet neu, auch wenn sich die Row nicht geändert hat.

### 4. Cell-Erstellung auf Main-Thread
**Problem:** `triggerAttach` und `cellForRowAtIndexPath` arbeiten synchron.

```objc
// TiUITableView.m:2132
[row triggerAttach];  // ← Blockiert Main-Thread
```

### 5. Keine Prefetching-Unterstützung
**Problem:** iOS Prefetching API (`tableView:cellForRowAtIndexPath:` + `tableView:prefetchRowsAtIndexPaths:`) wird nicht genutzt.

---

## Strategie: 4-Stufen-Plan

### Stufe 1: Row-Height Caching (hohe Priorität)

**Was:** Berechne Zellhöhen einmal und cache sie.

**Implementierung:**

```objc
// TiUITableView+SmoothScrolling.h
@interface TiUITableView (SmoothScrolling)
- (void)enableHeightCaching;
- (void)invalidateHeightCache;
- (void)invalidateHeightCacheForIndex:(NSIndexPath *)indexPath;
@end

// TiUITableView+SmoothScrolling.m
static NSCache<NSString *, NSNumber *> *heightCache;

- (void)enableHeightCaching
{
    if (heightCache == nil) {
        heightCache = [[NSCache alloc] init];
        heightCache.countLimit = 500;
        heightCache.totalCostLimit = 10 * 1024 * 1024; // 10MB
    }
}

- (CGFloat)cachedHeightForRow:(TiUITableViewRowProxy *)row
{
    NSString *key = [NSString stringWithFormat:@"%ld-%@", 
                     (long)row.row, row.height];
    NSNumber *cached = [heightCache objectForKey:key];
    if (cached) {
        return cached.floatValue;
    }
    
    CGFloat width = [row sizeWidthForDecorations:[self computeRowWidth] forceResizing:YES];
    CGFloat height = [row rowHeight:width];
    [heightCache setObject:@(height) forKey:key];
    return height;
}
```

**API für JavaScript:**
```javascript
tableView.enableHeightCaching = true;  // Aktiviert Caching
tableView.invalidateHeightCache();     // Cache leeren nach Datenänderung
```

**Erwarteter Gewinn:** 40-60% weniger Height-Berechnungen beim Scrollen.

---

### Stufe 2: Estimated Row Height mit Smart Fallback

**Was:** Nutze iOS Self-Sizing für variable Höhen, aber mit Fallback zu exakter Berechnung.

**Implementierung:**

```objc
// TiUITableView+SmoothScrolling.m
- (void)enableEstimatedHeights
{
    // Read estimatedRowHeight from proxy or use default
    CGFloat estimated = [TiUtils floatValue:[self.proxy valueForUndefinedKey:@"estimatedRowHeight"] def:80];
    
    if (estimated > 0) {
        tableview.estimatedRowHeight = estimated;
        tableview.estimatedSectionHeaderHeight = estimated * 0.5;
        tableview.estimatedSectionFooterHeight = estimated * 0.3;
        
        // Use automatic dimension for rows with Ti.UI.SIZE
        tableview.rowHeight = UITableViewAutomaticDimension;
    }
}

- (CGFloat)tableView:(UITableView *)ourTableView 
    estimatedHeightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    TiUITableViewRowProxy *row = [self rowForIndexPath:indexPath];
    
    // If row has fixed height, return it directly
    id heightValue = [row valueForUndefinedKey:@"height"];
    if (heightValue && ![heightValue isEqual:@"SIZE"]) {
        return [TiUtils floatValue:heightValue];
    }
    
    // Return estimated height for dynamic rows
    return [self.proxy valueForUndefinedKey:@"estimatedRowHeight"]?.floatValue ?: 80;
}
```

**API für JavaScript:**
```javascript
const tableView = Ti.UI.createTableView({
    estimatedRowHeight: 80,  // Schätzwert für Zellenhöhe
    data: rows
});
```

**Erwarteter Gewinn:** Lazy Layout → Zellen werden erst berechnet wenn sichtbar.

---

### Stufe 3: Background Row Preparation

**Was:** Vorbereite Zellen im Hintergrund bevor sie sichtbar werden.

**Implementierung:**

```objc
// TiUITableView+SmoothScrolling.h
@interface TiUITableView (SmoothScrolling)
- (void)prepareRowsBeforeIndex:(NSIndexPath *)startIndex 
                       count:(NSInteger)count 
               completion:(void(^)(BOOL finished))completion;
@end

// TiUITableView+SmoothScrolling.m
- (void)prepareRowsAsyncForIndexPaths:(NSArray<NSIndexPath *> *)indexPaths
{
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0);
    
    for (NSIndexPath *indexPath in indexPaths) {
        dispatch_async(queue, ^{
            TiUITableViewRowProxy *row = [self rowForIndexPath:indexPath];
            
            // Pre-calculate height
            CGFloat width = [row sizeWidthForDecorations:[self computeRowWidth] forceResizing:NO];
            CGFloat height = [row rowHeight:width];
            
            // Cache the result
            NSString *key = [NSString stringWithFormat:@"%ld", (long)indexPath.row];
            dispatch_sync(dispatch_get_main_queue(), ^{
                [heightCache setObject:@(height) forKey:key];
            });
        });
    }
}

// Hook into iOS prefetching
- (void)tableView:(UITableView *)ourTableView 
    prefetchRowsAtIndexPaths:(NSArray<NSIndexPath *> *)indexPaths
{
    [self prepareRowsAsyncForIndexPaths:indexPaths];
}
```

**API für JavaScript:**
```javascript
tableView.prefetchEnabled = true;  // Aktiviert Prefetching
```

**Erwarteter Gewinn:** Height-Berechnung happens before cell is visible → null jank.

---

### Stufe 4: Cell Reuse Optimierung

**Was:** Verbessere Cell-Reuse mit schnellerem Cleanup und Pool-Management.

**Implementierung:**

```objc
// TiUITableViewCell+SmoothReuse.h
@interface TiUITableViewCell (SmoothReuse)
- (void)quickPrepareForReuse;
@end

// TiUITableViewCell+SmoothReuse.m
- (void)quickPrepareForReuse
{
    // Fast path: only detach essential views
    id rowContainer = [self valueForKey:@"rowContainerView"];
    if (rowContainer) {
        // Remove from superview without animation
        [rowContainer removeFromSuperview];
    }
    
    // Clear image caches
    UIImageView *imageView = [self.imageView isKindOfClass:[TiUIImageView class]] 
        ? self.imageView : nil;
    if (imageView) {
        [imageView setImage:nil];
    }
    
    // Reset transforms
    self.layer.transform = CATransform3DIdentity;
}

// Cell pool for high-frequency reuse
static NSMapTable<NSString *, NSPointerArray *> *cellPool;

- (UITableViewCell *)tableView:(UITableView *)ourTableView 
    cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    TiUITableViewRowProxy *row = [self rowForIndexPath:indexPath];
    
    // Try pool first
    NSPointerArray *pool = [cellPool objectForKey:row.tableClass];
    UITableViewCell *cell = nil;
    if (pool && [pool count] > 0) {
        cell = [pool removeLastObject];
    }
    
    if (cell == nil) {
        cell = [ourTableView dequeueReusableCellWithIdentifier:row.tableClass];
    }
    
    // ... rest of cell configuration
    return cell;
}
```

**API für JavaScript:**
```javascript
const tableView = Ti.UI.createTableView({
    cellPoolSize: 20,  // Maximale gepoolte Zellen pro Klasse
    fastReuse: true     // Aktiviert optimiertes Reuse
});
```

**Erwarteter Gewinn:** Weniger Allokationen, schnellere Cell-Wiederverwendung.

---

## Integrations-Strategie (ohne Breaking Changes)

### Prinzipien

1. **Opt-in:** Alle neuen Features sind standardmäßig `false`/`0` → kein Verhaltenswechsel
2. **Kategorie-Overlay:** Neue Methoden in separater Kategorie `SmoothScrolling` → kein Eingriff in `Snappy`
3. **Fallback-Logik:** Wenn Caching aktiv, aber Row sich ändert → Cache automatisch invalidieren
4. **Kompatibilität:** Bestehende Events (`rowvisible`, `rownotvisible`, `pan`, `panend`) unverändert feuern

### So wird integriert

```
Bestand:
  TiUITableView (Snappy)  ← bleibt unverändert
  TiUITableViewProxy (Snappy)  ← bleibt unverändert
  
Neu:
  TiUITableView (SmoothScrolling)  ← fügt Caching/Prefetch hinzu
  TiUITableViewProxy (SmoothScrolling)  ← JavaScript API
  
Zusammenarbeit:
  - Snappy setzt Content Insets → Cache wird NICHT invalidiert (Höhen ändern sich nicht)
  - Snappy appendRowBeforeRow → Cache wird automatisch invalidiert (neue Row)
  - Snappy rowvisible Event → wird weiterhin gefeuert, zusätzlich Cache-Hit geloggt
```

---

## Architektur-Übersicht

```
┌─────────────────────────────────────────────┐
│  JavaScript Layer                            │
│  tableView = Ti.UI.createTableView({         │
│      enableHeightCaching: true,              │
│      estimatedRowHeight: 80,                 │
│      prefetchEnabled: true,                  │
│      cellPoolSize: 20                        │
│  })                                          │
└──────────────────┬──────────────────────────┘
                   │
┌──────────────────▼──────────────────────────┐
│  TiUITableViewProxy (Snappy)                 │
│  - setContentInsets                          │
│  - appendRowBeforeRow                        │
│  - setEstimatedRowHeight ← NEU               │
│  - enableHeightCaching ← NEU                 │
└──────────────────┬──────────────────────────┘
                   │
┌──────────────────▼──────────────────────────┐
│  TiUITableView (SmoothScrolling) ← NEU       │
│  ┌─────────────┐  ┌────────────────────┐   │
│  │ Height Cache│  │ Estimated Heights  │   │
│  │ (NSCache)   │  │ (iOS Self-Sizing)  │   │
│  └─────────────┘  └────────────────────┘   │
│  ┌─────────────┐  ┌────────────────────┐   │
│  │ Async Prep  │  │ Cell Pool Manager  │   │
│  │ (Prefetch)  │  │ (NSMapTable)       │   │
│  └─────────────┘  └────────────────────┘   │
└─────────────────────────────────────────────┘
```

---

## Neue Dateien

```
ios/Classes/
├── TiUITableView+SmoothScrolling.h          ← Haupt-Erweiterung
├── TiUITableView+SmoothScrolling.m
├── TiUITableViewProxy+SmoothScrolling.h     ← Proxy-Ebene
├── TiUITableViewProxy+SmoothScrolling.m
├── TiUITableViewCell+SmoothReuse.h          ← Cell-Pool
└── TiUITableViewCell+SmoothReuse.m
```

---

## API-Spezifikation (JavaScript)

### TableView Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `enableHeightCaching` | Boolean | `false` | Aktiviert Row-Height Caching |
| `estimatedRowHeight` | Number | `0` | Geschätzte Zellhöhe für Self-Sizing |
| `prefetchEnabled` | Boolean | `false` | Aktiviert Hintergrund-Vorbereitung |
| `cellPoolSize` | Number | `0` | Max. gepoolte Zellen pro Klasse |
| `fastReuse` | Boolean | `false` | Optimierter Cell-Reuse |
| `smoothScrolling` | Boolean | `false` | Alias: aktiviert ALLE Optimierungen |

### TableView Methods

| Method | Description |
|--------|-------------|
| `invalidateHeightCache()` | Leert den Height-Cache |
| `invalidateHeightCacheForRow(section, index)` | Leert Cache für spezifische Row |
| `getCacheStats()` | Liefert Cache-Statistiken |

### Beispiel

```javascript
// Quick setup - alles auf einmal
const tableView = Ti.UI.createTableView({
    smoothScrolling: true,
    estimatedRowHeight: 100,
    data: rows
});

// Oder individuell
const tableView = Ti.UI.createTableView({
    enableHeightCaching: true,
    prefetchEnabled: true,
    cellPoolSize: 30,
    data: rows
});

// Cache nach Datenänderung leeren
tableView.data = newData;
tableView.invalidateHeightCache();

// Monitoring
const stats = tableView.getCacheStats();
console.log(`Cache hits: ${stats.hits}, misses: ${stats.misses}`);
```

---

## Implementierungs-Reihenfolge

| Phase | Feature | Aufwand | Impact |
|-------|---------|---------|--------|
| **1** | Height Caching | 2h | ⭐⭐⭐⭐⭐ |
| **2** | Estimated Heights | 1h | ⭐⭐⭐⭐ |
| **3** | Cell Pool | 2h | ⭐⭐⭐ |
| **4** | Async Prefetch | 3h | ⭐⭐⭐⭐ |
| **5** | API + Docs | 2h | ⭐⭐⭐⭐⭐ |

**Gesamtgeschätzter Aufwand:** ~10 Stunden

---

## Testing

### Performance Benchmarks

```javascript
// Test: 1000 Rows mit variablen Höhen
const start = Date.now();
const tableView = Ti.UI.createTableView({
    smoothScrolling: true,
    data: generateRows(1000)
});
const initTime = Date.now() - start;

// Scroll-Performance messen
let frameCount = 0;
tableView.addEventListener('scroll', () => frameCount++);

// Nach 5 Sekunden: FPS = frameCount / 5
```

### Test-Szenarien

1. **Statische Höhen:** 500 Rows, feste Höhe → Cache Hit Rate > 95%
2. **Variable Höhen:** 200 Rows, `Ti.UI.SIZE` → Estimated Height Fallback
3. **Mixed Content:** Images + Text → Async Prefetch
4. **Infinite Scroll:** appendRowBeforeRow → Cache Invalidation
5. **Memory:** 1000+ Rows → Cache Eviction

---

## Risiken & Fallbacks

| Risiko | Fallback |
|--------|----------|
| Cache Memory Leak | `NSCache` mit `totalCostLimit` |
| Height-Inkonsistenzen | `invalidateHeightCache()` nach Datenänderung |
| Estimated Height Jump | Fallback zu exakter Berechnung bei Abweichung > 20% |
| Race Conditions | `dispatch_sync` für Main-Thread Updates |

---

## Next Steps

1. [ ] `TiUITableView+SmoothScrolling.h/m` erstellen
2. [ ] Height Caching implementieren
3. [ ] Estimated Row Height Support hinzufügen
4. [ ] Cell Pool Manager bauen
5. [ ] JavaScript API in Proxy einbinden
6. [ ] Performance Tests durchführen
7. [ ] README aktualisieren
