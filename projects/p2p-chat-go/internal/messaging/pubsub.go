package messaging

import (
	"context"
	"encoding/json"
	"fmt"
	"time"

	pubsub "github.com/libp2p/go-libp2p-pubsub"
	"github.com/libp2p/go-libp2p/core/peer"
)

// Message represents a chat message
type Message struct {
	Type      string `json:"type"`
	Content   string `json:"content"`
	Username  string `json:"username"`
	Timestamp int64  `json:"timestamp"`
	From      string `json:"from,omitempty"`
}

// P2PMessaging handles PubSub messaging for a topic
type P2PMessaging struct {
	pubsub *pubsub.PubSub
	topic  *pubsub.Topic
	sub    *pubsub.Subscription
	ctx    context.Context
}

// NewP2PMessaging creates a new messaging instance
func NewP2PMessaging(ctx context.Context, ps *pubsub.PubSub, topicName string) (*P2PMessaging, error) {
	// Join the topic
	topic, err := ps.Join(topicName)
	if err != nil {
		return nil, fmt.Errorf("failed to join topic: %w", err)
	}

	// Subscribe to the topic
	sub, err := topic.Subscribe()
	if err != nil {
		return nil, fmt.Errorf("failed to subscribe to topic: %w", err)
	}

	fmt.Printf("📡 Subscribed to topic: %s\n", topicName)

	return &P2PMessaging{
		pubsub: ps,
		topic:  topic,
		sub:    sub,
		ctx:    ctx,
	}, nil
}

// Publish publishes a message to the topic
func (m *P2PMessaging) Publish(msg *Message) error {
	data, err := json.Marshal(msg)
	if err != nil {
		return fmt.Errorf("failed to marshal message: %w", err)
	}

	if err := m.topic.Publish(m.ctx, data); err != nil {
		return fmt.Errorf("failed to publish message: %w", err)
	}

	return nil
}

// SendBroadcast sends a broadcast message
func (m *P2PMessaging) SendBroadcast(content, username string) error {
	msg := &Message{
		Type:      "broadcast",
		Content:   content,
		Username:  username,
		Timestamp: time.Now().UnixMilli(),
	}

	return m.Publish(msg)
}

// ReceiveMessages continuously receives messages from the topic
func (m *P2PMessaging) ReceiveMessages(handler func(*Message)) {
	go func() {
		for {
			msg, err := m.sub.Next(m.ctx)
			if err != nil {
				// Context canceled or subscription closed
				return
			}

			// Parse message
			var chatMsg Message
			if err := json.Unmarshal(msg.Data, &chatMsg); err != nil {
				fmt.Printf("⚠️  Failed to parse message: %v\n", err)
				continue
			}

			// Add sender info
			chatMsg.From = msg.ReceivedFrom.String()

			// Call handler
			handler(&chatMsg)
		}
	}()
}

// GetPeers returns the list of peers subscribed to the topic
func (m *P2PMessaging) GetPeers() []peer.ID {
	return m.topic.ListPeers()
}

// GetPeerCount returns the number of peers in the topic
func (m *P2PMessaging) GetPeerCount() int {
	return len(m.GetPeers())
}

// Close closes the messaging
func (m *P2PMessaging) Close() error {
	m.sub.Cancel()
	return m.topic.Close()
}
