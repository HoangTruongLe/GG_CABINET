# frozen_string_literal: true

module GG_Cabinet
  module ExtraNesting

    # Base class for all persistent entities
    # Handles SketchUp attribute persistence and database sync
    class PersistentEntity
      attr_reader :id, :entity_id, :attributes, :entity

      def initialize(sketchup_entity = nil)
        @entity = sketchup_entity
        @entity_id = sketchup_entity&.entityID
        @id = generate_id
        @attributes = {}
        load_attributes if @entity
      end

      # Load from SketchUp attributes
      def load_attributes
        return unless @entity

        dict = @entity.attribute_dictionary('ABF')
        return unless dict

        dict.each { |key, value| @attributes[key] = value }
      end

      # Save to SketchUp attributes
      def save_attributes
        return unless @entity

        @attributes.each do |key, value|
          @entity.set_attribute('ABF', key, value)
        end
      end

      # Sync with database
      def sync_to_db
        Database.instance.save(self.class.name, @id, to_hash)
      end

      # Serialize to hash
      def to_hash
        {
          id: @id,
          entity_id: @entity_id,
          attributes: @attributes,
          class: self.class.name
        }
      end

      # Get attribute value
      def get_attribute(key)
        @attributes[key]
      end

      # Set attribute value
      def set_attribute(key, value)
        @attributes[key] = value
      end

      # Check if has attribute
      def has_attribute?(key)
        @attributes.key?(key)
      end

      # SketchUp entity reference
      def sketchup_entity
        @entity
      end

      private

      # Generate unique ID
      def generate_id
        class_name = self.class.name.split('::').last.downcase
        "#{class_name}_#{Time.now.to_i}_#{rand(10000)}"
      end
    end

  end
end
