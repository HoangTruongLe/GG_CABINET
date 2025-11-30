# Phase-Specific Test Scripts

This folder contains phase-specific test scripts for different development phases of the GG_Cabinet Extra Nesting plugin.

## Test Files

### test_phase1.rb
Tests for **Phase 1: Foundation & N2 Playground**
- Plugin module loading
- N1/N2 nesting root detection
- Playground creation
- DevTools functionality
- Database system

**Run:**
```ruby
load 'c:/Users/KB5007253/Desktop/tools/GG_ExtraNesting/test/phase/test_phase1.rb'
```

### test_phase2.rb
Tests for **Phase 2: Board Detection & Classification**
- BoardScanner service
- Board model (material, thickness, classification)
- Face model (front/back/side detection)
- BoardValidator service
- Classification and statistics

**Run:**
```ruby
load 'c:/Users/KB5007253/Desktop/tools/GG_ExtraNesting/test/phase/test_phase2.rb'
```

### test_phase3.rb
Tests for **Phase 3: 2D Projection**
- TwoDGroup model
- TwoDProjector service
- Backface projection
- Edge banding integration

**Run:**
```ruby
load 'c:/Users/KB5007253/Desktop/tools/GG_ExtraNesting/test/phase/test_phase3.rb'
```

### test_phase4.rb
Tests for **Phase 4: Nesting Engine**
- Sheet model
- GapCalculator service
- NestingEngine service
- Placement algorithms

**Run:**
```ruby
load 'c:/Users/KB5007253/Desktop/tools/GG_ExtraNesting/test/phase/test_phase4.rb'
```

### test_settings.rb
Tests for **Settings Manager**
- Settings loading from N1
- User overrides
- Validation
- Calculated values

**Run:**
```ruby
load 'c:/Users/KB5007253/Desktop/tools/GG_ExtraNesting/test/phase/test_settings.rb'
```

## Usage

These are acceptance/integration test scripts that validate each development phase. They provide detailed output and can be run independently to verify phase completion.

For unit tests organized by component, see the main test suite:
- `test/test_suite.rb` - Main test runner
- `test/models/` - Model unit tests
- `test/services/` - Service unit tests
- `test/integration/` - Integration tests

