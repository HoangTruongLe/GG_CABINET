# frozen_string_literal: true

# ===============================================================
# Integration Tests for Labeling Workflow
# ===============================================================

require_relative '../test_helper'

module GG_Cabinet
  module ExtraNesting
    module TestHelper

      def self.test_labeling_workflow(results)
        puts "\nTesting Labeling Workflow..."

        begin
          model = Sketchup.active_model

          # Create test board
          board_group = create_test_board(600, 400, 18)
          board_group.name = "TestBoard_Label"

          # Select board
          model.selection.clear
          model.selection.add(board_group)

          # Label board
          LabelTool.label_selected_boards

          # Verify attributes
          assert_equal(true, board_group.get_attribute('ABF', 'is-board'))
          assert_equal(true, board_group.get_attribute('ABF', 'is-extra-board'))
          assert_not_nil(board_group.get_attribute('ABF', 'board-index'))
          assert_not_nil(board_group.get_attribute('ABF', 'labeled-at'))
          assert_not_nil(board_group.get_attribute('ABF', 'classification-key'))

          # Verify front face marked
          board = Board.new(board_group)
          if board.front_face && board.front_face.entity
            assert_equal(true, board.front_face.entity.get_attribute('ABF', 'is-labeled-face'))
          end

          board_group.erase!
          results.record_pass("Complete labeling workflow")

        rescue => e
          results.record_fail("Complete labeling workflow", e.message)
        end
      end

      def self.test_front_face_detection(results)
        puts "\nTesting Front Face Detection..."

        begin
          model = Sketchup.active_model

          # Create board with intersections
          board_group = create_test_board_with_intersections(600, 400, 18, 3, 1)
          board = Board.new(board_group)

          # Should detect front face (the one with more intersections)
          assert_not_nil(board.front_face, "Front face should be detected")

          front_intersections = board.front_intersections.count
          back_intersections = board.back_intersections.count

          # Front should have more or equal intersections
          assert(front_intersections >= back_intersections,
                 "Front face should have >= intersections than back")

          board_group.erase!
          results.record_pass("Front face detection by intersections")

        rescue => e
          results.record_fail("Front face detection by intersections", e.message)
        end
      end

    end
  end
end
