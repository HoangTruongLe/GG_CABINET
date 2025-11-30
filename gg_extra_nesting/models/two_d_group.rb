# frozen_string_literal: true

module GG_Cabinet
  module ExtraNesting

    # TwoDGroup - 2D projection of a 3D board
    # Represents a board projected onto the XY plane for nesting
    # Phase 3: Complete implementation
    class TwoDGroup < PersistentEntity
      attr_reader :source_board, :outline_points, :label_group
      attr_accessor :nesting_position, :nesting_rotation, :face_type

      def initialize(sketchup_group, source_board = nil)
        super(sketchup_group)

        @source_board = source_board
        @outline_points = []
        @label_group = nil
        @nesting_position = nil  # [x, y] position in nesting
        @nesting_rotation = 0    # Rotation angle in degrees
        @face_type = 'front'     # 'front' or 'back'
      end

      # =================================================================
      # Outline Management
      # =================================================================

      # Set outline points (2D vertices)
      def set_outline(points)
        @outline_points = points.map { |pt| [pt[0], pt[1]] }
      end

      # Get outline as array of 2D points
      def outline
        @outline_points
      end

      # Get bounding box in 2D
      def bounds_2d
        return nil if @outline_points.empty?

        xs = @outline_points.map { |pt| pt[0] }
        ys = @outline_points.map { |pt| pt[1] }

        {
          min_x: xs.min,
          max_x: xs.max,
          min_y: ys.min,
          max_y: ys.max
        }
      end

      # Get width in 2D
      def width
        bounds = bounds_2d
        return 0 unless bounds
        bounds[:max_x] - bounds[:min_x]
      end

      # Get height in 2D
      def height
        bounds = bounds_2d
        return 0 unless bounds
        bounds[:max_y] - bounds[:min_y]
      end

      # Get center point in 2D
      def center_2d
        bounds = bounds_2d
        return [0, 0] unless bounds

        [
          (bounds[:min_x] + bounds[:max_x]) / 2.0,
          (bounds[:min_y] + bounds[:max_y]) / 2.0
        ]
      end

      # Get area
      def area
        return 0 if @outline_points.length < 3

        # Shoelace formula for polygon area
        sum = 0
        n = @outline_points.length

        @outline_points.each_with_index do |pt, i|
          next_pt = @outline_points[(i + 1) % n]
          sum += pt[0] * next_pt[1]
          sum -= next_pt[0] * pt[1]
        end

        (sum.abs / 2.0)
      end

      # =================================================================
      # Label Management
      # =================================================================

      # Set label group
      def set_label(label_group)
        @label_group = label_group
      end

      # Check if has label
      def has_label?
        !@label_group.nil?
      end

      # Get label bounds
      def label_bounds
        return nil unless @label_group && @label_group.valid?
        @label_group.bounds
      end

      # =================================================================
      # Nesting State
      # =================================================================

      # Check if positioned in nesting
      def positioned?
        !@nesting_position.nil?
      end

      # Set position in nesting
      def place_at(x, y, rotation = 0)
        @nesting_position = [x, y]
        @nesting_rotation = rotation
      end

      # Reset nesting position
      def reset_position
        @nesting_position = nil
        @nesting_rotation = 0
      end

      # Get transformation for nesting position
      def nesting_transformation
        return Geom::Transformation.new if @nesting_position.nil?

        # Translation
        translation = Geom::Transformation.translation(
          Geom::Vector3d.new(@nesting_position[0], @nesting_position[1], 0)
        )

        # Rotation around Z axis
        if @nesting_rotation != 0
          rotation = Geom::Transformation.rotation(
            Geom::Point3d.new(0, 0, 0),
            Geom::Vector3d.new(0, 0, 1),
            @nesting_rotation.degrees
          )
          translation * rotation
        else
          translation
        end
      end

      # =================================================================
      # Source Board Reference
      # =================================================================

      # Get source board classification key
      def classification_key
        return nil unless @source_board
        @source_board.classification_key
      end

      # Get source board thickness
      def thickness
        return 0 unless @source_board
        @source_board.thickness
      end

      # Get source board material
      def material_name
        return nil unless @source_board
        @source_board.material_name
      end

      # Check if source board is valid
      def source_valid?
        return false unless @source_board
        @source_board.valid?
      end

      # =================================================================
      # Validation
      # =================================================================

      def valid?
        validation_errors.empty?
      end

      def validation_errors
        errors = []

        errors << "No outline points" if @outline_points.empty?
        errors << "Outline has less than 3 points" if @outline_points.length < 3
        errors << "No source board" unless @source_board
        errors << "Source board is invalid" if @source_board && !@source_board.valid?
        errors << "Zero area" if area <= 0

        errors
      end

      # =================================================================
      # Geometry Helpers
      # =================================================================

      # Check if point is inside outline
      def contains_point?(x, y)
        return false if @outline_points.length < 3

        # Ray casting algorithm
        inside = false
        n = @outline_points.length

        j = n - 1
        @outline_points.each_with_index do |pt, i|
          xi, yi = pt
          xj, yj = @outline_points[j]

          if ((yi > y) != (yj > y)) && (x < (xj - xi) * (y - yi) / (yj - yi) + xi)
            inside = !inside
          end

          j = i
        end

        inside
      end

      # Check if this 2D group overlaps with another
      def overlaps_with?(other_2d_group)
        return false unless other_2d_group.is_a?(TwoDGroup)

        # Simple bounding box check first
        bounds1 = bounds_2d
        bounds2 = other_2d_group.bounds_2d

        return false unless bounds1 && bounds2

        # Check if bounding boxes overlap
        return false if bounds1[:max_x] < bounds2[:min_x]
        return false if bounds1[:min_x] > bounds2[:max_x]
        return false if bounds1[:max_y] < bounds2[:min_y]
        return false if bounds1[:min_y] > bounds2[:max_y]

        # Bounding boxes overlap, need more detailed check
        # Check if any vertex of one is inside the other
        @outline_points.each do |pt|
          return true if other_2d_group.contains_point?(pt[0], pt[1])
        end

        other_2d_group.outline.each do |pt|
          return true if contains_point?(pt[0], pt[1])
        end

        false
      end

      # =================================================================
      # Display & Debug
      # =================================================================

      def print_info
        puts "=" * 70
        puts "2D GROUP INFO"
        puts "=" * 70
        puts ""
        puts "Entity ID: #{@entity_id}"
        puts "Source Board: #{@source_board ? @source_board.entity.name : 'None'}"
        puts ""
        puts "Dimensions:"
        puts "  Width: #{width.round(2)} mm"
        puts "  Height: #{height.round(2)} mm"
        puts "  Area: #{area.round(2)} mm²"
        puts "  Center: [#{center_2d[0].round(2)}, #{center_2d[1].round(2)}]"
        puts ""
        puts "Outline:"
        puts "  Points: #{@outline_points.length}"
        if @outline_points.length <= 10
          @outline_points.each_with_index do |pt, i|
            puts "    #{i + 1}. [#{pt[0].round(2)}, #{pt[1].round(2)}]"
          end
        end
        puts ""
        puts "Label:"
        puts "  Has label: #{has_label?}"
        puts ""
        puts "Nesting:"
        puts "  Positioned: #{positioned?}"
        if positioned?
          puts "  Position: [#{@nesting_position[0].round(2)}, #{@nesting_position[1].round(2)}]"
          puts "  Rotation: #{@nesting_rotation}°"
        end
        puts ""
        puts "Classification:"
        puts "  Key: #{classification_key || 'N/A'}"
        puts "  Thickness: #{thickness} mm"
        puts "  Material: #{material_name || 'N/A'}"
        puts ""
        puts "Validation:"
        if valid?
          puts "  Status: ✓ VALID"
        else
          puts "  Status: ✗ INVALID"
          puts "  Errors:"
          validation_errors.each { |err| puts "    - #{err}" }
        end
        puts "=" * 70
      end

      # =================================================================
      # Serialization
      # =================================================================

      def to_hash
        super.merge({
          source_board_id: @source_board ? @source_board.entity_id : nil,
          face_type: @face_type,
          outline_points: @outline_points,
          width: width,
          height: height,
          area: area,
          center: center_2d,
          has_label: has_label?,
          nesting_position: @nesting_position,
          nesting_rotation: @nesting_rotation,
          positioned: positioned?,
          classification_key: classification_key,
          thickness: thickness,
          material: material_name,
          valid: valid?,
          validation_errors: validation_errors
        })
      end
    end

  end
end
