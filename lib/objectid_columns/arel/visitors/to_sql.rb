require 'active_support'

module ObjectidColumns
  module Arel
    module Visitors
      # This module gets mixed into Arel::Visitors::ToSql, which is the class that the Arel gem (which is really the
      # backbone of ActiveRecord's query language) uses to generate SQL. This teaches Arel what to do when it bumps
      # into an object of a BSON ID class -- _i.e._, how to convert it to a SQL literal.
      #
      # How this works depends on which version of ActiveRecord -- and therefore AREL -- you're using:
      #
      # * In Arel 4.x, the #visit... methods get called with two arguments. The first is the actual BSON ID that needs
      #   to be converted; the second provides context. From the second parameter, we can get the table name and
      #   column name. We use this to get a hold of the ObjectidColumnsManager via its class method .for_table, and,
      #   from there, a converted, valid value for the column in question (whether hex or binary).
      # * In Arel 2.x (AR 3.0.x) and 3.x, we have to monkeypatch the #visit_Arel_Attributes_Attribute method -- it
      #   already picks up and stashes away the .last_column, but we need to add the .last_relation, too.
      #
      module ToSql
        extend ActiveSupport::Concern

        require 'arel'
        if ::Arel::VERSION =~ /^[23]\./
          def visit_Arel_Attributes_Attribute_with_objectid_columns(o, *args)
            out = visit_Arel_Attributes_Attribute_without_objectid_columns(o, *args)
            self.last_relation = o.relation
            out
          end

          included do
            alias_method_chain :visit_Arel_Attributes_Attribute, :objectid_columns

            alias :visit_Arel_Attributes_Integer :visit_Arel_Attributes_Attribute_with_objectid_columns
            alias :visit_Arel_Attributes_Float :visit_Arel_Attributes_Attribute_with_objectid_columns
            alias :visit_Arel_Attributes_Decimal :visit_Arel_Attributes_Attribute_with_objectid_columns
            alias :visit_Arel_Attributes_String :visit_Arel_Attributes_Attribute_with_objectid_columns
            alias :visit_Arel_Attributes_Time :visit_Arel_Attributes_Attribute_with_objectid_columns
            alias :visit_Arel_Attributes_Boolean :visit_Arel_Attributes_Attribute_with_objectid_columns

            attr_accessor :last_relation
          end
        end

        def visit_BSON_ObjectId(o, a = nil)
          column = if a then column_for(a) else last_column end
          relation = if a then a.relation else last_relation end

          return quote(o.to_s) unless column && relation

          quote(bson_objectid_value_from_parameter(o, column, relation), column)
        end

        alias_method :visit_Moped_BSON_ObjectId, :visit_BSON_ObjectId

        private
        def bson_objectid_value_from_parameter(o, column, relation)
          column_name = column.name

          manager = ObjectidColumns::ObjectidColumnsManager.for_table(relation.name)
          unless manager
            raise %{ObjectidColumns: You're trying to evaluate a SQL statement (in Arel, probably via ActiveRecord)
that contains a BSON ObjectId value -- you're trying to use the value '#{o}'
(of class #{o.class.name}) with column #{column_name.inspect} of table
#{relation.name.inspect}. However, we can't find any record of any ObjectId
columns being declared for that table anywhere.

As a result, we don't know whether this column should be treated as a binary or
a hexadecimal ObjectId, and hence don't know how to transform this value properly.}
          end

          unless manager.is_objectid_column?(column_name)
            raise %{ObjectidColumns: You're trying to evaluate a SQL statement (in Arel, probably via ActiveRecord)
that contains a BSON ObjectId value -- you're trying to use the value '#{o}'
(of class #{o.class.name}) with column #{column_name.inspect} of table
#{relation.name.inspect}.

While we can find a record of some ObjectId columns being declared for
that table, they don't appear to include #{column_name.inspect}. As such,
we don't know whether this column should be treated as a binary or a hexadecimal
ObjectId, and hence don't know how to transform this value properly.}
          end

          manager.to_valid_value_for_column(column_name, o)
        end
      end
    end
  end
end
