# Phase 3 Complete: 2D Projection

**Date**: 2025-11-27
**Status**: Complete ✅

---

## Summary

Phase 3 implements 2D projection of 3D boards onto the XY plane for nesting. This includes the TwoDGroup model to represent projected boards and the TwoDProjector service to perform the projection.

---

## Components Implemented

### 1. TwoDGroup Model ✅ (340 lines)

Represents a 2D projection of a 3D board.

**Features**:
- ✅ Outline management (2D polygon points)
- ✅ Bounding box calculation
- ✅ Area calculation (Shoelace formula)
- ✅ Geometric queries (point-in-polygon, overlap detection)
- ✅ Nesting position tracking
- ✅ Source board reference
- ✅ Validation

**Key Methods**:
```ruby
# Outline
two_d_group.set_outline(points)
two_d_group.outline  # => [[x1, y1], [x2, y2], ...]
two_d_group.bounds_2d  # => {min_x:, max_x:, min_y:, max_y:}

# Dimensions
two_d_group.width    # => Float (mm)
two_d_group.height   # => Float (mm)
two_d_group.area     # => Float (mm²)
two_d_group.center_2d  # => [x, y]

# Nesting
two_d_group.place_at(x, y, rotation)
two_d_group.positioned?  # => Boolean
two_d_group.nesting_transformation  # => Geom::Transformation

# Geometric queries
two_d_group.contains_point?(x, y)  # => Boolean
two_d_group.overlaps_with?(other)  # => Boolean

# Source board
two_d_group.classification_key
two_d_group.thickness
two_d_group.material_name
```

---

### 2. TwoDProjector Service ✅ (280 lines)

Projects 3D boards to 2D groups.

**Features**:
- ✅ Project front face outline to XY plane
- ✅ Create SketchUp 2D group entities
- ✅ Edge banding integration
- ✅ Label cloning
- ✅ Grid layout
- ✅ Batch projection

**Key Methods**:
```ruby
# Projection
projector = TwoDProjector.new
two_d_group = projector.project_board(board, target_container)
two_d_groups = projector.project_boards(boards, target_container)

# Layout
projector.layout_in_grid(two_d_groups, spacing)

# Class methods
TwoDProjector.project(board, target_container)
TwoDProjector.project_all(boards, target_container)
TwoDProjector.project_and_layout(boards, target_container, spacing)
```

---

## Key Algorithms

### 1. Face Outline Projection

```ruby
def project_face_outline(face)
  vertices = face.entity.vertices
  points_2d = vertices.map do |vertex|
    pos = vertex.position
    [pos.x, pos.y]  # Project to XY plane (drop Z)
  end
  points_2d
end
```

**Process**:
1. Get vertices from front face
2. Extract X and Y coordinates
3. Drop Z coordinate (project to XY plane)
4. Return 2D polygon

---

### 2. Area Calculation (Shoelace Formula)

```ruby
def area
  sum = 0
  n = @outline_points.length

  @outline_points.each_with_index do |pt, i|
    next_pt = @outline_points[(i + 1) % n]
    sum += pt[0] * next_pt[1]  # x_i * y_{i+1}
    sum -= next_pt[0] * pt[1]  # x_{i+1} * y_i
  end

  (sum.abs / 2.0)
end
```

**Formula**:
```
Area = 1/2 * |Σ(x_i * y_{i+1} - x_{i+1} * y_i)|
```

**Example** (rectangle 600×400):
```
Points: [0,0], [600,0], [600,400], [0,400]
Sum = (0*0 - 600*0) + (600*400 - 600*0) + (600*400 - 0*400) + (0*0 - 0*400)
Sum = 0 + 240000 + 240000 + 0 = 480000
Area = 480000 / 2 = 240000 mm²  ✓
```

---

### 3. Point-in-Polygon (Ray Casting)

```ruby
def contains_point?(x, y)
  inside = false
  n = @outline_points.length

  j = n - 1
  @outline_points.each_with_index do |pt, i|
    xi, yi = pt
    xj, yj = @outline_points[j]

    if ((yi > y) != (yj > y)) && (x < (xj - xi) * (y - yi) / (yj - yi) + xi)
      inside = !inside
    end

    j = i
  end

  inside
end
```

**Algorithm**: Cast a ray from point to infinity, count intersections with polygon edges.
- Odd count = inside
- Even count = outside

---

### 4. Overlap Detection

```ruby
def overlaps_with?(other_2d_group)
  # 1. Quick bounding box check
  bounds1 = bounds_2d
  bounds2 = other_2d_group.bounds_2d

  return false if bounds1[:max_x] < bounds2[:min_x]  # No overlap
  return false if bounds1[:min_x] > bounds2[:max_x]
  return false if bounds1[:max_y] < bounds2[:min_y]
  return false if bounds1[:min_y] > bounds2[:max_y]

  # 2. Detailed vertex check
  @outline_points.each do |pt|
    return true if other_2d_group.contains_point?(pt[0], pt[1])
  end

  other_2d_group.outline.each do |pt|
    return true if contains_point?(pt[0], pt[1])
  end

  false
end
```

**Process**:
1. Fast bounding box rejection
2. Check if any vertex of one polygon is inside the other

---

### 5. Grid Layout

```ruby
def layout_in_grid(two_d_groups, spacing = 100)
  x_offset = 0
  y_offset = 0
  row_height = 0
  max_width = 3000  # Max width before wrapping

  two_d_groups.each do |group|
    width = group.width
    height = group.height

    # Wrap to new row if needed
    if x_offset + width > max_width && x_offset > 0
      x_offset = 0
      y_offset += row_height + spacing
      row_height = 0
    end

    # Place group
    group.place_at(x_offset, y_offset, 0)

    # Update offsets
    x_offset += width + spacing
    row_height = [row_height, height].max
  end
end
```

**Layout**:
```
┌─────┐ ┌─────┐ ┌─────┐
│  1  │ │  2  │ │  3  │  ← Row 1
└─────┘ └─────┘ └─────┘
   ↓ spacing (100mm)
┌─────┐ ┌─────┐
│  4  │ │  5  │          ← Row 2 (wrapped at max_width)
└─────┘ └─────┘
```

---

## Integration with Edge Banding

The projector automatically integrates edge banding during projection:

```ruby
def project_board(board, target_container)
  # ... create 2D group ...

  # Project outline
  outline_points = project_face_outline(front_face)
  two_d_group.set_outline(outline_points)

  # Draw outline
  draw_outline(two_d_group_entity, outline_points)

  # Apply edge banding ✅
  apply_edge_banding(two_d_group_entity, board, front_face)

  two_d_group
end

def apply_edge_banding(group_entity, board, front_face)
  return unless EdgeBandingDrawer.has_edge_banding?(board)

  drawer = EdgeBandingDrawer.new
  drawer.draw_edge_banding(group_entity, board, front_face)
end
```

**Result**: 2D projection includes edge banding triangles automatically.

---

## Usage Examples

### Basic Projection

```ruby
# Load model
model = Sketchup.active_model

# Find N2 playground
n2 = model.entities.find { |e| e.name == "ExtraNesting_Playground" }

# Find a board
board_entity = model.entities.find { |e| e.get_attribute('ABF', 'is-board') }
board = Board.new(board_entity)

# Project to N2
projector = TwoDProjector.new
two_d_group = projector.project_board(board, n2)

# Check result
puts "Width: #{two_d_group.width} mm"
puts "Height: #{two_d_group.height} mm"
puts "Area: #{two_d_group.area} mm²"
```

### Batch Projection with Layout

```ruby
# Scan all boards
scanner = BoardScanner.new
boards = scanner.scan_all_boards

# Project and layout
two_d_groups = TwoDProjector.project_and_layout(boards, n2, 100)

puts "Projected #{two_d_groups.count} boards"
```

### Overlap Detection

```ruby
# Check if two projections overlap
if group1.overlaps_with?(group2)
  puts "Groups overlap - cannot place here"
else
  puts "No overlap - safe to place"
end
```

### Nesting Position

```ruby
# Place at specific position with rotation
two_d_group.place_at(500, 300, 90)  # x, y, rotation

# Apply transformation to SketchUp entity
two_d_group.entity.transformation = two_d_group.nesting_transformation

# Reset position
two_d_group.reset_position
```

---

## Visual Examples

### Rectangular Board Projection

**3D Board**:
```
     ┌───────────────┐
    ╱               ╱│
   ╱   Front Face  ╱ │  600×400×18mm
  ╱_______________╱  │
  │               │  │
  │               │ ╱
  │               │╱
  └───────────────┘
```

**2D Projection** (XY plane):
```
  (0,0)          (600,0)
    ●──────────────●
    │              │
    │  Front Face  │  600×400mm
    │  Projected   │
    │              │
    ●──────────────●
  (0,400)      (600,400)
```

### Circular Board Projection

**3D Board**:
```
       ___
     /     \
    |   O   |  Ø200mm
     \_____/
```

**2D Projection**:
```
       ___
     /     \
    |   O   |  Ø200mm (preserved)
     \_____/

Outline: [approx. 32 vertices forming circle]
```

### With Edge Banding

**2D Projection**:
```
   ┌───────────────────────────────────┐ ← Offset 1.0mm
   │              ▼                    │ ← Triangle marker
   │             ╱ ╲                   │
   │            ╱___╲                  │
   │                                   │
   │          Front Face               │
   │          (projected)              │
   │           _______                 │
   │          ╱       ╲                │
   │         ╱_________╲               │
   │        ▼           ▼              │
   └───────────────────────────────────┘ ← Offset 0.1mm
```

---

## Files Created

| File | Lines | Description |
|------|-------|-------------|
| [gg_extra_nesting/models/two_d_group.rb](gg_extra_nesting/models/two_d_group.rb) | 340 | TwoDGroup model |
| [gg_extra_nesting/services/two_d_projector.rb](gg_extra_nesting/services/two_d_projector.rb) | 280 | TwoDProjector service |
| [test_phase3.rb](test_phase3.rb) | 350 | Phase 3 test script |
| [PHASE3_COMPLETE.md](PHASE3_COMPLETE.md) | This file | Phase 3 documentation |

**Total**: ~1,000 lines of code and documentation

---

## Testing

Run the test script:

```ruby
load 'c:/Users/KB5007253/Desktop/tools/GG_ExtraNesting/test_phase3.rb'
```

**Test Coverage**:
1. ✅ TwoDGroup creation
2. ✅ Bounding box calculation
3. ✅ Area calculation (multiple shapes)
4. ✅ Point-in-polygon test
5. ✅ Overlap detection
6. ✅ Nesting position management
7. ✅ Simulated projection
8. ✅ Real board projection
9. ✅ Grid layout
10. ✅ Validation

---

## API Reference

### TwoDGroup

```ruby
# Constructor
TwoDGroup.new(sketchup_group, source_board)

# Outline
set_outline(points)           # Set 2D polygon points
outline                       # Get outline points

# Dimensions
width                         # Get width (mm)
height                        # Get height (mm)
area                          # Get area (mm²)
bounds_2d                     # Get bounding box
center_2d                     # Get center point

# Nesting
place_at(x, y, rotation)      # Set nesting position
positioned?                   # Check if positioned
nesting_transformation        # Get transformation matrix
reset_position                # Reset nesting state

# Geometric queries
contains_point?(x, y)         # Point inside test
overlaps_with?(other)         # Overlap detection

# Label
set_label(label_group)        # Set label
has_label?                    # Check for label

# Source board
classification_key            # Get classification key
thickness                     # Get thickness
material_name                 # Get material name
source_valid?                 # Check source board validity

# Validation
valid?                        # Check validity
validation_errors             # Get errors array

# Display
print_info                    # Print debug info
to_hash                       # Serialize to hash
```

### TwoDProjector

```ruby
# Instance methods
projector = TwoDProjector.new

project_board(board, target_container)
project_boards(boards, target_container)
layout_in_grid(two_d_groups, spacing)
projected_groups              # Get all projected groups
clear                         # Clear projected groups
print_summary                 # Print summary

# Class methods
TwoDProjector.project(board, target_container)
TwoDProjector.project_all(boards, target_container)
TwoDProjector.project_and_layout(boards, target_container, spacing)
```

---

## Integration Points

### With Phase 2 (Board Detection)

```ruby
# Scan boards
scanner = BoardScanner.new
boards = scanner.scan_all_boards.select(&:valid?)

# Project boards
projector = TwoDProjector.new
two_d_groups = projector.project_boards(boards, n2)
```

### With Phase 2.5 (Edge Banding)

```ruby
# Projection automatically includes edge banding
two_d_group = projector.project_board(board, n2)
# Edge banding triangles are drawn on the 2D projection
```

### With Phase 4 (Nesting Engine)

```ruby
# Nesting engine will use 2D groups
two_d_groups.each do |group|
  # Find placement position
  position = nesting_engine.find_placement(group)

  # Place group
  group.place_at(position[:x], position[:y], position[:rotation])

  # Check overlaps
  if group.overlaps_with?(other_group)
    # Find different position
  end
end
```

---

## Performance Considerations

### Area Calculation
- **Complexity**: O(n) where n = number of vertices
- **Typical**: 4-32 vertices (fast)
- **Worst case**: Complex polygons with 100+ vertices (still fast)

### Point-in-Polygon
- **Complexity**: O(n) per query
- **Optimization**: Use bounding box check first

### Overlap Detection
- **Fast path**: Bounding box check O(1)
- **Slow path**: Vertex checks O(n*m)
- **Optimization**: Check bounding boxes first

---

## Known Limitations

1. **No curved edges**: Circles/arcs are approximated with line segments
2. **No holes**: Assumes simple polygons (no interior holes)
3. **2D only**: No 3D nesting support
4. **Single front face**: Assumes one front face per board

---

## What's Next: Phase 4

Phase 4 will implement the nesting engine:

1. **Sheet Model** - Represent nesting sheets
2. **GapCalculator Service** - Find empty spaces in sheets
3. **NestingEngine Service** - Place boards in gaps
4. **Collision detection** - Use overlap detection
5. **Rotation** - Try different rotations
6. **Optimization** - Minimize waste

---

## Summary

Phase 3 is complete with:

✅ **TwoDGroup Model** (340 lines)
- Outline management
- Geometric calculations
- Nesting state tracking
- Overlap detection

✅ **TwoDProjector Service** (280 lines)
- Face outline projection
- Edge banding integration
- Label cloning
- Grid layout

✅ **Key Algorithms**
- Shoelace formula for area
- Ray casting for point-in-polygon
- Bounding box optimization
- Grid layout with wrapping

✅ **Complete Testing** (350 lines)
- 10 test scenarios
- Full coverage

✅ **Documentation** (this file)
- API reference
- Usage examples
- Algorithm explanations

**Status**: Phase 3 Complete ✅
**Ready for**: Phase 4 - Nesting Engine 🚀

---

**Last Updated**: 2025-11-27
