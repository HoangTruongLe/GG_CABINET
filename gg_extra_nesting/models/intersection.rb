# frozen_string_literal: true

module GG_Cabinet
  module ExtraNesting

    # Intersection - represents a flat group of edges on a board face
    # Used for detecting grooves, cutouts, and other features
    class Intersection < PersistentEntity
      attr_reader :board, :face_location

      def initialize(sketchup_group, board = nil)
        super(sketchup_group)

        unless sketchup_group.is_a?(Sketchup::Group)
          raise ArgumentError, "Intersection must be initialized with a Sketchup::Group"
        end

        @board = board
        @face_location = nil  # 'front', 'back', or nil if undetermined
      end

      # =================================================================
      # Class Methods - Layer Name Validation
      # =================================================================

      # Check if a layer name represents an intersection
      # Intersection: layer starts with ABF or _ABF
      # Exclude: _ABF_Label, _ABF_side*, ABF_Label, ABF_side*
      def self.valid_intersection_layer?(tag_name)
        return false unless tag_name
        return false if tag_name == 'Untagged'

        # Check if starts with ABF or _ABF
        starts_with_abf = tag_name.start_with?('ABF') || tag_name.start_with?('_ABF')
        return false unless starts_with_abf

        # Exclude labels and side faces
        excluded_patterns = [
          '_ABF_Label',
          '_ABF_side',
          'ABF_Label',
          'ABF_side'
        ]

        !excluded_patterns.any? { |pattern| tag_name.start_with?(pattern) }
      end

      # =================================================================
      # Face Location Detection
      # =================================================================

      # Determine which face this intersection lies on
      def detect_face_location
        return @face_location if @face_location  # Cache result
        return nil unless @board && @entity

        # Check front face
        if @board.front_face && lies_on_face?(@board.front_face.entity)
          @face_location = 'front'
        # Check back face
        elsif @board.back_face && lies_on_face?(@board.back_face.entity)
          @face_location = 'back'
        else
          @face_location = nil
        end

        @face_location
      end

      # Check if this intersection group lies on a specific face
      # Uses bounding box plane test: at least 4 bbox vertices on face plane
      def lies_on_face?(face)
        return false unless face && @entity

        # Get face plane equation: Ax + By + Cz = D
        face_plane = face.plane
        normal = Geom::Vector3d.new(face_plane[0], face_plane[1], face_plane[2])
        d = face_plane[3]

        # Get all 8 corners of intersection group's bounding box
        bounds = @entity.bounds
        bbox_points = [
          bounds.min,
          Geom::Point3d.new(bounds.max.x, bounds.min.y, bounds.min.z),
          Geom::Point3d.new(bounds.min.x, bounds.max.y, bounds.min.z),
          Geom::Point3d.new(bounds.max.x, bounds.max.y, bounds.min.z),
          Geom::Point3d.new(bounds.min.x, bounds.min.y, bounds.max.z),
          Geom::Point3d.new(bounds.max.x, bounds.min.y, bounds.max.z),
          Geom::Point3d.new(bounds.min.x, bounds.max.y, bounds.max.z),
          bounds.max
        ]

        # Count how many bbox vertices lie on the face plane
        vertices_on_plane = bbox_points.count do |pt|
          distance = normal.dot(pt) - d
          distance.abs < 1.mm  # 1mm tolerance
        end

        # If at least 4 vertices are on the plane, the group lies on this face
        vertices_on_plane >= 4
      end

      # =================================================================
      # Properties
      # =================================================================

      def layer_name
        return nil unless @entity && @entity.valid?
        @entity.layer.name
      end

      def edges
        return [] unless @entity && @entity.valid?
        @entity.entities.select { |e| e.is_a?(Sketchup::Edge) }
      end

      def edge_count
        edges.count
      end

      # =================================================================
      # Validation
      # =================================================================

      def valid?
        validation_errors.empty?
      end

      def validation_errors
        errors = []

        errors << "Entity is nil or invalid" if @entity.nil? || !@entity.valid?
        errors << "Not a valid intersection layer" unless self.class.valid_intersection_layer?(layer_name)
        errors << "No edges found" if edges.empty?
        errors << "Face location not determined" unless face_location

        errors
      end

      # =================================================================
      # Display & Debug
      # =================================================================

      def print_info
        puts "=" * 70
        puts "INTERSECTION INFO"
        puts "=" * 70
        puts ""
        puts "Entity: #{@entity ? @entity.name : 'nil'}"
        puts "Entity ID: #{@entity_id}"
        puts ""
        puts "Layer:"
        puts "  Name: #{layer_name || 'N/A'}"
        puts "  Valid intersection layer: #{self.class.valid_intersection_layer?(layer_name)}"
        puts ""
        puts "Location:"
        puts "  Face: #{face_location || 'Undetermined'}"
        puts "  Board: #{@board ? @board.entity.name : 'None'}"
        puts ""
        puts "Geometry:"
        puts "  Edge count: #{edge_count}"
        puts "  Bounds: #{@entity.bounds if @entity}" if @entity
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
          layer_name: layer_name,
          face_location: face_location,
          edge_count: edge_count,
          valid: valid?,
          validation_errors: validation_errors
        })
      end
    end

  end
end
