require 'objectid_columns'
require 'objectid_columns/helpers/system_helpers'

unless defined?(VALID_OBJECTID_CLASSES)
  VALID_OBJECTID_CLASSES = [ BSON::ObjectId ]
  VALID_OBJECTID_CLASSES << Moped::BSON::ObjectId if defined?(Moped::BSON::ObjectId)
end

RSpec::Matchers.define :be_an_objectid_object do
  match do |actual|
    VALID_OBJECTID_CLASSES.detect { |c| actual.kind_of?(c) }
  end
  failure_message_for_should do |actual|
    "expected that #{actual} (#{actual.class}) would be an instance of BSON::ObjectId or Moped::BSON::ObjectId"
  end
end

RSpec::Matchers.define :be_the_same_objectid_as do |expected|
  match do |actual|
    net_expected = expected ? expected.to_bson_id.to_s : expected
    net_actual = actual ? actual.to_bson_id.to_s : actual
    net_expected == net_actual
  end
  failure_message_for_should do |actual|
    "expected that #{actual} (#{actual.class}) would be the same ObjectId as #{expected} (#{expected.class})"
  end
end

RSpec::Matchers.define :be_an_objectid_object_matching do |expected|
  match do |actual|
    net_expected = expected ? expected.to_bson_id.to_s : expected
    net_actual = actual ? actual.to_bson_id.to_s : actual
    (net_expected == net_actual) && (VALID_OBJECTID_CLASSES.detect { |c| actual.kind_of?(c) })
  end
  failure_message_for_should do |actual|
    "expected that #{actual} (#{actual.class}) would be an ObjectId object equal to #{expected} (#{expected.class})"
  end
end

describe "ObjectidColumns basic operations" do
  include ObjectidColumns::Helpers::SystemHelpers

  before :each do
    ensure_database_is_set_up!

    create_standard_system_spec_tables!
    create_standard_system_spec_models!
  end

  after :each do
    drop_standard_system_spec_tables!
  end

  VALID_OBJECTID_CLASSES.each do |test_class|
    context "using test class #{test_class}" do
      before :each do
        @tc = test_class
      end

      def new_oid
        @tc.new
      end

      it "should not allow defining a column that's too short" do
        if ObjectidColumns::Helpers::SystemHelpers.supports_length_limits_on_binary_columns?
          expect { ::Spectable.class_eval { has_objectid_column :too_short_b } }.to raise_error(ArgumentError)
          expect { ::Spectable.class_eval { has_objectid_column :too_short_s } }.to raise_error(ArgumentError)
        end
      end

      it "should not allow defining a column that's the wrong type" do
        expect { ::Spectable.class_eval { has_objectid_column :some_int_column } }.to raise_error(ArgumentError)
      end

      it "should not allow defining a column that doesn't exist" do
        expect { ::Spectable.class_eval { has_objectid_column :unknown_column } }.to raise_error(ArgumentError)
      end

      it "should not fail if the table doesn't exist" do
        define_model_class(:SpectableNonexistent, 'objectidcols_spec_table_nonexistent') { }
        expect { ::SpectableNonexistent.class_eval { has_objectid_column :foo } }.to_not raise_error
      end

      describe "primary key column support" do
        before :each do
          migrate do
            drop_table :objectidcols_spec_pk_bin rescue nil
            create_table :objectidcols_spec_pk_bin, :id => false do |t|
              t.binary :id, :null => false
              t.string :name
            end

            drop_table :objectidcols_spec_pk_str rescue nil
            create_table :objectidcols_spec_pk_str, :id => false do |t|
              t.string :id, :null => false
              t.string :name
            end

            drop_table :objectidcols_spec_pk_alt rescue nil
            create_table :objectidcols_spec_pk_alt, :id => false do |t|
              t.binary :some_name, :null => false
              t.string :name
            end

            drop_table :objectidcols_spec_pk_implicit rescue nil
            create_table :objectidcols_spec_pk_implicit, :id => false do |t|
              t.binary :some_name, :null => false
              t.string :name
            end
          end

          define_model_class(:SpectablePkBin, :objectidcols_spec_pk_bin) { self.primary_key = 'id' }
          define_model_class(:SpectablePkStr, :objectidcols_spec_pk_str) { self.primary_key = 'id' }
          define_model_class(:SpectablePkAlt, :objectidcols_spec_pk_alt) { self.primary_key = 'some_name' }
          define_model_class(:SpectablePkImplicit, :objectidcols_spec_pk_implicit) { }

          ::SpectablePkBin.class_eval { has_objectid_primary_key }
          ::SpectablePkStr.class_eval { has_objectid_primary_key }
          ::SpectablePkAlt.class_eval { has_objectid_primary_key }
          ::SpectablePkImplicit.class_eval { has_objectid_primary_key :some_name }
        end

        after :each do
          drop_table :objectidcols_spec_pk_bin rescue nil
          drop_table :objectidcols_spec_pk_str rescue nil
          drop_table :objectidcols_spec_pk_table_alt rescue nil
          drop_table :objectidcols_spec_pk_implicit rescue nil
        end

        [ :SpectablePkBin, :SpectablePkStr, :SpectablePkAlt, :SpectablePkImplicit ].each do |model_class|
          context "on model #{model_class}" do
            before :each do
              @model_class = model_class.to_s.constantize
            end

            it "should allow using a binary ObjectId column as a primary key" do
              r1 = @model_class.new
              r1.name = 'row 1'
              expect(r1.id).to be_nil
              r1.save!
              expect(r1.id).to_not be_nil
              expect(r1.id).to be_an_objectid_object
              r1_id = r1.id

              r2 = @model_class.new
              r2.name = 'row 2'
              expect(r2.id).to be_nil
              r2.save!
              expect(r2.id).to_not be_nil
              expect(r2.id).to be_an_objectid_object
              r2_id = r2.id

              r1_again = @model_class.find(r1.id)
              expect(r1_again.name).to eq('row 1')

              r2_again = @model_class.find(r2.id)
              expect(r2_again.name).to eq('row 2')

              expect(@model_class.find([ r1.id, r2. id ]).map(&:id).sort_by(&:to_s)).to eq([ r1_id, r2_id ].sort_by(&:to_s))

              expect(@model_class.where(:name => 'row 1').first.id).to eq(r1_id)
              expect(@model_class.where(:name => 'row 2').first.id).to eq(r2_id)

              find_by_id_method = "find_by_#{@model_class.primary_key}"
              expect(@model_class.send(find_by_id_method, r1.id).id).to eq(r1_id)
              expect(@model_class.send(find_by_id_method, r2.id).id).to eq(r2_id)
              expect(@model_class.send(find_by_id_method, new_oid)).to be_nil
            end

            it "should not pick up primary-key columns automatically, even if they're named _oid" do
              migrate do
                drop_table :objectidcols_spec_pk_auto rescue nil
                create_table :objectidcols_spec_pk_auto, :id => false do |t|
                  t.binary :foo_oid, :null => false
                  t.binary :bar_oid
                  t.string :name
                end
              end

              define_model_class(:SpectablePkAuto, :objectidcols_spec_pk_auto) { self.primary_key = 'foo_oid' }

              ::SpectablePkAuto.has_objectid_columns
              r = ::SpectablePkAuto.new
              r.foo_oid = 'foobar' # this will only work if we do NOT think it's an ObjectId
              expect { r.bar_oid = 'foobar' }.to raise_error(ArgumentError)
              r.bar_oid = the_bar_oid = new_oid.to_s

              expect(r.bar_oid).to be_an_objectid_object_matching(the_bar_oid)

              migrate do
                drop_table :objectidcols_spec_pk_auto rescue nil
              end
            end
          end
        end
      end

      context "with a single, manually-defined column" do
        before :each do
          ::Spectable.class_eval { has_objectid_column :perfect_s_oid }
        end

        it "should allow writing and reading via an ObjectId object" do
          the_oid = new_oid

          r = ::Spectable.new
          r.perfect_s_oid = the_oid
          expect(r.perfect_s_oid).to be_the_same_objectid_as(the_oid)
          expect(r.perfect_s_oid).to be_an_objectid_object
          r.save!
          expect(r.perfect_s_oid).to be_the_same_objectid_as(the_oid.to_s)
          expect(r.perfect_s_oid).to be_an_objectid_object

          r_again = ::Spectable.find(r.id)
          expect(r_again.perfect_s_oid).to be_the_same_objectid_as(the_oid.to_s)
          expect(r_again.perfect_s_oid).to be_an_objectid_object
        end

        it "should raise a good exception if you try to assign something that isn't a valid ObjectId" do
          r = ::Spectable.new

          expect { r.perfect_s_oid = 12345 }.to raise_error(ArgumentError, /12345/)
          expect { r.perfect_s_oid = /foobar/ }.to raise_error(ArgumentError, /foobar/i)
        end

        if "".respond_to?(:encoding)
          it "should not allow assigning binary strings unless their encoding is BINARY" do
            r = ::Spectable.new

            binary = new_oid.to_binary
            binary = binary.force_encoding(Encoding::ISO_8859_1)
            expect { r.perfect_s_oid = binary }.to raise_error(ArgumentError)
          end
        end

        it "should not allow assigning strings that are the wrong format" do
          r = ::Spectable.new

          expect { r.perfect_s_oid = new_oid.to_binary[0..10] }.to raise_error(ArgumentError)
          expect { r.perfect_s_oid = new_oid.to_binary + "\x00" }.to raise_error(ArgumentError)
        end

        it "should let you set columns to nil" do
          r = ::Spectable.create!(:perfect_s_oid => (@oid = new_oid))

          r_again = ::Spectable.find(r.id)
          expect(r_again.perfect_s_oid).to be_an_objectid_object_matching(@oid)
          r.perfect_s_oid = nil
          r.save!

          r_yet_again = ::Spectable.find(r.id)
          expect(r_yet_again.perfect_s_oid).to be_nil
        end

        it "should accept ObjectIds for input in binary, String, or either object format" do
          VALID_OBJECTID_CLASSES.each do |klass|
            r = ::Spectable.create!(:perfect_s_oid => (@oid = klass.new))
            expect(::Spectable.find(r.id).perfect_s_oid).to be_an_objectid_object_matching(@oid)
          end

          r = ::Spectable.create!(:perfect_s_oid => (@oid = new_oid.to_s))
          expect(::Spectable.find(r.id).perfect_s_oid).to be_an_objectid_object_matching(@oid)

          r = ::Spectable.create!(:perfect_s_oid => (@oid = new_oid.to_binary))
          expect(::Spectable.find(r.id).perfect_s_oid).to be_an_objectid_object_matching(@oid)
        end

        it "should not do anything to the other columns" do
          r = ::Spectable.new

          r.perfect_b_oid = 'perfect_b_1'
          r.longer_b_oid = 'longer_b_1'

          r.too_short_b = 'short_b_2'
          r.perfect_b = 'perfect_b_2'
          r.longer_b = 'longer_b_2'

          the_oid = new_oid
          r.perfect_s_oid = the_oid
          r.longer_s_oid = 'longer_s_1'

          r.too_short_s = 'short_s_1'
          r.perfect_s = 'perfect_s_2'
          r.longer_s = 'longer_s'

          r.save!

          r_again = ::Spectable.find(r.id)

          expect(r_again.perfect_b_oid.strip).to eq('perfect_b_1')
          expect(r_again.longer_b_oid.strip).to eq('longer_b_1')

          expect(r_again.too_short_b.strip).to eq('short_b_2')
          expect(r_again.perfect_b.strip).to eq('perfect_b_2')
          expect(r_again.longer_b.strip).to eq('longer_b_2')

          expect(r_again.perfect_s_oid).to be_the_same_objectid_as(the_oid)
          expect(r_again.perfect_s_oid).to be_an_objectid_object
          expect(r_again.longer_s_oid).to eq('longer_s_1')

          expect(r_again.too_short_s).to eq('short_s_1')
          expect(r_again.perfect_s).to eq('perfect_s_2')
          expect(r_again.longer_s).to eq('longer_s')
        end

        it "should allow querying on ObjectId columns via Hash, but not change other queries" do
          r1 = ::Spectable.create!(:perfect_s_oid => (@oid1 = new_oid), :longer_s_oid => "foobar")
          r2 = ::Spectable.create!(:perfect_s_oid => (@oid2 = new_oid), :longer_s_oid => "barfoo")

          expect(::Spectable.where(:perfect_s_oid => @oid1).to_a.map(&:id)).to eq([ r1.id ])
          expect(::Spectable.where(:perfect_s_oid => @oid2).to_a.map(&:id)).to eq([ r2.id ])
          expect(::Spectable.where(:perfect_s_oid => [ @oid1, @oid2 ]).to_a.map(&:id).sort).to eq([ r1.id, r2.id ].sort)
        end
      end

      it "should allow using any column that's long enough, including binary or string columns" do
        ::Spectable.class_eval do
          has_objectid_columns :perfect_b_oid, :longer_b_oid
          has_objectid_columns :perfect_s_oid, :longer_s_oid, :perfect_s, :longer_s
        end

        r = ::Spectable.new

        r.perfect_b_oid = @perfect_b_oid = new_oid
        r.longer_b_oid = @longer_b_oid = new_oid
        r.perfect_s_oid = @perfect_s_oid = new_oid
        r.longer_s_oid = @longer_s_oid = new_oid
        r.perfect_s = @perfect_s = new_oid
        r.longer_s = @longer_s = new_oid

        r.save!

        r_again = ::Spectable.find(r.id)
        expect(r_again.perfect_b_oid).to be_an_objectid_object_matching(@perfect_b_oid)
        expect(r_again.longer_b_oid).to be_an_objectid_object_matching(@longer_b_oid)
        expect(r_again.perfect_s_oid).to be_an_objectid_object_matching(@perfect_s_oid)
        expect(r_again.longer_s_oid).to be_an_objectid_object_matching(@longer_s_oid)
        expect(r_again.perfect_s).to be_an_objectid_object_matching(@perfect_s)
        expect(r_again.longer_s).to be_an_objectid_object_matching(@longer_s)
      end

      it "should automatically pick up any _oid columns" do
        ::Spectable.class_eval do
          has_objectid_columns
        end

        r = ::Spectable.new

        r.perfect_b_oid = @perfect_b_oid = new_oid
        r.longer_b_oid = @longer_b_oid = new_oid

        r.too_short_b = 'short_b_2'
        r.perfect_b = 'perfect_b_2'
        r.longer_b = 'longer_b_2'

        r.perfect_s_oid = @perfect_s_oid = new_oid
        r.longer_s_oid = @longer_s_oid = new_oid

        r.too_short_s = 'short_s_1'
        r.perfect_s = 'perfect_s_2'
        r.longer_s = 'longer_s'

        r.save!

        r_again = ::Spectable.find(r.id)

        expect(r_again.perfect_b_oid).to be_an_objectid_object_matching(@perfect_b_oid)
        expect(r_again.longer_b_oid).to be_an_objectid_object_matching(@longer_b_oid)

        expect(r_again.too_short_b.strip).to eq('short_b_2')
        expect(r_again.perfect_b.strip).to eq('perfect_b_2')
        expect(r_again.longer_b.strip).to eq('longer_b_2')

        r_again.perfect_s_oid.should be_an_objectid_object_matching(@perfect_s_oid)
        r_again.longer_s_oid.should be_an_objectid_object_matching(@longer_s_oid)

        expect(r_again.too_short_s).to eq('short_s_1')
        expect(r_again.perfect_s).to eq('perfect_s_2')
        expect(r_again.longer_s).to eq('longer_s')
      end
    end
  end
end
