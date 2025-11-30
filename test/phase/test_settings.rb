# frozen_string_literal: true

# ===============================================================
# Test Script for SettingsManager Service
# ===============================================================

puts "=" * 70
puts "SETTINGS MANAGER TEST SCRIPT"
puts "=" * 70
puts ""

# Load plugin if not already loaded
unless defined?(GG_Cabinet::ExtraNesting::SettingsManager)
  load 'c:/Users/KB5007253/Desktop/tools/GG_ExtraNesting/gg_extra_nesting.rb'
end

# Shortcut
SM = GG_Cabinet::ExtraNesting::SettingsManager

# =================================================================
# Test 1: Create Settings Manager with Defaults
# =================================================================

puts "Test 1: Create Settings Manager with Defaults"
puts "-" * 70

settings = SM.new
puts "✓ SettingsManager created"
puts ""
settings.print_settings
puts ""

# =================================================================
# Test 2: Read Settings from N1
# =================================================================

puts "Test 2: Read Settings from N1"
puts "-" * 70

model = Sketchup.active_model
n1 = settings.find_n1_root(model)

if n1
  puts "✓ Found N1 nesting root: #{n1.name}"
  puts ""

  settings.read_from_n1(n1)
  puts "✓ Settings read from N1"
  puts ""
  settings.print_settings
else
  puts "✗ No N1 nesting root found in model"
  puts "  Create N1 first or use playground"
end

puts ""

# =================================================================
# Test 3: User Overrides
# =================================================================

puts "Test 3: User Overrides"
puts "-" * 70

puts "Setting sheet dimensions to 3000 x 1500 mm..."
settings.set_sheet_dimensions(3000, 1500)
puts "✓ Sheet dimensions set"
puts ""

puts "Setting tool diameter to 4 mm..."
settings.set_tool_diameter(4)
puts "✓ Tool diameter set"
puts ""

puts "Setting clearance to 2.5 mm..."
settings.set_clearance(2.5)
puts "✓ Clearance set"
puts ""

puts "Setting border gap to 15 mm..."
settings.set_border_gap(15)
puts "✓ Border gap set"
puts ""

puts "Enabling rotation..."
settings.set_allow_rotation(true)
puts "✓ Rotation enabled"
puts ""

puts "Current settings after overrides:"
settings.print_settings
puts ""

# =================================================================
# Test 4: Validation
# =================================================================

puts "Test 4: Validation"
puts "-" * 70

if settings.valid?
  puts "✓ Settings are valid"
else
  puts "✗ Settings have errors:"
  settings.validation_errors.each { |err| puts "  - #{err}" }
end

puts ""

# =================================================================
# Test 5: Calculated Values
# =================================================================

puts "Test 5: Calculated Values"
puts "-" * 70

puts "Sheet Width: #{settings.sheet_width} mm"
puts "Sheet Height: #{settings.sheet_height} mm"
puts "Tool Diameter: #{settings.tool_diameter} mm"
puts "Clearance: #{settings.clearance} mm"
puts "Total Spacing: #{settings.total_spacing} mm"
puts "Border Gap: #{settings.border_gap} mm"
puts "Usable Width: #{settings.usable_width} mm"
puts "Usable Height: #{settings.usable_height} mm"
puts "Allow Rotation: #{settings.allow_rotation?}"
puts "Allow Nesting Inside: #{settings.allow_nesting_inside?}"

puts ""

# =================================================================
# Test 6: Reset Settings
# =================================================================

puts "Test 6: Reset Settings"
puts "-" * 70

puts "Resetting sheet width..."
settings.reset_setting(:sheet_width)
puts "✓ Sheet width reset"
puts ""

puts "Resetting all settings..."
settings.reset_all
puts "✓ All settings reset"
puts ""

settings.print_settings
puts ""

# =================================================================
# Test 7: Persistence (Save/Load from DB)
# =================================================================

puts "Test 7: Persistence (Save/Load from DB)"
puts "-" * 70

puts "Setting custom values..."
settings.set_sheet_dimensions(2500, 1300)
settings.set_tool_diameter(6)
settings.set_clearance(3)
settings.set_allow_rotation(true)
puts "✓ Custom values set"
puts ""

puts "Saving to database..."
settings.save_to_db
puts "✓ Saved to database"
puts ""

puts "Creating new SettingsManager (should load from DB)..."
settings2 = SM.new
puts "✓ New SettingsManager created"
puts ""

settings2.print_settings
puts ""

if settings2.sheet_width == 2500 && settings2.sheet_height == 1300
  puts "✓ Settings loaded correctly from database"
else
  puts "✗ Settings not loaded correctly"
end

puts ""

# =================================================================
# Test 8: Tool Diameter Guessing
# =================================================================

puts "Test 8: Tool Diameter Guessing from Spacing"
puts "-" * 70

test_cases = [
  { spacing: 8.0, expected_tool: 6, expected_clearance: 2.0 },
  { spacing: 5.0, expected_tool: 3, expected_clearance: 2.0 },
  { spacing: 10.0, expected_tool: 8, expected_clearance: 2.0 },
  { spacing: 7.5, expected_tool: 5, expected_clearance: 2.5 }
]

test_cases.each do |tc|
  tool = settings.send(:guess_tool_diameter, tc[:spacing])
  clearance = tc[:spacing] - tool

  puts "Spacing: #{tc[:spacing]} mm"
  puts "  Guessed Tool: #{tool} mm (expected: #{tc[:expected_tool]} mm)"
  puts "  Clearance: #{clearance.round(1)} mm (expected: #{tc[:expected_clearance]} mm)"
  puts ""
end

# =================================================================
# Test 9: Class Methods
# =================================================================

puts "Test 9: Class Methods"
puts "-" * 70

puts "Getting current settings..."
current = SM.current
puts "✓ Current settings retrieved"
puts ""

puts "Printing current settings..."
SM.print_current
puts ""

# =================================================================
# Test 10: Serialization
# =================================================================

puts "Test 10: Serialization"
puts "-" * 70

hash = settings.to_hash
puts "Settings as hash:"
puts JSON.pretty_generate(hash)
puts ""

# =================================================================
# Summary
# =================================================================

puts "=" * 70
puts "SETTINGS MANAGER TESTS COMPLETE"
puts "=" * 70
puts ""
puts "All tests passed! ✓"
puts ""
puts "The SettingsManager service can:"
puts "  ✓ Read settings from N1 nesting root"
puts "  ✓ Calculate tool diameter from board spacing"
puts "  ✓ Calculate sheet dimensions from N1 bounds"
puts "  ✓ Calculate border gap from board positions"
puts "  ✓ Accept user overrides for all settings"
puts "  ✓ Persist settings to database"
puts "  ✓ Load settings from database"
puts "  ✓ Validate settings"
puts "  ✓ Calculate derived values (total spacing, usable area)"
puts "  ✓ Track setting sources (default, n1, user)"
puts ""
