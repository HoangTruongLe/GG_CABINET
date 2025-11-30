# Extra Nesting Plugin - Development Phase Plan

## Overview
Development được chia thành 3 giai đoạn chính:
- **Phase 1-4**: Development Mode (N2 Playground - isolated)
- **Phase 5-7**: Integration Mode (N2 → N1)
- **Phase 8-10**: Production Ready

---

## 🎮 Development Mode: N2 Playground (Week 1-6)

### Phase 1: Foundation & N2 Playground Setup (Week 1-2)

**Goal**: Setup architecture và tạo isolated playground để develop safely

**Tasks**:

#### 1.1 Module Structure
```ruby
module GG_Cabinet
  module ExtraNesting
    VERSION = '0.1.0-dev'
    DEV_MODE = true  # Toggle development mode
    
    # Development settings
    DEV_SETTINGS = {
      use_playground: true,
      playground_offset_x: 20000.mm,
      clone_n1_root: true,
      debug_logging: true
    }
  end
end
```

#### 1.2 N2 Playground Creator
```ruby
# lib/services/playground_creator.rb
class PlaygroundCreator
  def self.create_or_find_playground(model)
    # Find N1 nesting root
    n1_root = find_n1_nesting_root(model)
    
    unless n1_root
      UI.messagebox("N1 Nesting Root not found!")
      return nil
    end
    
    # Check if N2 playground already exists
    n2_root = find_n2_playground(model)
    
    if n2_root
      puts "N2 Playground found, reusing..."
      return n2_root
    end
    
    # Clone N1 root to create N2 playground
    puts "Creating N2 Playground (offset: 20000mm)..."
    n2_root = clone_n1_to_playground(n1_root, model)
    
    return n2_root
  end
  
  private
  
  def self.find_n1_nesting_root(model)
    model.entities.find { |e|
      e.is_a?(Sketchup::Group) &&
      e.get_attribute('ABF', 'is-nesting-root') &&
      !e.get_attribute('ABF', 'is-playground')
    }
  end
  
  def self.find_n2_playground(model)
    model.entities.find { |e|
      e.is_a?(Sketchup::Group) &&
      e.get_attribute('ABF', 'is-nesting-root') &&
      e.get_attribute('ABF', 'is-playground')
    }
  end
  
  def self.clone_n1_to_playground(n1_root, model)
    # Clone the entire N1 root
    n2_root = n1_root.copy
    
    # Mark as playground
    n2_root.set_attribute('ABF', 'is-playground', true)
    n2_root.set_attribute('ABF', 'playground-source', n1_root.entityID)
    n2_root.set_attribute('ABF', 'created-at', Time.now.to_s)
    n2_root.name = "__N2_Playground_ExtraNesting"
    
    # Offset 20000mm to the right
    offset = Geom::Transformation.translation([20000.mm, 0, 0])
    n2_root.transform!(offset)
    
    # Add to model
    model.entities.add_instance(n2_root.definition, n2_root.transformation)
    
    puts "✓ N2 Playground created at X+20000mm"
    
    return n2_root
  end
end
```

#### 1.3 Base Classes
- [ ] `PersistentEntity` base class
- [ ] `Database` singleton (simple JSON storage)
- [ ] Basic error classes

#### 1.4 Development Tools
```ruby
# lib/dev_tools.rb
module DevTools
  # Quick switch between N1 and N2
  def self.focus_n1
    # Camera zoom to N1 root
  end
  
  def self.focus_n2
    # Camera zoom to N2 playground
  end
  
  # Clear N2 and recreate
  def self.reset_playground
    # Delete N2, clone fresh from N1
  end
  
  # Compare N1 vs N2
  def self.compare_roots
    # Show differences
  end
end
```

**Deliverables**:
- ✅ N2 Playground auto-created at X+20000mm
- ✅ Module structure working
- ✅ Dev tools for quick navigation
- ✅ Can work on N2 without touching N1

**Testing**:
```ruby
# Manual test
model = Sketchup.active_model
n2 = PlaygroundCreator.create_or_find_playground(model)
puts "N2 Playground: #{n2.name}"
```

---

### Phase 2: Board Detection & Classification (Week 2-3)

**Goal**: Scan và classify boards - test trong N2 playground

**Tasks**:

#### 2.1 Board Model
```ruby
# lib/models/board.rb
class Board < PersistentEntity
  def initialize(sketchup_group)
    super(sketchup_group)
    @dev_mode = ExtraNesting::DEV_MODE
  end
  
  # Development helpers
  def highlight_in_model
    # Highlight this board (for debugging)
  end
  
  def print_debug_info
    puts "=" * 50
    puts "Board: #{@entity.name}"
    puts "Material: #{material_name}"
    puts "Thickness: #{thickness}mm"
    puts "Classification: #{classification_key}"
    puts "Valid: #{valid?}"
    puts "Errors: #{validation_errors.join(', ')}" unless valid?
    puts "=" * 50
  end
end
```

#### 2.2 BoardScanner Service
```ruby
# Test in N2 playground only
scanner = BoardScanner.new
boards = scanner.scan_playground  # Only scan N2 area
boards.each(&:print_debug_info)
```

#### 2.3 Material & Thickness Detection
- [ ] Material detection (face → group → layer)
- [ ] Thickness detection with snapping
- [ ] Classification key generation

#### 2.4 Validation System
- [ ] Parallel faces check
- [ ] Congruent check
- [ ] Rectangular check

**Deliverables**:
- ✅ Can scan boards in N2 playground
- ✅ Material/thickness detection working
- ✅ Classification working
- ✅ Validation with clear error messages

**Testing**:
```ruby
# Add test board to N2 playground
test_board = create_test_board(material: 'Color_A02', thickness: 17.5)
board = Board.new(test_board)
board.print_debug_info
# Expected: Valid board with correct classification
```

---

### Phase 3: 2D Projection in N2 (Week 3-4)

**Goal**: Convert 3D boards to 2D projections - render in N2 playground

**Tasks**:

#### 3.1 TwoDGroup Model
```ruby
class TwoDGroup < PersistentEntity
  def create_projection_in_playground(playground_root)
    # Create 2D projection
    # Add to playground sheets (not N1 sheets)
  end
end
```

#### 3.2 Projection Logic
- [ ] Front face → 2D face
- [ ] Back face → 2D face (if intersections)
- [ ] Boundary edges (welded)
- [ ] Label cloning with rotation

#### 3.3 GeometryHelpers
- [ ] `project_point_to_xy`
- [ ] `calculate_2d_bounds`
- [ ] `weld_edges`

**Deliverables**:
- ✅ 3D board → 2D projection working
- ✅ Projections rendered in N2 playground
- ✅ Label cloned correctly
- ✅ Can verify visually in model

**Testing**:
```ruby
board = Board.new(test_group)
board_2d = TwoDGroup.new(board)
board_2d.create_projection_in_playground(n2_playground)

# Visual check in model
DevTools.focus_n2
```

---

### Phase 4: Gap Detection & Placement in N2 (Week 4-6)

**Goal**: Find gaps và place boards - test trong N2 playground

**Tasks**:

#### 4.1 Sheet Model (N2 Sheets)
```ruby
class Sheet < PersistentEntity
  def calculate_gaps(margin: 5.0)
    # Work with N2 sheets
  end
end
```

#### 4.2 GapCalculator
- [ ] Sweep line algorithm
- [ ] Find rectangular gaps
- [ ] Sort by size

#### 4.3 Placement Strategies
- [ ] BestFitStrategy
- [ ] FirstFitStrategy
- [ ] BottomLeftStrategy

#### 4.4 Collision Detection
- [ ] Check overlap
- [ ] Check bounds
- [ ] Margin validation

**Deliverables**:
- ✅ Gap detection working
- ✅ Placement algorithms working
- ✅ Can place boards in N2 sheets
- ✅ Collision detection working

**Testing**:
```ruby
# Place boards in N2 playground
engine = NestingEngine.new(settings)
results = engine.nest_boards_in_playground(extra_boards, n2_playground)

# Visual verification
results.each do |r|
  puts "Board #{r[:board].board_index} → Sheet #{r[:sheet].sheet_id}"
end
```

---

## 🔗 Integration Mode: N2 → N1 (Week 7-9)

### Phase 5: N1 Integration (Week 7-8)

**Goal**: Merge N2 results vào N1 root

**Tasks**:

#### 5.1 N1 Integration Service
```ruby
class N1Integrator
  def initialize(n1_root, n2_playground)
    @n1_root = n1_root
    @n2_playground = n2_playground
  end
  
  # Copy boards từ N2 → N1
  def integrate_results(nesting_results)
    nesting_results.each do |result|
      copy_board_from_n2_to_n1(result[:board_2d], result[:sheet])
    end
  end
  
  private
  
  def copy_board_from_n2_to_n1(board_2d, n2_sheet)
    # Find corresponding N1 sheet (by classification)
    n1_sheet = find_matching_n1_sheet(n2_sheet)
    
    # Clone board 2D
    board_clone = board_2d.entity.copy
    
    # Calculate N1 position (subtract playground offset)
    n1_transform = calculate_n1_transform(board_2d.entity.transformation)
    board_clone.transform!(n1_transform)
    
    # Add to N1 sheet
    n1_sheet.entities.add_instance(board_clone.definition, board_clone.transformation)
    
    # Update attributes
    board_clone.delete_attribute('ABF', 'is-playground')
    board_clone.set_attribute('ABF', 'is-nested-2d', true)
  end
  
  def find_matching_n1_sheet(n2_sheet)
    class_key = n2_sheet.classification_key
    
    @n1_root.sheets.find { |s| 
      s.classification_key == class_key &&
      s.sheet_id == n2_sheet.sheet_id
    }
  end
  
  def calculate_n1_transform(n2_transform)
    # Remove playground offset (X-20000mm)
    offset_back = Geom::Transformation.translation([-20000.mm, 0, 0])
    n2_transform * offset_back
  end
end
```

#### 5.2 Settings Toggle
```ruby
SETTINGS = {
  use_playground: false,  # Switch to false for N1 mode
  integrate_to_n1: true,
  keep_playground: true   # Keep N2 for reference
}
```

#### 5.3 Preview in N1
- [ ] Preview trước khi integrate
- [ ] Show diff N1 before/after
- [ ] Confirmation dialog

**Deliverables**:
- ✅ Can copy results từ N2 → N1
- ✅ Transform calculations correct
- ✅ Preview in N1 working
- ✅ Rollback support

**Testing**:
```ruby
# Test integration
integrator = N1Integrator.new(n1_root, n2_playground)
integrator.integrate_results(nesting_results)

# Verify in N1
DevTools.focus_n1
DevTools.compare_roots
```

---

### Phase 6: Settings & UI (Week 8-9)

**Goal**: Settings system và user interface

**Tasks**:

#### 6.1 Settings Manager
- [ ] Settings persistence (model + file)
- [ ] Presets (conservative, aggressive)
- [ ] Validation

#### 6.2 Extra Label Dialog
- [ ] Scan unlabeled boards
- [ ] Batch validation
- [ ] Error display

#### 6.3 Extra Nesting Tool
- [ ] Main tool với preview
- [ ] Confirmation dialog
- [ ] Statistics display

#### 6.4 Development vs Production Mode
```ruby
if DEV_MODE
  # Work in N2 playground
  # Show dev tools
else
  # Work directly in N1
  # Hide dev tools
end
```

**Deliverables**:
- ✅ Settings dialog working
- ✅ Label tool working
- ✅ Nesting tool working
- ✅ Can toggle dev/production mode

---

### Phase 7: Export & Sync (Week 9)

**Goal**: Export cutting files và sync 3D↔2D

**Tasks**:

#### 7.1 Export Service
- [ ] Extract cutting paths from 2D
- [ ] Export JSON format
- [ ] Export by classification

#### 7.2 Sync Mechanism
- [ ] 3D board observer
- [ ] Auto-update 2D when 3D changes
- [ ] Manual sync UI

**Deliverables**:
- ✅ Export working
- ✅ Sync mechanism working

---

## 🚀 Production Ready (Week 10-12)

### Phase 8: Remove Playground Mode (Week 10)

**Goal**: Switch to direct N1 mode

**Tasks**:

#### 8.1 Direct N1 Mode
```ruby
# lib/extra_nesting.rb
module ExtraNesting
  DEV_MODE = false  # Production mode
  
  DEV_SETTINGS = {
    use_playground: false,
    integrate_to_n1: true,
    keep_playground: false
  }
end
```

#### 8.2 Code Cleanup
- [ ] Remove playground-specific code
- [ ] Remove dev tools (or hide behind debug flag)
- [ ] Optimize performance

#### 8.3 Final Testing
- [ ] Test directly in N1
- [ ] Test with real projects
- [ ] Performance testing

**Deliverables**:
- ✅ Works directly in N1
- ✅ No playground needed
- ✅ Production performance

---

### Phase 9: Polish & Documentation (Week 11)

**Goal**: Final touches

**Tasks**:

#### 9.1 Error Handling
- [ ] Graceful error messages
- [ ] Recovery mechanisms
- [ ] Logging

#### 9.2 Documentation
- [ ] User guide
- [ ] API documentation
- [ ] Video tutorials

#### 9.3 Localization
- [ ] English
- [ ] Vietnamese

**Deliverables**:
- ✅ Polished UI
- ✅ Complete documentation
- ✅ Multi-language support

---

### Phase 10: Release (Week 12)

**Goal**: Production release

**Tasks**:

#### 10.1 Beta Testing
- [ ] Internal testing
- [ ] User acceptance testing
- [ ] Bug fixes

#### 10.2 Deployment
- [ ] Version 1.0.0
- [ ] Extension Warehouse submission
- [ ] Release notes

**Deliverables**:
- ✅ v1.0.0 released
- ✅ Production ready

---

## Development Commands

### Quick Start (Development Mode)
```ruby
# In Ruby Console
require 'extra_nesting'

# Create N2 playground
n2 = PlaygroundCreator.create_or_find_playground(Sketchup.active_model)

# Focus camera on N2
DevTools.focus_n2

# Run nesting in playground
tool = ExtraNestingTool.new
tool.run_in_playground_mode
```

### Switch to Production Mode
```ruby
# Update config
ExtraNesting::DEV_MODE = false
ExtraNesting::DEV_SETTINGS[:use_playground] = false

# Run nesting directly in N1
tool = ExtraNestingTool.new
tool.run_in_production_mode
```

---

## Testing Strategy per Phase

### Phase 1-4 (N2 Playground)
- Manual visual testing in N2
- Unit tests for models
- N2 should be disposable (can reset anytime)

### Phase 5-7 (Integration)
- Test N2 → N1 copy
- Verify transforms correct
- Compare N1 before/after

### Phase 8-10 (Production)
- Direct N1 testing
- Real project testing
- Performance testing

---

## Risk Mitigation

### Why N2 Playground?
✅ **Safe Development**: Won't corrupt N1 data  
✅ **Easy Testing**: Can reset playground anytime  
✅ **Visual Verification**: See results side-by-side (N1 vs N2)  
✅ **Gradual Integration**: Test each component separately  
✅ **Rollback**: Can always delete N2 and start over

### When to Remove N2?
❌ Don't remove until Phase 8  
❌ Keep as debug option even in production  
✅ Add `--debug` flag to recreate N2 for troubleshooting

---

## Success Criteria

### Phase 1-4 Complete
- [ ] Can scan boards in N2
- [ ] Can classify boards
- [ ] Can create 2D projections in N2
- [ ] Can place boards in N2 sheets
- [ ] Visual verification working

### Phase 5-7 Complete
- [ ] Can integrate N2 → N1
- [ ] Settings system working
- [ ] UI tools working
- [ ] Export working

### Phase 8-10 Complete
- [ ] Works directly in N1
- [ ] Production performance
- [ ] Documentation complete
- [ ] Released v1.0.0
