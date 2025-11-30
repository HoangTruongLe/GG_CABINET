# frozen_string_literal: true

# ===============================================================
# Tests for GapCalculator Service
# ===============================================================

require_relative '../test_helper'

module GG_Cabinet
  module ExtraNesting
    module TestHelper

      def self.test_gap_calculator(results)
        puts "\nTesting GapCalculator..."

        begin
          model = Sketchup.active_model

          # Create test sheet
          root_group = model.entities.add_group
          root = NestingRoot.new(root_group)

          sheet_group = root_group.entities.add_group
          sheet_group.set_attribute('ABF', 'is-sheet', true)
          sheet = Sheet.new(sheet_group, root)

          calculator = GapCalculator.new(sheet)

          # Test empty sheet - should have one large gap
          gaps = calculator.find_gaps
          assert(gaps.count > 0, "Empty sheet should have at least one gap")

          largest_gap = gaps.first
          assert(largest_gap[:area] > 0, "Gap should have positive area")

          root_group.erase!
          results.record_pass("GapCalculator basic functionality")

        rescue => e
          results.record_fail("GapCalculator basic functionality", e.message)
        end
      end

    end
  end
end
