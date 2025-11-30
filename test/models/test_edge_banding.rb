# frozen_string_literal: true

# ===============================================================
# Tests for EdgeBanding Model
# ===============================================================

require_relative '../test_helper'

module GG_Cabinet
  module ExtraNesting
    module TestHelper

      def self.test_edge_banding_parse_array(results)
        puts "\nTesting EdgeBanding.parse_array..."

        begin
          # Example attribute array from board
          test_array = [0, "CHỈ", 1.0, "#b36ea9", 0, 1, "Dán Tay 01", 0.1, "#c46b6b", 0]

          edge_bandings = EdgeBanding.parse_array(test_array)

          assert(edge_bandings.count >= 2, "Should parse at least 2 edge banding types")

          # Check first edge banding
          eb1 = edge_bandings[0]
          assert_not_nil(eb1, "First edge banding should exist")
          assert_equal("CHỈ", eb1.name)
          assert_equal(1.0, eb1.thickness)
          assert_equal("#b36ea9", eb1.color)

          # Check second edge banding
          eb2 = edge_bandings[1]
          assert_not_nil(eb2, "Second edge banding should exist")
          assert_equal("Dán Tay 01", eb2.name)
          assert_equal(0.1, eb2.thickness)

          results.record_pass("EdgeBanding.parse_array")

        rescue => e
          results.record_fail("EdgeBanding.parse_array", e.message)
        end
      end

      def self.test_edge_banding_model(results)
        puts "\nTesting EdgeBanding Model..."

        begin
          eb1 = EdgeBanding.new(0, "CHỈ", 1.0, "#b36ea9")
          eb2 = EdgeBanding.new(1, "Dán Tay 01", 0.1, "#c46b6b")

          assert_equal(0, eb1.id)
          assert_equal("CHỈ", eb1.name)
          assert_equal(1.0, eb1.thickness)
          assert_equal("#b36ea9", eb1.color)

          assert_equal(1, eb2.id)
          assert_equal("Dán Tay 01", eb2.name)

          # Test color conversion
          color1 = eb1.sketchup_color
          assert_not_nil(color1, "Color should be converted to SketchUp::Color")

          # Test serialization
          hash = eb1.to_hash
          assert_not_nil(hash[:id])
          assert_equal("CHỈ", hash[:name])

          results.record_pass("EdgeBanding model basic functionality")

        rescue => e
          results.record_fail("EdgeBanding model basic functionality", e.message)
        end
      end

      def self.test_edge_banding_edge_cases(results)
        puts "\nTesting EdgeBanding Edge Cases..."

        begin
          empty_array = []
          nil_array = nil
          short_array = [0, "Test", 1.0]

          assert_equal(0, EdgeBanding.parse_array(empty_array).count)
          assert_equal(0, EdgeBanding.parse_array(nil_array).count)
          assert_equal(0, EdgeBanding.parse_array(short_array).count)

          results.record_pass("EdgeBanding edge cases")

        rescue => e
          results.record_fail("EdgeBanding edge cases", e.message)
        end
      end

      def self.test_edge_banding_multiple(results)
        puts "\nTesting EdgeBanding Multiple Types..."

        begin
          # Simulate 3 edge banding types
          multi_array = [
            0, "Type 1", 1.0, "#ff0000", 0,
            1, "Type 2", 0.5, "#00ff00", 0,
            2, "Type 3", 1.5, "#0000ff", 0
          ]

          multi_ebs = EdgeBanding.parse_array(multi_array)
          assert_equal(3, multi_ebs.count, "Should parse 3 edge banding types")

          assert_equal("Type 1", multi_ebs[0].name)
          assert_equal("Type 2", multi_ebs[1].name)
          assert_equal("Type 3", multi_ebs[2].name)

          results.record_pass("EdgeBanding multiple types")

        rescue => e
          results.record_fail("EdgeBanding multiple types", e.message)
        end
      end

      def self.test_edge_banding_from_board(results)
        puts "\nTesting EdgeBanding from Board..."

        begin
          model = Sketchup.active_model

          # Try to find a board in the model
          board_groups = model.entities.select do |entity|
            entity.is_a?(Sketchup::Group) &&
            entity.get_attribute('ABF', 'is-board') == true
          end

          if board_groups.empty?
            results.record_pass("EdgeBanding from board (no boards in model)")
          else
            board_entity = board_groups.first
            board = Board.new(board_entity)

            # Parse edge banding
            attr = board_entity.get_attribute('ABF', 'edge-band-types')

            if attr
              edge_bandings = EdgeBanding.parse_array(attr)
              assert(edge_bandings.is_a?(Hash), "Should return hash of edge bandings")
              results.record_pass("EdgeBanding from board")
            else
              results.record_pass("EdgeBanding from board (no edge banding attribute)")
            end
          end

        rescue => e
          results.record_fail("EdgeBanding from board", e.message)
        end
      end

      def self.test_edge_banding_serialization(results)
        puts "\nTesting EdgeBanding Serialization..."

        begin
          eb = EdgeBanding.new(0, "CHỈ", 1.0, "#b36ea9")
          hash = eb.to_hash

          assert_not_nil(hash, "to_hash should return hash")
          assert_equal(0, hash[:id])
          assert_equal("CHỈ", hash[:name])
          assert_equal(1.0, hash[:thickness])
          assert_equal("#b36ea9", hash[:color])

          results.record_pass("EdgeBanding serialization")

        rescue => e
          results.record_fail("EdgeBanding serialization", e.message)
        end
      end

    end
  end
end
