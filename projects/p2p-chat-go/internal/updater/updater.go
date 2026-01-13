package updater

import (
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"runtime"
	"strings"
	"time"
)

// Version is the current version of the application
var Version = "0.1.0"

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
