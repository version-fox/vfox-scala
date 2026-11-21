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

-- SCALA_HOME names a Scala home itself, and reports it with its note.
local test = require("vfox.test")
local plugin = test.load({
    os = "linux",
    arch = "amd64",
    env = {
        HOME = "/home/test",
        SCALA_HOME = "/srv/scala",
    },
})

local files = {}
local dirs = {}

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

io.popen = function(cmd, mode)
    if cmd:find(" -version", 1, true) then
        return {
            read = function()
                return "Scala code runner version 3.4.2 -- Copyright\n"
            end,
            close = function()
                return true
            end,
        }
    end
    local dir = cmd:match("'([^']+)'") or cmd:match('"([^"]+)"')
    local children = (dir and dirs[norm(dir)]) or {}
    local index = 0
    return {
        lines = function()
            return function()
                index = index + 1
                return children[index]
            end
        end,
        close = function()
            return true
        end,
    }
end

local cases = 0

files[norm("/srv/scala/bin/scala")] = "#!/bin/sh\n"
dirs[norm("/srv/scala/lib")] = { "scala3-library_3-3.4.2.jar" }
files[norm("/srv/scala/lib/scala3-library_3-3.4.2.jar")] = ""
-- Every other root is empty.
for _, root in ipairs({
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
}) do
    dirs[norm(root)] = {}
end

local found = plugin:Detect({})
assert(#found == 1, "expected SCALA_HOME only, got " .. #found)
assert(found[1].version == "3.4.2", "SCALA_HOME version: " .. tostring(found[1].version))
assert(found[1].path == "/srv/scala", "SCALA_HOME path: " .. tostring(found[1].path))
assert(found[1].note == "pointed to by SCALA_HOME", "SCALA_HOME note: " .. tostring(found[1].note))
cases = cases + 1

print("PASS: " .. cases .. " Detect SCALA_HOME cases")
