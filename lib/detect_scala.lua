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

--- Finds Scala installations that are already on the machine, for `vfox link --detect`.
--- A Scala home is a folder with a `bin/scala` launcher (`bin\scala.bat` on
--- Windows), or with one in its `libexec` folder, which is where a Homebrew
--- keg keeps the distribution. The version is read from the jar names in
--- `lib`, else from the name of the folder, else from `scala -version`.
local detect = {}

-- TEMPORARY TRACE (diagnostics for the Windows CI run; removed in the next commit).
local function trace(...)
    local parts = {}
    for i = 1, select("#", ...) do
        parts[#parts + 1] = tostring((select(i, ...)))
    end
    print("[scala-trace] " .. table.concat(parts, " | "))
end

local function escape(text)
    return (text:gsub("\r", "\\r"):gsub("\n", "\\n"))
end

local function trim(value)
    return (value:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function lower(value)
    return (value or ""):lower()
end

local function is_windows()
    return RUNTIME ~= nil and RUNTIME.osType == "windows"
end

--- Joins a directory and a name with the separator of the platform.
function detect.join(left, right)
    local last = left:sub(-1)
    if last == "/" or last == "\\" then
        return left .. right
    end
    return left .. (is_windows() and "\\" or "/") .. right
end

--- The last part of a path.
local function basename(path)
    return path:match("([^/\\]+)$") or path
end

local function shell_quote(value)
    if is_windows() then
        return '"' .. value:gsub('"', '""') .. '"'
    end
    return "'" .. value:gsub("'", "'\\''") .. "'"
end

--- Lists the entries of dir as full paths, or {} when dir cannot be read.
--- With dirs_only on Windows, only the subdirectories are listed. The output is
--- read whole and split into lines, because vfox's io.popen on Windows returns a
--- handle with read and close only, and no lines method.
--- @param dir string
--- @param dirs_only boolean
--- @return table
function detect.list_entries(dir, dirs_only)
    if dir == nil or dir == "" then
        return {}
    end
    local cmd
    if is_windows() then
        cmd = "dir /b " .. (dirs_only and "/ad " or "") .. shell_quote(dir) .. " 2>nul"
    else
        cmd = "ls -1 " .. shell_quote(dir) .. " 2>/dev/null"
    end
    local handle = io.popen(cmd, "r")
    if not handle then
        return {}
    end
    local output = handle:read("*a") or ""
    handle:close()
    trace("list", cmd, #output, escape(output:sub(1, 200)))
    local result = {}
    -- Lines from `dir /b` end in CR LF; both characters separate the entries.
    for line in output:gmatch("[^\r\n]+") do
        line = trim(line)
        if line ~= "" and line ~= "." and line ~= ".." then
            table.insert(result, detect.join(dir, line))
        end
    end
    return result
end

--- Lists the subdirectories of dir as full paths, or {}.
function detect.list_children(dir)
    return detect.list_entries(dir, true)
end

--- Whether a file or a directory exists at path.
local function exists(path)
    local file = io.open(path, "r")
    if file then
        file:close()
        return true
    end
    return false
end

--- The launcher of a Scala home.
local function launcher(home)
    return detect.join(detect.join(home, "bin"), is_windows() and "scala.bat" or "scala")
end

--- Returns the Scala home that dir is: dir itself, or the libexec folder of a
--- Homebrew keg. Returns nil where dir holds no Scala.
--- @param dir string
--- @return string|nil
function detect.scala_home(dir)
    for _, candidate in ipairs({ dir, detect.join(dir, "libexec") }) do
        trace("home?", candidate, exists(launcher(candidate)))
        if exists(launcher(candidate)) then
            return candidate
        end
    end
    return nil
end

--- The version a Scala 3 distribution writes in its VERSION file, which holds
--- the line `version:=3.5.0`. Scala 2 distributions have no such file.
local function version_from_file(home)
    local file = io.open(detect.join(home, "VERSION"), "r")
    if not file then
        return nil
    end
    local text = file:read("*a") or ""
    file:close()
    return text:match("version:=(%d[%w%.%-]*)")
end

--- The version in the jar names of lib: the Scala 3 runtime, else the Scala 2
--- library. Scala 3 distributions also ship a Scala 2 library, so the Scala 3
--- runtime comes first.
local function version_from_jars(home)
    local scala3, scala2
    for _, path in ipairs(detect.list_entries(detect.join(home, "lib"), false)) do
        local name = basename(path)
        scala3 = scala3 or name:match("^scala3%-library_3%-(%d[%w%.%-]*)%.jar$")
        scala2 = scala2 or name:match("^scala%-library%-(%d[%w%.%-]*)%.jar$")
    end
    return scala3 or scala2
end

--- The version a folder name gives: `scala-2.13.18`, `scala3-3.5.0` or `2.13.18`.
--- A name with only a major and minor number, such as Debian's `scala-2.12`,
--- gives none.
local function version_from_name(name)
    return name:match("^scala3?%-(%d+%.%d+%.%d+[%w%.%-]*)$") or name:match("^(%d+%.%d+%.%d+[%w%.%-]*)$")
end

--- The version `scala -version` prints: `Scala version (default): 3.5.0` from
--- Scala 3, `Scala code runner version 2.13.18` from Scala 2. It needs a Java
--- runtime, so a Scala that cannot start is left out.
local function version_from_launcher(home)
    local bat = launcher(home)
    local cmd
    if is_windows() then
        cmd = '""' .. bat .. '" -version 2>&1"'
    else
        cmd = shell_quote(bat) .. " -version 2>&1"
    end
    local handle = io.popen(cmd, "r")
    if not handle then
        return nil
    end
    local output = handle:read("*a") or ""
    handle:close()
    trace("probe", cmd, #output, escape(output:sub(1, 240)))
    return output:match("Scala version %(default%):%s*(%d[%w%.%-]*)") or output:match("version%s+(%d[%w%.%-]*)")
end

--- Returns the version of a Scala home, named the way `vfox install` names it,
--- or nil. dir is the folder that was scanned, which may name the version.
--- @param home string
--- @param dir string|nil
--- @return string|nil
function detect.version_for(home, dir)
    local version = version_from_file(home) or version_from_jars(home)
    if version then
        return version
    end
    version = version_from_name(basename(dir or home)) or version_from_name(basename(home))
    if version then
        return version
    end
    return version_from_launcher(home)
end

--- Paths vfox manages itself, which must never be reported.
local function is_vfox_managed(path)
    local p = lower(path or "")
    return p:find("/.vfox/", 1, true) ~= nil or p:find("\\.vfox\\", 1, true) ~= nil
end

--- The roots to scan, each {path, note, mode}. mode `home` means the root is
--- a Scala home itself; `entries` means each of its subdirectories may be one;
--- `scala-entries` means the same for those whose name mentions Scala.
--- @return table
function detect.candidate_roots()
    local roots = {}
    local function add(path, note, mode)
        if type(path) == "string" and path ~= "" then
            table.insert(roots, { path = path, note = note, mode = mode })
        end
    end
    local function child(base, ...)
        if base == nil or base == "" then
            return ""
        end
        local result = base
        for _, part in ipairs({ ... }) do
            result = detect.join(result, part)
        end
        return result
    end

    local scala_home = os.getenv("SCALA_HOME")
    add(scala_home, "pointed to by SCALA_HOME", "home")

    if is_windows() then
        local userprofile = os.getenv("USERPROFILE") or ""
        add(child(userprofile, ".asdf", "installs", "scala"), "installed by asdf", "entries")
        add(child(userprofile, ".local", "share", "mise", "installs", "scala"), "installed by mise", "entries")
        -- Scoop keeps one folder per version beside `current`.
        add(child(userprofile, "scoop", "apps", "scala"), "installed by Scoop", "entries")
        add(os.getenv("ProgramFiles") or "C:\\Program Files", "system Scala", "scala-entries")
        add(os.getenv("ProgramFiles(x86)"), "system Scala", "scala-entries")
        return roots
    end

    local home = os.getenv("HOME") or ""
    add(child(home, ".sdkman", "candidates", "scala"), "installed by SDKMAN", "entries")
    add(child(home, ".asdf", "installs", "scala"), "installed by asdf", "entries")
    add(child(home, ".local", "share", "mise", "installs", "scala"), "installed by mise", "entries")
    add("/opt/homebrew/opt", "installed by Homebrew", "scala-entries")
    add("/usr/local/opt", "installed by Homebrew", "scala-entries")
    add("/home/linuxbrew/.linuxbrew/opt", "installed by Homebrew", "scala-entries")
    add(child(home, ".linuxbrew", "opt"), "installed by Homebrew", "scala-entries")
    for _, dir in ipairs({ "/opt", "/usr/local", "/usr/local/share", "/usr/share", "/usr/lib" }) do
        add(dir, "system Scala", "scala-entries")
    end
    return roots
end

--- Finds every Scala home on the machine. Each result is { version, path, note }
--- and one result is kept per version, the first path in sorted order.
--- @return table
function detect.find_all()
    local found = {}
    local seen_paths = {}

    local function add_home(home, note, dir)
        if seen_paths[home] or is_vfox_managed(home) then
            return
        end
        seen_paths[home] = true
        local version = detect.version_for(home, dir)
        trace("version", home, version)
        if version then
            table.insert(found, { version = version, path = home, note = note })
        end
    end

    for _, root in ipairs(detect.candidate_roots()) do
        trace("root", root.mode, root.path, is_windows(), is_vfox_managed(root.path))
        if not is_vfox_managed(root.path) then
            if root.mode == "home" then
                local home = detect.scala_home(root.path)
                if home then
                    add_home(home, root.note, root.path)
                end
            else
                for _, entry in ipairs(detect.list_children(root.path)) do
                    local wanted = root.mode == "entries" or lower(basename(entry)):find("scala", 1, true) ~= nil
                    trace("entry", entry, wanted)
                    local home = wanted and detect.scala_home(entry)
                    if home then
                        add_home(home, root.note, entry)
                    end
                end
            end
        end
    end

    table.sort(found, function(a, b)
        if a.version ~= b.version then
            return a.version < b.version
        end
        return a.path < b.path
    end)
    local result = {}
    local seen_versions = {}
    for _, item in ipairs(found) do
        if not seen_versions[item.version] then
            seen_versions[item.version] = true
            table.insert(result, item)
        end
    end
    return result
end

return detect
