import mongoose from 'mongoose';

/**
 * Connects to MongoDB. The API keeps working if the database is down; only
 * search history is unavailable, so a failed connection is logged, not fatal.
 */
export async function connectMongo(uri, logger = console) {
  mongoose.set('strictQuery', true);
  mongoose.connection.on('disconnected', () => logger.warn('[mongo] disconnected'));
  mongoose.connection.on('reconnected', () => logger.info('[mongo] reconnected'));
  try {
    await mongoose.connect(uri, { serverSelectionTimeoutMS: 3000 });
    logger.info(`[mongo] connected to ${mongoose.connection.host}:${mongoose.connection.port}/${mongoose.connection.name}`);
    return true;
  } catch (err) {
    logger.warn(`[mongo] not available (${err.message}). Search history is disabled until it comes up.`);
    return false;
  }
}

export const isMongoUp = () => mongoose.connection.readyState === 1;

export async function disconnectMongo() {
  await mongoose.disconnect();
}
