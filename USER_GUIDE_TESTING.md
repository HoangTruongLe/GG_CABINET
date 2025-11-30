# User Guide - Testing Extra Nesting Workflow

**Date**: 2025-11-28
**Version**: 0.1.0-dev

---

## Overview

This guide explains how to test the complete extra nesting workflow using the two new buttons:

1. **Label Extra Boards** - Labels selected boards as extra boards
2. **Nest Extra Boards** - Nests selected labeled boards into a cloned nesting root

---

## Prerequisites

### Required Setup

1. ✅ Plugin installed in SketchUp Plugins folder
2. ✅ SketchUp model with existing nesting root (has `ABF > is-nesting-root: true`)
3. ✅ One or more board groups ready to be labeled and nested

### Recommended Test Model Setup

Create a simple test model:

```
Model entities:
├── NestingRoot (Group with is-nesting-root: true)
│   └── Sheet_1 (Group with is-sheet: true)
│       └── [Existing nested boards...]
│
└── ExtraBoard_1 (Group - your new board to nest)
    ├── Front face
    ├── Back face
    └── Side faces
```

---

## Step-by-Step Workflow

### Step 1: Create a Board

1. In SketchUp, create a rectangular board:
   ```
   Dimensions: e.g., 600mm × 400mm × 18mm
   ```

2. Make it a group:
   - Select all faces
   - Right-click → Make Group
   - Name it: `ExtraBoard_1`

3. Apply material (optional but recommended):
   - Right-click group → Entity Info
   - Set Material: e.g., "Oak Veneer"

4. Set board properties:
   - Window → Ruby Console
   - Run:
   ```ruby
   board = Sketchup.active_model.selection.first
   board.set_attribute('ABF', 'is-board', true)
   ```

### Step 2: Label the Board

1. **Select the board**:
   - Click on the board group to select it
   - You can select multiple boards at once

2. **Click menu button**:
   ```
   Plugins → GG Extra Nesting → Label Extra Boards
   ```

3. **Check console output**:
   ```
   ======================================================================
   LABEL TOOL - Labeling Extra Boards
   ======================================================================

   Processing 1/1: ExtraBoard_1
     ✓ Labeled successfully
       Material: Oak Veneer
       Thickness: 18.0 mm
       Size: 600 × 400 mm

   ----------------------------------------------------------------------
   LABELING SUMMARY
   ----------------------------------------------------------------------
     Total selected: 1
     Labeled: 1
     Skipped: 0
     Errors: 0
   ```

4. **Verify label**:
   - Right-click board → Entity Info → Advanced Attributes
   - Check for:
     - `ABF > is-extra-board: true`
     - `ABF > material-name: Oak Veneer`
     - `ABF > thickness: 18.0`
     - `ABF > labeled-at: 2025-11-28...`

### Step 3: Nest the Labeled Board

1. **Select the labeled board**:
   - Click on the board group
   - You can select multiple labeled boards

2. **Click menu button**:
   ```
   Plugins → GG Extra Nesting → Nest Extra Boards
   ```

3. **Watch the console**:
   ```
   ======================================================================
   NESTING TOOL - Nesting Extra Boards
   ======================================================================

   Found 1 labeled board(s) in selection

   Found existing nesting root: NestingRoot_Main
   Cloning nesting root...
   Created clone: NestingRoot_Main_Clone_ExtraNesting

   Projecting boards to 2D...
     Projecting 1/1: ExtraBoard_1
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

   ✓ Nesting is valid (no overlaps)
   ```

4. **Check the result**:
   - Camera should zoom to the cloned nesting root
   - The cloned root is offset 5000mm to the right
   - Your board should be placed on a new sheet

---

## What Happens Behind the Scenes

### Workflow Overview

```
User selects board → Label → Nest
                       │       │
                       │       ├─→ Clone nesting root
                       │       ├─→ Project board to 2D
                       │       ├─→ Find/create matching sheet
                       │       ├─→ Find gap in sheet
                       │       ├─→ Place board at position
                       │       └─→ Update SketchUp model
                       │
                       └─→ Set ABF attributes
```

### Cloning Behavior

**Original Nesting Root (N1)**:
- Remains unchanged
- Located at original position

**Cloned Nesting Root (N2)**:
- Complete copy of N1
- Offset 5000mm to the right
- Marked with `ABF > is-nesting-root-clone: true`
- All new boards nested here

### Sheet Creation

**If matching sheet exists**:
- Uses existing sheet (same material + thickness)
- Finds gap in sheet
- Places board in gap

**If no matching sheet**:
- Creates new sheet (2440mm × 1220mm)
- Sets material and thickness to match board
- Places board at position (0, 0)

---

## Testing Scenarios

### Scenario 1: Single Board, Empty Nesting Root

**Setup**:
1. Create nesting root (empty)
2. Create one board (600×400×18mm, Oak Veneer)

**Expected**:
- ✅ Board labeled successfully
- ✅ Nesting root cloned
- ✅ New sheet created (Oak Veneer, 18mm)
- ✅ Board placed at (0, 0)
- ✅ Utilization: ~8%

### Scenario 2: Multiple Boards, Same Material

**Setup**:
1. Create 3 boards:
   - Board A: 600×400×18mm, Oak Veneer
   - Board B: 500×300×18mm, Oak Veneer
   - Board C: 400×300×18mm, Oak Veneer

**Expected**:
- ✅ All 3 boards labeled
- ✅ All placed on same sheet (matching material)
- ✅ Boards arranged without overlaps
- ✅ Utilization: ~20-30%

### Scenario 3: Different Materials

**Setup**:
1. Create 2 boards:
   - Board A: 600×400×18mm, Oak Veneer
   - Board B: 600×400×18mm, Maple Veneer

**Expected**:
- ✅ Both labeled
- ✅ 2 new sheets created (one per material)
- ✅ Each board on its own sheet

### Scenario 4: Rotation Required

**Setup**:
1. Create wide board: 1000×200×18mm
2. Existing sheet has gap 300×1100mm

**Expected**:
- ✅ Board rotated 90° to fit
- ✅ Placed in gap successfully
- ✅ Result shows rotation: 90°

### Scenario 5: Existing Sheets with Boards

**Setup**:
1. Nesting root with sheets containing boards
2. Add new board matching existing material

**Expected**:
- ✅ Nesting root cloned (including existing boards)
- ✅ New board placed in gap on existing sheet
- ✅ No overlaps with existing boards

---

## Verification Checklist

After nesting, verify:

### ✅ Clone Created
- [ ] Cloned nesting root exists
- [ ] Name: `[OriginalName]_Clone_ExtraNesting`
- [ ] Offset 5000mm to the right
- [ ] Has attribute: `is-nesting-root-clone: true`

### ✅ Sheet Created/Used
- [ ] Sheet exists with correct material
- [ ] Sheet has correct thickness
- [ ] Sheet is inside cloned nesting root

### ✅ Board Placed
- [ ] Board is inside sheet
- [ ] Board is 2D (flat on XY plane)
- [ ] Board has no overlaps with other boards
- [ ] Position is within sheet bounds

### ✅ Console Output
- [ ] No errors in Ruby Console
- [ ] Success message shown
- [ ] Statistics displayed

---

## Troubleshooting

### Error: "No labeled boards found in selection"

**Cause**: Selected boards are not labeled

**Solution**:
1. Select boards
2. Click "Label Extra Boards" first
3. Then click "Nest Extra Boards"

---

### Error: "Could not find or create nesting root"

**Cause**: No nesting root in model

**Solution**:
1. Create a group
2. Set attribute: `ABF > is-nesting-root: true`
3. Try again

**Quick fix in Ruby Console**:
```ruby
root = Sketchup.active_model.entities.add_group
root.name = "NestingRoot_Main"
root.set_attribute('ABF', 'is-nesting-root', true)
```

---

### Error: "No valid boards to nest"

**Cause**: Selected boards failed validation

**Solution**:
Check board structure:
- [ ] Has front face
- [ ] Has back face
- [ ] Front/back are parallel
- [ ] Front/back are congruent
- [ ] Side faces are rectangular
- [ ] Thickness > 0

---

### Board not placed correctly

**Symptoms**: Board appears outside sheet or overlapping

**Debug**:
1. Check console for validation errors
2. Run validation:
   ```ruby
   # In Ruby Console after nesting
   GG_Cabinet::ExtraNesting::DevTools.validate_last_nesting
   ```

**Common causes**:
- Gap detection failed (too many boards)
- Rotation disabled but needed
- Material/thickness mismatch

---

### Clone appears in wrong location

**Expected**: Clone is 5000mm to the right

**If wrong**:
1. Check transformation was applied
2. Manually move if needed
3. Report issue

---

## Advanced Testing

### Test with Development Tools

If `DEV_MODE = true`, use development menu:

```ruby
# Focus on original
Plugins → GG Extra Nesting → 🎮 Dev: Focus N1

# Focus on clone
Plugins → GG Extra Nesting → 🎮 Dev: Focus N2
```

### Manual Validation

```ruby
# In Ruby Console
model = Sketchup.active_model

# Find cloned root
clone = model.entities.grep(Sketchup::Group).find do |e|
  e.get_attribute('ABF', 'is-nesting-root-clone') == true
end

puts "Clone: #{clone ? clone.name : 'Not found'}"

# Count boards in clone
if clone
  boards = 0
  clone.entities.grep(Sketchup::Group).each do |sheet|
    boards += sheet.entities.grep(Sketchup::Group).count
  end
  puts "Boards in clone: #{boards}"
end
```

### Performance Testing

Test with many boards:

```ruby
# Create 10 test boards
10.times do |i|
  board = model.entities.add_group
  board.name = "TestBoard_#{i + 1}"
  board.set_attribute('ABF', 'is-extra-board', true)
  board.set_attribute('ABF', 'material-name', 'Oak Veneer')
  board.set_attribute('ABF', 'thickness', 18.0)

  # Add simple face
  points = [
    Geom::Point3d.new(0, 0, 0),
    Geom::Point3d.new(600.mm, 0, 0),
    Geom::Point3d.new(600.mm, 400.mm, 0),
    Geom::Point3d.new(0, 400.mm, 0)
  ]
  board.entities.add_face(points)

  # Add back face
  points_back = points.map { |p| Geom::Point3d.new(p.x, p.y, -18.mm) }
  board.entities.add_face(points_back)
end
```

Then select all and nest.

---

## Expected Console Output (Full Example)

```
======================================================================
LABEL TOOL - Labeling Extra Boards
======================================================================

Processing 1/1: ExtraBoard_1
  ✓ Labeled successfully
    Material: Oak Veneer
    Thickness: 18.0 mm
    Size: 600 × 400 mm

----------------------------------------------------------------------
LABELING SUMMARY
----------------------------------------------------------------------
  Total selected: 1
  Labeled: 1
  Skipped: 0
  Errors: 0

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
  Projecting 1/1: ExtraBoard_1
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
   Sheet: Oak Veneer_18.0
   Position: (0, 0) @ 0°
   New sheet: true

✓ Nesting is valid (no overlaps)
```

---

## Summary

✅ **Two-button workflow**:
1. Select board → Label Extra Boards
2. Select labeled board → Nest Extra Boards

✅ **Automatic cloning**:
- Original nesting root unchanged
- Clone created at +5000mm offset

✅ **Smart nesting**:
- Matches material and thickness
- Finds gaps in existing sheets
- Creates new sheets when needed
- Tries rotations for best fit

✅ **Ready for production testing**!

---

**Last Updated**: 2025-11-28
