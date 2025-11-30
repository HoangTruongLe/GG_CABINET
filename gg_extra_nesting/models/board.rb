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

        #todo: implement remove_attributes
        remove_attributes

        # Detect board properties
        detect_faces
        detect_material
        detect_label

        # Generate classification key
        @classification_key = generate_classification_key
        
        if @front_face
          is_marked = @front_face.entity.get_attribute('ABF', 'is-labeled-face')
          puts "  [LOG] Board initialized, front_face marked: #{is_marked}, entity valid: #{@front_face.entity.valid?}"
        end
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
      # Face Detection
      # =================================================================

      def detect_faces
        return unless entity_valid?

        # Collect faces, sort by area (largest first), then detect front/back
        @faces = collect_faces.sort_by { |face| -face.area }
        detect_front_back_faces
      end

      def detect_front_back_faces
        puts "  [LOG] detect_front_back_faces called, faces count: #{@faces.count}"
        return if @faces.empty?

        labeled_face = @faces.find do |face|
          face.entity.get_attribute('ABF', 'is-labeled-face') == true
        end
        puts "  [LOG] labeled_face found: #{labeled_face ? 'yes' : 'no'}"

        if labeled_face
          @front_face = labeled_face
          @back_face = @faces.find do |face|
            face != @front_face &&
            face.parallel_to?(labeled_face) &&
            face.congruent_to?(labeled_face)
          end
          puts "  [LOG] Using existing labeled face as front"
        else
          puts "  [LOG] No labeled face found, calling detect_front_by_intersections"
          detect_front_by_intersections
        end
        
        if @front_face
          is_marked = @front_face.entity.get_attribute('ABF', 'is-labeled-face')
          puts "  [LOG] After detect_front_back_faces, front_face marked: #{is_marked}"
        end
      end

      def detect_front_by_intersections
        puts "  [LOG] detect_front_by_intersections called"
        candidate_faces = find_parallel_congruent_faces
        puts "  [LOG] candidate_faces count: #{candidate_faces.count}"

        unless candidate_faces.count >= 2
          raise ArgumentError, "Board must have at least 2 parallel congruent faces"
        end
      
        face1 = candidate_faces[0]
        face2 = candidate_faces[1]
        puts "  [LOG] face1.labelable?: #{face1.labelable?}, face2.labelable?: #{face2.labelable?}"

        unless face1.labelable? || face2.labelable?
          raise ArgumentError, "Face 1 and face 2 are not labelable"
        end
        
        board_persistent_id = @entity.persistent_id.to_s
        stored_face_id = Sketchup.read_default('GG_ExtraNesting', board_persistent_id, nil)
        puts "  [LOG] board_persistent_id: #{board_persistent_id}, stored_face_id: #{stored_face_id}"

        face1_intersections = face1.intersections.count
        face2_intersections = face2.intersections.count
        puts "  [LOG] face1_intersections: #{face1_intersections}, face2_intersections: #{face2_intersections}"
        
        if face1_intersections > face2_intersections
          puts "  [LOG] face1 has more intersections - using as front"
          @front_face = create_front_face(face1)
          @back_face = create_back_face(face2)
        elsif face2_intersections > face1_intersections
          puts "  [LOG] face2 has more intersections - using as front"
          @front_face = create_front_face(face2)
          @back_face = create_back_face(face1)
        else
          puts "  [LOG] Equal intersections - using face1 as front"
          @front_face = create_front_face(face1)
          @back_face = create_back_face(face2)
        end
        puts "  [LOG] @front_face set: #{@front_face ? 'yes' : 'no'}"
      end

      def create_front_face(face)
        puts "  [LOG] create_front_face called"
        face.entity.set_attribute('ABF', 'is-labeled-face', true)
        face
      end

      def create_back_face(face)
        face.entity.delete_attribute('ABF', 'is-labeled-face')
        face
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
        puts "  [LOG] create_label called with index: #{new_label_index}"
        puts "  [LOG] entity_valid?: #{entity_valid?}, front_face: #{front_face ? 'exists' : 'nil'}"
        
        unless entity_valid? && front_face
          puts "  [LOG] create_label returning nil - missing entity or front_face"
          return nil
        end

        @label = Label.new(self, new_label_index)
        puts "  [LOG] Label created: #{@label ? @label.entity : 'nil'}"
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
        return nil unless front_face
        
        "#{material_name}_#{thickness}"
      end

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

      def width
        return 0 unless @front_face
        @front_face.width
      end

      def height
        return 0 unless @front_face
        @front_face.height
      end

      def thickness
        return 0 unless @front_face && entity_valid?
        
        direction = thickness_direction
        return 0 unless direction
        
        vertices = entity_faces.flat_map(&:vertices).uniq
        return 0 if vertices.empty?
        
        local_points = vertices.map(&:position)
        projections = local_points.map { |pt| pt.to_a.zip(direction.to_a).map { |a, b| a * b }.sum }
        
        (projections.max - projections.min) / 1.mm
      end

      def width_direction
        return nil unless @front_face
        @front_face.width_direction
      end

      def height_direction
        return nil unless @front_face
        @front_face.height_direction
      end

      def thickness_direction
        return nil unless @front_face
        @front_face.normal
      end

      def dimensions
        { width: width, height: height, thickness: thickness }
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

      def remove_attributes
        return unless entity_valid?
        
        entity_faces.each do |face|
          face.delete_attribute('ABF', 'is-labeled-face')
          face.delete_attribute('ABF', 'is-cnced-face')
          face.delete_attribute('ABF', 'face-type')
        end
      end

    end

  end
end
