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

// P2PMessaging handles pub/sub messaging
type P2PMessaging struct {
	ps           *pubsub.PubSub
	topic        *pubsub.Topic
	subscription *pubsub.Subscription
	ctx          context.Context
	selfID       peer.ID
}

// NewP2PMessaging creates a new messaging instance
func NewP2PMessaging(ctx context.Context, ps *pubsub.PubSub, topicName string, selfID peer.ID) (*P2PMessaging, error) {
	// Register a topic validator before joining
	if err := ps.RegisterTopicValidator(topicName, messageValidator); err != nil {
		return nil, fmt.Errorf("failed to register topic validator: %w", err)
	}

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

	return &P2PMessaging{
		ps:           ps,
		topic:        topic,
		subscription: sub,
		ctx:          ctx,
		selfID:       selfID,
	}, nil
}

// messageValidator validates incoming messages
func messageValidator(ctx context.Context, id peer.ID, msg *pubsub.Message) pubsub.ValidationResult {
	// Try to unmarshal the message to validate structure
	var chatMsg Message
	if err := json.Unmarshal(msg.Data, &chatMsg); err != nil {
		// Invalid JSON structure - reject
		return pubsub.ValidationReject
	}

	// Validate message fields
	if chatMsg.Type == "" || chatMsg.Username == "" || chatMsg.Timestamp == 0 {
		// Missing required fields - reject
		return pubsub.ValidationReject
	}

	// Validate message type
	if chatMsg.Type != "message" && chatMsg.Type != "join" && chatMsg.Type != "leave" {
		// Unknown message type - reject
		return pubsub.ValidationReject
	}

	// Message is valid - accept
	return pubsub.ValidationAccept
}

// PublishMessage publishes a message to the topic
func (m *P2PMessaging) PublishMessage(msgType, content, username string) error {
	msg := Message{
		Type:      msgType,
		Content:   content,
		Username:  username,
		Timestamp: time.Now().Unix(),
		From:      m.selfID.String(),
	}

	msgBytes, err := json.Marshal(msg)
	if err != nil {
		return fmt.Errorf("failed to marshal message: %w", err)
	}

	if err := m.topic.Publish(m.ctx, msgBytes); err != nil {
		return fmt.Errorf("failed to publish message: %w", err)
	}

	return nil
}

// ReadMessages returns a channel of incoming messages
func (m *P2PMessaging) ReadMessages() <-chan *Message {
	msgChan := make(chan *Message)

	go func() {
		defer close(msgChan)

		for {
			msg, err := m.subscription.Next(m.ctx)
			if err != nil {
				fmt.Printf("Error reading message: %v\n", err)
				return
			}

			// Skip messages from ourselves
			if msg.ReceivedFrom == m.selfID {
				continue
			}

			// Unmarshal the message
			var chatMsg Message
			if err := json.Unmarshal(msg.Data, &chatMsg); err != nil {
				fmt.Printf("Error unmarshaling message: %v\n", err)
				continue
			}

			// Send to channel
			select {
			case msgChan <- &chatMsg:
			case <-m.ctx.Done():
				return
			}
		}
	}()

	return msgChan
}

// Close closes the messaging resources
func (m *P2PMessaging) Close() error {
	m.subscription.Cancel()
	return m.topic.Close()
}
