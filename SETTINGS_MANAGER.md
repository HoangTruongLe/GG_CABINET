# SettingsManager Service

**Phase 2.5**: Settings Management for Extra Nesting

---

## Overview

The `SettingsManager` service manages all nesting settings for the Extra Nesting plugin. It reads settings from the N1 nesting root, allows user overrides, and persists settings to the database.

### Key Features

- ✅ **Auto-detect from N1**: Read sheet dimensions, tool diameter, clearance, and border gap from existing N1 nesting
- ✅ **User overrides**: Allow users to manually set any value
- ✅ **Smart defaults**: Sensible defaults for all settings
- ✅ **Persistence**: Save/load settings from database
- ✅ **Source tracking**: Track whether each setting came from N1, user, or default
- ✅ **Validation**: Validate settings before use
- ✅ **Calculated values**: Derive total spacing, usable area, etc.

---

## Settings Reference

### Sheet Dimensions

| Setting | Type | Default | Source |
|---------|------|---------|--------|
| `sheet_width` | Float (mm) | 2440.0 | N1 bounds or user override |
| `sheet_height` | Float (mm) | 1220.0 | N1 bounds or user override |

**Auto-detection**: Read from N1 nesting root bounds.

**User override**:
```ruby
settings.set_sheet_dimensions(3000, 1500)
```

---

### Tool Settings

| Setting | Type | Default | Source |
|---------|------|---------|--------|
| `tool_diameter` | Float (mm) | 6.0 | Calculated from N1 board spacing or user override |
| `clearance` | Float (mm) | 2.0 | Calculated from N1 board spacing or user override |

**Auto-detection**:
- Calculate spacing between adjacent boards in N1
- Spacing = tool_diameter + clearance
- Match common tool diameters: [2, 3, 4, 5, 6, 8, 10, 12] mm
- Remaining spacing becomes clearance

**User override**:
```ruby
settings.set_tool_diameter(4)
settings.set_clearance(2.5)
```

**Common Tool Diameters**:
- 2mm - Very fine cuts
- 3mm - Fine cuts
- 4mm - Standard small diameter
- 5mm - Standard medium diameter
- 6mm - Most common (default)
- 8mm - Large diameter
- 10mm - Extra large
- 12mm - Very large

---

### Border Gap

| Setting | Type | Default | Source |
|---------|------|---------|--------|
| `border_gap` | Float (mm) | 10.0 | Calculated from N1 board positions or user override |

**Auto-detection**: Minimum distance from any board edge to N1 boundary.

**User override**:
```ruby
settings.set_border_gap(15)
```

---

### Nesting Behavior

| Setting | Type | Default | Source |
|---------|------|---------|--------|
| `allow_rotation` | Boolean | false | User only |
| `allow_nesting_inside` | Boolean | false | User only |

**User override**:
```ruby
settings.set_allow_rotation(true)
settings.set_allow_nesting_inside(false)
```

---

## Usage Examples

### Basic Usage

```ruby
# Create settings manager
settings = GG_Cabinet::ExtraNesting::SettingsManager.new

# Read from N1
settings.read_from_n1

# Print settings
settings.print_settings
```

### Read from N1 Automatically

```ruby
# Find N1 and read settings
settings = GG_Cabinet::ExtraNesting::SettingsManager.read_from_n1

# Access settings
puts "Sheet: #{settings.sheet_width} x #{settings.sheet_height} mm"
puts "Tool: #{settings.tool_diameter} mm"
puts "Clearance: #{settings.clearance} mm"
puts "Border: #{settings.border_gap} mm"
```

### User Overrides

```ruby
settings = GG_Cabinet::ExtraNesting::SettingsManager.new

# Override sheet dimensions
settings.set_sheet_dimensions(3000, 1500)

# Override tool settings
settings.set_tool_diameter(4)
settings.set_clearance(3)

# Override border gap
settings.set_border_gap(20)

# Enable rotation
settings.set_allow_rotation(true)

# Settings are automatically saved to DB
```

### Reset to N1 or Default

```ruby
# Reset single setting
settings.reset_setting(:sheet_width)
settings.reset_setting(:tool_diameter)

# Reset all settings
settings.reset_all
```

### Get Current Settings

```ruby
# Get current settings (loads from DB)
settings = GG_Cabinet::ExtraNesting::SettingsManager.current

# Or use class method
GG_Cabinet::ExtraNesting::SettingsManager.print_current
```

---

## Calculated Values

The SettingsManager provides several calculated values:

### Total Spacing

```ruby
settings.total_spacing
# = tool_diameter + clearance
# Example: 6mm tool + 2mm clearance = 8mm total spacing
```

### Usable Area

```ruby
settings.usable_width
# = sheet_width - (2 * border_gap)
# Example: 2440mm - (2 * 10mm) = 2420mm

settings.usable_height
# = sheet_height - (2 * border_gap)
# Example: 1220mm - (2 * 10mm) = 1200mm
```

---

## How Settings are Detected from N1

### 1. Sheet Dimensions

```ruby
# Read N1 bounds
bounds = n1_root.bounds
width = bounds.width
height = bounds.height
```

### 2. Tool Diameter & Clearance

```ruby
# Find all boards in N1
boards = n1_root.entities.select { |e| e.get_attribute('ABF', 'is-board') }

# Sort by X position
sorted = boards.sort_by { |b| b.bounds.min.x }

# Calculate spacing between consecutive boards
spacings = []
sorted.each_cons(2) do |board1, board2|
  gap = board2.bounds.min.x - board1.bounds.max.x
  spacings << gap
end

# Average spacing
avg_spacing = spacings.sum / spacings.count

# Match to common tool diameter
common_tools = [2, 3, 4, 5, 6, 8, 10, 12]
tool_dia = common_tools.find { |d| (avg_spacing - d) >= 0.5 && (avg_spacing - d) <= 5.0 }

# Remaining is clearance
clearance = avg_spacing - tool_dia
```

### 3. Border Gap

```ruby
# Find minimum distance from any board to N1 boundary
n1_bounds = n1_root.bounds

min_gap = boards.map { |board|
  board_bounds = board.bounds
  [
    board_bounds.min.x - n1_bounds.min.x,  # Left
    n1_bounds.max.x - board_bounds.max.x,  # Right
    board_bounds.min.y - n1_bounds.min.y,  # Front
    n1_bounds.max.y - board_bounds.max.y   # Back
  ].min
}.min
```

---

## Setting Sources

Each setting tracks its source:

| Source | Meaning |
|--------|---------|
| `'default'` | Using hardcoded default value |
| `'n1'` | Detected from N1 nesting root |
| `'user'` | User override (takes precedence) |

**Priority**: User > N1 > Default

```ruby
# Check source
puts settings.settings[:sheet_width_source]
# => "user" or "n1" or "default"
```

---

## Validation

### Validation Rules

A settings configuration is valid if:

1. ✅ Sheet width > 0
2. ✅ Sheet height > 0
3. ✅ Tool diameter > 0
4. ✅ Clearance >= 0
5. ✅ Border gap >= 0
6. ✅ Usable width > 0 (sheet_width - 2*border_gap > 0)
7. ✅ Usable height > 0 (sheet_height - 2*border_gap > 0)

### Check Validation

```ruby
if settings.valid?
  puts "Settings are valid"
else
  puts "Errors:"
  settings.validation_errors.each { |err| puts "  - #{err}" }
end
```

---

## Persistence

Settings are automatically saved to the database when changed:

```ruby
# Auto-saved on every change
settings.set_sheet_dimensions(3000, 1500)  # Saves to DB

# Manual save (if needed)
settings.save_to_db

# Load from DB
settings.load_from_db
```

**Database key**: `settings:nesting_settings`

---

## API Reference

### Constructor

```ruby
SettingsManager.new
```

Creates a new settings manager with default values and loads from DB if available.

---

### Instance Methods

#### N1 Detection

```ruby
find_n1_root(model = Sketchup.active_model)
# Find N1 nesting root in model
# Returns: Sketchup::Group or nil

read_from_n1(n1_root = nil)
# Read all settings from N1
# Returns: settings hash

read_sheet_dimensions_from_n1
# Read sheet dimensions from N1 bounds

read_tool_settings_from_n1
# Calculate tool diameter and clearance from board spacing

read_border_gap_from_n1
# Calculate border gap from board positions
```

#### User Overrides

```ruby
set_sheet_dimensions(width, height)
# Set sheet dimensions (user override)

set_tool_diameter(diameter)
# Set tool diameter (user override)

set_clearance(clearance)
# Set clearance (user override)

set_border_gap(gap)
# Set border gap (user override)

set_allow_rotation(allow)
# Enable/disable rotation

set_allow_nesting_inside(allow)
# Enable/disable nesting inside parts
```

#### Reset

```ruby
reset_setting(key)
# Reset single setting to N1 or default
# Keys: :sheet_width, :sheet_height, :tool_diameter, :clearance, :border_gap

reset_all
# Reset all settings
```

#### Getters

```ruby
sheet_width          # => Float (mm)
sheet_height         # => Float (mm)
tool_diameter        # => Float (mm)
clearance            # => Float (mm)
border_gap           # => Float (mm)
allow_rotation?      # => Boolean
allow_nesting_inside?  # => Boolean

# Calculated values
total_spacing        # => tool_diameter + clearance
usable_width         # => sheet_width - (2 * border_gap)
usable_height        # => sheet_height - (2 * border_gap)
```

#### Validation

```ruby
valid?               # => Boolean
validation_errors    # => Array of error strings
```

#### Display

```ruby
print_settings
# Print formatted settings to console

to_hash
# Serialize settings to hash
```

#### Persistence

```ruby
save_to_db
# Save settings to database

load_from_db
# Load settings from database
```

---

### Class Methods

```ruby
SettingsManager.read_from_n1(model = Sketchup.active_model)
# Quick: Find N1 and read settings
# Returns: SettingsManager instance

SettingsManager.current
# Get current settings (loads from DB)
# Returns: SettingsManager instance

SettingsManager.print_current
# Print current settings
```

---

## Integration with Nesting Engine

The SettingsManager will be used by the nesting engine:

```ruby
# In nesting engine
settings = SettingsManager.current

# Create sheets
sheet = Sheet.new(
  width: settings.usable_width,
  height: settings.usable_height
)

# Calculate spacing between parts
spacing = settings.total_spacing

# Check rotation
if settings.allow_rotation?
  # Try rotated positions
end

# Check nesting inside
if settings.allow_nesting_inside?
  # Try nesting inside other parts
end
```

---

## Example Output

### Default Settings

```
======================================================================
NESTING SETTINGS
======================================================================

Sheet Dimensions:
  Width: 2440.0 mm (default)
  Height: 1220.0 mm (default)
  Usable Width: 2420.0 mm
  Usable Height: 1200.0 mm

Tool Settings:
  Tool Diameter: 6.0 mm (default)
  Clearance: 2.0 mm (default)
  Total Spacing: 8.0 mm

Borders:
  Border Gap: 10.0 mm (default)

Nesting Behavior:
  Allow Rotation: No
  Allow Nesting Inside: No

Validation:
  Status: ✓ VALID
======================================================================
```

### After Reading from N1

```
======================================================================
NESTING SETTINGS
======================================================================

Sheet Dimensions:
  Width: 2440.0 mm (n1)
  Height: 1220.0 mm (n1)
  Usable Width: 2420.0 mm
  Usable Height: 1200.0 mm

Tool Settings:
  Tool Diameter: 6.0 mm (n1)
  Clearance: 2.5 mm (n1)
  Total Spacing: 8.5 mm

Borders:
  Border Gap: 12.0 mm (n1)

Nesting Behavior:
  Allow Rotation: No
  Allow Nesting Inside: No

Validation:
  Status: ✓ VALID
======================================================================
```

### With User Overrides

```
======================================================================
NESTING SETTINGS
======================================================================

Sheet Dimensions:
  Width: 3000.0 mm (user)
  Height: 1500.0 mm (user)
  Usable Width: 2970.0 mm
  Usable Height: 1470.0 mm

Tool Settings:
  Tool Diameter: 4.0 mm (user)
  Clearance: 3.0 mm (user)
  Total Spacing: 7.0 mm

Borders:
  Border Gap: 15.0 mm (user)

Nesting Behavior:
  Allow Rotation: Yes
  Allow Nesting Inside: No

Validation:
  Status: ✓ VALID
======================================================================
```

---

## Testing

Run the test script:

```ruby
load 'c:/Users/KB5007253/Desktop/tools/GG_ExtraNesting/test_settings.rb'
```

Tests include:
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

---

## Future Enhancements

Potential future features:

- 🚧 Settings presets (save/load named configurations)
- 🚧 Import/export settings to file
- 🚧 Settings UI dialog
- 🚧 Auto-detect material thickness from N1 boards
- 🚧 Per-material settings (different clearance for different materials)
- 🚧 Advanced rotation settings (90° only, 180°, any angle)
- 🚧 Sheet templates (common sheet sizes)

---

## Summary

The **SettingsManager** provides a complete solution for managing nesting settings:

✅ **Auto-detection**: Read settings from existing N1 nesting
✅ **User control**: Override any setting
✅ **Smart defaults**: Sensible defaults for all settings
✅ **Persistence**: Settings saved across sessions
✅ **Validation**: Ensure settings are valid before use
✅ **Source tracking**: Know where each setting came from
✅ **Calculated values**: Total spacing, usable area, etc.

**Status**: Complete ✅
**Phase**: 2.5
**Next**: Settings UI Dialog (Phase 6)

---

**Last Updated**: 2025-11-27
