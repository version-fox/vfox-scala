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

local test = require("vfox.test")
local plugin = test.load({ os = "linux", arch = "amd64" })

local cases = 0

local function value_of(keys, key)
    for _, item in ipairs(keys) do
        if item.key == key then
            return item.value
        end
    end
    return nil
end

-- vfox 1.x hands the install directory over as ctx.main.path.
local keys = plugin:EnvKeys({ main = { path = "/home/u/.vfox/sdks/scala/3.5.0" } })
assert(value_of(keys, "SCALA_HOME") == "/home/u/.vfox/sdks/scala/3.5.0", "SCALA_HOME")
assert(value_of(keys, "PATH") == "/home/u/.vfox/sdks/scala/3.5.0/bin", "PATH gets bin")
cases = cases + 1

-- An older context carries the directory as ctx.path.
keys = plugin:EnvKeys({ path = "/opt/scala" })
assert(value_of(keys, "SCALA_HOME") == "/opt/scala", "SCALA_HOME from ctx.path")
assert(value_of(keys, "PATH") == "/opt/scala/bin", "PATH from ctx.path")
cases = cases + 1

print("PASS: " .. cases .. " EnvKeys cases")
