package codename

import (
	"crypto/sha256"
	"encoding/binary"
	"fmt"
	"net"
)

// Word lists for generating codenames
var adjectives = []string{
	"Swift", "Brave", "Mighty", "Silent", "Golden",
	"Silver", "Crimson", "Azure", "Jade", "Amber",
	"Shadow", "Thunder", "Lightning", "Storm", "Frost",
	"Fire", "Iron", "Steel", "Diamond", "Crystal",
	"Noble", "Royal", "Ancient", "Mystic", "Cosmic",
	"Blazing", "Radiant", "Glowing", "Shining", "Bright",
	"Dark", "Wild", "Free", "Bold", "Fierce",
	"Wise", "Clever", "Swift", "Quick", "Rapid",
	"Strong", "Tough", "Solid", "Steady", "Calm",
	"Serene", "Peaceful", "Gentle", "Kind", "Pure",
}

var nouns = []string{
	"Falcon", "Eagle", "Hawk", "Phoenix", "Dragon",
	"Tiger", "Lion", "Wolf", "Bear", "Panther",
	"Leopard", "Jaguar", "Cheetah", "Lynx", "Fox",
	"Raven", "Owl", "Sparrow", "Robin", "Swan",
	"Shark", "Whale", "Dolphin", "Orca", "Seal",
	"Warrior", "Knight", "Guardian", "Sentinel", "Protector",
	"Hunter", "Scout", "Ranger", "Explorer", "Voyager",
	"Star", "Moon", "Sun", "Comet", "Nova",
	"Mountain", "River", "Ocean", "Forest", "Desert",
	"Wind", "Rain", "Snow", "Cloud", "Mist",
}

// GenerateFromMAC generates a deterministic codename from MAC address
// Returns format: "Adjective Noun" (e.g., "Swift Falcon")
func GenerateFromMAC() string {
	// Try to get MAC address
	mac, err := getMACAddress()
	if err != nil {
		// Fallback to random if MAC unavailable (use hostname as seed)
		return generateFallback()
	}

	// Hash the MAC address to get a deterministic seed
	hash := sha256.Sum256([]byte(mac))
	seed := binary.BigEndian.Uint64(hash[:8])

	// Use seed to pick words deterministically
	adjIndex := int(seed % uint64(len(adjectives)))
	nounIndex := int((seed >> 32) % uint64(len(nouns)))

	return fmt.Sprintf("%s %s", adjectives[adjIndex], nouns[nounIndex])
}

// GenerateWithUsername generates codename with traditional username
// Returns format: "Swift Falcon (user_1234)"
func GenerateWithUsername() (codename string, username string) {
	codename = GenerateFromMAC()

	// Generate username from same MAC for consistency
	mac, err := getMACAddress()
	if err != nil {
		username = "user_0000"
	} else {
		hash := sha256.Sum256([]byte(mac))
		userNum := binary.BigEndian.Uint32(hash[8:12]) % 10000
		username = fmt.Sprintf("user_%04d", userNum)
	}

	return codename, username
}

// getMACAddress retrieves the first non-loopback MAC address
func getMACAddress() (string, error) {
	interfaces, err := net.Interfaces()
	if err != nil {
		return "", err
	}

	for _, iface := range interfaces {
		// Skip loopback, virtual, and interfaces without MAC
		if iface.Flags&net.FlagLoopback != 0 ||
		   iface.HardwareAddr == nil ||
		   len(iface.HardwareAddr) == 0 {
			continue
		}

		// Skip virtual interfaces (common patterns)
		name := iface.Name
		if isVirtualInterface(name) {
			continue
		}

		// Found a physical MAC address
		return iface.HardwareAddr.String(), nil
	}

	return "", fmt.Errorf("no suitable MAC address found")
}

// isVirtualInterface checks if interface name suggests it's virtual
func isVirtualInterface(name string) bool {
	virtualPrefixes := []string{
		"veth", "docker", "br-", "vboxnet", "vmnet",
		"virbr", "vnet", "tap", "tun", "lo",
	}

	for _, prefix := range virtualPrefixes {
		if len(name) >= len(prefix) && name[:len(prefix)] == prefix {
			return true
		}
	}
	return false
}

// generateFallback generates a codename when MAC is unavailable
// Uses hostname or random seed
func generateFallback() string {
	// Use hostname as backup seed
	hostname := getHostname()
	hash := sha256.Sum256([]byte(hostname))
	seed := binary.BigEndian.Uint64(hash[:8])

	adjIndex := int(seed % uint64(len(adjectives)))
	nounIndex := int((seed >> 32) % uint64(len(nouns)))

	return fmt.Sprintf("%s %s", adjectives[adjIndex], nouns[nounIndex])
}

// getHostname safely retrieves hostname
func getHostname() string {
	hostname, err := net.LookupHost("localhost")
	if err != nil || len(hostname) == 0 {
		return "unknown-host"
	}
	return hostname[0]
}

// GetMACInfo returns MAC address info for debugging
func GetMACInfo() string {
	mac, err := getMACAddress()
	if err != nil {
		return fmt.Sprintf("MAC: Not available (%v)", err)
	}
	return fmt.Sprintf("MAC: %s", mac)
}
