# Quick Start Guide - Phase 1

## Installation

### Method 1: Direct Copy (Development)

1. Copy the entire `GG_ExtraNesting` folder to:
   ```
   C:\Users\[YourUsername]\AppData\Roaming\SketchUp\SketchUp 2024\SketchUp\Plugins\
   ```

2. Restart SketchUp

### Method 2: Load from Current Location

1. Open SketchUp
2. Open Ruby Console: Extensions > Ruby Console
3. Run:
   ```ruby
   load 'C:/Users/KB5007253/Desktop/tools/GG_ExtraNesting/gg_extra_nesting.rb'
   ```

## Quick Test

### Step 1: Check Installation

In Ruby Console:
```ruby
GG_Cabinet::ExtraNesting::VERSION
# Should output: "0.1.0-dev"
```

### Step 2: Run Test Script

```ruby
load 'C:/Users/KB5007253/Desktop/tools/GG_ExtraNesting/test_phase1.rb'
```

This will run all Phase 1 tests and show you:
- ✓ What's working
- ✗ What needs attention
- 📊 Test summary

### Step 3: Create Playground

**Option A - Menu**:
1. Go to: `Plugins > GG Extra Nesting > 🎮 Dev: Create Playground`
2. Dialog will confirm creation

**Option B - Ruby Console**:
```ruby
model = Sketchup.active_model
n2 = GG_Cabinet::ExtraNesting::PlaygroundCreator.create_or_find_playground(model)
```

### Step 4: Navigate

**Focus on N1 (Original)**:
```ruby
GG_Cabinet::ExtraNesting::DevTools.focus_n1
```

**Focus on N2 (Playground)**:
```ruby
GG_Cabinet::ExtraNesting::DevTools.focus_n2
```

**Compare**:
```ruby
GG_Cabinet::ExtraNesting::DevTools.compare_roots
```

## Common Commands

### Playground Management

```ruby
# Get info
info = GG_Cabinet::ExtraNesting::PlaygroundCreator.playground_info(Sketchup.active_model)
puts info.inspect

# Create or find
n2 = GG_Cabinet::ExtraNesting::PlaygroundCreator.create_or_find_playground(Sketchup.active_model)

# Reset (delete and recreate)
GG_Cabinet::ExtraNesting::PlaygroundCreator.reset_playground(Sketchup.active_model)

# Delete
GG_Cabinet::ExtraNesting::PlaygroundCreator.delete_playground(Sketchup.active_model)
```

### Database Operations

```ruby
# Get stats
GG_Cabinet::ExtraNesting::DevTools.print_db_stats

# Clear all
GG_Cabinet::ExtraNesting::DevTools.clear_database
```

### Board Info (Debug)

```ruby
# Select a board in model, then:
board = Sketchup.active_model.selection[0]
GG_Cabinet::ExtraNesting::DevTools.print_board_info(board)
```

## Troubleshooting

### "N1 Nesting Root not found"

Your model needs a nesting root group with attributes:
1. Select the nesting root group
2. Right-click > Entity Info
3. Click "Advanced Attributes"
4. Check for: `ABF > is-nesting-root: true`

### Plugin Doesn't Load

Check Ruby Console for errors:
```ruby
# Force reload
load 'C:/Users/KB5007253/Desktop/tools/GG_ExtraNesting/gg_extra_nesting.rb'
```

### Can't See Playground

```ruby
# Focus camera
GG_Cabinet::ExtraNesting::DevTools.focus_n2

# Or manually find it
model = Sketchup.active_model
n2 = model.entities.find { |e| e.name == "__N2_Playground_ExtraNesting" }
Sketchup.active_model.active_view.zoom(n2) if n2
```

## What's Working (Phase 1)

✅ Plugin architecture
✅ Module system
✅ Base classes (PersistentEntity)
✅ Database system
✅ N2 Playground creation
✅ Playground navigation
✅ DevTools helpers

## What's Next (Phase 2)

🚧 Board detection
🚧 Material/thickness classification
🚧 Board validation
🚧 Label tool

## Need Help?

Run the test script:
```ruby
load 'C:/Users/KB5007253/Desktop/tools/GG_ExtraNesting/test_phase1.rb'
```

It will tell you exactly what's working and what's not!
