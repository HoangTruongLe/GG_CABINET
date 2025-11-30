# frozen_string_literal: true

# ===============================================================
# Test Helper - Common utilities for all test files
# ===============================================================

require 'sketchup.rb'

# Ensure plugin is loaded
unless defined?(GG_Cabinet::ExtraNesting)
  puts "Error: GG_Cabinet::ExtraNesting not loaded"
  puts "Please install the plugin first"
  return
end

module GG_Cabinet
  module ExtraNesting
    module TestHelper

      # Test result tracking
      class TestResults
        attr_reader :tests_run, :tests_passed, :tests_failed, :failures

        def initialize
          @tests_run = 0
          @tests_passed = 0
          @tests_failed = 0
          @failures = []
        end

        def record_pass(test_name)
          @tests_run += 1
          @tests_passed += 1
          puts "  ✓ #{test_name}"
        end

        def record_fail(test_name, error)
          @tests_run += 1
          @tests_failed += 1
          @failures << { test: test_name, error: error }
          puts "  ✗ #{test_name}"
          puts "    Error: #{error}"
        end

        def print_summary
          puts "\n" + ("=" * 70)
          puts "TEST SUITE SUMMARY"
          puts ("=" * 70)
          puts "Total tests: #{@tests_run}"
          puts "Passed: #{@tests_passed} (#{(@tests_passed.to_f / @tests_run * 100).round(1)}%)" if @tests_run > 0
          puts "Failed: #{@tests_failed}"

          if @tests_failed > 0
            puts "\nFailures:"
            @failures.each_with_index do |failure, i|
              puts "  #{i + 1}. #{failure[:test]}"
              puts "     #{failure[:error]}"
            end
          end

          puts ("=" * 70)
        end

        def merge!(other_results)
          @tests_run += other_results.tests_run
          @tests_passed += other_results.tests_passed
          @tests_failed += other_results.tests_failed
          @failures.concat(other_results.failures)
        end
      end

      # Test assertion helpers
      def self.assert(condition, message = "Assertion failed")
        raise message unless condition
      end

      def self.assert_equal(expected, actual, message = nil)
        msg = message || "Expected #{expected.inspect}, got #{actual.inspect}"
        raise msg unless expected == actual
      end

      def self.assert_not_nil(value, message = "Value should not be nil")
        raise message if value.nil?
      end

      def self.assert_true(value, message = "Expected true")
        raise message unless value == true
      end

      def self.assert_false(value, message = "Expected false")
        raise message unless value == false
      end

      # Helper methods for creating test entities
      def self.create_test_board(width, height, thickness)
        model = Sketchup.active_model

        board_group = model.entities.add_group
        board_group.name = "TestBoard_#{width}x#{height}x#{thickness}"

        # Create front face
        points_front = [
          Geom::Point3d.new(0, 0, 0),
          Geom::Point3d.new(width.mm, 0, 0),
          Geom::Point3d.new(width.mm, height.mm, 0),
          Geom::Point3d.new(0, height.mm, 0)
        ]
        board_group.entities.add_face(points_front)

        # Create back face
        points_back = points_front.map { |p| Geom::Point3d.new(p.x, p.y, -thickness.mm) }
        board_group.entities.add_face(points_back).reverse!

        board_group
      end

      def self.create_test_board_with_intersections(width, height, thickness, front_count, back_count)
        board_group = create_test_board(width, height, thickness)

        # Add intersection groups on front face (z=0)
        front_count.times do |i|
          int_group = board_group.entities.add_group
          int_group.name = "Intersection_Front_#{i + 1}"
          int_group.layer = find_or_create_layer('ABF_groove')

          # Add simple edge
          pt1 = Geom::Point3d.new((i + 1) * 50.mm, 50.mm, 0)
          pt2 = Geom::Point3d.new((i + 1) * 50.mm, 100.mm, 0)
          int_group.entities.add_line(pt1, pt2)
        end

        # Add intersection groups on back face (z=-thickness)
        back_count.times do |i|
          int_group = board_group.entities.add_group
          int_group.name = "Intersection_Back_#{i + 1}"
          int_group.layer = find_or_create_layer('ABF_groove')

          # Add simple edge
          pt1 = Geom::Point3d.new((i + 1) * 50.mm, 50.mm, -thickness.mm)
          pt2 = Geom::Point3d.new((i + 1) * 50.mm, 100.mm, -thickness.mm)
          int_group.entities.add_line(pt1, pt2)
        end

        board_group
      end

      def self.find_or_create_layer(layer_name)
        model = Sketchup.active_model
        layer = model.layers[layer_name]

        unless layer
          layer = model.layers.add(layer_name)
        end

        layer
      end

    end
  end
end
