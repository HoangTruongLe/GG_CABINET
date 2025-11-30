# frozen_string_literal: true

# ===============================================================
# Integration Tests for Labeling Workflow
# ===============================================================

require_relative '../test_helper'

module GG_Cabinet
  module ExtraNesting
    module TestHelper

      def self.test_labeling_workflow(results)
        puts "\nTesting Complete Labeling Workflow..."

        begin
          model = Sketchup.active_model

          # Test 1: Single board labeling
          test_single_board_labeling(results, model)

          # Test 2: Multiple board labeling
          test_multiple_board_labeling(results, model)

          # Test 3: Re-labeling
          test_relabeling(results, model)

          # Test 4: Front face detection
          test_front_face_detection(results, model)

          # Test 5: Label visibility and positioning
          test_label_visibility_and_positioning(results, model)

          # Test 6: Label scaling
          test_label_scaling(results, model)

          results.record_pass("Complete labeling workflow")

        rescue => e
          results.record_fail("Complete labeling workflow", e.message)
        end
      end

      def self.test_single_board_labeling(results, model)
        puts "  Testing single board labeling..."

        # Create test board
        board_group = create_test_board(600, 400, 18)
        board_group.name = "TestBoard_Single"

        # Select board
        model.selection.clear
        model.selection.add(board_group)

        # Label board
        LabelTool.label_selected_boards

        # Verify board attributes
        assert_equal(true, board_group.get_attribute('ABF', 'is-board'), "is-board should be true")
        assert_equal(true, board_group.get_attribute('ABF', 'is-extra-board'), "is-extra-board should be true")
        assert_not_nil(board_group.get_attribute('ABF', 'board-index'), "board-index should exist")
        assert_not_nil(board_group.get_attribute('ABF', 'labeled-at'), "labeled-at should exist")
        assert_not_nil(board_group.get_attribute('ABF', 'classification-key'), "classification-key should exist")
        assert_not_nil(board_group.get_attribute('ABF', 'material-name'), "material-name should exist")
        assert_not_nil(board_group.get_attribute('ABF', 'thickness'), "thickness should exist")
        assert_not_nil(board_group.get_attribute('ABF', 'label-rotation'), "label-rotation should exist")

        # Verify front face marked
        board = Board.new(board_group)
        if board.front_face && board.front_face.entity
          assert_equal(true, board.front_face.entity.get_attribute('ABF', 'is-labeled-face'),
                       "Front face should be marked")
        end

        # Verify visual label exists
        label_group = board_group.entities.grep(Sketchup::Group).find do |g|
          g.get_attribute('ABF', 'is-label') == true
        end
        assert_not_nil(label_group, "Visual label should exist")

        # Verify label attributes
        if label_group
          assert_not_nil(label_group.get_attribute('ABF', 'label-index'), "Label should have index")
          assert_not_nil(label_group.get_attribute('ABF', 'label-rotation'), "Label should have rotation")
        end

        board_group.erase!
        results.record_pass("Single board labeling")
      end

      def self.test_multiple_board_labeling(results, model)
        puts "  Testing multiple board labeling..."

        # Create 3 test boards
        boards = []
        3.times do |i|
          board_group = create_test_board(600, 400, 18)
          board_group.name = "TestBoard_#{i + 1}"
          boards << board_group
        end

        # Select all boards
        model.selection.clear
        boards.each { |b| model.selection.add(b) }

        # Get starting index
        starting_index = LabelTool.find_next_index

        # Label boards
        LabelTool.label_selected_boards

        # Verify all boards are labeled with sequential indices
        boards.each_with_index do |board_group, i|
          assert_equal(true, board_group.get_attribute('ABF', 'is-extra-board'),
                       "Board #{i + 1} should be labeled")

          index = board_group.get_attribute('ABF', 'board-index')
          expected_index = starting_index + i
          assert_equal(expected_index, index,
                       "Board #{i + 1} should have index #{expected_index}")
        end

        # Clean up
        boards.each(&:erase!)
        results.record_pass("Multiple board labeling")
      end

      def self.test_relabeling(results, model)
        puts "  Testing re-labeling..."

        # Create and label board
        board_group = create_test_board(600, 400, 18)
        board_group.name = "TestBoard_Relabel"

        model.selection.clear
        model.selection.add(board_group)

        # First labeling
        LabelTool.label_selected_boards
        first_index = board_group.get_attribute('ABF', 'board-index')
        first_labeled_at = board_group.get_attribute('ABF', 'labeled-at')

        # Wait a moment
        sleep(0.1)

        # Re-label
        LabelTool.label_selected_boards
        second_index = board_group.get_attribute('ABF', 'board-index')
        second_labeled_at = board_group.get_attribute('ABF', 'labeled-at')

        # Index should be updated
        assert_not_equal(first_index, second_index, "Index should be updated on re-label")

        # Timestamp should be updated
        assert_not_equal(first_labeled_at, second_labeled_at, "Timestamp should be updated on re-label")

        # Still marked as extra board
        assert_equal(true, board_group.get_attribute('ABF', 'is-extra-board'),
                     "Should still be marked as extra board")

        # Visual label should still exist
        board = Board.new(board_group)
        label = board.label
        assert_not_nil(label, "Visual label should still exist after re-labeling")

        board_group.erase!
        results.record_pass("Re-labeling")
      end

      def self.test_front_face_detection(results, model)
        puts "  Testing front face detection..."

        # Create board
        board_group = create_test_board(600, 400, 18)
        board = Board.new(board_group)

        # Should detect front face
        assert_not_nil(board.front_face, "Front face should be detected")
        assert_not_nil(board.back_face, "Back face should be detected")

        # Front and back should be different
        assert_not_equal(board.front_face, board.back_face,
                         "Front and back faces should be different")

        # Front face should have width and height
        assert_true(board.front_face.width > 0, "Front face width should be > 0")
        assert_true(board.front_face.height > 0, "Front face height should be > 0")

        # Create board with intersections
        board_group_with_int = create_test_board_with_intersections(600, 400, 18, 3, 1)
        board_with_int = Board.new(board_group_with_int)

        # Front should have more intersections
        front_count = board_with_int.front_intersections.count
        back_count = board_with_int.back_intersections.count

        assert_true(front_count >= back_count,
                    "Front face should have >= intersections (front: #{front_count}, back: #{back_count})")

        board_group.erase!
        board_group_with_int.erase!
        results.record_pass("Front face detection")
      end

      def self.test_label_visibility_and_positioning(results, model)
        puts "  Testing label visibility and positioning..."

        # Create and label board
        board_group = create_test_board(600, 400, 18)
        board_group.name = "TestBoard_Visibility"

        model.selection.clear
        model.selection.add(board_group)
        LabelTool.label_selected_boards

        board = Board.new(board_group)
        label = board.label

        assert_not_nil(label, "Label should exist")

        # Label should be visible
        assert_false(label.entity.hidden?, "Label should be visible")

        # Label should have valid bounds
        bounds = label.bounds
        assert_not_nil(bounds, "Label should have bounds")

        # Label should be positioned near face center
        label_center = label.center
        face_center = board.front_face.center

        distance = label_center.distance(face_center)
        assert_true(distance < 100.0,
                    "Label center should be near face center (distance: #{distance.round(2)}mm)")

        # Label should have width and height
        assert_true(label.width > 0, "Label width should be > 0")
        assert_true(label.height > 0, "Label height should be > 0")

        # Label should have direction vectors
        assert_not_nil(label.width_direction, "Width direction should exist")
        assert_not_nil(label.height_direction, "Height direction should exist")

        board_group.erase!
        results.record_pass("Label visibility and positioning")
      end

      def self.test_label_scaling(results, model)
        puts "  Testing label scaling..."

        # Create boards of different sizes
        sizes = [
          [200, 300, 18],   # Small board
          [600, 800, 18],   # Medium board
          [1200, 1800, 18]  # Large board
        ]

        sizes.each_with_index do |(width, height, thickness), i|
          board_group = create_test_board(width, height, thickness)
          board_group.name = "TestBoard_Scale_#{i + 1}"

          model.selection.clear
          model.selection.add(board_group)
          LabelTool.label_selected_boards

          board = Board.new(board_group)
          label = board.label
          next unless label

          # Get label dimensions in face space
          dims = label.label_dimensions_in_face_space
          label_width = dims[:width]
          label_height = dims[:height]

          # Get face dimensions
          face_width = board.front_face.width
          face_height = board.front_face.height

          # Calculate margins
          margin_width = (face_width - label_width) / 2.0
          margin_height = (face_height - label_height) / 2.0
          min_margin = [margin_width, margin_height].min

          # Margins should be at least 9mm (allowing 1mm tolerance)
          assert_true(min_margin >= 9.0,
                      "Board #{i + 1} (#{width}x#{height}): min margin should be >= 9mm (got #{min_margin.round(2)}mm)")

          # Label should not exceed face dimensions
          assert_true(label_width <= face_width,
                      "Board #{i + 1}: label width should not exceed face width")
          assert_true(label_height <= face_height,
                      "Board #{i + 1}: label height should not exceed face height")

          # Check scale factor
          scale = label.entity.get_attribute('ABF', 'label-scale')
          if scale
            assert_true(scale > 0 && scale <= 6.0,
                        "Board #{i + 1}: scale should be between 0 and 6.0 (got #{scale})")
          end

          board_group.erase!
        end

        results.record_pass("Label scaling")
      end

      # Helper assertion methods
      def self.assert_not_nil(value, message = "Value should not be nil")
        raise message if value.nil?
      end

      def self.assert_true(condition, message = "Condition should be true")
        raise message unless condition
      end

      def self.assert_false(condition, message = "Condition should be false")
        raise message if condition
      end

      def self.assert_equal(expected, actual, message = nil)
        message ||= "Expected #{expected}, got #{actual}"
        raise message unless expected == actual
      end

      def self.assert_not_equal(expected, actual, message = nil)
        message ||= "Expected not #{expected}, got #{actual}"
        raise message if expected == actual
      end

      def self.create_test_board_with_intersections(width, height, thickness, front_holes, back_holes)
        # Create basic board
        board_group = create_test_board(width, height, thickness)

        # Add intersections to front face (first large face)
        faces = board_group.entities.grep(Sketchup::Face)
        large_faces = faces.select { |f| f.area > 100.0.mm * 100.0.mm }

        if large_faces.length >= 2
          front_face = large_faces[0]
          back_face = large_faces[1]

          # Add holes to front face
          front_holes.times do |i|
            center_x = (width / 2.0 - 50 + i * 30).mm
            center_y = (height / 2.0).mm
            center_z = front_face.plane[3]

            circle_center = Geom::Point3d.new(center_x, center_y, center_z)
            circle = board_group.entities.add_circle(circle_center, front_face.normal, 10.mm)
            circle_face = board_group.entities.add_face(circle)
            circle_face.reverse! if circle_face.normal.dot(front_face.normal) < 0
            circle_face.pushpull(-thickness.mm / 2.0, false)
          end

          # Add holes to back face
          back_holes.times do |i|
            center_x = (width / 2.0 + 50 + i * 30).mm
            center_y = (height / 2.0).mm
            center_z = back_face.plane[3]

            circle_center = Geom::Point3d.new(center_x, center_y, center_z)
            circle = board_group.entities.add_circle(circle_center, back_face.normal, 10.mm)
            circle_face = board_group.entities.add_face(circle)
            circle_face.reverse! if circle_face.normal.dot(back_face.normal) < 0
            circle_face.pushpull(-thickness.mm / 2.0, false)
          end
        end

        board_group
      end

    end
  end
end
