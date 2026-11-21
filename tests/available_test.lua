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

-- Lines of the download list as scala-lang.org has them on 2026-11-21.
local LISTING = [[
<div class="download-elem">
                <a href="/download/3.10.1.html">Scala 3.10.1</a>
              </div>
<div class="download-elem">
                <a href="/download/3.9.0.html">Scala 3.9.0 LTS</a>
              </div>
<div class="download-elem">
                <a href="/download/2.13.18.html">Scala 2.13.18</a>
              </div>
]]

local status = 200
local requests = {}
local plugin = test.load({
    os = "linux",
    arch = "amd64",
    http = function(req)
        table.insert(requests, req.url)
        return { status_code = status, body = LISTING }
    end,
})

local cases = 0

local versions = plugin:Available({})
assert(#versions == 3, "expected 3 versions, got " .. #versions)
assert(versions[1].version == "3.10.1", "first version: " .. tostring(versions[1].version))
assert(versions[2].version == "3.9.0", "LTS version has no note in its name: " .. tostring(versions[2].version))
assert(versions[2].note == "LTS", "LTS note: " .. tostring(versions[2].note))
assert(versions[3].note == "", "plain version has no note")
assert(
    requests[1] == "https://www.scala-lang.org/download/all.html",
    "asks the download list: " .. tostring(requests[1])
)
cases = cases + 1

-- A failed read is an error, not an empty list that looks like no release.
status = 500
local ok = pcall(function()
    plugin:Available({})
end)
assert(not ok, "a 500 from the download list must fail")
cases = cases + 1

print("PASS: " .. cases .. " Available cases")
