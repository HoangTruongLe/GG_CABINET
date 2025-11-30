# Nesting Update - New Nesting Root Creation

**Date**: 2025-11-28
**Status**: ✅ Updated

---

## Change Summary

**Previous behavior**: Cloned existing nesting root for extra boards
**New behavior**: Creates **new empty nesting root** for extra boards

---

## What Changed

### Before

```
User clicks "Nest Extra Boards"
  ↓
Find existing nesting root (N1)
  ↓
Clone N1 → N2 (with all existing sheets and boards)
  ↓
Nest extra boards into N2
```

**Issues**:
- Required existing nesting root
- Clone included all existing boards
- More complex workflow

### After

```
User clicks "Nest Extra Boards"
  ↓
Create NEW empty nesting root
  ↓
Nest extra boards into new root
```

**Benefits**:
- ✅ No existing nesting root required
- ✅ Clean start - no existing boards
- ✅ Simpler and faster
- ✅ Independent from main nesting

---

## New Nesting Root Attributes

When you click "Nest Extra Boards", a new group is created with:

```ruby
Name: "ExtraNesting_20251128_183857"  # Timestamp

Attributes:
[ABF] "is-nesting-root" => true
[ABF] "is-extra-nesting" => true
[ABF] "created-at" => "2025-11-28 18:38:57 +0700"
```

---

## Updated Workflow

### Complete Flow

```
1. User creates boards
   ↓
2. User selects boards
   ↓
3. Click "Label Extra Boards"
   → Boards labeled with indices, attributes, visual labels
   ↓
4. User selects labeled boards
   ↓
5. Click "Nest Extra Boards"
   ↓
6. System creates new nesting root
   ↓
7. System projects boards to 2D
   ↓
8. System creates sheets in new root
   ↓
9. System nests boards into sheets
   ↓
10. Done! View results in new nesting root
```

---

## Console Output

### Before (Cloning)

```
Found existing nesting root: NestingRoot_Main
Cloning nesting root...
Created clone: NestingRoot_Main_Clone_ExtraNesting
Using nesting root: NestingRoot_Main_Clone_ExtraNesting
```

### After (New Root)

```
Created new nesting root: ExtraNesting_20251128_183857
```

---

## Example Usage

### Test Scenario

```ruby
# 1. Create and label boards
board1 = create_board(600, 400, 18)
board2 = create_board(500, 300, 18)

# Select boards
Sketchup.active_model.selection.add([board1, board2])

# 2. Label
# Click: Plugins → GG Extra Nesting → Label Extra Boards
# Result: Boards labeled with indices 1, 2

# 3. Keep selected and nest
# Click: Plugins → GG Extra Nesting → Nest Extra Boards

# Result:
# - New nesting root created: "ExtraNesting_20251128_183857"
# - New sheet created: e.g., "Sheet_[Color A02]_17.5_1732792737"
# - Both boards nested on new sheet
```

---

## What You'll See

After clicking "Nest Extra Boards":

```
Model entities:
├── Board_1 (original - unchanged)
├── Board_2 (original - unchanged)
│
└── ExtraNesting_20251128_183857 (NEW)
    └── Sheet_[Color A02]_17.5_1732792737 (NEW)
        ├── Board_1_2D (projected)
        └── Board_2_2D (projected)
```

---

## Benefits

### ✅ No Prerequisites

**Before**: Needed existing nesting root
**After**: Works standalone

### ✅ Clean Slate

**Before**: Clone included all existing boards
**After**: New root is empty, only has your extra boards

### ✅ Independent

**Before**: Connected to original nesting
**After**: Completely independent nesting root

### ✅ Simpler Code

**Before**: Find, clone, transform, update attributes
**After**: Create new, set attributes

---

## Nesting Root Identification

### Finding Extra Nesting Roots

```ruby
# Find all extra nesting roots
model = Sketchup.active_model

extra_roots = model.entities.grep(Sketchup::Group).select do |entity|
  entity.get_attribute('ABF', 'is-extra-nesting') == true
end

puts "Found #{extra_roots.count} extra nesting root(s)"
extra_roots.each do |root|
  puts "  - #{root.name}"
  puts "    Created: #{root.get_attribute('ABF', 'created-at')}"
end
```

### Differentiating Root Types

```ruby
# Main nesting root (from original workflow)
is_main = entity.get_attribute('ABF', 'is-nesting-root') == true &&
          entity.get_attribute('ABF', 'is-extra-nesting') != true

# Extra nesting root (from extra boards workflow)
is_extra = entity.get_attribute('ABF', 'is-extra-nesting') == true
```

---

## Updated Code

### File Modified

**[nesting_tool.rb](gg_extra_nesting/tools/nesting_tool.rb)**

**Changes**:
- Line 35: Changed from `find_or_clone_nesting_root()` to `create_extra_nesting_root()`
- Lines 187-210: New method `create_extra_nesting_root()` replaces cloning logic
- Removed: `find_or_clone_nesting_root()`, `find_existing_nesting_root()`, `find_cloned_nesting_root()`, `clone_nesting_root()`

**Before**:
```ruby
def find_or_clone_nesting_root(model)
  n1_root = find_existing_nesting_root(model)
  # ... cloning logic ...
end
```

**After**:
```ruby
def create_extra_nesting_root(model)
  root_group = model.entities.add_group
  root_group.name = "ExtraNesting_#{Time.now.strftime('%Y%m%d_%H%M%S')}"
  root_group.set_attribute('ABF', 'is-nesting-root', true)
  root_group.set_attribute('ABF', 'is-extra-nesting', true)
  # ...
end
```

---

## Testing

### Quick Test

```ruby
# 1. Create simple board
board = Sketchup.active_model.entities.add_group
board.name = "TestBoard"

# Add faces
points = [
  Geom::Point3d.new(0, 0, 0),
  Geom::Point3d.new(600.mm, 0, 0),
  Geom::Point3d.new(600.mm, 400.mm, 0),
  Geom::Point3d.new(0, 400.mm, 0)
]
board.entities.add_face(points)

# Add back face
points_back = points.map { |p| Geom::Point3d.new(p.x, p.y, -18.mm) }
board.entities.add_face(points_back).reverse!

# 2. Label
Sketchup.active_model.selection.clear
Sketchup.active_model.selection.add(board)
# Click: Label Extra Boards

# 3. Nest (keeps selection)
# Click: Nest Extra Boards

# 4. Verify new root created
roots = Sketchup.active_model.entities.grep(Sketchup::Group).select do |e|
  e.get_attribute('ABF', 'is-extra-nesting') == true
end

puts "Extra nesting roots: #{roots.count}"
# Should show: 1
```

---

## Migration Notes

### For Existing Users

If you were using the previous version with cloning:

**No migration needed** - the new version creates fresh nesting roots.

**If you want the old behavior** (cloning):
- The old code is removed but can be restored if needed
- Current approach is simpler and recommended

---

## Summary

✅ **New behavior**: Creates new empty nesting root
✅ **No prerequisites**: Works without existing nesting root
✅ **Clean results**: Only contains your extra boards
✅ **Simpler**: Fewer steps, faster execution

**Root naming**: `ExtraNesting_YYYYMMDD_HHMMSS`
**Root attributes**: `is-nesting-root: true`, `is-extra-nesting: true`

---

**Ready to use!** Just label boards and nest - new root will be created automatically.

---

**Last Updated**: 2025-11-28
