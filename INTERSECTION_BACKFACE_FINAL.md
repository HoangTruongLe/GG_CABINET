# Intersection Detection & Backface Projection - Final Implementation

**Date**: 2025-11-28
**Status**: Complete ✅

---

## Summary

This implementation adds support for:
1. **Intersection detection** - Groups of edges with ABF/_ ABF layers
2. **Face location detection** - Determines if intersection is on front or back face
3. **Backface projection** - Only when back face has intersections
4. **Mark square detection** - Identifies bottom sheets

---

## 1. What is an Intersection?

An **intersection** is a **flat group of edges** with specific layer naming:

### Key Characteristics:
- **Always a Sketchup::Group**
- Contains edges (not faces)
- Flat object (2D, not 3D)
- Layer name starts with `ABF` or `_ABF`
- Lies ON the front or back face (not side faces)

### Layer Naming Rules:

**Include**:
- `ABF*` (e.g., `ABF_sheetBorder`, `ABF_custom`)
- `_ABF*` (e.g., `_ABF_markSquare`, `_ABF_groove`)

**Exclude**:
- `_ABF_Label` or `ABF_Label` (labels)
- `_ABF_side*` or `ABF_side*` (side faces)
- `Untagged`

### Examples:

| Layer Name | Is Intersection? | Reason |
|------------|------------------|--------|
| `ABF_sheetBorder` | ✅ Yes | Starts with ABF |
| `_ABF_markSquare` | ✅ Yes | Starts with _ABF |
| `ABF_groove` | ✅ Yes | Custom ABF layer |
| `_ABF_Label` | ❌ No | Excluded: Label |
| `_ABF_side1` | ❌ No | Excluded: Side face |
| `ABF_side_left` | ❌ No | Excluded: Side face |
| `Untagged` | ❌ No | Not ABF layer |

---

## 2. Face Location Detection

Since intersections are flat groups that lie ON a face, we need to determine which face they're on.

### Algorithm: Bounding Box Plane Test

```ruby
def intersection_on_face?(intersection_group, face)
  # Get face plane equation: Ax + By + Cz = D
  face_plane = face.plane
  normal = Geom::Vector3d.new(face_plane[0], face_plane[1], face_plane[2])
  d = face_plane[3]

  # Get all 8 corners of intersection group's bounding box
  bounds = intersection_group.bounds
  bbox_points = [
    bounds.min,
    Geom::Point3d.new(bounds.max.x, bounds.min.y, bounds.min.z),
    Geom::Point3d.new(bounds.min.x, bounds.max.y, bounds.min.z),
    Geom::Point3d.new(bounds.max.x, bounds.max.y, bounds.min.z),
    Geom::Point3d.new(bounds.min.x, bounds.min.y, bounds.max.z),
    Geom::Point3d.new(bounds.max.x, bounds.min.y, bounds.max.z),
    Geom::Point3d.new(bounds.min.x, bounds.max.y, bounds.max.z),
    bounds.max
  ]

  # Count how many bbox vertices lie on the face plane
  vertices_on_plane = bbox_points.count do |pt|
    distance = normal.dot(pt) - d
    distance.abs < 1.mm  # 1mm tolerance
  end

  # If at least 4 vertices are on the plane, the group lies on this face
  vertices_on_plane >= 4
end
```

### Why This Works:

- Intersection groups are **flat** (2D)
- At least 4 of the 8 bbox corners will be on the face plane
- 1mm tolerance handles floating point precision

---

## 3. Backface Projection Rules

### Rule 1: Only Create Backface if Back Face Has Intersections

**Critical**: Backface projection is ONLY created when the **back face** has at least one intersection group.

```ruby
if board.has_back_intersections? && board.back_face
  # Create backface projection
end
```

### Rule 2: Front Face Always Projected

The front face is always projected, regardless of intersections.

### Visual Example:

**Board WITHOUT Back Face Intersections:**
```
3D Board                2D Projection
┌─────────┐            ┌─────────┐
│  Front  │    =>      │  Front  │  (front face only)
│         │            │         │
│  Back   │            └─────────┘
└─────────┘
```

**Board WITH Back Face Intersections:**
```
3D Board                2D Projection
┌─────────┐            ┌─────────┐
│  Front  │            │  Front  │  (front face)
│   ╱╲    │    =>      │         │
│  ╱  ╲   │            └─────────┘
│ Back    │            ┌─────────┐
└─────────┘            │  Back   │  (back face with intersections)
                       │   ╱╲    │
                       └─────────┘
```

---

## 4. Implementation Details

### Board Model ([board.rb](gg_extra_nesting/models/board.rb))

**Intersection Detection:**

```ruby
def has_intersections?
  has_front_intersections? || has_back_intersections?
end

def has_front_intersections?
  front_intersections.any?
end

def has_back_intersections?
  back_intersections.any?
end

def front_intersections
  return [] unless @front_face && @front_face.entity
  get_intersection_groups_on_face(@front_face.entity)
end

def back_intersections
  return [] unless @back_face && @back_face.entity
  get_intersection_groups_on_face(@back_face.entity)
end

def get_intersection_groups_on_face(face)
  return [] unless face && @entity

  intersection_groups = []

  # Find all groups with ABF/_ABF layers inside the board
  @entity.entities.each do |ent|
    next unless ent.is_a?(Sketchup::Group)

    tag_name = ent.layer.name
    next unless Board.is_intersection_layer?(tag_name)

    # Check if this group lies on the given face
    if intersection_on_face?(ent, face)
      intersection_groups << ent
    end
  end

  intersection_groups
end
```

### TwoDProjector Service ([two_d_projector.rb](gg_extra_nesting/services/two_d_projector.rb))

**Projection Logic:**

```ruby
def project_board(board, target_container)
  # Always create front face projection
  front_2d = project_face(board, front_face, target_container, 'front')

  # Only create back face if it has intersections
  if board.has_back_intersections? && board.back_face
    back_2d = project_face(board, board.back_face, target_container, 'back')
  end

  front_2d
end

def project_face(board, face, target_container, face_type = 'front')
  # ... create 2D group ...

  # Project intersections (only on back face)
  if face_type == 'back' && board.has_back_intersections?
    project_intersections(two_d_group_entity, face)
  end
end
```

**Intersection Projection:**

```ruby
def project_intersections(group_entity, face)
  board = face.board
  return unless board

  # Get intersection groups on this specific face
  intersection_groups = if face == board.front_face
    board.front_intersections
  elsif face == board.back_face
    board.back_intersections
  else
    []
  end

  # Project each intersection group's edges
  intersection_groups.each do |intersection_group|
    project_intersection_group(group_entity, intersection_group)
  end
end

def project_intersection_group(target_group, intersection_group)
  return unless intersection_group && intersection_group.entities

  # Project all edges from the intersection group
  intersection_group.entities.each do |ent|
    if ent.is_a?(Sketchup::Edge)
      project_intersection_edge(target_group, ent, intersection_group.transformation)
    end
  end
end

def project_intersection_edge(target_group, edge, transformation = nil)
  # Transform edge to board local coordinates
  if transformation
    start_pt = edge.start.position.transform(transformation)
    end_pt = edge.end.position.transform(transformation)
  else
    start_pt = edge.start.position
    end_pt = edge.end.position
  end

  # Project to 2D (drop Z)
  start_2d = Geom::Point3d.new(start_pt.x, start_pt.y, 0)
  end_2d = Geom::Point3d.new(end_pt.x, end_pt.y, 0)

  # Draw edge in 2D projection
  new_edge = target_group.entities.add_line(start_2d, end_2d)
  new_edge.layer = edge.layer if edge.layer  # Preserve layer
end
```

---

## 5. Mark Square Detection

A **mark square** identifies a board as a "bottom sheet".

```ruby
def has_mark_square?
  return false unless @entity

  @entity.entities.any? do |ent|
    ent.is_a?(Sketchup::Group) &&
    ent.get_attribute('ABF', 'is-mark-square') == true
  end
end

def is_bottom_sheet?
  has_mark_square?
end
```

---

## 6. API Reference

### Board

```ruby
# Class method
Board.is_intersection_layer?(tag_name)  # => Boolean

# Instance methods - Intersections
board.has_intersections?         # => Boolean (front OR back has intersections)
board.has_front_intersections?   # => Boolean
board.has_back_intersections?    # => Boolean
board.intersections              # => Array of Groups (front + back)
board.front_intersections        # => Array of Groups (on front face)
board.back_intersections         # => Array of Groups (on back face)

# Instance methods - Bottom Sheet
board.has_mark_square?       # => Boolean
board.mark_square            # => Sketchup::Group or nil
board.is_bottom_sheet?       # => Boolean
```

### TwoDProjector

```ruby
# Main projection (creates front + back if back has intersections)
projector.project_board(board, container)  # => TwoDGroup (front)

# Face-specific projection
projector.project_face(board, face, container, 'front')  # => TwoDGroup
projector.project_face(board, face, container, 'back')   # => TwoDGroup

# Intersection projection
projector.project_intersections(group_entity, face)
projector.project_intersection_group(target, intersection_group)
projector.project_intersection_edge(target, edge, transformation)
```

---

## 7. Usage Examples

### Example 1: Check Board Intersections

```ruby
board = Board.new(board_entity)

if board.has_intersections?
  puts "Board has intersections:"
  puts "  Front face: #{board.has_front_intersections?} (#{board.front_intersections.count} groups)"
  puts "  Back face: #{board.has_back_intersections?} (#{board.back_intersections.count} groups)"

  # List front face intersection groups
  board.front_intersections.each do |group|
    layer = group.layer.name
    edge_count = group.entities.select { |e| e.is_a?(Sketchup::Edge) }.count
    puts "  - Front: Group '#{group.name}' on layer '#{layer}' (#{edge_count} edges)"
  end

  # List back face intersection groups
  board.back_intersections.each do |group|
    layer = group.layer.name
    edge_count = group.entities.select { |e| e.is_a?(Sketchup::Edge) }.count
    puts "  - Back: Group '#{group.name}' on layer '#{layer}' (#{edge_count} edges)"
  end
end
```

### Example 2: Project Board with Back Face Intersections

```ruby
board = Board.new(board_entity)

# Only creates backface if BACK FACE has intersections
if board.has_back_intersections?
  projector = TwoDProjector.new
  front_2d = projector.project_board(board, target_container)

  # Check what was projected
  projector.projected_groups.each do |group|
    puts "#{group.face_type} face: #{group.width} × #{group.height} mm"
  end
  # Output:
  # front face: 600 × 400 mm (always created)
  # back face: 600 × 400 mm (with intersection edges)
else
  # Only front face created
  projector = TwoDProjector.new
  front_2d = projector.project_board(board, target_container)
  # No backface (even if front face has intersections)
end
```

### Example 3: Check Bottom Sheets

```ruby
board = Board.new(board_entity)

if board.is_bottom_sheet?
  puts "This is a bottom sheet"
  mark_square = board.mark_square
  puts "Mark square: #{mark_square.name}" if mark_square
end
```

---

## 8. Testing

Run the test script:

```ruby
load 'c:/Users/KB5007253/Desktop/tools/GG_ExtraNesting/test_intersections.rb'
```

### Test Coverage:

1. ✅ **Layer name validation** - Tests all ABF/* patterns
2. ✅ **Intersection group detection** - Finds groups on faces
3. ✅ **Face location detection** - Correctly identifies front/back
4. ✅ **Backface projection** - Only when back face has intersections
5. ✅ **Mark square detection** - Identifies bottom sheets

---

## 9. Key Differences from Previous Versions

### ❌ **Version 1 (Wrong)**:
- Intersections were board-level entities
- Checked `board.entity.entities`

### ❌ **Version 2 (Wrong)**:
- Intersections were individual edges on faces
- Checked `face.edges` directly

### ✅ **Version 3 (CORRECT)**:
- **Intersections are GROUPS of edges**
- Groups have ABF/* layers
- Groups lie ON front or back face (determined by bbox plane test)
- Backface projection ONLY when back face has intersection groups

---

## 10. Visual Example

### Board Structure:

```
Board Group
├─ Front Face (Sketchup::Face)
│  └─ [Intersection Group on front face]
│     ├─ Layer: ABF_groove
│     └─ Contains: Edges
│
├─ Back Face (Sketchup::Face)
│  └─ [Intersection Group on back face]
│     ├─ Layer: _ABF_custom
│     └─ Contains: Edges
│
├─ Side Faces (4x Sketchup::Face)
│
└─ [Mark Square Group] (optional)
   ├─ Attribute: is-mark-square = true
   ├─ Layer: ABF_markSquare
   └─ Contains: 2 edges (dimensions)
```

### 2D Projection Result:

**Front Face Projection** (always created):
```
┌───────────────────────┐
│  Front Face Outline   │
│                       │
│  [No intersections    │
│   from front face]    │
│                       │
└───────────────────────┘
```

**Back Face Projection** (only if back face has intersections):
```
┌───────────────────────┐
│  Back Face Outline    │
│                       │
│   ╱───╲              │  ← Intersection edges
│  ╱     ╲             │     (from ABF_* group)
│ ╱_______╲            │
│                       │
└───────────────────────┘
```

---

## Summary

✅ **Intersection Detection**
- Groups (not edges) with ABF/_ ABF layers
- Face location via bounding box plane test
- Separate tracking for front and back face

✅ **Backface Projection**
- ONLY when back face has intersection groups
- Projects all edges from intersection groups
- Preserves layer information

✅ **Mark Square Detection**
- Identifies bottom sheets
- Board-level detection

✅ **Complete Testing**
- 5 comprehensive test scenarios
- Real board testing
- Face location validation

**Status**: Complete ✅
**Ready for**: Production use and nesting integration

---

**Last Updated**: 2025-11-28
