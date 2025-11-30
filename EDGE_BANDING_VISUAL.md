# Edge Banding Visual Guide

Visual diagrams for understanding edge banding indicators in 2D projections.

---

## Triangle Dimensions

```
Standard Triangle (Isosceles):

                      Apex
                       △
                      ╱│╲
                     ╱ │ ╲
                    ╱  │  ╲          Height = 56mm
                   ╱   │   ╲
                  ╱    │    ╲
                 ╱     │     ╲
                ╱      │      ╲
               ╱_______|_______╲
              ◄───────40mm──────►
                    Base

Side lengths: 40mm (isosceles)
Base: 40mm
Height: 56mm
```

---

## Triangle Position Relative to Edge

```
Board Edge (viewed from above):

    ←─────────────────────────→  Board edge (after offset)
                │
                │ 28mm (height * 50%)
                │
        ╲_______|_______╱  ◄── Triangle base (inward)
         ╲      │      ╱
          ╲     │     ╱
           ╲    │    ╱
            ╲   │   ╱
             ╲  │  ╱
              ╲ │ ╱
               ╲│╱
                ▼  ◄── Apex points TOWARD edge
```

**Key Measurements**:
- Distance from edge to triangle base: 28mm (height * 50%)
- Triangle points OUTWARD toward the edge (apex at edge)
- Triangle centered on edge midpoint
- Base is positioned inward from edge

---

## Rectangular Board Example

### 3D View (Side Perspective)

```
                Top Edge
    ┌───────────────────────────┐
    │                           │
    │         Front Face        │  Side faces (4 total)
    │                           │
    │                           │
    └───────────────────────────┘
               Bottom Edge

Top side face: Has edge banding (1.0mm "CHỈ")
Bottom side face: Has edge banding (0.1mm "Dán Tay 01")
Left/Right: No edge banding
```

### 2D Projection (Top View)

```
Normal outline (no offset):
    ┌─────────────────────────────────┐
    │                                 │
    │                                 │
    │          Front Face             │
    │          (projected)            │
    │                                 │
    │                                 │
    └─────────────────────────────────┘

With edge banding (offset + markers):

   ┌───────────────────────────────────┐ ← Top edge offset inward 1.0mm
   │              ▼                    │ ← Triangle apex points to edge
   │             ╱ ╲                   │    Base at 28mm from edge
   │            ╱   ╲                  │    Color: #b36ea9
   │           ╱_____╲                 │
   │                                   │
   │          Front Face               │
   │          (projected)              │
   │           _______                 │
   │          ╱       ╲                │
   │         ╱         ╲               │ ← Triangle base inward
   │        ╱           ╲              │    Color: #c46b6b
   │       ▼             ▼             │
   └───────────────────────────────────┘ ← Bottom edge offset inward 0.1mm
```

---

## Edge Offset Direction

### Top Edge (Looking down at board)

```
                  Board Center
                       ▼
    ───────────────────────────────────  Original edge position
              ▲
              │ 1.0mm offset (inward)
              │
    ───────────────────────────────────  New edge position (offset)
           _______                       Triangle base
          ╱       ╲                      (28mm from edge, inward)
         ╱         ╲
        ╱           ╲
       ▼             ▼  ← Apex points TOWARD edge
```

**Offset Direction**: Always inward (toward board center)
**Triangle Direction**: Apex points TOWARD edge (outward)

---

## Common Edge Detection

### 3D Board Structure

```
Front Face (marked with ●):

    ●─────────●
    │         │
    │  Front  │
    │  Face   │
    │         │
    ●─────────●

Side Face (Top) shares edge with Front Face:

    ●═════════●  ← Common edge (shared by both faces)
    ║         ║
    ║  Side   ║
    ║  Face   ║
    ║ (Top)   ║
    ●─────────●
```

**Key Point**: Side face always shares exactly **1 edge** with front face.

---

## Edge Banding Data Flow

```
Board Attribute:
┌────────────────────────────────────────────────────┐
│ 'edge-band-types' =                                │
│   [0, "CHỈ", 1.0, "#b36ea9", 0,                   │
│    1, "Dán Tay 01", 0.1, "#c46b6b", 0]            │
└────────────────────────────────────────────────────┘
                    │
                    │ Parse
                    ▼
        ┌───────────────────────┐
        │ EdgeBanding Objects   │
        │                       │
        │ [0] => {              │
        │   name: "CHỈ"         │
        │   thickness: 1.0mm    │
        │   color: "#b36ea9"    │
        │ }                     │
        │                       │
        │ [1] => {              │
        │   name: "Dán Tay 01"  │
        │   thickness: 0.1mm    │
        │   color: "#c46b6b"    │
        │ }                     │
        └───────────────────────┘
                    │
                    │ Reference by ID
                    ▼
Side Face Attributes:
┌─────────────────────┐
│ Top Side:           │
│ 'edge-band-id' = 0  │ ──→ Uses "CHỈ" (1.0mm)
└─────────────────────┘

┌─────────────────────┐
│ Bottom Side:        │
│ 'edge-band-id' = 1  │ ──→ Uses "Dán Tay 01" (0.1mm)
└─────────────────────┘

┌─────────────────────┐
│ Left Side:          │
│ 'edge-band-id' = nil│ ──→ No edge banding
└─────────────────────┘

┌─────────────────────┐
│ Right Side:         │
│ 'edge-band-id' = nil│ ──→ No edge banding
└─────────────────────┘
```

---

## Triangle Scaling Examples

### 100mm Edge (Standard Size)

```
Edge length: 100mm
Scale: 100%
Triangle: 40mm base × 56mm height

    ●─────────────────────────────────●  Edge (100mm)
              △                          Triangle (full size)
             ╱ ╲
            ╱   ╲
           ╱     ╲
```

### 50mm Edge (Scaled)

```
Edge length: 50mm
Scale: 83%
Triangle: 33mm base × 46mm height

    ●────────────────────●  Edge (50mm)
           △                Triangle (scaled)
          ╱ ╲
         ╱   ╲
```

### 30mm Edge (Minimum Scale)

```
Edge length: 30mm
Scale: 50% (minimum)
Triangle: 20mm base × 28mm height

    ●──────────────●  Edge (30mm)
         △           Triangle (minimum size)
        ╱ ╲
```

**Scaling Formula**:
```
min_edge_for_standard = 60mm (base × 1.5)
scale = edge_length / min_edge_for_standard
scale = max(scale, 0.5)  # Minimum 50%

scaled_base = 40mm × scale
scaled_height = 56mm × scale
```

---

## Circular Board Example

### 3D View

```
       Top View:              Side View:
      ___________            ___________
    /             \         /           \
   |               |       |  Front Face |
   |   Front Face  |       |   (circle)  |
   |    (circle)   |       |             |
    \_____________/         \___________/
                                  │
                                  │ Side face (curved)
                                  │ with edge banding
```

### 2D Projection with Edge Banding

```
      ___________
    /      ▼      \  ← Triangle apex points to edge
   |      ╱ ╲      |    Base inward from arc
   |     ╱___╲     |    (relative to nesting orientation)
   |               |
   |               |    Arc offset by edge banding thickness
   |               |
    \_____________/

Circle center at origin
Triangle at θ = 90° (top)
Tangent at midpoint → perpendicular for triangle
Triangle base inward, apex toward edge
```

---

## Perpendicular Direction Calculation

### Finding Inward Perpendicular

```
Edge vector:        Perpendicular vectors:

    v2              Perp1 (90° CCW)      Perp2 (90° CW)
     ●                    ▲                    │
     │                    │                    ▼
     │ edge               │
     │                    │
     ●              ──────●──────          ──────●──────
    v1                 edge                   edge

Board center:
                   ×  ← Center


To find inward perpendicular:
1. Calculate both perpendicular vectors
2. Calculate vector from edge midpoint to center
3. Use dot product to find which perpendicular points toward center
4. Use that perpendicular for offset direction
```

**Code**:
```ruby
perp1 = [-edge_vector[1], edge_vector[0]]   # 90° CCW
perp2 = [edge_vector[1], -edge_vector[0]]   # 90° CW

to_center = [center[0] - edge_mid[0], center[1] - edge_mid[1]]

dot1 = perp1[0] * to_center[0] + perp1[1] * to_center[1]
dot2 = perp2[0] * to_center[0] + perp2[1] * to_center[1]

inward_perp = (dot1 > dot2) ? perp1 : perp2
```

---

## Complete Example: 600mm × 400mm Board

### Board Specifications

```
Dimensions: 600mm × 400mm × 18mm
Material: "Color A02"
Front face: Rectangular

Edge Banding:
- Top edge (600mm): "CHỈ" (1.0mm, #b36ea9)
- Bottom edge (600mm): "Dán Tay 01" (0.1mm, #c46b6b)
- Left edge (400mm): None
- Right edge (400mm): None
```

### 2D Projection Output

```
    0,0                                  600,0
     ●─────────────────────────────────────●
     │              △                       │  ← Top: offset 1.0mm inward
     │             ╱ ╲                      │     Triangle: 40×56mm, #b36ea9
     │            ╱   ╱                     │     Position: (300, -12.2)
     │                                      │
     │                                      │
     │           Front Face                 │
     │            600 × 400                 │
     │                                      │
     │                                      │
     │              △                       │  ← Bottom: offset 0.1mm inward
     │             ╱ ╱                      │     Triangle: 40×56mm, #c46b6b
     ●─────────────────────────────────────●     Position: (300, 400+12.2)
   0,400                                600,400
```

**Triangle Positions**:
- Top triangle center: (300, -12.2)
  - Edge midpoint: (300, 0)
  - Offset inward: -11.2mm (y-direction)
  - Offset for edge: -1.0mm (y-direction)
  - Total: -12.2mm

- Bottom triangle center: (300, 412.2)
  - Edge midpoint: (300, 400)
  - Offset inward: +11.2mm (y-direction)
  - Offset for edge: +0.1mm (y-direction)
  - Total: +12.2mm

---

## Layer Organization in 2D Group

```
2D Group
├── Layer 0: Outline (cutting path)
│   ├── Edge 1 (top) - offset by 1.0mm
│   ├── Edge 2 (right) - no offset
│   ├── Edge 3 (bottom) - offset by 0.1mm
│   └── Edge 4 (left) - no offset
│
├── Layer 1: Edge Banding Markers
│   ├── Triangle 1 (top edge)
│   │   ├── Material: Color #b36ea9
│   │   └── Face (filled)
│   └── Triangle 2 (bottom edge)
│       ├── Material: Color #c46b6b
│       └── Face (filled)
│
└── Layer 2: Label (if exists)
    └── Label group
```

---

## Edge Banding Attribute Parsing

### Raw Attribute Array

```ruby
[0, "CHỈ", 1.0, "#b36ea9", 0, 1, "Dán Tay 01", 0.1, "#c46b6b", 0]
```

### Parsing Pattern

```
Index:  0    1      2    3          4  5    6            7    8          9
       ┌────┬──────┬────┬──────────┬───┬───┬────────────┬────┬──────────┬───┐
       │ 0  │"CHỈ" │1.0 │"#b36ea9" │ 0 │ 1 │"Dán Tay 01"│0.1 │"#c46b6b" │ 0 │
       └────┴──────┴────┴──────────┴───┴───┴────────────┴────┴──────────┴───┘
         │     │     │       │       │   │       │        │       │       │
         ID    │     │       │       ?   ID      │        │       │       ?
              Name   │       │                  Name     │       │
                   Thick     │                         Thick     │
                            Color                              Color

Edge Banding Type 1:              Edge Banding Type 2:
├─ ID: 0                          ├─ ID: 1
├─ Name: "CHỈ"                    ├─ Name: "Dán Tay 01"
├─ Thickness: 1.0mm               ├─ Thickness: 0.1mm
└─ Color: "#b36ea9"               └─ Color: "#c46b6b"
```

### Parsed Output

```ruby
{
  0 => EdgeBanding(id: 0, name: "CHỈ", thickness: 1.0, color: "#b36ea9"),
  1 => EdgeBanding(id: 1, name: "Dán Tay 01", thickness: 0.1, color: "#c46b6b")
}
```

---

## Summary Diagram

```
┌──────────────────────────────────────────────────────────────┐
│                      3D BOARD                                │
│                                                              │
│  ┌────────────────────────────────────┐                     │
│  │ Attribute: 'edge-band-types'       │                     │
│  │ [0, "CHỈ", 1.0, "#b36ea9", 0, ...] │                     │
│  └────────────────────────────────────┘                     │
│                   │                                          │
│                   │ Parse                                    │
│                   ▼                                          │
│  ┌────────────────────────────────────┐                     │
│  │ EdgeBanding Objects:               │                     │
│  │  0 => CHỈ (1.0mm, #b36ea9)         │                     │
│  │  1 => Dán Tay 01 (0.1mm, #c46b6b)  │                     │
│  └────────────────────────────────────┘                     │
│                   │                                          │
│         ┌─────────┴─────────┐                               │
│         ▼                   ▼                                │
│  ┌──────────┐        ┌──────────┐                           │
│  │ Side 1   │        │ Side 2   │                           │
│  │ edge-id:0│        │ edge-id:1│                           │
│  └──────────┘        └──────────┘                           │
│         │                   │                                │
│         │ Find common edge  │                                │
│         ▼                   ▼                                │
│  ┌──────────┐        ┌──────────┐                           │
│  │ Edge 1   │        │ Edge 3   │                           │
│  │ (top)    │        │ (bottom) │                           │
│  └──────────┘        └──────────┘                           │
└──────────────────────────────────────────────────────────────┘
                        │
                        │ Project to 2D
                        ▼
┌──────────────────────────────────────────────────────────────┐
│                    2D PROJECTION                             │
│                                                              │
│    Edge 1 (offset by 1.0mm)                                 │
│   ●─────────────────────────────────────●                   │
│   │            △                         │                  │
│   │           ╱ ╲  (40×56, #b36ea9)     │                  │
│   │          ╱   ╱                       │                  │
│   │                                      │                  │
│   │                                      │                  │
│   │            △                         │                  │
│   │           ╱ ╱  (40×56, #c46b6b)     │                  │
│   ●─────────────────────────────────────●                   │
│    Edge 3 (offset by 0.1mm)                                 │
│                                                              │
└──────────────────────────────────────────────────────────────┘
```

---

**Last Updated**: 2025-11-27
