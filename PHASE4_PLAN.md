# Phase 4 Plan: Nesting Engine

**Date**: 2025-11-28
**Status**: Planning

---

## Overview

Phase 4 implements the core nesting engine that places extra boards (2D projections) into existing nesting sheets. The system must find empty gaps in sheets and intelligently place boards while avoiding collisions.

---

## Prerequisites (Complete ✅)

- ✅ Phase 1: Playground system
- ✅ Phase 2: Board detection and classification
- ✅ Phase 2.5: Edge banding system
- ✅ Phase 3: 2D projection (TwoDGroup + TwoDProjector)
- ✅ Intersection detection and backface projection

---

## Phase 4 Components

### 1. Sheet Model Enhancement

**Current State**: Basic placeholder (~21 lines)

**Target State**: Full sheet management (~350 lines)

**Features to Implement**:
- ✅ Sheet detection from nesting root
- ✅ Material and thickness properties
- ✅ Existing boards detection (already nested)
- ✅ Available area calculation
- ✅ Gap detection and tracking
- ✅ Bounds calculation
- ✅ Validation
- ✅ Serialization

**Key Methods**:
```ruby
# Detection
sheet.detect_existing_boards    # Find boards already on sheet
sheet.calculate_available_area  # Total area - used area

# Gaps
sheet.gaps                      # Array of gap rectangles
sheet.largest_gap              # Biggest available space
sheet.find_gap_for_board(board_2d)  # Find suitable gap

# Properties
sheet.width
sheet.height
sheet.area
sheet.used_area
sheet.available_area
sheet.utilization_percentage

# Validation
sheet.valid?
sheet.can_fit?(board_2d)
```

---

### 2. GapCalculator Service

**Purpose**: Detect empty rectangular spaces in sheets where new boards can be placed

**Complexity**: This is the most challenging component - it must analyze 2D space and find usable gaps between existing boards.

**Features to Implement** (~400 lines):
- ✅ Scan sheet for existing boards
- ✅ Build occupancy grid or map
- ✅ Identify rectangular gaps
- ✅ Sort gaps by size/desirability
- ✅ Validate gap accessibility
- ✅ Handle rotation considerations

**Key Algorithms**:

1. **Grid-Based Gap Detection**:
   ```ruby
   # Divide sheet into grid cells
   # Mark occupied cells
   # Find contiguous empty regions
   # Convert regions to rectangles
   ```

2. **Bounding Box Subtraction**:
   ```ruby
   # Start with full sheet rectangle
   # Subtract each board's bounding box
   # Result = set of available rectangles
   ```

3. **Corner Detection**:
   ```ruby
   # Find all corners created by existing boards
   # Test each corner for available space
   # Build rectangles from corners
   ```

**Output**:
```ruby
[
  { x: 0, y: 0, width: 300, height: 200, area: 60000 },
  { x: 500, y: 0, width: 400, height: 300, area: 120000 },
  # ... sorted by area (largest first)
]
```

---

### 3. NestingEngine Service

**Purpose**: Main service that orchestrates the nesting process

**Features to Implement** (~500 lines):
- ✅ Find best sheet for each board
- ✅ Try multiple rotations (0°, 90°, 180°, 270°)
- ✅ Place board in gap
- ✅ Handle collision detection
- ✅ Optimize placement strategy
- ✅ Create new sheets if needed
- ✅ Batch processing
- ✅ Progress reporting

**Key Methods**:
```ruby
engine = NestingEngine.new(nesting_root)

# Single board
result = engine.nest_board(board_2d)
# => { success: true, sheet: sheet, position: {x, y, rotation} }

# Multiple boards
results = engine.nest_boards(boards_2d)
# => Array of placement results

# Strategy options
engine.allow_rotation = true
engine.prefer_existing_sheets = true
engine.create_new_sheets = true
engine.optimize_utilization = true
```

**Placement Algorithm**:
```ruby
def nest_board(board_2d)
  # 1. Get all sheets with matching material/thickness
  candidate_sheets = find_candidate_sheets(board_2d)

  # 2. For each sheet
  candidate_sheets.each do |sheet|
    # 3. Try rotations (0°, 90°, 180°, 270°)
    [0, 90, 180, 270].each do |rotation|
      # 4. Find gaps that can fit rotated board
      gaps = GapCalculator.find_gaps(sheet, board_2d, rotation)

      # 5. Try each gap (largest first)
      gaps.each do |gap|
        # 6. Test placement
        if can_place?(board_2d, sheet, gap, rotation)
          # 7. Place board
          place_board(board_2d, sheet, gap, rotation)
          return { success: true, sheet: sheet, gap: gap, rotation: rotation }
        end
      end
    end
  end

  # 8. No placement found - create new sheet
  if @create_new_sheets
    new_sheet = create_new_sheet(board_2d.material, board_2d.thickness)
    place_board(board_2d, new_sheet, { x: 0, y: 0 }, 0)
    return { success: true, sheet: new_sheet, new: true }
  end

  # 9. Failed
  { success: false, reason: "No suitable placement found" }
end
```

---

### 4. Collision Detection Enhancement

**Uses existing** `TwoDGroup#overlaps_with?` from Phase 3, but adds:
- ✅ Sheet boundary checking
- ✅ Minimum spacing between boards
- ✅ Rotation-aware collision testing

**Key Methods**:
```ruby
def can_place?(board_2d, sheet, position, rotation)
  # 1. Check sheet bounds
  return false unless within_sheet_bounds?(board_2d, sheet, position, rotation)

  # 2. Check spacing
  return false unless has_minimum_spacing?(board_2d, sheet, position, rotation)

  # 3. Check overlaps with existing boards
  sheet.boards_2d.each do |existing_board|
    return false if board_2d.overlaps_with?(existing_board)
  end

  true
end
```

---

## Implementation Strategy

### Step 1: Sheet Model Enhancement

**Priority**: High (foundation for everything else)

**Tasks**:
1. Add existing board detection
2. Implement area calculations
3. Add gap storage and management
4. Add validation logic
5. Add debug/print methods

**Estimated**: ~350 lines

---

### Step 2: GapCalculator Service

**Priority**: High (critical path)

**Approach**: Start with **simple corner-based detection**, then optimize

**Simple Algorithm** (v1):
```ruby
def find_gaps(sheet)
  gaps = []

  # Try corners of existing boards
  sheet.boards_2d.each do |board|
    # Test 4 corners: top-left, top-right, bottom-left, bottom-right
    corners = [
      { x: board.x, y: board.y + board.height },           # Top-left
      { x: board.x + board.width, y: board.y + board.height }, # Top-right
      { x: board.x, y: board.y - gap_height },             # Bottom-left
      { x: board.x + board.width, y: board.y - gap_height }  # Bottom-right
    ]

    corners.each do |corner|
      # Find maximum rectangle from this corner
      rect = find_max_rectangle_from_corner(corner, sheet)
      gaps << rect if rect[:area] > min_area
    end
  end

  # Sort by area (largest first)
  gaps.sort_by { |g| -g[:area] }
end
```

**Advanced Algorithm** (v2 - if needed):
- Sweep line algorithm
- Quadtree space partitioning
- R-tree spatial indexing

**Estimated**: ~400 lines

---

### Step 3: NestingEngine Service

**Priority**: Medium (depends on Sheet + GapCalculator)

**Tasks**:
1. Implement candidate sheet selection
2. Implement rotation logic
3. Implement gap selection
4. Implement placement logic
5. Implement new sheet creation
6. Add batch processing
7. Add progress reporting

**Estimated**: ~500 lines

---

### Step 4: Testing & Validation

**Test Scenarios**:

1. **Empty Sheet**: Place first board at (0, 0)
2. **Single Board on Sheet**: Find gap around existing board
3. **Multiple Boards**: Find best gap among several
4. **Rotation Required**: Board doesn't fit at 0° but fits at 90°
5. **No Space Available**: Return failure or create new sheet
6. **Different Materials**: Don't mix materials on same sheet
7. **Different Thicknesses**: Don't mix thicknesses on same sheet
8. **Batch Processing**: Nest 10+ boards efficiently

**Estimated**: ~500 lines test script

---

## Data Flow

### Complete Nesting Process

```
User selects extra boards
  │
  ├─→ BoardScanner.scan_unlabeled_boards
  │     │
  │     └─→ Returns array of Board objects
  │
  ├─→ TwoDProjector.project_boards
  │     │
  │     └─→ Returns array of TwoDGroup objects
  │
  ├─→ NestingEngine.new(nesting_root)
  │     │
  │     ├─→ Detect existing sheets
  │     └─→ Calculate available space
  │
  ├─→ NestingEngine.nest_boards(boards_2d)
  │     │
  │     ├─→ For each board:
  │     │     │
  │     │     ├─→ Find candidate sheets (material + thickness match)
  │     │     │
  │     │     ├─→ For each sheet:
  │     │     │     │
  │     │     │     ├─→ GapCalculator.find_gaps(sheet)
  │     │     │     │     │
  │     │     │     │     ├─→ Scan existing boards
  │     │     │     │     ├─→ Identify rectangular gaps
  │     │     │     │     └─→ Return sorted gaps
  │     │     │     │
  │     │     │     ├─→ Try rotations [0°, 90°, 180°, 270°]
  │     │     │     │
  │     │     │     ├─→ Test each gap:
  │     │     │     │     │
  │     │     │     │     ├─→ Check bounds
  │     │     │     │     ├─→ Check spacing
  │     │     │     │     └─→ Check overlaps
  │     │     │     │
  │     │     │     └─→ If fits: place_board()
  │     │     │
  │     │     └─→ If no fit: create new sheet
  │     │
  │     └─→ Return placement results
  │
  └─→ Update SketchUp model with new placements
```

---

## API Design

### Sheet

```ruby
sheet = Sheet.new(sketchup_group, nesting_root)

# Properties
sheet.material            # => "Oak Veneer"
sheet.thickness           # => 18.0 (mm)
sheet.width               # => 2440.0 (mm)
sheet.height              # => 1220.0 (mm)
sheet.area                # => 2976800.0 (mm²)

# Boards
sheet.boards_2d           # => Array<TwoDGroup>
sheet.add_board(board_2d)
sheet.remove_board(board_2d)

# Utilization
sheet.used_area           # => 1500000.0 (mm²)
sheet.available_area      # => 1476800.0 (mm²)
sheet.utilization         # => 0.504 (50.4%)

# Gaps
sheet.gaps                # => Array<Hash> {x, y, width, height, area}
sheet.largest_gap         # => Hash {x, y, width, height, area}
sheet.find_gap_for_board(board_2d, rotation)

# Validation
sheet.valid?
sheet.can_fit?(board_2d)
sheet.matches_material?(material)
sheet.matches_thickness?(thickness)
```

### GapCalculator

```ruby
calculator = GapCalculator.new(sheet)

# Find gaps
gaps = calculator.find_gaps
# => [
#   { x: 100, y: 200, width: 500, height: 400, area: 200000 },
#   { x: 0, y: 0, width: 300, height: 200, area: 60000 }
# ]

# Find gap for specific board
gap = calculator.find_gap_for_board(board_2d, rotation: 0)
gap = calculator.find_best_gap(board_2d, try_rotations: true)

# Options
calculator.min_gap_size = 100      # Minimum gap width/height (mm)
calculator.min_spacing = 5          # Minimum spacing between boards (mm)
calculator.allow_rotation = true    # Try 90° rotation
```

### NestingEngine

```ruby
engine = NestingEngine.new(nesting_root)

# Options
engine.allow_rotation = true
engine.create_new_sheets = true
engine.prefer_existing_sheets = true
engine.min_spacing = 5.mm

# Single board
result = engine.nest_board(board_2d)
# => {
#   success: true,
#   sheet: sheet,
#   position: { x: 100, y: 200, rotation: 90 },
#   gap_used: { x: 100, y: 200, width: 500, height: 400 }
# }

# Multiple boards
results = engine.nest_boards(boards_2d)
# => Array of result hashes

# Progress callback
engine.on_progress do |current, total, board|
  puts "Nesting #{current}/#{total}: #{board.classification_key}"
end

# Statistics
engine.print_summary
# Output:
# Nesting Summary:
#   Total boards: 25
#   Successfully nested: 23
#   Failed: 2
#   New sheets created: 1
#   Average utilization: 68.5%
```

---

## Gap Detection Algorithms Comparison

### Option 1: Corner-Based (Simple)

**Pros**:
- Easy to implement
- Fast for small number of boards (<20)
- Intuitive logic

**Cons**:
- May miss some gaps
- Not optimal for complex layouts

**Complexity**: O(n²) where n = number of boards

### Option 2: Grid-Based

**Pros**:
- Finds all gaps
- Handles complex shapes
- Good for visualization

**Cons**:
- Memory intensive
- Slower for large sheets
- Grid resolution affects accuracy

**Complexity**: O(w × h) where w,h = grid dimensions

### Option 3: Sweep Line

**Pros**:
- Optimal gap finding
- Efficient for many boards
- Academic algorithm

**Cons**:
- Complex to implement
- Overkill for typical use case

**Complexity**: O(n log n)

**Recommendation**: **Start with Option 1 (Corner-Based)**, optimize later if needed.

---

## Edge Cases to Handle

1. **Board Too Large**: Board doesn't fit on any standard sheet
   - **Solution**: Report error, suggest custom sheet size

2. **No Material Match**: No sheets with matching material
   - **Solution**: Create new sheet with correct material

3. **Thickness Mismatch**: Boards with different thicknesses
   - **Solution**: Create separate sheets per thickness

4. **Rotation Constraints**: Some boards can't be rotated (grain direction)
   - **Solution**: Add `allow_rotation` property to Board/TwoDGroup

5. **Minimum Spacing**: Boards need spacing for saw blade
   - **Solution**: Add spacing parameter (default 5mm)

6. **Sheet Boundary**: Board partially off sheet
   - **Solution**: Validate bounds before placement

7. **Floating Point Precision**: Rounding errors in calculations
   - **Solution**: Use tolerance (0.1mm) for comparisons

---

## Performance Targets

**For typical cabinet project** (50 extra boards, 10 existing sheets):

| Operation | Target | Acceptable |
|-----------|--------|------------|
| Find gaps in sheet | <50ms | <200ms |
| Test single placement | <5ms | <20ms |
| Nest single board | <100ms | <500ms |
| Nest 50 boards | <5s | <15s |
| Create new sheet | <50ms | <100ms |

**Optimization strategies**:
- Cache gap calculations
- Use bounding box pre-checks
- Sort boards by size (largest first)
- Limit rotation attempts if not needed

---

## Testing Plan

### Unit Tests

```ruby
# Sheet Model
describe Sheet do
  it 'detects existing boards'
  it 'calculates used area correctly'
  it 'calculates available area'
  it 'validates material match'
  it 'validates thickness match'
end

# GapCalculator
describe GapCalculator do
  it 'finds gaps in empty sheet'
  it 'finds gaps around single board'
  it 'finds gaps around multiple boards'
  it 'sorts gaps by area'
  it 'respects minimum gap size'
  it 'respects minimum spacing'
end

# NestingEngine
describe NestingEngine do
  it 'nests board on empty sheet'
  it 'nests board in gap'
  it 'tries rotations when needed'
  it 'creates new sheet when needed'
  it 'matches material and thickness'
  it 'handles batch nesting'
end
```

### Integration Tests

```ruby
# Full workflow
describe 'Complete Nesting Workflow' do
  it 'nests extra boards into existing layout' do
    # 1. Load model with nesting root
    # 2. Scan extra boards
    # 3. Project to 2D
    # 4. Nest into sheets
    # 5. Verify placements
  end
end
```

---

## File Structure

**New Files**:
```
gg_extra_nesting/
├── models/
│   └── sheet.rb (enhanced)          ~350 lines
│
└── services/
    ├── gap_calculator.rb (new)      ~400 lines
    └── nesting_engine.rb (new)      ~500 lines

test_phase4.rb (new)                 ~500 lines
PHASE4_COMPLETE.md (new)             ~400 lines
```

**Total New Code**: ~2,150 lines

---

## Success Criteria

Phase 4 is complete when:

- ✅ Sheet model can detect and track existing boards
- ✅ GapCalculator can find available spaces in sheets
- ✅ NestingEngine can place boards in gaps
- ✅ Rotation logic works (0°, 90°, 180°, 270°)
- ✅ Collision detection prevents overlaps
- ✅ Material/thickness matching works
- ✅ New sheet creation works
- ✅ Batch processing works
- ✅ All tests pass
- ✅ Documentation complete

---

## Implementation Order

### Priority 1: Foundation (Week 1)
1. ✅ Sheet model enhancement
2. ✅ Basic gap detection (corner-based)
3. ✅ Simple placement logic

### Priority 2: Core Features (Week 2)
4. ✅ Rotation support
5. ✅ Collision detection refinement
6. ✅ Material/thickness matching

### Priority 3: Advanced Features (Week 3)
7. ✅ Gap detection optimization
8. ✅ Batch processing
9. ✅ Progress reporting

### Priority 4: Polish (Week 4)
10. ✅ Performance optimization
11. ✅ Comprehensive testing
12. ✅ Documentation

---

## Risks & Mitigation

| Risk | Impact | Mitigation |
|------|--------|------------|
| Gap detection too slow | High | Start simple, optimize later |
| Placement algorithm inefficient | Medium | Cache calculations, use heuristics |
| Too many edge cases | Medium | Comprehensive testing, validation |
| Poor utilization | Low | Iterative improvement, user feedback |

---

## Next Steps

1. ✅ Review and approve this plan
2. ✅ Start with Sheet model enhancement
3. ✅ Implement basic GapCalculator
4. ✅ Build simple NestingEngine
5. ✅ Test with real data
6. ✅ Iterate and improve

---

**Status**: Plan Complete - Ready for Implementation
**Estimated Timeline**: 3-4 weeks
**Total Code**: ~2,150 lines

---

**Last Updated**: 2025-11-28
