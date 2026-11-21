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

--- Versions, download addresses and checksums of the Scala releases.
---
--- Scala 3 and Scala 2.11 and later are downloaded from GitHub. Earlier
--- releases are on scala-lang.org, whose file names follow no single pattern
--- (`scala-2.5.0-final.tar.gz`, `scala-2.7.7.final.tgz`), so the download page
--- of such a version names its archive.
local http = require("http")

local util = {}

util.SEARCH_URL = "https://www.scala-lang.org/download/all.html"
util.DOWNLOAD_PAGE_URL = "https://www.scala-lang.org/download/%s.html"
util.SCALA3_DOWNLOAD_URL = "https://github.com/scala/scala3/releases/download/%s/scala3-%s.%s"
util.SCALA2_DOWNLOAD_URL = "https://github.com/scala/scala/releases/download/v%s/scala-%s.%s"

local function trim(value)
    return (value:gsub("^%s+", ""):gsub("%s+$", ""))
end

--- Splits a name of the download list, such as `Scala 3.9.0 LTS`, into the
--- version (`3.9.0`) and its note (`LTS`).
--- @param name string
--- @return string version
--- @return string note
function util.parse_listing_name(name)
    local version = trim(name):gsub("^Scala ", "")
    local base = version:match("^(.-)%s+LTS$")
    if base then
        return base, "LTS"
    end
    return version, ""
end

--- Lists the versions of the download list page, newest first as the page has them.
--- @param html string
--- @return table Entries of { version = string, note = string }
function util.parse_listing(html)
    local result = {}
    for name in html:gmatch('<div class="download%-elem">.-<a href="[^"]-">([^<]-)</a>.-</div>') do
        local version, note = util.parse_listing_name(name)
        table.insert(result, { version = version, note = note })
    end
    return result
end

--- Returns the major and minor numbers of a version such as `3.5.0` or
--- `2.13.0-M5`, or nil when it does not start with two numbers.
--- @param version string
--- @return integer|nil major
--- @return integer|nil minor
function util.major_minor(version)
    local major, minor = (version or ""):match("^(%d+)%.(%d+)")
    if major == nil then
        return nil, nil
    end
    return tonumber(major), tonumber(minor)
end

--- Returns where a version is downloaded from: `scala3` for GitHub's
--- scala3 repository, `scala2` for GitHub's scala repository (Scala 2.11 and
--- later), and `archive` for scala-lang.org.
--- @param version string
--- @return string
function util.source_of(version)
    local major, minor = util.major_minor(version)
    if major == nil then
        error("not a Scala version: " .. tostring(version))
    end
    if major >= 3 then
        return "scala3"
    end
    if major == 2 and minor >= 11 then
        return "scala2"
    end
    return "archive"
end

--- Returns the GitHub download of a version for the platform, or nil for a
--- version that is on scala-lang.org instead.
--- @param version string
--- @param windows boolean
--- @return string|nil
function util.github_url(version, windows)
    local source = util.source_of(version)
    if source == "scala3" then
        return util.SCALA3_DOWNLOAD_URL:format(version, version, windows and "zip" or "tar.gz")
    end
    if source == "scala2" then
        return util.SCALA2_DOWNLOAD_URL:format(version, version, windows and "zip" or "tgz")
    end
    return nil
end

--- Returns the archive of a version on scala-lang.org, from the links of its
--- download page. Windows takes the zip; elsewhere tar.gz, then tgz. The
--- documentation and tool-support archives, and the .msi and .deb packages,
--- are not the distribution and are skipped.
--- @param html string The download page
--- @param windows boolean
--- @return string|nil
function util.archive_url_from_page(html, windows)
    local extensions = windows and { "zip" } or { "tar.gz", "tgz" }
    for _, extension in ipairs(extensions) do
        for url in html:gmatch("https?://[%w%.%-]*scala%-lang%.org/files/archive/[^\"%s<>']+") do
            local file = url:match("([^/]+)$") or ""
            local is_distribution = file:match("^scala%-") ~= nil
                and not file:find("docs", 1, true)
                and not file:find("tool-support", 1, true)
            if is_distribution and file:sub(-(#extension + 1)) == "." .. extension then
                return url
            end
        end
    end
    return nil
end

--- Reads the archive of a version from its download page on scala-lang.org.
--- @param version string
--- @param windows boolean
--- @return string url
function util.archive_url(version, windows)
    local page = util.DOWNLOAD_PAGE_URL:format(version)
    local resp, err = http.get({ url = page })
    if err ~= nil then
        error("cannot read " .. page .. ": " .. tostring(err))
    end
    if resp.status_code ~= 200 then
        error("cannot read " .. page .. ": status_code => " .. tostring(resp.status_code))
    end
    local url = util.archive_url_from_page(resp.body, windows)
    if url == nil then
        error("no archive of Scala " .. version .. " for this platform on " .. page)
    end
    return url
end

--- Returns the address to download a version from, and whether that address is
--- on GitHub, where a `.sha256` file may sit next to the download.
--- @param version string
--- @param windows boolean
--- @return string url
--- @return boolean from_github
function util.download(version, windows)
    local url = util.github_url(version, windows)
    if url ~= nil then
        return url, true
    end
    return util.archive_url(version, windows), false
end

--- Reads the SHA-256 digest of a `.sha256` file, which holds `<digest>  <name>`.
--- @param text string|nil
--- @return string|nil The digest in lower case
function util.parse_sha256(text)
    local digest = (text or ""):match("^%s*(%x+)")
    if digest == nil or #digest ~= 64 then
        return nil
    end
    return digest:lower()
end

--- Returns the SHA-256 digest published next to a GitHub download, or nil.
--- Scala does not publish one for every release. Without one vfox warns and
--- installs, so a missing or unreadable file is not an error here.
--- @param url string The download address
--- @return string|nil
function util.github_sha256(url)
    local resp, err = http.get({ url = url .. ".sha256" })
    if err ~= nil or resp == nil or resp.status_code ~= 200 then
        return nil
    end
    return util.parse_sha256(resp.body)
end

return util
