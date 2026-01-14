package codename

import (
	"crypto/sha256"
	"encoding/binary"
	"fmt"
	"math/rand"
	"net"
	"os"
	"strings"
	"unicode"

	"github.com/docker/docker/pkg/namesgenerator"
)

// GenerateFromMAC generates a deterministic codename from MAC address
// Returns format: "Adjective Surname" (e.g., "Focused Turing", "Admiring Lovelace")
// Uses Docker's namesgenerator for familiar, memorable names
func GenerateFromMAC() string {
	// Try to get MAC address
	mac, err := getMACAddress()
	if err != nil {
		// Fallback to hostname-based seed if MAC unavailable
		return generateFallback()
	}

	// Hash MAC address to get deterministic seed
	hash := sha256.Sum256([]byte(mac))
	seed := int64(binary.BigEndian.Uint64(hash[:8]))

	// Set random seed for deterministic generation
	rand.Seed(seed)

	// Generate name using Docker's namesgenerator
	// Format: "adjective_surname" (e.g., "focused_turing")
	rawName := namesgenerator.GetRandomName(0)

	// Convert to title case: "Focused Turing"
	return formatName(rawName)
}

// formatName converts "adjective_surname" to "Adjective Surname"
func formatName(raw string) string {
	parts := strings.Split(raw, "_")
	if len(parts) != 2 {
		return titleCase(raw)
	}

	adjective := titleCase(parts[0])
	surname := titleCase(parts[1])

	return fmt.Sprintf("%s %s", adjective, surname)
}

// titleCase converts "word" to "Word"
func titleCase(s string) string {
	if s == "" {
		return s
	}
	r := []rune(s)
	r[0] = unicode.ToUpper(r[0])
	for i := 1; i < len(r); i++ {
		r[i] = unicode.ToLower(r[i])
	}
	return string(r)
}

// GenerateWithUsername generates codename with traditional username
// Returns codename (e.g., "Focused Turing") and username (e.g., "user_1234")
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
// Uses hostname as seed for deterministic generation
func generateFallback() string {
	// Use hostname as backup seed
	hostname := getHostname()
	hash := sha256.Sum256([]byte(hostname))
	seed := int64(binary.BigEndian.Uint64(hash[:8]))

	// Set random seed for deterministic generation
	rand.Seed(seed)

	// Generate name using Docker's namesgenerator
	rawName := namesgenerator.GetRandomName(0)

	return formatName(rawName)
}

// getHostname safely retrieves hostname
func getHostname() string {
	hostname, err := os.Hostname()
	if err != nil || hostname == "" {
		return "unknown-host"
	}
	return hostname
}

// GetMACInfo returns MAC address info for debugging
func GetMACInfo() string {
	mac, err := getMACAddress()
	if err != nil {
		return fmt.Sprintf("MAC: Not available (%v)", err)
	}
	return fmt.Sprintf("MAC: %s", mac)
}
