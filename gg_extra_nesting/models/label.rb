# frozen_string_literal: true

module GG_Cabinet
  module ExtraNesting

    class Label < PersistentEntity
      attr_reader :parent, :rotation, :board

      ARROW_LENGTH = 25.0
      ARROW_HEAD = 5.0
      TEXT_HEIGHT_INDEX = 6.0
      TEXT_HEIGHT_NAME = 5.0
      TEXT_SPACING = 2.0
      TEXT_OFFSET_Y = 4.0
      BORDER_OFFSET = 10.0
      MAX_SCALE = 6.0

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
        b = @entity.bounds
        dims = [b.width / 1.mm, b.height / 1.mm, b.depth / 1.mm].select { |d| d > 0.1 }.sort
        return 0 if dims.empty?
        w = dims[0]
        puts "  [LOG] label.width: #{w.round(1)}mm (from bounds, using smallest non-zero dimension)"
        w
      end

      def height
        return 0 unless @entity && @entity.valid?
        b = @entity.bounds
        dims = [b.width / 1.mm, b.height / 1.mm, b.depth / 1.mm].select { |d| d > 0.1 }.sort
        return 0 if dims.length < 2
        h = dims[1]
        puts "  [LOG] label.height: #{h.round(1)}mm (from bounds, using second largest dimension)"
        h
      end

      def center
        return nil unless @entity && @entity.valid?
        bounds&.center
      end

      def width_direction
        return nil unless @entity && @entity.valid?
        transform_local_axis(Geom::Vector3d.new(1, 0, 0))
      end

      def height_direction
        return nil unless @entity && @entity.valid?
        transform_local_axis(Geom::Vector3d.new(0, 1, 0))
      end

      private

      def length_to_world(local_length, direction)
        return local_length unless @board && direction
        
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

      def local_dimensions
        return { width: 0, height: 0, width_direction: nil, height_direction: nil } unless @entity && @entity.valid?
        
        label_bounds = @entity.bounds
        return { width: 0, height: 0, width_direction: nil, height_direction: nil } unless label_bounds
        
        dim_data = [
          { length: (label_bounds.max.x - label_bounds.min.x) / 1.mm, direction: X_AXIS },
          { length: (label_bounds.max.y - label_bounds.min.y) / 1.mm, direction: Y_AXIS },
          { length: (label_bounds.max.z - label_bounds.min.z) / 1.mm, direction: Z_AXIS }
        ].select { |d| d[:length] > 0.1 }.sort_by { |d| d[:length] }
        
        case dim_data.length
        when 0
          { width: 0, height: 0, width_direction: nil, height_direction: nil }
        when 1
          { width: dim_data[0][:length], height: dim_data[0][:length],
            width_direction: dim_data[0][:direction], height_direction: dim_data[0][:direction] }
        else
          { width: dim_data[0][:length], height: dim_data[1][:length],
            width_direction: dim_data[0][:direction], height_direction: dim_data[1][:direction] }
        end
      end

      def label_dimensions_in_face_space
        empty_result = { width: 0, height: 0, width_direction: nil, height_direction: nil }
        return empty_result unless @entity && @entity.valid?
        
        label_bounds = @entity.bounds
        face = @board&.front_face
        return empty_result unless label_bounds && face
        
        face_width_dir = face.width_direction
        face_height_dir = face.height_direction
        return empty_result unless face_width_dir && face_height_dir
        
        corners = (0..7).map { |i| label_bounds.corner(i) }
        
        width_projections = corners.map { |c| dot_product(c, face_width_dir) }
        height_projections = corners.map { |c| dot_product(c, face_height_dir) }
        
        label_width = (width_projections.max - width_projections.min) / 1.mm
        label_height = (height_projections.max - height_projections.min) / 1.mm
        
        if label_width > label_height
          { width: label_height, height: label_width, 
            width_direction: face_height_dir, height_direction: face_width_dir }
        else
          { width: label_width, height: label_height,
            width_direction: face_width_dir, height_direction: face_height_dir }
        end
      end

      def create_label_group
        return nil unless @board && @board.entity && @board.front_face

        instance_name = @board.entity.name || "Board"
        label_group = @board.entity.entities.add_group
        label_group.name = "Label_#{@label_index}"

        set_label_attributes(label_group)
        
        index_group = draw_text_element(label_group, @label_index.to_s, TEXT_HEIGHT_INDEX)
        return nil unless index_group&.valid?
        
        position_text(index_group, nil)
        
        separator_group = draw_text_element(label_group, "-", TEXT_HEIGHT_NAME)
        position_text(separator_group, index_group.bounds) if separator_group&.valid?
        
        name_group = draw_text_element(label_group, instance_name, TEXT_HEIGHT_NAME)
        ref_bounds = separator_group&.valid? ? separator_group.bounds : index_group.bounds
        position_text(name_group, ref_bounds) if name_group&.valid?
        
        all_bounds = [index_group, separator_group, name_group].compact.select(&:valid?).map(&:bounds)
        draw_arrow(label_group, calculate_arrow_length(all_bounds))

        label_group
      end

      def set_label_attributes(label_group)
        label_group.set_attribute('ABF', 'is-label', true)
        label_group.set_attribute('ABF', 'label-index', @label_index)
        label_group.set_attribute('ABF', 'label-rotation', @board.label_rotation)
      end

      def draw_text_element(label_group, text, height)
        TextDrawer.draw_text(label_group.entities, text, height, false)
      end

      def position_text(text_group, reference_bounds)
        return unless text_group&.valid?
        
        offset_y = Geom::Transformation.translation(Geom::Vector3d.new(0, TEXT_OFFSET_Y.mm, 0))
        text_group.transform!(offset_y)
        
        return unless reference_bounds
        
        offset_x = reference_bounds.max.x - text_group.bounds.min.x + TEXT_SPACING.mm
        text_group.transform!(Geom::Transformation.translation(Geom::Vector3d.new(offset_x, 0, 0)))
      end

      def calculate_arrow_length(bounds_list)
        return ARROW_LENGTH.mm if bounds_list.empty?
        
        min_x = bounds_list.map { |b| b.min.x }.min
        max_x = bounds_list.map { |b| b.max.x }.max
        
        [max_x - min_x, ARROW_LENGTH.mm].max + 5.0.mm
      end

      def draw_arrow(label_group, length)
        entities = label_group.entities
        x_axis = Geom::Vector3d.new(1, 0, 0)
        y_axis = Geom::Vector3d.new(0, 1, 0)
        origin = Geom::Point3d.new(0, 0, 0)
        
        arrow_end = origin.offset(x_axis, length)
        entities.add_line(origin, arrow_end)
        
        head_offset = ARROW_HEAD.mm
        entities.add_line(arrow_end, arrow_end.offset(x_axis, -head_offset).offset(y_axis, -head_offset * 0.5))
        entities.add_line(arrow_end, arrow_end.offset(x_axis, -head_offset).offset(y_axis, head_offset * 0.5))
      end

      def scale_label
        puts "  [LOG] scale_label called"
        return unless @entity && @entity.valid?
        
        label_w = width
        label_h = height
        puts "  [LOG] label dimensions: #{label_w} × #{label_h}"
        return if label_w == 0 || label_h == 0
        
        front_face = @board.front_face
        return unless front_face
        
        face_w = front_face.width.to_f
        face_h = front_face.height.to_f
        puts "  [LOG] front_face dimensions: #{face_w} × #{face_h}"
        
        scale_factor = calculate_scale_factor(face_w, face_h, label_w, label_h)
        puts "  [LOG] scale_factor: #{scale_factor}"
        
        if scale_factor != 1.0
          apply_scale(@entity, scale_factor)
          @entity.set_attribute('ABF', 'label-scale', scale_factor) if @entity.valid?
        end
        puts "  [LOG] label entity valid after scale: #{@entity.valid?}"
      end

      def calculate_scale_factor(face_width, face_height, label_width, label_height)
        puts "  [LOG] calculate_scale_factor: face=#{face_width.round(1)}×#{face_height.round(1)}, label=#{label_width.round(1)}×#{label_height.round(1)}"
        return 1.0 if [face_width, face_height, label_width, label_height].any? { |v| v <= 0 }

        total_offset = BORDER_OFFSET * 2.0
        available_width = face_width - total_offset
        available_height = face_height - total_offset
        puts "  [LOG] available space: #{available_width.round(1)}×#{available_height.round(1)} (after #{total_offset}mm borders)"
        
        return 1.0 if available_width <= 0 || available_height <= 0
        
        scale_x = available_width / label_width
        scale_y = available_height / label_height
        puts "  [LOG] scale_x=#{scale_x.round(2)}, scale_y=#{scale_y.round(2)}, min=#{[scale_x, scale_y].min.round(2)}, max=#{MAX_SCALE}"
        
        [[scale_x, scale_y].min, MAX_SCALE].min
      end

      def apply_scale(label_group, scale_factor)
        center = label_group.bounds.center
        label_group.transform!(Geom::Transformation.scaling(center, scale_factor, scale_factor, scale_factor))
      end

      def move_label_to_face(label_group)
        puts "  [LOG] move_label_to_face called"
        front_face = @board.front_face
        unless front_face&.valid?
          puts "  [LOG] front_face invalid, returning"
          return
        end

        face_normal = front_face.normal
        height_dir = front_face.height_direction
        unless face_normal && height_dir
          puts "  [LOG] face_normal or height_dir nil, returning"
          return
        end
        puts "  [LOG] face_normal: #{face_normal.to_a}, height_dir: #{height_dir.to_a}"
        
        label_center = label_group.bounds.center
        
        z_up = Geom::Vector3d.new(0, 0, 1)
        rotation_axis = z_up * face_normal
        if rotation_axis.length < 0.001
          rotation_axis = Geom::Vector3d.new(1, 0, 0)
        else
          rotation_axis.normalize!
        end
        
        angle = z_up.angle_between(face_normal)
        face_rotation = Geom::Transformation.rotation(ORIGIN, rotation_axis, angle)
        
        arrow_dir = Geom::Vector3d.new(1, 0, 0)
        rotated_arrow = face_rotation * arrow_dir
        
        dot_product = height_dir.dot(face_normal)
        projection = Geom::Vector3d.new(
          face_normal.x * dot_product,
          face_normal.y * dot_product,
          face_normal.z * dot_product
        )
        height_on_plane = height_dir - projection
        height_on_plane.normalize! if height_on_plane.length > 0.001
        
        arrow_angle = rotated_arrow.angle_between(height_on_plane)
        cross = rotated_arrow * height_on_plane
        arrow_angle = -arrow_angle if cross.dot(face_normal) < 0
        
        arrow_rotation = Geom::Transformation.rotation(ORIGIN, face_normal, arrow_angle)
        user_rotation = Geom::Transformation.rotation(ORIGIN, face_normal, (@board.label_rotation + 180) * Math::PI / 180.0)
        
        full_rotation = user_rotation * arrow_rotation * face_rotation
        rotated_center = full_rotation * label_center
        
        offset = face_normal.clone
        offset.length = 0.01.mm
        target_position = front_face.center.offset(offset)
        
        translation = Geom::Transformation.translation(target_position - rotated_center)
        label_group.transform!(translation * full_rotation)
        
        puts "  [LOG] Label final position: #{label_group.bounds.center.to_a}"
        puts "  [LOG] Label valid after move: #{label_group.valid?}"
      end

      def create_face_alignment_transform(face_normal)
        z_local = face_normal.parallel?(Geom::Vector3d.new(0, 0, 1)) ? 
                  Geom::Vector3d.new(1, 0, 0) : Geom::Vector3d.new(0, 0, 1)
        
        axis = z_local * face_normal
        axis = Geom::Vector3d.new(1, 0, 0) if axis.length < 0.001
        
        Geom::Transformation.rotation(ORIGIN, axis.normalize, z_local.angle_between(face_normal))
      end

      def create_arrow_alignment_transform(face_normal, height_dir, face_transform)
        arrow_world = transform_vector(Geom::Vector3d.new(1, 0, 0), face_transform)
        arrow_plane = project_to_plane(arrow_world, face_normal)
        height_plane = project_to_plane(height_dir.normalize, face_normal)
        
        return Geom::Transformation.new if arrow_plane.length < 0.001 || height_plane.length < 0.001
        
        arrow_plane.normalize!
        height_plane.normalize!
        
        angle = arrow_plane.angle_between(height_plane)
        angle = -angle if (arrow_plane * height_plane).dot(face_normal) < 0
        
        Geom::Transformation.rotation(ORIGIN, face_normal, angle)
      end
      
      def create_user_rotation_transform(face_normal, rotation_degrees)
        Geom::Transformation.rotation(ORIGIN, face_normal, (rotation_degrees + 180) * Math::PI / 180.0)
      end

      def transform_local_axis(axis)
        transform = @entity.transformation
        origin = Geom::Point3d.new(0, 0, 0)
        vec = (transform * (origin + axis)) - (transform * origin)
        vec.normalize if vec.length > 0.001
        vec
      end

      def transform_vector(vector, transformation)
        origin = Geom::Point3d.new(0, 0, 0)
        (transformation * (origin + vector)) - (transformation * origin)
      end

      def project_to_plane(vector, plane_normal)
        n = plane_normal.normalize
        dot = vector.dot(n)
        vector - Geom::Vector3d.new(n.x * dot, n.y * dot, n.z * dot)
      end

      def dot_product(point, vector)
        point.to_a.zip(vector.to_a).map { |a, b| a * b }.sum
      end

      ORIGIN = Geom::Point3d.new(0, 0, 0)
    end
  end
end
