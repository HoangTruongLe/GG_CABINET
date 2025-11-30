# frozen_string_literal: true

# ===============================================================
# Tests for NestingRoot Model
# ===============================================================

require_relative '../test_helper'

module GG_Cabinet
  module ExtraNesting
    module TestHelper

      def self.test_nesting_root_model(results)
        puts "\nTesting NestingRoot Model..."

        begin
          model = Sketchup.active_model

          # Create test nesting root
          root_group = model.entities.add_group
          root_group.name = "TestNestingRoot"
          root_group.set_attribute('ABF', 'is-nesting-root', true)

          root = NestingRoot.new(root_group)

          assert_not_nil(root, "NestingRoot should be created")
          assert_not_nil(root.entity, "Entity should not be nil")
          assert(root.sheets.is_a?(Array), "Sheets should be an array")

          # Test finding in model
          found_root = NestingRoot.find_in_model(model)
          assert_not_nil(found_root, "Should find nesting root in model")

          root_group.erase!
          results.record_pass("NestingRoot model basic functionality")

        rescue => e
          results.record_fail("NestingRoot model basic functionality", e.message)
        end
      end

    end
  end
end
