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

package common

import (
	"archive/zip"
	"errors"
	"os"
	"path/filepath"
	"slices"
	"strings"
	"testing"
	"time"
)

func TestRetryStopsAtFirstSuccess(t *testing.T) {
	calls := 0
	err := Retry(3, 0, func() error {
		calls++
		if calls < 3 {
			return errors.New("not yet")
		}
		return nil
	})
	if err != nil {
		t.Fatalf("Retry: %v", err)
	}
	if calls != 3 {
		t.Fatalf("calls = %d, want 3", calls)
	}
}

func TestRetryGivesUp(t *testing.T) {
	calls := 0
	err := Retry(2, time.Millisecond, func() error {
		calls++
		return errors.New("down")
	})
	if err == nil || !strings.Contains(err.Error(), "after 2 attempts") {
		t.Fatalf("Retry error = %v, want the attempt count", err)
	}
	if calls != 2 {
		t.Fatalf("calls = %d, want 2", calls)
	}
}

func TestSafeJoinKeepsEntriesInside(t *testing.T) {
	dir := t.TempDir()
	for _, name := range []string{"a/b.txt", "top.txt"} {
		if _, err := safeJoin(dir, name); err != nil {
			t.Fatalf("safeJoin(%q): %v", name, err)
		}
	}
	for _, name := range []string{"../escape.txt", "a/../../escape.txt"} {
		if _, err := safeJoin(dir, name); err == nil {
			t.Fatalf("safeJoin(%q) let the entry leave %s", name, dir)
		}
	}
}

func TestExtractZipRefusesEscapingEntries(t *testing.T) {
	dir := t.TempDir()
	archive := filepath.Join(dir, "bad.zip")
	file, err := os.Create(archive)
	if err != nil {
		t.Fatal(err)
	}
	writer := zip.NewWriter(file)
	entry, err := writer.Create("../escape.txt")
	if err != nil {
		t.Fatal(err)
	}
	if _, err := entry.Write([]byte("x")); err != nil {
		t.Fatal(err)
	}
	if err := writer.Close(); err != nil {
		t.Fatal(err)
	}
	if err := file.Close(); err != nil {
		t.Fatal(err)
	}
	if err := ExtractZip(archive, filepath.Join(dir, "out")); err == nil {
		t.Fatal("ExtractZip accepted an entry outside its folder")
	}
	if _, err := os.Stat(filepath.Join(dir, "escape.txt")); err == nil {
		t.Fatal("the escaping entry was written")
	}
}

func TestBuildPluginZipHoldsOnlyThePlugin(t *testing.T) {
	root, err := RepoRoot()
	if err != nil {
		t.Fatal(err)
	}
	files, err := PluginFiles(root)
	if err != nil {
		t.Fatal(err)
	}
	for _, want := range []string{"metadata.lua", "hooks/available.lua", "lib/util.lua", "lib/detect_scala.lua"} {
		if !slices.Contains(files, want) {
			t.Fatalf("PluginFiles lacks %s: %v", want, files)
		}
	}
	for _, file := range files {
		if strings.HasPrefix(file, "tests/") || strings.HasSuffix(file, ".md") {
			t.Fatalf("PluginFiles holds %s, which is not part of the plugin", file)
		}
	}

	archive := filepath.Join(t.TempDir(), "plugin.zip")
	if err := BuildPluginZip(root, archive); err != nil {
		t.Fatalf("BuildPluginZip: %v", err)
	}
	reader, err := zip.OpenReader(archive)
	if err != nil {
		t.Fatal(err)
	}
	defer reader.Close()
	var names []string
	for _, entry := range reader.File {
		names = append(names, entry.Name)
	}
	if !slices.Equal(names, files) {
		t.Fatalf("zip entries = %v, want %v", names, files)
	}
}

func TestDownloadFailureLeavesNothingBehind(t *testing.T) {
	// The address refuses connections, so the download fails before any digest
	// is compared, and no partial file may remain.
	dest := filepath.Join(t.TempDir(), "missing")
	if err := DownloadVerified("http://127.0.0.1:1/none", "00", dest); err == nil {
		t.Fatal("download from a closed port succeeded")
	}
	if _, err := os.Stat(dest + ".part"); err == nil {
		t.Fatal("a partial download was left behind")
	}
}
