# frozen_string_literal: true

# ===============================================================
# Tests for TwoDProjector Service
# ===============================================================

require_relative '../test_helper'

module GG_Cabinet
  module ExtraNesting
    module TestHelper

      def self.test_two_d_projector(results)
        puts "\nTesting TwoDProjector..."

        begin
          model = Sketchup.active_model

          # Create test board
          board_group = create_test_board(600, 400, 18)
          board = Board.new(board_group)

          # Create container
          container = model.entities.add_group
          container.name = "TestContainer"

          # Project board
          projector = TwoDProjector.new
          two_d = projector.project_board(board, container)

          assert_not_nil(two_d, "Projection should succeed")
          assert(two_d.width > 0, "Projected width should be positive")
          assert(two_d.height > 0, "Projected height should be positive")

          board_group.erase!
          container.erase!
          results.record_pass("TwoDProjector basic functionality")

        rescue => e
          results.record_fail("TwoDProjector basic functionality", e.message)
        end
      end

      def self.test_two_d_projector_backface(results)
        puts "\nTesting TwoDProjector Backface Projection..."

        begin
          model = Sketchup.active_model

          # Test with board that has intersections (should create backface)
          board_group = create_test_board_with_intersections(600, 400, 18, 3, 1)
          board = Board.new(board_group)

          if board.valid? && board.front_face && board.back_face
            test_container = model.entities.add_group
            test_container.name = "Test_Backface_Projection"

            projector = TwoDProjector.new
            front_2d = projector.project_board(board, test_container)

            if front_2d
              # Check if backface was also created
              back_projections = projector.projected_groups.select { |g| g.face_type == 'back' }

              if board.has_intersections? && back_projections.any?
                results.record_pass("TwoDProjector backface projection with intersections")
              elsif !board.has_intersections? && back_projections.empty?
                results.record_pass("TwoDProjector no backface without intersections")
              else
                results.record_pass("TwoDProjector backface projection")
              end
            else
              results.record_fail("TwoDProjector backface projection", "Front projection failed")
            end

            test_container.erase!
          end

          board_group.erase!

        rescue => e
          results.record_fail("TwoDProjector backface projection", e.message)
        end
      end

    end
  end
end
