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

// Package linux runs the end-to-end checks in throwaway Docker containers, one
// per group of checks, so each starts with no Scala, no JDK plugin and an
// empty VFOX_HOME. The containers run the image built from ./Dockerfile.
package linux

import (
	"bytes"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path"
	"path/filepath"
	"strings"
	"sync/atomic"
	"testing"
	"time"

	"github.com/version-fox/vfox-scala/tests/e2e/common"
)

const (
	image     = "vfox-scala-e2e:dev"
	vfoxHome  = "/root/.vfox"
	workDir   = "/work"
	pluginZip = "/plugin/vfox-scala-local.zip"
)

// containerCount names the containers of one run apart.
var containerCount atomic.Int64

// dockerSession runs commands in one container.
type dockerSession struct {
	container string
}

func (s *dockerSession) Vfox(args ...string) (string, error) {
	return s.exec("", nil, "vfox", args...)
}

func (s *dockerSession) Run(dir, name string, args ...string) (string, error) {
	return s.exec(dir, nil, name, args...)
}

// UseGlobal activates vfox in bash the way `vfox activate bash` does in a
// user's profile. The prompt hook it installs does not run in a script, so the
// environment that `vfox env` gives is applied once, after the `use`.
func (s *dockerSession) UseGlobal(spec string) (string, error) {
	script := `eval "$(vfox activate bash)" && vfox use --global "$1" && eval "$(vfox env -s bash)" && scala -version`
	return s.exec("", nil, "bash", "-c", script, "bash", spec)
}

func (s *dockerSession) WriteFile(file string, data []byte) error {
	out, err := s.exec("", bytes.NewReader(data), "sh", "-c", `mkdir -p "$(dirname "$1")" && cat > "$1"`, "sh", file)
	if err != nil {
		return fmt.Errorf("write %s: %w: %s", file, err, out)
	}
	return nil
}

func (s *dockerSession) Join(parts ...string) string {
	return path.Join(parts...)
}

func (s *dockerSession) PluginZip() string {
	return pluginZip
}

func (s *dockerSession) Work() string {
	return workDir
}

// exec runs name with args in the container, with VFOX_HOME set, and returns
// what it printed. The command runs in the work folder unless dir says
// otherwise: the Scala 3 launchers work out their project from the working
// directory, and fail in /.
func (s *dockerSession) exec(dir string, stdin io.Reader, name string, args ...string) (string, error) {
	if dir == "" {
		dir = workDir
	}
	dockerArgs := []string{"exec", "--env", "VFOX_HOME=" + vfoxHome, "--workdir", dir}
	if stdin != nil {
		dockerArgs = append(dockerArgs, "--interactive")
	}
	dockerArgs = append(dockerArgs, s.container, name)
	dockerArgs = append(dockerArgs, args...)
	cmd := exec.Command("docker", dockerArgs...)
	cmd.Stdin = stdin
	var out bytes.Buffer
	cmd.Stdout = &out
	cmd.Stderr = &out
	err := cmd.Run()
	return out.String(), err
}

// buildImage builds the image from the Dockerfile in dir.
func buildImage(t *testing.T, dir string) {
	t.Helper()
	cmd := exec.Command("docker", "build", "--tag", image, dir)
	out, err := cmd.CombinedOutput()
	if err != nil {
		t.Fatalf("docker build %s: %v\n%s", dir, err, tail(string(out)))
	}
}

// startContainer starts a container, removes it when the test ends, and writes
// the plugin archive into it. The archive travels through the Docker API rather
// than a bind mount, so the suite also works where the Docker daemon cannot see
// this process's folders, as in a dev container that mounts the host's socket.
func startContainer(t *testing.T, plugin []byte) *dockerSession {
	t.Helper()
	name := fmt.Sprintf("vfox-scala-e2e-%d-%d", os.Getpid(), containerCount.Add(1))
	cmd := exec.Command("docker", "run", "--detach", "--rm", "--name", name,
		"--workdir", workDir, image, "sleep", "infinity")
	out, err := cmd.CombinedOutput()
	if err != nil {
		t.Fatalf("docker run %s: %v\n%s", name, err, tail(string(out)))
	}
	t.Cleanup(func() {
		_ = exec.Command("docker", "rm", "--force", name).Run()
	})
	s := &dockerSession{container: name}
	if err := s.WriteFile(pluginZip, plugin); err != nil {
		t.Fatalf("copy the plugin into %s: %v", name, err)
	}
	return s
}

// installSystemScala puts Scala common.ScalaSystem in /opt/scala-system, the
// way someone would install it by hand, outside vfox, and checks it started.
func installSystemScala(t *testing.T, s *dockerSession) {
	t.Helper()
	url := common.ScalaSystemURL("tgz")
	script := `set -eu
mkdir -p /opt/staging
curl --fail --silent --show-error --location "$1" | tar --extract --gzip --directory /opt/staging
mv "/opt/staging/scala-$2" /opt/scala-system
rm -rf /opt/staging`
	err := common.Retry(common.Attempts(), 10*time.Second, func() error {
		out, runErr := s.Run("", "sh", "-c", script, "sh", url, common.ScalaSystem)
		if runErr != nil {
			return fmt.Errorf("%w: %s", runErr, tail(out))
		}
		return nil
	})
	if err != nil {
		t.Fatalf("install Scala %s by hand: %v", common.ScalaSystem, err)
	}
}

func tail(out string) string {
	const limit = 2000
	if len(out) > limit {
		return "..." + out[len(out)-limit:]
	}
	return strings.TrimSpace(out)
}

// TestE2E runs the Linux checks. It needs Docker and network access to GitHub
// and scala-lang.org, and takes a while.
func TestE2E(t *testing.T) {
	if testing.Short() {
		t.Skip("the Linux suite starts containers; run it without -short")
	}
	root, err := common.RepoRoot()
	if err != nil {
		t.Fatal(err)
	}

	archive := filepath.Join(t.TempDir(), "vfox-scala-local.zip")
	if err := common.BuildPluginZip(root, archive); err != nil {
		t.Fatalf("pack the plugin: %v", err)
	}
	plugin, err := os.ReadFile(archive)
	if err != nil {
		t.Fatal(err)
	}
	buildImage(t, filepath.Join(root, "tests", "e2e", "linux"))

	t.Run("install and run", func(t *testing.T) {
		t.Parallel()
		s := startContainer(t, plugin)
		common.CheckInstallAndRun(t, s)
	})

	t.Run("archive and detect", func(t *testing.T) {
		t.Parallel()
		s := startContainer(t, plugin)
		installSystemScala(t, s)
		common.CheckArchiveAndDetect(t, s, "/opt/scala-system")
	})
}
