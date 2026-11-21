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

// TEMPORARY diagnostics: why the ProgramFiles override does not reach the
// plugin on the Windows runner. Each environment variant is probed four ways:
// a child test binary (Go's os.Getenv), cmd.exe, pwsh and the plugin itself
// (vfox plugin run, whose Lua os.getenv is the one the scan uses). This file is
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

// TestE2EDiagChild runs as a child of TestE2EDiagEnv and prints what the
// process sees in its environment.
func TestE2EDiagChild(t *testing.T) {
	if os.Getenv(diagChildEnv) != "1" {
		t.Skip("runs only as a child of TestE2EDiagEnv")
	}
	fmt.Printf("DIAG-CHILD ProgramFiles=%q DIAG_PROBE=%q\n", os.Getenv("ProgramFiles"), os.Getenv("DIAG_PROBE"))
	os.Exit(0)
}

type diagVariant struct {
	name string
	env  []string
}

func filterDiagEnv(env []string, name string) []string {
	var out []string
	for _, kv := range env {
		key, _, _ := strings.Cut(kv, "=")
		if strings.EqualFold(key, name) {
			continue
		}
		out = append(out, kv)
	}
	return out
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

// writeDiagProbe writes a plugin whose Detect hook returns what its Lua
// os.getenv sees for ProgramFiles and DIAG_PROBE.
func writeDiagProbe(t *testing.T, dir string) {
	t.Helper()
	files := map[string]string{
		"metadata.lua": `PLUGIN = {}
PLUGIN.name = "probe"
PLUGIN.version = "0.0.1"
PLUGIN.homepage = "https://example.invalid/probe"
PLUGIN.license = "Apache 2.0"
PLUGIN.description = "diagnostics"
`,
		"hooks/detect.lua": `function PLUGIN:Detect(ctx)
    local pf = os.getenv("ProgramFiles") or "<nil>"
    local probe = os.getenv("DIAG_PROBE") or "<nil>"
    return {
        { version = "1.0.0", path = pf .. " ; " .. probe, note = "diag" },
    }
end
`,
		"hooks/pre_install.lua": "function PLUGIN:PreInstall(ctx)\n    return {}\nend\n",
		"hooks/available.lua":   "function PLUGIN:Available(ctx)\n    return {}\nend\n",
		"hooks/env_keys.lua":    "function PLUGIN:EnvKeys(ctx)\n    return {}\nend\n",
	}
	for name, content := range files {
		path := filepath.Join(dir, filepath.FromSlash(name))
		if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
			t.Fatal(err)
		}
		if err := os.WriteFile(path, []byte(content), 0o644); err != nil {
			t.Fatal(err)
		}
	}
}

// TestE2EDiagEnv logs what each probe sees. It never fails on a probe error;
// the logged lines are the result.
func TestE2EDiagEnv(t *testing.T) {
	if testing.Short() {
		t.Skip("diagnostics are not run with -short")
	}
	if runtime.GOOS != "windows" {
		t.Skip("Windows only")
	}

	base := t.TempDir()
	vfoxExe := installVfox(t, base)
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
	probe := filepath.Join(base, "probe")
	writeDiagProbe(t, probe)

	for _, kv := range os.Environ() {
		key, value, _ := strings.Cut(kv, "=")
		if strings.HasPrefix(strings.ToUpper(key), "PROGRAMFILES") {
			t.Logf("DIAG real env: %s=%s", key, value)
		}
	}

	variants := []diagVariant{
		{"A-append", append(append(os.Environ(), "ProgramFiles="+fake, "DIAG_PROBE=hello"), "VFOX_HOME="+home)},
		{"B-filtered", append(append(filterDiagEnv(os.Environ(), "ProgramFiles"), "ProgramFiles="+fake, "DIAG_PROBE=hello"), "VFOX_HOME="+home)},
		{"C-minimal", minimalDiagEnv(fake, home)},
	}

	for _, v := range variants {
		childEnv := append(append([]string(nil), v.env...), diagChildEnv+"=1")

		child := exec.Command(self, "-test.run=^TestE2EDiagChild$")
		child.Env = childEnv
		out, err := child.CombinedOutput()
		t.Logf("DIAG %s go-child: err=%v out=%s", v.name, err, strings.TrimSpace(string(out)))

		cmdProbe := exec.Command("cmd.exe", "/d", "/c", "echo [%ProgramFiles%] [%DIAG_PROBE%]")
		cmdProbe.Env = v.env
		out, err = cmdProbe.CombinedOutput()
		t.Logf("DIAG %s cmd: err=%v out=%s", v.name, err, strings.TrimSpace(string(out)))

		psProbe := exec.Command("pwsh", "-NoProfile", "-Command",
			"Write-Output ('[' + $env:ProgramFiles + '] [' + $env:DIAG_PROBE + ']')")
		psProbe.Env = v.env
		out, err = psProbe.CombinedOutput()
		t.Logf("DIAG %s pwsh: err=%v out=%s", v.name, err, strings.TrimSpace(string(out)))

		plugin := exec.Command(vfoxExe, "plugin", "run", probe, "Detect", "--json")
		plugin.Env = v.env
		out, err = plugin.CombinedOutput()
		t.Logf("DIAG %s plugin: err=%v out=%s", v.name, err, strings.TrimSpace(string(out)))
	}
}
