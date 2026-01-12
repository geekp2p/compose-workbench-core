import { Level } from 'level';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

/**
 * Message store using LevelDB for persistence
 * Stores messages for offline peers and message history
 */
export class MessageStore {
  constructor(dbPath = path.join(__dirname, '../../data/messages')) {
    this.db = new Level(dbPath, { valueEncoding: 'json' });
  }

  /**
   * Store a message
   */
  async storeMessage(message) {
    const key = `msg-${message.timestamp}-${Math.random().toString(36).substr(2, 9)}`;
    try {
      await this.db.put(key, message);
      return key;
    } catch (error) {
      console.error('Failed to store message:', error);
      return null;
    }
  }

  /**
   * Get all messages (for history)
   */
  async getAllMessages(limit = 100) {
    const messages = [];
    try {
      for await (const [key, value] of this.db.iterator({ limit, reverse: true })) {
        messages.push({ key, ...value });
      }
      return messages.reverse(); // Show oldest first
    } catch (error) {
      console.error('Failed to get messages:', error);
      return [];
    }
  }

  /**
   * Get messages after a specific timestamp
   */
  async getMessagesSince(timestamp) {
    const messages = [];
    try {
      for await (const [key, value] of this.db.iterator()) {
        if (value.timestamp > timestamp) {
          messages.push({ key, ...value });
        }
      }
      return messages;
    } catch (error) {
      console.error('Failed to get messages since:', error);
      return [];
    }
  }

  /**
   * Delete old messages (cleanup)
   */
  async deleteOldMessages(olderThan) {
    const toDelete = [];
    try {
      for await (const [key, value] of this.db.iterator()) {
        if (value.timestamp < olderThan) {
          toDelete.push(key);
        }
      }

      for (const key of toDelete) {
        await this.db.del(key);
      }

      return toDelete.length;
    } catch (error) {
      console.error('Failed to delete old messages:', error);
      return 0;
    }
  }

  /**
   * Close the database
   */
  async close() {
    await this.db.close();
  }
}
