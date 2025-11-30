# frozen_string_literal: true

# ===============================================================
# Tests for Face Model
# ===============================================================

require_relative '../test_helper'

module GG_Cabinet
  module ExtraNesting
    module TestHelper

      def self.test_face_model(results)
        puts "\nTesting Face Model..."

        begin
          model = Sketchup.active_model

          board_group = create_test_board(600, 400, 18)
          board = Board.new(board_group)

          face = board.front_face

          # Test properties
          assert_not_nil(face, "Face should exist")
          assert(face.area > 0, "Area should be positive")
          assert_not_nil(face.normal, "Normal should exist")

          # Test comparison
          if board.back_face
            assert_true(face.parallel_to?(board.back_face), "Front and back should be parallel")
            assert_true(face.congruent_to?(board.back_face), "Front and back should be congruent")
          end

          # Test validation
          assert_true(face.valid?, "Face should be valid")

          board_group.erase!
          results.record_pass("Face model basic functionality")

        rescue => e
          results.record_fail("Face model basic functionality", e.message)
        end
      end

    end
  end
end
