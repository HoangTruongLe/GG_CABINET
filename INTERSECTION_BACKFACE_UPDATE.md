# Intersection Detection & Backface Projection Update

**Date**: 2025-11-28
**Status**: Complete ✅

---

## Summary

This update adds support for:
1. **Intersection detection** based on layer/tag names
2. **Backface projection** for boards with intersections
3. **Mark square detection** for bottom sheets

---

## 1. Intersection Definition

An **intersection** is an **edge on a board's front or back face** whose layer/tag name matches these criteria:

### Include:
- Layer name starts with `ABF` (e.g., `ABF_sheetBorder`, `ABF_custom`)
- Layer name starts with `_ABF` (e.g., `_ABF_markSquare`, `_ABF_custom`)

### Exclude:
- `_ABF_Label` or `ABF_Label` (labels are not intersections)
- `_ABF_side*` or `ABF_side*` (side faces are not intersections)
- `Untagged` (untagged entities are not intersections)

### Examples:

| Layer Name | Is Intersection? | Reason |
|------------|------------------|--------|
| `ABF_sheetBorder` | ✅ Yes | Starts with `ABF` |
| `_ABF_markSquare` | ✅ Yes | Starts with `_ABF` |
| `ABF_custom` | ✅ Yes | Starts with `ABF` |
| `_ABF_Label` | ❌ No | Excluded: Label |
| `_ABF_side1` | ❌ No | Excluded: Side face |
| `ABF_side_left` | ❌ No | Excluded: Side face |
| `Untagged` | ❌ No | Not ABF layer |
| `MyLayer` | ❌ No | Doesn't start with ABF |

---

## 2. Backface Projection Rules

### Rule 1: Only Create Backface if Back Face Has Intersections

A board's **backface** is only projected to 2D if the **back face** has at least one intersection edge.

```ruby
# Project board
if board.has_back_intersections? && board.back_face
  # Create backface projection with intersection edges
end
```

**Note**: Front face intersections do NOT trigger backface projection. Only back face intersections do.

### Rule 2: Front Face Always Projected

The **front face** is always projected, regardless of intersections.

### Visual Example:

**Board WITHOUT Intersections:**
```
3D Board                2D Projection
┌─────────┐            ┌─────────┐
│  Front  │    =>      │  Front  │  (front face only)
│         │            │         │
│  Back   │            └─────────┘
└─────────┘
```

**Board WITH Intersections:**
```
3D Board                2D Projection
┌─────────┐            ┌─────────┐
│  Front  │            │  Front  │  (front face)
│   ╱╲    │    =>      │   ╱╲    │
│  ╱  ╲   │            └─────────┘
│ Back    │            ┌─────────┐
└─────────┘            │  Back   │  (back face with intersections)
                       │   ╱╲    │
                       └─────────┘
```

---

## 3. Mark Square (Bottom Sheet)

A **mark square** is a special group that identifies a board as a "bottom sheet".

### Detection:

```ruby
# Check if board has mark square
board.has_mark_square?  # => true/false

# Get mark square group
mark_square = board.mark_square  # => Sketchup::Group or nil

# Check if board is bottom sheet
board.is_bottom_sheet?  # => true if has mark square
```

### Mark Square Properties:

- Attribute: `'is-mark-square' => true`
- Layer: Usually `ABF_markSquare` or `_ABF_markSquare`
- Contains: Typically 2 edges representing sheet dimensions
- Location: Inside the board group

### Example from Dump:

```ruby
Sketchup::Group (__ABF_markSquare)
  tag: ABF_markSquare
  attributes:
    - [ABF] "is-mark-square" => true
  container_stats: faces=0, edges=2
```

---

## 4. Code Changes

### [gg_extra_nesting/models/board.rb](gg_extra_nesting/models/board.rb)

**Added: Intersection Layer Detection**

```ruby
# Check if entity is an intersection based on layer/tag name
# Intersection: layer starts with ABF or _ABF
# Exclude: _ABF_Label, _ABF_side*, ABF_Label, ABF_side*
def self.is_intersection_layer?(tag_name)
  return false unless tag_name
  return false if tag_name == 'Untagged'

  # Check if starts with ABF or _ABF
  starts_with_abf = tag_name.start_with?('ABF') || tag_name.start_with?('_ABF')
  return false unless starts_with_abf

  # Exclude labels and side faces
  excluded_patterns = [
    '_ABF_Label',
    '_ABF_side',
    'ABF_Label',
    'ABF_side'
  ]

  !excluded_patterns.any? { |pattern| tag_name.start_with?(pattern) }
end
```

**Updated: Intersection Detection (Face-Based)**

```ruby
def has_intersections?
  has_front_intersections? || has_back_intersections?
end

def has_front_intersections?
  return false unless @front_face && @front_face.entity
  face_has_intersections?(@front_face.entity)
end

def has_back_intersections?
  return false unless @back_face && @back_face.entity
  face_has_intersections?(@back_face.entity)
end

def face_has_intersections?(face)
  return false unless face

  face.edges.any? do |edge|
    tag_name = edge.layer.name
    Board.is_intersection_layer?(tag_name)
  end
end

def intersections
  front_intersections + back_intersections
end

def front_intersections
  return [] unless @front_face && @front_face.entity
  get_face_intersections(@front_face.entity)
end

def back_intersections
  return [] unless @back_face && @back_face.entity
  get_face_intersections(@back_face.entity)
end

def get_face_intersections(face)
  return [] unless face

  face.edges.select do |edge|
    tag_name = edge.layer.name
    Board.is_intersection_layer?(tag_name)
  end
end
```

**Added: Mark Square Detection**

```ruby
# Check if board is a bottom sheet (has mark square)
def has_mark_square?
  return false unless @entity

  @entity.entities.any? do |ent|
    ent.is_a?(Sketchup::Group) &&
    ent.get_attribute('ABF', 'is-mark-square') == true
  end
end

def mark_square
  return nil unless @entity

  @entity.entities.find do |ent|
    ent.is_a?(Sketchup::Group) &&
    ent.get_attribute('ABF', 'is-mark-square') == true
  end
end

def is_bottom_sheet?
  has_mark_square?
end
```

---

### [gg_extra_nesting/services/two_d_projector.rb](gg_extra_nesting/services/two_d_projector.rb)

**Updated: Main Projection Method**

```ruby
# Project board to 2D group in target container
# Creates frontface projection (always) and backface projection (if has intersections)
def project_board(board, target_container)
  return nil unless board && board.valid?
  return nil unless target_container

  # Get front face
  front_face = board.front_face
  return nil unless front_face

  # Create front face projection
  front_2d = project_face(board, front_face, target_container, 'front')

  # Create back face projection if back face has intersections
  if board.has_back_intersections? && board.back_face
    back_2d = project_face(board, board.back_face, target_container, 'back')
  end

  # Return front face projection (primary)
  front_2d
end
```

**Added: Face Projection Method**

```ruby
# Project a single face to 2D group
def project_face(board, face, target_container, face_type = 'front')
  return nil unless board && face && target_container

  # Create 2D group in target container
  two_d_group_entity = target_container.entities.add_group
  two_d_group_entity.name = "2D_#{board.entity.name}_#{face_type}"

  # Mark as 2D projection
  two_d_group_entity.set_attribute('ABF', 'is-2d-projection', true)
  two_d_group_entity.set_attribute('ABF', 'source-board-id', board.entity_id)
  two_d_group_entity.set_attribute('ABF', 'face-type', face_type)

  # Create TwoDGroup object
  two_d_group = TwoDGroup.new(two_d_group_entity, board)
  two_d_group.face_type = face_type

  # Project face outline
  outline_points = project_face_outline(face)
  two_d_group.set_outline(outline_points)

  # Draw outline in SketchUp
  draw_outline(two_d_group_entity, outline_points)

  # Apply edge banding if present (only on front face)
  if face_type == 'front'
    apply_edge_banding(two_d_group_entity, board, face)
  end

  # Clone label if present (only on front face)
  if face_type == 'front'
    clone_label(two_d_group_entity, board, face)
  end

  # Project intersections (only on back face)
  if face_type == 'back' && board.has_back_intersections?
    project_intersections(two_d_group_entity, face)
  end

  # Store projected group
  @projected_groups << two_d_group

  two_d_group
end
```

**Added: Intersection Projection (Face-Based)**

```ruby
# Project intersection edges from a face to 2D group
def project_intersections(group_entity, face)
  return unless face && face.entity

  # Get intersection edges from the face
  intersection_edges = face.entity.edges.select do |edge|
    tag_name = edge.layer.name
    Board.is_intersection_layer?(tag_name)
  end

  # Project each intersection edge
  intersection_edges.each do |edge|
    project_intersection_edge(group_entity, edge)
  end
end

# Project single intersection edge to 2D
def project_intersection_edge(target_group, edge)
  # Get edge vertices (in board local coordinates)
  start_pt = edge.start.position
  end_pt = edge.end.position

  # Project to 2D (drop Z)
  start_2d = Geom::Point3d.new(start_pt.x, start_pt.y, 0)
  end_2d = Geom::Point3d.new(end_pt.x, end_pt.y, 0)

  # Draw edge in target group
  new_edge = target_group.entities.add_line(start_2d, end_2d)

  # Copy layer from source
  new_edge.layer = edge.layer if edge.layer
end
```

---

### [gg_extra_nesting/models/two_d_group.rb](gg_extra_nesting/models/two_d_group.rb)

**Added: Face Type Attribute**

```ruby
class TwoDGroup < PersistentEntity
  attr_reader :source_board, :outline_points, :label_group
  attr_accessor :nesting_position, :nesting_rotation, :face_type

  def initialize(sketchup_group, source_board = nil)
    super(sketchup_group)

    @source_board = source_board
    @outline_points = []
    @label_group = nil
    @nesting_position = nil  # [x, y] position in nesting
    @nesting_rotation = 0    # Rotation angle in degrees
    @face_type = 'front'     # 'front' or 'back'
  end
end
```

**Updated: Serialization**

```ruby
def to_hash
  super.merge({
    source_board_id: @source_board ? @source_board.entity_id : nil,
    face_type: @face_type,  # Added
    outline_points: @outline_points,
    # ... rest of fields
  })
end
```

---

## 5. Testing

Run the test script:

```ruby
load 'c:/Users/KB5007253/Desktop/tools/GG_ExtraNesting/test_intersections.rb'
```

### Test Coverage:

1. ✅ **Intersection layer detection** - Test all layer name patterns
2. ✅ **Board intersection detection** - Find intersections in boards
3. ✅ **Backface projection with intersections** - Create backface when intersections exist
4. ✅ **No backface without intersections** - Skip backface when no intersections
5. ✅ **Mark square detection** - Identify bottom sheets

---

## 6. Usage Examples

### Example 1: Check Board Intersections

```ruby
board = Board.new(board_entity)

if board.has_intersections?
  puts "Board has intersections:"
  puts "  Front face: #{board.has_front_intersections?} (#{board.front_intersections.count} edges)"
  puts "  Back face: #{board.has_back_intersections?} (#{board.back_intersections.count} edges)"

  # List front face intersections
  board.front_intersections.each do |edge|
    layer = edge.layer.name
    length = edge.length / 1.mm
    puts "  - Front edge on layer: #{layer} (#{length.round(2)} mm)"
  end

  # List back face intersections
  board.back_intersections.each do |edge|
    layer = edge.layer.name
    length = edge.length / 1.mm
    puts "  - Back edge on layer: #{layer} (#{length.round(2)} mm)"
  end
end
```

### Example 2: Check if Layer is Intersection

```ruby
# Test layer names
Board.is_intersection_layer?('ABF_sheetBorder')  # => true
Board.is_intersection_layer?('_ABF_markSquare')  # => true
Board.is_intersection_layer?('_ABF_Label')       # => false
Board.is_intersection_layer?('ABF_side1')        # => false
Board.is_intersection_layer?('Untagged')         # => false
```

### Example 3: Project Board with Intersections

```ruby
board = Board.new(board_entity)

# Only creates backface if BACK FACE has intersections
if board.has_back_intersections?
  # Will create both front AND back projections
  projector = TwoDProjector.new
  front_2d = projector.project_board(board, target_container)

  # Check projected groups
  projector.projected_groups.each do |group|
    puts "#{group.face_type} face: #{group.width} × #{group.height} mm"
  end
  # Output:
  # front face: 600 × 400 mm (always created)
  # back face: 600 × 400 mm (with back face intersection edges)
else
  # Will only create front projection
  projector = TwoDProjector.new
  front_2d = projector.project_board(board, target_container)
  # Only front face created (even if front face has intersections)
end
```

### Example 4: Check Bottom Sheets

```ruby
board = Board.new(board_entity)

if board.is_bottom_sheet?
  puts "This is a bottom sheet"
  puts "Has mark square: #{board.has_mark_square?}"

  mark_square = board.mark_square
  puts "Mark square: #{mark_square.name}" if mark_square
end
```

---

## 7. Visual Examples

### Rectangular Board with Intersections

**3D Board:**
```
     ┌───────────────┐
    ╱               ╱│
   ╱   Front Face  ╱ │  600×400×18mm
  ╱_______________╱  │
  │       ╱╲      │  │  Intersections
  │      ╱  ╲     │  │  (ABF_* layers)
  │     ╱____╲    │ ╱
  │   Back Face   │╱
  └───────────────┘
```

**2D Projection (Front Face):**
```
  (0,0)          (600,0)
    ●──────────────●
    │              │
    │  Front Face  │  600×400mm
    │  (with edge  │  (Edge banding + label)
    │   banding)   │
    │              │
    ●──────────────●
  (0,400)      (600,400)
```

**2D Projection (Back Face):**
```
  (0,0)          (600,0)
    ●──────────────●
    │      ╱╲      │
    │     ╱  ╲     │  600×400mm
    │    ╱____╲    │  (Intersection edges projected)
    │   Back Face  │
    │              │
    ●──────────────●
  (0,400)      (600,400)
```

### Board Without Intersections

**3D Board:**
```
     ┌───────────────┐
    ╱               ╱│
   ╱   Front Face  ╱ │  600×400×18mm
  ╱_______________╱  │
  │               │  │  No intersections
  │               │  │
  │               │ ╱
  │   Back Face   │╱
  └───────────────┘
```

**2D Projection (Front Face ONLY):**
```
  (0,0)          (600,0)
    ●──────────────●
    │              │
    │  Front Face  │  600×400mm
    │  (with edge  │  (Edge banding + label)
    │   banding)   │
    │              │
    ●──────────────●
  (0,400)      (600,400)

  No back face projection (no intersections)
```

---

## 8. API Reference

### Board

```ruby
# Class method
Board.is_intersection_layer?(tag_name)  # Check if layer is intersection

# Instance methods - Intersections
board.has_intersections?         # => Boolean (front OR back has intersections)
board.has_front_intersections?   # => Boolean (front face has intersections)
board.has_back_intersections?    # => Boolean (back face has intersections)
board.intersections              # => Array of Edges (front + back)
board.front_intersections        # => Array of Edges (front face only)
board.back_intersections         # => Array of Edges (back face only)

# Instance methods - Bottom Sheet
board.has_mark_square?       # => Boolean
board.mark_square            # => Sketchup::Group or nil
board.is_bottom_sheet?       # => Boolean (same as has_mark_square?)
```

### TwoDProjector

```ruby
# Main projection (creates front + back if has intersections)
projector.project_board(board, container)  # => TwoDGroup (front)

# New method: Project specific face
projector.project_face(board, face, container, 'front')  # => TwoDGroup
projector.project_face(board, face, container, 'back')   # => TwoDGroup

# Intersection projection (face-based)
projector.project_intersections(group_entity, face)  # Projects edges from face
projector.project_intersection_edge(target, edge)    # Projects single edge
```

### TwoDGroup

```ruby
# New attribute
two_d_group.face_type        # => 'front' or 'back'
two_d_group.face_type = 'back'
```

---

## 9. Integration Points

### With Phase 3 (2D Projection)

- Seamless integration with existing projection system
- Front face projection unchanged
- Backface projection added conditionally

### With Phase 4 (Nesting Engine)

- Front face always used for nesting (primary)
- Back face provides intersection information
- Bottom sheets identified via mark square

---

## 10. Files Updated

| File | Changes | Lines Added |
|------|---------|-------------|
| [gg_extra_nesting/models/board.rb](gg_extra_nesting/models/board.rb) | Intersection detection, mark square detection | ~70 lines |
| [gg_extra_nesting/services/two_d_projector.rb](gg_extra_nesting/services/two_d_projector.rb) | Backface projection, intersection projection | ~90 lines |
| [gg_extra_nesting/models/two_d_group.rb](gg_extra_nesting/models/two_d_group.rb) | Face type attribute | ~5 lines |
| [test_intersections.rb](test_intersections.rb) | Comprehensive test script | ~250 lines |
| [INTERSECTION_BACKFACE_UPDATE.md](INTERSECTION_BACKFACE_UPDATE.md) | This documentation | ~600 lines |

**Total**: ~1,015 lines of code and documentation

---

## Summary

✅ **Intersection Detection**
- Face-based detection (edges on front/back faces)
- Layer-based filtering (ABF_* or _ABF_*)
- Excludes labels and side faces
- Separate tracking for front and back face intersections

✅ **Backface Projection**
- Only created when BACK FACE has intersections
- Includes projected intersection edges from back face
- Preserves layer information
- Front face intersections do NOT trigger backface projection

✅ **Mark Square Detection**
- Identifies bottom sheets
- Board-level API methods
- Integration with serialization

✅ **Complete Testing**
- 5 comprehensive test scenarios
- Real board testing
- Layer name validation

✅ **Documentation**
- API reference
- Usage examples
- Visual diagrams

**Status**: Complete ✅
**Ready for**: Integration with nesting workflow

---

**Last Updated**: 2025-11-28
