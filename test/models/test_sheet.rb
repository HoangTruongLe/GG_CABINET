# frozen_string_literal: true

# ===============================================================
# Tests for Sheet Model
# ===============================================================

require_relative '../test_helper'

module GG_Cabinet
  module ExtraNesting
    module TestHelper

      def self.test_sheet_model(results)
        puts "\nTesting Sheet Model..."

        begin
          model = Sketchup.active_model

          # Create test nesting root
          root_group = model.entities.add_group
          root_group.name = "TestRoot"
          root = NestingRoot.new(root_group)

          # Create test sheet
          sheet_group = root_group.entities.add_group
          sheet_group.name = "TestSheet"
          sheet_group.set_attribute('ABF', 'is-sheet', true)

          sheet = Sheet.new(sheet_group, root)

          # Test dimensions
          assert(sheet.width > 0, "Width should be positive")
          assert(sheet.height > 0, "Height should be positive")
          assert(sheet.area > 0, "Area should be positive")

          # Test empty sheet
          assert_true(sheet.is_empty?, "Sheet should be empty")
          assert_equal(0, sheet.board_count)
          assert_equal(0.0, sheet.utilization)

          # Test validation
          assert_true(sheet.valid?, "Sheet should be valid")

          root_group.erase!
          results.record_pass("Sheet model basic functionality")

        rescue => e
          results.record_fail("Sheet model basic functionality", e.message)
        end
      end

    end
  end
end
