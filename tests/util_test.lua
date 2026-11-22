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
test.load()
local util = require("util")

local cases = 0

local function check(got, expected, message)
    assert(got == expected, message .. ": expected " .. tostring(expected) .. ", got " .. tostring(got))
    cases = cases + 1
end

-- Lines of the download list as scala-lang.org has them on 2026-11-21.
local LISTING = [[
<div class="download-elem">
                <a href="/download/3.10.1.html">Scala 3.10.1</a>
              </div>
<div class="download-elem">
                <a href="/download/3.9.0.html">Scala 3.9.0 LTS</a>
              </div>
<div class="download-elem">
                <a href="/download/2.13.0-M5.html">Scala 2.13.0-M5</a>
              </div>
<div class="download-elem">
                <a href="/download/2.5.0.final.html">Scala 2.5.0.final</a>
              </div>
]]

local listing = util.parse_listing(LISTING)
check(#listing, 4, "listing count")
check(listing[1].version, "3.10.1", "plain version")
check(listing[1].note, "", "plain version has no note")
check(listing[2].version, "3.9.0", "LTS version is cut from its note")
check(listing[2].note, "LTS", "LTS note")
check(listing[3].version, "2.13.0-M5", "milestone keeps its suffix")
check(listing[4].version, "2.5.0.final", "old release keeps .final")

-- Where each version comes from.
check(util.source_of("3.0.0"), "scala3", "3.0.0 is Scala 3")
check(util.source_of("3.0.0-RC1"), "scala3", "a Scala 3 release candidate is Scala 3")
check(util.source_of("2.13.14"), "scala2", "2.13 comes from GitHub")
check(util.source_of("2.11.0-RC1"), "scala2", "2.11 starts GitHub")
check(util.source_of("2.10.4"), "archive", "2.10.4 is on scala-lang.org")
check(util.source_of("2.10.4-RC3"), "archive", "2.10.4 candidates are on scala-lang.org")
check(util.source_of("2.5.0.final"), "archive", ".final releases are on scala-lang.org")

-- GitHub addresses: Scala 3 ships tar.gz, Scala 2 tgz, Windows zip.
check(
    util.github_url("3.0.0", false),
    "https://github.com/scala/scala3/releases/download/3.0.0/scala3-3.0.0.tar.gz",
    "Scala 3.0.0 is tar.gz, not tgz"
)
check(
    util.github_url("3.0.0-RC1", false),
    "https://github.com/scala/scala3/releases/download/3.0.0-RC1/scala3-3.0.0-RC1.tar.gz",
    "Scala 3 candidate is tar.gz"
)
check(
    util.github_url("3.10.1", true),
    "https://github.com/scala/scala3/releases/download/3.10.1/scala3-3.10.1.zip",
    "Scala 3 on Windows is zip"
)
check(
    util.github_url("2.13.14", false),
    "https://github.com/scala/scala/releases/download/v2.13.14/scala-2.13.14.tgz",
    "Scala 2.13 is tgz on GitHub"
)
check(
    util.github_url("2.13.0-M5", true),
    "https://github.com/scala/scala/releases/download/v2.13.0-M5/scala-2.13.0-M5.zip",
    "Scala 2 milestone on Windows is zip"
)
check(util.github_url("2.10.4", false), nil, "2.10.4 has no GitHub address")

-- The archive of an old release is named on its download page.
local PAGE_2_10_4 = [[
<a id="#link-main-unixsys" href="https://scala-lang.org/files/archive/scala-2.10.4.tgz">
<a id="#link-main-windows" href="https://scala-lang.org/files/archive/scala-2.10.4.msi">
<a id="#link-non-main-sys" href="https://scala-lang.org/files/archive/scala-2.10.4.zip">
<a id="#link-non-main-sys" href="https://scala-lang.org/files/archive/scala-2.10.4.deb">
<a href="https://scala-lang.org/files/archive/scala-docs-2.10.4.zip">
<a href="https://scala-lang.org/files/archive/spec/2.13/">
<a href="https://github.com/scala/scala/archive/v2.10.4.tar.gz">
]]
check(
    util.archive_url_from_page(PAGE_2_10_4, false),
    "https://scala-lang.org/files/archive/scala-2.10.4.tgz",
    "2.10.4 unix archive"
)
check(
    util.archive_url_from_page(PAGE_2_10_4, true),
    "https://scala-lang.org/files/archive/scala-2.10.4.zip",
    "2.10.4 windows archive"
)

-- Scala 2.10.5 to 2.10.7 link their archives on GitHub, not on scala-lang.org.
local PAGE_2_10_5 = [[
<a id="#link-main-unixsys" href="https://github.com/scala/scala/releases/download/v2.10.5/scala-2.10.5.tgz">
<a id="#link-main-windows" href="https://github.com/scala/scala/releases/download/v2.10.5/scala-2.10.5.msi">
<a id="#link-non-main-sys" href="https://github.com/scala/scala/releases/download/v2.10.5/scala-2.10.5.zip">
<a id="#link-non-main-sys" href="https://github.com/scala/scala/releases/download/v2.10.5/scala-2.10.5.deb">
<a id="#link-non-main-sys" href="https://github.com/scala/scala/releases/download/v2.10.5/scala-docs-2.10.5.zip">
<a id="#link-non-main-sys" href="https://github.com/scala/scala/archive/v2.10.5.tar.gz">
]]
check(
    util.archive_url_from_page(PAGE_2_10_5, false),
    "https://github.com/scala/scala/releases/download/v2.10.5/scala-2.10.5.tgz",
    "2.10.5 unix archive on GitHub"
)
check(
    util.archive_url_from_page(PAGE_2_10_5, true),
    "https://github.com/scala/scala/releases/download/v2.10.5/scala-2.10.5.zip",
    "2.10.5 windows archive on GitHub"
)
check(
    util.archive_url_from_page('<a href="https://github.com/scala/scala/archive/v2.10.5.tar.gz">', false),
    nil,
    "a GitHub source archive is not a distribution"
)

-- A name with a space is not a version: `3.9.0 LTS` has no major number.
check(util.major_minor("3.9.0 LTS"), nil, "an LTS name is not a version")

local PAGE_2_7_0_FINAL = [[
<a id="#link-main-unixsys" href="https://scala-lang.org/files/archive/scala-2.7.0-final.tar.gz">
<a id="#link-main-windows" href="https://scala-lang.org/files/archive/scala-2.7.0-final.zip">
<a href="https://scala-lang.org/files/archive/scala-docs-2.7.0-final.zip">
]]
check(
    util.archive_url_from_page(PAGE_2_7_0_FINAL, false),
    "https://scala-lang.org/files/archive/scala-2.7.0-final.tar.gz",
    "2.7.0 final prefers tar.gz"
)

check(
    util.archive_url_from_page('<a href="https://scala-lang.org/files/archive/scala-2.9.0.msi">', false),
    nil,
    "an msi is not a distribution"
)

-- Checksums: `<digest>  <name>`, in lower case, and nothing else.
local DIGEST = string.rep("0123456789abcdef", 4)
check(util.parse_sha256(DIGEST:upper() .. "  scala3-3.10.1.tar.gz\n"), DIGEST, "digest is lower-cased")
check(util.parse_sha256(DIGEST), DIGEST, "a bare digest")
check(util.parse_sha256("not a digest"), nil, "text without a digest")
check(util.parse_sha256(string.rep("a", 63)), nil, "a short digest")
check(util.parse_sha256(string.rep("a", 128)), nil, "a SHA-512 length is not SHA-256")
check(util.parse_sha256(nil), nil, "no text")

-- Names of the list and their notes.
local version, note = util.parse_listing_name("Scala 3.3.9 LTS")
check(version, "3.3.9", "LTS name version")
check(note, "LTS", "LTS name note")
version, note = util.parse_listing_name("Scala 2.7.7.final")
check(version, "2.7.7.final", "old name version")
check(note, "", "old name note")

print("PASS: " .. cases .. " util cases")
