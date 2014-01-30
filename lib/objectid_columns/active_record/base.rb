require 'objectid_columns'
require 'active_support'

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
      end
    end
  end
end
