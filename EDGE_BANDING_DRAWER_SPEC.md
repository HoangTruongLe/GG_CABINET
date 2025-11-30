# EdgeBandingDrawer Service - Technical Specification

**Phase**: 3 (2D Projection)
**Status**: Specification ✅
**Date**: 2025-11-27

---

## Overview

The **EdgeBandingDrawer** service draws triangular indicators on 2D projections to show which edges have edge banding applied. It reads edge banding information from the board and side faces, offsets cutting lines, and places isosceles triangle markers.

---

## Edge Banding Data Structure

### Board Attribute: `edge-band-types`

**Location**: `board.entity.get_attribute('ABF', 'edge-band-types')`

**Format**: Array of edge banding definitions
```ruby
[
  id,              # Integer - Edge banding ID
  name,            # String  - Edge banding name (e.g., "CHỈ", "Dán Tay 01")
  thickness,       # Float   - Thickness in mm (e.g., 1.0, 0.1)
  color,           # String  - Color hex code (e.g., "#b36ea9")
  unknown1,        # Integer - Unknown parameter
  id2,             # Integer - Second ID (duplicate or reference)
  name2,           # String  - Second name (duplicate or reference)
  thickness2,      # Float   - Second thickness (duplicate or reference)
  color2,          # String  - Second color (duplicate or reference)
  unknown2         # Integer - Unknown parameter
]
```

**Example**:
```ruby
[0, "CHỈ", 1.0, "#b36ea9", 0, 1, "Dán Tay 01", 0.1, "#c46b6b", 0]
```

**Parsed Structure**:
```ruby
{
  types: [
    {
      id: 0,
      name: "CHỈ",
      thickness: 1.0,
      color: "#b36ea9"
    },
    {
      id: 1,
      name: "Dán Tay 01",
      thickness: 0.1,
      color: "#c46b6b"
    }
  ]
}
```

### Side Face Attribute: `edge-band-id`

**Location**: `side_face.entity.get_attribute('ABF', 'edge-band-id')`

**Format**: Integer (references edge banding type ID)

**Example**:
```ruby
0  # References edge banding type with id=0 ("CHỈ", 1.0mm)
1  # References edge banding type with id=1 ("Dán Tay 01", 0.1mm)
```

---

## Algorithm Overview

### Step 1: Read Edge Banding Information

```ruby
# From board
edge_band_types = board.entity.get_attribute('ABF', 'edge-band-types')
# => [0, "CHỈ", 1.0, "#b36ea9", 0, 1, "Dán Tay 01", 0.1, "#c46b6b", 0]

# Parse into structured format
types = parse_edge_band_types(edge_band_types)
# => { 0 => {name: "CHỈ", thickness: 1.0, color: "#b36ea9"},
#      1 => {name: "Dán Tay 01", thickness: 0.1, color: "#c46b6b"} }
```

### Step 2: Find Side Faces with Edge Banding

```ruby
board.side_faces.each do |side_face|
  edge_band_id = side_face.entity.get_attribute('ABF', 'edge-band-id')

  if edge_band_id
    edge_band = types[edge_band_id]
    # Process this side face
  end
end
```

### Step 3: Find Common Edge with Front Face

```ruby
# Side face always shares exactly 1 edge with front face
common_edge = find_common_edge(side_face, front_face)

# Get edge vertices in 3D
v1 = common_edge.start.position
v2 = common_edge.end.position
```

### Step 4: Project Edge to 2D

```ruby
# Project 3D edge to 2D (XY plane)
v1_2d = project_to_xy(v1)  # => [x1, y1]
v2_2d = project_to_xy(v2)  # => [x2, y2]

# Edge in 2D
edge_2d = [v1_2d, v2_2d]
```

### Step 5: Offset Edge by Edge Banding Thickness

```ruby
thickness = edge_band.thickness  # e.g., 1.0mm

# Calculate offset direction (inward, perpendicular to edge)
edge_vector = [v2_2d[0] - v1_2d[0], v2_2d[1] - v1_2d[1]]
edge_length = Math.sqrt(edge_vector[0]**2 + edge_vector[1]**2)

# Perpendicular vector (inward toward board center)
perp = calculate_inward_perpendicular(edge_vector, board_center_2d)
perp_normalized = [perp[0] / edge_length, perp[1] / edge_length]

# Offset edge
v1_offset = [v1_2d[0] + perp_normalized[0] * thickness,
             v1_2d[1] + perp_normalized[1] * thickness]
v2_offset = [v2_2d[0] + perp_normalized[0] * thickness,
             v2_2d[1] + perp_normalized[1] * thickness]

# Update 2D outline with offset edge
```

### Step 6: Draw Triangle Marker

```ruby
# Triangle dimensions (isosceles)
base = 40.mm          # Base width
height = 56.mm        # Height
side = 40.mm          # Side length (isosceles)

# Calculate middle point of edge
edge_mid = [(v1_2d[0] + v2_2d[0]) / 2, (v1_2d[1] + v2_2d[1]) / 2]

# Position triangle base (offset inward from edge)
# Triangle apex will point back toward the edge
offset_distance = height * 0.5  # 28mm (50% of height)
triangle_base_center = [
  edge_mid[0] + perp_normalized[0] * offset_distance,
  edge_mid[1] + perp_normalized[1] * offset_distance
]

# Calculate triangle vertices
# Base is inward, apex points toward edge
triangle = calculate_triangle_vertices(
  triangle_base_center,
  edge_vector,
  base,
  height  # Apex will be -height from base (pointing outward toward edge)
)

# Draw triangle
draw_triangle(two_d_group, triangle, edge_band.color)
```

---

## Triangle Geometry

### Standard Triangle Dimensions

```
       Apex (height = 56mm from base)
         △
        ╱ ╲
       ╱   ╲     Side = 40mm (isosceles)
      ╱     ╲
     ╱       ╲
    ╱         ╲
   ╱___________╲
  Base = 40mm
```

**Dimensions**:
- Base width: 40mm
- Height: 56mm
- Side length: 40mm (isosceles triangle)

**Position**:
- Distance from edge: height/5 = 11.2mm
- Centered on edge midpoint
- Points toward board center

### Triangle Calculation

```ruby
def calculate_triangle_vertices(base_center, edge_vector, base_width, height)
  # Normalize edge vector
  edge_length = Math.sqrt(edge_vector[0]**2 + edge_vector[1]**2)
  edge_norm = [edge_vector[0] / edge_length, edge_vector[1] / edge_length]

  # Perpendicular (toward board center)
  perp = [-edge_norm[1], edge_norm[0]]  # Rotate 90°

  # Base left point
  base_left = [
    base_center[0] - edge_norm[0] * (base_width / 2),
    base_center[1] - edge_norm[1] * (base_width / 2)
  ]

  # Base right point
  base_right = [
    base_center[0] + edge_norm[0] * (base_width / 2),
    base_center[1] + edge_norm[1] * (base_width / 2)
  ]

  # Apex point (toward board center)
  apex = [
    base_center[0] + perp[0] * height,
    base_center[1] + perp[1] * height
  ]

  [base_left, base_right, apex]
end
```

### Triangle Scaling for Small Boards

```ruby
def scale_triangle_for_board(board_size, base, height)
  # Minimum edge length required for standard triangle
  min_edge_length = base * 1.5  # 60mm

  # If board edge is too small, scale triangle down
  if board_edge_length < min_edge_length
    scale_factor = board_edge_length / min_edge_length

    # Clamp to minimum 50% size
    scale_factor = [scale_factor, 0.5].max

    scaled_base = base * scale_factor
    scaled_height = height * scale_factor

    [scaled_base, scaled_height]
  else
    [base, height]
  end
end
```

**Scaling Rules**:
- Standard triangle: 40mm base, 56mm height
- Minimum edge length for standard: 60mm (base × 1.5)
- If edge < 60mm: scale proportionally
- Minimum scale: 50% (20mm base, 28mm height)
- Maximum scale: 100% (40mm base, 56mm height)

**Examples**:
| Edge Length | Scale | Base | Height |
|-------------|-------|------|--------|
| 100mm | 100% | 40mm | 56mm |
| 60mm | 100% | 40mm | 56mm |
| 50mm | 83% | 33mm | 46mm |
| 40mm | 67% | 27mm | 37mm |
| 30mm | 50% | 20mm | 28mm |
| 20mm | 50% | 20mm | 28mm |

---

## 2D Group Structure

### Without Edge Banding

```
2D Group (XY projection of front face)
├── Outline (closed loop)
│   ├── Edge 1
│   ├── Edge 2
│   ├── Edge 3
│   └── Edge 4
└── Label (if exists)
```

### With Edge Banding

```
2D Group (XY projection of front face)
├── Outline (closed loop with offset edges)
│   ├── Edge 1 (normal)
│   ├── Edge 2 (offset by 1.0mm) ← Has edge banding
│   ├── Edge 3 (normal)
│   └── Edge 4 (offset by 0.1mm) ← Has edge banding
├── Triangle Marker 1 (on Edge 2)
│   ├── Material: edge_band.color (#b36ea9)
│   └── Position: centered on Edge 2, 11.2mm inward
├── Triangle Marker 2 (on Edge 4)
│   ├── Material: edge_band.color (#c46b6b)
│   └── Position: centered on Edge 4, 11.2mm inward
└── Label (if exists)
```

---

## Edge Detection

### Find Common Edge Between Side Face and Front Face

```ruby
def find_common_edge(side_face, front_face)
  side_edges = side_face.edges
  front_edges = front_face.edges

  # Find shared edge
  common = side_edges.find do |side_edge|
    front_edges.any? { |front_edge| front_edge == side_edge }
  end

  common
end
```

**Important**: Side face always shares exactly **1 edge** with front face.

### Determine Offset Direction

```ruby
def calculate_inward_perpendicular(edge_vector, board_center)
  # Two possible perpendicular directions
  perp1 = [-edge_vector[1], edge_vector[0]]   # Rotate 90° CCW
  perp2 = [edge_vector[1], -edge_vector[0]]   # Rotate 90° CW

  # Choose the one pointing toward board center
  # Calculate midpoint of edge
  edge_mid = [(v1[0] + v2[0]) / 2, (v1[1] + v2[1]) / 2]

  # Vector from edge to center
  to_center = [board_center[0] - edge_mid[0], board_center[1] - edge_mid[1]]

  # Dot product to determine which perpendicular points inward
  dot1 = perp1[0] * to_center[0] + perp1[1] * to_center[1]
  dot2 = perp2[0] * to_center[0] + perp2[1] * to_center[1]

  # Use the perpendicular with positive dot product (pointing inward)
  dot1 > dot2 ? perp1 : perp2
end
```

---

## Visual Examples

### Example 1: Rectangular Board with 2 Edge Bandings

```
3D Board (Front View):
┌─────────────────────┐
│                     │  ← Top: Edge banding "CHỈ" (1.0mm, #b36ea9)
│                     │
│     FRONT FACE      │
│                     │
│                     │  ← Bottom: Edge banding "Dán Tay 01" (0.1mm, #c46b6b)
└─────────────────────┘

2D Projection:
       ┌───────────────────┐  ← Offset inward 1.0mm
       │        △          │  ← Triangle marker (40x56mm, #b36ea9)
       │       ╱ ╲         │     11.2mm from edge
       │      ╱   ╲        │
       │                   │
       │                   │
       │        △          │  ← Triangle marker (40x56mm, #c46b6b)
       │       ╱ ╲         │     11.2mm from edge
       └───────────────────┘  ← Offset inward 0.1mm
```

### Example 2: Circular Board with Edge Banding

```
3D Board (Front View):
      ___________
    /             \
   |               |  ← Circular front face
   |               |
    \_____________/

Side face: Single curved surface with edge banding

2D Projection:
      ___________
    /      △      \  ← Arc offset by thickness
   |      ╱ ╲      |    Triangle at "top" of circle
   |               |    (relative to nesting orientation)
    \_____________/
```

**Note**: For circular/curved edges:
- Find tangent at midpoint
- Offset arc by thickness
- Place triangle perpendicular to tangent

---

## Implementation Classes

### EdgeBandingDrawer Service

```ruby
class EdgeBandingDrawer
  # Main method: Draw edge banding indicators on 2D group
  def draw_edge_banding(two_d_group, board, front_face)
    # 1. Parse edge banding types from board
    # 2. Find side faces with edge banding
    # 3. For each edge-banded side face:
    #    - Find common edge with front face
    #    - Offset edge in 2D
    #    - Draw triangle marker
  end

  # Parse edge banding types from attribute array
  def parse_edge_band_types(attr_array)
    # Parse [0, "CHỈ", 1.0, "#b36ea9", 0, 1, ...] format
  end

  # Find common edge between two faces
  def find_common_edge(face1, face2)
  end

  # Calculate inward perpendicular direction
  def calculate_inward_perpendicular(edge_vector, board_center)
  end

  # Calculate triangle vertices
  def calculate_triangle_vertices(base_center, edge_vector, base, height)
  end

  # Scale triangle for small boards
  def scale_triangle_for_board(edge_length)
  end

  # Draw triangle marker
  def draw_triangle(two_d_group, vertices, color)
  end
end
```

### EdgeBanding Model

```ruby
class EdgeBanding < PersistentEntity
  attr_reader :id, :name, :thickness, :color

  def initialize(id, name, thickness, color)
    @id = id
    @name = name
    @thickness = thickness.to_f  # mm
    @color = color               # Hex color
  end

  # Parse from board attribute
  def self.parse_from_board(board)
    attr = board.entity.get_attribute('ABF', 'edge-band-types')
    return [] unless attr

    # Parse array into EdgeBanding objects
    parse_array(attr)
  end

  # Parse attribute array
  def self.parse_array(array)
    # Array format: [id1, name1, thick1, color1, ?, id2, name2, thick2, color2, ?]
    # Pattern: every 5 elements is one edge banding definition

    edge_bandings = {}

    # Parse in groups of 5 (but there might be duplicates)
    # First set: indices 0-3 (id, name, thickness, color)
    # Second set: indices 5-8 (id, name, thickness, color)

    if array.length >= 4
      edge_bandings[array[0]] = new(array[0], array[1], array[2], array[3])
    end

    if array.length >= 9
      edge_bandings[array[5]] = new(array[5], array[6], array[7], array[8])
    end

    edge_bandings
  end
end
```

---

## Data Flow

```
Board (3D)
  │
  ├─── Attribute: 'edge-band-types' = [0, "CHỈ", 1.0, "#b36ea9", 0, ...]
  │                                      │
  │                                      └─> Parse into EdgeBanding objects
  │                                           { 0 => EdgeBanding(...), 1 => EdgeBanding(...) }
  │
  └─── Side Faces
         │
         ├─── Side Face 1: 'edge-band-id' = 0 ───┐
         │                                        │
         ├─── Side Face 2: 'edge-band-id' = nil  │
         │                                        │
         └─── Side Face 3: 'edge-band-id' = 1 ───┤
                                                  │
                                                  ▼
                            EdgeBandingDrawer.draw_edge_banding()
                                                  │
                                                  ├─> Find common edge with front face
                                                  ├─> Project to 2D
                                                  ├─> Offset edge by thickness
                                                  └─> Draw triangle marker
                                                  │
                                                  ▼
                                            2D Group (Updated)
                                                  │
                                                  ├─> Offset outline edges
                                                  └─> Triangle markers
```

---

## Attributes Reference

### Board Attributes

| Attribute | Type | Example | Description |
|-----------|------|---------|-------------|
| `edge-band-types` | Array | `[0, "CHỈ", 1.0, "#b36ea9", 0, 1, "Dán Tay 01", 0.1, "#c46b6b", 0]` | Edge banding type definitions |

**Format**: `[id1, name1, thickness1, color1, ?, id2, name2, thickness2, color2, ?]`

### Side Face Attributes

| Attribute | Type | Example | Description |
|-----------|------|---------|-------------|
| `edge-band-id` | Integer | `0` | References edge banding type ID |

---

## Edge Cases

### 1. No Edge Banding

```ruby
edge_band_types = board.entity.get_attribute('ABF', 'edge-band-types')
# => nil

# Skip edge banding processing
```

### 2. Empty Edge Banding Array

```ruby
edge_band_types = []
# => No types defined, skip processing
```

### 3. Side Face Without Edge Banding

```ruby
edge_band_id = side_face.entity.get_attribute('ABF', 'edge-band-id')
# => nil

# Skip this side face
```

### 4. Invalid Edge Banding ID

```ruby
edge_band_id = 5
edge_band_types = { 0 => {...}, 1 => {...} }

# ID 5 not found in types
# Log warning, skip this side face
```

### 5. Very Small Board

```ruby
edge_length = 20.mm
# => Scale triangle to 50% (20mm base, 28mm height)
```

### 6. Circular/Curved Front Face

```ruby
# Front face is circular
# Common edge is an arc
# Calculate tangent at arc midpoint
# Offset arc by thickness
# Place triangle perpendicular to tangent
```

---

## Testing Scenarios

### Test 1: Rectangular Board with 1 Edge Banding

```ruby
board:
  edge-band-types: [0, "CHỈ", 1.0, "#b36ea9", 0]
  side_face[0]: edge-band-id = 0 (top edge)
  side_face[1]: edge-band-id = nil (right edge)
  side_face[2]: edge-band-id = nil (bottom edge)
  side_face[3]: edge-band-id = nil (left edge)

Expected 2D:
  - Top edge offset inward by 1.0mm
  - Triangle at top center (40x56mm, #b36ea9)
  - Other edges normal
```

### Test 2: Rectangular Board with 2 Edge Bandings

```ruby
board:
  edge-band-types: [0, "CHỈ", 1.0, "#b36ea9", 0, 1, "Dán Tay 01", 0.1, "#c46b6b", 0]
  side_face[0]: edge-band-id = 0 (top edge, 1.0mm)
  side_face[2]: edge-band-id = 1 (bottom edge, 0.1mm)

Expected 2D:
  - Top edge offset inward by 1.0mm
  - Bottom edge offset inward by 0.1mm
  - Triangle at top center (#b36ea9)
  - Triangle at bottom center (#c46b6b)
```

### Test 3: Small Board (30mm x 30mm)

```ruby
board:
  dimensions: 30mm x 30mm
  edge-band-types: [0, "CHỈ", 1.0, "#b36ea9", 0]
  side_face[0]: edge-band-id = 0

Expected 2D:
  - Edge offset by 1.0mm
  - Triangle scaled to 50% (20mm base, 28mm height)
```

### Test 4: Circular Board

```ruby
board:
  front_face: circular (diameter 200mm)
  side_face: curved edge with edge-band-id = 0

Expected 2D:
  - Arc offset by thickness
  - Triangle at "top" (relative to nesting orientation)
```

---

## Visual Indicators Summary

| Element | Size | Position | Color | Purpose |
|---------|------|----------|-------|---------|
| **Triangle** | 40mm × 56mm (isosceles) | Edge midpoint, 11.2mm inward | Edge banding color | Indicates edge banding presence |
| **Offset Edge** | thickness mm | Inward from original edge | Same as outline | Shows cutting line adjustment |
| **Triangle Base** | 40mm | Parallel to edge | Edge banding color | Visual clarity |
| **Triangle Height** | 56mm | Perpendicular to edge | Edge banding color | Points toward board center |

---

## Implementation Priority

### Phase 3.1: Basic Edge Banding (Required)
1. ✅ EdgeBanding model - Parse from board attributes
2. ✅ Find side faces with edge banding
3. ✅ Find common edges with front face
4. ✅ Offset edges in 2D projection
5. ✅ Draw triangle markers (standard size)

### Phase 3.2: Advanced Features (Optional)
6. 🚧 Triangle scaling for small boards
7. 🚧 Curved edge support (circles, arcs)
8. 🚧 Edge banding color application
9. 🚧 Multiple edge bandings on same board

---

## API Design

### EdgeBandingDrawer Service

```ruby
# Main usage
drawer = EdgeBandingDrawer.new
drawer.draw_edge_banding(two_d_group, board, front_face)

# Class method (convenience)
EdgeBandingDrawer.draw(two_d_group, board, front_face)
```

### EdgeBanding Model

```ruby
# Parse from board
edge_bandings = EdgeBanding.parse_from_board(board)
# => { 0 => EdgeBanding(...), 1 => EdgeBanding(...) }

# Access properties
edge_band = edge_bandings[0]
edge_band.name        # => "CHỈ"
edge_band.thickness   # => 1.0
edge_band.color       # => "#b36ea9"
```

---

## Summary

This specification defines:

✅ **Data Structure**: Edge banding types and side face IDs
✅ **Algorithm**: Find edges, offset, draw triangles
✅ **Triangle Geometry**: 40×56mm isosceles, 11.2mm from edge
✅ **Scaling**: Proportional reduction for small boards
✅ **Edge Detection**: Find common edges between faces
✅ **2D Projection**: Offset cutting lines by thickness
✅ **Visual Markers**: Colored triangles at edge midpoints

**Status**: Specification Complete ✅
**Next Step**: Implementation of EdgeBanding model and EdgeBandingDrawer service

---

**Last Updated**: 2025-11-27
