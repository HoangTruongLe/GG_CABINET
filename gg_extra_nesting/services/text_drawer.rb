# frozen_string_literal: true

module GG_Cabinet
  module ExtraNesting

    class TextDrawer

      DEFAULT_HEIGHT = 10.0
      DEFAULT_FONT = 'Arial'
      DEFAULT_BOLD = false
      DEFAULT_ITALIC = false
      DEFAULT_FILLED = true
      MM_TO_INCHES = 25.4

      class << self

        def draw_text(entities, text, height = DEFAULT_HEIGHT, filled = DEFAULT_FILLED)
          text = convert_to_string(text)
          return create_empty_group(entities) if text.nil? || text.empty?

          height_mm = convert_height_to_mm(height)
          height_inches = height_mm / MM_TO_INCHES

          text_group = create_empty_group(entities)

          text_group.entities.add_3d_text(text, 1, DEFAULT_FONT, DEFAULT_BOLD, DEFAULT_ITALIC, height_inches, 0.0, 0.0, filled, 0.0)

          flatten_group(text_group)
        end

        private

        def convert_to_string(text)
          return nil if text.nil?

          case text
          when String
            text
          when Integer
            text.to_s
          when Float
            str = text.to_s
            str.sub(/\.0+$/, '')
          else
            text.to_s
          end
        end

        def convert_height_to_mm(height_input)
          case height_input
          when Numeric
            height_input.to_f
          when ->(h) { h.respond_to?(:/) }
            begin
              (height_input / 1.mm).to_f
            rescue
              height_input.to_f
            end
          else
            height_input.to_f
          end
        end

        def flatten_group(group)
          return unless group && group.valid?
          GeometryFlattener.flatten_group(group)
        end

        def create_empty_group(entities)
          empty_group = entities.add_group
          empty_group.name = "EmptyTextGroup"
          empty_group
        end

      end

    end

  end
end
