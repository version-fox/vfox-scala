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

// Package common holds the checks that the Linux and Windows suites share.
// Each platform package decides where vfox runs, a throwaway container on
// Linux and the host on Windows, builds a Session for it and calls the checks
// here, so both suites test the same flow. See docs/e2e.md.
package common

import (
	"archive/zip"
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"testing"
	"time"
)

// Pinned vfox release. The checksums are the digests GitHub publishes for the
// release assets, so a changed download fails the suite.
const (
	VfoxVersion            = "1.1.0"
	VfoxLinuxAmd64SHA256   = "3b33c3c468b27bc17aecf0d6d3af24fe49fe204972984904a136a47b402a0ee4"
	VfoxWindowsAmd64SHA256 = "1bbec8fffddbb62de0d93030c3f6203c69680662bc65257ca4a5e611cb607d0a"
)

// The Scala releases the checks install.
const (
	// Scala3Checksum has a SHA-256 file next to its download on GitHub, so vfox verifies it.
	Scala3Checksum = "3.10.1"
	// Scala3NoChecksum has no such file, so vfox installs it with a warning.
	Scala3NoChecksum = "3.5.0"
	// Scala2 comes from the scala repository on GitHub.
	Scala2 = "2.13.18"
	// Scala2Archive is on scala-lang.org, and its archive is found on its download page.
	Scala2Archive = "2.10.4"
	// ScalaSystem is put in a folder by hand, outside vfox, for `vfox link --detect` to find.
	ScalaSystem = "2.12.20"
)

// The SHA-256 of the GitHub release archives of ScalaSystem. GitHub publishes no
// digest for them, so the values were computed from the assets; scala-lang.org
// serves identical copies.
const (
	ScalaSystemTgzSHA256 = "cc29d91ad390dc8e9a68d1e2ec6892711b64116f549fecd67a928361d33a39c0"
	ScalaSystemZipSHA256 = "fab2a5f87d58e641b5ea612b3752e70b8d6160c568546cc76c0b2b9e59dd079a"
)

// Session is one environment that vfox runs in, fresh for each check: a
// container on Linux, a temporary folder on the host for Windows.
type Session interface {
	// Vfox runs vfox with args and returns what it printed.
	Vfox(args ...string) (string, error)
	// UseGlobal runs `vfox use --global spec` in a shell where vfox is activated,
	// as a user's shell is, applies the environment that vfox then gives, and
	// runs `scala -version` in it. vfox use refuses to run outside such a shell.
	UseGlobal(spec string) (string, error)
	// Run runs name with args in dir, in the session's environment, and returns what it printed.
	Run(dir, name string, args ...string) (string, error)
	// WriteFile writes data to path in the session, creating its folders.
	WriteFile(path string, data []byte) error
	// Join joins the parts of a path the way the session's system does.
	Join(parts ...string) string
	// PluginZip is the plugin archive, as the session sees it.
	PluginZip() string
	// Work is a folder that the checks write into.
	Work() string
}

// ScalaSystemURL is the GitHub release archive of ScalaSystem, as ext names it:
// "tgz" for Linux and "zip" for Windows.
func ScalaSystemURL(ext string) string {
	return fmt.Sprintf("https://github.com/scala/scala/releases/download/v%s/scala-%s.%s",
		ScalaSystem, ScalaSystem, ext)
}

// Attempts is how many times a step that uses the network runs, from
// E2E_RETRY_ATTEMPTS and 3 by default.
func Attempts() int {
	if value, err := strconv.Atoi(os.Getenv("E2E_RETRY_ATTEMPTS")); err == nil && value > 0 {
		return value
	}
	return 3
}

// Retry runs fn until it succeeds or the attempts run out, waiting one more
// backoff after each failure.
func Retry(attempts int, backoff time.Duration, fn func() error) error {
	var err error
	for attempt := 1; attempt <= attempts; attempt++ {
		if err = fn(); err == nil {
			return nil
		}
		if attempt < attempts {
			time.Sleep(time.Duration(attempt) * backoff)
		}
	}
	return fmt.Errorf("after %d attempts: %w", attempts, err)
}

// RepoRoot returns the root of the repository: the nearest folder above the
// working directory that holds metadata.lua.
func RepoRoot() (string, error) {
	dir, err := os.Getwd()
	if err != nil {
		return "", err
	}
	for {
		if _, err := os.Stat(filepath.Join(dir, "metadata.lua")); err == nil {
			return dir, nil
		}
		parent := filepath.Dir(dir)
		if parent == dir {
			return "", errors.New("metadata.lua not found above the working directory")
		}
		dir = parent
	}
}

// PluginFiles lists the files that make up the plugin, relative to root with
// forward slashes: the metadata, and the hooks and libraries that vfox loads.
// Tests and documentation stay out.
func PluginFiles(root string) ([]string, error) {
	files := []string{"metadata.lua"}
	for _, dir := range []string{"hooks", "lib"} {
		entries, err := os.ReadDir(filepath.Join(root, dir))
		if err != nil {
			return nil, err
		}
		for _, entry := range entries {
			if !entry.IsDir() && strings.HasSuffix(entry.Name(), ".lua") {
				files = append(files, dir+"/"+entry.Name())
			}
		}
	}
	return files, nil
}

// BuildPluginZip writes the plugin of root to dest as a zip archive, the form
// `vfox add --source` takes from a local path.
func BuildPluginZip(root, dest string) error {
	files, err := PluginFiles(root)
	if err != nil {
		return err
	}
	out, err := os.Create(dest)
	if err != nil {
		return err
	}
	writer := zip.NewWriter(out)
	for _, name := range files {
		data, err := os.ReadFile(filepath.Join(root, filepath.FromSlash(name)))
		if err != nil {
			out.Close()
			return err
		}
		entry, err := writer.Create(name)
		if err != nil {
			out.Close()
			return err
		}
		if _, err := entry.Write(data); err != nil {
			out.Close()
			return err
		}
	}
	if err := writer.Close(); err != nil {
		out.Close()
		return err
	}
	return out.Close()
}

// DownloadVerified downloads url to dest and fails unless its SHA-256 is want.
func DownloadVerified(url, want, dest string) error {
	return download(url, want, dest)
}

// download saves url to dest, and checks its SHA-256 against want. Nothing is
// left at dest on a failure.
func download(url, want, dest string) error {
	client := &http.Client{Timeout: 10 * time.Minute}
	resp, err := client.Get(url)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("GET %s: %s", url, resp.Status)
	}
	part := dest + ".part"
	file, err := os.Create(part)
	if err != nil {
		return err
	}
	hash := sha256.New()
	if _, err := io.Copy(io.MultiWriter(file, hash), resp.Body); err != nil {
		file.Close()
		os.Remove(part)
		return err
	}
	if err := file.Close(); err != nil {
		os.Remove(part)
		return err
	}
	if got := hex.EncodeToString(hash.Sum(nil)); got != want {
		os.Remove(part)
		return fmt.Errorf("SHA-256 of %s is %s, want %s", url, got, want)
	}
	return os.Rename(part, dest)
}

// ExtractZip unpacks the zip at src into dir. An entry that would land outside
// dir is refused.
func ExtractZip(src, dir string) error {
	reader, err := zip.OpenReader(src)
	if err != nil {
		return err
	}
	defer reader.Close()
	for _, entry := range reader.File {
		target, err := safeJoin(dir, entry.Name)
		if err != nil {
			return err
		}
		if entry.FileInfo().IsDir() {
			if err := os.MkdirAll(target, 0o755); err != nil {
				return err
			}
			continue
		}
		if err := os.MkdirAll(filepath.Dir(target), 0o755); err != nil {
			return err
		}
		if err := extractFile(entry, target); err != nil {
			return err
		}
	}
	return nil
}

func extractFile(entry *zip.File, target string) error {
	in, err := entry.Open()
	if err != nil {
		return err
	}
	defer in.Close()
	out, err := os.OpenFile(target, os.O_CREATE|os.O_WRONLY|os.O_TRUNC, 0o755)
	if err != nil {
		return err
	}
	if _, err := io.Copy(out, in); err != nil {
		out.Close()
		return err
	}
	return out.Close()
}

func safeJoin(dir, name string) (string, error) {
	target := filepath.Join(dir, filepath.FromSlash(name))
	rel, err := filepath.Rel(dir, target)
	if err != nil || rel == ".." || strings.HasPrefix(rel, ".."+string(filepath.Separator)) {
		return "", fmt.Errorf("zip entry %q leaves %s", name, dir)
	}
	return target, nil
}

// Expect fails the test unless out holds every one of wants.
func Expect(t *testing.T, step, out string, wants ...string) {
	t.Helper()
	for _, want := range wants {
		if !strings.Contains(out, want) {
			t.Fatalf("%s: the output does not contain %q:\n%s", step, want, tail(out))
		}
	}
}

// tail keeps the end of long output, where vfox prints its error.
func tail(out string) string {
	const limit = 4000
	if len(out) > limit {
		return "..." + out[len(out)-limit:]
	}
	return out
}

// vfoxStep runs vfox with args. A step that uses the network is retried, and
// the output must hold every one of wants.
func vfoxStep(t *testing.T, s Session, step string, network bool, wants []string, args ...string) string {
	t.Helper()
	attempts := 1
	if network {
		attempts = Attempts()
	}
	var out string
	err := Retry(attempts, 10*time.Second, func() error {
		var runErr error
		out, runErr = s.Vfox(args...)
		return runErr
	})
	if err != nil {
		t.Fatalf("%s: vfox %s: %v\n%s", step, strings.Join(args, " "), err, tail(out))
	}
	Expect(t, step, out, wants...)
	return out
}

// hello is compiled and run with each Scala the checks use.
const hello = `object Hello {
  def main(args: Array[String]): Unit = println("hello from scala")
}
`

// CheckRun runs the Scala of version through vfox exec: its version, then a
// program compiled with scalac and run with scala.
func CheckRun(t *testing.T, s Session, version string) {
	t.Helper()
	spec := "scala@" + version
	vfoxStep(t, s, "scalac -version "+version, false, []string{version},
		"exec", spec, "--", "scalac", "-version")

	project := s.Join(s.Work(), "hello-"+version)
	source := s.Join(project, "Hello.scala")
	classes := s.Join(project, "classes")
	if err := s.WriteFile(source, []byte(hello)); err != nil {
		t.Fatalf("write %s: %v", source, err)
	}
	// WriteFile makes the folder of classes, which scalac needs to exist.
	if err := s.WriteFile(s.Join(classes, ".keep"), nil); err != nil {
		t.Fatalf("create %s: %v", classes, err)
	}
	vfoxStep(t, s, "scalac "+version, false, nil,
		"exec", spec, "--", "scalac", "-d", classes, source)
	// Scala 3's launcher takes the main class with --main-class; Scala 2's
	// takes it after the classpath.
	run := []string{"-cp", classes, "Hello"}
	if strings.HasPrefix(version, "3.") {
		run = []string{"--main-class", "Hello", "-cp", classes}
	}
	vfoxStep(t, s, "scala "+version, false, []string{"hello from scala"},
		append([]string{"exec", spec, "--", "scala"}, run...)...)
}

// CheckInstallAndRun adds the plugin, installs Scala 3 with and without a
// published checksum and Scala 2, and runs them.
func CheckInstallAndRun(t *testing.T, s Session) {
	t.Helper()
	vfoxStep(t, s, "add", false, []string{"successfully"},
		"add", "--source", s.PluginZip(), "scala")
	vfoxStep(t, s, "info", false, []string{"README.md"},
		"info", "scala")
	vfoxStep(t, s, "search", true, []string{Scala3Checksum, Scala2, "LTS"},
		"search", "scala")
	vfoxStep(t, s, "install with checksum", true, []string{"Verifying checksum", "success"},
		"install", "scala@"+Scala3Checksum, "-y")
	vfoxStep(t, s, "install without checksum", true, []string{"Checksum is not provided", "success"},
		"install", "scala@"+Scala3NoChecksum, "-y")
	vfoxStep(t, s, "install Scala 2", true, []string{"success"},
		"install", "scala@"+Scala2, "-y")
	out, err := s.UseGlobal("scala@" + Scala3Checksum)
	if err != nil {
		t.Fatalf("use --global scala@%s: %v\n%s", Scala3Checksum, err, tail(out))
	}
	Expect(t, "use --global", out, Scala3Checksum)
	CheckRun(t, s, Scala3Checksum)
	CheckRun(t, s, Scala3NoChecksum)
	CheckRun(t, s, Scala2)
}

// CheckArchiveAndDetect installs a release from the scala-lang.org archive, and
// links the Scala that the caller put in systemHome, which vfox did not install.
func CheckArchiveAndDetect(t *testing.T, s Session, systemHome string) {
	t.Helper()
	vfoxStep(t, s, "add", false, []string{"successfully"},
		"add", "--source", s.PluginZip(), "scala")
	vfoxStep(t, s, "install archive", true, []string{"success"},
		"install", "scala@"+Scala2Archive, "-y")
	vfoxStep(t, s, "list archive", false, []string{Scala2Archive},
		"list", "scala")
	vfoxStep(t, s, "detect", false, []string{ScalaSystem, systemHome},
		"link", "--detect", "scala", "--yes")
	vfoxStep(t, s, "run linked", false, []string{ScalaSystem},
		"exec", "scala@"+ScalaSystem, "--", "scala", "-version")
}
