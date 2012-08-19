mongoose = require 'mongoose'

Schema = mongoose.Schema
ObjectId = mongoose.ObjectId

TaskSchema = new Schema
  description: String
  bucket: String
  createdAt: Date
  updatedAt: Date
  _owner:
    type: Schema.Types.ObjectId
    ref: 'User'

TaskSchema.pre 'save', (next) ->
  @updatedAt = new Date()
  next()

exports.Task = mongoose.model 'Task', TaskSchema
