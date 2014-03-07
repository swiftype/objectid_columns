# Change History for ObjectidColumns

### Version 1.0.1: March 6, 2014

* Fixed an issue where you could not save an ActiveRecord model that had an ObjectId column as its primary key.
  Implemented this by teaching Arel how to deal with BSON ObjectIds, which should have broader benefits, too.
