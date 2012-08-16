mongoose = require 'mongoose'

Schema = mongoose.Schema
ObjectId = mongoose.ObjectId

TaskSchema = new Schema
  description: String
  bucket: String
  createdAt: Date

exports.Task = mongoose.model 'Task', TaskSchema
