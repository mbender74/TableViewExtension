# ProMotion 120Hz Optimierungsplan für TableViewExtension

## Status Quo
Alle Timing-Konstanten sind auf 60Hz/30fps hardcoded. Kein ProMotion-Support.

## Optimierungen

### 1. Adaptive Throttle-Intervalle (HIGH PRIORITY)
**Problem:** `0.032s` (30fps) hardcoded — auf 120Hz-Displays verschwenden wir die doppelte Frame-Rate.

**Lösung:** 
- ProMotion-Fähigkeit erkennen via `CADisplayLink` oder `UITraitCollection`
- Throttle auf `0.016s` (60fps) bei 120Hz-Displays reduzieren
- Bei 60Hz-Displays bleibt `0.032s` (30fps) — kein Overhead

**Betroffene Dateien:**
- `TiUITableView+SmoothScrolling.m` — scroll processing throttle
- `TiUITableView+Snappy.m` — rowvisible/rownotvisible throttle

### 2. FPS-Sample-Window anpassen (MEDIUM PRIORITY)
**Problem:** 60 Samples bei 120Hz = nur 0.5s Abdeckung → instabiler FPS-Durchschnitt

**Lösung:**
- Bei 120Hz: Window auf 120 erhöhen (oder dynamisch anpassen)
- Timestamp-Array dynamisch allozieren oder vergrößern

### 3. Animation-Durations frame-alignen (LOW PRIORITY)
**Problem:** 180ms und 211ms sind nicht frame-aligned → subtile Ruckler

**Lösung:**
- 180ms → 167ms (12 frames @ 120Hz, 10 frames @ 60Hz)
- 211ms → 200ms (15 frames @ 120Hz, 12 frames @ 60Hz)
- Oder: Duration via `CADisplayLink.duration` dynamisch berechnen

### 4. Velocity-Tracking anpassen (LOW PRIORITY)  
**Problem:** Alle 3 Frames bei 120Hz = alle 16ms → unnötig häufig

**Lösung:**
- Bei 120Hz: alle 6 Frames (≈32ms)
- Bei 60Hz: alle 3 Frames (≈50ms) — bleibt gleich

### 5. CADisplayLink preferredFrameRateRange (NICE-TO-HAVE)
**Problem:** Core Animation bekommt keine Hinweise, dass Scrollen High-Impact ist

**Lösung:**
- Während aktiven Scrollens: `CAFrameRateRange(min:80, max:120, preferred:120)`
- Nach Scroll-Ende: auf Default zurück — Power-Saving

### 6. Info.plist Key (für consuming Apps)
**Problem:** Ohne `CADisableMinimumFrameDurationOnPhone` bleibt iPhone auf ~60Hz

**Lösung:**
- In README dokumentieren
- Optional: Module könnte den Key selbst setzen (via tiapp.xml merge)

## Implementierungs-Reihenfolge
1. ✅ Adaptive Throttle (größter Effekt)
2. ✅ FPS-Window anpassen  
3. ✅ Animation-Durations
4. ✅ Velocity-Tracking
5. ✅ CADisplayLink hints
6. ✅ README update

## Apple ProMotion Doku
https://developer.apple.com/documentation/quartzcore/optimizing-iphone-and-ipad-apps-to-support-promotion-displays
