# frozen_string_literal: true

# ===============================================================
# Tests for TwoDGroup Model
# ===============================================================

require_relative '../test_helper'

module GG_Cabinet
  module ExtraNesting
    module TestHelper

      def self.test_two_d_group_model(results)
        puts "\nTesting TwoDGroup Model..."

        begin
          model = Sketchup.active_model

          group = model.entities.add_group
          group.name = "Test2DGroup"

          two_d = TwoDGroup.new(group)

          # Test outline
          outline = [[0, 0], [600, 0], [600, 400], [0, 400]]
          two_d.set_outline(outline)

          assert_equal(600.0, two_d.width)
          assert_equal(400.0, two_d.height)
          assert_equal(240000.0, two_d.area)

          # Test bounds
          bounds = two_d.bounds_2d
          assert_equal(0.0, bounds[:min_x])
          assert_equal(600.0, bounds[:max_x])
          assert_equal(0.0, bounds[:min_y])
          assert_equal(400.0, bounds[:max_y])

          # Test placement
          two_d.place_at(100, 200, 0)
          assert_true(two_d.positioned?)
          pos = two_d.nesting_position
          assert_equal(100, pos[:x])
          assert_equal(200, pos[:y])
          assert_equal(0, pos[:rotation])

          # Test point containment
          assert_true(two_d.contains_point?(300, 200))
          assert_false(two_d.contains_point?(700, 200))

          group.erase!
          results.record_pass("TwoDGroup model basic functionality")

        rescue => e
          results.record_fail("TwoDGroup model basic functionality", e.message)
        end
      end

    end
  end
end
