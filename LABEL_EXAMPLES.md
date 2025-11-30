# Label Examples - Visual Reference

**Date**: 2025-11-29
**Version**: 0.1.0-dev

---

## Standard Label Layout

```
┌────────────────────────────────┐
│                                │
│           [1][4]               │  ← Board Index (14)
│                                │
│             ↓                  │
│             ↓                  │  ← Vector Arrow (grain direction)
│            ╱ ╲                 │
│                                │
│     [Đ][Ộ] [G][Ỗ] [A][3]     │  ← Instance Name (ĐỘ GỖ A3)
│                                │
└────────────────────────────────┘
```

---

## Example 1: Simple Board

**Board Details**:
- Name: `Board_1`
- Index: `7`
- Material: `[Color A02]`
- Thickness: `17.5mm`

**Label**:
```
┌────────────────────────────────┐
│                                │
│             [7]                │
│                                │
│             ↓                  │
│             ↓                  │
│            ╱ ╲                 │
│                                │
│         Board_1                │
│                                │
└────────────────────────────────┘
```

---

## Example 2: Vietnamese Material Name

**Board Details**:
- Name: `ĐỘ GỖ A02`
- Index: `14`
- Material: `Oak Veneer`
- Thickness: `18mm`

**Label**:
```
┌────────────────────────────────┐
│                                │
│          [1][4]                │
│                                │
│             ↓                  │
│             ↓                  │
│            ╱ ╲                 │
│                                │
│        ĐỘ GỖ A02              │
│                                │
└────────────────────────────────┘
```

---

## Example 3: Long Index Number

**Board Details**:
- Name: `Panel_Top`
- Index: `105`
- Material: `MDF`
- Thickness: `16mm`

**Label**:
```
┌────────────────────────────────┐
│                                │
│        [1][0][5]               │
│                                │
│             ↓                  │
│             ↓                  │
│            ╱ ╲                 │
│                                │
│         Panel_Top              │
│                                │
└────────────────────────────────┘
```

---

## Example 4: Truncated Long Name

**Board Details**:
- Name: `Very_Long_Board_Name_With_Many_Characters`
- Index: `42`
- Material: `Plywood`
- Thickness: `12mm`

**Label** (name truncated at 12 characters):
```
┌────────────────────────────────┐
│                                │
│          [4][2]                │
│                                │
│             ↓                  │
│             ↓                  │
│            ╱ ╲                 │
│                                │
│       Very_Long_Bo             │  ← Truncated
│                                │
└────────────────────────────────┘
```

---

## Example 5: Rotated Label (90°)

**Board Details**:
- Name: `Shelf_Mid`
- Index: `8`
- Rotation: `90°`

**Label** (rotated 90° clockwise):
```
┌──────┐
│      │
│  [8] │
│      │
│  →   │  ← Arrow rotated
│  →   │
│  ╱╲  │
│      │
│ S    │
│ h    │
│ e    │
│ l    │
│ f    │
│ _    │
│ M    │
│ i    │
│ d    │
│      │
└──────┘
```

---

## Example 6: Multiple Boards in Scene

**Scenario**: Three boards labeled in sequence

**Board 1**:
```
Name: Panel_A
Index: 1
┌──────────┐
│   [1]    │
│    ↓     │
│  Panel_A │
└──────────┘
```

**Board 2**:
```
Name: Panel_B
Index: 2
┌──────────┐
│   [2]    │
│    ↓     │
│  Panel_B │
└──────────┘
```

**Board 3**:
```
Name: Panel_C
Index: 3
┌──────────┐
│   [3]    │
│    ↓     │
│  Panel_C │
└──────────┘
```

---

## Label Components Breakdown

### 1. Rectangle Border
```
┌────────────────┐
│                │  ← 80mm wide
│                │  ← 40mm high
└────────────────┘
```

### 2. Vector Arrow (Grain Direction)
```
    ↑
    │  ← Main shaft (25mm)
    │
   ╱ ╲ ← Arrow head (5mm)
```

### 3. Index Number
```
[1] [4]  ← Two-digit number
 ↑   ↑
 │   └─ Each digit: 4mm × 6mm rectangle
 └───── Spacing: 2mm between digits
```

### 4. Instance Name
```
[P] [a] [n] [e] [l]  ← Five characters
 ↑   ↑   ↑   ↑   ↑
 │   └─ Each char: 3mm × 5mm rectangle
 └───── Spacing: 1mm between chars
```

---

## Label on Board Front Face

**3D Perspective View**:
```
                    ┌───────────────────┐
                   ╱                   ╱│
                  ╱  ┌──────────┐     ╱ │
                 ╱   │   [7]    │    ╱  │
                ╱    │    ↓     │   ╱   │  ← Board (3D)
               ╱     │  Board_1 │  ╱    │
              ╱      └──────────┘ ╱     │
             ╱         ↑         ╱      │
            ╱      Label on     ╱       │
           ╱      front face   ╱        │
          ╱                   ╱         │
         └───────────────────┘          │
         │                   │          │
         │                   │         ╱
         │                   │        ╱
         │                   │       ╱
         └───────────────────┘──────┘
```

---

## Label on Nested 2D Board

**After nesting** (projected to 2D sheet):
```
Sheet: [Color A02]_17.5_1732792737

┌────────────────────────────────────────────┐
│                                            │
│  ┌────────────────┐                        │
│  │                │                        │
│  │     [7]        │  ← Label projected     │
│  │      ↓         │     with board         │
│  │   Board_1      │                        │
│  │                │                        │
│  └────────────────┘                        │
│   ← Board_1_2D                             │
│                                            │
│                    ┌────────────┐          │
│                    │    [8]     │          │
│                    │     ↓      │          │
│                    │  Board_2   │          │
│                    └────────────┘          │
│                     ← Board_2_2D           │
│                                            │
└────────────────────────────────────────────┘
```

---

## Edge-Based Drawing

Labels are drawn using **edges only** (no faces):

**Advantage**:
- Minimal geometry
- Fast rendering
- Always visible (no face culling)
- Easy to select and manipulate

**Typical edge count per label**:
- Rectangle: 4 edges
- Arrow: 3 edges (shaft + 2 head lines)
- Index (2 digits): 8 edges (4 per digit)
- Name (8 chars): 32 edges (4 per char)
- **Total**: ~47 edges

---

## Label Attributes Reference

Each label group has these attributes:

```ruby
[ABF] "is-label" => true
[ABF] "label-index" => 14           # Matches board-index
[ABF] "label-rotation" => 0         # Degrees: 0, 90, 180, 270
```

---

## Console Output When Labeling

```
Processing 1/1: Board_1
  ✓ Labeled successfully
    Index: 7
    Material: [Color A02]
    Thickness: 17.5 mm
    Size: 600 × 400 mm
    Classification: [Color A02]_17.5
    Front face intersections: 3
    Front face marked (3 intersections)
    Visual label drawn (rotation: 0°)
```

---

## Visual Identification Benefits

1. **Quick Board Identification**: See index at a glance
2. **Grain Direction**: Arrow shows orientation
3. **Board Name**: Know which board it is
4. **Material Verification**: Cross-reference with name
5. **Nesting Verification**: Labels visible on sheets

---

## Real-World Usage Example

**Scenario**: Cabinet maker has 12 boards to nest

```
Step 1: Create boards in SketchUp
  - Board names: Panel_A through Panel_L

Step 2: Select all 12 boards

Step 3: Click "Label Extra Boards"
  - Each board gets labeled with:
    - Index: 1-12
    - Arrow showing grain
    - Board name

Step 4: Verify labels visually
  - Zoom to each board
  - Check arrow direction
  - Verify indices are sequential

Step 5: Click "Nest Extra Boards"
  - Boards nest onto sheets
  - Labels stay with boards
  - Easy to identify on sheets

Step 6: Export or cut
  - Labels help identify pieces
  - Grain direction visible
  - Board numbers for tracking
```

---

## Customization Options

You can customize labels by modifying [label_drawer.rb](gg_extra_nesting/services/label_drawer.rb):

**Dimensions**:
```ruby
LABEL_WIDTH = 80.0      # mm - Rectangle width
LABEL_HEIGHT = 40.0     # mm - Rectangle height
ARROW_LENGTH = 25.0     # mm - Arrow shaft length
ARROW_HEAD = 5.0        # mm - Arrow head size
TEXT_HEIGHT = 8.0       # mm - Text character height
```

**Colors** (add to label group):
```ruby
label_group.material = "LabelColor"
```

**Layer** (organize labels):
```ruby
label_group.layer = "Labels"
```

---

**Last Updated**: 2025-11-29
