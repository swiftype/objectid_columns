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
    expected = expected.to_bson_id.to_s if expected
    actual = actual.to_bson_id.to_s if actual
    expected == actual
  end
  failure_message_for_should do |actual|
    "expected that #{actual} (#{actual.class}) would be the same ObjectId as #{expected} (#{expected.class})"
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

      context "with a single, manually-defined column" do
        before :each do
          ::Spectable.class_eval { has_objectid_column :perfect_s_oid }
        end

        it "should allow writing and reading via an ObjectId object" do
          the_oid = new_oid

          r = ::Spectable.new
          r.perfect_s_oid = the_oid
          r.perfect_s_oid.should be_the_same_objectid_as(the_oid)
          r.perfect_s_oid.should be_an_objectid_object
          r.save!
          r.perfect_s_oid.should be_the_same_objectid_as(the_oid.to_s)
          r.perfect_s_oid.should be_an_objectid_object

          r_again = ::Spectable.find(r.id)
          r_again.perfect_s_oid.should be_the_same_objectid_as(the_oid.to_s)
          r_again.perfect_s_oid.should be_an_objectid_object
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

          r_again.perfect_b_oid.strip.should == 'perfect_b_1'
          r_again.longer_b_oid.strip.should == 'longer_b_1'

          r_again.too_short_b.strip.should == 'short_b_2'
          r_again.perfect_b.strip.should == 'perfect_b_2'
          r_again.longer_b.strip.should == 'longer_b_2'

          r_again.perfect_s_oid.should be_the_same_objectid_as(the_oid)
          r_again.perfect_s_oid.should be_an_objectid_object
          r_again.longer_s_oid.should == 'longer_s_1'

          r_again.too_short_s.should == 'short_s_1'
          r_again.perfect_s.should == 'perfect_s_2'
          r_again.longer_s.should == 'longer_s'
        end
      end
    end
  end
end
