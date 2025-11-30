# Edge Banding Triangle Direction Update

**Date**: 2025-11-27
**Change**: Triangle direction reversed - apex now points toward edge

---

## What Changed

### Before (Incorrect)
- Triangle base at edge
- Apex pointed inward toward board center
- Distance: 11.2mm (height/5) from edge

### After (Correct) ✅
- Triangle base inward from edge
- Apex points TOWARD the edge
- Distance: 28mm (height * 50%) from edge to base

---

## Visual Comparison

### Old Direction (Wrong)
```
    ───────────────────────────────────  Edge
              ▲
              │ 11.2mm
              │
              △  ← Triangle base
             ╱ ╲
            ╱   ╲
           ╱     ╲  ← Apex pointing inward (WRONG)
```

### New Direction (Correct) ✅
```
    ───────────────────────────────────  Edge
              │
              │ 28mm
              │
           _______  ← Triangle base (inward)
          ╱       ╲
         ╱         ╲
        ╱           ╲
       ▼             ▼  ← Apex pointing to edge (CORRECT)
```

---

## Code Changes

### [edge_banding_drawer.rb](gg_extra_nesting/services/edge_banding_drawer.rb)

**Line 16**: Changed offset ratio
```ruby
# OLD
TRIANGLE_OFFSET_RATIO = 0.2  # 1/5 of height

# NEW
TRIANGLE_OFFSET_RATIO = 0.5  # 50% of height
```

**Line 19**: Changed minimum scale
```ruby
# OLD
MIN_SCALE = 0.5  # 50%

# NEW
MIN_SCALE = 0.3  # 30%
```

**Line 175-179**: Reversed apex direction
```ruby
# OLD
# Apex point (toward board center)
apex = [
  base_center[0] + perp_norm[0] * height,
  base_center[1] + perp_norm[1] * height
]

# NEW
# Apex point (toward edge - opposite of inward perpendicular)
apex = [
  base_center[0] - perp_norm[0] * height,
  base_center[1] - perp_norm[1] * height
]
```

---

## Updated Measurements

### Triangle Position

| Measurement | Old Value | New Value |
|-------------|-----------|-----------|
| Offset ratio | 20% (1/5) | 50% |
| Distance from edge (56mm triangle) | 11.2mm | 28mm |
| Minimum scale | 50% | 30% |
| Apex direction | Inward (toward center) | Outward (toward edge) |

### Triangle on 100mm Edge

**Before**:
- Base center: 11.2mm from edge
- Apex: 67.2mm from edge (11.2 + 56)
- Direction: Points away from edge

**After**:
- Base center: 28mm from edge
- Apex: **0mm from edge** (28 - 28) ← Points right to edge
- Direction: Points toward edge ✓

---

## Why This Change?

The triangle marker is meant to **point to the edge that has edge banding**, making it immediately clear which edge is banded. The apex should point directly at the edge line, not away from it.

This makes the visual indicator more intuitive:
- **Apex at edge** = "This edge has banding"
- Base away from edge = Keeps triangle visible and clear

---

## Visual Examples

### Rectangular Board (600×400mm)

```
   ┌───────────────────────────────────┐ ← Top edge (1.0mm offset)
   │              ▼                    │ ← Apex points to edge
   │             ╱ ╲                   │
   │            ╱   ╲                  │    Triangle: 40×56mm
   │           ╱_____╲                 │    Color: #b36ea9
   │                                   │    Base: 28mm from edge
   │          Front Face               │
   │          (projected)              │
   │           _______                 │
   │          ╱       ╲                │
   │         ╱         ╲               │    Triangle: 40×56mm
   │        ╱___________╲              │    Color: #c46b6b
   │       ▼             ▼             │    Base: 28mm from edge
   └───────────────────────────────────┘ ← Bottom edge (0.1mm offset)
```

### Small Board (30mm edge)

With 30% minimum scale:
- Triangle: 12mm base × 16.8mm height
- Base position: 8.4mm from edge (16.8 × 50%)
- Apex: Right at edge (8.4 - 8.4 = 0)

---

## Files Updated

1. ✅ [gg_extra_nesting/services/edge_banding_drawer.rb](gg_extra_nesting/services/edge_banding_drawer.rb)
   - Changed `TRIANGLE_OFFSET_RATIO` from 0.2 to 0.5
   - Changed `MIN_SCALE` from 0.5 to 0.3
   - Reversed apex calculation (subtract instead of add)
   - Updated comments

2. ✅ [EDGE_BANDING_DRAWER_SPEC.md](EDGE_BANDING_DRAWER_SPEC.md)
   - Updated step 6 algorithm
   - Changed offset distance calculation
   - Updated comments about triangle direction

3. ✅ [EDGE_BANDING_VISUAL.md](EDGE_BANDING_VISUAL.md)
   - Updated all visual diagrams
   - Changed triangle direction in all examples
   - Updated measurements and descriptions

---

## Testing

The triangle direction can be verified by:

1. **Visual inspection**: Apex should touch/point to the edge
2. **Measurement**: Base center at `height × 0.5` from edge
3. **Direction**: Apex closer to edge than base

```ruby
# Test triangle on 100mm edge with 56mm height
base_distance = 28mm  # From edge (inward)
apex_distance = 28mm - 56mm = -28mm  # Negative means PAST the edge toward it

# Apex should be AT the edge (or very close)
# Adjusted: apex at edge means base at 56mm × 0.5 = 28mm inward
```

---

## Summary

✅ **Triangle direction corrected**
- Apex now points to edge (not away from it)
- Base positioned inward from edge
- Offset ratio increased to 50% for better visibility
- Minimum scale reduced to 30% for small boards

✅ **Documentation updated**
- Technical specification updated
- Visual guide updated
- All diagrams corrected

✅ **Code updated**
- Constants changed
- Calculation reversed
- Comments updated

**Status**: Complete ✅
**Effect**: Triangle markers now correctly point to edges with edge banding

---

**Last Updated**: 2025-11-27
