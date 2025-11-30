# Labeling Update - Complete Implementation

**Date**: 2025-11-29 (Updated)
**Status**: ✅ Complete with Enhanced Visual Labels

---

## What's New

I've completely updated the labeling system based on your requirements:

### 1. ✅ Front Face Detection by Intersections

**Old behavior**: Used largest face as front
**New behavior**: Face with **more intersections** becomes front face

```ruby
Face A: 5 intersections → FRONT FACE ✓
Face B: 2 intersections → Back face
```

**Implementation**: [board.rb:139-187](gg_extra_nesting/models/board.rb#L139-L187)

### 2. ✅ Visual Label on Front Face (Enhanced)

**New service**: LabelDrawer draws comprehensive visual label (group of edges) on front face

**Features**:
- Rectangle outline (80mm × 40mm)
- **Vector arrow** showing grain direction (25mm, pointing down)
- **Index number** at top (matches board-index)
- **Instance name** at bottom (board entity name, max 12 chars)
- Positioned at face center
- Automatic rotation based on face orientation

**Visual Layout**:
```
┌──────────────┐
│     [14]     │  ← Index number
│      ↓       │  ← Vector arrow (grain direction)
│   ĐỘ GỖ A3   │  ← Instance name
└──────────────┘
```

**Implementation**: [label_drawer.rb](gg_extra_nesting/services/label_drawer.rb)

**See**: [LABEL_FORMAT.md](LABEL_FORMAT.md) for detailed label format documentation

### 3. ✅ Automatic Board Indexing

**Sequential numbering**:
- Finds highest existing `board-index`
- Auto-increments for each new board
- Re-indexing support for reordering

**Example**:
```
Existing boards: 1, 2, 3
New boards: 4, 5, 6
```

**Implementation**: [label_tool.rb:132-142](gg_extra_nesting/tools/label_tool.rb#L132-L142)

### 4. ✅ Complete ABF Attributes

All required attributes are now set:

```ruby
[ABF] "board-index" => 7                           # ✅ Auto-increment
[ABF] "classification-key" => "[Color A02]_17.5"  # ✅ From board
[ABF] "edge-band-types" => [0, "CHỈ", 1.0, "#b36ea9", 0]  # ✅ Default
[ABF] "is-board" => true                           # ✅ Set
[ABF] "is-extra-board" => true                     # ✅ Set
[ABF] "label-rotation" => 0                        # ✅ Calculated
[ABF] "labeled-at" => "2025-11-28 18:38:57 +0700" # ✅ Timestamp
[ABF] "material-name" => "[Color A02]"             # ✅ From board
[ABF] "thickness" => 17.5                          # ✅ Detected
```

**Front face entity**:
```ruby
[ABF] "is-labeled-face" => true                    # ✅ Marked
```

**Implementation**: [label_tool.rb:144-169](gg_extra_nesting/tools/label_tool.rb#L144-L169)

---

## Files Updated

### Modified

1. **[board.rb](gg_extra_nesting/models/board.rb)**
   - Added `detect_front_by_intersections()` method
   - Added `find_parallel_congruent_faces()` method
   - Front face detection now compares intersection counts
   - Lines 139-187

2. **[label_tool.rb](gg_extra_nesting/tools/label_tool.rb)** - Completely rewritten
   - Auto-indexing with `find_next_board_index()`
   - Complete attribute setting with `label_board()`
   - Front face marking with `mark_front_face()`
   - Visual label drawing with `draw_visual_label()`
   - Re-labeling support (updates index)
   - Added `unlabel_selected_boards()`
   - Added `reindex_all_labeled_boards()`
   - 346 lines

### New Files

3. **[label_drawer.rb](gg_extra_nesting/services/label_drawer.rb)** - New service
   - `draw_label()` - Creates visual label on front face
   - `remove_label()` - Removes existing label
   - `has_label?()` - Checks for label
   - 142 lines

4. **[LABELING_GUIDE.md](LABELING_GUIDE.md)** - Complete documentation
   - How front face detection works
   - Automatic indexing explained
   - Usage examples
   - Troubleshooting guide

5. **[extra_nesting.rb](gg_extra_nesting/extra_nesting.rb)** - Updated to load LabelDrawer

---

## How It Works Now

### Complete Workflow

```
1. User selects board(s)
   ↓
2. Click "Label Extra Boards"
   ↓
3. For each board:
   │
   ├─→ Validate structure
   │
   ├─→ Detect front face (by intersection count)
   │
   ├─→ Find next index (auto-increment)
   │
   ├─→ Set all ABF attributes
   │   - board-index
   │   - material-name
   │   - thickness
   │   - classification-key
   │   - edge-band-types
   │   - label-rotation
   │   - labeled-at
   │
   ├─→ Mark front face (is-labeled-face: true)
   │
   └─→ Draw visual label on front face
   ↓
4. Show summary with indices
```

---

## Console Output Example

```
======================================================================
LABEL TOOL - Labeling Extra Boards
======================================================================

Processing 1/3: Board_A
  ✓ Labeled successfully
    Index: 7
    Material: [Color A02]
    Thickness: 17.5 mm
    Size: 600 × 400 mm
    Classification: [Color A02]_17.5
    Front face intersections: 5
    Front face marked (5 intersections)
    Visual label drawn (rotation: 0°)

Processing 2/3: Board_B
  ✓ Labeled successfully
    Index: 8
    Material: [Color A02]
    Thickness: 17.5 mm
    Size: 500 × 300 mm
    Classification: [Color A02]_17.5
    Front face intersections: 2
    Front face marked (2 intersections)
    Visual label drawn (rotation: 0°)

Processing 3/3: Board_C
  ↻ Re-labeled (index updated)
    Index: 9
    Material: Oak Veneer
    Thickness: 18.0 mm
    Size: 400 × 300 mm
    Classification: Oak Veneer_18.0
    Front face intersections: 0
    Front face marked (0 intersections)
    Visual label drawn (rotation: 0°)

----------------------------------------------------------------------
LABELING SUMMARY
----------------------------------------------------------------------
  Total selected: 3
  Newly labeled: 2
  Re-labeled: 1
  Skipped: 0
  Errors: 0
  Next index: 10

[Message box]:
Successfully labeled 3 board(s) as extra boards.

Newly labeled: 2
Re-labeled: 1
Skipped: 0
Errors: 0

Board indices: 7 - 9
```

---

## Front Face Detection Logic

### Algorithm

```ruby
1. Check if face already marked with is-labeled-face: true
   → If yes: Use that face as front

2. If not marked:
   → Find two largest parallel congruent faces
   → Count intersections on each face

   Face A intersections > Face B intersections:
     → Face A = Front, Face B = Back

   Face B intersections > Face A intersections:
     → Face B = Front, Face A = Back

   Equal intersections:
     → Largest face = Front
```

### Examples

**Board with grooves on one side**:
```
Top face: 5 grooves (intersections) → FRONT ✓
Bottom face: 0 intersections → Back
```

**Board with hole on bottom**:
```
Top face: 0 intersections → FRONT ✓ (largest)
Bottom face: 1 hole → Back
```

**Board with equal intersections**:
```
Top face: 2 intersections → FRONT ✓ (largest by area)
Bottom face: 2 intersections → Back
```

---

## Attributes Reference

### Board Entity Attributes

```ruby
# Identity
"is-board" => true
"is-extra-board" => true
"board-index" => Integer (auto-increment)

# Properties
"material-name" => String or nil
"thickness" => Float (mm)
"classification-key" => "Material_Thickness"

# Labeling
"labeled-at" => String (timestamp)
"label-rotation" => Integer (degrees: 0, 90, 180, 270)

# Edge banding
"edge-band-types" => [top, name, thickness, color, bottom]
  # [0, "CHỈ", 1.0, "#b36ea9", 0]
  # 0 = no edge band, 1 = has edge band
```

### Front Face Entity Attributes

```ruby
"is-labeled-face" => true
```

### Label Group Attributes

```ruby
"is-label" => true
"label-index" => Integer (matches board-index)
"label-rotation" => Integer (degrees)
```

---

## Additional Features

### Unlabel Boards

```ruby
# Select labeled board(s)
GG_Cabinet::ExtraNesting::LabelTool.unlabel_selected_boards
```

**Removes**:
- `is-extra-board` attribute
- `labeled-at` attribute
- Visual label group
- `is-labeled-face` from front face

**Keeps**:
- `is-board`
- `material-name`
- `thickness`
- `classification-key`
- `board-index` (for reference)

### Reindex All Labeled Boards

```ruby
GG_Cabinet::ExtraNesting::LabelTool.reindex_all_labeled_boards
```

**What it does**:
- Finds all boards with `is-extra-board: true`
- Renumbers them sequentially (1, 2, 3, ...)
- Redraws visual labels with new indices
- Shows old → new mapping in console

**Use case**: After deleting labeled boards, clean up indices

### Count Labeled Boards

```ruby
count = GG_Cabinet::ExtraNesting::LabelTool.count_labeled_boards
puts "Total: #{count}"
```

---

## Testing

### Quick Test

1. **Create test board**:
   ```
   Rectangle: 600×400×18mm
   Add 3 intersection groups on top face (ABF_groove layer)
   Add 1 intersection group on bottom face
   Make group
   ```

2. **Label**:
   ```
   Select board → Label Extra Boards
   ```

3. **Verify**:
   - Check console: "Front face intersections: 3"
   - Check attributes: board-index, material, thickness, etc.
   - Check visual: Label drawn on face with 3 intersections

### Full Test Scenarios

See [LABELING_GUIDE.md](LABELING_GUIDE.md) for:
- Multiple board labeling
- Re-labeling test
- Edge cases
- Troubleshooting

---

## Integration with Nesting

The nesting tool uses all these attributes:

```ruby
# After labeling
board.get_attribute('ABF', 'is-extra-board')  # → true
board.get_attribute('ABF', 'board-index')     # → 7
board.get_attribute('ABF', 'material-name')   # → "[Color A02]"
board.get_attribute('ABF', 'thickness')       # → 17.5

# Nesting uses:
# - material-name for sheet matching
# - thickness for sheet matching
# - board-index for identification
# - Front face (is-labeled-face) for projection
```

---

## Summary

✅ **Front face detection** by intersection count
✅ **Visual label drawing** on front face
✅ **Auto-indexing** with sequential numbering
✅ **Complete attributes** matching your specification
✅ **Re-labeling support** with index updates
✅ **Helper functions** for unlabeling and reindexing

---

**Ready to test!**

See [LABELING_GUIDE.md](LABELING_GUIDE.md) for complete documentation.

---

**Last Updated**: 2025-11-28
