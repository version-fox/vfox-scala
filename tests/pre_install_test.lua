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

local DIGEST = string.rep("0123456789abcdef", 4)
local SCALA3 = "https://github.com/scala/scala3/releases/download/"
local SCALA2 = "https://github.com/scala/scala/releases/download/v"
local PAGES = "https://www.scala-lang.org/download/"

-- The answers of the hosts, keyed by address. Anything else is a 404.
local routes = {
    [SCALA3 .. "3.10.1/scala3-3.10.1.tar.gz.sha256"] = {
        status_code = 200,
        body = DIGEST:upper() .. "  scala3-3.10.1.tar.gz\n",
    },
    [PAGES .. "2.5.0.final.html"] = {
        status_code = 200,
        body = '<a href="https://scala-lang.org/files/archive/scala-2.5.0-final.tar.gz">\n'
            .. '<a href="https://scala-lang.org/files/archive/scala-2.5.0-final.zip">\n',
    },
    [PAGES .. "2.7.7.final.html"] = {
        status_code = 200,
        body = '<a href="https://scala-lang.org/files/archive/scala-2.7.7.final.tgz">\n'
            .. '<a href="https://scala-lang.org/files/archive/scala-2.7.7.final.zip">\n',
    },
    [PAGES .. "2.10.4.html"] = {
        status_code = 200,
        body = '<a href="https://scala-lang.org/files/archive/scala-2.10.4.tgz">\n'
            .. '<a href="https://scala-lang.org/files/archive/scala-2.10.4.zip">\n',
    },
    [PAGES .. "2.10.5.html"] = {
        status_code = 200,
        body = '<a href="https://github.com/scala/scala/releases/download/v2.10.5/scala-2.10.5.tgz">\n'
            .. '<a href="https://github.com/scala/scala/releases/download/v2.10.5/scala-2.10.5.zip">\n'
            .. '<a href="https://github.com/scala/scala/archive/v2.10.5.tar.gz">\n',
    },
    [SCALA2 .. "2.10.5/scala-2.10.5.tgz.sha256"] = {
        status_code = 200,
        body = DIGEST .. "  scala-2.10.5.tgz\n",
    },
}

local requests = {}
local plugin = test.load({
    os = "linux",
    arch = "amd64",
    http = function(req)
        table.insert(requests, req.url)
        return routes[req.url] or { status_code = 404, body = "Not Found" }
    end,
})

local cases = 0

local function install(version, windows)
    RUNTIME.osType = windows and "windows" or "linux"
    local ok, result = pcall(function()
        return plugin:PreInstall({ version = version })
    end)
    RUNTIME.osType = "linux"
    return ok, result
end

local function expect_url(version, windows, url, label)
    local ok, result = install(version, windows)
    assert(ok, label .. " failed: " .. tostring(result))
    assert(result.version == version, label .. " keeps the version")
    assert(result.url == url, label .. ": got " .. tostring(result.url) .. ", expected " .. url)
    cases = cases + 1
    return result
end

-- Scala 3.0.0 is tar.gz on GitHub, like the later releases.
local result = expect_url("3.0.0", false, SCALA3 .. "3.0.0/scala3-3.0.0.tar.gz", "Scala 3.0.0")
assert(result.sha256 == nil, "no .sha256 file for 3.0.0, so no checksum")

-- A published digest is passed on for vfox to check the download with.
result = expect_url("3.10.1", false, SCALA3 .. "3.10.1/scala3-3.10.1.tar.gz", "Scala 3.10.1")
assert(result.sha256 == DIGEST, "the published digest: " .. tostring(result.sha256))

expect_url("3.0.0-RC1", false, SCALA3 .. "3.0.0-RC1/scala3-3.0.0-RC1.tar.gz", "Scala 3 candidate")
expect_url("3.10.1", true, SCALA3 .. "3.10.1/scala3-3.10.1.zip", "Scala 3 on Windows")
expect_url("2.13.14", false, SCALA2 .. "2.13.14/scala-2.13.14.tgz", "Scala 2.13 on Linux")
expect_url("2.13.14", true, SCALA2 .. "2.13.14/scala-2.13.14.zip", "Scala 2.13 on Windows")

-- Releases on scala-lang.org take the archive their download page names.
result = expect_url("2.10.4", false, "https://scala-lang.org/files/archive/scala-2.10.4.tgz", "Scala 2.10.4")
assert(result.sha256 == nil, "scala-lang.org publishes no checksum here")
expect_url("2.10.4", true, "https://scala-lang.org/files/archive/scala-2.10.4.zip", "Scala 2.10.4 on Windows")
-- Scala 2.10.5 to 2.10.7 are on GitHub, which their download page links. A GitHub
-- archive is checked against the .sha256 file next to it, where there is one.
result = expect_url("2.10.5", false, SCALA2 .. "2.10.5/scala-2.10.5.tgz", "Scala 2.10.5")
assert(result.sha256 == DIGEST, "the digest of a GitHub archive: " .. tostring(result.sha256))
expect_url("2.10.5", true, SCALA2 .. "2.10.5/scala-2.10.5.zip", "Scala 2.10.5 on Windows")

expect_url("2.5.0.final", false, "https://scala-lang.org/files/archive/scala-2.5.0-final.tar.gz", "Scala 2.5.0 final")
expect_url(
    "2.7.7.final",
    true,
    "https://scala-lang.org/files/archive/scala-2.7.7.final.zip",
    "Scala 2.7.7 final on Windows"
)

-- No download page, no archive: the install stops with the page it could not read.
local ok, message = install("2.9.0.1", false)
assert(not ok, "a version without a download page must fail")
assert(tostring(message):find("2.9.0.1", 1, true), "the error names the version: " .. tostring(message))
cases = cases + 1

-- "3.9.0 LTS" is the version 3.9.0 with a note. With its space it is no version, so no URL is made.
local lts_ok, lts_message = install("3.9.0 LTS", false)
assert(
    not lts_ok and tostring(lts_message):find("not a Scala version", 1, true),
    "an LTS name is refused: " .. tostring(lts_message)
)
cases = cases + 1

-- downloads.lightbend.com answers 403 for every Scala release, so no request goes there.
for _, url in ipairs(requests) do
    assert(not url:find("downloads.lightbend.com", 1, true), "lightbend is not used: " .. url)
end
cases = cases + 1

print("PASS: " .. cases .. " PreInstall cases")
