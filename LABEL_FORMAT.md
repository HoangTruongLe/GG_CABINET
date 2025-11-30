# Label Format - Visual Label Components

**Date**: 2025-11-29
**Version**: 0.1.0-dev

---

## Label Components

The visual label drawn on the front face includes three main components:

```
┌──────────────────────────────┐
│                              │
│         [4]  ← Index         │
│          ↓   ← Vector Arrow  │
│          ↓                   │
│        [ĐỘ GỖ A3]           │
│      ← Instance Name         │
│                              │
└──────────────────────────────┘
```

---

## 1. Vector Arrow (Grain Direction)

**Purpose**: Shows the grain direction of the board

**Visual**:
```
    ↑
    │  ← Main line
    │
   ╱ ╲ ← Arrow head
```

**Position**: Center of label
**Length**: 25mm
**Arrow head**: 5mm V-shape
**Direction**: Points downward (in local Y-axis)

**Attributes**:
- Indicates material grain flow direction
- Used for orientation during nesting
- Helps with visual alignment

---

## 2. Index Number

**Purpose**: Shows the board index (sequential numbering)

**Visual**: Drawn as rectangles representing digits
```
[1] [4]  ← Two-digit number (14)
```

**Position**: Top of label (above arrow)
**Size**: 4mm × 6mm per digit
**Spacing**: 2mm between digits

**Examples**:
- Single digit: `[7]`
- Two digits: `[1][2]`
- Three digits: `[1][0][5]`

**Attributes**:
- Matches `[ABF] "board-index"` attribute
- Auto-incremented when labeling
- Used for board identification

---

## 3. Instance Name

**Purpose**: Shows the board's entity name (instance name)

**Visual**: Drawn as small rectangles representing characters
```
[Đ][Ộ] [G][Ỗ] [A][3]  ← "ĐỘ GỖ A3"
```

**Position**: Bottom of label (below arrow)
**Size**: 3mm × 5mm per character
**Spacing**: 1mm between characters
**Max Length**: 12 characters (truncated if longer)

**Examples**:
- `Board_1`
- `ĐỘ GỖ A02`
- `Panel_Top`
- `Shelf_Mid`

**Attributes**:
- Taken from `board.entity.name`
- If no name: defaults to "Board"
- Truncated at 12 characters for space

---

## Complete Label Layout

```
┌────────────────────────────────┐  ← Label rectangle (80mm × 40mm)
│                                │
│           [1][4]               │  ← Index number (top)
│             ↓                  │  ← Vector arrow (center)
│             ↓                  │     pointing down
│            ╱ ╲                 │
│                                │
│     [Đ][Ộ] [G][Ỗ] [A][3]     │  ← Instance name (bottom)
│                                │
└────────────────────────────────┘
```

---

## Label Dimensions

**Rectangle**:
- Width: 80mm
- Height: 40mm
- Line weight: Default edge

**Vector Arrow**:
- Length: 25mm
- Arrow head: 5mm
- Position: Center

**Index Number**:
- Character size: 4mm × 6mm
- Y-offset from center: +12mm (upward)
- Spacing: 2mm between digits

**Instance Name**:
- Character size: 3mm × 5mm
- Y-offset from center: -12mm (downward)
- Spacing: 1mm between characters
- Max length: 12 characters

---

## Label Attributes

The label group has these ABF attributes:

```ruby
[ABF] "is-label" => true
[ABF] "label-index" => 14
[ABF] "label-rotation" => 0  # degrees
```

---

## Drawing Method

Labels are drawn using edge geometry only (no faces):

1. **Rectangle**: 4 edges forming boundary
2. **Arrow**: 3 edges (main line + 2 arrow head lines)
3. **Index**: Small rectangles (4 edges per digit)
4. **Name**: Small rectangles (4 edges per character)

**Total edges**: Approximately 20-40 edges depending on text length

---

## Rotation Support

Labels rotate with the `label-rotation` attribute:

**Rotation values**: 0°, 90°, 180°, 270°

**Effect**:
- Entire label rotates around face center
- Vector arrow maintains direction relative to label
- Text remains readable in rotated orientation

**Example**:
```
0°:      90°:     180°:    270°:
  [4]      [4]      [4]      [4]
   ↓      →         ↑       ←
 Name    Name     Name     Name
```

---

## Label Visibility

**On Front Face**:
- Label drawn on face plane
- Slightly raised or embedded (0.1mm offset optional)
- Visible when viewing front face

**Color/Style**:
- Default edge color (black)
- Can be customized via layer or material
- Edge weight: Default (1px)

---

## Examples

### Example 1: Simple Board

```
Board name: "Board_1"
Index: 7
Rotation: 0°

Label shows:
┌──────────────┐
│     [7]      │
│      ↓       │
│   Board_1    │
└──────────────┘
```

### Example 2: Named Board

```
Board name: "ĐỘ GỖ A02"
Index: 14
Rotation: 0°

Label shows:
┌──────────────┐
│    [1][4]    │
│      ↓       │
│  ĐỘ GỖ A02  │
└──────────────┘
```

### Example 3: Long Name (Truncated)

```
Board name: "Very_Long_Board_Name_123"
Index: 105
Rotation: 0°

Label shows:
┌──────────────┐
│  [1][0][5]   │
│      ↓       │
│ Very_Long_Bo │  ← Truncated at 12 chars
└──────────────┘
```

---

## Implementation

**File**: [label_drawer.rb](gg_extra_nesting/services/label_drawer.rb)

**Methods**:
- `draw_label(board, index, rotation)` - Main method
- `draw_label_rectangle()` - Rectangle boundary
- `draw_vector_arrow()` - Grain direction arrow
- `draw_index_number()` - Index at top
- `draw_instance_name()` - Name at bottom

**Constants**:
```ruby
LABEL_WIDTH = 80.0      # mm
LABEL_HEIGHT = 40.0     # mm
ARROW_LENGTH = 25.0     # mm
ARROW_HEAD = 5.0        # mm
TEXT_HEIGHT = 8.0       # mm
```

---

## Usage

Labels are automatically drawn when you use "Label Extra Boards":

```
1. Select board(s)
2. Click: Plugins → GG Extra Nesting → Label Extra Boards
3. Labels automatically drawn on front faces
```

**Re-labeling**: Labels are redrawn if board is labeled again

**Unlabeling**: Labels are removed when unlabeling board

---

## Integration with Nesting

During nesting, the label is:

1. **Projected to 2D** along with the board
2. **Maintains orientation** (rotation preserved)
3. **Visible on nested sheet** for identification

This allows you to:
- Identify boards on sheets
- Verify grain direction
- Check board indices
- Confirm instance names

---

## Future Enhancements

Possible improvements:

- **3D Text**: Use SketchUp 3D text for better readability
- **Custom fonts**: Different font styles
- **Color coding**: Different colors for different materials
- **Dimension lines**: Show board dimensions
- **Material texture**: Show material pattern

---

**Last Updated**: 2025-11-29
