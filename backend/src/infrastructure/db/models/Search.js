import mongoose from 'mongoose';

const placeSchema = new mongoose.Schema(
  {
    name: { type: String, required: true, maxlength: 200 },
    address: { type: String, default: '', maxlength: 300 },
    lat: { type: Number, required: true, min: -90, max: 90 },
    lng: { type: Number, required: true, min: -180, max: 180 },
  },
  { _id: false },
);

/** One comparison a user ran. Kept for 30 days (TTL index) to power "recent searches". */
const searchSchema = new mongoose.Schema(
  {
    pickup: { type: placeSchema, required: true },
    drop: { type: placeSchema, required: true },
    distanceKm: Number,
    durationMin: Number,
    optionCount: Number,
    cheapest: { provider: String, productName: String, fareMin: Number },
    dataMode: { type: String, enum: ['demo', 'live', 'mixed'] },
    createdAt: { type: Date, default: Date.now, expires: 60 * 60 * 24 * 30 },
  },
  { versionKey: false },
);

searchSchema.index({ createdAt: -1 });

export const Search = mongoose.models.Search ?? mongoose.model('Search', searchSchema);
