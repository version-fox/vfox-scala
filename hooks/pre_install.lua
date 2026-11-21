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

local util = require("util")

--- Returns some pre-installed information, such as version number, download address, local files, etc.
--- If checksum is provided, vfox will automatically check it for you. A GitHub
--- download is checked against the `.sha256` file next to it where Scala has
--- published one.
--- ctx.version is the version the user typed.
--- @param ctx table
--- @return table Version information
function PLUGIN:PreInstall(ctx)
    local version = ctx.version
    local windows = RUNTIME.osType == "windows"
    local url, from_github = util.download(version, windows)
    local result = {
        version = version,
        url = url,
    }
    if from_github then
        result.sha256 = util.github_sha256(url)
    end
    return result
end
