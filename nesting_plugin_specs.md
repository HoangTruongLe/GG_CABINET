# SketchUp Extra Nesting Plugin - Technical Specifications

## 1. Tổng quan dự án

### 1.1 Mục đích
Phát triển plugin SketchUp hỗ trợ nesting bổ sung (Extra Nesting) cho phép thêm các chi tiết tấm ván mới vào sơ đồ nesting đã có sẵn mà không cần phải nesting lại toàn bộ.

### 1.2 Bối cảnh
- **Công cụ hiện có (N1)**: Tool nesting chính đã label và sắp xếp các tấm ván vào khổ ván
- **Vấn đề**: Khi vẽ thêm chi tiết mới, phải nesting lại toàn bộ
- **Giải pháp**: Tool Extra Nesting (N2) cho phép nesting bổ sung dựa trên sơ đồ cũ

---

## 2. Định nghĩa đối tượng tấm ván

### 2.1 Cấu trúc tấm ván
Mỗi tấm ván phẳng có:
- **Front Face**: 1 trong 2 face lớn nhất, song song, đồng dạng
- **Back Face**: Face còn lại song song với Front Face
- **Side Faces**: Các face còn lại (cạnh bên)

### 2.2 Thuộc tính cần xác định
- **Front/Back Face**: Để xác định hướng khi lật mặt cắt
- **Index**: Số thứ tự định danh tấm ván
- **Kích thước**: Width × Height × Depth (từ bounds)
- **Thickness**: Độ dày tấm ván (depth của bounding box)
- **Material**: Vật liệu/màu của tấm ván

### 2.3 Material & Thickness - Nesting Classification

**CRITICAL**: Boards được phân loại và nesting riêng theo:
1. **Material/Color**: Loại gỗ, màu sắc
2. **Thickness**: Độ dày (VD: 17.5mm, 18mm, 25mm)

**Quy tắc nesting**:
```
Boards chỉ được nest vào cùng sheet NẾU:
  ✓ Cùng material/color
  ✓ Cùng thickness
  ✗ Khác material → nest vào sheet khác
  ✗ Khác thickness → nest vào sheet khác
```

**Ví dụ phân loại**:
```
Group 1: Color A02, 17.5mm
  → Sheet: Color A02-17.5mm-sheet-1
  → Board 1, 2, 3, 5, 7...

Group 2: Color A02, 18mm
  → Sheet: Color A02-18mm-sheet-1
  → Board 10, 15, 20...

Group 3: Veneer Oak, 17.5mm
  → Sheet: Veneer Oak-17.5mm-sheet-1
  → Board 4, 8, 12...

Group 4: Veneer Oak, 25mm
  → Sheet: Veneer Oak-25mm-sheet-1
  → Board 6, 9, 11...
```

### 2.4 Material Detection

**Xác định material từ board**:
```ruby
def detect_board_material(board)
  # Method 1: From face material
  front_face = find_front_face(board)
  
  if front_face.material
    material_name = front_face.material.name
    material_color = front_face.material.color
  else
    # Method 2: From group material
    if board.material
      material_name = board.material.name
      material_color = board.material.color
    else
      # Method 3: From layer name
      material_name = board.layer.name
      material_color = nil
    end
  end
  
  # Normalize material name
  material_name = normalize_material_name(material_name)
  
  return {
    name: material_name,
    color: material_color,
    display_name: format_material_display(material_name, material_color)
  }
end

def normalize_material_name(raw_name)
  # Remove special characters, standardize
  # "Color A02" → "Color_A02"
  # "Veneer - Oak" → "Veneer_Oak"
  
  raw_name.gsub(/[^a-zA-Z0-9]/, '_').squeeze('_')
end
```

### 2.5 Thickness Detection

**Xác định thickness từ board**:
```ruby
def detect_board_thickness(board)
  bounds = board.bounds
  
  # Thickness là dimension nhỏ nhất (depth)
  dimensions = [
    bounds.width,
    bounds.height,
    bounds.depth
  ].sort
  
  thickness = dimensions.first
  
  # Round to common thicknesses
  thickness_mm = (thickness / 1.mm).round(1)
  
  # Validate common thicknesses
  common_thicknesses = [8, 9, 12, 15, 17.5, 18, 20, 25, 30]
  
  if common_thicknesses.any? { |t| (t - thickness_mm).abs < 0.5 }
    # Snap to common thickness
    thickness_mm = common_thicknesses.min_by { |t| (t - thickness_mm).abs }
  end
  
  return thickness_mm
end
```

### 2.6 Board Classification Key

**Tạo key để phân loại boards**:
```ruby
def generate_board_classification_key(board)
  material = detect_board_material(board)
  thickness = detect_board_thickness(board)
  
  # Format: "Material_Thickness"
  # Example: "Color_A02_17.5", "Veneer_Oak_25.0"
  
  key = "#{material[:name]}_#{thickness}"
  
  # Save to attributes
  board.set_attribute('ABF', 'material-name', material[:name])
  board.set_attribute('ABF', 'material-display', material[:display_name])
  board.set_attribute('ABF', 'thickness', thickness)
  board.set_attribute('ABF', 'classification-key', key)
  
  return key
end
```

---

## 3. Quy trình Nesting chính (N1) - Hiện có

### 3.1 Bước 1: Label Tool
**Chức năng**: Gắn nhãn cho các tấm ván
- Xác định Front Face và Back Face
- Gán Index cho từng tấm ván
- Lưu thông tin vào attributes của đối tượng
- Gán `label-rotation` (góc xoay theo chiều kim đồng hồ, VD: 0, 90, 120, 180, 270)

### 3.2 Bước 2: 2D Projection (Core Nesting Logic)

**CRITICAL**: Nesting hoạt động trên 2D projection, không phải 3D geometry

#### 3.2.0 Pre-processing: Group boards by Material + Thickness
```ruby
def group_boards_for_nesting(boards)
  # Group boards by classification key
  grouped = boards.group_by { |board| 
    generate_board_classification_key(board)
  }
  
  # Result: Hash
  # {
  #   "Color_A02_17.5" => [Board1, Board3, Board5],
  #   "Color_A02_18.0" => [Board10, Board15],
  #   "Veneer_Oak_17.5" => [Board4, Board8],
  #   "Veneer_Oak_25.0" => [Board6, Board9]
  # }
  
  return grouped
end

def create_sheets_by_classification(grouped_boards, nesting_root)
  sheets_by_class = {}
  
  grouped_boards.each do |class_key, boards|
    # Parse classification key
    material_name, thickness = parse_classification_key(class_key)
    
    # Create sheet(s) for this classification
    sheet_group = create_classified_sheet(
      nesting_root,
      material: material_name,
      thickness: thickness,
      sheet_id: 1  # Start from 1 for each classification
    )
    
    sheets_by_class[class_key] = [sheet_group]
  end
  
  return sheets_by_class
end

def create_classified_sheet(nesting_root, material:, thickness:, sheet_id:)
  sheet_group = nesting_root.entities.add_group
  
  # Naming convention: Material-Thickness-sheet-ID
  # Example: "Color_A02-17.5mm-sheet-1"
  sheet_name = "__#{material}-#{thickness}mm-sheet-#{sheet_id}"
  sheet_group.name = sheet_name
  
  # Set attributes
  sheet_group.set_attribute('ABF', 'sheet-id', sheet_id)
  sheet_group.set_attribute('ABF', 'sheet-type', material)
  sheet_group.set_attribute('ABF', 'sheet-thickness', thickness)
  sheet_group.set_attribute('ABF', 'classification-key', "#{material}_#{thickness}")
  sheet_group.set_attribute('ABF', 'sheet-dimension', [1220, 2440])
  
  # Create border
  create_sheet_border(sheet_group, [1220, 2440])
  
  return sheet_group
end
```

#### 3.2.1 2D Face Generation Rules
```ruby
# Rule 1: Front face → LUÔN tạo 2D face
front_face = find_front_face(board)  # Face có is-labeled-face=true
front_2d_face = project_face_to_xy(front_face)

# Rule 2: Back face → CHỈ tạo 2D face KHI có intersection
back_face = find_back_face(board)
intersections = board.entities.grep(Sketchup::Group).select { |g| 
  g.get_attribute('ABF', 'is-intersect') 
}

if intersections.any?
  back_2d_face = project_face_to_xy(back_face)
else
  back_2d_face = nil  # Không tạo
end
```

#### 3.2.2 2D Group Structure
```
2D_Group (projection của board)
│
├── 2D Face(s)
│   ├── Front face projection (LUÔN có)
│   │   - Hình chiếu xuống mặt phẳng XY
│   │   - Normal = [0, 0, 1] (luôn hướng lên Z+)
│   │
│   └── Back face projection (NẾU có intersection)
│       - Hình chiếu xuống mặt phẳng XY
│       - Normal = [0, 0, 1]
│
├── Boundary Edges (welded)
│   - Các cạnh của board được weld thành 1 edge khép kín
│   - KHÔNG có face bên trong
│   - Chỉ dùng để xác định outline
│
└── Label (clone)
    - Clone từ board label gốc
    - Giữ đúng vị trí: tâm của front face
    - Giữ đúng hướng: xoay theo label-rotation
    - Transform: chỉ rotation quanh trục Z
```

**Code Implementation**:
```ruby
def create_2d_group(board, sheet)
  # Tạo 2D group
  group_2d = sheet.entities.add_group
  group_2d.name = "__2D_#{board.name}"
  group_2d.set_attribute('ABF', 'is-2d-projection', true)
  group_2d.set_attribute('ABF', 'source-board-id', board.entityID)
  
  # 1. Project front face (LUÔN có)
  front_face = find_front_face(board)
  front_2d = project_face_to_xy_plane(front_face)
  
  # Add vào 2D group với normal hướng lên Z+
  add_face_to_group(group_2d, front_2d, normal: [0, 0, 1])
  
  # 2. Project back face (NẾU có intersection)
  if has_intersections?(board)
    back_face = find_back_face(board)
    back_2d = project_face_to_xy_plane(back_face)
    add_face_to_group(group_2d, back_2d, normal: [0, 0, 1])
  end
  
  # 3. Create boundary edges (welded, no face)
  boundary = get_board_boundary(board)
  boundary_2d = project_edges_to_xy(boundary)
  welded_edge = weld_edges(boundary_2d)
  group_2d.entities.add_edges(welded_edge)
  
  # 4. Clone label
  original_label = find_label(board)
  cloned_label = clone_label_to_2d(original_label, board)
  
  # Position label at face center
  face_center_2d = front_2d.bounds.center
  face_center_2d.z = 0  # Flatten to XY plane
  
  # Rotate label theo label-rotation (chiều kim đồng hồ)
  label_rotation = board.get_attribute('ABF', 'label-rotation') || 0
  rotation_radians = -label_rotation.degrees  # Negative = clockwise
  
  label_transform = Geom::Transformation.new
  label_transform.set!(
    face_center_2d,
    Geom::Vector3d.new(0, 0, 1),  # Around Z axis
    rotation_radians
  )
  
  cloned_label.transform!(label_transform)
  group_2d.entities.add_instance(cloned_label)
  
  return group_2d
end

def project_face_to_xy_plane(face)
  # Lấy vertices của face
  vertices_3d = face.vertices.map(&:position)
  
  # Project xuống XY plane (z=0)
  vertices_2d = vertices_3d.map { |v| 
    Geom::Point3d.new(v.x, v.y, 0) 
  }
  
  return vertices_2d
end

def has_intersections?(board)
  board.entities.grep(Sketchup::Group).any? { |g| 
    g.get_attribute('ABF', 'is-intersect') == true
  }
end
```

#### 3.2.3 Label Clone Behavior
```ruby
def clone_label_to_2d(original_label, board)
  cloned = original_label.copy
  
  # CRITICAL: Giữ đúng vị trí và hướng
  # 1. Vị trí: tâm của front face (đã flatten về z=0)
  # 2. Hướng: xoay theo label-rotation
  
  label_rotation = board.get_attribute('ABF', 'label-rotation') || 0
  
  # Transform properties được preserve
  cloned.set_attribute('ABF', 'is-label', true)
  cloned.set_attribute('ABF', 'label-rotation', label_rotation)
  cloned.set_attribute('ABF', 'is-2d-clone', true)
  
  return cloned
end
```

### 3.3 Bước 3: Nesting Rotation Logic

**Arrow orientation rule**: Khi nesting board vào sheet, xoay 2D_group sao cho **arrow luôn hướng về Y=0**

```ruby
def calculate_nesting_rotation(board_2d_group, placement_position, sheet)
  # Lấy label rotation hiện tại
  current_rotation = board_2d_group.get_attribute('ABF', 'label-rotation') || 0
  
  # Sheet origin Y
  sheet_origin_y = sheet.transformation.origin.y
  
  # Board sẽ đặt ở vị trí nào
  target_y = placement_position.y
  
  # Arrow cần hướng về Y=0
  # Nếu board ở phía trên origin → arrow hướng xuống (270° hoặc -90°)
  # Nếu board ở phía dưới origin → arrow hướng lên (90°)
  
  if target_y > sheet_origin_y
    desired_arrow_direction = 270.degrees  # Down
  else
    desired_arrow_direction = 90.degrees   # Up
  end
  
  # Tính rotation cần thiết
  # Arrow hiện tại ở góc: current_rotation
  # Arrow cần ở góc: desired_arrow_direction
  
  rotation_delta = desired_arrow_direction - current_rotation
  
  # Normalize về [0, 360)
  rotation_delta = rotation_delta % 360
  
  return rotation_delta
end

def apply_nesting_transform(board_2d_group, placement, sheet)
  # 1. Rotate để arrow về Y=0
  rotation = calculate_nesting_rotation(
    board_2d_group, 
    placement[:position], 
    sheet
  )
  
  # 2. Translate đến vị trí placement
  transform = Geom::Transformation.new
  
  # Rotate around center
  center = board_2d_group.bounds.center
  transform = transform * Geom::Transformation.rotation(
    center, 
    Geom::Vector3d.new(0, 0, 1),  # Z axis
    rotation.degrees
  )
  
  # Translate to position
  offset = placement[:position] - center
  transform = transform * Geom::Transformation.translation(offset)
  
  # Apply
  board_2d_group.transform!(transform)
  
  # Save final rotation
  final_rotation = (rotation + (board_2d_group.get_attribute('ABF', 'label-rotation') || 0)) % 360
  board_2d_group.set_attribute('ABF', 'final-rotation', final_rotation)
end
```

### 3.4 Ví dụ: Board với label-rotation = 120°

```
Original Board (3D):
  Label rotation: 120° (clockwise from 0°)
  Arrow direction: 120° from X-axis
  
2D Projection:
  ┌─────────────────┐
  │   ┌───┐  Name   │
  │   │ 7 │  ABF    │
  │   └───┘         │
  │      ↗          │  ← Arrow at 120° (tilted)
  └─────────────────┘

Nesting to Sheet position (Y=1500, above Y=0):
  Need arrow to point down (270°)
  Current arrow: 120°
  Rotation needed: 270° - 120° = 150°
  
  Rotate 2D group 150° clockwise:
  ┌─────────────────┐
  │   ┌───┐  Name   │
  │   │ 7 │  ABF    │
  │   └───┘         │
  │      ↓          │  ← Arrow now points to Y=0 ✓
  └─────────────────┘
```

### 3.5 Dữ liệu đầu ra N1
```
Nesting Root Group:
│
├── Sheet 1 Group
│   ├── Board 1 (2D projection)
│   │   ├── Front face (z=0, normal=[0,0,1])
│   │   ├── Boundary edges (welded)
│   │   └── Label clone (arrow → Y=0)
│   │
│   ├── Board 2 (2D projection)
│   │   ├── Front face (z=0, normal=[0,0,1])
│   │   ├── Back face (z=0, có intersection)
│   │   ├── Boundary edges (welded)
│   │   └── Label clone (arrow → Y=0)
│   │
│   └── ...
│
└── Sheet 2 Group
    └── ...
```

---

## 4. Quy trình Extra Nesting (N2) - Yêu cầu mới

### 4.1 Input
- **Sơ đồ nesting cũ**: Group có `is-nesting-root: true` với các 2D projections
- **Tấm ván phát sinh mới**: 3D boards chưa được nesting

### 4.2 Bước 1: Extra Label Tool
**Chức năng**: Gắn nhãn cho tấm ván mới dựa trên hệ thống label hiện có

**Yêu cầu**:
- Kế thừa quy tắc đánh số Index từ N1
- Tự động xác định Front/Back Face tương tự N1
- Phân biệt tấm ván mới (extra) với tấm ván đã nesting
- Lưu flag đánh dấu đây là "extra item"
- Tạo label với 4 components: Index + Name + ABF + Arrow
- **Gán label-rotation**: User có thể chọn 0°, 90°, 180°, 270° (hoặc custom)

**Output**:
- Tấm ván mới có đầy đủ thông tin label
- Tương thích với format label của N1
- Có `label-rotation` attribute

### 4.3 Bước 2: Extra Nesting Algorithm

**Input**:
1. Nesting root group (từ N1) - chứa các 2D projections
2. Danh sách tấm ván extra 3D (đã label)

**Thuật toán**:

#### Step 1: Group and validate extra boards
```ruby
def prepare_extra_boards_for_nesting(extra_boards_3d, nesting_root)
  # Step 1: Group by classification (material + thickness)
  grouped_boards = group_boards_for_nesting(extra_boards_3d)
  
  boards_2d_by_class = {}
  
  grouped_boards.each do |class_key, boards_3d|
    boards_2d_list = []
    
    boards_3d.each do |board_3d|
      # Tạo 2D projection
      board_2d = create_2d_projection(board_3d)
      
      # Lưu classification
      board_2d.set_attribute('ABF', 'classification-key', class_key)
      board_2d.set_attribute('ABF', 'source-3d-board', board_3d.entityID)
      board_2d.set_attribute('ABF', 'is-extra-board', true)
      
      boards_2d_list << board_2d
    end
    
    boards_2d_by_class[class_key] = boards_2d_list
  end
  
  return boards_2d_by_class
end
```

#### Step 2: Analyze existing layout BY CLASSIFICATION
```ruby
def analyze_2d_nesting_layout_by_class(nesting_root)
  sheets_by_class = {}
  
  # Duyệt qua tất cả sheets
  nesting_root.entities.each do |sheet_group|
    next unless sheet_group.get_attribute('ABF', 'sheet-id')
    
    # Get classification of this sheet
    class_key = sheet_group.get_attribute('ABF', 'classification-key')
    next unless class_key
    
    # Initialize array for this classification
    sheets_by_class[class_key] ||= []
    
    # Analyze this sheet
    boards_2d = sheet_group.entities.select { |e| 
      e.is_a?(Sketchup::Group) && 
      e.get_attribute('ABF', 'is-2d-projection')
    }
    
    occupied = boards_2d.map { |b| get_2d_bounds(b) }
    gaps = calculate_gaps_2d(sheet_group, occupied)
    
    sheets_by_class[class_key] << {
      group: sheet_group,
      sheet_id: sheet_group.get_attribute('ABF', 'sheet-id'),
      material: sheet_group.get_attribute('ABF', 'sheet-type'),
      thickness: sheet_group.get_attribute('ABF', 'sheet-thickness'),
      boards: boards_2d,
      occupied: occupied,
      gaps: gaps
    }
  end
  
  return sheets_by_class
end
```

#### Step 3: Place boards BY CLASSIFICATION
```ruby
def place_extra_boards_by_classification(boards_2d_by_class, nesting_root, settings)
  all_results = []
  
  # Process each classification group separately
  boards_2d_by_class.each do |class_key, boards_2d|
    # Parse classification
    material, thickness = parse_classification_key(class_key)
    
    # Find or create sheets for this classification
    sheets = find_sheets_by_classification(nesting_root, class_key)
    
    if sheets.empty?
      # Create first sheet for this classification
      first_sheet = create_classified_sheet(
        nesting_root,
        material: material,
        thickness: thickness,
        sheet_id: 1
      )
      
      sheets = [{
        group: first_sheet,
        sheet_id: 1,
        material: material,
        thickness: thickness,
        boards: [],
        occupied: [],
        gaps: [calculate_full_sheet_gap(first_sheet)]
      }]
    end
    
    # Sort boards by size (largest first)
    sorted_boards = boards_2d.sort_by { |b| -b.bounds.diagonal }
    
    # Place each board
    sorted_boards.each do |board_2d|
      # CRITICAL: Only search in sheets with SAME classification
      placement = find_best_placement_2d(board_2d, sheets, settings)
      
      if placement
        # Place in existing sheet
        apply_nesting_transform_2d(
          board_2d,
          placement[:sheet],
          placement[:position],
          placement[:rotation],
          arrow_to_origin: true
        )
        
        # Move to sheet
        sheet_group = placement[:sheet][:group]
        board_2d.move!(sheet_group.entities)
        
        all_results << {
          board: board_2d,
          sheet: sheet_group,
          classification: class_key,
          success: true
        }
        
        # Update gaps for this sheet
        placement[:sheet][:occupied] << get_2d_bounds(board_2d)
        placement[:sheet][:gaps] = calculate_gaps_2d(
          sheet_group, 
          placement[:sheet][:occupied]
        )
      else
        # Create new sheet for this classification
        if settings[:auto_create_sheet]
          # Find max sheet ID for this classification
          max_id = sheets.map { |s| s[:sheet_id] }.max || 0
          
          new_sheet_group = create_classified_sheet(
            nesting_root,
            material: material,
            thickness: thickness,
            sheet_id: max_id + 1
          )
          
          # Place at origin
          place_at_origin_2d(board_2d, new_sheet_group)
          
          # Add to sheets list
          new_sheet_data = {
            group: new_sheet_group,
            sheet_id: max_id + 1,
            material: material,
            thickness: thickness,
            boards: [board_2d],
            occupied: [get_2d_bounds(board_2d)],
            gaps: []  # Recalculate
          }
          sheets << new_sheet_data
          
          all_results << {
            board: board_2d,
            sheet: new_sheet_group,
            classification: class_key,
            success: true,
            new_sheet: true
          }
        else
          all_results << {
            board: board_2d,
            classification: class_key,
            success: false,
            reason: "No suitable gap in #{class_key} sheets"
          }
        end
      end
    end
  end
  
  return all_results
end

def find_sheets_by_classification(nesting_root, class_key)
  sheets = []
  
  nesting_root.entities.each do |entity|
    next unless entity.is_a?(Sketchup::Group)
    next unless entity.get_attribute('ABF', 'sheet-id')
    
    sheet_class = entity.get_attribute('ABF', 'classification-key')
    
    if sheet_class == class_key
      # Analyze this sheet
      boards_2d = entity.entities.select { |e|
        e.is_a?(Sketchup::Group) &&
        e.get_attribute('ABF', 'is-2d-projection')
      }
      
      occupied = boards_2d.map { |b| get_2d_bounds(b) }
      gaps = calculate_gaps_2d(entity, occupied)
      
      sheets << {
        group: entity,
        sheet_id: entity.get_attribute('ABF', 'sheet-id'),
        material: entity.get_attribute('ABF', 'sheet-type'),
        thickness: entity.get_attribute('ABF', 'sheet-thickness'),
        classification: class_key,
        boards: boards_2d,
        occupied: occupied,
        gaps: gaps
      }
    end
  end
  
  return sheets
end

def parse_classification_key(class_key)
  # "Color_A02_17.5" → ["Color_A02", 17.5]
  parts = class_key.split('_')
  thickness = parts.pop.to_f
  material = parts.join('_')
  
  return [material, thickness]
end
```

def create_2d_projection(board_3d)
  # Tạo temporary group cho 2D projection
  temp_group = Sketchup.active_model.entities.add_group
  
  # 1. Front face → 2D face
  front_face = find_front_face(board_3d)
  front_2d = project_face_to_xy_plane(front_face)
  add_face_to_group(temp_group, front_2d, normal: [0, 0, 1])
  
  # 2. Back face → 2D face (nếu có intersection)
  if has_intersections?(board_3d)
    back_face = find_back_face(board_3d)
    back_2d = project_face_to_xy_plane(back_face)
    add_face_to_group(temp_group, back_2d, normal: [0, 0, 1])
  end
  
  # 3. Boundary edges (welded)
  boundary = get_board_boundary(board_3d)
  boundary_2d = project_edges_to_xy(boundary)
  welded_edge = weld_edges(boundary_2d)
  temp_group.entities.add_edges(welded_edge)
  
  # 4. Clone label với đúng vị trí và rotation
  label_rotation = board_3d.get_attribute('ABF', 'label-rotation') || 0
  cloned_label = clone_label_to_2d(
    find_label(board_3d), 
    board_3d,
    rotation: label_rotation
  )
  
  # Position at face center
  face_center = front_2d.bounds.center
  face_center.z = 0
  
  cloned_label.transformation = create_label_transform(
    position: face_center,
    rotation: label_rotation
  )
  
  temp_group.entities.add_instance(cloned_label.definition)
  
  return temp_group
end
```

#### Step 2: Analyze existing 2D layout
```ruby
def analyze_2d_nesting_layout(nesting_root)
  sheets = {}
  
  # Duyệt qua tất cả sheets
  nesting_root.entities.each do |sheet_group|
    next unless sheet_group.get_attribute('ABF', 'sheet-id')
    
    sheet_id = sheet_group.get_attribute('ABF', 'sheet-id')
    
    # Thu thập tất cả 2D boards trong sheet
    boards_2d = sheet_group.entities.select { |e| 
      e.is_a?(Sketchup::Group) && 
      e.get_attribute('ABF', 'is-2d-projection')
    }
    
    # Tính occupied regions (từ boundary edges)
    occupied = boards_2d.map { |b| get_2d_bounds(b) }
    
    # Tính gaps
    gaps = calculate_gaps_2d(sheet_group, occupied)
    
    sheets[sheet_id] = {
      group: sheet_group,
      boards: boards_2d,
      occupied: occupied,
      gaps: gaps
    }
  end
  
  return sheets
end
```

#### Step 3: Place extra boards vào gaps
```ruby
def place_extra_boards_2d(boards_2d_extra, sheets, settings)
  results = []
  
  # Sort boards by size (largest first)
  sorted_boards = boards_2d_extra.sort_by { |b| -b.bounds.diagonal }
  
  sorted_boards.each do |board_2d|
    placement = find_best_placement_2d(board_2d, sheets, settings)
    
    if placement
      # Apply placement với rotation để arrow → Y=0
      apply_nesting_transform_2d(
        board_2d, 
        placement[:sheet],
        placement[:position],
        placement[:rotation],
        arrow_to_origin: true
      )
      
      # Add vào sheet
      sheet_group = placement[:sheet][:group]
      board_2d.move!(sheet_group.entities)
      
      results << {
        board: board_2d,
        sheet: sheet_group,
        success: true
      }
    else
      # Create new sheet (nếu enabled)
      if settings[:auto_create_sheet]
        new_sheet = create_new_sheet_2d(nesting_root, board_2d)
        place_at_origin_2d(board_2d, new_sheet)
        
        results << {
          board: board_2d,
          sheet: new_sheet,
          success: true,
          new_sheet: true
        }
      else
        results << {
          board: board_2d,
          success: false,
          reason: "No suitable gap"
        }
      end
    end
  end
  
  return results
end

def apply_nesting_transform_2d(board_2d, sheet, position, rotation, arrow_to_origin: true)
  # 1. Tính rotation để arrow hướng về Y=0
  if arrow_to_origin
    label_rotation = board_2d.get_attribute('ABF', 'label-rotation') || 0
    sheet_origin_y = sheet[:group].transformation.origin.y
    target_y = position.y
    
    # Arrow direction calculation
    if target_y > sheet_origin_y
      desired_arrow_angle = 270  # Down to Y=0
    else
      desired_arrow_angle = 90   # Up to Y=0
    end
    
    # Rotation delta
    rotation_needed = (desired_arrow_angle - label_rotation) % 360
  else
    rotation_needed = rotation
  end
  
  # 2. Build transform
  center = board_2d.bounds.center
  
  # Rotate
  rot_transform = Geom::Transformation.rotation(
    center,
    Geom::Vector3d.new(0, 0, 1),
    rotation_needed.degrees
  )
  
  # Translate
  new_center = rot_transform * center
  offset = position - new_center
  trans_transform = Geom::Transformation.translation(offset)
  
  # Apply
  final_transform = trans_transform * rot_transform
  board_2d.transform!(final_transform)
  
  # Save final state
  board_2d.set_attribute('ABF', 'nesting-rotation', rotation_needed)
  board_2d.set_attribute('ABF', 'nesting-position', position.to_a)
end
```

#### Step 4: Finalize và maintain references
```ruby
def finalize_extra_nesting(results)
  # CRITICAL: Keep both 3D boards và 2D projections
  # - 3D boards: giữ nguyên cho reference và editing
  # - 2D projections: dùng cho nesting layout và export cutting
  
  results.each do |result|
    next unless result[:success]
    
    board_2d = result[:board]
    source_3d_id = board_2d.get_attribute('ABF', 'source-3d-board')
    
    if source_3d_id
      board_3d = find_entity_by_id(source_3d_id)
      
      if board_3d
        # Option: Keep both (SELECTED)
        # 1. Keep 3D board visible for editing
        board_3d.hidden = false
        
        # 2. Link 2D ↔ 3D
        board_3d.set_attribute('ABF', '2d-projection-id', board_2d.entityID)
        board_2d.set_attribute('ABF', 'source-3d-board', board_3d.entityID)
        
        # 3. Mark as nested
        board_3d.set_attribute('ABF', 'is-nested', true)
        board_3d.set_attribute('ABF', 'nested-in-sheet', result[:sheet].get_attribute('ABF', 'sheet-id'))
        board_3d.set_attribute('ABF', 'nested-at', Time.now.to_s)
        
        # 4. Optional: Move 3D board to separate layer for organization
        # board_3d.layer = "Nested_Boards_3D"
      end
    end
    
    # Mark 2D projection for export
    board_2d.set_attribute('ABF', 'export-for-cutting', true)
    board_2d.set_attribute('ABF', 'is-nested-2d', true)
  end
  
  return results
end
```

### 4.4 Relationship: 3D Boards ↔ 2D Projections

**Data Structure**:
```
Model Structure:
│
├── 3D Boards (Original, editable)
│   ├── Board 31 [3D geometry]
│   │   - is-board: true
│   │   - is-nested: true
│   │   - 2d-projection-id: 172369
│   │   - nested-in-sheet: 1
│   │   - All components (drills, intersects, etc.)
│   │
│   ├── Board 32 [3D geometry]
│   └── ...
│
└── Nesting Root (2D projections for cutting)
    ├── Sheet 1
    │   ├── Board 31 [2D projection]
    │   │   - is-2d-projection: true
    │   │   - source-3d-board: 127763
    │   │   - export-for-cutting: true
    │   │   - nesting-rotation: 150
    │   │   - nesting-position: [120.5, 450.2]
    │   │
    │   └── ...
    │
    └── Sheet 2
        └── ...
```

**Benefits of keeping both**:
1. ✅ 3D boards có thể edit components (drills, intersects)
2. ✅ 2D projections dùng cho nesting layout
3. ✅ Export cutting file từ 2D (đơn giản, flat)
4. ✅ Sync changes: khi edit 3D → update 2D projection

### 4.5 Export Cutting File Logic

**Sử dụng 2D projections để export**:
```ruby
def export_cutting_file(nesting_root, sheet_id = nil)
  cutting_data = []
  
  # Filter sheets
  sheets = if sheet_id
    [find_sheet_by_id(nesting_root, sheet_id)]
  else
    find_all_sheets(nesting_root)
  end
  
  sheets.each do |sheet|
    sheet_data = {
      sheet_id: sheet.get_attribute('ABF', 'sheet-id'),
      sheet_type: sheet.get_attribute('ABF', 'sheet-type'),
      dimension: sheet.get_attribute('ABF', 'sheet-dimension'),
      boards: []
    }
    
    # Collect 2D projections only
    boards_2d = sheet.entities.select { |e|
      e.is_a?(Sketchup::Group) && 
      e.get_attribute('ABF', 'is-2d-projection') &&
      e.get_attribute('ABF', 'export-for-cutting')
    }
    
    boards_2d.each do |board_2d|
      # Extract cutting paths from 2D faces
      cutting_paths = extract_cutting_paths_2d(board_2d)
      
      # Extract label info
      label_info = extract_label_info(board_2d)
      
      # Get source 3D board for additional data
      source_3d_id = board_2d.get_attribute('ABF', 'source-3d-board')
      source_3d = find_entity_by_id(source_3d_id)
      
      board_data = {
        board_index: source_3d.get_attribute('ABF', 'board-index'),
        board_name: source_3d.name,
        position: board_2d.get_attribute('ABF', 'nesting-position'),
        rotation: board_2d.get_attribute('ABF', 'nesting-rotation'),
        cutting_paths: cutting_paths,
        drills: extract_drills_from_3d(source_3d),  # From 3D source
        edge_bands: extract_edge_bands_from_3d(source_3d),  # From 3D source
        label: label_info
      }
      
      sheet_data[:boards] << board_data
    end
    
    cutting_data << sheet_data
  end
  
  return cutting_data
end

def extract_cutting_paths_2d(board_2d)
  paths = []
  
  # 1. Outer boundary (from welded edges)
  boundary_edges = board_2d.entities.grep(Sketchup::Edge).select { |e|
    !e.faces.any?  # Edges without faces = boundary
  }
  
  outer_path = extract_closed_loop(boundary_edges)
  paths << {
    type: 'outer_boundary',
    points: outer_path.map { |pt| [pt.x, pt.y] }  # 2D coordinates
  }
  
  # 2. Inner paths (from 2D faces - holes, intersections)
  faces_2d = board_2d.entities.grep(Sketchup::Face)
  
  faces_2d.each do |face|
    # Inner loops (holes)
    face.loops.each_with_index do |loop, index|
      next if index == 0  # Skip outer loop
      
      inner_path = loop.vertices.map { |v| v.position }
      paths << {
        type: 'inner_hole',
        points: inner_path.map { |pt| [pt.x, pt.y] }
      }
    end
  end
  
  return paths
end
```

### 4.6 Sync Changes: 3D → 2D

**Khi user edit 3D board sau khi nested**:
```ruby
def sync_3d_changes_to_2d(board_3d)
  # Find corresponding 2D projection
  projection_2d_id = board_3d.get_attribute('ABF', '2d-projection-id')
  return unless projection_2d_id
  
  board_2d = find_entity_by_id(projection_2d_id)
  return unless board_2d
  
  # Get current 2D position and rotation
  saved_position = board_2d.get_attribute('ABF', 'nesting-position')
  saved_rotation = board_2d.get_attribute('ABF', 'nesting-rotation')
  
  # Delete old 2D projection
  board_2d.erase!
  
  # Recreate 2D projection with new geometry
  new_board_2d = create_2d_projection(board_3d)
  
  # Restore position and rotation
  if saved_position && saved_rotation
    apply_nesting_transform_2d(
      new_board_2d,
      sheet: find_parent_sheet(board_2d),
      position: Geom::Point3d.new(saved_position),
      rotation: saved_rotation,
      arrow_to_origin: false  # Keep existing rotation
    )
  end
  
  # Update cross-references
  board_3d.set_attribute('ABF', '2d-projection-id', new_board_2d.entityID)
  new_board_2d.set_attribute('ABF', 'source-3d-board', board_3d.entityID)
  
  UI.messagebox("2D projection updated for Board #{board_3d.get_attribute('ABF', 'board-index')}")
end

# Observer to auto-sync
class Board3DObserver < Sketchup::EntityObserver
  def onChangeEntity(entity)
    # When 3D board is modified
    if entity.get_attribute('ABF', 'is-board') && 
       entity.get_attribute('ABF', 'is-nested')
      
      # Ask user to sync
      result = UI.messagebox(
        "Board geometry changed. Update 2D projection?",
        MB_YESNO
      )
      
      sync_3d_changes_to_2d(entity) if result == IDYES
    end
  end
end
```

**Output**:
```
Updated Nesting Root Group:
│
├── Sheet 1
│   ├── Board 1 (2D, from N1)
│   ├── Board 2 (2D, from N1)
│   ├── Board 31 (2D, EXTRA) ← New
│   └── ...
│
├── Sheet 2
│   ├── Board 7 (2D, from N1)
│   ├── Board 34 (2D, EXTRA) ← New
│   └── ...
│
└── Sheet 3 [NEW]
    ├── Board 33 (2D, EXTRA) ← New
    └── Board 35 (2D, EXTRA) ← New
```

---

## 5. Phân tích cấu trúc dữ liệu từ Log

### 5.1 Cấu trúc Nesting Hierarchy (4 tầng)

```
Nesting Root Group (__ABF_Nesting)
│   - is-nesting-root: true
│   - shift-origin: 3
│   - bounds: [3940.2, 5280.1, 0.0] mm
│
└── Sheet Level Groups (Color A02-sheet-1, sheet-2)
    │   - sheet-id: 1, 2
    │   - sheet-dimension: [1220, 2440]
    │   - sheet-thickness: 17.5
    │   - sheet-type: "Color A02"
    │
    └── Board Level Groups (__15. Đáy, __9. Tầng, __23. Chân...)
        │   - board-index: 1-31
        │   - is-board: true
        │   - label-rotation: 0
        │   - drills-desc: [[...], [...]]
        │   - edge-band-desc: [...]
        │   - edge-band-types: [...]
        │
        └── Component Level (Nested Object)
            ├── _ABF_cuttingLines (đường cắt CNC)
            ├── _ABF_edgeBanding (ký hiệu dán cạnh)
            ├── _ABF_Label (nhãn hiển thị)
            ├── _ABF_hingeCup (lỗ bản lề)
            ├── _ABF_Intersect (rãnh khớp)
            ├── _ABF_sideDrill (lỗ khoan cạnh)
            └── Board Geometry (6 faces + 12 edges)
```

### 5.2 Chi tiết từng cấp

#### 5.2.1 Tầng 1: Nesting Root
```ruby
entityID: 127760
persistent_id: 705628
bounds_mm: [3940.2, 5280.1, 0.0]
container_stats: faces=0, edges=0, groups=4
attributes:
  - [ABF] "is-nesting-root" => true
  - [ABF] "shift-origin" => 3
```
- **Vai trò**: Container tổng, không chứa geometry
- **Chức năng**: Nhóm tất cả sheets lại

#### 5.2.2 Tầng 2: Sheet Level
```ruby
# Sheet 1
entityID: 127623
sheet-id: 1
sheet-dimension: [1220, 2440]
sheet-thickness: 17.5
sheet-type: "Color A02"
transform: [[1.0, 0.0, 0.0, -115.748031], 
           [0.0, 1.0, 0.0, -318.110236], 
           [0.0, 0.0, 1.0, 0.0], 
           [0.0, 0.0, 0.0, 1.0]]
container_stats: groups=16  # 16 tấm ván
```
- **Vai trò**: Đại diện cho 1 tấm ván gỗ nguyên liệu
- **Dimensions**: 1220mm × 2440mm (kích thước chuẩn)
- **Transform**: Vị trí sheet trên canvas

#### 5.2.3 Tầng 3: Board Level
```ruby
# Ví dụ: Board Index 15 (Đáy)
entityID: 76147
board-index: 15
is-board: true
bounds_mm: [398.0, 1198.0, 0.0]
transform: [[-0.0, -1.0, 0.0, -114.999999], 
           [1.0, -0.0, 0.0, -271.555118], 
           [0.0, 0.0, 1.0, 0.0]]
container_stats: groups=5  # 5 components bên trong
attributes:
  - [ABF] "board-index" => 15
  - [ABF] "drills-desc" => [[...], [...]]  # Thông tin khoan
  - [ABF] "edge-band-desc" => [...]        # Dán cạnh
  - [ABF] "label-rotation" => 0
```

**Thông tin chi tiết trong Board**:
- **drills-desc**: Mảng 2 phần tử
  - Phần 1: Thông tin vị trí khoan dạng string (VD: "13_37_297.5_321.5")
  - Phần 2: Mảng chi tiết lỗ khoan [diameter, depth, [x, y, z]]
  
- **edge-band-desc**: Danh sách dán cạnh
  - Format: [x1, y1, z1, x2, y2, z2, "CHỈ - 1mm"]
  
- **Transform**: Ma trận xoay + dịch chuyển
  - Xác định vị trí, góc xoay board trên sheet

#### 5.2.4 Tầng 4: Component Level
```ruby
# Ví dụ: Board __2 có 5 groups con
1. _ABF_cuttingLines (122 edges)  # Đường cắt CNC
2. _ABF_edgeBanding (12 edges)    # Ký hiệu dán cạnh
3. _ABF_Label (38 edges)          # Text nhãn số
4. _ABF_hingeCup (72 edges) ×2    # Lỗ bản lề
```

**Component đặc biệt trong Board mới (Index 31)**:
```ruby
# Board 31 (Tấm mới chưa nesting)
bounds_mm: [17.5, 364.5, 621.4]  # 3D bounding box
container_stats: groups=12        # Nhiều components

Groups bên trong:
- _ABF_Intersect ×4    # Rãnh khớp với tấm khác
- _ABF_sideDrill ×3    # Lỗ khoan cạnh (minifix)
- _ABF_sideDrillDepth ×3
- _ABF_Label ×1        # Nhãn "31. 3. Hông Phải"
- Board Geometry       # 6 faces + 12 edges
```

### 5.3 Face Types trong Board

Từ log `new_nested_board_face_level`:
```ruby
Face 1: area=223552.5mm², normal=[1.0, 0.0, 0.0]   # Side face
Face 2: area=6361.25mm², normal=[0.0, 0.0, 1.0]    # Front/Back (nhỏ)
Face 3: area=10762.5mm², normal=[0.0, 1.0, 0.0]    # Side (có edge-band)
Face 4: area=223552.5mm², normal=[-1.0, 0.0, 0.0]  # FRONT FACE ⭐
        - is-cnced-face: true
        - is-labeled-face: true
Face 5: area=6361.25mm², normal=[0.0, 0.0, -1.0]   # Back (nhỏ)
Face 6: area=10762.5mm², normal=[0.0, -1.0, 0.0]   # Side face
```

**Cách xác định Front/Back Face**:
1. Tìm 2 faces có `area` lớn nhất và song song (normal ngược nhau)
2. Face có attribute `is-labeled-face: true` → **FRONT FACE**
3. Face song song còn lại → **BACK FACE**

### 5.4 Label Structure

**Label Components**:
```
┌─────────────────────────┐
│   ┌───┐  Hội Giữa       │  
│   │ 7 │  ABF            │  ← Text: Index + Name + Company
│   └───┘                 │
│    ↑                    │  ← Arrow vector
└─────────────────────────┘
```

**Label Properties**:
```ruby
# Label Group
entityID: 194710
tag: ABF_Label
bounds_mm: [0.0, 191.599, 80.0]
transform: rotation + position matrix
container_stats: edges=142  # Text + Arrow được vẽ bằng edges
attributes:
  - [ABF] "is-label" => true
  - [ABF] "label-height" => 2.0
  - [ABF] "label-scale" => 1.5748031496062993
  - [ABF] "label-width" => 7.73327966862917
```

**Label Elements**:
1. **Index Box**: Số thứ tự board (VD: "7") trong khung vuông
2. **Board Name**: Tên instance của board (VD: "Hội Giữa")
3. **Company Tag**: "ABF"
4. **Direction Arrow**: Vector chỉ hướng
   - Luôn song song với trục Y của sheet
   - Luôn hướng về gốc Y=0
   - Giúp xác định orientation của board

**Label Positioning Logic**:
```ruby
def calculate_label_transform(board, sheet)
  # Label đặt trên front face (is-labeled-face)
  front_face = find_front_face(board)
  
  # Tính center của front face
  center = front_face.bounds.center
  
  # Arrow direction: luôn về phía Y=0 của sheet
  sheet_origin = sheet.transformation.origin
  arrow_direction = Geom::Vector3d.new(0, -1, 0) # Về Y=0
  
  # Tính rotation để arrow đúng hướng
  rotation = calculate_rotation_to_y_axis(board, sheet)
  
  # Transform matrix
  transform = Geom::Transformation.new
  transform.set!(center, front_face.normal, arrow_direction)
  
  return transform
end
```

**Arrow Behavior**:
```
Sheet coordinate:
  Y=2440mm (top)
      ↑
      │
      │  Board A (Y=1500)
      │    ↓  arrow hướng xuống
      │
      │  Board B (Y=1000)
      │    ↓  arrow hướng xuống
      │
  Y=0mm (origin)

- Tất cả arrows đều hướng xuống Y=0
- Arrow giúp identify orientation khi board bị xoay
```

### 5.5 Attributes cần thiết cho Extra Nesting

**Board Level** (đã có):
```ruby
[ABF] "board-index" => 31
[ABF] "is-board" => true
[ABF] "label-rotation" => 0
[ABF] "edge-band-types" => "[...]"
```

**Đề xuất thêm**:
```ruby
[ABF] "is-extra-board" => true        # Đánh dấu board extra
[ABF] "extra-added-date" => timestamp
[ABF] "original-parent-sheet" => 1    # Sheet ID gốc
[ABF] "nesting-attempt" => 1          # Lần thử nesting thứ mấy
```

**Face Level** (để xác định Front/Back):
```ruby
[ABF] "is-labeled-face" => true       # ĐÃ CÓ - Front face
[ABF] "is-cnced-face" => true         # ĐÃ CÓ - Face có gia công
[ABF] "face-type" => "front"|"back"   # ĐỀ XUẤT thêm
```

---

## 6. Yêu cầu chức năng chi tiết

### 6.1 Extra Label Tool

#### 6.1.1 Board Validation
**CRITICAL**: Board phải thỏa mãn điều kiện:
```ruby
def validate_board_geometry(group)
  faces = group.entities.grep(Sketchup::Face)
  
  # Phải có ít nhất 6 faces (hình hộp)
  return false if faces.length < 6
  
  # Sắp xếp faces theo diện tích
  sorted = faces.sort_by { |f| -f.area }
  
  # 2 faces lớn nhất
  face1, face2 = sorted[0], sorted[1]
  
  # Kiểm tra đồng phẳng (normals song song)
  unless face1.normal.parallel?(face2.normal)
    return false, "Two largest faces are not parallel"
  end
  
  # Kiểm tra đồng dạng (diện tích gần bằng nhau)
  area_diff = (face1.area - face2.area).abs
  area_tolerance = face1.area * 0.01  # 1% tolerance
  
  unless area_diff < area_tolerance
    return false, "Two largest faces are not congruent (area mismatch)"
  end
  
  # Kiểm tra hình chữ nhật (4 cạnh)
  unless face1.edges.length == 4 && face2.edges.length == 4
    return false, "Faces must be rectangular (4 edges)"
  end
  
  return true, "Valid board geometry"
end
```

#### 6.1.2 Label Generation
**Label phải bao gồm**:
```ruby
def create_label(board, board_index, sheet)
  label_group = board.entities.add_group
  label_group.name = "_ABF_Label"
  label_group.set_attribute('ABF', 'is-label', true)
  
  # Get board info
  board_name = board.name.gsub(/^__\d+\.\s*/, '') # "7. Hội Giữa" → "Hội Giữa"
  
  # 1. Create index box with number
  index_text = board_index.to_s
  create_text_geometry(label_group, index_text, position: [0, 0], 
                       box: true, box_size: [10.mm, 10.mm])
  
  # 2. Create board name text
  create_text_geometry(label_group, board_name, 
                       position: [15.mm, 5.mm], 
                       size: 2.0)
  
  # 3. Create company tag
  create_text_geometry(label_group, "ABF", 
                       position: [15.mm, -5.mm], 
                       size: 1.5)
  
  # 4. Create direction arrow
  # Arrow luôn song song với Y-axis và hướng về Y=0
  arrow_start = [5.mm, -15.mm, 0]
  arrow_end = [5.mm, -25.mm, 0]
  create_arrow_geometry(label_group, arrow_start, arrow_end)
  
  # 5. Position label on front face
  front_face = find_front_face(board)
  label_transform = calculate_label_position(
    front_face, 
    sheet,
    ensure_arrow_to_origin: true  # Arrow luôn hướng về Y=0
  )
  label_group.transform!(label_transform)
  
  # 6. Save label properties
  label_bounds = label_group.bounds
  label_group.set_attribute('ABF', 'label-width', label_bounds.width)
  label_group.set_attribute('ABF', 'label-height', label_bounds.height)
  label_group.set_attribute('ABF', 'label-scale', calculate_scale(label_bounds))
  
  return label_group
end

def create_arrow_geometry(group, start_pt, end_pt)
  # Main arrow line
  group.entities.add_line(start_pt, end_pt)
  
  # Arrow head (2 lines forming "V")
  arrow_vec = Geom::Vector3d.new(start_pt, end_pt).normalize
  perpendicular = arrow_vec * Geom::Vector3d.new(1, 0, 0)
  
  arrow_size = 2.mm
  left_pt = [
    end_pt.x - arrow_vec.x * arrow_size + perpendicular.x * arrow_size,
    end_pt.y - arrow_vec.y * arrow_size + perpendicular.y * arrow_size,
    0
  ]
  right_pt = [
    end_pt.x - arrow_vec.x * arrow_size - perpendicular.x * arrow_size,
    end_pt.y - arrow_vec.y * arrow_size - perpendicular.y * arrow_size,
    0
  ]
  
  group.entities.add_line(end_pt, left_pt)
  group.entities.add_line(end_pt, right_pt)
end

def calculate_label_position(front_face, sheet, ensure_arrow_to_origin: true)
  # Center của front face
  face_center = front_face.bounds.center
  face_normal = front_face.normal
  
  if ensure_arrow_to_origin
    # Xác định hướng về Y=0 trong sheet coordinate
    sheet_transform = sheet.transformation
    sheet_origin_y = sheet_transform.origin.y
    board_y = face_center.y
    
    # Arrow direction: luôn về Y=0
    if board_y > sheet_origin_y
      arrow_direction = Geom::Vector3d.new(0, -1, 0)  # Hướng xuống
    else
      arrow_direction = Geom::Vector3d.new(0, 1, 0)   # Hướng lên (rare)
    end
    
    # Tính rotation để arrow đúng hướng
    rotation_angle = calculate_rotation_to_align(
      current_direction: Geom::Vector3d.new(0, 1, 0),
      target_direction: arrow_direction,
      around_axis: face_normal
    )
    
    # Build transform
    transform = Geom::Transformation.new
    transform.set!(face_center, face_normal)
    transform = transform * Geom::Transformation.rotation(face_center, face_normal, rotation_angle)
    
    return transform
  end
end
```

#### 6.1.3 Labeling Logic
- [ ] **Scan unlabeled groups**: Tìm tất cả groups chưa có `is-board` attribute
- [ ] **Batch validation**: Validate tất cả groups cùng lúc
- [ ] **Auto-detect geometry**: Tự động xác định Front/Back faces
- [ ] **Sequential indexing**: Gán board-index tiếp theo từ max hiện tại
- [ ] **Label generation**: Tạo label với 4 components:
  - Index box với số
  - Board instance name
  - Company tag "ABF"
  - Direction arrow (→ Y=0)
- [ ] **Arrow orientation**: Đảm bảo arrow luôn hướng về Y=0 của sheet
- [ ] **Error reporting**: Hiển thị danh sách groups không hợp lệ

**UI Flow**:
```
┌─────────────────────────────────────────┐
│  Extra Label Tool                       │
├─────────────────────────────────────────┤
│ Scanning model for unlabeled boards...  │
│                                         │
│ ✓ Found 3 valid boards                  │
│ ✗ Found 2 invalid geometries            │
│                                         │
│ Valid boards:                           │
│ ☑ Group#127763 [17.5×364.5×621.4]       │
│   Name: "3. Hông Phải"                  │
│ ☑ Group#127800 [17.5×400×1200]          │
│   Name: "Tấm ngang"                     │
│ ☑ Group#127850 [17.5×500×800]           │
│   Name: "Ngăn giữa"                     │
│                                         │
│ Invalid geometries (click to highlight):│
│ • Group#127900: Not parallel faces      │
│ • Group#127950: Area mismatch (5.2%)    │
│                                         │
│ Next index starts at: 31                │
│ Label will include: Index + Name + ABF  │
│                   + Arrow (→ Y=0)       │
│                                         │
│   [Deselect All]  [Cancel]  [Label All] │
└─────────────────────────────────────────┘
```

### 6.2 Extra Nesting Tool

#### 6.2.1 Batch Processing
**Nesting tất cả boards extra cùng lúc**:
```ruby
def batch_nest_extra_boards(extra_boards, nesting_root, settings)
  results = {
    success: [],
    failed: [],
    new_sheets: []
  }
  
  # Sắp xếp boards theo kích thước (lớn trước)
  sorted_boards = extra_boards.sort_by { |b| -b.bounds.diagonal }
  
  sorted_boards.each do |board|
    # Tìm placement cho từng board
    placement = find_best_placement(board, nesting_root, settings)
    
    if placement
      # Apply placement
      apply_placement(board, placement)
      results[:success] << {
        board: board,
        sheet: placement[:sheet],
        position: placement[:position],
        rotation: placement[:rotation]
      }
    else
      # Không fit → tạo sheet mới (nếu enabled)
      if settings[:auto_create_sheet]
        new_sheet = create_new_sheet(nesting_root, board)
        place_board_at_origin(board, new_sheet)
        
        results[:success] << {
          board: board,
          sheet: new_sheet,
          position: [0, 0],
          rotation: 0
        }
        results[:new_sheets] << new_sheet
      else
        results[:failed] << {
          board: board,
          reason: "No suitable gap found"
        }
      end
    end
  end
  
  return results
end
```

#### 6.2.2 Preview Mode (View-Only)
**Preview KHÔNG cho phép điều chỉnh vị trí thủ công**:
```
┌─────────────────────────────────────────────┐
│  Extra Nesting Preview                      │
├─────────────────────────────────────────────┤
│  ┌───────────────────────────────────────┐  │
│  │ [3D Viewport - Read Only]             │  │
│  │                                       │  │
│  │  Sheet 1: 2 boards placed             │  │
│  │  Sheet 2: 1 board placed              │  │
│  │  Sheet 3: [NEW] 1 board placed        │  │
│  │                                       │  │
│  │  [Zoom to Fit] [Rotate View]          │  │
│  └───────────────────────────────────────┘  │
│                                             │
│  Nesting Results (4 boards):                │
│  ──────────────────────────────────────     │
│  ✓ Board 31 → Sheet 1                       │
│    Position: (120.5, 450.2)                 │
│    Rotation: 90°                            │
│    Waste: 15.3%                             │
│                                             │
│  ✓ Board 32 → Sheet 1                       │
│    Position: (550.0, 100.0)                 │
│    Rotation: 0°                             │
│    Waste: 8.7%                              │
│                                             │
│  ✓ Board 33 → Sheet 2                       │
│    Position: (80.0, 1200.0)                 │
│    Rotation: 90°                            │
│    Waste: 12.1%                             │
│                                             │
│  ✓ Board 34 → Sheet 3 [NEW]                 │
│    Position: (0, 0)                         │
│    Rotation: 0°                             │
│    Waste: N/A (new sheet)                  │
│                                             │
│  Summary:                                   │
│  • Total boards: 4                          │
│  • New sheets created: 1                    │
│  • Average waste: 12.0%                     │
│  • Total area used: 1,845,320 mm²           │
│                                             │
│      [Reject All]  [Accept & Apply]         │
└─────────────────────────────────────────────┘
```

#### 6.2.3 Nesting Requirements
- [ ] **Batch processing**: Nest tất cả extra boards trong một lần chạy
- [ ] **Size-based sorting**: Ưu tiên board lớn trước
- [ ] **Preview only**: Preview chỉ hiển thị, không cho edit
- [ ] **Accept/Reject all**: User chỉ có thể accept hoặc reject toàn bộ
- [ ] **Statistics reporting**: Hiển thị waste %, area usage, etc.
- [ ] **Animation**: Hiển thị quá trình nesting (optional)
- [ ] **Rollback support**: Có thể undo nếu user không hài lòng

### 6.3 Validation Rules

#### 6.3.1 Board Geometry Validation
```ruby
BOARD_VALIDATION_RULES = {
  min_faces: 6,                    # Tối thiểu 6 faces
  max_faces: 20,                   # Tối đa 20 faces (có CNC)
  face_count: 4,                   # Mỗi face phải có 4 edges
  parallel_tolerance: 0.001,       # Tolerance cho parallel check
  area_tolerance: 0.01,            # 1% tolerance cho area match
  min_dimension: 10.mm,            # Kích thước tối thiểu
  max_dimension: 3000.mm           # Kích thước tối đa
}

def detailed_validation(group)
  errors = []
  
  # Check 1: Face count
  faces = group.entities.grep(Sketchup::Face)
  if faces.length < RULES[:min_faces]
    errors << "Insufficient faces (#{faces.length} < 6)"
  end
  
  # Check 2: Find largest faces
  sorted = faces.sort_by { |f| -f.area }
  face1, face2 = sorted[0], sorted[1]
  
  # Check 3: Parallel
  unless face1.normal.parallel?(face2.normal)
    angle = face1.normal.angle_between(face2.normal.reverse)
    errors << "Not parallel: angle=#{angle.radians}°"
  end
  
  # Check 4: Congruent (đồng dạng)
  area_diff_pct = (face1.area - face2.area).abs / face1.area * 100
  if area_diff_pct > RULES[:area_tolerance] * 100
    errors << "Not congruent: area diff=#{area_diff_pct.round(2)}%"
  end
  
  # Check 5: Rectangular
  unless face1.edges.length == 4 && face2.edges.length == 4
    errors << "Not rectangular: face1=#{face1.edges.length}, face2=#{face2.edges.length} edges"
  end
  
  # Check 6: Dimensions
  bounds = group.bounds
  if bounds.width < RULES[:min_dimension] ||
     bounds.height < RULES[:min_dimension] ||
     bounds.depth < RULES[:min_dimension]
    errors << "Dimension too small: #{bounds.width}×#{bounds.height}×#{bounds.depth}"
  end
  
  return errors.empty? ? nil : errors
end
```

#### 6.3.2 Error Display
```
┌──────────────────────────────────────┐
│  Validation Errors                   │
├──────────────────────────────────────┤
│ Group#127900 is not a valid board:   │
│                                      │
│ ✗ Not parallel: angle=15.3°          │
│ ✗ Not congruent: area diff=5.2%      │
│                                      │
│ [Highlight in Model]  [Dismiss]      │
└──────────────────────────────────────┘
```

---

## 7. Các trường hợp đặc biệt cần xử lý

### 7.1 Space Management
- Không đủ không gian cho tấm ván mới
- Tấm ván mới quá lớn
- Nhiều tấm ván extra cùng lúc

### 7.2 Face Orientation
- Tấm ván cần lật để fit
- Ưu tiên Front face hướng lên
- Conflict về mặt cắt

### 7.3 Data Integrity
- Sơ đồ N1 bị corrupted
- Missing attributes
- Duplicate index

---

## 8. Công nghệ và kiến trúc

### 8.1 SketchUp Ruby API Operations

**Đọc cấu trúc Nesting**:
```ruby
# Tìm Nesting Root
nesting_root = model.entities.find { |e| 
  e.is_a?(Sketchup::Group) && 
  e.get_attribute('ABF', 'is-nesting-root') 
}

# Duyệt qua các Sheet
nesting_root.entities.each do |sheet_group|
  sheet_id = sheet_group.get_attribute('ABF', 'sheet-id')
  
  # Duyệt qua các Board trong Sheet
  sheet_group.entities.each do |board_group|
    board_index = board_group.get_attribute('ABF', 'board-index')
    transform = board_group.transformation
    bounds = board_group.bounds
  end
end
```

**Xác định Front/Back Face**:
```ruby
def find_front_back_faces(board_group)
  faces = board_group.entities.grep(Sketchup::Face)
  
  # Sắp xếp theo diện tích giảm dần
  sorted = faces.sort_by { |f| -f.area }
  
  # 2 faces lớn nhất
  largest_faces = sorted.take(2)
  
  # Kiểm tra song song (normal ngược chiều)
  face1, face2 = largest_faces
  if face1.normal.parallel?(face2.normal.reverse)
    front = face1.get_attribute('ABF', 'is-labeled-face') ? face1 : face2
    back = (front == face1) ? face2 : face1
    return [front, back]
  end
end
```

**Tính toán Gap (vùng trống)**:
```ruby
def calculate_gaps(sheet_group)
  sheet_bounds = sheet_group.bounds
  occupied_regions = []
  
  sheet_group.entities.each do |board|
    board_bounds = board.bounds
    board_transform = board.transformation
    occupied_regions << transform_bounds(board_bounds, board_transform)
  end
  
  # Thuật toán tìm vùng trống
  gaps = find_empty_regions(sheet_bounds, occupied_regions)
  return gaps.sort_by { |g| -g.area }
end
```

### 8.2 Modules đề xuất

```
ABF_ExtraNesting/
│
├── Core/
│   ├── board_analyzer.rb       # Phân tích board geometry
│   ├── face_detector.rb        # Xác định front/back face
│   ├── nesting_reader.rb       # Đọc cấu trúc nesting hiện tại
│   └── gap_calculator.rb       # Tính toán vùng trống
│
├── ExtraLabel/
│   ├── label_tool.rb           # Tool gắn nhãn extra
│   ├── label_generator.rb      # Tạo label text geometry
│   └── index_manager.rb        # Quản lý board-index
│
├── ExtraNesting/
│   ├── placement_algorithm.rb  # Thuật toán sắp xếp
│   ├── transform_calculator.rb # Tính toán transform matrix
│   ├── collision_detector.rb   # Kiểm tra va chạm
│   └── sheet_selector.rb       # Chọn sheet phù hợp
│
├── Validation/
│   ├── data_validator.rb       # Validate attributes
│   ├── geometry_validator.rb   # Kiểm tra geometry hợp lệ
│   └── compatibility_checker.rb # Kiểm tra tương thích N1
│
├── UI/
│   ├── extra_label_dialog.rb   # Dialog label tool
│   ├── nesting_preview.rb      # Preview kết quả
│   └── settings_manager.rb     # Cài đặt plugin
│
└── Utils/
    ├── attribute_helper.rb     # Helper cho attributes
    ├── transform_helper.rb     # Helper cho transformations
    └── logger.rb               # Logging & debugging
```

### 8.3 Data Flow trong Extra Nesting

```
[Board mới vẽ] 
    ↓
[1. Geometry Analysis]
    - Xác định bounds: [w, h, d]
    - Detect front/back faces
    - Tìm side faces có edge-band
    ↓
[2. Extra Labeling]
    - Gán board-index tiếp theo (index=32)
    - Tạo label geometry (142 edges)
    - Mark "is-extra-board" = true
    - Lưu attributes
    ↓
[3. Nesting Analysis]
    - Load nesting root
    - Duyệt tất cả sheets
    - Tính toán occupied regions
    - Xác định gaps khả dụng
    ↓
[4. Placement Calculation]
    - Chọn gap phù hợp (by size)
    - Tính transform matrix (rotation + translation)
    - Kiểm tra collision
    - Validate fit trong bounds
    ↓
[5. Apply Transform]
    - Clone board group
    - Apply transformation
    - Add vào sheet group
    - Update sheet bounds nếu cần
    ↓
[6. Finalization]
    - Copy components (label, cutting lines, etc.)
    - Preserve all attributes
    - Mark nesting version/timestamp
    - Save model
```

---

## 9. Workflow chi tiết với Settings

### 9.1 Extra Label Workflow

```
[User vẽ board mới] 
        ↓
[Click "Extra Label" tool]
        ↓
[Tool phát hiện boards chưa label]
        ↓
┌─────────────────────────────────┐
│  Extra Label Dialog             │
│                                 │
│  Found 1 unlabeled board:       │
│  • Group#127763                 │
│                                 │
│  Next index: [31] (auto)        │
│  Board name: [3. Hông Phải]     │
│                                 │
│  Front face: [Auto-detect ▼]    │
│  ☑ Detect largest parallel faces│
│                                 │
│  [Preview] [Cancel] [Apply]     │
└─────────────────────────────────┘
        ↓
[Apply → Gắn attributes + tạo label geometry]
        ↓
[Board ready for Extra Nesting]
```

### 9.2 Extra Nesting Workflow với Settings

```
[User có boards đã label extra]
        ↓
[Click "Extra Nesting" tool]
        ↓
[Load settings từ model/file]
        ↓
┌─────────────────────────────────────┐
│  Extra Nesting Dialog               │
│                                     │
│  Extra boards found: 2              │
│  • Board 31: [17.5×364.5×621.4]     │
│  • Board 32: [17.5×400×1200]        │
│                                     │
│  Current sheets: 2 (Color A02)      │
│  Available gaps: 5                  │
│                                     │
│  [⚙️ Settings] [Preview] [Apply]    │
└─────────────────────────────────────┘
        ↓
[Click Settings → Open Settings Dialog]
        ↓
[User configure rotation, sheet creation, etc.]
        ↓
[Save settings → Apply to model]
        ↓
[Click Preview]
        ↓
┌──────────────────────────────────────────────┐
│ Preview Mode - Vẽ trực tiếp lên model        │
│                                              │
│ 1. Clone nesting root → preview layer       │
│ 2. Vẽ 2D projections lên sheets              │
│ 3. Highlight màu preview (semi-transparent)  │
│ 4. Show dimensions và statistics             │
│                                              │
│ Camera auto-zoom to fit tất cả sheets        │
│                                              │
│ User xem preview trực tiếp trên model        │
│ (Không thể edit, chỉ xem)                    │
└──────────────────────────────────────────────┘
        ↓
┌─────────────────────────────────────┐
│  Confirmation Dialog (Simple)       │
│                                     │
│  Preview created successfully!      │
│                                     │
│  Placement summary:                 │
│  • Board 31 → Sheet 1               │
│    Position: (120, 450), Rot: 90°   │
│                                     │
│  • Board 32 → Sheet 3 [NEW]         │
│    Position: (0, 0), Rot: 0°        │
│                                     │
│  [Cancel Preview] [Apply Nesting]   │
└─────────────────────────────────────┘
        ↓
    User chọn:
    ├─ [Cancel Preview]
    │   └─> Xóa preview layer, về trạng thái ban đầu
    │
    └─ [Apply Nesting]
        └─> Replace preview với actual nesting
            └─> Update model + Save attributes
                └─> Success!
```

### 9.2.1 Preview Rendering Details

**Preview được vẽ trực tiếp lên Nesting Root (world coordinates)**:

```ruby
class PreviewRenderer
  def initialize(nesting_root, placement_results)
    @nesting_root = nesting_root
    @results = placement_results
    @preview_entities = []
  end
  
  # Tạo preview trực tiếp trên model
  def render_preview
    model = Sketchup.active_model
    
    # Step 1: Tạo preview groups với màu highlight
    @results.each do |result|
      next unless result[:success]
      
      board_2d = result[:board]
      sheet = result[:sheet]
      
      # Clone board 2D vào sheet
      preview_group = clone_board_for_preview(board_2d, sheet)
      
      # Apply preview material (semi-transparent)
      apply_preview_material(preview_group)
      
      # Add to tracking
      @preview_entities << preview_group
      
      # Set preview attribute
      preview_group.set_attribute('ABF', 'is-preview', true)
    end
    
    # Step 2: Highlight new sheets
    @results.select { |r| r[:new_sheet] }.each do |result|
      highlight_new_sheet(result[:sheet])
    end
    
    # Step 3: Add dimension annotations
    add_dimension_annotations
    
    # Step 4: Zoom to fit all sheets
    zoom_to_fit_sheets
    
    return @preview_entities
  end
  
  # Xóa preview
  def clear_preview
    @preview_entities.each(&:erase!)
    @preview_entities.clear
    
    # Remove dimension annotations
    remove_annotations
    
    # Restore original view
    restore_view
  end
  
  # Apply nesting (convert preview to actual)
  def apply_nesting
    @preview_entities.each do |preview_group|
      # Remove preview flag
      preview_group.delete_attribute('ABF', 'is-preview')
      
      # Remove preview material
      preview_group.material = nil
      
      # Set as actual nested board
      preview_group.set_attribute('ABF', 'is-nested-2d', true)
      preview_group.set_attribute('ABF', 'export-for-cutting', true)
    end
    
    # Clear tracking
    @preview_entities.clear
  end
  
  private
  
  def clone_board_for_preview(board_2d, sheet)
    # Clone board 2D geometry
    preview_group = board_2d.entity.copy
    
    # Add to sheet (in nesting root)
    sheet.sketchup_entity.entities.add_instance(
      preview_group.definition,
      board_2d.entity.transformation
    )
  end
  
  def apply_preview_material(group)
    # Create semi-transparent blue material
    model = Sketchup.active_model
    
    unless model.materials['ABF_Preview']
      mat = model.materials.add('ABF_Preview')
      mat.color = Sketchup::Color.new(100, 150, 255)
      mat.alpha = 0.5  # 50% transparent
    end
    
    group.material = 'ABF_Preview'
  end
  
  def highlight_new_sheet(sheet)
    # Add temporary border highlight for new sheets
    border_group = sheet.sketchup_entity.entities.add_group
    border_group.name = "__Preview_NewSheet"
    
    # Draw thick border
    pts = [
      [0, 0, 0],
      [sheet.width, 0, 0],
      [sheet.width, sheet.height, 0],
      [0, sheet.height, 0]
    ]
    
    edges = border_group.entities.add_edges(pts + [pts.first])
    edges.each { |e| e.set_attribute('ABF', 'is-preview-highlight', true) }
    
    @preview_entities << border_group
  end
  
  def add_dimension_annotations
    # Add text annotations showing placement info
    model = Sketchup.active_model
    
    @results.each do |result|
      next unless result[:success]
      
      board_2d = result[:board]
      position = result[:position]
      rotation = result[:rotation]
      
      # Create 3D text showing board index and rotation
      text_group = create_dimension_text(
        position,
        "Board #{board_2d.source_board.board_index}\nRot: #{rotation}°"
      )
      
      @preview_entities << text_group
    end
  end
  
  def zoom_to_fit_sheets
    model = Sketchup.active_model
    view = model.active_view
    
    # Calculate bounding box of all sheets
    all_bounds = @nesting_root.sheets.map { |s| 
      s.sketchup_entity.bounds 
    }
    
    combined_bounds = all_bounds.reduce { |acc, b| 
      acc.add(b.min)
      acc.add(b.max)
      acc
    }
    
    # Zoom to fit
    view.zoom(combined_bounds)
  end
end
```

### 9.2.2 Preview Workflow Implementation

```ruby
class ExtraNestingTool
  def initialize
    @preview_renderer = nil
  end
  
  def on_preview_button_clicked
    # Run nesting calculation
    results = run_nesting_calculation
    
    # Create preview renderer
    @preview_renderer = PreviewRenderer.new(@nesting_root, results)
    
    # Render preview on model
    @preview_renderer.render_preview
    
    # Show confirmation dialog
    show_confirmation_dialog(results)
  end
  
  def show_confirmation_dialog(results)
    # Simple HTML dialog with summary
    dialog = UI::HtmlDialog.new(
      dialog_title: "Nesting Preview - Confirm",
      width: 400,
      height: 300
    )
    
    # Generate summary HTML
    summary_html = generate_summary_html(results)
    dialog.set_html(summary_html)
    
    # Callbacks
    dialog.add_action_callback('cancel_preview') do
      @preview_renderer.clear_preview
      dialog.close
    end
    
    dialog.add_action_callback('apply_nesting') do
      @preview_renderer.apply_nesting
      finalize_nesting(results)
      dialog.close
      
      UI.messagebox("Nesting applied successfully!")
    end
    
    dialog.show
  end
  
  private
  
  def generate_summary_html(results)
    success_count = results.count { |r| r[:success] }
    new_sheets = results.count { |r| r[:new_sheet] }
    
    boards_html = results.map do |r|
      next unless r[:success]
      
      board_index = r[:board].source_board.board_index
      sheet_id = r[:sheet].sheet_id
      position = r[:position]
      rotation = r[:rotation]
      new_marker = r[:new_sheet] ? ' [NEW]' : ''
      
      <<-HTML
        <li>
          Board #{board_index} → Sheet #{sheet_id}#{new_marker}
          <br>
          <small>Position: (#{position.x.round(1)}, #{position.y.round(1)}), 
                 Rotation: #{rotation}°</small>
        </li>
      HTML
    end.compact.join
    
    <<-HTML
    <!DOCTYPE html>
    <html>
    <head>
      <style>
        body { font-family: Arial; padding: 20px; }
        .summary { background: #f0f0f0; padding: 10px; margin: 10px 0; }
        ul { list-style: none; padding: 0; }
        li { margin: 10px 0; padding: 10px; background: white; border-left: 3px solid #4CAF50; }
        .buttons { margin-top: 20px; text-align: center; }
        button { padding: 10px 20px; margin: 0 5px; font-size: 14px; cursor: pointer; }
        .cancel { background: #f44336; color: white; }
        .apply { background: #4CAF50; color: white; }
      </style>
    </head>
    <body>
      <h2>Nesting Preview</h2>
      <div class="summary">
        <p><strong>Successfully placed:</strong> #{success_count} boards</p>
        <p><strong>New sheets created:</strong> #{new_sheets}</p>
      </div>
      
      <h3>Placement Details:</h3>
      <ul>
        #{boards_html}
      </ul>
      
      <div class="buttons">
        <button class="cancel" onclick="cancel_preview()">Cancel Preview</button>
        <button class="apply" onclick="apply_nesting()">Apply Nesting</button>
      </div>
      
      <script>
        function cancel_preview() {
          sketchup.cancel_preview();
        }
        function apply_nesting() {
          sketchup.apply_nesting();
        }
      </script>
    </body>
    </html>
    HTML
  end
end
```

### 9.3 Settings Dialog Interaction Flow

```
[Click ⚙️ Settings button]
        ↓
┌─────────────────────────────────────────┐
│ Load current settings (priority order): │
│ 1. Model-specific settings              │
│ 2. Global settings file                 │
│ 3. Default settings                     │
└─────────────────────────────────────────┘
        ↓
[Display Settings Dialog]
        ↓
[User modifies settings]
        ↓
[On OK button click]
        ↓
┌─────────────────────────────────────────┐
│ Save settings:                          │
│ • To model attributes (priority)        │
│ • To global file (fallback)             │
└─────────────────────────────────────────┘
        ↓
[Validate settings]
        ↓
[Apply to current nesting operation]
```

### 9.4 Auto-Create Sheet Workflow

```
[Board không fit vào sheets hiện có]
        ↓
[Check settings: auto_create_sheet?]
        ↓
     YES │ NO
         │  └→ [Show error message]
         │     [Suggest: enable auto-create or adjust board]
         ↓
[Check: max_sheets_per_type limit]
        ↓
   Not exceeded │ Exceeded
                │  └→ [Show limit exceeded message]
                │     [Options: increase limit or remove boards]
                ↓
[Create new sheet]
        ↓
┌─────────────────────────────────────┐
│ new_sheet = Sheet.create(           │
│   type: board.sheet_type,           │
│   id: next_available_id,            │
│   dimension: [1220, 2440],          │
│   thickness: board.thickness,       │
│   position: calculate_position()    │
│ )                                   │
└─────────────────────────────────────┘
        ↓
[Add to nesting root]
        ↓
[Place board at origin (0,0) of new sheet]
        ↓
[Create sheet border + setup attributes]
        ↓
[Log: "Created #{sheet_type}-sheet-#{id}"]
        ↓
[Continue with remaining boards]
```

### 9.5 Complete Flow Diagram

```
┌─────────────────┐
│  User Action    │
└────────┬────────┘
         │
    ┌────┴────┐
    │ Draw    │  Vẽ board mới
    │ Board   │  trong model
    └────┬────┘
         │
    ┌────▼────────┐
    │ Extra Label │
    │    Tool     │  • Auto-detect geometry
    └────┬────────┘  • Assign index
         │           • Mark front/back face
         │           • Create label
    ┌────▼──────────┐
    │ Board ready   │
    │ for nesting   │
    └────┬──────────┘
         │
    ┌────▼──────────┐
    │ Extra Nesting │  • Load settings
    │     Tool      │  • Analyze gaps
    └────┬──────────┘  • Calculate placement
         │
         ├─────────────────┐
         │                 │
    ┌────▼────┐      ┌────▼────────┐
    │Settings │      │  Preview    │
    │ Dialog  │      │   Result    │
    └────┬────┘      └────┬────────┘
         │                │
         └────────┬───────┘
                  │
            ┌─────▼──────┐
            │ Fits in    │
            │ existing?  │
            └─────┬──────┘
                  │
         ┌────────┴────────┐
         │                 │
       YES               NO
         │                 │
    ┌────▼────┐      ┌────▼──────────┐
    │ Place   │      │ Auto-create   │
    │ in gap  │      │  new sheet?   │
    └────┬────┘      └────┬──────────┘
         │                │
         │           ┌────┴────┐
         │         YES        NO
         │           │          │
         │      ┌────▼────┐  ┌──▼───┐
         │      │ Create  │  │Error │
         │      │  Sheet  │  │Dialog│
         │      └────┬────┘  └──────┘
         │           │
         └───────────┴─────────┐
                               │
                      ┌────────▼────────┐
                      │ Apply Transform │
                      │   + Attributes  │
                      └────────┬────────┘
                               │
                      ┌────────▼────────┐
                      │ Update Model    │
                      │  Save & Log     │
                      └────────┬────────┘
                               │
                      ┌────────▼────────┐
                      │ Show Success    │
                      │   Statistics    │
                      └─────────────────┘
```

---

## 10. Settings & Configuration System

### 10.1 Extra Nesting Settings Dialog

**Settings cần có**:
```ruby
EXTRA_NESTING_SETTINGS = {
  # Rotation Options
  allow_rotation: true,              # Cho phép xoay 90°
  rotation_angles: [0, 90, 180, 270], # Các góc được phép
  prefer_original_rotation: true,     # Ưu tiên giữ nguyên rotation
  
  # Sheet Management
  auto_create_sheet: true,           # Tự động tạo sheet mới
  max_sheets_per_type: 10,           # Giới hạn số sheet PER CLASSIFICATION
  sheet_naming_pattern: "%{material}-%{thickness}mm-sheet-%{id}",
  
  # Classification (CRITICAL)
  group_by_material: true,           # Bắt buộc - group theo material
  group_by_thickness: true,          # Bắt buộc - group theo thickness
  material_tolerance: 0.0,           # Tolerance cho material match (0 = exact)
  thickness_tolerance: 0.5,          # Tolerance cho thickness (mm)
  
  # Placement Strategy
  placement_strategy: "best_fit",    # best_fit | first_fit | bottom_left
  gap_priority: "largest_first",     # largest_first | closest_to_origin
  min_gap_margin: 5.0,               # mm - khoảng cách tối thiểu
  
  # Optimization
  optimize_material_usage: true,     # Tối ưu sử dụng vật liệu
  minimize_waste: true,              # Giảm thiểu phế liệu
  keep_same_orientation: false,      # Giữ cùng hướng với boards lân cận
  
  # Validation
  check_collision: true,             # Kiểm tra va chạm
  validate_bounds: true,             # Validate trong bounds
  allow_partial_overlap: false,      # Cho phép chồng lấn một phần
  validate_classification: true,     # Validate material/thickness match
  
  # Preview & Feedback
  show_preview: true,                # Hiển thị preview trước khi apply
  highlight_gaps: true,              # Highlight vùng trống
  show_placement_info: true,         # Hiển thị thông tin vị trí
  group_preview_by_classification: true  # Group preview theo material/thickness
}
```

### 10.2 UI Layout - Settings Dialog

```
┌─────────────────────────────────────────────────┐
│  Extra Nesting Settings                    [X]  │
├─────────────────────────────────────────────────┤
│                                                 │
│ ┌─ Classification (CRITICAL) ───────────────┐  │
│ │ ☑ Group by Material (required)            │  │
│ │ ☑ Group by Thickness (required)           │  │
│ │ Material tolerance: [Exact match] ▼        │  │
│ │ Thickness tolerance: [0.5] mm              │  │
│ │                                            │  │
│ │ ℹ️ Boards will only nest with same         │  │
│ │    material and thickness                  │  │
│ └────────────────────────────────────────────┘  │
│                                                 │
│ ┌─ Rotation Options ─────────────────────────┐ │
│ │ ☑ Allow 90° rotation                       │ │
│ │ ☑ Prefer original rotation                 │ │
│ │ Allowed angles: [0°] [90°] [180°] [270°]  │ │
│ └───────────────────────────────────────────── │
│                                                 │
│ ┌─ Sheet Management ────────────────────────┐  │
│ │ ☑ Auto-create new sheet when full         │ │
│ │ Max sheets per classification: [10   ] ▼   │ │
│ │ Naming: [%{material}-%{thickness}mm-...]   │ │
│ └───────────────────────────────────────────── │
│                                                 │
│ ┌─ Placement Strategy ──────────────────────┐  │
│ │ Strategy:  ⦿ Best Fit  ○ First Fit         │ │
│ │            ○ Bottom Left                   │ │
│ │ Gap priority: ⦿ Largest first              │ │
│ │               ○ Closest to origin          │ │
│ │ Min gap margin: [5.0    ] mm               │ │
│ └───────────────────────────────────────────── │
│                                                 │
│        [Load Defaults]  [Cancel]  [OK]         │
└─────────────────────────────────────────────────┘
```

### 10.2 UI Layout - Settings Dialog

```
┌─────────────────────────────────────────────────┐
│  Extra Nesting Settings                    [X]  │
├─────────────────────────────────────────────────┤
│                                                 │
│ ┌─ Rotation Options ─────────────────────────┐ │
│ │ ☑ Allow 90° rotation                       │ │
│ │ ☑ Prefer original rotation                 │ │
│ │ Allowed angles: [0°] [90°] [180°] [270°]  │ │
│ └───────────────────────────────────────────── │
│                                                 │
│ ┌─ Sheet Management ────────────────────────┐  │
│ │ ☑ Auto-create new sheet when full         │ │
│ │ Max sheets per type: [10        ] ▼        │ │
│ │ Sheet naming: [%{type}-sheet-%{id}]        │ │
│ └───────────────────────────────────────────── │
│                                                 │
│ ┌─ Placement Strategy ──────────────────────┐  │
│ │ Strategy:  ⦿ Best Fit  ○ First Fit         │ │
│ │            ○ Bottom Left                   │ │
│ │ Gap priority: ⦿ Largest first              │ │
│ │               ○ Closest to origin          │ │
│ │ Min gap margin: [5.0    ] mm               │ │
│ └───────────────────────────────────────────── │
│                                                 │
│ ┌─ Optimization ────────────────────────────┐  │
│ │ ☑ Optimize material usage                  │ │
│ │ ☑ Minimize waste                           │ │
│ │ ☐ Keep same orientation as neighbors      │ │
│ └───────────────────────────────────────────── │
│                                                 │
│ ┌─ Preview & Validation ────────────────────┐  │
│ │ ☑ Show preview before apply                │ │
│ │ ☑ Highlight available gaps                 │ │
│ │ ☑ Show placement information               │ │
│ │ ☑ Check collision                          │ │
│ └───────────────────────────────────────────── │
│                                                 │
│        [Load Defaults]  [Cancel]  [OK]         │
└─────────────────────────────────────────────────┘
```

### 10.3 Settings Persistence

**Lưu settings**:
```ruby
class ExtraNestingSettingsManager
  SETTINGS_FILE = 'extra_nesting_settings.json'
  
  def save_settings(settings)
    path = File.join(plugin_dir, SETTINGS_FILE)
    File.write(path, JSON.pretty_generate(settings))
    
    # Backup to model attributes
    model = Sketchup.active_model
    model.set_attribute('ABF_ExtraNesting', 'settings', settings.to_json)
  end
  
  def load_settings
    # Priority 1: Model-specific settings
    model = Sketchup.active_model
    if model_settings = model.get_attribute('ABF_ExtraNesting', 'settings')
      return JSON.parse(model_settings)
    end
    
    # Priority 2: Global settings file
    path = File.join(plugin_dir, SETTINGS_FILE)
    if File.exist?(path)
      return JSON.parse(File.read(path))
    end
    
    # Priority 3: Default settings
    return default_settings
  end
end
```

### 10.4 Auto-Create Sheet Logic

**Khi không fit vào sheets hiện có**:
```ruby
def handle_no_fit(board, nesting_root, settings)
  if settings[:auto_create_sheet]
    # Lấy thông tin loại sheet
    sheet_type = board.get_attribute('ABF', 'sheet-type') || 'Color A02'
    sheet_thickness = board.get_attribute('ABF', 'sheet-thickness') || 17.5
    
    # Tìm sheet ID mới
    existing_sheets = find_sheets_by_type(nesting_root, sheet_type)
    new_sheet_id = existing_sheets.map { |s| s.get_attribute('ABF', 'sheet-id') }.max + 1
    
    # Kiểm tra giới hạn
    if existing_sheets.length >= settings[:max_sheets_per_type]
      UI.messagebox("Exceeded max sheets limit (#{settings[:max_sheets_per_type]})")
      return nil
    end
    
    # Tạo sheet mới
    new_sheet = create_new_sheet(
      nesting_root,
      sheet_type: sheet_type,
      sheet_id: new_sheet_id,
      dimension: [1220, 2440],
      thickness: sheet_thickness
    )
    
    # Place board vào sheet mới
    place_board(board, new_sheet, position: [0, 0, 0])
    
    UI.messagebox("Created new sheet: #{sheet_type}-sheet-#{new_sheet_id}")
    return new_sheet
  else
    UI.messagebox("Board doesn't fit in existing sheets. Enable auto-create sheet.")
    return nil
  end
end
```

### 10.5 Rotation Strategy

**Thuật toán thử rotation**:
```ruby
def find_best_placement_with_rotation(board, gaps, settings)
  board_bounds = board.bounds
  best_placement = nil
  best_score = Float::INFINITY
  
  # Danh sách các góc cần thử
  angles = settings[:allow_rotation] ? settings[:rotation_angles] : [0]
  
  # Ưu tiên rotation gốc
  if settings[:prefer_original_rotation]
    original_rotation = board.get_attribute('ABF', 'label-rotation') || 0
    angles = [original_rotation] + (angles - [original_rotation])
  end
  
  angles.each do |angle|
    rotated_bounds = calculate_rotated_bounds(board_bounds, angle)
    
    gaps.each do |gap|
      if fits_in_gap?(rotated_bounds, gap, settings[:min_gap_margin])
        score = calculate_placement_score(
          gap, 
          rotated_bounds, 
          angle, 
          settings
        )
        
        if score < best_score
          best_score = score
          best_placement = {
            gap: gap,
            angle: angle,
            position: calculate_position(gap, rotated_bounds),
            score: score
          }
        end
      end
    end
  end
  
  return best_placement
end

def calculate_placement_score(gap, bounds, angle, settings)
  score = 0
  
  # Penalty cho rotation khác gốc
  if angle != 0 && settings[:prefer_original_rotation]
    score += 100
  end
  
  # Reward cho gap vừa khít
  waste = gap.area - bounds.area
  score += waste * 0.1
  
  # Reward cho vị trí gần origin
  if settings[:gap_priority] == "closest_to_origin"
    distance = Math.sqrt(gap.center.x**2 + gap.center.y**2)
    score += distance * 0.01
  end
  
  return score
end
```