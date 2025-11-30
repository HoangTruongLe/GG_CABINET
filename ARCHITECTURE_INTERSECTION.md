# Intersection Architecture - Refactored Design

**Date**: 2025-11-28
**Status**: Refactored ✅

---

## Overview

The intersection detection system has been refactored into a clean, object-oriented architecture with proper separation of concerns across three models: **Board**, **Face**, and **Intersection**.

---

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                          Board                               │
│  ┌────────────────────────────────────────────────────────┐ │
│  │ Responsibilities:                                       │ │
│  │ - Owns multiple Face objects                          │ │
│  │ - Delegates intersection queries to Face              │ │
│  │ - Aggregates intersection data from all faces         │ │
│  └────────────────────────────────────────────────────────┘ │
│                            │                                 │
│                            │ has many                        │
│                            ▼                                 │
│  ┌────────────────────────────────────────────────────────┐ │
│  │                        Face                            │ │
│  │  ┌──────────────────────────────────────────────────┐ │ │
│  │  │ Responsibilities:                                 │ │ │
│  │  │ - Detects intersection groups on this face       │ │ │
│  │  │ - Creates Intersection objects                   │ │ │
│  │  │ - Caches intersection list                       │ │ │
│  │  └──────────────────────────────────────────────────┘ │ │
│  │                          │                             │ │
│  │                          │ has many                    │ │
│  │                          ▼                             │ │
│  │  ┌──────────────────────────────────────────────────┐ │ │
│  │  │                 Intersection                      │ │ │
│  │  │  ┌────────────────────────────────────────────┐ │ │ │
│  │  │  │ Responsibilities:                          │ │ │ │
│  │  │  │ - Validates layer name                     │ │ │ │
│  │  │  │ - Detects face location (plane test)      │ │ │ │
│  │  │  │ - Provides edge access                     │ │ │ │
│  │  │  │ - Encapsulates all intersection logic     │ │ │ │
│  │  │  └────────────────────────────────────────────┘ │ │ │
│  │  └──────────────────────────────────────────────────┘ │ │
│  └────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

---

## Model Responsibilities

### 1. **Intersection Model** ([intersection.rb](gg_extra_nesting/models/intersection.rb))

The Intersection model is the **core** of the intersection system. It encapsulates all intersection-specific logic.

#### Responsibilities:
- ✅ Layer name validation (`ABF*` or `_ABF*`)
- ✅ Face location detection (bounding box plane test)
- ✅ Edge access and counting
- ✅ Validation and error checking

#### Key Methods:

```ruby
class Intersection < PersistentEntity
  # Class method: Validate layer name
  def self.valid_intersection_layer?(tag_name)
    # Returns true if layer starts with ABF/_ABF
    # Excludes: _ABF_Label, _ABF_side*, ABF_Label, ABF_side*
  end

  # Instance method: Determine which face this intersection lies on
  def detect_face_location
    # Returns 'front', 'back', or nil
    # Caches result for performance
  end

  # Instance method: Check if intersection lies on specific face
  def lies_on_face?(face)
    # Bounding box plane test
    # Returns true if >= 4 bbox vertices on face plane
  end

  # Properties
  def layer_name      # => String (e.g., "ABF_groove")
  def edges           # => Array of Sketchup::Edge
  def edge_count      # => Integer
  def face_location   # => 'front', 'back', or nil
end
```

#### Algorithm: Bounding Box Plane Test

```ruby
def lies_on_face?(face)
  # 1. Get face plane equation: Ax + By + Cz = D
  face_plane = face.plane
  normal = Geom::Vector3d.new(face_plane[0], face_plane[1], face_plane[2])
  d = face_plane[3]

  # 2. Get all 8 corners of bounding box
  bounds = @entity.bounds
  bbox_points = [
    bounds.min,
    Geom::Point3d.new(bounds.max.x, bounds.min.y, bounds.min.z),
    # ... 6 more corners
    bounds.max
  ]

  # 3. Count vertices on plane (within 1mm tolerance)
  vertices_on_plane = bbox_points.count do |pt|
    distance = normal.dot(pt) - d
    distance.abs < 1.mm
  end

  # 4. If >= 4 vertices on plane, intersection lies on this face
  vertices_on_plane >= 4
end
```

---

### 2. **Face Model** ([face.rb](gg_extra_nesting/models/face.rb))

The Face model **detects and creates** Intersection objects for intersections that lie on it.

#### Responsibilities:
- ✅ Detect intersection groups on this specific face
- ✅ Create Intersection objects
- ✅ Cache intersection list for performance
- ✅ Provide has_intersections? query

#### Key Methods:

```ruby
class Face < PersistentEntity
  attr_reader :board, :intersections

  # Public API
  def intersections
    @intersections ||= detect_intersections  # Lazy-loaded and cached
  end

  def has_intersections?
    intersections.any?
  end

  private

  # Detection logic
  def detect_intersections
    return [] unless board_entity_valid?

    # 1. Find all groups in board with valid intersection layers
    board_groups.each_with_object([]) do |group, collection|
      tag_name = group.layer&.name
      next unless Intersection.valid_intersection_layer?(tag_name)

      # 2. Create Intersection object
      intersection = Intersection.new(group, @board)

      # 3. Check if it lies on THIS face
      next unless intersection.lies_on_face?(@entity)

      # 4. Detect which face it's on (front/back)
      intersection.detect_face_location

      # 5. Add to collection
      collection << intersection
    end
  end
end
```

#### Flow:

```
Face.intersections called
  │
  ├─→ Get all groups from board
  │
  ├─→ Filter by valid intersection layer (ABF*/_ ABF*)
  │
  ├─→ Create Intersection object for each
  │
  ├─→ Test if intersection lies on THIS face (plane test)
  │
  ├─→ Detect face location (front/back)
  │
  └─→ Return array of Intersection objects
```

---

### 3. **Board Model** ([board.rb](gg_extra_nesting/models/board.rb))

The Board model **delegates** intersection queries to its Face objects and **aggregates** the results.

#### Responsibilities:
- ✅ Delegate intersection queries to Face objects
- ✅ Aggregate intersections from all faces
- ✅ Provide convenience methods for front/back face intersections

#### Key Methods:

```ruby
class Board < PersistentEntity
  # Class method: Delegates to Intersection model
  def self.is_intersection_layer?(tag_name)
    Intersection.valid_intersection_layer?(tag_name)
  end

  # Instance methods: Delegate to Face objects
  def has_intersections?
    @faces.any?(&:has_intersections?)
  end

  def has_front_intersections?
    @front_face&.has_intersections? || false
  end

  def has_back_intersections?
    @back_face&.has_intersections? || false
  end

  # Aggregation methods
  def intersections
    @faces.flat_map(&:intersections)  # All intersections from all faces
  end

  def front_intersections
    @front_face ? @front_face.intersections : []
  end

  def back_intersections
    @back_face ? @back_face.intersections : []
  end
end
```

#### Delegation Flow:

```
board.has_intersections?
  │
  └─→ @faces.any?(&:has_intersections?)
        │
        └─→ face.has_intersections?
              │
              └─→ face.intersections.any?
                    │
                    └─→ detect_intersections (if not cached)
                          │
                          └─→ Creates Intersection objects
```

---

## Data Flow

### Example: Checking if a board has intersections

```ruby
board = Board.new(board_entity)

# User calls
board.has_back_intersections?

# Flow:
# 1. Board: @back_face&.has_intersections?
# 2. Face: intersections.any?
# 3. Face: detect_intersections (if not cached)
#    a. Find all groups in board
#    b. Filter by valid intersection layer
#    c. Create Intersection objects
#    d. Test each with lies_on_face?(@entity)
#    e. Cache results in @intersections
# 4. Face: Return cached @intersections.any?
# 5. Board: Return result
```

### Example: Getting all front face intersections

```ruby
board = Board.new(board_entity)
intersections = board.front_intersections

# Returns: Array of Intersection objects
intersections.each do |intersection|
  puts intersection.layer_name      # => "ABF_groove"
  puts intersection.edge_count      # => 4
  puts intersection.face_location   # => "front"

  intersection.edges.each do |edge|
    # Access SketchUp edges directly
  end
end
```

---

## Benefits of This Architecture

### ✅ **1. Separation of Concerns**

Each model has a single, clear responsibility:
- **Intersection**: Knows about layer validation and face location
- **Face**: Knows about detecting intersections on itself
- **Board**: Knows about aggregating from multiple faces

### ✅ **2. Encapsulation**

All intersection logic is contained in the Intersection model:
- Layer name validation
- Bounding box plane test
- Edge access

### ✅ **3. Lazy Loading & Caching**

Face model caches intersections for performance:
```ruby
def intersections
  @intersections ||= detect_intersections  # Only detect once
end
```

### ✅ **4. Testability**

Each model can be tested independently:
- Test Intersection.valid_intersection_layer? in isolation
- Test Face.detect_intersections with mock boards
- Test Board.has_intersections? with mock faces

### ✅ **5. Extensibility**

Easy to add new features:
- Add intersection types (groove, cutout, etc.)
- Add intersection area calculation
- Add intersection transformation

---

## API Reference

### Intersection

```ruby
# Class methods
Intersection.valid_intersection_layer?(tag_name)  # => Boolean

# Instance methods
intersection = Intersection.new(group, board)
intersection.detect_face_location                  # => 'front', 'back', or nil
intersection.lies_on_face?(face)                   # => Boolean
intersection.layer_name                            # => String
intersection.edges                                 # => Array<Sketchup::Edge>
intersection.edge_count                            # => Integer
intersection.face_location                         # => 'front', 'back', or nil
intersection.valid?                                # => Boolean
intersection.print_info                            # Debug output
```

### Face

```ruby
# Instance methods
face = Face.new(sketchup_face, board)
face.intersections                  # => Array<Intersection> (cached)
face.has_intersections?             # => Boolean
```

### Board

```ruby
# Class methods
Board.is_intersection_layer?(tag_name)  # => Boolean (delegates to Intersection)

# Instance methods
board = Board.new(board_entity)
board.has_intersections?             # => Boolean
board.has_front_intersections?       # => Boolean
board.has_back_intersections?        # => Boolean
board.intersections                  # => Array<Intersection> (all faces)
board.front_intersections            # => Array<Intersection> (front face only)
board.back_intersections             # => Array<Intersection> (back face only)
```

---

## Usage Examples

### Example 1: Check if Board Has Intersections

```ruby
board = Board.new(board_entity)

if board.has_intersections?
  puts "Board has intersections"

  puts "Front face: #{board.has_front_intersections?}"
  puts "Back face: #{board.has_back_intersections?}"
end
```

### Example 2: List All Intersections

```ruby
board = Board.new(board_entity)

board.intersections.each do |intersection|
  puts "Intersection: #{intersection.layer_name}"
  puts "  Location: #{intersection.face_location}"
  puts "  Edges: #{intersection.edge_count}"
  puts "  Valid: #{intersection.valid?}"
end
```

### Example 3: Access Intersection Edges

```ruby
board = Board.new(board_entity)

board.back_intersections.each do |intersection|
  puts "#{intersection.layer_name} on back face:"

  intersection.edges.each do |edge|
    length = edge.length / 1.mm
    start_pt = edge.start.position
    end_pt = edge.end.position

    puts "  Edge: #{start_pt} → #{end_pt} (#{length.round(2)} mm)"
  end
end
```

### Example 4: Validate Intersection Layer

```ruby
# Class method - no instance needed
Intersection.valid_intersection_layer?('ABF_groove')        # => true
Intersection.valid_intersection_layer?('_ABF_cutout')       # => true
Intersection.valid_intersection_layer?('_ABF_Label')        # => false
Intersection.valid_intersection_layer?('ABF_side1')         # => false
Intersection.valid_intersection_layer?('Untagged')          # => false

# Or use Board wrapper
Board.is_intersection_layer?('ABF_groove')  # => true
```

### Example 5: Debug Intersection

```ruby
board = Board.new(board_entity)
intersection = board.front_intersections.first

# Print detailed info
intersection.print_info

# Output:
# ======================================================================
# INTERSECTION INFO
# ======================================================================
#
# Entity: Group#123
# Entity ID: 456
#
# Layer:
#   Name: ABF_groove
#   Valid intersection layer: true
#
# Location:
#   Face: front
#   Board: Board#789
#
# Geometry:
#   Edge count: 4
#   Bounds: (0, 0, 0), (100, 50, 0)
#
# Validation:
#   Status: ✓ VALID
# ======================================================================
```

---

## Performance Considerations

### ✅ **Caching**

Face model caches intersection detection:
```ruby
def intersections
  @intersections ||= detect_intersections  # Detect only once
end
```

### ✅ **Lazy Loading**

Intersections are only detected when requested:
```ruby
board.has_intersections?  # Triggers detection if not cached
board.has_intersections?  # Uses cached result
```

### ✅ **Efficient Plane Test**

Bounding box test is O(8) - very fast:
- 8 bbox vertices checked
- Simple dot product calculation
- 1mm tolerance for floating point

---

## Testing Strategy

### Unit Tests

**Intersection Model:**
```ruby
# Test layer validation
Intersection.valid_intersection_layer?('ABF_groove')  # => true
Intersection.valid_intersection_layer?('_ABF_Label')  # => false

# Test face location detection
intersection = Intersection.new(group, board)
intersection.detect_face_location  # => 'front' or 'back'

# Test plane test
intersection.lies_on_face?(front_face)  # => true
intersection.lies_on_face?(side_face)   # => false
```

**Face Model:**
```ruby
# Test intersection detection
face = Face.new(sketchup_face, board)
intersections = face.intersections  # => Array<Intersection>
face.has_intersections?             # => Boolean

# Test caching
face.intersections.object_id  # => 12345
face.intersections.object_id  # => 12345 (same object)
```

**Board Model:**
```ruby
# Test delegation
board = Board.new(board_entity)
board.has_intersections?        # Delegates to faces
board.has_front_intersections?  # Delegates to front_face
board.has_back_intersections?   # Delegates to back_face

# Test aggregation
board.intersections             # Aggregates from all faces
board.front_intersections       # From front face only
board.back_intersections        # From back face only
```

---

## Summary

✅ **Clean Architecture**
- Three models with clear responsibilities
- Intersection logic encapsulated in Intersection model
- Face model handles detection
- Board model aggregates results

✅ **Performance Optimized**
- Lazy loading
- Result caching
- Efficient plane test (O(8))

✅ **Highly Testable**
- Each model independently testable
- Clear interfaces between models
- Mock-friendly design

✅ **Maintainable**
- Single Responsibility Principle
- Don't Repeat Yourself
- Easy to extend

✅ **Well-Documented**
- Clear API
- Usage examples
- Architecture diagrams

---

**Last Updated**: 2025-11-28
