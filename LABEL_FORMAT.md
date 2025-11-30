# Label Format - Text-Based Visual Labels

**Date**: 2025-11-30
**Version**: 0.1.0-dev

---

## Overview

The label system uses **3D text entities** to create readable, scalable labels on board faces. Each label contains multiple text components arranged horizontally with a directional arrow.

---

## Label Components

The visual label drawn on the front face includes four main components:

```
[1] - [Board_Name] →
 ↑      ↑       ↑   ↑
 │      │       │   └─ Direction Arrow
 │      │       └───── Instance Name (5.0mm)
 │      └─────────────── Separator (5.0mm)
 └──────────────────── Index Number (6.0mm)
```

All components are positioned horizontally in a single line with automatic spacing.

---

## 1. Index Number

**Purpose**: Sequential board numbering for identification

**Format**: 3D text, filled, bold
**Base Height**: 6.0mm
**Position**: Leftmost component
**Vertical Offset**: +4.0mm above baseline

**Examples**:
- `1`
- `14`
- `105`

**Attributes**:
- Matches `[ABF] "board-index"` attribute
- Auto-incremented when labeling (finds max existing index)
- Used for board identification

**Implementation**:
```ruby
TextDrawer.draw_text(entities, index.to_s, 6.0, false)
```

---

## 2. Separator

**Purpose**: Visual separator between index and instance name

**Format**: 3D text, filled
**Character**: Single dash "-"
**Base Height**: 5.0mm
**Position**: Between index and instance name
**Spacing**: 2.0mm from index number
**Vertical Offset**: +4.0mm above baseline

**Implementation**:
```ruby
TextDrawer.draw_text(entities, "-", 5.0, false)
```

---

## 3. Instance Name

**Purpose**: Shows the board's entity name from SketchUp

**Format**: 3D text, filled
**Base Height**: 5.0mm
**Position**: After separator
**Spacing**: 2.0mm from separator
**Vertical Offset**: +4.0mm above baseline

**Examples**:
- `Board_1`
- `Panel_Top`
- `Shelf_Mid`
- `Cabinet_Side_Left`

**Source**:
- Taken from `board.entity.name`
- If no name or empty: defaults to "Board"
- No truncation - full name is displayed

**Implementation**:
```ruby
TextDrawer.draw_text(entities, instance_name, 5.0, false)
```

---

## 4. Direction Arrow

**Purpose**: Indicates face height direction and label orientation

**Format**: Vector geometry (lines and edges)
**Length**: Dynamic - matches total text width + 5.0mm
**Arrow Head**: 5.0mm V-shape
**Position**: Below text baseline (Y = 0)

**Components**:
1. **Main Line**: Horizontal line from origin to arrow end
2. **Arrow Head**: Two angled lines forming V-shape
   - Left line: -5.0mm X, -2.5mm Y from arrow end
   - Right line: -5.0mm X, +2.5mm Y from arrow end

**Direction**:
- Points in face height direction
- Rotated to align with face coordinate system
- Indicates grain flow and orientation

**Implementation**:
```ruby
def draw_vector_arrow(label_group, total_text_width)
  arrow_length = total_text_width
  arrow_end = origin.offset(x_axis, arrow_length)

  entities.add_line(origin, arrow_end)

  head_left = arrow_end.offset(x_axis, -5.mm).offset(y_axis, -2.5.mm)
  head_right = arrow_end.offset(x_axis, -5.mm).offset(y_axis, 2.5.mm)

  entities.add_line(arrow_end, head_left)
  entities.add_line(arrow_end, head_right)
end
```

---

## Label Layout & Positioning

### Horizontal Layout

All text components are positioned relative to each other:

```ruby
# Index at origin
index_group.bounds.min.x = 0

# Separator after index
separator.bounds.min.x = index_bounds.max.x + 2.0.mm

# Instance name after separator
instance_name.bounds.min.x = separator_bounds.max.x + 2.0.mm

# Arrow spans full width
arrow_length = instance_name_bounds.max.x - index_bounds.min.x + 5.0.mm
```

### Vertical Positioning

All text components are offset upward from the baseline:

```ruby
offset_text_up(text_group, 4.0.mm)
```

The arrow remains at Y = 0 (baseline level).

### Total Width Calculation

The arrow length is calculated to span the entire label:

```ruby
def calculate_total_text_width(index_bounds, separator_bounds, instance_name_bounds)
  all_bounds = [index_bounds, separator_bounds, instance_name_bounds].compact
  return ARROW_LENGTH.mm if all_bounds.empty?

  min_x = all_bounds.map { |b| b.min.x }.min
  max_x = all_bounds.map { |b| b.max.x }.max
  total_width = max_x - min_x

  [total_width, ARROW_LENGTH.mm].max + 5.0.mm
end
```

---

## Automatic Scaling

Labels are automatically scaled to fit the face with proper margins.

### Scaling Algorithm

```ruby
def calculate_scale_factor(front_face, label_width, label_height)
  face_width_mm = front_face.width.to_f
  face_height_mm = front_face.height.to_f

  # Define 10mm border on each side
  border_offset_mm = 10.0
  total_offset_mm = border_offset_mm * 2.0

  # Calculate available space
  available_width_mm = face_width_mm - total_offset_mm
  available_height_mm = face_height_mm - total_offset_mm

  # Calculate scale factors
  scale_x = available_width_mm / label_width
  scale_y = available_height_mm / label_height

  # Use minimum scale, cap at 6.0x
  max_scale = 6.0
  [[scale_x, scale_y].min, max_scale].min
end
```

### Scale Application

```ruby
def apply_scale(label_group, scale_factor)
  label_center = label_group.bounds.center
  scale_transform = Geom::Transformation.scaling(
    label_center,
    scale_factor,
    scale_factor,
    scale_factor
  )
  label_group.transform!(scale_transform)
end
```

### Margin Rules

- **Minimum margin**: 10.0mm on all sides
- **Maximum scale**: 6.0x (prevents oversized labels)
- **Uniform scaling**: Same factor for width and height

### Debug Output

The scaling process outputs detailed debug information:

```
=== SCALE_LABEL DEBUG ===
Raw bounds dimensions:
  X: 45.32 mm
  Y: 12.15 mm
  Z: 0.00 mm
Label dimensions BEFORE scale:
  label_width: 12.15 mm
  label_height: 45.32 mm
Face dimensions:
  face_width: 400.00 mm
  face_height: 600.00 mm
Calculated scale_factor: 6.0000
Expected after scaling:
  scaled_width: 72.90 mm
  scaled_height: 271.92 mm
  margin_width: 163.55 mm
  margin_height: 164.04 mm
Label dimensions AFTER scale:
  label_width: 72.90 mm
  label_height: 271.92 mm
Actual margins after scaling:
  margin_width: 163.55 mm
  margin_height: 164.04 mm
=== END SCALE_LABEL DEBUG ===
```

---

## Label Rotation & Alignment

Labels undergo multiple transformations to ensure proper alignment with the face.

### Rotation Process

**1. Face Alignment Transform**
```ruby
def create_face_alignment_transform(face_normal)
  z_local = Geom::Vector3d.new(0, 0, 1)
  rotation_axis = (z_local * face_normal).normalize
  angle = z_local.angle_between(face_normal)

  Geom::Transformation.rotation(
    Geom::Point3d.new(0, 0, 0),
    rotation_axis,
    angle
  )
end
```

**2. Arrow Alignment Transform**
```ruby
def create_arrow_alignment_transform(face_normal, height_direction, face_alignment_transform)
  arrow_local = Geom::Vector3d.new(1, 0, 0)
  arrow_world = transform_vector(arrow_local, face_alignment_transform)
  arrow_in_plane = project_to_plane(arrow_world, face_normal)

  height_in_plane = project_to_plane(height_direction.normalize, face_normal)

  angle = arrow_in_plane.angle_between(height_in_plane)
  cross_product = arrow_in_plane * height_in_plane
  angle = -angle if cross_product.dot(face_normal) < 0

  Geom::Transformation.rotation(
    Geom::Point3d.new(0, 0, 0),
    face_normal,
    angle
  )
end
```

**3. User Rotation Transform**
```ruby
def create_user_rotation_transform(face_normal, rotation_degrees)
  rotation_radians = (rotation_degrees + 180) * Math::PI / 180.0

  Geom::Transformation.rotation(
    Geom::Point3d.new(0, 0, 0),
    face_normal,
    rotation_radians
  )
end
```

### Combined Transform

```ruby
rotation_transform = user_rotation_transform *
                     arrow_alignment_transform *
                     face_alignment_transform

final_transform = translation_transform * rotation_transform
label_group.transform!(final_transform)
```

### User Rotation Values

- `0°` - Default orientation (arrow points in height direction)
- `90°` - Rotated 90° clockwise
- `180°` - Arrow points opposite direction
- `270°` - Rotated 270° clockwise

---

## Label Dimensions

Labels provide dimension information in multiple coordinate systems.

### Local Dimensions

```ruby
def local_dimensions
  label_bounds = @entity.bounds

  x_dim = (label_bounds.max.x - label_bounds.min.x) / 1.mm
  y_dim = (label_bounds.max.y - label_bounds.min.y) / 1.mm
  z_dim = (label_bounds.max.z - label_bounds.min.z) / 1.mm

  # Select two largest non-zero dimensions
  non_zero_dims = [x_dim, y_dim, z_dim].select { |d| d > 0.1 }.sort

  {
    width: non_zero_dims[0],
    height: non_zero_dims[1]
  }
end
```

### Face Space Dimensions

```ruby
def label_dimensions_in_face_space
  label_bounds = @entity.bounds
  face = @board.front_face

  face_width_dir = face.width_direction
  face_height_dir = face.height_direction

  # Get all 8 corners of bounding box
  corners = [
    label_bounds.corner(0), label_bounds.corner(1),
    label_bounds.corner(2), label_bounds.corner(3),
    label_bounds.corner(4), label_bounds.corner(5),
    label_bounds.corner(6), label_bounds.corner(7)
  ]

  # Project corners onto face axes
  width_projections = corners.map { |c|
    c.to_a.zip(face_width_dir.to_a).map { |a, b| a * b }.sum
  }
  height_projections = corners.map { |c|
    c.to_a.zip(face_height_dir.to_a).map { |a, b| a * b }.sum
  }

  label_width = (width_projections.max - width_projections.min) / 1.mm
  label_height = (height_projections.max - height_projections.min) / 1.mm

  # Ensure width < height by swapping if needed
  if label_width > label_height
    label_width, label_height = label_height, label_width
    face_width_dir, face_height_dir = face_height_dir, face_width_dir
  end

  {
    width: label_width,
    height: label_height,
    width_direction: face_width_dir,
    height_direction: face_height_dir
  }
end
```

### Direction Vectors

```ruby
def width_direction
  transform = @entity.transformation
  origin = Geom::Point3d.new(0, 0, 0)
  x_axis_point = Geom::Point3d.new(1, 0, 0)

  transformed_origin = transform * origin
  transformed_x = transform * x_axis_point

  width_vec = transformed_x - transformed_origin
  width_vec.normalize if width_vec.length > 0.001
  width_vec
end

def height_direction
  transform = @entity.transformation
  origin = Geom::Point3d.new(0, 0, 0)
  y_axis_point = Geom::Point3d.new(0, 1, 0)

  transformed_origin = transform * origin
  transformed_y = transform * y_axis_point

  height_vec = transformed_y - transformed_origin
  height_vec.normalize if height_vec.length > 0.001
  height_vec
end
```

---

## Label Attributes

The label group has these ABF attributes:

```ruby
[ABF] "is-label" => true
[ABF] "label-index" => 14
[ABF] "label-rotation" => 0          # degrees (user offset)
[ABF] "label-scale" => 2.5           # if scaled (!= 1.0)
```

---

## Text Drawing Implementation

### TextDrawer Service

Labels use the `TextDrawer` service for creating 3D text:

```ruby
class TextDrawer
  DEFAULT_HEIGHT = 10.0
  DEFAULT_FONT = 'Arial'
  DEFAULT_BOLD = false
  DEFAULT_ITALIC = false
  DEFAULT_FILLED = true
  MM_TO_INCHES = 25.4

  def self.draw_text(entities, text, height = DEFAULT_HEIGHT, filled = DEFAULT_FILLED)
    text = convert_to_string(text)
    return create_empty_group(entities) if text.nil? || text.empty?

    height_mm = convert_height_to_mm(height)
    height_inches = height_mm / MM_TO_INCHES

    text_group = create_empty_group(entities)
    text_group.entities.add_3d_text(
      text, 1, DEFAULT_FONT, DEFAULT_BOLD, DEFAULT_ITALIC,
      height_inches, 0.0, 0.0, filled, 0.0
    )

    flatten_group(text_group)
  end
end
```

### Geometry Flattening

3D text is flattened to 2D geometry for performance:

```ruby
def flatten_group(group)
  GeometryFlattener.flatten_group(group)
end
```

This converts 3D text faces into flat edge geometry on the label plane.

---

## Examples

### Example 1: Simple Board

```
Board name: "Board_1"
Index: 7
Rotation: 0°

Label shows:
7 - Board_1 →
```

### Example 2: Named Board

```
Board name: "Cabinet_Top"
Index: 14
Rotation: 0°

Label shows:
14 - Cabinet_Top →
```

### Example 3: Long Name

```
Board name: "Very_Long_Board_Name_For_Cabinet_Side_Left_Panel"
Index: 105
Rotation: 0°

Label shows:
105 - Very_Long_Board_Name_For_Cabinet_Side_Left_Panel →
(No truncation - full name is displayed and scaled to fit)
```

### Example 4: Scaled Label

```
Board: 800mm × 1200mm face
Index: 3
Name: "Panel"
Base label size: 45mm × 12mm

Scale calculation:
  available_width = 800 - 20 = 780mm
  available_height = 1200 - 20 = 1180mm
  scale_x = 780 / 45 = 17.33
  scale_y = 1180 / 12 = 98.33
  scale_factor = min(17.33, 98.33, 6.0) = 6.0

Final label size: 270mm × 72mm
Margins: ~265mm (width), ~564mm (height)
```

---

## Integration with Board Model

The `Label` model is a child of `PersistentEntity`:

```ruby
class Label < PersistentEntity
  attr_reader :parent, :rotation, :board

  ARROW_LENGTH = 25.0
  ARROW_HEAD = 5.0

  def initialize(board, label_index)
    @board = board
    @label_index = label_index

    @entity = create_label_group
    raise "Failed to create label group" unless @entity

    scale_label
    move_label_to_face(@entity)

    super(@entity)
    @parent = board
    @rotation = @board.label_rotation
  end
end
```

---

## Usage

Labels are automatically drawn when you use "Label Extra Boards":

```
1. Select board(s)
2. Click: Plugins → GG Extra Nesting → Label Extra Boards
3. Labels automatically drawn on front faces with:
   - Index numbers
   - Instance names
   - Direction arrows
   - Automatic scaling
   - Proper rotation
```

**Re-labeling**: Labels are redrawn if board is labeled again

**Unlabeling**: Labels are removed when unlabeling board

---

## Files

**Model**: [gg_extra_nesting/models/label.rb](gg_extra_nesting/models/label.rb:1)

**Services**:
- [gg_extra_nesting/services/text_drawer.rb](gg_extra_nesting/services/text_drawer.rb:1) - 3D text drawing
- [gg_extra_nesting/services/geometry_flattener.rb](gg_extra_nesting/services/geometry_flattener.rb:1) - Text flattening

**Tools**: [gg_extra_nesting/tools/label_tool.rb](gg_extra_nesting/tools/label_tool.rb:1) - User interface

---

**Last Updated**: 2025-11-30
