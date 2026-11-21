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

--- Each SDK may have different environment variable configurations.
--- This allows plugins to define custom environment variables (including PATH settings)
--- Note: Be sure to distinguish between environment variable settings for different platforms!
--- ctx.main.path is the install directory of this version (ctx.path on older vfox).
--- @param ctx table Context information
function PLUGIN:EnvKeys(ctx)
    local path = (ctx.main and ctx.main.path) or ctx.path
    return {
        {
            key = "SCALA_HOME",
            value = path,
        },
        {
            key = "PATH",
            value = path .. "/bin",
        },
    }
end
