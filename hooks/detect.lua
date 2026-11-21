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

local detect = require("detect_scala")

--- Finds Scala installations that are already on the machine and that vfox did not
--- install, for `vfox link --detect scala`: SCALA_HOME, SDKMAN, asdf, mise, Homebrew,
--- Scoop, the system directories and Program Files, among others.
--- Each entry names the version the way `vfox install` names it.
--- @param ctx table Empty table used as context
--- @return table Entries of { version = string, path = string, note = string }
function PLUGIN:Detect(ctx)
    return detect.find_all()
end
