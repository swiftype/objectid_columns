require 'objectid_columns'
require 'bson'
require 'moped'
require 'objectid_columns/helpers/system_helpers'
require 'objectid_columns/helpers/database_helper'

RSpec::Matchers.define :be_an_objectid_object do
  match do |actual|
    actual.kind_of?(BSON::ObjectId) || actual.kind_of?(Moped::BSON::ObjectId)
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
    (net_expected == net_actual) && (actual.kind_of?(BSON::ObjectId) || actual.kind_of?(Moped::BSON::ObjectId))
  end
  failure_message_for_should do |actual|
    "expected that #{actual} (#{actual.class}) would be an ObjectId object equal to #{expected} (#{expected.class})"
  end
end

describe "ObjectidColumns basic operations" do
  include ObjectidColumns::Helpers::SystemHelpers

  before :each do
    @dh = ObjectidColumns::Helpers::DatabaseHelper.new
    @dh.setup_activerecord!

    create_standard_system_spec_tables!
    create_standard_system_spec_models!
  end

  after :each do
    drop_standard_system_spec_tables!
  end

  [ BSON::ObjectId, Moped::BSON::ObjectId ].each do |test_class|
    context "using test class #{test_class}" do
      before :each do
        @tc = test_class
      end

      def new_oid
        @tc.new
      end

      it "should not allow defining a column that's too short" do
        expect { ::Spectable.class_eval { has_objectid_column :too_short_b } }.to raise_error(ArgumentError)
        expect { ::Spectable.class_eval { has_objectid_column :too_short_s } }.to raise_error(ArgumentError)
      end

      it "should not allow defining a column that's the wrong type" do
        expect { ::Spectable.class_eval { has_objectid_column :some_int_column } }.to raise_error(ArgumentError)
      end

      it "should not fail if the table doesn't exist" do
        define_model_class(:SpectableNonexistent, 'objectidcols_spec_table_nonexistent') { }
        expect { ::SpectableNonexistent.class_eval { has_objectid_column :foo } }.to_not raise_error
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

        it "should not allow assigning binary strings unless their encoding is BINARY" do
          r = ::Spectable.new

          binary = new_oid.to_binary
          binary = binary.force_encoding(Encoding::ISO_8859_1)
          expect { r.perfect_s_oid = binary }.to raise_error(ArgumentError)
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
          r = ::Spectable.create!(:perfect_s_oid => (@oid = BSON::ObjectId.new))
          expect(::Spectable.find(r.id).perfect_s_oid).to be_an_objectid_object_matching(@oid)

          r = ::Spectable.create!(:perfect_s_oid => (@oid = Moped::BSON::ObjectId.new))
          expect(::Spectable.find(r.id).perfect_s_oid).to be_an_objectid_object_matching(@oid)

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
