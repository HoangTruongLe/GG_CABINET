# frozen_string_literal: true

# ===============================================================
# Tests for EdgeBandingDrawer Service
# ===============================================================

require_relative '../test_helper'

module GG_Cabinet
  module ExtraNesting
    module TestHelper

      def self.test_edge_banding_drawer_geometry(results)
        puts "\nTesting EdgeBandingDrawer Geometry Calculations..."

        begin
          drawer = EdgeBandingDrawer.new

          # Test perpendicular calculation
          edge_vector = [100, 0]  # Horizontal edge
          edge_mid = [50, 50]
          board_center = [50, 100]  # Center is above edge

          perp = drawer.send(:calculate_inward_perpendicular, edge_vector, edge_mid, board_center)
          assert_not_nil(perp, "Perpendicular should be calculated")

          # Test vector normalization
          vector = [3, 4]  # Length = 5
          normalized = drawer.send(:normalize_vector, vector)
          length = Math.sqrt(normalized[0]**2 + normalized[1]**2)

          assert((length - 1.0).abs < 0.001, "Vector should be normalized to length 1")

          results.record_pass("EdgeBandingDrawer geometry calculations")

        rescue => e
          results.record_fail("EdgeBandingDrawer geometry calculations", e.message)
        end
      end

      def self.test_edge_banding_drawer_triangle_scaling(results)
        puts "\nTesting EdgeBandingDrawer Triangle Scaling..."

        begin
          drawer = EdgeBandingDrawer.new

          test_edges = [100, 60, 50, 40, 30, 20]

          test_edges.each do |edge_length|
            scale = drawer.send(:calculate_triangle_scale, edge_length)
            assert(scale > 0, "Scale should be positive for edge length #{edge_length}")

            base = EdgeBandingDrawer::TRIANGLE_BASE * scale
            height = EdgeBandingDrawer::TRIANGLE_HEIGHT * scale

            assert(base > 0, "Triangle base should be positive")
            assert(height > 0, "Triangle height should be positive")
          end

          results.record_pass("EdgeBandingDrawer triangle scaling")

        rescue => e
          results.record_fail("EdgeBandingDrawer triangle scaling", e.message)
        end
      end

      def self.test_edge_banding_drawer_class_methods(results)
        puts "\nTesting EdgeBandingDrawer Class Methods..."

        begin
          # Test with fake board object
          class FakeBoard
            attr_accessor :entity

            def initialize
              @entity = FakeEntity.new
            end
          end

          class FakeEntity
            def get_attribute(dict, key)
              if key == 'edge-band-types'
                [0, "CHỈ", 1.0, "#b36ea9", 0, 1, "Dán Tay 01", 0.1, "#c46b6b", 0]
              else
                nil
              end
            end
          end

          fake_board = FakeBoard.new
          edge_bandings = EdgeBandingDrawer.get_edge_bandings(fake_board)

          assert(edge_bandings.is_a?(Hash), "get_edge_bandings should return hash")
          assert(edge_bandings.count > 0, "Should find edge bandings")

          has_eb = EdgeBandingDrawer.has_edge_banding?(fake_board)
          assert(has_eb == true || has_eb == false, "has_edge_banding? should return boolean")

          results.record_pass("EdgeBandingDrawer class methods")

        rescue => e
          results.record_fail("EdgeBandingDrawer class methods", e.message)
        end
      end

      def self.test_edge_banding_drawer_triangle_vertices(results)
        puts "\nTesting EdgeBandingDrawer Triangle Vertices Calculation..."

        begin
          drawer = EdgeBandingDrawer.new

          base_center = [100, 100]
          edge_vector = [100, 0]  # Horizontal edge
          perp = [0, 1]  # Pointing up
          base_width = 40
          height = 56

          vertices = drawer.send(:calculate_triangle_vertices, base_center, edge_vector, perp, base_width, height)

          assert(vertices.is_a?(Array), "Vertices should be an array")
          assert_equal(3, vertices.count, "Should have 3 vertices")

          # Verify isosceles triangle
          side1 = Math.sqrt((vertices[2][0] - vertices[0][0])**2 + (vertices[2][1] - vertices[0][1])**2)
          side2 = Math.sqrt((vertices[2][0] - vertices[1][0])**2 + (vertices[2][1] - vertices[1][1])**2)

          assert((side1 - side2).abs < 0.1, "Triangle should be isosceles")

          results.record_pass("EdgeBandingDrawer triangle vertices calculation")

        rescue => e
          results.record_fail("EdgeBandingDrawer triangle vertices calculation", e.message)
        end
      end

    end
  end
end
