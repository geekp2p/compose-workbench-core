package storage

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"time"

	badger "github.com/dgraph-io/badger/v4"
)

// Message represents a stored message
type Message struct {
	Type      string `json:"type"`
	Content   string `json:"content"`
	Username  string `json:"username"`
	Timestamp int64  `json:"timestamp"`
	From      string `json:"from"`
}

// MessageStore handles message persistence using BadgerDB
type MessageStore struct {
	db *badger.DB
}

// NewMessageStore creates a new message store
func NewMessageStore(dataDir string) (*MessageStore, error) {
	// Create data directory if it doesn't exist
	if err := os.MkdirAll(dataDir, 0755); err != nil {
		return nil, fmt.Errorf("failed to create data directory: %w", err)
	}

	// Open BadgerDB
	dbPath := filepath.Join(dataDir, "messages")
	opts := badger.DefaultOptions(dbPath).WithLogger(nil) // Disable logging

	db, err := badger.Open(opts)
	if err != nil {
		return nil, fmt.Errorf("failed to open database: %w", err)
	}

	fmt.Printf("💾 Message store initialized at: %s\n", dbPath)

	return &MessageStore{db: db}, nil
}

// StoreMessage stores a message in the database
func (s *MessageStore) StoreMessage(msg *Message) error {
	// Generate key: msg-<timestamp>-<random>
	key := fmt.Sprintf("msg-%d-%d", msg.Timestamp, time.Now().UnixNano())

	// Marshal message to JSON
	data, err := json.Marshal(msg)
	if err != nil {
		return fmt.Errorf("failed to marshal message: %w", err)
	}

	// Store in database
	err = s.db.Update(func(txn *badger.Txn) error {
		return txn.Set([]byte(key), data)
	})

	if err != nil {
		return fmt.Errorf("failed to store message: %w", err)
	}

	return nil
}

// GetAllMessages retrieves all messages (up to limit)
func (s *MessageStore) GetAllMessages(limit int) ([]*Message, error) {
	var messages []*Message

	err := s.db.View(func(txn *badger.Txn) error {
		opts := badger.DefaultIteratorOptions
		opts.PrefetchSize = limit
		it := txn.NewIterator(opts)
		defer it.Close()

		for it.Rewind(); it.Valid(); it.Next() {
			item := it.Item()

			err := item.Value(func(val []byte) error {
				var msg Message
				if err := json.Unmarshal(val, &msg); err != nil {
					return err
				}
				messages = append(messages, &msg)
				return nil
			})

			if err != nil {
				return err
			}

			if len(messages) >= limit {
				break
			}
		}
		return nil
	})

	if err != nil {
		return nil, fmt.Errorf("failed to get messages: %w", err)
	}

	// Sort messages by timestamp (oldest first)
	sort.Slice(messages, func(i, j int) bool {
		return messages[i].Timestamp < messages[j].Timestamp
	})

	// Return only the last 'limit' messages
	if len(messages) > limit {
		messages = messages[len(messages)-limit:]
	}

	return messages, nil
}

// GetMessagesSince retrieves messages after a specific timestamp
func (s *MessageStore) GetMessagesSince(timestamp int64) ([]*Message, error) {
	var messages []*Message

	err := s.db.View(func(txn *badger.Txn) error {
		opts := badger.DefaultIteratorOptions
		it := txn.NewIterator(opts)
		defer it.Close()

		for it.Rewind(); it.Valid(); it.Next() {
			item := it.Item()

			err := item.Value(func(val []byte) error {
				var msg Message
				if err := json.Unmarshal(val, &msg); err != nil {
					return err
				}

				if msg.Timestamp > timestamp {
					messages = append(messages, &msg)
				}
				return nil
			})

			if err != nil {
				return err
			}
		}
		return nil
	})

	if err != nil {
		return nil, fmt.Errorf("failed to get messages since: %w", err)
	}

	return messages, nil
}

// DeleteOldMessages deletes messages older than the specified timestamp
func (s *MessageStore) DeleteOldMessages(olderThan int64) (int, error) {
	var keysToDelete [][]byte

	// Find keys to delete
	err := s.db.View(func(txn *badger.Txn) error {
		opts := badger.DefaultIteratorOptions
		it := txn.NewIterator(opts)
		defer it.Close()

		for it.Rewind(); it.Valid(); it.Next() {
			item := it.Item()
			key := item.Key()

			err := item.Value(func(val []byte) error {
				var msg Message
				if err := json.Unmarshal(val, &msg); err != nil {
					return err
				}

				if msg.Timestamp < olderThan {
					keysToDelete = append(keysToDelete, append([]byte{}, key...))
				}
				return nil
			})

			if err != nil {
				return err
			}
		}
		return nil
	})

	if err != nil {
		return 0, fmt.Errorf("failed to find old messages: %w", err)
	}

	// Delete keys
	err = s.db.Update(func(txn *badger.Txn) error {
		for _, key := range keysToDelete {
			if err := txn.Delete(key); err != nil {
				return err
			}
		}
		return nil
	})

	if err != nil {
		return 0, fmt.Errorf("failed to delete old messages: %w", err)
	}

	return len(keysToDelete), nil
}

// Close closes the database
func (s *MessageStore) Close() error {
	return s.db.Close()
}
