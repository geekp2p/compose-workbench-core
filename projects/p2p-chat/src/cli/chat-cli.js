import readline from 'readline';
import { getNodeInfo } from '../network/p2p-node.js';

/**
 * CLI interface for P2P chat
 */
export class ChatCLI {
  constructor(node, messaging, messageStore) {
    this.node = node;
    this.messaging = messaging;
    this.messageStore = messageStore;
    this.username = `user-${Math.random().toString(36).substr(2, 5)}`;

    this.rl = readline.createInterface({
      input: process.stdin,
      output: process.stdout,
      prompt: `${this.username}> `,
    });
  }

  /**
   * Start the CLI
   */
  start() {
    this.showWelcome();
    this.showHelp();

    // Subscribe to incoming messages
    this.messaging.subscribe(this.handleIncomingMessage.bind(this));

    // Handle user input
    this.rl.on('line', async (input) => {
      await this.handleCommand(input.trim());
      this.rl.prompt();
    });

    this.rl.on('close', () => {
      console.log('\n👋 Goodbye!');
      process.exit(0);
    });

    this.rl.prompt();
  }

  /**
   * Show welcome message
   */
  showWelcome() {
    console.log('\n╔═══════════════════════════════════════════════════╗');
    console.log('║         P2P Chat - Decentralized Messaging        ║');
    console.log('║     No servers • NAT Traversal • Offline Support  ║');
    console.log('╚═══════════════════════════════════════════════════╝\n');

    const info = getNodeInfo(this.node);
    console.log(`🆔 Your Peer ID: ${info.peerIdShort}`);
    console.log(`👤 Username: ${this.username}`);
    console.log(`🌐 Listening on ${info.addresses.length} address(es)`);
    console.log();
  }

  /**
   * Show help message
   */
  showHelp() {
    console.log('Commands:');
    console.log('  /help          - Show this help');
    console.log('  /peers         - List connected peers');
    console.log('  /name <name>   - Change your username');
    console.log('  /history       - Show message history');
    console.log('  /info          - Show node information');
    console.log('  /quit or /exit - Exit the chat');
    console.log('  <message>      - Send a broadcast message');
    console.log();
  }

  /**
   * Handle incoming message
   */
  handleIncomingMessage(message) {
    const { from, username, content, timestamp, type } = message;

    if (type === 'broadcast') {
      const time = new Date(timestamp).toLocaleTimeString();
      const fromShort = from.slice(0, 10) + '...';
      console.log(`\n[${time}] ${username} (${fromShort}): ${content}`);

      // Store the message
      this.messageStore.storeMessage(message);

      this.rl.prompt();
    }
  }

  /**
   * Handle user commands
   */
  async handleCommand(input) {
    if (!input) return;

    // Commands
    if (input.startsWith('/')) {
      const [cmd, ...args] = input.split(' ');

      switch (cmd) {
        case '/help':
          this.showHelp();
          break;

        case '/peers':
          await this.showPeers();
          break;

        case '/name':
          if (args.length > 0) {
            this.username = args.join(' ');
            console.log(`✅ Username changed to: ${this.username}`);
          } else {
            console.log('❌ Usage: /name <username>');
          }
          break;

        case '/history':
          await this.showHistory();
          break;

        case '/info':
          this.showInfo();
          break;

        case '/quit':
        case '/exit':
          this.rl.close();
          break;

        default:
          console.log(`❌ Unknown command: ${cmd}`);
          console.log('   Type /help for available commands');
      }
    } else {
      // Regular message - broadcast to all peers
      const sent = await this.messaging.sendBroadcast(input, this.username);

      if (sent) {
        // Store own message
        await this.messageStore.storeMessage({
          type: 'broadcast',
          content: input,
          username: this.username,
          timestamp: Date.now(),
          from: this.node.peerId.toString(),
        });
      } else {
        console.log('❌ Failed to send message (no peers connected?)');
      }
    }
  }

  /**
   * Show connected peers
   */
  async showPeers() {
    const connections = this.node.getConnections();
    const pubsubPeers = this.messaging.getPeers();

    console.log('\n📊 Peer Information:');
    console.log(`   Connected peers: ${connections.length}`);
    console.log(`   Topic subscribers: ${pubsubPeers.length}`);

    if (connections.length > 0) {
      console.log('\n   Connected:');
      connections.forEach((conn, i) => {
        const peerId = conn.remotePeer.toString();
        console.log(`   ${i + 1}. ${peerId.slice(0, 10)}...`);
      });
    }

    if (pubsubPeers.length > 0) {
      console.log('\n   In chat room:');
      pubsubPeers.forEach((peer, i) => {
        const peerId = peer.toString();
        console.log(`   ${i + 1}. ${peerId.slice(0, 10)}...`);
      });
    }

    if (connections.length === 0 && pubsubPeers.length === 0) {
      console.log('   No peers connected yet. Waiting for discovery...');
    }
    console.log();
  }

  /**
   * Show message history
   */
  async showHistory() {
    console.log('\n📜 Message History (last 50 messages):');
    const messages = await this.messageStore.getAllMessages(50);

    if (messages.length === 0) {
      console.log('   No messages yet.');
    } else {
      messages.forEach((msg) => {
        const time = new Date(msg.timestamp).toLocaleTimeString();
        const fromShort = msg.from.slice(0, 10) + '...';
        console.log(`   [${time}] ${msg.username} (${fromShort}): ${msg.content}`);
      });
    }
    console.log();
  }

  /**
   * Show node information
   */
  showInfo() {
    const info = getNodeInfo(this.node);

    console.log('\n🔍 Node Information:');
    console.log(`   Peer ID: ${info.peerId}`);
    console.log(`   Connections: ${info.connections}`);
    console.log('\n   Listening addresses:');
    info.addresses.forEach((addr) => {
      console.log(`   - ${addr}`);
    });
    console.log();
  }
}
