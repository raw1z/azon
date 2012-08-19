mongoose = require 'mongoose'

Schema = mongoose.Schema
ObjectId = mongoose.ObjectId

UserSchema = new Schema
  username: String
  salt: String
  hash: String

exports.User = mongoose.model 'User', UserSchema
