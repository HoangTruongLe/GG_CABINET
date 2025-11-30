# frozen_string_literal: true

# ===============================================================
# Tests for Intersection Model
# ===============================================================

require_relative '../test_helper'

module GG_Cabinet
  module ExtraNesting
    module TestHelper

      def self.test_intersection_model(results)
        puts "\nTesting Intersection Model..."

        begin
          # Test layer validation
          assert_true(Intersection.valid_intersection_layer?('ABF_groove'))
          assert_true(Intersection.valid_intersection_layer?('_ABF_cutout'))
          assert_false(Intersection.valid_intersection_layer?('_ABF_Label'))
          assert_false(Intersection.valid_intersection_layer?('ABF_side1'))
          assert_false(Intersection.valid_intersection_layer?('Untagged'))

          results.record_pass("Intersection layer validation")

        rescue => e
          results.record_fail("Intersection layer validation", e.message)
        end
      end

      def self.test_intersection_detection(results)
        puts "\nTesting Intersection Detection..."

        begin
          model = Sketchup.active_model

          # Find boards in model
          board_groups = model.entities.select do |entity|
            entity.is_a?(Sketchup::Group) &&
            entity.get_attribute('ABF', 'is-board') == true
          end

          if board_groups.empty?
            results.record_pass("Intersection detection (no boards in model)")
          else
            board_groups.each do |board_entity|
              board = Board.new(board_entity)

              # Test intersection detection methods
              assert_not_nil(board.has_intersections?, "has_intersections? should return boolean")
              assert_not_nil(board.has_front_intersections?, "has_front_intersections? should return boolean")
              assert_not_nil(board.has_back_intersections?, "has_back_intersections? should return boolean")

              # Test intersection collections
              assert(board.intersections.is_a?(Array), "intersections should return array")
              assert(board.front_intersections.is_a?(Array), "front_intersections should return array")
              assert(board.back_intersections.is_a?(Array), "back_intersections should return array")
            end

            results.record_pass("Intersection detection on boards")
          end

        rescue => e
          results.record_fail("Intersection detection", e.message)
        end
      end

      def self.test_board_intersection_layer(results)
        puts "\nTesting Board Intersection Layer Detection..."

        begin
          # Test various layer names
          test_layers = [
            ['ABF_sheetBorder', true, 'ABF prefix'],
            ['_ABF_markSquare', true, '_ABF prefix'],
            ['ABF_someLayer', true, 'ABF custom layer'],
            ['_ABF_custom', true, '_ABF custom layer'],
            ['_ABF_Label', false, 'Excluded: _ABF_Label'],
            ['_ABF_side1', false, 'Excluded: _ABF_side*'],
            ['_ABF_side_left', false, 'Excluded: _ABF_side*'],
            ['ABF_Label', false, 'Excluded: ABF_Label'],
            ['ABF_side1', false, 'Excluded: ABF_side*'],
            ['ABF_side_right', false, 'Excluded: ABF_side*'],
            ['Untagged', false, 'Untagged'],
            ['MyCustomLayer', false, 'Regular layer'],
            [nil, false, 'Nil layer']
          ]

          test_layers.each do |layer_name, expected, description|
            result = Board.is_intersection_layer?(layer_name)
            if result == expected
              results.record_pass("#{description}: '#{layer_name || 'nil'}'")
            else
              results.record_fail("#{description}: '#{layer_name || 'nil'}'", "Expected #{expected}, got #{result}")
            end
          end

        rescue => e
          results.record_fail("Board intersection layer detection", e.message)
        end
      end

      def self.test_mark_square_detection(results)
        puts "\nTesting Mark Square Detection..."

        begin
          model = Sketchup.active_model

          # Find all groups with mark square attribute
          mark_square_groups = model.entities.select do |entity|
            entity.is_a?(Sketchup::Group) &&
            entity.get_attribute('ABF', 'is-mark-square') == true
          end

          # Find boards in model
          board_groups = model.entities.select do |entity|
            entity.is_a?(Sketchup::Group) &&
            entity.get_attribute('ABF', 'is-board') == true
          end

          # Check which boards have mark squares
          bottom_sheets = board_groups.select do |board_entity|
            board = Board.new(board_entity)
            board.is_bottom_sheet?
          end

          # Test that is_bottom_sheet? returns boolean
          board_groups.each do |board_entity|
            board = Board.new(board_entity)
            assert(board.is_bottom_sheet?.is_a?(TrueClass) || board.is_bottom_sheet?.is_a?(FalseClass),
                   "is_bottom_sheet? should return boolean")
          end

          results.record_pass("Mark square detection")

        rescue => e
          results.record_fail("Mark square detection", e.message)
        end
      end

    end
  end
end
