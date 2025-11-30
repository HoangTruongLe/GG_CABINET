# frozen_string_literal: true

module GG_Cabinet
  module ExtraNesting

    class Label < PersistentEntity
      attr_reader :parent, :rotation, :board

      ARROW_LENGTH = 25.0
      ARROW_HEAD = 5.0

      def initialize(board, label_index)
        @board = board
        @label_index = label_index
        
        @entity = create_label_group
        raise "Failed to create label group" unless @entity

        scale_label
        move_label_to_face(@entity)
        
        super(@entity)
        @parent = board
        @rotation = @board.label_rotation
      end

      def bounds
        return nil unless @entity && @entity.valid?
        @entity.bounds
      end

      def width
        return 0 unless @entity && @entity.valid?
        dims = local_dimensions
        dims[:width]
      end

      def height
        return 0 unless @entity && @entity.valid?
        dims = local_dimensions
        dims[:height]
      end

      def local_dimensions
        return { width: 0, height: 0 } unless @entity && @entity.valid?
        
        label_bounds = @entity.bounds
        return { width: 0, height: 0 } unless label_bounds
        
        x_dim = (label_bounds.max.x - label_bounds.min.x) / 1.mm
        y_dim = (label_bounds.max.y - label_bounds.min.y) / 1.mm
        z_dim = (label_bounds.max.z - label_bounds.min.z) / 1.mm
        
        non_zero_dims = [x_dim, y_dim, z_dim].select { |d| d > 0.1 }.sort
        
        if non_zero_dims.length >= 2
          label_width = non_zero_dims[0]
          label_height = non_zero_dims[1]
        elsif non_zero_dims.length == 1
          label_width = non_zero_dims[0]
          label_height = non_zero_dims[0]
        else
          label_width = 0
          label_height = 0
        end
        
        {
          width: label_width,
          height: label_height
        }
      end

      def label_dimensions_in_face_space
        return { width: 0, height: 0, width_direction: nil, height_direction: nil } unless @entity && @entity.valid?
        
        label_bounds = @entity.bounds
        return { width: 0, height: 0, width_direction: nil, height_direction: nil } unless label_bounds
        
        face = @board&.front_face
        return { width: 0, height: 0, width_direction: nil, height_direction: nil } unless face
        
        face_width_dir = face.width_direction
        face_height_dir = face.height_direction
        
        return { width: 0, height: 0, width_direction: nil, height_direction: nil } unless face_width_dir && face_height_dir
        
        corners = [
          label_bounds.corner(0), label_bounds.corner(1),
          label_bounds.corner(2), label_bounds.corner(3),
          label_bounds.corner(4), label_bounds.corner(5),
          label_bounds.corner(6), label_bounds.corner(7)
        ]
        
        width_projections = corners.map { |c| c.to_a.zip(face_width_dir.to_a).map { |a, b| a * b }.sum }
        height_projections = corners.map { |c| c.to_a.zip(face_height_dir.to_a).map { |a, b| a * b }.sum }
        
        label_width = (width_projections.max - width_projections.min) / 1.mm
        label_height = (height_projections.max - height_projections.min) / 1.mm
        
        if label_width > label_height
          label_width, label_height = label_height, label_width
          face_width_dir, face_height_dir = face_height_dir, face_width_dir
        end
        
        {
          width: label_width,
          height: label_height,
          width_direction: face_width_dir,
          height_direction: face_height_dir
        }
      end

      def width_direction
        return nil unless @entity && @entity.valid?
        
        transform = @entity.transformation
        origin = Geom::Point3d.new(0, 0, 0)
        x_axis_point = Geom::Point3d.new(1, 0, 0)
        
        transformed_origin = transform * origin
        transformed_x = transform * x_axis_point
        
        width_vec = transformed_x - transformed_origin
        width_vec.normalize if width_vec.length > 0.001
        width_vec
      end

      def height_direction
        return nil unless @entity && @entity.valid?
        
        transform = @entity.transformation
        origin = Geom::Point3d.new(0, 0, 0)
        y_axis_point = Geom::Point3d.new(0, 1, 0)
        
        transformed_origin = transform * origin
        transformed_y = transform * y_axis_point
        
        height_vec = transformed_y - transformed_origin
        height_vec.normalize if height_vec.length > 0.001
        height_vec
      end

      def center
        return nil unless @entity && @entity.valid?
        
        bounds = @entity.bounds
        return nil unless bounds
        bounds.center
      end

      private

      def create_label_group
        return nil unless @board && @board.entity && @board.front_face

        front_face = @board.front_face
        instance_name = @board.entity.name || "Board"

        label_group = @board.entity.entities.add_group
        label_group.name = "Label_#{@label_index}"

        label_group.set_attribute('ABF', 'is-label', true)
        label_group.set_attribute('ABF', 'label-index', @label_index)
        label_group.set_attribute('ABF', 'label-rotation', @board.label_rotation)

        index_group = draw_index_number(label_group, @label_index)
        return nil unless index_group && index_group.valid?
        
        offset_text_up(index_group, 4.0.mm)
        index_bounds = index_group.bounds
        
        separator_group = draw_separator(label_group, index_bounds)
        separator_bounds = nil
        
        if separator_group && separator_group.valid?
          offset_text_up(separator_group, 4.0.mm)
          offset_to_right_of(separator_group, index_bounds, 2.0.mm)
          separator_bounds = separator_group.bounds
        end
        
        instance_name_group = draw_instance_name(label_group, instance_name, separator_bounds, index_bounds)
        instance_name_bounds = nil
        
        if instance_name_group && instance_name_group.valid?
          offset_text_up(instance_name_group, 4.0.mm)
          reference_bounds = separator_bounds || index_bounds
          offset_to_right_of(instance_name_group, reference_bounds, 2.0.mm) if reference_bounds
          instance_name_bounds = instance_name_group.bounds
        end
        
        total_text_width = calculate_total_text_width(index_bounds, separator_bounds, instance_name_bounds)
        draw_vector_arrow(label_group, total_text_width)

        label_group
      end

      def scale_label
        return unless @entity && @entity.valid?
        
        puts "=== SCALE_LABEL DEBUG ==="
        
        label_bounds = @entity.bounds
        x_dim = (label_bounds.max.x - label_bounds.min.x) / 1.mm
        y_dim = (label_bounds.max.y - label_bounds.min.y) / 1.mm
        z_dim = (label_bounds.max.z - label_bounds.min.z) / 1.mm
        
        puts "Raw bounds dimensions:"
        puts "  X: #{x_dim.round(2)} mm"
        puts "  Y: #{y_dim.round(2)} mm"
        puts "  Z: #{z_dim.round(2)} mm"
        
        label_width_before = width
        label_height_before = height
        
        puts "Label dimensions BEFORE scale (via local_dimensions):"
        puts "  label_width: #{label_width_before.round(2)} mm"
        puts "  label_height: #{label_height_before.round(2)} mm"
        
        return if label_width_before == 0 || label_height_before == 0
        
        front_face = @board.front_face
        return unless front_face
        
        face_width = front_face.width.to_f
        face_height = front_face.height.to_f
        
        puts "Face dimensions:"
        puts "  face_width: #{face_width.round(2)} mm"
        puts "  face_height: #{face_height.round(2)} mm"
        
        scale_factor = calculate_scale_factor(front_face, label_width_before, label_height_before)
        
        puts "Calculated scale_factor: #{scale_factor.round(4)}"
        
        expected_scaled_width = label_width_before * scale_factor
        expected_scaled_height = label_height_before * scale_factor
        expected_margin_w = (face_width - expected_scaled_width) / 2.0
        expected_margin_h = (face_height - expected_scaled_height) / 2.0
        
        puts "Expected after scaling:"
        puts "  scaled_width: #{expected_scaled_width.round(2)} mm"
        puts "  scaled_height: #{expected_scaled_height.round(2)} mm"
        puts "  margin_width: #{expected_margin_w.round(2)} mm"
        puts "  margin_height: #{expected_margin_h.round(2)} mm"
        
        if scale_factor != 1.0
          apply_scale(@entity, scale_factor)
          @entity.set_attribute('ABF', 'label-scale', scale_factor) if @entity.valid?
        end
        
        label_width_after = width
        label_height_after = height
        
        puts "Label dimensions AFTER scale:"
        puts "  label_width: #{label_width_after.round(2)} mm"
        puts "  label_height: #{label_height_after.round(2)} mm"
        
        actual_margin_w = (face_width - label_width_after) / 2.0
        actual_margin_h = (face_height - label_height_after) / 2.0
        
        puts "Actual margins after scaling:"
        puts "  margin_width: #{actual_margin_w.round(2)} mm"
        puts "  margin_height: #{actual_margin_h.round(2)} mm"
        puts "=== END SCALE_LABEL DEBUG ==="
      end

      def calculate_total_text_width(index_bounds, separator_bounds, instance_name_bounds)
        all_bounds = [index_bounds, separator_bounds, instance_name_bounds].compact
        return ARROW_LENGTH.mm if all_bounds.empty?
        
        min_x = all_bounds.map { |b| b.min.x }.min
        max_x = all_bounds.map { |b| b.max.x }.max
        
        total_width = max_x - min_x
        
        [total_width, ARROW_LENGTH.mm].max + 5.0.mm
      end

      def draw_vector_arrow(label_group, total_text_width = ARROW_LENGTH.mm)
        entities = label_group.entities

        x_axis = Geom::Vector3d.new(1, 0, 0)
        y_axis = Geom::Vector3d.new(0, 1, 0)
        origin = Geom::Point3d.new(0, 0, 0)
        arrow_start = origin
        
        arrow_length = total_text_width
        arrow_end = origin.offset(x_axis, arrow_length)

        entities.add_line(arrow_start, arrow_end)

        head_left = arrow_end.offset(x_axis, -ARROW_HEAD.mm).offset(y_axis, -ARROW_HEAD.mm * 0.5)
        head_right = arrow_end.offset(x_axis, -ARROW_HEAD.mm).offset(y_axis, ARROW_HEAD.mm * 0.5)

        entities.add_line(arrow_end, head_left)
        entities.add_line(arrow_end, head_right)
      end

      def draw_index_number(label_group, number)
        entities = label_group.entities

        TextDrawer.draw_text(
          entities,
          number.to_s,
          6.0,
          false
        )
      end

      def draw_separator(label_group, index_bounds)
        return nil unless index_bounds

        entities = label_group.entities
        separator = "-"

        TextDrawer.draw_text(
          entities,
          separator,
          5.0,
          false
        )
      end

      def draw_instance_name(label_group, name, separator_bounds, index_bounds)
        entities = label_group.entities

        TextDrawer.draw_text(
          entities,
          name,
          5.0,
          false
        )
      end

      def offset_text_up(text_group, offset_y)
        return unless text_group && text_group.valid?
        
        translation = Geom::Transformation.translation(Geom::Vector3d.new(0, offset_y, 0))
        text_group.transform!(translation)
      end

      def offset_to_right_of(text_group, reference_bounds, spacing)
        return unless text_group && text_group.valid? && reference_bounds
        
        reference_max_x = reference_bounds.max.x
        current_min_x = text_group.bounds.min.x
        offset_x = reference_max_x - current_min_x + spacing
        
        translation = Geom::Transformation.translation(Geom::Vector3d.new(offset_x, 0, 0))
        text_group.transform!(translation)
      end

      def calculate_scale_factor(front_face, label_width, label_height)
        puts "=== CALCULATE_SCALE_FACTOR DEBUG ==="
        
        face_width_mm = front_face.width.to_f
        face_height_mm = front_face.height.to_f
        
        puts "Input values:"
        puts "  face_width_mm: #{face_width_mm.round(2)}"
        puts "  face_height_mm: #{face_height_mm.round(2)}"
        puts "  label_width: #{label_width.round(2)}"
        puts "  label_height: #{label_height.round(2)}"
        
        if face_width_mm <= 0 || face_height_mm <= 0 || label_width <= 0 || label_height <= 0
          puts "Returning 1.0 due to invalid dimensions"
          return 1.0
        end

        border_offset_mm = 10.0
        total_offset_mm = border_offset_mm * 2.0
        
        available_width_mm = face_width_mm - total_offset_mm
        available_height_mm = face_height_mm - total_offset_mm
        
        puts "Available space (after 10mm border on each side):"
        puts "  available_width_mm: #{available_width_mm.round(2)}"
        puts "  available_height_mm: #{available_height_mm.round(2)}"
        
        if available_width_mm <= 0 || available_height_mm <= 0
          puts "Returning 1.0 due to insufficient space"
          return 1.0
        end
        
        scale_x = available_width_mm / label_width
        scale_y = available_height_mm / label_height
        
        puts "Scale factors:"
        puts "  scale_x: #{scale_x.round(4)}"
        puts "  scale_y: #{scale_y.round(4)}"
        
        max_scale = 6.0
        result = [[scale_x, scale_y].min, max_scale].min
        
        puts "Final scale_factor (min, capped at #{max_scale}): #{result.round(4)}"
        puts "=== END CALCULATE_SCALE_FACTOR DEBUG ==="
        
        result
      end

      def apply_scale(label_group, scale_factor)
        label_center = label_group.bounds.center
        scale_transform = Geom::Transformation.scaling(label_center, scale_factor, scale_factor, scale_factor)
        label_group.transform!(scale_transform)
      end

      def move_label_to_face(label_group)
        front_face = @board.front_face
        return unless front_face && front_face.valid?

        face_normal = front_face.normal
        return unless face_normal

        height_direction = front_face.height_direction
        return unless height_direction
        
        label_center_local = label_group.bounds.center
            
        face_alignment_transform = create_face_alignment_transform(face_normal)
        arrow_alignment_transform = create_arrow_alignment_transform(face_normal, height_direction, face_alignment_transform)
        user_rotation_transform = create_user_rotation_transform(face_normal, @board.label_rotation)
        
        rotation_transform = user_rotation_transform * arrow_alignment_transform * face_alignment_transform
        label_center_world = rotation_transform * label_center_local
        
        face_center = front_face.center
        translation_offset = face_center - label_center_world
        translation_transform = Geom::Transformation.translation(translation_offset)
        
        final_transform = translation_transform * rotation_transform
        label_group.transform!(final_transform)
        
        verify_label_offset(front_face)
      end
      
      def verify_label_offset(front_face)
        puts "=== VERIFY_LABEL_OFFSET DEBUG ==="
        return unless @entity && @entity.valid? && front_face
        
        label_bounds = @entity.bounds
        puts "Label bounds (after move_label_to_face):"
        puts "  min: #{label_bounds.min}"
        puts "  max: #{label_bounds.max}"
        puts "  width (bounds.width): #{label_bounds.width.to_mm.round(2)} mm"
        puts "  height (bounds.height): #{label_bounds.height.to_mm.round(2)} mm"
        puts "  depth (bounds.depth): #{label_bounds.depth.to_mm.round(2)} mm"
        
        dims = label_dimensions_in_face_space
        scaled_label_width = dims[:width]
        scaled_label_height = dims[:height]
        
        puts "Label dimensions in face space:"
        puts "  scaled_label_width: #{scaled_label_width.round(2)} mm"
        puts "  scaled_label_height: #{scaled_label_height.round(2)} mm"
        
        return if scaled_label_width == 0 || scaled_label_height == 0
        
        face_width_mm = front_face.width
        face_height_mm = front_face.height
        
        puts "Face dimensions:"
        puts "  face_width_mm: #{face_width_mm.round(2)} mm"
        puts "  face_height_mm: #{face_height_mm.round(2)} mm"
        
        border_offset_mm = 10.0
        
        margin_width = (face_width_mm - scaled_label_width) / 2.0
        margin_height = (face_height_mm - scaled_label_height) / 2.0
        
        puts "Calculated margins:"
        puts "  margin_width: #{margin_width.round(2)} mm"
        puts "  margin_height: #{margin_height.round(2)} mm"
        
        min_margin = [margin_width, margin_height].min
        
        puts "min_margin: #{min_margin.round(2)} mm (expected: #{border_offset_mm} mm)"
        puts "=== END VERIFY_LABEL_OFFSET DEBUG ==="
        
        if min_margin < border_offset_mm - 0.1
          puts "⚠️ Warning: Label offset is #{min_margin.round(2)}mm (min), expected #{border_offset_mm}mm"
        else
          puts "✓ Label offset OK: #{min_margin.round(2)}mm >= #{border_offset_mm}mm"
        end
      end

      def create_face_alignment_transform(face_normal)
        z_local = Geom::Vector3d.new(0, 0, 1)
        
        if face_normal.parallel?(z_local)
          z_local = Geom::Vector3d.new(1, 0, 0)
        end
        
        rotation_axis = (z_local * face_normal).normalize
        if rotation_axis.length < 0.001
          rotation_axis = Geom::Vector3d.new(1, 0, 0)
        end
        
        angle = z_local.angle_between(face_normal)
        
        Geom::Transformation.rotation(
          Geom::Point3d.new(0, 0, 0),
          rotation_axis,
          angle
        )
      end

      def create_arrow_alignment_transform(face_normal, height_direction, face_alignment_transform)
        arrow_local = Geom::Vector3d.new(1, 0, 0)
        
        arrow_world = transform_vector(arrow_local, face_alignment_transform)
        arrow_in_plane = project_to_plane(arrow_world, face_normal)
        
        height_in_plane = project_to_plane(height_direction.normalize, face_normal)
        
        return Geom::Transformation.new unless arrow_in_plane.length > 0.001 && height_in_plane.length > 0.001
        
        arrow_in_plane.normalize!
        height_in_plane.normalize!
        
        angle = arrow_in_plane.angle_between(height_in_plane)
        cross_product = arrow_in_plane * height_in_plane
        
        angle = -angle if cross_product.dot(face_normal) < 0
        
        Geom::Transformation.rotation(
          Geom::Point3d.new(0, 0, 0),
          face_normal,
          angle
        )
      end
      
      def create_user_rotation_transform(face_normal, rotation_degrees)
        rotation_radians = (rotation_degrees + 180) * Math::PI / 180.0
        
        Geom::Transformation.rotation(
          Geom::Point3d.new(0, 0, 0),
          face_normal,
          rotation_radians
        )
      end

      def transform_vector(vector, transformation)
        origin = Geom::Point3d.new(0, 0, 0)
        point_end = origin + vector
        
        transformed_origin = transformation * origin
        transformed_end = transformation * point_end
        
        transformed_end - transformed_origin
      end

      def project_to_plane(vector, plane_normal)
        normal_normalized = plane_normal.normalize
        dot_product = vector.dot(normal_normalized)
        component_along_normal = Geom::Vector3d.new(
          normal_normalized.x * dot_product,
          normal_normalized.y * dot_product,
          normal_normalized.z * dot_product
        )
        vector - component_along_normal
      end
    end

  end
end
