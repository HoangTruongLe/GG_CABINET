# frozen_string_literal: true

# ===============================================================
# Tests for Label Model
# ===============================================================

require_relative '../test_helper'

module GG_Cabinet
  module ExtraNesting
    module TestHelper

      def self.test_label_model(results)
        puts "\nTesting Label Model..."

        begin
          model = Sketchup.active_model

          # Create test board with proper faces
          board_group = create_test_board(600, 400, 18)
          board = Board.new(board_group)

          # Test label creation
          test_label_creation(results, board)

          # Test label dimensions
          test_label_dimensions(results, board)

          # Test label attributes
          test_label_attributes(results, board)

          # Test label rotation
          test_label_rotation(results, board)

          # Test label scaling
          test_label_scaling(results, board)

          board_group.erase!
          results.record_pass("Label model comprehensive tests")

        rescue => e
          results.record_fail("Label model comprehensive tests", e.message)
        end
      end

      def self.test_label_creation(results, board)
        puts "  Testing label creation..."

        # Create label
        label = Label.new(board, 1)

        assert_not_nil(label, "Label should be created")
        assert_not_nil(label.entity, "Label entity should exist")
        assert_true(label.valid?, "Label should be valid")

        # Check label is child of board
        assert_equal(board, label.parent, "Label parent should be board")
        assert_equal(board, label.board, "Label board should be board")

        # Check label group exists in board entities
        label_group = board.entity.entities.grep(Sketchup::Group).find do |g|
          g.get_attribute('ABF', 'is-label') == true
        end
        assert_not_nil(label_group, "Label group should exist in board entities")

        results.record_pass("Label creation")
      end

      def self.test_label_dimensions(results, board)
        puts "  Testing label dimensions..."

        label = board.label
        return unless label

        # Test local dimensions
        dims = label.local_dimensions
        assert_not_nil(dims, "Local dimensions should be returned")
        assert_true(dims[:width] > 0, "Label width should be > 0")
        assert_true(dims[:height] > 0, "Label height should be > 0")

        # Test face space dimensions
        face_dims = label.label_dimensions_in_face_space
        assert_not_nil(face_dims, "Face space dimensions should be returned")
        assert_true(face_dims[:width] > 0, "Face space width should be > 0")
        assert_true(face_dims[:height] > 0, "Face space height should be > 0")
        assert_not_nil(face_dims[:width_direction], "Width direction should exist")
        assert_not_nil(face_dims[:height_direction], "Height direction should exist")

        # Ensure width < height in face space
        assert_true(face_dims[:width] < face_dims[:height], "Width should be less than height in face space")

        # Test dimension accessors
        width = label.width
        height = label.height
        assert_true(width > 0, "Label width accessor should return > 0")
        assert_true(height > 0, "Label height accessor should return > 0")

        # Test direction vectors
        width_dir = label.width_direction
        height_dir = label.height_direction
        assert_not_nil(width_dir, "Width direction vector should exist")
        assert_not_nil(height_dir, "Height direction vector should exist")

        # Direction vectors should be normalized
        assert_in_delta(1.0, width_dir.length, 0.01, "Width direction should be normalized")
        assert_in_delta(1.0, height_dir.length, 0.01, "Height direction should be normalized")

        # Test center
        center = label.center
        assert_not_nil(center, "Label center should exist")
        assert_instance_of(Geom::Point3d, center, "Center should be Point3d")

        # Test bounds
        bounds = label.bounds
        assert_not_nil(bounds, "Label bounds should exist")
        assert_instance_of(Geom::BoundingBox, bounds, "Bounds should be BoundingBox")

        results.record_pass("Label dimensions")
      end

      def self.test_label_attributes(results, board)
        puts "  Testing label attributes..."

        label = board.label
        return unless label

        entity = label.entity

        # Test core attributes
        assert_equal(true, entity.get_attribute('ABF', 'is-label'), "is-label should be true")
        assert_not_nil(entity.get_attribute('ABF', 'label-index'), "label-index should exist")
        assert_not_nil(entity.get_attribute('ABF', 'label-rotation'), "label-rotation should exist")

        # Test label index matches
        index = entity.get_attribute('ABF', 'label-index')
        assert_instance_of(Integer, index, "Label index should be integer")
        assert_true(index > 0, "Label index should be > 0")

        # Test rotation
        rotation = entity.get_attribute('ABF', 'label-rotation')
        assert_instance_of(Integer, rotation, "Label rotation should be integer")
        assert_true([0, 90, 180, 270].include?(rotation), "Label rotation should be 0, 90, 180, or 270")

        # Test scale attribute if scaled
        scale = entity.get_attribute('ABF', 'label-scale')
        if scale
          assert_instance_of(Float, scale, "Label scale should be float")
          assert_true(scale > 0 && scale <= 6.0, "Label scale should be between 0 and 6.0")
        end

        results.record_pass("Label attributes")
      end

      def self.test_label_rotation(results, board)
        puts "  Testing label rotation..."

        label = board.label
        return unless label

        # Test rotation accessor
        rotation = label.rotation
        assert_not_nil(rotation, "Label rotation should exist")
        assert_instance_of(Integer, rotation, "Rotation should be integer")

        # Rotation should match board's label rotation
        assert_equal(board.label_rotation, rotation, "Label rotation should match board rotation")

        # Test label is positioned on face
        label_center = label.center
        face_center = board.front_face.center

        # Label center should be close to face center
        distance = label_center.distance(face_center)
        assert_true(distance < 50.0, "Label center should be close to face center (within 50mm)")

        results.record_pass("Label rotation")
      end

      def self.test_label_scaling(results, board)
        puts "  Testing label scaling..."

        label = board.label
        return unless label

        face = board.front_face
        return unless face

        # Get label dimensions in face space
        dims = label.label_dimensions_in_face_space
        label_width = dims[:width]
        label_height = dims[:height]

        # Get face dimensions
        face_width = face.width
        face_height = face.height

        # Calculate margins
        margin_width = (face_width - label_width) / 2.0
        margin_height = (face_height - label_height) / 2.0

        # Margins should be at least 9mm (allowing 1mm tolerance from 10mm target)
        min_margin = [margin_width, margin_height].min
        assert_true(min_margin >= 9.0, "Minimum margin should be >= 9mm (got #{min_margin.round(2)}mm)")

        # Label should not be larger than face
        assert_true(label_width <= face_width, "Label width should not exceed face width")
        assert_true(label_height <= face_height, "Label height should not exceed face height")

        # If label was scaled, check scale attribute
        scale = label.entity.get_attribute('ABF', 'label-scale')
        if scale
          assert_true(scale > 0, "Scale should be > 0")
          assert_true(scale <= 6.0, "Scale should be <= 6.0 (max scale)")
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

      def self.assert_equal(expected, actual, message = nil)
        message ||= "Expected #{expected}, got #{actual}"
        raise message unless expected == actual
      end

      def self.assert_instance_of(klass, object, message = nil)
        message ||= "Expected instance of #{klass}, got #{object.class}"
        raise message unless object.is_a?(klass)
      end

      def self.assert_in_delta(expected, actual, delta, message = nil)
        message ||= "Expected #{expected} ± #{delta}, got #{actual}"
        diff = (expected - actual).abs
        raise message unless diff <= delta
      end

    end
  end
end
