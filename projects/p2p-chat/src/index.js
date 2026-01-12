import { createP2PNode } from './network/p2p-node.js';
import { P2PMessaging } from './messaging/pubsub.js';
import { MessageStore } from './storage/message-store.js';
import { ChatCLI } from './cli/chat-cli.js';

/**
 * Main entry point for P2P Chat
 */
async function main() {
  try {
    console.log('🚀 Starting P2P Chat...\n');

    // 1. Initialize message store
    console.log('💾 Initializing message store...');
    const messageStore = new MessageStore();

    // 2. Create libp2p node
    console.log('🌐 Creating P2P node...');
    const node = await createP2PNode();

    // 3. Start the node
    console.log('▶️  Starting node...');
    await node.start();

    // 4. Get the topic from environment or use default
    const topic = process.env.CHAT_TOPIC || 'p2p-chat-default';

    // 5. Initialize messaging
    console.log(`📡 Initializing messaging (topic: ${topic})...`);
    const messaging = new P2PMessaging(node, topic);

    // 6. Start CLI
    console.log('🖥️  Starting CLI...\n');
    const cli = new ChatCLI(node, messaging, messageStore);
    cli.start();

    // Handle graceful shutdown
    process.on('SIGINT', async () => {
      console.log('\n\n🛑 Shutting down...');
      await messageStore.close();
      await node.stop();
      process.exit(0);
    });

  } catch (error) {
    console.error('❌ Fatal error:', error);
    process.exit(1);
  }
}

main();
