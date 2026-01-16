package storage

import (
	"encoding/json"
	"fmt"
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

// MessageStore handles message persistence
type MessageStore struct {
	db *badger.DB
}

// NewMessageStore creates a new message store
func NewMessageStore(dataDir string) (*MessageStore, error) {
	opts := badger.DefaultOptions(dataDir)
	opts.Logger = nil // Disable badger logging

	db, err := badger.Open(opts)
	if err != nil {
		return nil, fmt.Errorf("failed to open database: %w", err)
	}

	return &MessageStore{db: db}, nil
}

// SaveMessage saves a message to the store
func (s *MessageStore) SaveMessage(msg *Message) error {
	return s.db.Update(func(txn *badger.Txn) error {
		key := fmt.Sprintf("msg_%d_%s", msg.Timestamp, msg.From)
		data, err := json.Marshal(msg)
		if err != nil {
			return err
		}
		return txn.Set([]byte(key), data)
	})
}

// GetRecentMessages returns the N most recent messages
func (s *MessageStore) GetRecentMessages(limit int) ([]*Message, error) {
	var messages []*Message

	err := s.db.View(func(txn *badger.Txn) error {
		opts := badger.DefaultIteratorOptions
		opts.Reverse = true // Iterate in reverse (newest first)

		it := txn.NewIterator(opts)
		defer it.Close()

		prefix := []byte("msg_")
		count := 0

		for it.Seek([]byte("msg_~")); it.ValidForPrefix(prefix) && count < limit; it.Next() {
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
			count++
		}
		return nil
	})

	if err != nil {
		return nil, err
	}

	// Reverse to get chronological order
	sort.Slice(messages, func(i, j int) bool {
		return messages[i].Timestamp < messages[j].Timestamp
	})

	return messages, nil
}

// Clear removes all messages from the store
func (s *MessageStore) Clear() error {
	return s.db.DropAll()
}

// ClearAllMessages removes all messages from the store (alias for Clear)
func (s *MessageStore) ClearAllMessages() (int, error) {
	count, err := s.GetMessageCount()
	if err != nil {
		return 0, err
	}

	if err := s.Clear(); err != nil {
		return 0, err
	}

	return count, nil
}

// ClearOldMessages removes messages older than the specified number of days
func (s *MessageStore) ClearOldMessages(days int) (int, error) {
	if days <= 0 {
		return 0, fmt.Errorf("days must be greater than 0")
	}

	cutoffTime := time.Now().AddDate(0, 0, -days).Unix()
	deletedCount := 0

	err := s.db.Update(func(txn *badger.Txn) error {
		opts := badger.DefaultIteratorOptions
		it := txn.NewIterator(opts)
		defer it.Close()

		prefix := []byte("msg_")
		var keysToDelete [][]byte

		// Collect keys to delete
		for it.Seek(prefix); it.ValidForPrefix(prefix); it.Next() {
			item := it.Item()
			key := item.Key()

			// Get the message to check timestamp
			err := item.Value(func(val []byte) error {
				var msg Message
				if err := json.Unmarshal(val, &msg); err != nil {
					return err
				}

				// If message is older than cutoff, mark for deletion
				if msg.Timestamp < cutoffTime {
					keysToDelete = append(keysToDelete, append([]byte{}, key...))
				}
				return nil
			})
			if err != nil {
				return err
			}
		}

		// Delete collected keys
		for _, key := range keysToDelete {
			if err := txn.Delete(key); err != nil {
				return err
			}
			deletedCount++
		}

		return nil
	})

	if err != nil {
		return 0, err
	}

	return deletedCount, nil
}

// GetMessageCount returns the total number of messages in the store
func (s *MessageStore) GetMessageCount() (int, error) {
	count := 0

	err := s.db.View(func(txn *badger.Txn) error {
		opts := badger.DefaultIteratorOptions
		opts.PrefetchValues = false // We only need keys

		it := txn.NewIterator(opts)
		defer it.Close()

		prefix := []byte("msg_")
		for it.Seek(prefix); it.ValidForPrefix(prefix); it.Next() {
			count++
		}
		return nil
	})

	if err != nil {
		return 0, err
	}

	return count, nil
}

// Close closes the database
func (s *MessageStore) Close() error {
	return s.db.Close()
}

// FormatTimestamp formats a Unix timestamp for display
func FormatTimestamp(ts int64) string {
	t := time.Unix(ts, 0)
	now := time.Now()

	// If message is from today, show time only
	if t.YearDay() == now.YearDay() && t.Year() == now.Year() {
		return t.Format("15:04:05")
	}

	// Otherwise show date and time
	return t.Format("2006-01-02 15:04")
}
