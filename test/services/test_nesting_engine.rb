# frozen_string_literal: true

# ===============================================================
# Tests for NestingEngine Service
# ===============================================================

require_relative '../test_helper'

module GG_Cabinet
  module ExtraNesting
    module TestHelper

      def self.test_nesting_engine(results)
        puts "\nTesting NestingEngine..."

        begin
          model = Sketchup.active_model

          # Create test nesting root
          root_group = model.entities.add_group
          root_group.name = "TestNestingRoot"
          root_group.set_attribute('ABF', 'is-nesting-root', true)
          root = NestingRoot.new(root_group)

          # Create engine
          engine = NestingEngine.new(root)

          assert_not_nil(engine, "Engine should be created")
          assert_true(engine.allow_rotation, "Rotation should be enabled by default")
          assert_true(engine.create_new_sheets, "Sheet creation should be enabled")

          root_group.erase!
          results.record_pass("NestingEngine initialization")

        rescue => e
          results.record_fail("NestingEngine initialization", e.message)
        end
      end

    end
  end
end
