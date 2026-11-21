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

-- The Windows roots: Program Files, Scoop, asdf and mise, with bin\scala.bat
-- for the launcher and `dir /b` for the listings. The fake file system keys
-- are normalized to forward slashes.
local test = require("vfox.test")
local plugin = test.load({
    os = "windows",
    arch = "amd64",
    env = {
        USERPROFILE = "C:\\Users\\John Doe",
        ProgramFiles = "C:\\Program Files",
    },
})

local files = {}
local dirs = {}
local outputs = {}

local function norm(path)
    return (path or ""):gsub("\\", "/")
end

io.open = function(path, mode)
    local key = norm(path)
    local content = files[key]
    if content == nil and dirs[key] == nil then
        return nil
    end
    return {
        read = function()
            return content or ""
        end,
        close = function()
            return true
        end,
    }
end

-- The fake handle has read and close only, as vfox's Windows io.popen does
-- (see internal/plugin/luai/exec.go in vfox), and `dir /b` lines end in CR LF.
io.popen = function(cmd, mode)
    local output = ""
    if cmd:find(" -version", 1, true) then
        for launcher, text in pairs(outputs) do
            if cmd:find(launcher, 1, true) then
                output = text
            end
        end
    else
        assert(cmd:find("dir /b", 1, true), "listings use dir /b: " .. cmd)
        local dir = cmd:match('"([^"]+)"')
        output = table.concat(dirs[norm(dir)] or {}, "\r\n") .. "\r\n"
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

local function add_home(home, jars)
    files[norm(home .. "\\bin\\scala.bat")] = "@echo off\r\n"
    dirs[norm(home .. "\\lib")] = {}
    for _, jar in ipairs(jars or {}) do
        files[norm(home .. "\\lib\\" .. jar)] = ""
        table.insert(dirs[norm(home .. "\\lib")], jar)
    end
end

local cases = 0

-- Program Files: a folder whose name mentions Scala, with its version in the name.
add_home("C:\\Program Files\\scala-2.13.18", { "scala-library.jar" })
dirs[norm("C:\\Program Files")] = { "Microsoft", "scala-2.13.18" }
-- Unversioned jars and no version in the name: `scala -version` answers.
add_home("C:\\Program Files\\Scala", { "scala-library.jar" })
table.insert(dirs[norm("C:\\Program Files")], "Scala")
outputs["C:\\Program Files\\Scala\\bin\\scala.bat"] = "Scala code runner version 2.12.20 -- Copyright\r\n"
-- Scoop keeps each version beside `current`.
dirs[norm("C:\\Users\\John Doe\\scoop\\apps\\scala")] = { "3.5.0", "current" }
add_home(
    "C:\\Users\\John Doe\\scoop\\apps\\scala\\3.5.0",
    { "scala3-library_3-3.5.0.jar", "scala-library-2.13.14.jar" }
)
add_home(
    "C:\\Users\\John Doe\\scoop\\apps\\scala\\current",
    { "scala3-library_3-3.5.0.jar", "scala-library-2.13.14.jar" }
)
dirs[norm("C:\\Users\\John Doe\\.asdf\\installs\\scala")] = {}
dirs[norm("C:\\Users\\John Doe\\.local\\share\\mise\\installs\\scala")] = {}
dirs[norm("C:\\Program Files (x86)")] = {}
dirs[norm("C:\\Program Files\\Microsoft")] = {}

local found = plugin:Detect({})
local by_version = {}
for _, item in ipairs(found) do
    by_version[item.version] = item
end
assert(#found == 3, "expected 3 Scala versions, got " .. #found)

local system = by_version["2.13.18"]
assert(system ~= nil, "Program Files 2.13.18 is found")
assert(system.path == "C:\\Program Files\\scala-2.13.18", "Program Files path: " .. tostring(system.path))
assert(system.note == "system Scala", "system note: " .. tostring(system.note))
cases = cases + 1

local launched = by_version["2.12.20"]
assert(launched ~= nil, "a Scala without a version in its name is asked for one")
assert(launched.path == "C:\\Program Files\\Scala", "launcher path: " .. tostring(launched.path))
cases = cases + 1

local scoop = by_version["3.5.0"]
assert(scoop ~= nil, "Scoop's 3.5.0 is found")
assert(scoop.path == "C:\\Users\\John Doe\\scoop\\apps\\scala\\3.5.0", "Scoop path: " .. tostring(scoop.path))
assert(scoop.note == "installed by Scoop", "Scoop note: " .. tostring(scoop.note))
cases = cases + 1

print("PASS: " .. cases .. " Detect Windows cases")
