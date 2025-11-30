# frozen_string_literal: true

module GG_Cabinet
  module ExtraNesting

    # Service for drawing edge banding indicators on 2D projections
    # Phase 3: Complete implementation
    class EdgeBandingDrawer

      # Standard triangle dimensions (mm)
      TRIANGLE_BASE = 40.0
      TRIANGLE_HEIGHT = 56.0
      TRIANGLE_SIDE = 40.0  # Isosceles

      # Triangle position (distance from edge)
      TRIANGLE_OFFSET_RATIO = 0.5  # 1/5 of height

      # Minimum scale for small boards
      MIN_SCALE = 0.3  # 50%
      MIN_EDGE_LENGTH_FOR_STANDARD = TRIANGLE_BASE * 1.5  # 60mm

      def initialize
        @edge_bandings = {}
      end

      # =================================================================
      # Main Method: Draw Edge Banding Indicators
      # =================================================================

      # Draw edge banding indicators on 2D group
      def draw_edge_banding(two_d_group, board, front_face)
        return unless two_d_group && board && front_face

        # Parse edge banding types from board
        @edge_bandings = EdgeBanding.parse_from_board(board)
        return if @edge_bandings.empty?

        # Find side faces with edge banding
        board.side_faces.each do |side_face|
          edge_band_id = EdgeBanding.get_edge_band_id(side_face)
          next unless edge_band_id

          # Get edge banding info
          edge_band = @edge_bandings[edge_band_id]
          next unless edge_band

          # Process this edge
          process_edge_banding(two_d_group, side_face, front_face, edge_band, board)
        end
      end

      # =================================================================
      # Edge Processing
      # =================================================================

      # Process single edge with edge banding
      def process_edge_banding(two_d_group, side_face, front_face, edge_band, board)
        # Find common edge between side face and front face
        common_edge = find_common_edge(side_face, front_face)
        return unless common_edge

        # Get edge vertices in 3D
        v1_3d = common_edge.start.position
        v2_3d = common_edge.end.position

        # Project to 2D (XY plane)
        v1_2d = project_to_xy(v1_3d)
        v2_2d = project_to_xy(v2_3d)

        # Calculate board center in 2D
        board_center_2d = project_to_xy(board.bounds.center)

        # Calculate edge properties
        edge_vector = [v2_2d[0] - v1_2d[0], v2_2d[1] - v1_2d[1]]
        edge_length = Math.sqrt(edge_vector[0]**2 + edge_vector[1]**2)

        # Calculate inward perpendicular direction
        edge_mid = [(v1_2d[0] + v2_2d[0]) / 2.0, (v1_2d[1] + v2_2d[1]) / 2.0]
        perp = calculate_inward_perpendicular(edge_vector, edge_mid, board_center_2d)

        # Offset edge by edge banding thickness
        offset_edge(two_d_group, v1_2d, v2_2d, perp, edge_band.thickness)

        # Draw triangle marker
        draw_triangle_marker(
          two_d_group,
          edge_mid,
          edge_vector,
          perp,
          edge_length,
          edge_band
        )
      end

      # =================================================================
      # Geometry Calculations
      # =================================================================

      # Find common edge between two faces
      def find_common_edge(face1, face2)
        return nil unless face1.entity && face2.entity

        face1_edges = face1.entity.edges
        face2_edges = face2.entity.edges

        # Find shared edge
        face1_edges.find do |edge1|
          face2_edges.any? { |edge2| edge2 == edge1 }
        end
      end

      # Project 3D point to 2D (XY plane)
      def project_to_xy(point_3d)
        [point_3d.x, point_3d.y]
      end

      # Calculate inward perpendicular direction
      def calculate_inward_perpendicular(edge_vector, edge_mid, board_center)
        # Two possible perpendicular directions
        perp1 = [-edge_vector[1], edge_vector[0]]   # Rotate 90° CCW
        perp2 = [edge_vector[1], -edge_vector[0]]   # Rotate 90° CW

        # Vector from edge midpoint to board center
        to_center = [
          board_center[0] - edge_mid[0],
          board_center[1] - edge_mid[1]
        ]

        # Dot product to determine which perpendicular points inward
        dot1 = perp1[0] * to_center[0] + perp1[1] * to_center[1]
        dot2 = perp2[0] * to_center[0] + perp2[1] * to_center[1]

        # Return the perpendicular with positive dot product (pointing inward)
        dot1 > dot2 ? perp1 : perp2
      end

      # Normalize vector
      def normalize_vector(vector)
        length = Math.sqrt(vector[0]**2 + vector[1]**2)
        return [0, 0] if length == 0

        [vector[0] / length, vector[1] / length]
      end

      # =================================================================
      # Triangle Calculations
      # =================================================================

      # Calculate triangle scale based on edge length
      def calculate_triangle_scale(edge_length)
        return 1.0 if edge_length >= MIN_EDGE_LENGTH_FOR_STANDARD

        scale = edge_length / MIN_EDGE_LENGTH_FOR_STANDARD
        [scale, MIN_SCALE].max  # Minimum 50%
      end

      # Calculate triangle vertices
      def calculate_triangle_vertices(base_center, edge_vector, perp, base_width, height)
        # Normalize edge vector
        edge_norm = normalize_vector(edge_vector)
        perp_norm = normalize_vector(perp)

        # Base left point
        base_left = [
          base_center[0] - edge_norm[0] * (base_width / 2.0),
          base_center[1] - edge_norm[1] * (base_width / 2.0)
        ]

        # Base right point
        base_right = [
          base_center[0] + edge_norm[0] * (base_width / 2.0),
          base_center[1] + edge_norm[1] * (base_width / 2.0)
        ]

        # Apex point (toward edge - opposite of inward perpendicular)
        apex = [
          base_center[0] - perp_norm[0] * height,
          base_center[1] - perp_norm[1] * height
        ]

        [base_left, base_right, apex]
      end

      # =================================================================
      # Drawing Methods
      # =================================================================

      # Offset edge in 2D group
      def offset_edge(two_d_group, v1, v2, perp, thickness)
        # This will be implemented when we have the 2D group structure
        # For now, this is a placeholder for the offset operation

        # Normalize perpendicular
        perp_norm = normalize_vector(perp)

        # Calculate offset vertices
        v1_offset = [
          v1[0] + perp_norm[0] * thickness,
          v1[1] + perp_norm[1] * thickness
        ]

        v2_offset = [
          v2[0] + perp_norm[0] * thickness,
          v2[1] + perp_norm[1] * thickness
        ]

        # Store offset information for later use
        {
          original: [v1, v2],
          offset: [v1_offset, v2_offset],
          thickness: thickness
        }
      end

      # Draw triangle marker
      def draw_triangle_marker(two_d_group, edge_mid, edge_vector, perp, edge_length, edge_band)
        # Calculate triangle scale
        scale = calculate_triangle_scale(edge_length)

        # Scaled dimensions
        base_width = TRIANGLE_BASE * scale
        height = TRIANGLE_HEIGHT * scale

        # Normalize perpendicular
        perp_norm = normalize_vector(perp)

        # Triangle base center (offset inward from edge by height * ratio)
        # Base is inward, apex points back toward edge
        offset_distance = height * TRIANGLE_OFFSET_RATIO
        triangle_base_center = [
          edge_mid[0] + perp_norm[0] * offset_distance,
          edge_mid[1] + perp_norm[1] * offset_distance
        ]

        # Calculate triangle vertices
        vertices = calculate_triangle_vertices(
          triangle_base_center,
          edge_vector,
          perp,
          base_width,
          height
        )
      end

      # =================================================================
      # Class Methods (Convenience)
      # =================================================================

      class << self
        # Quick draw edge banding
        def draw(two_d_group, board, front_face)
          drawer = new
          drawer.draw_edge_banding(two_d_group, board, front_face)
        end

        # Get edge banding info from board
        def get_edge_bandings(board)
          EdgeBanding.parse_from_board(board)
        end

        # Check if board has edge banding
        def has_edge_banding?(board)
          edge_bandings = get_edge_bandings(board)
          !edge_bandings.empty?
        end
      end

      # =================================================================
      # Debug & Visualization
      # =================================================================

      # Print edge banding information
      def print_edge_banding_info(board)
        edge_bandings = EdgeBanding.parse_from_board(board)

        puts "=" * 70
        puts "EDGE BANDING INFORMATION"
        puts "=" * 70
        puts ""

        if edge_bandings.empty?
          puts "No edge banding found on board"
          puts ""
          return
        end

        puts "Edge Banding Types:"
        edge_bandings.each do |id, edge_band|
          puts "  [#{id}] #{edge_band.name}"
          puts "      Thickness: #{edge_band.thickness} mm"
          puts "      Color: #{edge_band.color}"
        end
        puts ""

        puts "Side Faces with Edge Banding:"
        board.side_faces.each_with_index do |side_face, i|
          edge_band_id = EdgeBanding.get_edge_band_id(side_face)

          if edge_band_id
            edge_band = edge_bandings[edge_band_id]
            puts "  Side Face #{i + 1}: #{edge_band.name} (#{edge_band.thickness}mm)"
          else
            puts "  Side Face #{i + 1}: None"
          end
        end

        puts "=" * 70
      end
    end

  end
end
