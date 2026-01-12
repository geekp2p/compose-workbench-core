import { createLibp2p } from 'libp2p';
import { tcp } from '@libp2p/tcp';
import { noise } from '@chainsafe/libp2p-noise';
import { mplex } from '@libp2p/mplex';
import { gossipsub } from '@chainsafe/libp2p-gossipsub';
import { kadDHT } from '@libp2p/kad-dht';
import { mdns } from '@libp2p/mdns';
import { bootstrap } from '@libp2p/bootstrap';
import { identify } from '@libp2p/identify';
import { circuitRelayTransport } from '@libp2p/circuit-relay-v2';
import { dcutr } from '@libp2p/dcutr';

/**
 * Create a libp2p node with full P2P capabilities:
 * - NAT Traversal (Circuit Relay + DCUtR)
 * - Local Discovery (mDNS)
 * - Global Discovery (DHT)
 * - PubSub Messaging (GossipSub)
 */
export async function createP2PNode() {
  // Bootstrap nodes for initial peer discovery
  const bootstrapPeers = [
    '/dnsaddr/bootstrap.libp2p.io/p2p/QmNnooDu7bfjPFoTZYxMNLWUQJyrVwtbZg5gBMjTezGAJN',
    '/dnsaddr/bootstrap.libp2p.io/p2p/QmQCU2EcMqAqQPR2i9bChDtGNJchTbq5TbXJJ16u19uLTa',
    '/dnsaddr/bootstrap.libp2p.io/p2p/QmbLHAnMoJPWSCR5Zhtx6BHJX9KiKNN6tpvbUcqanj75Nb',
    '/dnsaddr/bootstrap.libp2p.io/p2p/QmcZf59bWwK5XFi76CZX8cbJ4BhTzzA3gU1ZjYZcYW3dwt',
  ];

  const node = await createLibp2p({
    addresses: {
      listen: [
        '/ip4/0.0.0.0/tcp/0',              // Random TCP port
        '/ip4/0.0.0.0/tcp/0/ws',            // Random WebSocket port
      ]
    },
    transports: [
      tcp(),
      circuitRelayTransport({              // Circuit Relay for NAT traversal
        discoverRelays: 2,
      }),
    ],
    connectionEncryption: [noise()],       // Noise protocol for encryption
    streamMuxers: [mplex()],               // Multiplex streams
    peerDiscovery: [
      mdns({                               // Local network discovery
        interval: 1000,
      }),
      bootstrap({                          // Bootstrap nodes
        list: bootstrapPeers,
      }),
    ],
    services: {
      identify: identify(),                // Peer identification
      dht: kadDHT({                        // Distributed Hash Table
        clientMode: false,                 // Act as DHT server
      }),
      pubsub: gossipsub({                  // PubSub for messaging
        allowPublishToZeroPeers: true,
        emitSelf: false,                   // Don't echo own messages
      }),
      dcutr: dcutr(),                      // Direct Connection Upgrade through Relay
    },
  });

  // Log peer discovery events
  node.addEventListener('peer:discovery', (evt) => {
    const peer = evt.detail;
    console.log(`🔍 Discovered peer: ${peer.id.toString().slice(0, 10)}...`);
  });

  // Log connection events
  node.addEventListener('peer:connect', (evt) => {
    const connection = evt.detail;
    console.log(`🤝 Connected to: ${connection.remotePeer.toString().slice(0, 10)}...`);
  });

  // Log disconnection events
  node.addEventListener('peer:disconnect', (evt) => {
    const connection = evt.detail;
    console.log(`👋 Disconnected from: ${connection.remotePeer.toString().slice(0, 10)}...`);
  });

  return node;
}

/**
 * Get node information for display
 */
export function getNodeInfo(node) {
  const peerId = node.peerId.toString();
  const addresses = node.getMultiaddrs().map(ma => ma.toString());
  const connections = node.getConnections().length;

  return {
    peerId,
    peerIdShort: peerId.slice(0, 10) + '...',
    addresses,
    connections,
  };
}
