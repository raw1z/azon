mongoose = require 'mongoose'

Schema = mongoose.Schema
ObjectId = mongoose.ObjectId

TaskSchema = new Schema
  description: String
  bucket: String
  createdAt: Date
  updatedAt: Date

TaskSchema.pre 'save', (next) ->
  @updatedAt = new Date()
  next()

exports.Task = mongoose.model 'Task', TaskSchema
