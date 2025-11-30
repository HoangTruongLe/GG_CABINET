# Test Suite Documentation

This folder contains all tests for the GG_Cabinet Extra Nesting plugin, organized by component type.

## Structure

```
test/
├── test_helper.rb              # Common test utilities and assertion helpers
├── test_suite.rb               # Main test runner that loads all tests
├── README.md                   # This file
│
├── models/                     # Tests for models
│   ├── test_persistent_entity.rb
│   ├── test_board.rb
│   ├── test_face.rb
│   ├── test_intersection.rb
│   ├── test_two_d_group.rb
│   ├── test_sheet.rb
│   ├── test_edge_banding.rb
│   ├── test_label.rb
│   └── test_nesting_root.rb
│
├── services/                   # Tests for services
│   ├── test_board_scanner.rb
│   ├── test_two_d_projector.rb
│   ├── test_gap_calculator.rb
│   ├── test_nesting_engine.rb
│   ├── test_label_drawer.rb
│   ├── test_edge_banding_drawer.rb
│   └── test_board_validator.rb
│
├── integration/                # Integration tests
│   └── test_labeling_workflow.rb
│
└── phase/                      # Phase-specific test scripts
    ├── test_phase1.rb          # Phase 1: Foundation & N2 Playground
    ├── test_phase2.rb          # Phase 2: Board Detection & Classification
    ├── test_phase3.rb          # Phase 3: 2D Projection
    ├── test_phase4.rb          # Phase 4: Nesting Engine
    └── test_settings.rb        # Settings Manager tests
```

## Running Tests

### Run All Tests

Load the main test suite in SketchUp Ruby Console:

```ruby
load 'c:/Users/KB5007253/Desktop/tools/GG_ExtraNesting/test/test_suite.rb'
```

### Run Individual Test Files

You can also load individual test files:

```ruby
# Load test helper first
load 'c:/Users/KB5007253/Desktop/tools/GG_ExtraNesting/test/test_helper.rb'

# Then load specific test file
load 'c:/Users/KB5007253/Desktop/tools/GG_ExtraNesting/test/models/test_board.rb'
```

## Test Organization

### Models Tests

Each model has its own test file:
- **test_persistent_entity.rb**: Tests for the base PersistentEntity class
- **test_board.rb**: Tests for Board model (geometry, validation, classification)
- **test_face.rb**: Tests for Face model (detection, comparison)
- **test_intersection.rb**: Tests for Intersection model (layer validation, detection)
- **test_two_d_group.rb**: Tests for TwoDGroup model (2D projection)
- **test_sheet.rb**: Tests for Sheet model (nesting sheets)
- **test_edge_banding.rb**: Tests for EdgeBanding model (parsing, serialization)
- **test_label.rb**: Tests for Label model
- **test_nesting_root.rb**: Tests for NestingRoot model

### Services Tests

Each service has its own test file:
- **test_board_scanner.rb**: Tests for BoardScanner (scanning, filtering)
- **test_two_d_projector.rb**: Tests for TwoDProjector (2D projection, backface)
- **test_gap_calculator.rb**: Tests for GapCalculator (gap detection)
- **test_nesting_engine.rb**: Tests for NestingEngine (nesting logic)
- **test_label_drawer.rb**: Tests for LabelDrawer (label creation)
- **test_edge_banding_drawer.rb**: Tests for EdgeBandingDrawer (geometry, drawing)
- **test_board_validator.rb**: Tests for BoardValidator (validation, batch)

### Integration Tests

End-to-end workflow tests:
- **test_labeling_workflow.rb**: Complete labeling workflow tests

### Phase Tests

Phase-specific acceptance tests:
- **test_phase1.rb**: Tests for Phase 1 (Foundation & N2 Playground)
- **test_phase2.rb**: Tests for Phase 2 (Board Detection & Classification)
- **test_phase3.rb**: Tests for Phase 3 (2D Projection)
- **test_phase4.rb**: Tests for Phase 4 (Nesting Engine)
- **test_settings.rb**: Tests for Settings Manager

## Test Helper

The `test_helper.rb` file provides:
- `TestResults` class for tracking test results
- Assertion helpers: `assert`, `assert_equal`, `assert_not_nil`, `assert_true`, `assert_false`
- Helper methods: `create_test_board`, `create_test_board_with_intersections`, `find_or_create_layer`

## Adding New Tests

1. Create a new test file in the appropriate folder (`models/`, `services/`, or `integration/`)
2. Require the test helper: `require_relative '../test_helper'`
3. Add test methods in the `TestHelper` module
4. Update `test_suite.rb` to load and run your new test file

Example:

```ruby
# test/models/test_new_model.rb
require_relative '../test_helper'

module GG_Cabinet
  module ExtraNesting
    module TestHelper
      def self.test_new_model(results)
        puts "\nTesting NewModel..."
        begin
          # Your test code here
          results.record_pass("NewModel test")
        rescue => e
          results.record_fail("NewModel test", e.message)
        end
      end
    end
  end
end
```

Then add to `test_suite.rb`:

```ruby
require_relative 'models/test_new_model'
# ...
TestHelper.test_new_model(results)
```

## Migration Notes

The tests were previously in:
- `test_suite.rb` (comprehensive test suite)
- `test_intersections.rb` (intersection-specific tests)
- `test_edge_banding.rb` (edge banding tests)
- `test_phase1.rb`, `test_phase2.rb`, `test_phase3.rb`, `test_phase4.rb` (phase-specific tests)
- `test_settings.rb` (settings tests)

All tests have been reorganized into this structure:
- Unit tests split by model/service → `test/models/` and `test/services/`
- Integration tests → `test/integration/`
- Phase-specific tests → `test/phase/`

**Note:** The old test files (`test_suite.rb`, `test_intersections.rb`, `test_edge_banding.rb`) have been removed from the root directory. All their tests have been migrated to the organized structure above. All new tests should follow the structure in this folder.
