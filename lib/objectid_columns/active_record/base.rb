require 'objectid_columns'
require 'active_support'
require 'objectid_columns/has_objectid_columns'

module ObjectidColumns
  module ActiveRecord
    module Base
      extend ActiveSupport::Concern

      module ClassMethods
        def has_objectid_columns?
          false
        end

        def has_objectid_columns(*args)
          include ::ObjectidColumns::HasObjectidColumns
          has_objectid_columns(*args)
        end

        def has_objectid_column(*args)
          include ::ObjectidColumns::HasObjectidColumns
          has_objectid_column(*args)
        end
      end
    end
  end
end
