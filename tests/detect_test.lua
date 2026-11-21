-- Copyright 2026 Han Li and contributors
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--   http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.

-- The Linux and macOS roots, on a fake file system: files maps a normalized
-- path to its content, dirs maps a normalized directory to its entries, and
-- outputs answers `scala -version` for a launcher.
local test = require("vfox.test")
local plugin = test.load({
    os = "linux",
    arch = "amd64",
    env = { HOME = "/home/test" },
})
local detect = require("detect_scala")

local files = {}
local dirs = {}
local outputs = {}

local function norm(path)
    return (path or ""):gsub("\\", "/")
end

io.open = function(path, mode)
    mode = mode or "r"
    if mode ~= "r" then
        return nil
    end
    local key = norm(path)
    local content = files[key]
    if content == nil and dirs[key] == nil then
        return nil
    end
    return {
        read = function(_, pattern)
            if pattern == "*a" then
                return content or ""
            end
            return nil
        end,
        close = function()
            return true
        end,
    }
end

-- vfox's io.popen on Windows returns a handle with read and close only (see
-- internal/plugin/luai/exec.go in vfox), so this fake has no lines method: a
-- listing is read whole, as that handle is.
io.popen = function(cmd, mode)
    local output = ""
    if cmd:find(" -version", 1, true) then
        for launcher, text in pairs(outputs) do
            if cmd:find(launcher, 1, true) then
                output = text
            end
        end
    else
        local dir = cmd:match("'([^']+)'") or cmd:match('"([^"]+)"')
        output = table.concat(dirs[norm(dir)] or {}, "\n") .. "\n"
    end
    return {
        read = function(_, format)
            if format == "*a" then
                return output
            end
            return nil
        end,
        close = function()
            return true
        end,
    }
end

local function reset()
    files = {}
    dirs = {}
    outputs = {}
end

-- Makes a Scala home at home, with the launcher and the given jar names in lib.
local function add_home(home, jars)
    files[norm(home .. "/bin/scala")] = "#!/bin/sh\n"
    dirs[norm(home .. "/lib")] = {}
    for _, jar in ipairs(jars or {}) do
        files[norm(home .. "/lib/" .. jar)] = ""
        table.insert(dirs[norm(home .. "/lib")], jar)
    end
end

-- Lists name under parent, as the directory listing of the parent has it.
local function list(parent, names)
    dirs[norm(parent)] = dirs[norm(parent)] or {}
    for _, name in ipairs(names) do
        table.insert(dirs[norm(parent)], name)
    end
end

local function empty_roots()
    local roots = {
        "/home/test/.sdkman/candidates/scala",
        "/home/test/.asdf/installs/scala",
        "/home/test/.local/share/mise/installs/scala",
        "/opt/homebrew/opt",
        "/usr/local/opt",
        "/home/linuxbrew/.linuxbrew/opt",
        "/home/test/.linuxbrew/opt",
        "/opt",
        "/usr/local",
        "/usr/local/share",
        "/usr/share",
        "/usr/lib",
    }
    for _, root in ipairs(roots) do
        dirs[norm(root)] = dirs[norm(root)] or {}
    end
end

local cases = 0

-- A Scala 3 distribution as it is laid out: its VERSION file names the version,
-- and lib holds scala.jar beside a Scala 2 library of another version, which
-- must not be taken for it.
reset()
empty_roots()
local SCALA3_JARS = { "scala.jar", "scaladoc.jar", "scala-library-2.13.14.jar" }
add_home("/home/test/.sdkman/candidates/scala/3.5.0", SCALA3_JARS)
files[norm("/home/test/.sdkman/candidates/scala/3.5.0/VERSION")] = "version:=3.5.0\nrevision:=abc\n"
list("/home/test/.sdkman/candidates/scala", { "3.5.0", "current" })
add_home("/home/test/.sdkman/candidates/scala/current", SCALA3_JARS)
files[norm("/home/test/.sdkman/candidates/scala/current/VERSION")] = "version:=3.5.0\nrevision:=abc\n"
assert(
    detect.version_for("/home/test/.sdkman/candidates/scala/3.5.0", "/home/test/.sdkman/candidates/scala/3.5.0")
        == "3.5.0"
)
local found = plugin:Detect({})
assert(#found == 1, "SDKMAN's 3.5.0 and its current link are one version: " .. #found)
assert(found[1].version == "3.5.0", "Scala 3 version from VERSION: " .. tostring(found[1].version))
assert(found[1].path == "/home/test/.sdkman/candidates/scala/3.5.0", "the first path of a version wins")
assert(found[1].note == "installed by SDKMAN", "SDKMAN note: " .. tostring(found[1].note))
cases = cases + 1

-- Unversioned Scala 2 jars: the folder name gives the version.
reset()
empty_roots()
add_home("/opt/scala-2.13.18", { "scala-library.jar", "scala-compiler.jar" })
list("/opt", { "scala-2.13.18" })
found = plugin:Detect({})
assert(#found == 1, "one system Scala: " .. #found)
assert(found[1].version == "2.13.18", "version from the folder name: " .. tostring(found[1].version))
assert(found[1].path == "/opt/scala-2.13.18", "system path: " .. tostring(found[1].path))
assert(found[1].note == "system Scala", "system note: " .. tostring(found[1].note))
cases = cases + 1

-- A folder that names only major and minor, as Debian's /usr/share/scala-2.12
-- does, falls back to `scala -version`.
reset()
empty_roots()
add_home("/usr/share/scala-2.12", { "scala-library.jar" })
list("/usr/share", { "scala-2.12", "java" })
outputs["/usr/share/scala-2.12/bin/scala"] = "Scala code runner version 2.12.20 -- Copyright 2002-2023, LAMP/EPFL\n"
found = plugin:Detect({})
assert(#found == 1, "debian scala: " .. #found)
assert(found[1].version == "2.12.20", "version from scala -version: " .. tostring(found[1].version))
cases = cases + 1

-- A Homebrew keg keeps the distribution in libexec; a keg whose launcher
-- cannot print a version is left out.
reset()
empty_roots()
add_home("/home/linuxbrew/.linuxbrew/opt/scala/libexec", { "scala-library.jar" })
outputs["/home/linuxbrew/.linuxbrew/opt/scala/libexec/bin/scala"] = "Scala code runner version 2.13.14 -- Copyright\n"
files[norm("/home/linuxbrew/.linuxbrew/opt/broken/bin/scala")] = "#!/bin/sh\n"
dirs[norm("/home/linuxbrew/.linuxbrew/opt/broken/lib")] = {}
list("/home/linuxbrew/.linuxbrew/opt", { "scala", "broken" })
found = plugin:Detect({})
assert(#found == 1, "keg only: " .. #found)
assert(found[1].version == "2.13.14", "keg version: " .. tostring(found[1].version))
assert(found[1].path == "/home/linuxbrew/.linuxbrew/opt/scala/libexec", "keg home is libexec")
assert(found[1].note == "installed by Homebrew", "keg note: " .. tostring(found[1].note))
cases = cases + 1

-- Folders without a launcher are not Scala, and a `.vfox` folder is skipped.
reset()
empty_roots()
dirs[norm("/opt/scala-notes")] = {}
list("/opt", { "scala-notes", "scala-2.11.12" })
add_home("/opt/scala-2.11.12", { "scala-library.jar" })
found = plugin:Detect({})
assert(#found == 1 and found[1].version == "2.11.12", "only the real Scala is found")
for _, item in ipairs(found) do
    assert(not item.path:find(".vfox", 1, true), "vfox-managed path leaked: " .. item.path)
end
cases = cases + 1

-- The version of a home by its jars, names and launcher, on its own.
reset()
add_home("/x/scala3", { "scala3-library_3-3.10.1.jar" })
assert(detect.version_for("/x/scala3", "/x/scala3") == "3.10.1", "jar version")
add_home("/x/named", {})
assert(detect.version_for("/x/named", "/x/scala-2.13.5") == "2.13.5", "name version")
add_home("/x/unknown", {})
outputs["/x/unknown/bin/scala"] = "no version here\n"
assert(detect.version_for("/x/unknown", "/x/unknown") == nil, "no version is not reported")
cases = cases + 1

-- Scala 3's launcher prints the version of the code it runs on its own line.
reset()
add_home("/x/scala3-launcher", {})
outputs["/x/scala3-launcher/bin/scala"] = "Scala code runner version: 1.4.0\nScala version (default): 3.5.0\n"
assert(detect.version_for("/x/scala3-launcher", "/x/scala3-launcher") == "3.5.0", "Scala 3 launcher line")
cases = cases + 1

print("PASS: " .. cases .. " Detect Linux cases")
