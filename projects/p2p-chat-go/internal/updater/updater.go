package updater

import (
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"runtime"
	"strconv"
	"strings"
	"time"
)

const (
	githubRepo = "geekp2p/compose-workbench-core"
	releasesAPI = "https://api.github.com/repos/" + githubRepo + "/releases/latest"
)

// ReleaseInfo contains information about a GitHub release
type ReleaseInfo struct {
	TagName string `json:"tag_name"`
	Name    string `json:"name"`
	Body    string `json:"body"`
	Assets  []struct {
		Name               string `json:"name"`
		BrowserDownloadURL string `json:"browser_download_url"`
	} `json:"assets"`
}

// CheckForUpdate checks if a newer version is available
func CheckForUpdate(currentVersion string) (*ReleaseInfo, bool, error) {
	// Skip check if version is "dev"
	if currentVersion == "dev" {
		return nil, false, nil
	}

	client := &http.Client{Timeout: 10 * time.Second}
	resp, err := client.Get(releasesAPI)
	if err != nil {
		return nil, false, fmt.Errorf("failed to check for updates: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, false, fmt.Errorf("GitHub API returned status %d", resp.StatusCode)
	}

	var release ReleaseInfo
	if err := json.NewDecoder(resp.Body).Decode(&release); err != nil {
		return nil, false, fmt.Errorf("failed to parse release info: %w", err)
	}

	// Compare versions
	latestVer := strings.TrimPrefix(release.TagName, "v")
	currentVer := strings.TrimPrefix(currentVersion, "v")

	hasUpdate := compareVersions(latestVer, currentVer) > 0
	return &release, hasUpdate, nil
}

// DownloadAndUpdate downloads the latest release and replaces the current binary
func DownloadAndUpdate(release *ReleaseInfo) error {
	// Find the appropriate asset for current platform
	assetName := getBinaryName()
	var downloadURL string

	for _, asset := range release.Assets {
		if asset.Name == assetName {
			downloadURL = asset.BrowserDownloadURL
			break
		}
	}

	if downloadURL == "" {
		return fmt.Errorf("no binary found for %s/%s", runtime.GOOS, runtime.GOARCH)
	}

	fmt.Printf("Downloading %s from %s...\n", assetName, release.TagName)

	// Download the new binary
	client := &http.Client{Timeout: 60 * time.Second}
	resp, err := client.Get(downloadURL)
	if err != nil {
		return fmt.Errorf("failed to download update: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("download failed with status %d", resp.StatusCode)
	}

	// Create temporary file
	tmpFile, err := os.CreateTemp("", "p2p-chat-*")
	if err != nil {
		return fmt.Errorf("failed to create temp file: %w", err)
	}
	tmpPath := tmpFile.Name()
	defer os.Remove(tmpPath)

	// Write downloaded binary to temp file
	_, err = io.Copy(tmpFile, resp.Body)
	tmpFile.Close()
	if err != nil {
		return fmt.Errorf("failed to write temp file: %w", err)
	}

	// Make it executable
	if err := os.Chmod(tmpPath, 0755); err != nil {
		return fmt.Errorf("failed to make binary executable: %w", err)
	}

	// Get current executable path
	execPath, err := os.Executable()
	if err != nil {
		return fmt.Errorf("failed to get executable path: %w", err)
	}

	// Backup current binary
	backupPath := execPath + ".backup"
	if err := os.Rename(execPath, backupPath); err != nil {
		return fmt.Errorf("failed to backup current binary: %w", err)
	}

	// Move new binary to replace old one
	if err := os.Rename(tmpPath, execPath); err != nil {
		// Restore backup if move fails
		os.Rename(backupPath, execPath)
		return fmt.Errorf("failed to replace binary: %w", err)
	}

	// Remove backup
	os.Remove(backupPath)

	fmt.Printf("✓ Successfully updated to version %s\n", release.TagName)
	fmt.Println("Please restart the application for changes to take effect.")

	return nil
}

// getBinaryName returns the expected binary name for the current platform
func getBinaryName() string {
	goos := runtime.GOOS
	goarch := runtime.GOARCH

	baseName := "p2p-chat"

	// Windows needs .exe extension
	if goos == "windows" {
		return fmt.Sprintf("%s-%s-%s.exe", baseName, goos, goarch)
	}

	return fmt.Sprintf("%s-%s-%s", baseName, goos, goarch)
}

// GetCurrentVersion returns the current version string
func GetCurrentVersion() string {
	return Version
}

// Version is the current version of the application
// This should be updated with each release
var Version = "0.1.0"

// compareVersions compares two semantic version strings
// Returns: 1 if v1 > v2, -1 if v1 < v2, 0 if equal
func compareVersions(v1, v2 string) int {
	parts1 := parseVersion(v1)
	parts2 := parseVersion(v2)

	for i := 0; i < 3; i++ {
		if parts1[i] > parts2[i] {
			return 1
		}
		if parts1[i] < parts2[i] {
			return -1
		}
	}
	return 0
}

// parseVersion parses a semantic version string (e.g., "1.2.3") into [major, minor, patch]
func parseVersion(v string) [3]int {
	parts := strings.Split(v, ".")
	var result [3]int

	for i := 0; i < 3 && i < len(parts); i++ {
		// Remove any non-numeric suffix (e.g., "1.2.3-beta" -> "1.2.3")
		numStr := strings.Split(parts[i], "-")[0]
		if num, err := strconv.Atoi(numStr); err == nil {
			result[i] = num
		}
	}

	return result
}
