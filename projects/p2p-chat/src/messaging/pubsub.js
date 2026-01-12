import { toString as uint8ArrayToString } from 'uint8arrays/to-string';
import { fromString as uint8ArrayFromString } from 'uint8arrays/from-string';

/**
 * Initialize PubSub messaging for a topic
 */
export class P2PMessaging {
  constructor(node, topic = 'p2p-chat-default') {
    this.node = node;
    this.topic = topic;
    this.messageHandlers = [];
  }

  /**
   * Subscribe to messages in the topic
   */
  subscribe(handler) {
    this.messageHandlers.push(handler);

    // Subscribe to the topic
    this.node.services.pubsub.subscribe(this.topic);

    // Handle incoming messages
    this.node.services.pubsub.addEventListener('message', (evt) => {
      if (evt.detail.topic !== this.topic) return;

      try {
        const message = JSON.parse(uint8ArrayToString(evt.detail.data));
        const from = evt.detail.from.toString();

        // Call all registered handlers
        this.messageHandlers.forEach(h => h({ ...message, from }));
      } catch (error) {
        console.error('Failed to parse message:', error);
      }
    });

    console.log(`📡 Subscribed to topic: ${this.topic}`);
  }

  /**
   * Publish a message to the topic
   */
  async publish(message) {
    try {
      const data = uint8ArrayFromString(JSON.stringify(message));
      await this.node.services.pubsub.publish(this.topic, data);
      return true;
    } catch (error) {
      console.error('Failed to publish message:', error);
      return false;
    }
  }

  /**
   * Send a broadcast message
   */
  async sendBroadcast(content, username) {
    const message = {
      type: 'broadcast',
      content,
      username,
      timestamp: Date.now(),
    };

    return await this.publish(message);
  }

  /**
   * Get list of peers subscribed to the topic
   */
  getPeers() {
    try {
      return this.node.services.pubsub.getSubscribers(this.topic);
    } catch {
      return [];
    }
  }

  /**
   * Get count of peers in the topic
   */
  getPeerCount() {
    return this.getPeers().length;
  }
}
