# frozen_string_literal: true

module GG_Cabinet
  module ExtraNesting

    # Board model - represents a 3D board/panel
    # Phase 2: Complete implementation
    class Board < PersistentEntity
      attr_reader :faces, :edge_bandings, :label, :material, :thickness_mm
      attr_accessor :classification_key

      # Common wood thicknesses in mm
      COMMON_THICKNESSES = [8, 9, 12, 15, 17.5, 18, 20, 25, 30].freeze
      THICKNESS_TOLERANCE = 0.5 # mm

      def initialize(sketchup_group)
        super(sketchup_group)

        unless sketchup_group.is_a?(Sketchup::Group)
          raise ArgumentError, "Board must be initialized with a Sketchup::Group"
        end

        @faces = []
        @edge_bandings = []
        @label = nil

        # Detect board properties
        detect_faces
        detect_material
        detect_thickness
        detect_label

        # Generate classification key
        @classification_key = generate_classification_key
      end

      # =================================================================
      # Material Detection
      # =================================================================

      def detect_material
        @material = {
          name: nil,
          display_name: nil,
          color: nil,
          source: nil
        }

        group_material = entity_material
        return @material unless group_material

        @material[:name] = group_material.name
        @material[:color] = group_material.color
        @material[:display_name] = group_material.display_name || group_material.name
        @material[:source] = 'group'

        @material
      end

      def material_name
        @material[:name] # Can be nil
      end

      def material_display_name
        @material[:display_name] || material_name
      end

      # =================================================================
      # Thickness Detection
      # =================================================================

      def detect_thickness
        return nil unless entity_valid?

        bounds = @entity.bounds

        # Get all three dimensions
        dimensions = [
          bounds.width,
          bounds.height,
          bounds.depth
        ].map { |d| d / 1.mm }.sort

        # Thickness is the smallest dimension
        raw_thickness = dimensions.first

        # Round to 1 decimal place
        thickness_mm = raw_thickness.round(1)

        # Snap to common thicknesses if close enough
        common_match = COMMON_THICKNESSES.find do |common_t|
          (common_t - thickness_mm).abs < THICKNESS_TOLERANCE
        end

        @thickness_mm = common_match || thickness_mm
      end

      def thickness
        @thickness_mm || 0.0
      end

      # =================================================================
      # Face Detection
      # =================================================================

      def detect_faces
        return unless entity_valid?

        # Collect faces, sort by area (largest first), then detect front/back
        @faces = collect_faces.sort_by { |face| -face.area }
        detect_front_back_faces
      end

      def detect_front_back_faces
        return if @faces.empty?

        # Check if any face is already marked as labeled face
        labeled_face = @faces.find do |face|
          face.entity.get_attribute('ABF', 'is-labeled-face') == true
        end

        if labeled_face
          # Use existing labeled face as front
          @front_face = labeled_face

          # Find back face (parallel to front)
          @back_face = @faces.find do |face|
            face != @front_face &&
            face.parallel_to?(labeled_face) &&
            face.congruent_to?(labeled_face)
          end
        else
          # Auto-detect based on intersections
          # Face with more intersections becomes front face
          detect_front_by_intersections
        end
      end

      def detect_front_by_intersections
        # Get the two largest parallel congruent faces
        candidate_faces = find_parallel_congruent_faces

        if candidate_faces.count >= 2
          face1 = candidate_faces[0]
          face2 = candidate_faces[1]

          # Count intersections on each face
          face1_intersections = face1.intersections.count
          face2_intersections = face2.intersections.count

          # Face with more intersections becomes front
          if face1_intersections > face2_intersections
            @front_face = face1
            @back_face = face2
          elsif face2_intersections > face1_intersections
            @front_face = face2
            @back_face = face1
          else
            # Equal intersections - use first as front
            @front_face = face1
            @back_face = face2
          end
        elsif candidate_faces.count == 1
          @front_face = candidate_faces[0]
          @back_face = nil
        else
          # Fallback to largest face
          @front_face = @faces.first
          @back_face = nil
        end
      end

      def find_parallel_congruent_faces
        return [] if @faces.empty?

        # Start with largest face
        first = @faces.first
        candidates = [first]

        # Find parallel and congruent face
        second = @faces[1..-1].find do |face|
          face.parallel_to?(first) && face.congruent_to?(first)
        end

        candidates << second if second
        candidates
      end

      def front_face
        @front_face
      end

      def back_face
        @back_face
      end

      def side_faces
        @faces.reject { |f| f == @front_face || f == @back_face }
      end

      # =================================================================
      # Label Detection
      # =================================================================

      def detect_label
        return unless entity_valid?

        # Find label group inside board
        @label = entity_groups.find do |group|
          group.get_attribute('ABF', 'is-label') == true
        end
      end

      def label_index
        return nil unless @label
        @label.get_attribute('ABF', 'label-index')
      end

      def label_rotation
        return 0 unless @label
        @label.get_attribute('ABF', 'label-rotation') || 0
      end

      # Check if board has a label
      def labeled?
        !@label.nil?
      end

      def has_label?
        return false unless entity_valid?

        entity_groups.any? do |group|
          group.get_attribute('ABF', 'is-label') == true
        end
      end
      
      def create_label(new_label_index)
        return nil unless entity_valid? && front_face

        @label = Label.new(self, new_label_index)
        @label
      end

      def remove_label
        return unless entity_valid?

        entity_groups.each do |group|
          if group.get_attribute('ABF', 'is-label') == true
            group.erase!
          end
        end
        @label = nil
      end

      # Check if board can be labeled (only valid boards can be labeled)
      def can_be_labeled?
        valid?
      end

      # Check if board can be nested (only labeled boards can be nested)
      def can_be_nested?
        labeled?
      end

      # =================================================================
      # Classification
      # =================================================================

      def generate_classification_key
        # Format: "Material_Thickness"
        # Example: "Color A02_17.5", "Veneer Oak_25.0"
        # Material can be nil: "nil_17.5"
        mat_name = material_name || 'nil'
        "#{mat_name}_#{thickness}"
      end

      # =================================================================
      # Validation
      # =================================================================

      def valid?
        validation_errors.empty?
      end

      def validation_errors
        errors = []

        # Check if entity exists
        errors << "Entity is nil or deleted" if @entity.nil? || !@entity.valid?

        # Check faces
        errors << "No faces detected" if @faces.empty?
        errors << "Front face not detected" unless @front_face
        errors << "Back face not detected" unless @back_face

        # Check if front and back are parallel
        if @front_face && @back_face
          unless @front_face.parallel_to?(@back_face)
            errors << "Front and back faces are not parallel"
          end

          unless @front_face.congruent_to?(@back_face)
            errors << "Front and back faces are not congruent"
          end
        end

        # Material can be nil - no validation needed for material

        # Check thickness
        errors << "Thickness is zero or invalid" if thickness <= 0

        # Side faces should be rectangular (front/back can be any shape)
        unless side_faces_rectangular?
          errors << "Side faces are not rectangular"
        end

        errors
      end

      def side_faces_rectangular?
        return true if side_faces.empty?

        # Check if side faces are rectangular (4 vertices, 4 edges)
        side_faces.all? do |face|
          vertices = face.entity.vertices
          edges = face.entity.edges
          vertices.count == 4 && edges.count == 4
        end
      end

      # =================================================================
      # Dimensions
      # =================================================================

      def bounds
        @entity.bounds
      end

      def width
        bounds.width / 1.mm
      end

      def height
        bounds.height / 1.mm
      end

      def depth
        bounds.depth / 1.mm
      end

      def dimensions
        dims = [width, height, depth].sort.reverse
        { length: dims[0], width: dims[1], thickness: dims[2] }
      end

      # =================================================================
      # Intersections & Grooves
      # =================================================================

      def self.is_intersection_layer?(tag_name)
        Intersection.valid_intersection_layer?(tag_name)
      end

      def has_intersections?
        @faces.any?(&:has_intersections?)
      end

      def has_front_intersections?
        @front_face&.has_intersections? || false
      end

      def has_back_intersections?
        @back_face&.has_intersections? || false
      end

      def intersections
        @faces.flat_map(&:intersections)
      end

      def front_intersections
        @front_face ? @front_face.intersections : []
      end

      def back_intersections
        @back_face ? @back_face.intersections : []
      end

      # =================================================================
      # Mark Square (Bottom Sheet)
      # =================================================================

      # Check if board is a bottom sheet (has mark square)
      def has_mark_square?
        return false unless entity_valid?

        entity_groups.any? do |group|
          group.get_attribute('ABF', 'is-mark-square') == true
        end
      end

      def mark_square
        return nil unless entity_valid?

        entity_groups.find do |group|
          group.get_attribute('ABF', 'is-mark-square') == true
        end
      end

      def is_bottom_sheet?
        has_mark_square?
      end

      # =================================================================
      # Development Helpers
      # =================================================================

      def highlight_in_model
        return unless entity_valid?

        model = @entity.model
        model.selection.clear
        model.selection.add(@entity)
        model.active_view.zoom(@entity)
      end

      # =================================================================
      # Serialization
      # =================================================================

      def to_hash
        super.merge({
          material: @material,
          thickness: @thickness_mm,
          classification_key: @classification_key,
          dimensions: dimensions,
          has_label: labeled?,
          label_index: label_index,
          label_rotation: label_rotation,
          can_be_labeled: can_be_labeled?,
          can_be_nested: can_be_nested?,
          has_intersections: has_intersections?,
          intersection_count: intersections.count,
          is_bottom_sheet: is_bottom_sheet?,
          has_mark_square: has_mark_square?,
          valid: valid?,
          validation_errors: validation_errors
        })
      end

      private

      def entity_valid?
        @entity && @entity.valid?
      end

      def entity_material
        return nil unless entity_valid?
        @entity.material
      end

      def entity_entities
        return [] unless entity_valid?
        @entity.entities
      end

      def entity_groups
        entity_entities.grep(Sketchup::Group)
      end

      def entity_faces
        entity_entities.grep(Sketchup::Face)
      end

      def collect_faces
        entity_faces.map { |face_entity| Face.new(face_entity, self) }
      end

    end

  end
end
