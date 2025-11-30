# Phase 2.5 Complete: Settings & Edge Banding

**Date**: 2025-11-27
**Status**: Complete ✅

---

## Summary

Phase 2.5 adds two critical features for the nesting system:

1. **SettingsManager Service** - Manage nesting settings (sheet size, tool diameter, clearance, etc.)
2. **EdgeBanding Model & Drawer** - Parse and visualize edge banding indicators on 2D projections

---

## 1. SettingsManager Service ✅

### Features

✅ **Auto-detection from N1** - Read settings from existing N1 nesting root
✅ **User overrides** - Allow manual configuration of all settings
✅ **Persistence** - Save/load settings from database
✅ **Validation** - Ensure settings are valid before use
✅ **Source tracking** - Know where each setting came from (default/N1/user)
✅ **Calculated values** - Total spacing, usable area, etc.

### Settings Managed

| Setting | Auto-detect | User Override | Default |
|---------|-------------|---------------|---------|
| Sheet Width | ✅ From N1 bounds | ✅ | 2440mm |
| Sheet Height | ✅ From N1 bounds | ✅ | 1220mm |
| Tool Diameter | ✅ From board spacing | ✅ | 6mm |
| Clearance | ✅ From board spacing | ✅ | 2mm |
| Border Gap | ✅ From board positions | ✅ | 10mm |
| Allow Rotation | ❌ User only | ✅ | false |
| Allow Nesting Inside | ❌ User only | ✅ | false |

### Usage Examples

```ruby
# Read from N1 automatically
settings = GG_Cabinet::ExtraNesting::SettingsManager.read_from_n1

# Access settings
puts "Sheet: #{settings.sheet_width} x #{settings.sheet_height} mm"
puts "Tool: #{settings.tool_diameter} mm"
puts "Total spacing: #{settings.total_spacing} mm"
puts "Usable area: #{settings.usable_width} x #{settings.usable_height} mm"

# User overrides
settings.set_sheet_dimensions(3000, 1500)
settings.set_tool_diameter(4)
settings.set_allow_rotation(true)

# Print settings
settings.print_settings

# Validate
if settings.valid?
  puts "Settings are valid"
else
  puts "Errors: #{settings.validation_errors.join(', ')}"
end
```

### Files

- [gg_extra_nesting/services/settings_manager.rb](gg_extra_nesting/services/settings_manager.rb) (470 lines)
- [test_settings.rb](test_settings.rb) (260 lines)
- [SETTINGS_MANAGER.md](SETTINGS_MANAGER.md) (600+ lines documentation)

---

## 2. EdgeBanding Model & Drawer ✅

### Features

✅ **Parse edge banding attributes** - Read from board and side face attributes
✅ **Multiple edge banding types** - Support for multiple types on one board
✅ **Color conversion** - Hex color to SketchUp color
✅ **Geometry calculations** - Find common edges, calculate perpendiculars
✅ **Triangle markers** - Draw isosceles triangles (40×56mm)
✅ **Triangle scaling** - Scale for small boards (minimum 50%)
✅ **Offset edges** - Offset cutting lines by edge banding thickness

### Edge Banding Data Structure

**Board Attribute**: `edge-band-types`
```ruby
[0, "CHỈ", 1.0, "#b36ea9", 0, 1, "Dán Tay 01", 0.1, "#c46b6b", 0]
```

**Parsed**:
```ruby
{
  0 => EdgeBanding(id: 0, name: "CHỈ", thickness: 1.0mm, color: "#b36ea9"),
  1 => EdgeBanding(id: 1, name: "Dán Tay 01", thickness: 0.1mm, color: "#c46b6b")
}
```

**Side Face Attribute**: `edge-band-id`
```ruby
side_face.get_attribute('ABF', 'edge-band-id')  # => 0 (references type 0)
```

### Triangle Specifications

**Standard Dimensions**:
- Base: 40mm
- Height: 56mm
- Side: 40mm (isosceles)

**Position**:
- Distance from edge: 11.2mm (height/5)
- Centered on edge midpoint
- Points toward board center

**Scaling**:
| Edge Length | Scale | Base | Height |
|-------------|-------|------|--------|
| 100mm | 100% | 40mm | 56mm |
| 60mm | 100% | 40mm | 56mm |
| 50mm | 83% | 33mm | 46mm |
| 40mm | 67% | 27mm | 37mm |
| 30mm | 50% | 20mm | 28mm |

### Usage Examples

```ruby
# Parse edge banding from board
edge_bandings = GG_Cabinet::ExtraNesting::EdgeBanding.parse_from_board(board)
# => { 0 => EdgeBanding(...), 1 => EdgeBanding(...) }

# Access properties
edge_band = edge_bandings[0]
puts edge_band.name        # => "CHỈ"
puts edge_band.thickness   # => 1.0
puts edge_band.color       # => "#b36ea9"

# Convert color
color = edge_band.sketchup_color  # => Sketchup::Color

# Draw edge banding on 2D group
drawer = GG_Cabinet::ExtraNesting::EdgeBandingDrawer.new
drawer.draw_edge_banding(two_d_group, board, front_face)

# Or use class method
GG_Cabinet::ExtraNesting::EdgeBandingDrawer.draw(two_d_group, board, front_face)

# Check if board has edge banding
has_eb = GG_Cabinet::ExtraNesting::EdgeBandingDrawer.has_edge_banding?(board)
```

### Visual Example

```
2D Projection with Edge Banding:

   ┌───────────────────────────────────┐ ← Top edge offset 1.0mm
   │              △                    │ ← Triangle (40×56mm, #b36ea9)
   │             ╱ ╲                   │    11.2mm from edge
   │            ╱   ╱                  │
   │                                   │
   │          Front Face               │
   │                                   │
   │              △                    │ ← Triangle (40×56mm, #c46b6b)
   │             ╱ ╱                   │
   └───────────────────────────────────┘ ← Bottom edge offset 0.1mm
```

### Files

- [gg_extra_nesting/models/edge_banding.rb](gg_extra_nesting/models/edge_banding.rb) (158 lines)
- [gg_extra_nesting/services/edge_banding_drawer.rb](gg_extra_nesting/services/edge_banding_drawer.rb) (340 lines)
- [test_edge_banding.rb](test_edge_banding.rb) (340 lines)
- [EDGE_BANDING_DRAWER_SPEC.md](EDGE_BANDING_DRAWER_SPEC.md) (900+ lines specification)
- [EDGE_BANDING_VISUAL.md](EDGE_BANDING_VISUAL.md) (500+ lines visual guide)

---

## Key Algorithms

### 1. Tool Diameter Auto-Detection

```ruby
# Find boards in N1
boards = find_boards_in_n1

# Calculate spacing between adjacent boards
spacings = calculate_board_spacing(boards)
avg_spacing = spacings.sum / spacings.count

# Spacing = tool_diameter + clearance
# Match to common tool diameters: [2, 3, 4, 5, 6, 8, 10, 12]
common_tools = [2, 3, 4, 5, 6, 8, 10, 12]
tool_dia = common_tools.find { |d| (avg_spacing - d) >= 0.5 && (avg_spacing - d) <= 5.0 }

# Remaining is clearance
clearance = avg_spacing - tool_dia
```

### 2. Edge Banding Triangle Placement

```ruby
# 1. Find common edge between side face and front face
common_edge = find_common_edge(side_face, front_face)

# 2. Project to 2D
v1_2d = project_to_xy(common_edge.start.position)
v2_2d = project_to_xy(common_edge.end.position)

# 3. Calculate inward perpendicular
edge_vector = [v2_2d[0] - v1_2d[0], v2_2d[1] - v1_2d[1]]
perp = calculate_inward_perpendicular(edge_vector, edge_mid, board_center)

# 4. Offset edge by thickness
v1_offset = [v1_2d[0] + perp[0] * thickness, v1_2d[1] + perp[1] * thickness]
v2_offset = [v2_2d[0] + perp[0] * thickness, v2_2d[1] + perp[1] * thickness]

# 5. Place triangle at edge midpoint, offset inward by height/5
triangle_base_center = [
  edge_mid[0] + perp[0] * (height / 5.0),
  edge_mid[1] + perp[1] * (height / 5.0)
]

# 6. Calculate triangle vertices
vertices = calculate_triangle_vertices(triangle_base_center, edge_vector, perp, base, height)

# 7. Draw triangle face
draw_triangle_face(two_d_group, vertices, edge_band.color)
```

### 3. Inward Perpendicular Calculation

```ruby
def calculate_inward_perpendicular(edge_vector, edge_mid, board_center)
  # Two possible perpendiculars
  perp1 = [-edge_vector[1], edge_vector[0]]   # 90° CCW
  perp2 = [edge_vector[1], -edge_vector[0]]   # 90° CW

  # Vector from edge to center
  to_center = [board_center[0] - edge_mid[0], board_center[1] - edge_mid[1]]

  # Dot product determines which points inward
  dot1 = perp1[0] * to_center[0] + perp1[1] * to_center[1]
  dot2 = perp2[0] * to_center[0] + perp2[1] * to_center[1]

  # Return perpendicular with positive dot product
  dot1 > dot2 ? perp1 : perp2
end
```

---

## Testing

### SettingsManager Tests

```ruby
load 'c:/Users/KB5007253/Desktop/tools/GG_ExtraNesting/test_settings.rb'
```

**Test Coverage**:
1. ✅ Create with defaults
2. ✅ Read from N1
3. ✅ User overrides
4. ✅ Validation
5. ✅ Calculated values
6. ✅ Reset settings
7. ✅ Persistence (save/load)
8. ✅ Tool diameter guessing
9. ✅ Class methods
10. ✅ Serialization

### EdgeBanding Tests

```ruby
load 'c:/Users/KB5007253/Desktop/tools/GG_ExtraNesting/test_edge_banding.rb'
```

**Test Coverage**:
1. ✅ Parse edge banding array
2. ✅ EdgeBanding model
3. ✅ Empty/invalid arrays
4. ✅ Multiple edge bandings
5. ✅ Geometry calculations
6. ✅ Triangle scaling
7. ✅ Triangle vertices
8. ✅ Read from real boards
9. ✅ Class methods
10. ✅ Serialization

---

## Integration Points

### With Nesting Engine (Phase 4)

```ruby
# Use settings
settings = SettingsManager.current

sheet = Sheet.new(
  width: settings.usable_width,
  height: settings.usable_height
)

spacing = settings.total_spacing

if settings.allow_rotation?
  # Try rotated positions
end
```

### With 2D Projection (Phase 3)

```ruby
# Draw 2D projection
two_d_group = create_2d_group(board, front_face)

# Add edge banding indicators
EdgeBandingDrawer.draw(two_d_group, board, front_face)
```

---

## Documentation

| Document | Lines | Purpose |
|----------|-------|---------|
| [SETTINGS_MANAGER.md](SETTINGS_MANAGER.md) | 600+ | Complete settings guide |
| [EDGE_BANDING_DRAWER_SPEC.md](EDGE_BANDING_DRAWER_SPEC.md) | 900+ | Technical specification |
| [EDGE_BANDING_VISUAL.md](EDGE_BANDING_VISUAL.md) | 500+ | Visual diagrams |

---

## Code Statistics

### New Files Created

| File | Lines | Type |
|------|-------|------|
| settings_manager.rb | 470 | Service |
| edge_banding.rb | 158 | Model |
| edge_banding_drawer.rb | 340 | Service |
| test_settings.rb | 260 | Test |
| test_edge_banding.rb | 340 | Test |
| SETTINGS_MANAGER.md | 600+ | Docs |
| EDGE_BANDING_DRAWER_SPEC.md | 900+ | Docs |
| EDGE_BANDING_VISUAL.md | 500+ | Docs |

**Total**: ~3,500 lines of code and documentation

### Updated Files

- [gg_extra_nesting/extra_nesting.rb](gg_extra_nesting/extra_nesting.rb) - Added requires
- [PROJECT_STATUS.md](PROJECT_STATUS.md) - Updated status

---

## API Summary

### SettingsManager

```ruby
# Create and read from N1
settings = SettingsManager.read_from_n1

# Getters
settings.sheet_width
settings.sheet_height
settings.tool_diameter
settings.clearance
settings.border_gap
settings.allow_rotation?
settings.allow_nesting_inside?
settings.total_spacing
settings.usable_width
settings.usable_height

# Setters (user overrides)
settings.set_sheet_dimensions(width, height)
settings.set_tool_diameter(dia)
settings.set_clearance(clearance)
settings.set_border_gap(gap)
settings.set_allow_rotation(bool)
settings.set_allow_nesting_inside(bool)

# Reset
settings.reset_setting(:sheet_width)
settings.reset_all

# Validation
settings.valid?
settings.validation_errors

# Display
settings.print_settings
settings.to_hash

# Persistence
settings.save_to_db
settings.load_from_db

# Class methods
SettingsManager.current
SettingsManager.print_current
```

### EdgeBanding

```ruby
# Parse from board
edge_bandings = EdgeBanding.parse_from_board(board)
# => { 0 => EdgeBanding(...), 1 => EdgeBanding(...) }

# Parse from array
edge_bandings = EdgeBanding.parse_array(attr_array)

# Get from side face
edge_band_id = EdgeBanding.get_edge_band_id(side_face)
has_eb = EdgeBanding.has_edge_banding?(side_face)

# Instance methods
edge_band.id
edge_band.name
edge_band.thickness
edge_band.color
edge_band.valid?
edge_band.sketchup_color
edge_band.print_info
edge_band.to_hash
```

### EdgeBandingDrawer

```ruby
# Draw edge banding
drawer = EdgeBandingDrawer.new
drawer.draw_edge_banding(two_d_group, board, front_face)

# Class methods
EdgeBandingDrawer.draw(two_d_group, board, front_face)
EdgeBandingDrawer.get_edge_bandings(board)
EdgeBandingDrawer.has_edge_banding?(board)

# Debug
drawer.print_edge_banding_info(board)
```

---

## What's Next: Phase 3

Phase 3 will implement 2D projection:

1. **TwoDGroup Model** - Represent 2D projections of boards
2. **TwoDProjector Service** - Project 3D boards to XY plane
3. **Label Cloning** - Clone labels with rotation
4. **Integration** - Combine with EdgeBandingDrawer

---

## Summary

Phase 2.5 is complete with:

✅ **SettingsManager Service** (470 lines)
- Auto-detect from N1
- User overrides
- Persistence
- Validation
- Calculated values

✅ **EdgeBanding Model** (158 lines)
- Parse attributes
- Multiple types
- Color conversion
- Validation

✅ **EdgeBandingDrawer Service** (340 lines)
- Geometry calculations
- Triangle markers
- Edge offsetting
- Scaling for small boards

✅ **Comprehensive Testing** (600 lines)
- 20 test scenarios
- Full coverage

✅ **Complete Documentation** (2000+ lines)
- Technical specifications
- Visual guides
- API reference
- Usage examples

**Status**: Phase 2.5 Complete ✅
**Ready for**: Phase 3 - 2D Projection 🚀

---

**Last Updated**: 2025-11-27
