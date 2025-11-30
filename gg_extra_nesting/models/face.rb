# frozen_string_literal: true

module GG_Cabinet
  module ExtraNesting

    # Face model - represents a face of a board
    # Phase 2: Complete implementation
    class Face < PersistentEntity
      attr_reader :board, :intersections

      # Tolerance for parallel check (degrees)
      PARALLEL_TOLERANCE = 1.0
      # Tolerance for area comparison (mm²)
      AREA_TOLERANCE = 0.01

      def initialize(sketchup_face, board = nil)
        super(sketchup_face)

        unless sketchup_face.is_a?(Sketchup::Face)
          raise ArgumentError, "Face must be initialized with a Sketchup::Face"
        end

        @board = board
        @intersections = nil
      end

      # =================================================================
      # Face Type Detection
      # =================================================================


      def front_face?
        return false unless @entity

        # Check if marked as labeled face
        @entity.get_attribute('ABF', 'is-labeled-face') == true
      end

      def labelable?
        return false unless @entity && @board
        largest_faces = @board.faces.first(2)
        largest_faces.include?(self)
      end

      def back_face?
        # Back face is parallel and congruent to front, but not the front itself
        return false unless @board
        return false if front_face?

        front = @board.front_face
        return false unless front

        parallel_to?(front) && congruent_to?(front)
      end

      def side_face?
        !front_face? && !back_face?
      end

      # =================================================================
      # Geometric Properties
      # =================================================================

      def area
        return 0 unless @entity && @entity.valid?
        @entity.area / (1.mm * 1.mm) # Convert to mm²
      end

      def normal
        return nil unless @entity && @entity.valid?
        @entity.normal
      end

      def vertices
        return [] unless @entity && @entity.valid?
        @entity.vertices
      end

      def edges
        return [] unless @entity && @entity.valid?
        @entity.edges
      end

      def bounds
        return nil unless @entity && @entity.valid?
        @entity.bounds
      end

      def center
        return nil unless bounds
        bounds.center
      end

      def width
        return 0 unless bounds
        dimensions = face_dimensions
        return dimensions[:width] unless dimensions[:width_direction]
        length_to_world(dimensions[:width], dimensions[:width_direction])
      end
      
      def height
        return 0 unless bounds
        dimensions = face_dimensions
        return dimensions[:height] unless dimensions[:height_direction]
        length_to_world(dimensions[:height], dimensions[:height_direction])
      end

      def width_direction
        return nil unless bounds && normal
        dimensions = face_dimensions
        dimensions[:width_direction]
      end

      def height_direction
        return nil unless bounds && normal
        dimensions = face_dimensions
        dimensions[:height_direction]
      end

      # =================================================================
      # Face Comparison
      # =================================================================

      def parallel_to?(other_face)
        return false unless other_face.is_a?(Face)
        return false unless normal && other_face.normal

        # Faces are parallel if their normals are parallel or anti-parallel
        # Calculate angle between normals
        angle = normal.angle_between(other_face.normal)
        angle_deg = angle * 180.0 / Math::PI

        # Parallel: 0° or 180° (within tolerance)
        (angle_deg < PARALLEL_TOLERANCE) || ((180.0 - angle_deg).abs < PARALLEL_TOLERANCE)
      end

      def congruent_to?(other_face)
        return false unless other_face.is_a?(Face)

        # Check if areas are similar
        (area - other_face.area).abs < AREA_TOLERANCE
      end

      def coplanar_with?(other_face)
        return false unless other_face.is_a?(Face)
        return false unless @entity && other_face.entity

        # Two faces are coplanar if they are parallel and their planes are the same
        return false unless parallel_to?(other_face)

        # Check if a vertex from one face lies on the plane of the other
        plane = @entity.plane
        other_vertex = other_face.vertices.first.position

        distance = plane[0..2].dot(other_vertex) - plane[3]
        distance.abs < 1.mm
      end

      # =================================================================
      # Material
      # =================================================================

      def material
        return nil unless @entity && @entity.valid?
        @entity.material
      end

      def material_name
        return material.name
      end

      # =================================================================
      # Face Orientation
      # =================================================================

      def facing_direction
        return nil unless normal

        # Determine primary facing direction
        x, y, z = normal.to_a

        # Find largest component
        abs_x = x.abs
        abs_y = y.abs
        abs_z = z.abs

        if abs_z > abs_x && abs_z > abs_y
          z > 0 ? :up : :down
        elsif abs_x > abs_y
          x > 0 ? :right : :left
        else
          y > 0 ? :back : :front
        end
      end

      def horizontal?
        return false unless normal
        facing_direction == :up || facing_direction == :down
      end

      def vertical?
        !horizontal?
      end

      # =================================================================
      # Intersections
      # =================================================================

      def intersections
        @intersections ||= detect_intersections
      end

      def has_intersections?
        intersections.any?
      end

      # =================================================================
      # Development Helpers
      # =================================================================

      def highlight_in_model
        return unless @entity && @entity.valid?

        model = @entity.model
        model.selection.clear
        model.selection.add(@entity)
        model.active_view.zoom(@entity)
      end
      
      def valid?
        @entity && @entity.valid? && area > 0
      end

      # =================================================================
      # Serialization
      # =================================================================

      def to_hash
        super.merge({
          type: front_face? ? 'front' : (back_face? ? 'back' : 'side'),
          area: area,
          normal: normal ? normal.to_a : nil,
          vertices_count: vertices.count,
          edges_count: edges.count,
          facing_direction: facing_direction,
          material: material_name,
          is_labeled: front_face?
        })
      end

      private

      def detect_intersections
        return [] unless board_entity_valid?

        board_groups.each_with_object([]) do |group, collection|
          tag_name = group.layer&.name
          next unless Intersection.valid_intersection_layer?(tag_name)

          intersection = Intersection.new(group, @board)
          next unless intersection.lies_on_face?(@entity)

          intersection.detect_face_location
          collection << intersection
        end
      end

      def board_entity_valid?
        @board&.entity && @board.entity.valid?
      end

      def board_groups
        return [] unless board_entity_valid?
        @board.entity.entities.grep(Sketchup::Group)
      end

      def face_dimensions
        return { width: 0, height: 0, width_direction: nil, height_direction: nil } unless @entity && @entity.valid?

        face_normal = normal
        return { width: 0, height: 0, width_direction: nil, height_direction: nil } unless face_normal

        vertices = @entity.vertices
        return { width: 0, height: 0, width_direction: nil, height_direction: nil } if vertices.length < 3

        points = vertices.map(&:position)
        
        edges = @entity.edges
        return { width: 0, height: 0, width_direction: nil, height_direction: nil } if edges.empty?

        puts "  [LOG] face_dimensions: #{edges.count} edges, #{vertices.count} vertices"
        
        edge_lengths = edges.map do |edge|
          start_pt = edge.start.position
          end_pt = edge.end.position
          direction = (end_pt - start_pt).normalize
          length = start_pt.distance(end_pt) / 1.mm
          { length: length, direction: direction, edge: edge }
        end

        edge_lengths.sort_by! { |e| -e[:length] }
        puts "  [LOG] edge lengths (sorted): #{edge_lengths.map { |e| e[:length].round(1) }.first(6).join(', ')}"

        longest_edge = edge_lengths[0]
        height_direction = longest_edge[:direction]
        face_height = longest_edge[:length]

        perpendicular_edges = edge_lengths.select do |e|
          dot = e[:direction].dot(height_direction).abs
          dot < 0.1
        end
        puts "  [LOG] perpendicular edges count: #{perpendicular_edges.count}"

        if perpendicular_edges.empty?
          width_direction = face_normal * height_direction
          width_direction.normalize! if width_direction.length > 0.001
          
          width_projections = points.map { |p| p.to_a.zip(width_direction.to_a).map { |a, b| a * b }.sum }
          face_width = (width_projections.max - width_projections.min) / 1.mm
          puts "  [LOG] No perpendicular edges, calculated width from projections: #{face_width.round(1)}"
        else
          width_edge = perpendicular_edges[0]
          width_direction = width_edge[:direction]
          face_width = width_edge[:length]
        end

        if face_width > face_height
          face_width, face_height = face_height, face_width
          width_direction, height_direction = height_direction, width_direction
        end
        
        puts "  [LOG] final face_dimensions: #{face_width.round(1)} × #{face_height.round(1)}"

        {
          width: face_width,
          height: face_height,
          width_direction: width_direction,
          height_direction: height_direction
        }
      end

      def length_to_world(local_length, direction)
        return local_length unless @board
        return local_length unless direction
        
        transform = parent_transformation
        return local_length unless transform
        
        origin = Geom::Point3d.new(0, 0, 0)
        unit_vector = direction.normalize
        end_point = origin.offset(unit_vector, local_length.mm)
        
        world_origin = transform * origin
        world_end = transform * end_point
        
        world_origin.distance(world_end) / 1.mm
      end
      
      def parent_transformation
        return nil unless @board && @board.entity && @board.entity.valid?
        @board.entity.transformation
      end
    end
  end
end
