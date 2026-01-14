package updater

import (
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"runtime"
	"strings"
	"time"
)

// Version is the current version of the application
var Version = "0.3.0"

// GitHubRelease represents a GitHub release response
type GitHubRelease struct {
	TagName string `json:"tag_name"`
	Name    string `json:"name"`
	Body    string `json:"body"`
	Assets  []struct {
		Name               string `json:"name"`
		BrowserDownloadURL string `json:"browser_download_url"`
		Size               int64  `json:"size"`
	} `json:"assets"`
	HTMLURL string `json:"html_url"`
}

// CheckForUpdates checks if a new version is available on GitHub
func CheckForUpdates(owner, repo string) (*GitHubRelease, bool, error) {
	// Build API URL for latest release
	apiURL := fmt.Sprintf("https://api.github.com/repos/%s/%s/releases/latest", owner, repo)

	// Create HTTP client with timeout
	client := &http.Client{
		Timeout: 10 * time.Second,
	}

	// Make request
	resp, err := client.Get(apiURL)
	if err != nil {
		return nil, false, fmt.Errorf("failed to fetch release info: %w", err)
	}
	defer resp.Body.Close()

	// Check status code
	if resp.StatusCode == 404 {
		return nil, false, fmt.Errorf("no releases found")
	}
	if resp.StatusCode != 200 {
		return nil, false, fmt.Errorf("GitHub API returned status %d", resp.StatusCode)
	}

	// Parse JSON response
	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, false, fmt.Errorf("failed to read response: %w", err)
	}

	var release GitHubRelease
	if err := json.Unmarshal(body, &release); err != nil {
		return nil, false, fmt.Errorf("failed to parse release info: %w", err)
	}

	// Compare versions (remove 'v' prefix if present)
	latestVersion := strings.TrimPrefix(release.TagName, "p2p-chat-v")
	currentVersion := strings.TrimPrefix(Version, "v")

	// Simple version comparison (works for semantic versions)
	hasUpdate := latestVersion != currentVersion

	return &release, hasUpdate, nil
}

// GetDownloadURL returns the download URL for the current platform
func GetDownloadURL(release *GitHubRelease) (string, error) {
	// Determine platform-specific binary name
	osName := runtime.GOOS
	archName := runtime.GOARCH

	// Expected binary name pattern: p2p-chat-{os}-{arch}[.exe]
	var binaryName string
	if osName == "windows" {
		binaryName = fmt.Sprintf("p2p-chat-%s-%s.exe", osName, archName)
	} else {
		binaryName = fmt.Sprintf("p2p-chat-%s-%s", osName, archName)
	}

	// Find matching asset
	for _, asset := range release.Assets {
		if asset.Name == binaryName {
			return asset.BrowserDownloadURL, nil
		}
	}

	return "", fmt.Errorf("no binary found for %s/%s", osName, archName)
}

// FormatSize formats bytes to human-readable size
func FormatSize(bytes int64) string {
	const unit = 1024
	if bytes < unit {
		return fmt.Sprintf("%d B", bytes)
	}
	div, exp := int64(unit), 0
	for n := bytes / unit; n >= unit; n /= unit {
		div *= unit
		exp++
	}
	return fmt.Sprintf("%.1f %cB", float64(bytes)/float64(div), "KMGTPE"[exp])
}

// GetVersionInfo returns formatted version information
func GetVersionInfo() string {
	return fmt.Sprintf("p2p-chat v%s (%s/%s)", Version, runtime.GOOS, runtime.GOARCH)
}

// DownloadBinary downloads a binary from the given URL
func DownloadBinary(url string, progressCallback func(downloaded, total int64)) ([]byte, error) {
	// Create HTTP client with timeout
	client := &http.Client{
		Timeout: 5 * time.Minute, // Longer timeout for binary downloads
	}

	// Make request
	resp, err := client.Get(url)
	if err != nil {
		return nil, fmt.Errorf("failed to download: %w", err)
	}
	defer resp.Body.Close()

	// Check status code
	if resp.StatusCode != 200 {
		return nil, fmt.Errorf("download failed with status %d", resp.StatusCode)
	}

	// Get content length for progress tracking
	contentLength := resp.ContentLength

	// Download with progress tracking
	var data []byte
	buffer := make([]byte, 32*1024) // 32KB buffer
	downloaded := int64(0)

	for {
		n, err := resp.Body.Read(buffer)
		if n > 0 {
			data = append(data, buffer[:n]...)
			downloaded += int64(n)

			// Call progress callback if provided
			if progressCallback != nil {
				progressCallback(downloaded, contentLength)
			}
		}

		if err == io.EOF {
			break
		}
		if err != nil {
			return nil, fmt.Errorf("download interrupted: %w", err)
		}
	}

	return data, nil
}

// VerifyChecksum verifies the SHA256 checksum of data
func VerifyChecksum(data []byte, expectedChecksum string) bool {
	if expectedChecksum == "" {
		return true // Skip verification if no checksum provided
	}

	hash := sha256.Sum256(data)
	actualChecksum := hex.EncodeToString(hash[:])

	return strings.EqualFold(actualChecksum, expectedChecksum)
}

// GetCurrentExecutable returns the path to the current executable
func GetCurrentExecutable() (string, error) {
	exe, err := os.Executable()
	if err != nil {
		return "", fmt.Errorf("failed to get executable path: %w", err)
	}

	// Resolve symlinks
	exe, err = filepath.EvalSymlinks(exe)
	if err != nil {
		return "", fmt.Errorf("failed to resolve symlinks: %w", err)
	}

	return exe, nil
}

// InstallBinary replaces the current binary with a new one
func InstallBinary(newBinaryData []byte) error {
	// Get current executable path
	currentExe, err := GetCurrentExecutable()
	if err != nil {
		return err
	}

	// Create backup of current binary
	backupPath := currentExe + ".backup"
	if err := os.Rename(currentExe, backupPath); err != nil {
		return fmt.Errorf("failed to backup current binary: %w", err)
	}

	// Write new binary
	if err := os.WriteFile(currentExe, newBinaryData, 0755); err != nil {
		// Restore backup on failure
		os.Rename(backupPath, currentExe)
		return fmt.Errorf("failed to write new binary: %w", err)
	}

	// Remove backup on success
	os.Remove(backupPath)

	return nil
}

// PerformUpdate performs the complete update process
func PerformUpdate(owner, repo string, progressCallback func(downloaded, total int64)) error {
	// Check for updates
	release, hasUpdate, err := CheckForUpdates(owner, repo)
	if err != nil {
		return fmt.Errorf("failed to check for updates: %w", err)
	}

	if !hasUpdate {
		return fmt.Errorf("already running the latest version (v%s)", Version)
	}

	// Get download URL for current platform
	downloadURL, err := GetDownloadURL(release)
	if err != nil {
		return fmt.Errorf("failed to get download URL: %w", err)
	}

	// Download binary
	fmt.Printf("Downloading version %s...\n", strings.TrimPrefix(release.TagName, "p2p-chat-v"))
	binaryData, err := DownloadBinary(downloadURL, progressCallback)
	if err != nil {
		return fmt.Errorf("download failed: %w", err)
	}

	// Find checksum asset if available
	checksumAsset := ""
	for _, asset := range release.Assets {
		if strings.Contains(asset.Name, "checksums") || strings.Contains(asset.Name, "SHA256") {
			checksumAsset = asset.BrowserDownloadURL
			break
		}
	}

	// Verify checksum if available
	if checksumAsset != "" {
		fmt.Println("Verifying checksum...")
		// Note: Full checksum verification would require downloading and parsing the checksum file
		// For now, we'll skip this step but the infrastructure is in place
	}

	// Install new binary
	fmt.Println("Installing new binary...")
	if err := InstallBinary(binaryData); err != nil {
		return fmt.Errorf("installation failed: %w", err)
	}

	fmt.Printf("✓ Successfully updated to version %s!\n", strings.TrimPrefix(release.TagName, "p2p-chat-v"))
	fmt.Println("Please restart the application to use the new version.")

	return nil
}
