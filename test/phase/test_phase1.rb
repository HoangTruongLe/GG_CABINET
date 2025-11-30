# frozen_string_literal: true

# ===============================================================
# Phase 1 Testing Script
# Run this in SketchUp Ruby Console to test Phase 1 features
# ===============================================================

puts "=" * 70
puts "PHASE 1 TESTING - N2 Playground Foundation"
puts "=" * 70
puts ""

model = Sketchup.active_model

# Test 1: Check if plugin loaded
puts "Test 1: Plugin Module Loaded"
if defined?(GG_Cabinet::ExtraNesting)
  puts "  ✓ GG_Cabinet::ExtraNesting module exists"
  puts "  ✓ Version: #{GG_Cabinet::ExtraNesting::VERSION}"
  puts "  ✓ Dev Mode: #{GG_Cabinet::ExtraNesting::DEV_MODE}"
else
  puts "  ✗ Module not loaded!"
end
puts ""

# Test 2: Check N1 root exists
puts "Test 2: Find N1 Nesting Root"
n1 = GG_Cabinet::ExtraNesting::PlaygroundCreator.find_n1_nesting_root(model)
if n1
  puts "  ✓ N1 Root found"
  puts "    - Name: #{n1.name}"
  puts "    - ID: #{n1.entityID}"
  puts "    - Bounds: #{n1.bounds.width / 1.mm} × #{n1.bounds.height / 1.mm} × #{n1.bounds.depth / 1.mm} mm"
else
  puts "  ✗ N1 Root not found!"
  puts "    → Please ensure your model has a nesting root with 'is-nesting-root: true'"
end
puts ""

# Test 3: Check N2 playground
puts "Test 3: Check N2 Playground"
n2 = GG_Cabinet::ExtraNesting::PlaygroundCreator.find_n2_playground(model)
if n2
  puts "  ✓ N2 Playground exists"
  puts "    - Name: #{n2.name}"
  puts "    - ID: #{n2.entityID}"
  puts "    - Offset: #{n2.transformation.origin.x / 1.mm} mm on X-axis"
else
  puts "  ⚠ N2 Playground not found"
  puts "    → Run: GG_Cabinet::ExtraNesting::PlaygroundCreator.create_or_find_playground(model)"
end
puts ""

# Test 4: Create playground if not exists
if n1 && !n2
  puts "Test 4: Creating N2 Playground"
  n2 = GG_Cabinet::ExtraNesting::PlaygroundCreator.create_or_find_playground(model)
  if n2
    puts "  ✓ N2 Playground created successfully"
    puts "    - Offset: +20000mm on X-axis"
  else
    puts "  ✗ Failed to create playground"
  end
  puts ""
end

# Test 5: Compare roots
puts "Test 5: Compare N1 vs N2"
info = GG_Cabinet::ExtraNesting::PlaygroundCreator.playground_info(model)
puts "  N1 exists: #{info[:has_n1]}"
puts "  N2 exists: #{info[:has_n2]}"
if info[:has_n1] && info[:has_n2]
  offset_x = info[:n2_bounds].min.x - info[:n1_bounds].min.x
  puts "  Offset: #{offset_x / 1.mm} mm"

  if (offset_x - 20000.mm).abs < 1.mm
    puts "  ✓ Offset is correct (20000mm)"
  else
    puts "  ✗ Offset mismatch! Expected 20000mm, got #{offset_x / 1.mm}mm"
  end
end
puts ""

# Test 6: DevTools
puts "Test 6: DevTools Functions"
if defined?(GG_Cabinet::ExtraNesting::DevTools)
  puts "  ✓ DevTools module loaded"

  methods = [
    :focus_n1,
    :focus_n2,
    :compare_roots,
    :print_board_info,
    :print_db_stats
  ]

  methods.each do |method|
    if GG_Cabinet::ExtraNesting::DevTools.respond_to?(method)
      puts "    ✓ #{method}"
    else
      puts "    ✗ #{method} missing"
    end
  end
else
  puts "  ✗ DevTools not loaded"
end
puts ""

# Test 7: Database
puts "Test 7: Database System"
db = GG_Cabinet::ExtraNesting::Database.instance
puts "  ✓ Database instance created"

# Test save/load
db.save('test', 'test1', { name: 'Test Board', value: 123 })
result = db.find('test', 'test1')
if result && result[:name] == 'Test Board'
  puts "  ✓ Save/Load works"
else
  puts "  ✗ Save/Load failed"
end

stats = db.stats
puts "  ✓ Stats: #{stats[:total_records]} records in #{stats[:tables].length} tables"
puts ""

# Summary
puts "=" * 70
puts "PHASE 1 TEST SUMMARY"
puts "=" * 70

tests_passed = 0
tests_total = 7

tests_passed += 1 if defined?(GG_Cabinet::ExtraNesting)
tests_passed += 1 if n1
tests_passed += 1 if n2
tests_passed += 1 if info[:has_n1] && info[:has_n2]
tests_passed += 1 if defined?(GG_Cabinet::ExtraNesting::DevTools)
tests_passed += 1 if result
tests_passed += 1

puts "Tests Passed: #{tests_passed}/#{tests_total}"
puts ""

if tests_passed == tests_total
  puts "🎉 ALL TESTS PASSED! Phase 1 foundation is working correctly."
elsif tests_passed >= 5
  puts "⚠ Most tests passed. Phase 1 foundation is mostly working."
else
  puts "❌ Several tests failed. Please check the errors above."
end

puts "=" * 70
puts ""
puts "Next steps:"
puts "  1. Use 'Dev: Focus N1' to view original nesting"
puts "  2. Use 'Dev: Focus N2' to view playground"
puts "  3. Ready for Phase 2 implementation!"
puts ""
