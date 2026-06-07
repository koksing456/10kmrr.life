#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

cd "$ROOT_DIR"

/usr/bin/ruby <<'RUBY'
require "cgi"
require "find"
require "pathname"
require "shellwords"
require "uri"

ROOT = Pathname.new(Dir.pwd)
SKIP_DIRS = %w[.git .codex Atoll build opc-doc].freeze
LINK_PATTERN = /!?\[[^\]]*\]\(([^)\s]+)(?:\s+"[^"]*")?\)/
REFERENCE_PATTERN = /^\s*\[[^\]]+\]:\s+(\S+)/

def markdown_files
  files = []
  Find.find(ROOT.to_s) do |path|
    basename = File.basename(path)
    if File.directory?(path) && SKIP_DIRS.include?(basename)
      Find.prune
      next
    end
    files << Pathname.new(path) if path.end_with?(".md")
  end
  files.sort
end

def external_or_anchor?(target)
  target.start_with?("#") ||
    target.match?(/\A[a-z][a-z0-9+.-]*:/i) ||
    target.start_with?("//")
end

def normalized_target(raw_target)
  target = raw_target.strip
  target = target[1..-2] if target.start_with?("<") && target.end_with?(">")
  target = target.split("#", 2).first
  target = target.split("?", 2).first
  CGI.unescape(target)
end

failures = []

markdown_files.each do |file|
  content = file.read
  links = content.scan(LINK_PATTERN).flatten + content.scan(REFERENCE_PATTERN).flatten
  links.each do |raw_target|
    next if external_or_anchor?(raw_target)

    target = normalized_target(raw_target)
    next if target.empty?

    resolved = (file.dirname + target).cleanpath
    unless resolved.to_s.start_with?(ROOT.to_s + "/") || resolved == ROOT
      failures << "#{file.relative_path_from(ROOT)}: link escapes repo: #{raw_target}"
      next
    end

    next if resolved.exist?

    failures << "#{file.relative_path_from(ROOT)}: missing link target: #{raw_target}"
  end
end

if failures.empty?
  puts "Markdown local links verified (#{markdown_files.size} files)."
else
  warn failures.join("\n")
  exit 1
end
RUBY
