# frozen_string_literal: true

module GG_Cabinet
  module ExtraNesting

    # Service for projecting 3D boards to 2D groups
    # Phase 3: Complete implementation
    class TwoDProjector

      def initialize
        @projected_groups = []
      end

      # =================================================================
      # Main Projection Methods
      # =================================================================

      # Project board to 2D group in target container
      # Creates frontface projection (always) and backface projection (if has intersections)
      def project_board(board, target_container)
        return nil unless board && board.valid?
        return nil unless target_container

        # Get front face
        front_face = board.front_face
        return nil unless front_face

        # Create front face projection
        front_2d = project_face(board, front_face, target_container, 'front')

        # Create back face projection if board has intersections
        if board.has_intersections? && board.back_face
          back_2d = project_face(board, board.back_face, target_container, 'back')
        end

        # Return front face projection (primary)
        front_2d
      end

      # Project a single face to 2D group
      def project_face(board, face, target_container, face_type = 'front')
        return nil unless board && face && target_container

        # Create 2D group in target container
        two_d_group_entity = target_container.entities.add_group
        two_d_group_entity.name = "2D_#{board.entity.name}_#{face_type}"

        # Mark as 2D projection
        two_d_group_entity.set_attribute('ABF', 'is-2d-projection', true)
        two_d_group_entity.set_attribute('ABF', 'source-board-id', board.entity_id)
        two_d_group_entity.set_attribute('ABF', 'face-type', face_type)

        # Create TwoDGroup object
        two_d_group = TwoDGroup.new(two_d_group_entity, board)
        two_d_group.face_type = face_type

        # Project face outline
        outline_points = project_face_outline(face)
        two_d_group.set_outline(outline_points)

        # Draw outline in SketchUp
        draw_outline(two_d_group_entity, outline_points)

        # Apply edge banding if present (only on front face)
        if face_type == 'front'
          apply_edge_banding(two_d_group_entity, board, face)
        end

        # Clone label if present (only on front face)
        if face_type == 'front'
          clone_label(two_d_group_entity, board, face)
        end

        # Project intersections (only on back face)
        if face_type == 'back' && board.has_back_intersections?
          project_intersections(two_d_group_entity, face)
        end

        # Store projected group
        @projected_groups << two_d_group

        two_d_group
      end

      # Project multiple boards
      def project_boards(boards, target_container)
        boards.map { |board| project_board(board, target_container) }.compact
      end

      # =================================================================
      # Face Outline Projection
      # =================================================================

      # Project face outline to 2D (XY plane)
      def project_face_outline(face)
        return [] unless face && face.entity

        vertices = face.entity.vertices
        points_2d = vertices.map do |vertex|
          pos = vertex.position
          [pos.x, pos.y]  # Project to XY plane (drop Z)
        end

        points_2d
      end

      # =================================================================
      # Drawing Methods
      # =================================================================

      # Draw outline in SketchUp group
      def draw_outline(group_entity, points)
        return unless group_entity && points.length >= 3

        # Convert 2D points to 3D (Z=0)
        points_3d = points.map { |pt| Geom::Point3d.new(pt[0], pt[1], 0) }

        # Create face
        face = group_entity.entities.add_face(points_3d)

        if face
          # Set face to show front (normal pointing up)
          face.reverse! if face.normal.z < 0
        end

        face
      end

      # =================================================================
      # Edge Banding Integration
      # =================================================================

      # Apply edge banding indicators
      def apply_edge_banding(group_entity, board, front_face)
        return unless EdgeBandingDrawer.has_edge_banding?(board)

        drawer = EdgeBandingDrawer.new
        drawer.draw_edge_banding(group_entity, board, front_face)
      end

      # =================================================================
      # Intersection Projection
      # =================================================================

      # Project intersection groups from board's face to 2D group
      def project_intersections(group_entity, face)
        return unless face && face.entity

        # Get intersection groups on this face
        board = face.board
        return unless board

        intersection_groups = if face == board.front_face
          board.front_intersections
        elsif face == board.back_face
          board.back_intersections
        else
          []
        end

        # Project each intersection group
        intersection_groups.each do |intersection_group|
          project_intersection_group(group_entity, intersection_group)
        end
      end

      # Project intersection group edges to 2D
      def project_intersection_group(target_group, intersection_group)
        return unless intersection_group && intersection_group.entities

        # Get all edges from the intersection group
        intersection_group.entities.each do |ent|
          if ent.is_a?(Sketchup::Edge)
            project_intersection_edge(target_group, ent, intersection_group.transformation)
          end
        end
      end

      # Project single intersection edge to 2D
      def project_intersection_edge(target_group, edge, transformation = nil)
        # Get edge vertices in board local coordinates
        if transformation
          # Transform from group local to board local
          start_pt = edge.start.position.transform(transformation)
          end_pt = edge.end.position.transform(transformation)
        else
          start_pt = edge.start.position
          end_pt = edge.end.position
        end

        # Project to 2D (drop Z)
        start_2d = Geom::Point3d.new(start_pt.x, start_pt.y, 0)
        end_2d = Geom::Point3d.new(end_pt.x, end_pt.y, 0)

        # Draw edge in target group
        new_edge = target_group.entities.add_line(start_2d, end_2d)

        # Copy layer from source
        new_edge.layer = edge.layer if edge.layer
      end

      # =================================================================
      # Label Cloning
      # =================================================================

      # Clone label from board to 2D group
      def clone_label(group_entity, board, front_face)
        return unless board.labeled?

        label = board.label
        return unless label && label.valid?

        # Get label transformation relative to front face
        label_transform = get_label_transform_2d(label, front_face, board)

        # Clone label group
        cloned_label = clone_label_group(group_entity, label, label_transform)

        cloned_label
      end

      # Get label transformation in 2D
      def get_label_transform_2d(label, front_face, board)
        # Get label bounds
        label_bounds = label.bounds
        label_center = label_bounds.center

        # Project to 2D
        label_center_2d = [label_center.x, label_center.y]

        # Get label rotation
        rotation = board.label_rotation || 0

        # Create transformation
        translation = Geom::Transformation.translation(
          Geom::Vector3d.new(label_center_2d[0], label_center_2d[1], 0)
        )

        if rotation != 0
          rotation_transform = Geom::Transformation.rotation(
            Geom::Point3d.new(0, 0, 0),
            Geom::Vector3d.new(0, 0, 1),
            rotation.degrees
          )
          translation * rotation_transform
        else
          translation
        end
      end

      # Clone label group into 2D group
      def clone_label_group(target_group, source_label, transform)
        # Get label entities
        label_entities = source_label.entities

        # Clone each entity
        label_entities.each do |entity|
          cloned = target_group.entities.add_instance(
            entity.definition,
            transform * entity.transformation
          ) if entity.is_a?(Sketchup::ComponentInstance)

          target_group.entities.add_face(entity.vertices) if entity.is_a?(Sketchup::Face)
        end
      end

      # =================================================================
      # Batch Operations
      # =================================================================

      # Project all boards in a container
      def project_all_boards_in_container(source_container, target_container)
        # Find all boards
        boards = []

        source_container.entities.each do |entity|
          if entity.is_a?(Sketchup::Group) &&
             entity.get_attribute('ABF', 'is-board') == true
            # Wrap in Board object
            board = Board.new(entity)
            boards << board if board.valid?
          end
        end

        # Project all
        project_boards(boards, target_container)
      end

      # =================================================================
      # Layout & Positioning
      # =================================================================

      # Layout 2D groups in a grid
      def layout_in_grid(two_d_groups, spacing = 100)
        return if two_d_groups.empty?

        x_offset = 0
        y_offset = 0
        row_height = 0
        max_width = 3000  # Max width before wrapping to new row

        two_d_groups.each do |group|
          width = group.width
          height = group.height

          # Check if need to wrap to new row
          if x_offset + width > max_width && x_offset > 0
            x_offset = 0
            y_offset += row_height + spacing
            row_height = 0
          end

          # Place group
          group.place_at(x_offset, y_offset, 0)

          # Apply transformation to SketchUp entity
          if group.entity && group.entity.valid?
            group.entity.transformation = group.nesting_transformation
          end

          # Update offsets
          x_offset += width + spacing
          row_height = [row_height, height].max
        end
      end

      # =================================================================
      # Helpers
      # =================================================================

      # Get all projected groups
      def projected_groups
        @projected_groups
      end

      # Clear projected groups
      def clear
        @projected_groups.clear
      end

      # =================================================================
      # Class Methods (Convenience)
      # =================================================================

      class << self
        # Quick project single board
        def project(board, target_container)
          projector = new
          projector.project_board(board, target_container)
        end

        # Quick project multiple boards
        def project_all(boards, target_container)
          projector = new
          projector.project_boards(boards, target_container)
        end

        # Project and layout in grid
        def project_and_layout(boards, target_container, spacing = 100)
          projector = new
          two_d_groups = projector.project_boards(boards, target_container)
          projector.layout_in_grid(two_d_groups, spacing)
          two_d_groups
        end
      end

      # =================================================================
      # Debug & Visualization
      # =================================================================

      def print_summary
        puts "=" * 70
        puts "2D PROJECTOR SUMMARY"
        puts "=" * 70
        puts ""
        puts "Projected Groups: #{@projected_groups.count}"
        puts ""

        if @projected_groups.any?
          puts "Groups:"
          @projected_groups.each_with_index do |group, i|
            puts "  #{i + 1}. #{group.width.round(2)} × #{group.height.round(2)} mm"
            puts "     Material: #{group.material_name || 'None'}"
            puts "     Thickness: #{group.thickness} mm"
            puts "     Valid: #{group.valid?}"
          end
        end

        puts "=" * 70
      end
    end

  end
end
