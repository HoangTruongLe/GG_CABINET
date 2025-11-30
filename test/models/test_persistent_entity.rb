# frozen_string_literal: true

# ===============================================================
# Tests for PersistentEntity Model
# ===============================================================

require_relative '../test_helper'

module GG_Cabinet
  module ExtraNesting
    module TestHelper

      def self.test_persistent_entity(results)
        puts "\nTesting PersistentEntity..."

        begin
          model = Sketchup.active_model
          group = model.entities.add_group
          group.name = "TestEntity"

          entity = PersistentEntity.new(group)

          assert_not_nil(entity.entity, "Entity should not be nil")
          assert_not_nil(entity.entity_id, "Entity ID should not be nil")
          assert_not_nil(entity.id, "ID should not be nil")

          # Test attributes
          entity.set_attribute('test-key', 'test-value')
          assert_equal('test-value', entity.get_attribute('test-key'))
          assert_true(entity.has_attribute?('test-key'))

          # Test serialization
          hash = entity.to_hash
          assert_not_nil(hash[:id])
          assert_not_nil(hash[:entity_id])

          group.erase!
          results.record_pass("PersistentEntity basic functionality")

        rescue => e
          results.record_fail("PersistentEntity basic functionality", e.message)
        end
      end

    end
  end
end
