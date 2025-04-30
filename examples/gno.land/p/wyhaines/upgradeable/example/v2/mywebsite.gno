package mywebsitev2

import (
	"std"
	"strconv"

	v1 "gno.land/r/wyhaines/v1/mywebsite" // Import the v1 realm
)

// Package information
const (
	Version = 2
)

func init() {
	// Directly upgrade the function in the v1 realm's Registry
	// We can access the Registry because it's public (capitalized)
	err := v1.Registry.RegisterFunction("render", RenderV2)
	if err != nil {
		std.Emit("UpgradeError", "error", err.Error())
	} else {
		std.Emit("FunctionUpgraded", "function", "render", "version", strconv.Itoa(Version))
	}
}

// V2 implementation with enhanced features
func RenderV2(path string) string {
	return "# Enhanced page for " + path + " (v2)"
}

// We can still have our own implementation that calls v1's function
// which will now use the upgraded implementation
func Render(path string) string {
	return v1.Render(path)
}

// Get version info
func GetVersion() int {
	return Version
}
