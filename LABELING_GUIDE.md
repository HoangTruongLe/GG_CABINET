# Labeling Guide - Extra Boards

**Date**: 2025-11-30
**Version**: 0.1.0-dev

---

## Overview

The labeling system now includes:

✅ **Automatic front face detection** based on intersections
✅ **Text-based visual labels** with index numbers, separators, and instance names
✅ **Dynamic label scaling** with automatic sizing and margins
✅ **Directional arrow indicators** pointing in the height direction
✅ **Automatic board indexing** (sequential numbering)
✅ **Complete ABF attributes** matching specification
✅ **Re-labeling support** with index updates
✅ **Multi-line label rotation** based on face orientation

---

## How It Works

### Step 1: Front Face Detection

When you label a board, the system automatically detects which face should be the "front face":

**Detection Priority**:
1. If face already marked with `is-labeled-face: true` → Use that face
2. If no marked face → **Compare intersection counts**:
   - Face with **more intersections** becomes front face
   - Face with fewer intersections becomes back face
3. If equal intersections → Use largest face as front

**Why This Matters**:
- Front face is where the label will be drawn
- Front face is used for 2D projection
- Intersections are typically on the visible/important face

### Step 2: Board Attributes Set

All required ABF attributes are set:

```ruby
[ABF] "is-board" => true
[ABF] "is-extra-board" => true
[ABF] "board-index" => 7                    # Auto-incremented
[ABF] "labeled-at" => "2025-11-28 18:38:57 +0700"
[ABF] "material-name" => "[Color A02]"      # From board material
[ABF] "thickness" => 17.5                   # Detected thickness
[ABF] "classification-key" => "[Color A02]_17.5"
[ABF] "edge-band-types" => [0, "CHỈ", 1.0, "#b36ea9", 0]  # Default
[ABF] "label-rotation" => 0                 # Based on face orientation
```

### Step 3: Front Face Marked

The front face entity is marked:

```ruby
[ABF] "is-labeled-face" => true
```

This ensures the same face is recognized as front next time.

### Step 4: Visual Label Drawn

A text-based visual label is drawn on the front face with the following components:

**Label Components**:
- **Index Number**: Large text (6.0mm height) showing the board index
- **Separator**: Dash character "-" (5.0mm height)
- **Instance Name**: Board name (5.0mm height)
- **Direction Arrow**: Vector arrow with arrowhead pointing in height direction
- All components are 3D text entities, flattened to face geometry

**Label Layout**:
```
[1] - [Board_Name] →
```

**Automatic Scaling**:
- Labels are automatically scaled to fit the face with 10mm margins
- Maximum scale factor: 6.0x
- Labels are positioned at face center
- Scaling preserves text proportions

**Label Positioning**:
- Centered on the front face
- Rotated to align arrow with face height direction
- Additional user rotation offset can be applied (0°, 90°, 180°, 270°)

**Attributes**:
  ```ruby
  [ABF] "is-label" => true
  [ABF] "label-index" => 7
  [ABF] "label-rotation" => 0
  [ABF] "label-scale" => 2.5  # If scaled
  ```

---

## Automatic Indexing

### Sequential Numbering

Boards are automatically indexed when labeled:

**First labeling session**:
```
Board 1 → index 1
Board 2 → index 2
Board 3 → index 3
```

**Second labeling session** (finds max existing index):
```
Existing max index: 3
Board 4 → index 4
Board 5 → index 5
```

### Re-labeling

If you label a board that's already labeled:
- Index is **updated** to current position
- Visual label is **redrawn**
- Status shown as "Re-labeled"

---

## Usage Examples

### Example 1: Label Single Board

```ruby
# 1. Select board
board = Sketchup.active_model.selection.first

# 2. Click: Plugins → GG Extra Nesting → Label Extra Boards

# Console output:
======================================================================
LABEL TOOL - Labeling Extra Boards
======================================================================

Processing 1/1: Board_1
  ✓ Labeled successfully
    Index: 1
    Material: [Color A02]
    Thickness: 17.5 mm
    Size: 600 × 400 mm
    Classification: [Color A02]_17.5
    Front face intersections: 3
    Front face marked (3 intersections)
    Visual label drawn (rotation: 0°)

----------------------------------------------------------------------
LABELING SUMMARY
----------------------------------------------------------------------
  Total selected: 1
  Newly labeled: 1
  Re-labeled: 0
  Skipped: 0
  Errors: 0
  Next index: 2
```

### Example 2: Label Multiple Boards

```ruby
# Select 3 boards
# Click: Label Extra Boards

# Result:
Newly labeled: 3
Board indices: 1 - 3
```

### Example 3: Board with Intersections

```ruby
# Board has:
# - Front face: 5 intersections (grooves)
# - Back face: 1 intersection (hole)

# After labeling:
Front face: The one with 5 intersections
Back face: The one with 1 intersection
Label drawn on: Front face (the one with 5 intersections)
Label content: "5 - Board_Name →"
Label scale: Automatically calculated based on face size
```

---

## Label Format Details

### Text Components

**1. Index Number** (6.0mm base height)
- Bold, filled 3D text
- Sequential numbering (1, 2, 3, ...)
- Positioned first (leftmost)

**2. Separator** (5.0mm base height)
- Single dash character "-"
- Positioned after index number with 2.0mm spacing
- Aligned vertically with index

**3. Instance Name** (5.0mm base height)
- Board entity name from SketchUp
- Positioned after separator with 2.0mm spacing
- Aligned vertically with index

**4. Direction Arrow**
- Horizontal line with arrowhead
- Length: Total text width + 5.0mm
- Arrow head: 5.0mm size
- Points in face height direction
- Positioned below text baseline

### Automatic Scaling Algorithm

The label is automatically scaled to fit the face:

```ruby
# 1. Calculate available space
available_width = face_width - (2 × 10mm)  # 10mm margins
available_height = face_height - (2 × 10mm)

# 2. Calculate scale factors
scale_x = available_width / label_width
scale_y = available_height / label_height

# 3. Use minimum scale, capped at 6.0x
scale_factor = min(scale_x, scale_y, 6.0)

# 4. Apply uniform scaling
label.transform!(scale_factor)
```

**Margin Verification**:
- Labels maintain minimum 10mm margins on all sides
- Debug output shows actual margins after scaling
- Warnings displayed if margins are less than expected

---

## Front Face Detection Examples

### Case 1: Clear Winner (Different Intersection Counts)

```
Face A: 5 intersections → FRONT FACE ✓
Face B: 1 intersection  → Back face
```

### Case 2: Equal Intersections

```
Face A: 3 intersections → FRONT FACE ✓ (largest face)
Face B: 3 intersections → Back face
```

### Case 3: No Intersections

```
Face A: 0 intersections → FRONT FACE ✓ (largest face)
Face B: 0 intersections → Back face
```

### Case 4: Already Labeled

```
Face A: is-labeled-face: true → FRONT FACE ✓ (respects existing)
Face B: (not marked) → Back face
```

---

## Verifying Labels

### Check Board Attributes

```ruby
board = Sketchup.active_model.selection.first

# Check all attributes
puts "Index: #{board.get_attribute('ABF', 'board-index')}"
puts "Material: #{board.get_attribute('ABF', 'material-name')}"
puts "Thickness: #{board.get_attribute('ABF', 'thickness')}"
puts "Classification: #{board.get_attribute('ABF', 'classification-key')}"
puts "Labeled at: #{board.get_attribute('ABF', 'labeled-at')}"
puts "Label rotation: #{board.get_attribute('ABF', 'label-rotation')}"
```

### Check Front Face

```ruby
board = Sketchup.active_model.selection.first

# Find front face
front_face = board.entities.grep(Sketchup::Face).find do |face|
  face.get_attribute('ABF', 'is-labeled-face') == true
end

puts "Front face: #{front_face ? 'Found' : 'Not found'}"
```

### Check Visual Label

```ruby
board = Sketchup.active_model.selection.first

# Find label group
label = board.entities.grep(Sketchup::Group).find do |group|
  group.get_attribute('ABF', 'is-label') == true
end

puts "Visual label: #{label ? 'Found' : 'Not found'}"
if label
  puts "  Index: #{label.get_attribute('ABF', 'label-index')}"
  puts "  Rotation: #{label.get_attribute('ABF', 'label-rotation')}"
end
```

---

## Advanced Features

### Unlabel Boards

Remove label from selected boards:

```ruby
# Select labeled board(s)
# In Ruby Console:
GG_Cabinet::ExtraNesting::LabelTool.unlabel_selected_boards
```

This will:
- Remove `is-extra-board` attribute
- Remove `labeled-at` attribute
- Delete visual label
- Un-mark front face

**Note**: Other attributes (material, thickness, classification) are kept.

### Reindex All Labeled Boards

Renumber all labeled boards sequentially:

```ruby
# In Ruby Console:
GG_Cabinet::ExtraNesting::LabelTool.reindex_all_labeled_boards
```

This will:
- Find all labeled boards
- Renumber them 1, 2, 3, ...
- Update visual labels
- Show old → new index mapping

**Use case**: After deleting some labeled boards, reindex to fill gaps.

### Count Labeled Boards

```ruby
count = GG_Cabinet::ExtraNesting::LabelTool.count_labeled_boards
puts "Total labeled boards: #{count}"
```

---

## Edge Banding Attribute

The `edge-band-types` attribute is set with a default value:

```ruby
[0, "CHỈ", 1.0, "#b36ea9", 0]
```

**Format**: `[top, name, thickness, color, bottom]`

**Values**:
- `0` = no edge banding
- `1` = has edge banding
- `name` = edge band material name (Vietnamese: "CHỈ")
- `thickness` = edge band thickness (mm)
- `color` = edge band color (hex)

**Modify edge banding**:
```ruby
board = Sketchup.active_model.selection.first

# Set edge banding on top and bottom edges
board.set_attribute('ABF', 'edge-band-types', [1, "CHỈ", 1.0, "#b36ea9", 1])
```

---

## Label Rotation

Label rotation involves multiple transformations to ensure proper alignment:

### Rotation Process

**1. Face Alignment Transform**
- Rotates label from local XY plane to face plane
- Uses face normal to calculate rotation axis and angle

**2. Arrow Alignment Transform**
- Rotates label so arrow points in face height direction
- Ensures consistent orientation across different face orientations

**3. User Rotation Transform**
- Additional 180° + user offset rotation
- Default user offset: 0°
- Can be set to 90°, 180°, or 270° for custom orientations

### Setting Custom Rotation

```ruby
board = Sketchup.active_model.selection.first
board.set_attribute('ABF', 'label-rotation', 90)  # 90° offset

# Re-label to redraw with new rotation
# Select board → Label Extra Boards
```

**Rotation Values**:
- `0` - Default orientation (arrow points in height direction)
- `90` - Rotated 90° clockwise
- `180` - Rotated 180° (arrow points opposite direction)
- `270` - Rotated 270° clockwise (or 90° counter-clockwise)

---

## Troubleshooting

### Issue: Wrong face detected as front

**Symptom**: Back face has more intersections but front face was selected

**Solution**: Manually mark the correct face:
```ruby
# Select the face entity (double-click board, then click face)
face = Sketchup.active_model.selection.first
face.set_attribute('ABF', 'is-labeled-face', true)

# Then re-label the board
```

### Issue: No visual label drawn

**Symptom**: Board labeled but no label group visible

**Debug**:
1. Check if label group exists:
   ```ruby
   board.entities.grep(Sketchup::Group).each do |g|
     is_label = g.get_attribute('ABF', 'is-label')
     if is_label
       puts "Label found: #{g.name}"
       puts "  Index: #{g.get_attribute('ABF', 'label-index')}"
       puts "  Rotation: #{g.get_attribute('ABF', 'label-rotation')}"
       puts "  Scale: #{g.get_attribute('ABF', 'label-scale')}"
     end
   end
   ```

2. Check face center is valid:
   ```ruby
   board_obj = GG_Cabinet::ExtraNesting::Board.new(board)
   puts "Front face center: #{board_obj.front_face.center}"
   ```

3. Check label dimensions:
   ```ruby
   board_obj = GG_Cabinet::ExtraNesting::Board.new(board)
   label = board_obj.label
   if label
     puts "Label width: #{label.width} mm"
     puts "Label height: #{label.height} mm"
     puts "Label bounds: #{label.bounds}"
   end
   ```

### Issue: Index not incrementing

**Symptom**: All boards get same index

**Check**:
```ruby
# Find max existing index
max_index = 0
Sketchup.active_model.entities.grep(Sketchup::Group).each do |e|
  index = e.get_attribute('ABF', 'board-index')
  max_index = index if index && index.to_i > max_index
end
puts "Max index: #{max_index}"
```

---

## Console Output Reference

### Successful Labeling

```
======================================================================
LABEL TOOL - Labeling Extra Boards
======================================================================

Processing 1/1: Board_1
  ✓ Labeled successfully
    Index: 7
    Material: [Color A02]
    Thickness: 17.5 mm
    Size: 600 × 400 mm
    Classification: [Color A02]_17.5
    Front face intersections: 3
    Front face marked (3 intersections)
    Visual label drawn (rotation: 0°)

----------------------------------------------------------------------
LABELING SUMMARY
----------------------------------------------------------------------
  Total selected: 1
  Newly labeled: 1
  Re-labeled: 0
  Skipped: 0
  Errors: 0
  Next index: 8
```

### Re-labeling

```
Processing 1/1: Board_1
  ↻ Re-labeled (index updated)
    Index: 8
    ...
```

### Invalid Board

```
Processing 1/1: InvalidBoard
  ✗ Invalid board:
    - Front face not detected
    - Back face not detected
```

---

## Summary

✅ **Automatic front face detection** by intersection count
✅ **Text-based visual labels** with 3D text geometry
✅ **Multi-component labels**: Index + Separator + Instance Name + Arrow
✅ **Automatic scaling** with 10mm margins and 6.0x max scale
✅ **Intelligent rotation** aligning arrow with face height direction
✅ **Sequential indexing** with auto-increment
✅ **Complete attributes** matching specification:
   - board-index
   - material-name
   - thickness
   - classification-key
   - edge-band-types
   - label-rotation
   - label-scale (when scaled)
   - is-labeled-face (on front face entity)

✅ **Ready to use**!

---

## Advanced Features

### Label Dimensions

Labels provide dimension information in multiple coordinate systems:

**Local Dimensions** (`label.local_dimensions`):
- Width and height in label's local coordinate space
- Uses bounding box dimensions
- Returns smallest two non-zero dimensions

**Face Space Dimensions** (`label.label_dimensions_in_face_space`):
- Width and height projected onto face axes
- Includes width_direction and height_direction vectors
- Ensures width < height by swapping if needed
- Used for positioning and scaling calculations

**Direction Vectors**:
- `label.width_direction` - Label's local X-axis in world space
- `label.height_direction` - Label's local Y-axis in world space
- Used for alignment and rotation verification

---

**Next Step**: After labeling, use "Nest Extra Boards" to nest them into sheets.

---

**Last Updated**: 2025-11-30
