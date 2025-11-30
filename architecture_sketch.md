# Extra Nesting - Architecture Sketch

## Module Structure

```ruby
GG_Cabinet
└── ExtraNesting
    ├── VERSION = '0.1.0-dev'
    ├── DEV_MODE = true
    └── DEV_SETTINGS = {...}
```

---

## 1. Core Models (Domain Layer)

### 1.1 PersistentEntity (Base Class)
```ruby
class PersistentEntity
  attr_reader :id, :entity_id, :attributes
  
  def initialize(sketchup_entity)
  def load_attributes              # Load từ SketchUp
  def save_attributes              # Save vào SketchUp
  def sync_to_db                   # Sync to Database
  def to_hash                      # Serialize
end
```

### 1.2 Board
```ruby
class Board < PersistentEntity
  attr_reader :faces, :edge_bandings, :label
  
  # Detection
  def material                     # {name, display_name, color}
  def material_name                # "Color_A02"
  def thickness                    # 17.5 (mm)
  def classification_key           # "Color_A02_17.5"
  
  # Validation
  def valid?                       # Boolean
  def validation_errors            # Array<String>
  
  # Relationships
  def front_face                   # Face
  def back_face                    # Face
  def side_faces                   # Array<Face>
  
  # Nesting status
  def nested?                      # Boolean
  def nested_in_sheet              # Sheet ID
  def projection_2d_id             # Entity ID
  def projection_2d                # TwoDGroup
  
  # Dev helpers
  def highlight_in_model
  def print_debug_info
end
```

### 1.3 Face
```ruby
class Face < PersistentEntity
  attr_reader :board
  
  # Type detection
  def front_face?                  # Boolean
  def back_face?                   # Boolean
  def side_face?                   # Boolean
  
  # Properties
  def has_edge_banding?            # Boolean
  def area                         # Float (mm²)
  def normal                       # Vector3d
  
  # Geometry
  def parallel_to?(other_face)     # Boolean
  def congruent_to?(other_face)    # Boolean
  def project_to_2d                # Array<Point3d>
  
  # Relations
  def has_intersections?           # Boolean
  def sketchup_entity              # Sketchup::Face
end
```

### 1.4 TwoDGroup
```ruby
class TwoDGroup < PersistentEntity
  attr_reader :source_board, :label, :faces_2d, :boundary_edges
  attr_accessor :nesting_position, :nesting_rotation
  
  # Creation
  def create_projection            # Self
  def create_projection_in_playground(playground_root)
  
  # Geometry
  def bounds_2d                    # {min, max, width, height}
  
  # Transform
  def apply_nesting_transform(sheet, position, rotation, arrow_to_origin: true)
  def move_to_sheet(sheet)
end
```

### 1.5 Sheet
```ruby
class Sheet < PersistentEntity
  attr_reader :nesting_root, :boards_2d
  attr_accessor :sheet_id, :material, :thickness
  
  # Classification
  def classification_key           # "Color_A02_17.5"
  
  # Type
  def top_sheet?                   # Boolean
  def bottom_sheet?                # Boolean
  
  # Dimensions
  def dimension                    # [1220, 2440]
  def width                        # 1220
  def height                       # 2440
  
  # Analysis
  def calculate_gaps(margin: 5.0)  # Array<Gap>
  def utilization                  # Float (%)
  def has_space_for?(board_2d)     # Boolean
  def full?                        # Boolean
  
  # Operations
  def add_board(board_2d)
  def transform                    # Transformation
  def sketchup_entity              # Group
end
```

### 1.6 NestingRoot
```ruby
class NestingRoot < PersistentEntity
  attr_reader :sheets
  attr_accessor :tool_diameter, :clearance, :border_gap
  
  # Factory
  def self.find_in_model(model)   # NestingRoot | nil
  
  # Settings
  def tool_diameter                # Float (mm)
  def clearance                    # Float (mm)
  def border_gap                   # Float (mm)
  
  # Query
  def sheets_by_classification     # Hash{class_key => Array<Sheet>}
  def find_sheets_by_classification(class_key)
  def total_boards                 # Integer
  def classifications              # Array<String>
end
```

### 1.7 Label
```ruby
class Label < PersistentEntity
  attr_reader :parent, :rotation
  
  def rotation                     # 0-360
  def clone_to_2d(group_2d)        # Label
end
```

### 1.8 EdgeBanding
```ruby
class EdgeBanding < PersistentEntity
  attr_reader :face
  
  def band_type                    # String
end
```

### 1.9 Intersection
```ruby
class Intersection < PersistentEntity
  attr_reader :face
  
  def on_back_face?                # Boolean
  def on_top_face?                 # Boolean
  def on_side_face?                # Boolean
  def cnced?                       # Boolean
  def marker?                      # Boolean
end
```

---

## 2. Services (Business Logic)

### 2.1 PlaygroundCreator
```ruby
class PlaygroundCreator
  def self.create_or_find_playground(model)
  
  private
  def self.find_n1_nesting_root(model)
  def self.find_n2_playground(model)
  def self.clone_n1_to_playground(n1_root, model)
end
```

### 2.2 BoardScanner
```ruby
class BoardScanner
  def scan_model(model)            # Array<Board>
  def scan_playground              # Array<Board> (N2 only)
  def scan_unlabeled               # Array<Board>
end
```

### 2.3 BoardValidator
```ruby
class BoardValidator
  def self.validate(board)         # Boolean
  def self.validate_batch(boards)  # {valid: [], invalid: []}
  
  private
  def self.check_parallel_faces
  def self.check_congruent_faces
  def self.check_rectangular_faces
end
```

### 2.4 TwoDProjector
```ruby
class TwoDProjector
  def self.project_board(board)                    # TwoDGroup
  def self.batch_project(boards)                   # Array<TwoDGroup>
  def self.project_board_in_playground(board, n2)  # TwoDGroup (Dev)
end
```

### 2.5 GapCalculator
```ruby
class GapCalculator
  def initialize(sheet, occupied_regions, margin)
  
  def find_gaps                    # Array<Gap>
  
  private
  def collect_occupied_regions
  def find_horizontal_gaps_at_height(y1, y2, occupied)
  def merge_intervals
  def merge_gaps
end

class Gap
  attr_reader :x, :y, :width, :height
  
  def area                         # Float
  def center                       # Point3d
  def can_fit?(board_bounds)       # Boolean
end
```

### 2.6 NestingEngine
```ruby
class NestingEngine
  def initialize(settings)
  
  # Main API
  def nest_boards(boards, nesting_root)
  def nest_boards_in_playground(boards, n2_playground)  # Dev
  
  private
  def nest_classification_group(class_key, boards, root)
  def find_best_placement_2d(board_2d, sheets, settings)
  def calculate_placement_score(gap, board, rotation)
end

# Strategies
class BestFitStrategy
  def find_placement(board, gaps)
end

class FirstFitStrategy
  def find_placement(board, gaps)
end

class BottomLeftStrategy
  def find_placement(board, gaps)
end
```

### 2.7 SheetManager
```ruby
class SheetManager
  def self.find_or_create_sheet(root, class_key)
  def self.create_classified_sheet(root, material, thickness, sheet_id)
  def self.auto_create_sheet_if_needed(board, root, settings)
end
```

### 2.8 PreviewRenderer
```ruby
class PreviewRenderer
  def initialize(nesting_root, placement_results)
  
  # Preview on model
  def render_preview               # Array<Entity> (preview entities)
  def clear_preview
  def apply_nesting                # Convert preview to actual
  
  private
  def clone_board_for_preview(board_2d, sheet)
  def apply_preview_material(group)
  def highlight_new_sheet(sheet)
  def add_dimension_annotations
  def zoom_to_fit_sheets
end
```

### 2.9 N1Integrator (Phase 5+)
```ruby
class N1Integrator
  def initialize(n1_root, n2_playground)
  
  def integrate_results(nesting_results)
  
  private
  def copy_board_from_n2_to_n1(board_2d, n2_sheet)
  def find_matching_n1_sheet(n2_sheet)
  def calculate_n1_transform(n2_transform)  # Remove X-20000mm offset
end
```

### 2.10 ExportService
```ruby
class ExportService
  def export_cutting_file(nesting_root, sheet_id = nil)
  def export_to_json(nesting_root)
  
  private
  def extract_cutting_paths_2d(board_2d)
  def extract_drills_from_3d(board_3d)
  def extract_edge_bands_from_3d(board_3d)
end
```

---

## 3. Helpers

### 3.1 GeometryHelpers
```ruby
module GeometryHelpers
  def self.project_point_to_xy(point)
  def self.calculate_2d_bounds(points)
  def self.weld_edges(edges)
  def self.calculate_rotation_to_origin(label_rot, target_y, origin_y)
end
```

### 3.2 MaterialHelpers
```ruby
module MaterialHelpers
  def self.detect_material(entity)
  def self.normalize_material_name(raw_name)
  def self.material_match?(mat1, mat2, tolerance)
end
```

### 3.3 ValidationHelpers
```ruby
module ValidationHelpers
  def self.validate_board_geometry(board)
  def self.validate_parallel_faces(face1, face2)
  def self.validate_congruent_faces(face1, face2, tolerance)
end
```

---

## 4. UI Layer

### 4.1 ExtraLabelDialog
```ruby
class ExtraLabelDialog
  def initialize
  def show
  
  private
  def scan_unlabeled_boards
  def display_validation_results(valid, invalid)
  def on_label_button_clicked
end
```

### 4.2 ExtraNestingTool
```ruby
class ExtraNestingTool
  def initialize
  
  # API
  def run_in_playground_mode       # Dev mode (Phase 1-4)
  def run_in_production_mode       # Production (Phase 8+)
  
  # UI
  def show_main_dialog
  def on_preview_button_clicked
  def show_confirmation_dialog(results)
  
  private
  def run_nesting_calculation
end
```

### 4.3 SettingsManager
```ruby
class SettingsManager
  def self.load_settings
  def self.save_settings(settings)
  def self.show_settings_dialog
  
  def self.default_settings
  def self.validate_settings(settings)
end
```

---

## 5. Database Layer

### 5.1 Database
```ruby
class Database
  include Singleton
  
  def save(table, id, data)
  def find(table, id)
  def find_by(table, conditions)
  def where(table, conditions)
  
  def export_to_json
  def import_from_json(json_string)
  
  private
  def transaction(&block)
end
```

---

## 6. Development Tools (Phase 1-7 only)

### 6.1 DevTools
```ruby
module DevTools
  def self.focus_n1                # Camera → N1
  def self.focus_n2                # Camera → N2
  def self.reset_playground        # Delete N2, recreate
  def self.compare_roots           # Show N1 vs N2 diff
  def self.print_board_info(board)
  def self.highlight_gaps(sheet)
end
```

---

## Data Flow (Simplified)

```
User Action (Label Extra Boards)
        ↓
BoardScanner.scan_unlabeled
        ↓
BoardValidator.validate_batch
        ↓
Board.save_attributes (label data)
        ↓
Done
```

```
User Action (Nest Extra Boards)
        ↓
[DEV MODE]
PlaygroundCreator.create_or_find_playground
        ↓
TwoDProjector.project_board_in_playground
        ↓
NestingEngine.nest_boards_in_playground
        ↓
PreviewRenderer.render_preview (in N2)
        ↓
User confirms
        ↓
N1Integrator.integrate_results (N2 → N1)
        ↓
Done
```

```
User Action (Nest Extra Boards) - PRODUCTION
        ↓
TwoDProjector.batch_project
        ↓
NestingEngine.nest_boards (directly in N1)
        ↓
PreviewRenderer.render_preview (in N1)
        ↓
User confirms
        ↓
PreviewRenderer.apply_nesting
        ↓
Done
```

---

## File Structure

```
lib/
├── models/
│   ├── persistent_entity.rb      # Base class
│   ├── board.rb                  # ~150 lines
│   ├── face.rb                   # ~100 lines
│   ├── two_d_group.rb            # ~120 lines
│   ├── sheet.rb                  # ~80 lines
│   ├── nesting_root.rb           # ~70 lines
│   ├── label.rb                  # ~40 lines
│   ├── edge_banding.rb           # ~30 lines
│   └── intersection.rb           # ~40 lines
│
├── services/
│   ├── playground_creator.rb     # ~100 lines (Dev)
│   ├── board_scanner.rb          # ~60 lines
│   ├── board_validator.rb        # ~80 lines
│   ├── two_d_projector.rb        # ~100 lines
│   ├── gap_calculator.rb         # ~150 lines
│   ├── nesting_engine.rb         # ~200 lines
│   ├── sheet_manager.rb          # ~80 lines
│   ├── preview_renderer.rb       # ~150 lines
│   ├── n1_integrator.rb          # ~100 lines (Phase 5+)
│   └── export_service.rb         # ~120 lines
│
├── helpers/
│   ├── geometry_helpers.rb       # ~80 lines
│   ├── material_helpers.rb       # ~50 lines
│   └── validation_helpers.rb     # ~60 lines
│
├── ui/
│   ├── extra_label_dialog.rb     # ~150 lines
│   ├── extra_nesting_tool.rb     # ~200 lines
│   ├── settings_manager.rb       # ~100 lines
│   └── html/
│       ├── label_dialog.html
│       ├── confirmation_dialog.html
│       └── settings_dialog.html
│
├── database.rb                   # ~150 lines
└── dev_tools.rb                  # ~100 lines (Dev only)
```

**Total estimated: ~2,500 lines of Ruby code**

---

## Key Design Principles

1. **Persistence**: All entities auto-sync với SketchUp attributes
2. **Separation**: Models ≠ Services ≠ UI
3. **Testability**: Services can be tested without SketchUp
4. **Safe Development**: N2 Playground protects N1
5. **Progressive**: Start simple (N2), integrate later (N1)

---

## Quick Reference

### Create N2 Playground
```ruby
n2 = PlaygroundCreator.create_or_find_playground(model)
```

### Scan & Validate Boards
```ruby
boards = BoardScanner.new.scan_playground
results = BoardValidator.validate_batch(boards)
```

### Nest in Playground
```ruby
engine = NestingEngine.new(settings)
results = engine.nest_boards_in_playground(boards, n2)
```

### Preview & Apply
```ruby
preview = PreviewRenderer.new(n2, results)
preview.render_preview
# User confirms
preview.apply_nesting
```

### Integrate to N1 (Phase 5+)
```ruby
integrator = N1Integrator.new(n1, n2)
integrator.integrate_results(results)
```
