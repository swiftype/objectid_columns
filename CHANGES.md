# Change History for ObjectidColumns

### Version 1.0.1: March 7, 2014

* Compatibility with the [`composite_primary_keys`](https://github.com/composite-primary-keys/composite_primary_keys)
  gem, so that you can use object-ID columns as part of a composite primary key.
* Fixed an issue where you could not save an ActiveRecord model that had an ObjectId column as its primary key.
  Implemented this by teaching Arel how to deal with BSON ObjectIds, which should have broader benefits, too.
