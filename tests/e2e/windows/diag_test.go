// Copyright 2026 Han Li and contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//   http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

// TEMPORARY diagnostics: which environment variable stops a child process from
// seeing the ProgramFiles override on the Windows runner. The probe is the
// test binary itself, run as a child with a chosen environment. This file is
// removed once the cause is fixed.
package windows

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"strings"
	"testing"
)

const diagChildEnv = "DIAG_CHILD"

// TestE2EDiagChild runs as a child of TestE2EDiagBisect and prints how many
// environment entries it received and what it reads for ProgramFiles.
func TestE2EDiagChild(t *testing.T) {
	if os.Getenv(diagChildEnv) != "1" {
		t.Skip("runs only as a child of TestE2EDiagBisect")
	}
	fmt.Printf("DIAG-CHILD len=%d ProgramFiles=%q\n", len(os.Environ()), os.Getenv("ProgramFiles"))
	os.Exit(0)
}

// diagChild runs the test binary with env and returns what it printed.
func diagChild(self string, env []string) string {
	child := exec.Command(self, "-test.run=^TestE2EDiagChild$")
	child.Env = append(append([]string(nil), env...), diagChildEnv+"=1")
	out, err := child.CombinedOutput()
	if err != nil {
		return fmt.Sprintf("error: %v: %s", err, strings.TrimSpace(string(out)))
	}
	return strings.TrimSpace(string(out))
}

// classify names what a child saw for ProgramFiles: the fake folder, the real
// one, or anything else (with the raw output).
func classify(output string) string {
	switch {
	case strings.Contains(output, "Fake Program Files"):
		return "fake"
	case strings.Contains(output, `ProgramFiles="C:`):
		return "real"
	default:
		return "other: " + output
	}
}

func keyOf(kv string) string {
	key, _, _ := strings.Cut(kv, "=")
	return key
}

func minimalDiagEnv(programFiles, home string) []string {
	env := []string{"ProgramFiles=" + programFiles, "DIAG_PROBE=hello", "VFOX_HOME=" + home}
	for _, name := range []string{"SYSTEMROOT", "TEMP", "TMP", "PATH", "USERPROFILE", "COMSPEC", "PSModulePath"} {
		if value, ok := os.LookupEnv(name); ok {
			env = append(env, name+"="+value)
		}
	}
	return env
}

// TestE2EDiagBisect logs what children see under several environments. It
// never fails on a probe result; the logged lines are the result.
func TestE2EDiagBisect(t *testing.T) {
	if testing.Short() {
		t.Skip("diagnostics are not run with -short")
	}
	if runtime.GOOS != "windows" {
		t.Skip("Windows only")
	}

	base := t.TempDir()
	self, err := os.Executable()
	if err != nil {
		t.Fatal(err)
	}
	fake := filepath.Join(base, "Fake Program Files")
	home := filepath.Join(base, "home")
	for _, dir := range []string{fake, home} {
		if err := os.MkdirAll(dir, 0o755); err != nil {
			t.Fatal(err)
		}
	}

	full := os.Environ()
	chars := 0
	for _, kv := range full {
		chars += len(kv) + 1
	}
	t.Logf("DIAG parent: %d entries, %d characters", len(full), chars)

	minimal := minimalDiagEnv(fake, home)
	t.Logf("DIAG C (minimal) -> %s", classify(diagChild(self, minimal)))

	// B: every entry except ProgramFiles, plus the fake and the two probes.
	var bset []string
	for _, kv := range full {
		if strings.EqualFold(keyOf(kv), "ProgramFiles") {
			continue
		}
		bset = append(bset, kv)
	}
	bset = append(bset, "ProgramFiles="+fake, "DIAG_PROBE=hello", "VFOX_HOME="+home)
	t.Logf("DIAG B (full minus ProgramFiles, plus fake) -> %s", classify(diagChild(self, bset)))

	// Single entries added to the minimal environment.
	inMinimal := map[string]bool{}
	for _, kv := range minimal {
		inMinimal[strings.ToUpper(keyOf(kv))] = true
	}
	var addFlips []string
	for _, kv := range full {
		key := keyOf(kv)
		if strings.EqualFold(key, "ProgramFiles") || inMinimal[strings.ToUpper(key)] {
			continue
		}
		env := append(append([]string(nil), minimal...), kv)
		if classify(diagChild(self, env)) != "fake" {
			addFlips = append(addFlips, key)
		}
	}
	t.Logf("DIAG add-one-to-C that makes the real folder visible (%d): %v", len(addFlips), addFlips)

	// Single entries removed from B (the last three are the appended ones).
	var removeFlips []string
	for i := 0; i < len(bset)-3; i++ {
		env := make([]string, 0, len(bset)-1)
		env = append(env, bset[:i]...)
		env = append(env, bset[i+1:]...)
		if classify(diagChild(self, env)) == "fake" {
			removeFlips = append(removeFlips, keyOf(bset[i]))
		}
	}
	t.Logf("DIAG remove-one-from-B that makes the fake folder visible (%d): %v", len(removeFlips), removeFlips)

	// Size only: the minimal environment plus one padding variable.
	for _, n := range []int{1000, 8000, 16000, 24000, 30000, 32000, 32700, 36000} {
		env := append(append([]string(nil), minimal...), "DIAG_PAD="+strings.Repeat("x", n))
		t.Logf("DIAG C + pad %d -> %s", n, classify(diagChild(self, env)))
	}
}
