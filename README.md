# GG Cabinet Extra Nesting Plugin

**Version**: 0.1.0-dev (Phase 1)
**Status**: Development - N2 Playground Foundation

## Overview

SketchUp plugin for adding extra boards to existing nesting layouts without re-nesting everything.

## Phase 1 Features ✅

- **N2 Playground System**: Safe development environment at X+20000mm offset
- **PlaygroundCreator Service**: Create/manage playground copies of N1 root
- **DevTools**: Development helpers for navigation and debugging
- **Base Architecture**: PersistentEntity, Database, core models

## Installation (Development)

1. Copy the entire `GG_ExtraNesting` folder to SketchUp Plugins directory:
   - Windows: `C:\Users\[Username]\AppData\Roaming\SketchUp\SketchUp 20XX\SketchUp\Plugins\`
   - Mac: `~/Library/Application Support/SketchUp 20XX/SketchUp/Plugins/`

2. Launch SketchUp

3. Check Ruby Console for initialization message:
   ```
   ============================================================
   GG_Cabinet Extra Nesting v0.1.0-dev
   Development Mode: true
   ============================================================
   ✓ Extra Nesting Plugin initialized successfully
   ```

## Usage (Phase 1)

### Menu: Plugins > GG Extra Nesting

**Development Tools**:
- 🎮 **Dev: Create Playground** - Create N2 playground from N1 root
- 🎮 **Dev: Focus N1** - Camera zoom to original nesting root
- 🎮 **Dev: Focus N2** - Camera zoom to playground

### Testing the Playground

1. Open a SketchUp model with existing nesting (N1 root with `is-nesting-root: true`)

2. **Create Playground**:
   ```ruby
   # Ruby Console
   model = Sketchup.active_model
   n2 = GG_Cabinet::ExtraNesting::PlaygroundCreator.create_or_find_playground(model)
   ```

3. **Navigate**:
   - Use menu: `Dev: Focus N1` / `Dev: Focus N2`
   - Or Ruby Console:
     ```ruby
     GG_Cabinet::ExtraNesting::DevTools.focus_n1
     GG_Cabinet::ExtraNesting::DevTools.focus_n2
     ```

4. **Compare**:
   ```ruby
   GG_Cabinet::ExtraNesting::DevTools.compare_roots
   ```

## Project Structure

```
GG_ExtraNesting/
├── gg_extra_nesting.rb           # Main loader (RBZ entry point)
│
└── lib/
    ├── extra_nesting.rb          # Plugin initialization
    ├── database.rb               # In-memory database
    ├── dev_tools.rb              # Development helpers
    │
    ├── models/                   # Domain models
    │   ├── persistent_entity.rb  # Base class ✅
    │   ├── board.rb              # Board model (placeholder)
    │   ├── face.rb               # Face model (placeholder)
    │   ├── two_d_group.rb        # 2D projection (placeholder)
    │   ├── sheet.rb              # Sheet model (placeholder)
    │   ├── nesting_root.rb       # Root model (placeholder)
    │   ├── label.rb              # Label model (placeholder)
    │   ├── edge_banding.rb       # Edge band (placeholder)
    │   └── intersection.rb       # Intersection (placeholder)
    │
    ├── services/                 # Business logic
    │   ├── playground_creator.rb # N2 playground ✅
    │   ├── board_scanner.rb      # Scan boards (placeholder)
    │   └── board_validator.rb    # Validate boards (placeholder)
    │
    └── helpers/                  # Helper modules
        └── geometry_helpers.rb   # Geometry utils (placeholder)
```

## Requirements

- SketchUp 2017 or later
- Existing nesting root with `ABF > is-nesting-root: true`

## Development Mode

Currently in **DEV_MODE** with:
- `use_playground: true` - Work in N2 playground
- `playground_offset_x: 20000mm` - Offset from N1
- `debug_logging: true` - Verbose console output

## Next Steps (Phase 2)

- [ ] Board detection and classification
- [ ] Material/thickness detection
- [ ] Board validation system
- [ ] Label tool for extra boards

## Testing Checklist

- [x] Plugin loads without errors
- [x] Menu items appear correctly
- [x] N1 root is detected
- [x] N2 playground is created
- [x] Playground offset is correct (20000mm)
- [x] Camera navigation works (Focus N1/N2)
- [x] Compare function displays info

## Troubleshooting

**"N1 Nesting Root not found"**:
- Ensure your model has a group with `ABF > is-nesting-root: true`
- Check attribute: Window > Entity Info > Advanced Attributes

**Plugin doesn't load**:
- Check Ruby Console for errors
- Verify file structure matches above
- Ensure `gg_extra_nesting.rb` is in Plugins folder

**Playground not visible**:
- Use `Dev: Focus N2` to zoom to playground
- Check it exists: Look for group named `__N2_Playground_ExtraNesting`

## Ruby Console Commands

```ruby
# Get plugin info
info = GG_Cabinet::ExtraNesting::PlaygroundCreator.playground_info(Sketchup.active_model)
puts info.inspect

# Create playground
n2 = GG_Cabinet::ExtraNesting::PlaygroundCreator.create_or_find_playground(Sketchup.active_model)

# Reset playground
GG_Cabinet::ExtraNesting::PlaygroundCreator.reset_playground(Sketchup.active_model)

# Database stats
GG_Cabinet::ExtraNesting::DevTools.print_db_stats

# Clear database
GG_Cabinet::ExtraNesting::DevTools.clear_database
```

## License

Internal tool for GG_Cabinet

## Contact

GG_Cabinet Team
