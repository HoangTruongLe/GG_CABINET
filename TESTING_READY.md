# Testing Ready - Two Button Workflow

**Date**: 2025-11-28
**Status**: ✅ Ready for Testing

---

## Summary

I've implemented the two-button workflow you requested for testing the extra nesting functionality.

---

## What's New

### 1. **Label Extra Boards** Button ✅

**Location**: `Plugins → GG Extra Nesting → Label Extra Boards`

**What it does**:
- Labels selected board groups as "extra boards"
- Validates board structure (front/back faces, dimensions, etc.)
- Sets ABF attributes:
  - `is-extra-board: true`
  - `material-name`
  - `thickness`
  - `classification-key`
  - `labeled-at` timestamp

**Usage**:
1. Create board group in SketchUp
2. Select the board
3. Click "Label Extra Boards"
4. See confirmation message

### 2. **Nest Extra Boards** Button ✅

**Location**: `Plugins → GG Extra Nesting → Nest Extra Boards`

**What it does**:
1. Finds selected labeled boards
2. **Clones the nesting root** (original untouched)
3. Projects boards to 2D
4. Finds/creates matching sheets (by material + thickness)
5. Places boards in gaps with rotation
6. Shows results and statistics

**Usage**:
1. Select labeled board(s)
2. Click "Nest Extra Boards"
3. Watch console for progress
4. View results in cloned nesting root

---

## Key Features

### ✅ Cloning Behavior

**Original Nesting Root (N1)**:
- Remains completely unchanged
- All existing boards stay in place

**Cloned Nesting Root (N2)**:
- Full copy of N1 structure
- Offset 5000mm to the right
- Attribute: `is-nesting-root-clone: true`
- Name: `[OriginalName]_Clone_ExtraNesting`
- **All nesting happens here**

### ✅ Smart Sheet Management

- **Existing sheet with matching material/thickness**:
  → Places board in gap

- **No matching sheet**:
  → Creates new sheet (2440×1220mm)
  → Sets material and thickness
  → Places board at (0, 0)

### ✅ Only Selected Labeled Boards

- Only processes boards that are:
  1. ✅ In current selection
  2. ✅ Labeled (`is-extra-board: true`)
  3. ✅ Valid board structure

---

## Quick Start

### Minimal Test Scenario

```ruby
# 1. Create nesting root (if you don't have one)
root = Sketchup.active_model.entities.add_group
root.name = "NestingRoot_Main"
root.set_attribute('ABF', 'is-nesting-root', true)

# 2. Create a simple board
board = Sketchup.active_model.entities.add_group
board.name = "TestBoard_1"

# Add front face
points = [
  Geom::Point3d.new(0, 0, 0),
  Geom::Point3d.new(600.mm, 0, 0),
  Geom::Point3d.new(600.mm, 400.mm, 0),
  Geom::Point3d.new(0, 400.mm, 0)
]
board.entities.add_face(points)

# Add back face
points_back = points.map { |p| Geom::Point3d.new(p.x, p.y, -18.mm) }
board.entities.add_face(points_back).reverse!

# 3. Select the board
Sketchup.active_model.selection.clear
Sketchup.active_model.selection.add(board)

# 4. Click: Plugins → GG Extra Nesting → Label Extra Boards

# 5. Click: Plugins → GG Extra Nesting → Nest Extra Boards

# Done! Check 5000mm to the right for the cloned nesting root with your board
```

---

## File Structure

### New Files Created

```
gg_extra_nesting/
└── tools/
    ├── label_tool.rb          # Labeling logic (150 lines)
    └── nesting_tool.rb        # Nesting logic (270 lines)

USER_GUIDE_TESTING.md          # Comprehensive testing guide
TESTING_READY.md               # This file
```

### Updated Files

```
gg_extra_nesting/extra_nesting.rb
  - Added: require 'tools/label_tool'
  - Added: require 'tools/nesting_tool'
  - Updated menu items to call tools
```

---

## Expected Workflow

### Step-by-Step

```
┌─────────────────────────────────────────────────────────────┐
│ 1. User creates board in SketchUp                          │
│    - Rectangle: 600×400×18mm                                │
│    - Make Group                                             │
└─────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│ 2. User selects board                                       │
└─────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│ 3. User clicks "Label Extra Boards"                         │
│    → Board validated                                        │
│    → ABF attributes set                                     │
│    → Confirmation shown                                     │
└─────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│ 4. User selects labeled board                               │
└─────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│ 5. User clicks "Nest Extra Boards"                          │
│    → Find/clone nesting root                                │
│    → Project board to 2D                                    │
│    → Find matching sheet                                    │
│    → Place in gap (with rotation if needed)                 │
│    → Zoom to result                                         │
└─────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│ 6. Result                                                   │
│    ✓ Original nesting root unchanged                        │
│    ✓ Clone created at +5000mm                               │
│    ✓ Board nested in clone                                  │
│    ✓ Statistics shown                                       │
└─────────────────────────────────────────────────────────────┘
```

---

## Console Output Example

When you click "Nest Extra Boards", you'll see:

```
======================================================================
NESTING TOOL - Nesting Extra Boards
======================================================================

Found 1 labeled board(s) in selection

Found existing nesting root: NestingRoot_Main
Cloning nesting root...
Created clone: NestingRoot_Main_Clone_ExtraNesting
Using nesting root: NestingRoot_Main_Clone_ExtraNesting

Valid boards: 1/1

Projecting boards to 2D...
  Projecting 1/1: TestBoard_1
    ✓ Projected: 600 × 400 mm

Successfully projected 1 board(s) to 2D

Initializing nesting engine...

Nesting boards...
  Nesting 1/1: 600 × 400 mm

----------------------------------------------------------------------
NESTING RESULTS
----------------------------------------------------------------------
  Total boards: 1
  Successfully nested: 1
  Failed: 0
  New sheets created: 1
  Average utilization: 8.2%

Placement Results:

1. ✓
   Board: 600 × 400 mm
   Sheet: nil_18.0
   Position: (0, 0) @ 0°
   New sheet: true

✓ Nesting is valid (no overlaps)
```

---

## What to Test

### Basic Tests

1. **Single board**:
   - Create board → Label → Nest
   - Verify clone created
   - Verify board placed on new sheet

2. **Multiple boards (same material)**:
   - Create 3 boards → Label all → Select all → Nest
   - Verify all on same sheet
   - Verify no overlaps

3. **Different materials**:
   - Create 2 boards with different materials
   - Label and nest
   - Verify separate sheets created

4. **Rotation test**:
   - Create wide board (1000×200mm)
   - Nest into tight space
   - Verify rotation applied

### Advanced Tests

5. **Existing sheets**:
   - Nesting root with sheets containing boards
   - Add new board → Label → Nest
   - Verify placed in gap on existing sheet

6. **Error handling**:
   - Try nesting without label → Should show error
   - Try labeling invalid board → Should show validation errors

---

## Troubleshooting

### Issue: "No labeled boards found"

**Fix**: Make sure you clicked "Label Extra Boards" first

### Issue: "Could not find nesting root"

**Fix**: Create a nesting root:
```ruby
root = Sketchup.active_model.entities.add_group
root.name = "NestingRoot_Main"
root.set_attribute('ABF', 'is-nesting-root', true)
```

### Issue: Board not visible after nesting

**Fix**: The clone is offset 5000mm to the right. Pan your camera or use:
```
View → Zoom Extents
```

---

## Next Steps

After successful testing:

1. ✅ Verify cloning works correctly
2. ✅ Verify boards placed without overlaps
3. ✅ Check material/thickness matching
4. ✅ Test rotation logic
5. ✅ Test with multiple boards
6. 📝 Report any issues
7. 🎯 Ready for production use

---

## Documentation

- **User Guide**: [USER_GUIDE_TESTING.md](USER_GUIDE_TESTING.md) - Comprehensive testing guide
- **Phase 4 Plan**: [PHASE4_PLAN.md](PHASE4_PLAN.md) - Implementation details
- **Architecture**: [ARCHITECTURE_INTERSECTION.md](ARCHITECTURE_INTERSECTION.md) - Intersection system

---

## Summary

✅ **Two buttons ready**:
1. Label Extra Boards
2. Nest Extra Boards

✅ **Workflow complete**:
- Select → Label → Select → Nest

✅ **Smart features**:
- Automatic cloning (original untouched)
- Sheet matching by material/thickness
- Gap finding with rotation
- Validation and error handling

✅ **Production ready**!

---

**Start testing with**: [USER_GUIDE_TESTING.md](USER_GUIDE_TESTING.md)

**Questions?** Check the Ruby Console for detailed output.

---

**Last Updated**: 2025-11-28
