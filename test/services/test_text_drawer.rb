# frozen_string_literal: true

# ===============================================================
# Tests for TextDrawer Service
# ===============================================================

require_relative '../test_helper'

module GG_Cabinet
  module ExtraNesting
    module TestHelper

      def self.test_text_drawer(results)
        puts "\nTesting TextDrawer..."

        model = nil
        begin
          model = Sketchup.active_model
          model.start_operation('Test TextDrawer', true)

          # Test 1: Basic text drawing
          test_basic_text_drawing(model, results)

          # Test 2: Integer/Float text conversion
          test_text_conversion(model, results)

          # Test 3: Multi-line text
          test_multiline_text(model, results)

          # Test 4: Text width estimation
          test_text_width_estimation(results)

          # Test 5: Text in group
          test_text_in_group(model, results)

          # Test 6: Oriented text
          test_oriented_text(model, results)

          # Test 7: Centered text
          test_centered_text(model, results)

          model.commit_operation
          results.record_pass("TextDrawer all tests")

        rescue => e
          model.abort_operation if model && model.active_operation
          results.record_fail("TextDrawer all tests", e.message)
          puts "  Error: #{e.message}"
          puts "  Backtrace: #{e.backtrace.first(5).join("\n  ")}"
        end
      end

      private

      def self.test_basic_text_drawing(model, results)
        begin
          drawer = TextDrawer
          entities = model.active_entities

          # Create a test group
          test_group = entities.add_group
          test_entities = test_group.entities

          position = Geom::Point3d.new(0, 0, 0)
          text_entities = drawer.draw_text(test_entities, "Hello", position, { height: 10 })

          assert_not_nil(text_entities, "Text entities should be created")
          assert(text_entities.is_a?(Array), "Text entities should be an array")
          assert(text_entities.length > 0, "Should create at least one text entity")

          test_group.erase!
          results.record_pass("Basic text drawing")
        rescue => e
          results.record_fail("Basic text drawing", e.message)
        end
      end

      def self.test_text_conversion(model, results)
        begin
          drawer = TextDrawer
          entities = model.active_entities

          test_group = entities.add_group
          test_entities = test_group.entities

          position = Geom::Point3d.new(200, 0, 0)

          # Test integer
          int_text = 123
          text_entities_int = drawer.draw_text(test_entities, int_text, position, { height: 10 })
          assert(text_entities_int.is_a?(Array), "Integer text should create entities")

          # Test float
          float_position = position.offset(Geom::Vector3d.new(0, 50, 0))
          float_text = 45.5
          text_entities_float = drawer.draw_text(test_entities, float_text, float_position, { height: 10 })
          assert(text_entities_float.is_a?(Array), "Float text should create entities")

          # Test float that's a whole number (should remove .0)
          whole_float_position = position.offset(Geom::Vector3d.new(0, 100, 0))
          whole_float_text = 100.0
          text_entities_whole = drawer.draw_text(test_entities, whole_float_text, whole_float_position, { height: 10 })
          assert(text_entities_whole.is_a?(Array), "Whole number float should create entities")

          test_group.erase!
          results.record_pass("Text conversion (Integer/Float)")
        rescue => e
          results.record_fail("Text conversion (Integer/Float)", e.message)
        end
      end

      def self.test_multiline_text(model, results)
        begin
          drawer = TextDrawer
          entities = model.active_entities

          test_group = entities.add_group
          test_entities = test_group.entities

          position = Geom::Point3d.new(300, 0, 0)
          multiline_text = "Line 1\nLine 2\nLine 3"
          
          text_entities = drawer.draw_multiline_text(test_entities, multiline_text, position, { height: 10 })

          assert_not_nil(text_entities, "Multi-line text entities should be created")
          assert(text_entities.is_a?(Array), "Text entities should be an array")
          assert(text_entities.length > 0, "Should create text entities for multiple lines")

          test_group.erase!
          results.record_pass("Multi-line text drawing")
        rescue => e
          results.record_fail("Multi-line text drawing", e.message)
        end
      end

      def self.test_text_width_estimation(results)
        begin
          drawer = TextDrawer

          # Test width estimation
          width1 = drawer.estimate_text_width("Hello", 10.mm)
          assert(width1 > 0, "Width estimation should be positive")

          width2 = drawer.estimate_text_width("Hello World", 10.mm)
          assert(width2 > width1, "Longer text should have greater width")

          # Test with integer input
          width3 = drawer.estimate_text_width(123, 10.mm)
          assert(width3 > 0, "Width estimation should work with integer")

          # Test with empty string
          width4 = drawer.estimate_text_width("", 10.mm)
          assert_equal(0, width4, "Width estimation should be 0 for empty string")

          results.record_pass("Text width estimation")
        rescue => e
          results.record_fail("Text width estimation", e.message)
        end
      end

      def self.test_text_in_group(model, results)
        begin
          drawer = TextDrawer
          entities = model.active_entities

          # Create a parent group
          parent_group = entities.add_group
          position = Geom::Point3d.new(400, 0, 0)

          text_entities = drawer.draw_text_in_group(parent_group, "Group Text", position, { height: 10 })

          assert_not_nil(text_entities, "Text entities in group should be created")
          assert(text_entities.is_a?(Array), "Text entities should be an array")
          assert(parent_group.entities.length > 0, "Group should contain entities")

          parent_group.erase!
          results.record_pass("Text drawing in group")
        rescue => e
          results.record_fail("Text drawing in group", e.message)
        end
      end

      def self.test_oriented_text(model, results)
        begin
          drawer = TextDrawer
          entities = model.active_entities

          test_group = entities.add_group
          test_entities = test_group.entities

          origin = Geom::Point3d.new(500, 0, 0)
          x_axis = Geom::Vector3d.new(1, 0, 0)
          y_axis = Geom::Vector3d.new(0, 1, 0)

          text_entities = drawer.draw_text_oriented(
            test_entities,
            "Oriented",
            origin,
            x_axis,
            y_axis,
            { height: 10 }
          )

          assert_not_nil(text_entities, "Oriented text entities should be created")
          assert(text_entities.is_a?(Array), "Text entities should be an array")

          test_group.erase!
          results.record_pass("Oriented text drawing")
        rescue => e
          results.record_fail("Oriented text drawing", e.message)
        end
      end

      def self.test_centered_text(model, results)
        begin
          drawer = TextDrawer
          entities = model.active_entities

          test_group = entities.add_group
          test_entities = test_group.entities

          center = Geom::Point3d.new(600, 0, 0)
          x_axis = Geom::Vector3d.new(1, 0, 0)
          y_axis = Geom::Vector3d.new(0, 1, 0)

          text_entities = drawer.draw_text_centered(
            test_entities,
            "Centered",
            center,
            x_axis,
            y_axis,
            { height: 10 }
          )

          assert_not_nil(text_entities, "Centered text entities should be created")
          assert(text_entities.is_a?(Array), "Text entities should be an array")

          test_group.erase!
          results.record_pass("Centered text drawing")
        rescue => e
          results.record_fail("Centered text drawing", e.message)
        end
      end

    end
  end
end

