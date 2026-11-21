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

// Package windows runs the end-to-end checks on a Windows host, with the vfox
// that its release ships and a VFOX_HOME in a folder whose path has a space,
// as vfox-java tests it. Windows containers cannot run on the Linux runners, so
// this suite runs on the host itself.
package windows

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"strings"
	"testing"
	"time"

	"github.com/version-fox/vfox-scala/tests/e2e/common"
)

// hostSession runs commands on the host. Each session has its own VFOX_HOME,
// a Program Files folder that vfox's Detect reads through ProgramFiles, and a
// folder for the checks to write into.
type hostSession struct {
	vfox         string
	home         string
	work         string
	programFiles string
	zip          string
}

func (s *hostSession) Vfox(args ...string) (string, error) {
	return s.Run(s.work, s.vfox, args...)
}

func (s *hostSession) Run(dir, name string, args ...string) (string, error) {
	cmd := exec.Command(name, args...)
	cmd.Dir = dir
	// The shell of UseGlobal finds vfox by its name, so its folder goes first.
	path := filepath.Dir(s.vfox) + string(os.PathListSeparator) + os.Getenv("PATH")
	cmd.Env = append(os.Environ(), "VFOX_HOME="+s.home, "ProgramFiles="+s.programFiles, "PATH="+path)
	out, err := cmd.CombinedOutput()
	return string(out), err
}

// UseGlobal activates vfox in PowerShell the way `vfox activate pwsh` does in a
// user's profile. The prompt hook it installs does not run in a script, so the
// environment that `vfox env` gives is applied once, after the `use`.
func (s *hostSession) UseGlobal(spec string) (string, error) {
	script := "vfox activate pwsh | Out-String | Invoke-Expression; " +
		"vfox use --global " + spec + "; " +
		"if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }; " +
		"vfox env -s pwsh | Out-String | Invoke-Expression; " +
		"scala -version"
	return s.Run(s.work, "pwsh", "-NoProfile", "-Command", script)
}

func (s *hostSession) WriteFile(file string, data []byte) error {
	if err := os.MkdirAll(filepath.Dir(file), 0o755); err != nil {
		return err
	}
	return os.WriteFile(file, data, 0o644)
}

func (s *hostSession) Join(parts ...string) string {
	return filepath.Join(parts...)
}

func (s *hostSession) PluginZip() string {
	return s.zip
}

func (s *hostSession) Work() string {
	return s.work
}

// newSession makes the folders of one group of checks under base.
func newSession(t *testing.T, base, group, vfoxExe, zip string) *hostSession {
	t.Helper()
	root := filepath.Join(base, group)
	s := &hostSession{
		vfox:         vfoxExe,
		home:         filepath.Join(root, "VFOX HOME", ".vfox"),
		work:         filepath.Join(root, "work"),
		programFiles: filepath.Join(root, "Program Files"),
		zip:          zip,
	}
	for _, dir := range []string{s.home, s.work, s.programFiles} {
		if err := os.MkdirAll(dir, 0o755); err != nil {
			t.Fatal(err)
		}
	}
	return s
}

// installVfox downloads the pinned vfox release, checks it, and returns the path
// of vfox.exe in it.
func installVfox(t *testing.T, base string) string {
	t.Helper()
	archive := filepath.Join(base, "vfox.zip")
	url := fmt.Sprintf("https://github.com/version-fox/vfox/releases/download/v%s/vfox_%s_windows_x86_64.zip",
		common.VfoxVersion, common.VfoxVersion)
	err := common.Retry(common.Attempts(), 10*time.Second, func() error {
		return common.DownloadVerified(url, common.VfoxWindowsAmd64SHA256, archive)
	})
	if err != nil {
		t.Fatalf("download vfox: %v", err)
	}
	unpacked := filepath.Join(base, "vfox-bin")
	if err := common.ExtractZip(archive, unpacked); err != nil {
		t.Fatalf("unpack vfox: %v", err)
	}
	exe := filepath.Join(unpacked, "vfox_"+common.VfoxVersion+"_windows_x86_64", "vfox.exe")
	if _, err := os.Stat(exe); err != nil {
		t.Fatalf("vfox.exe is not in the release: %v", err)
	}
	return exe
}

// installSystemScala puts Scala common.ScalaSystem in the session's Program
// Files as scala-system, the way someone would install it by hand, outside
// vfox, and returns that folder.
func installSystemScala(t *testing.T, s *hostSession, base string) string {
	t.Helper()
	archive := filepath.Join(base, "scala-"+common.ScalaSystem+".zip")
	err := common.Retry(common.Attempts(), 10*time.Second, func() error {
		return common.Download(common.ScalaSystemURL("zip"), archive)
	})
	if err != nil {
		t.Fatalf("download Scala %s: %v", common.ScalaSystem, err)
	}
	if err := common.ExtractZip(archive, s.programFiles); err != nil {
		t.Fatalf("unpack Scala %s: %v", common.ScalaSystem, err)
	}
	extracted := filepath.Join(s.programFiles, "scala-"+common.ScalaSystem)
	system := filepath.Join(s.programFiles, "scala-system")
	if err := os.Rename(extracted, system); err != nil {
		t.Fatalf("move Scala %s into place: %v", common.ScalaSystem, err)
	}
	return system
}

// TestE2E runs the Windows checks. It needs network access to GitHub and
// scala-lang.org, a JDK on the PATH, and takes a while.
func TestE2E(t *testing.T) {
	if testing.Short() {
		t.Skip("the Windows suite runs vfox on the host; run it without -short")
	}
	if runtime.GOOS != "windows" {
		t.Skip("the Windows suite runs on Windows hosts only")
	}
	root, err := common.RepoRoot()
	if err != nil {
		t.Fatal(err)
	}

	base := t.TempDir()
	zip := filepath.Join(base, "vfox-scala-local.zip")
	if err := common.BuildPluginZip(root, zip); err != nil {
		t.Fatalf("pack the plugin: %v", err)
	}
	vfoxExe := installVfox(t, base)

	t.Run("install and run", func(t *testing.T) {
		s := newSession(t, base, "install", vfoxExe, zip)
		out, err := s.Vfox("--version")
		if err != nil || !strings.Contains(out, common.VfoxVersion) {
			t.Fatalf("vfox --version: %v\n%s", err, out)
		}
		common.CheckInstallAndRun(t, s)
	})

	t.Run("archive and detect", func(t *testing.T) {
		s := newSession(t, base, "detect", vfoxExe, zip)
		system := installSystemScala(t, s, base)
		common.CheckArchiveAndDetect(t, s, system)
	})
}
