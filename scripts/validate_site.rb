#!/usr/bin/env ruby

require "yaml"
require "date"

ROOT = File.expand_path("..", __dir__)
CONFIG_PATH = File.join(ROOT, "config.yml")
CONTENT_GLOB = File.join(ROOT, "entries", "**", "*.md")

errors = []

begin
  config = YAML.safe_load(File.read(CONFIG_PATH), permitted_classes: [Date, Time], aliases: true) || {}
rescue StandardError => e
  warn "config.yml could not be parsed: #{e.message}"
  exit 1
end

%w[title url repository author languages appearance].each do |key|
  errors << "config.yml is missing '#{key}'" unless config.key?(key)
end

languages = Array(config.dig("languages", "available")).map { |item| item["code"] }.compact
errors << "No languages are configured" if languages.empty?

def front_matter(path)
  source = File.read(path)
  match = source.match(/\A---\s*\n(.*?)\n---\s*\n/m)
  return nil unless match

  YAML.safe_load(match[1], permitted_classes: [Date, Time], aliases: true) || {}
end

seen = {}
Dir.glob(CONTENT_GLOB).sort.each do |path|
  relative = path.delete_prefix("#{ROOT}/")
  data = front_matter(path)

  unless data
    errors << "#{relative}: missing YAML front matter"
    next
  end

  %w[title type layout lang slug permalink date excerpt].each do |key|
    errors << "#{relative}: missing '#{key}'" if data[key].nil? || data[key].to_s.strip.empty?
  end

  if data["lang"] && !languages.include?(data["lang"])
    errors << "#{relative}: language '#{data['lang']}' is not configured"
  end

  if data["type"] && !%w[project article].include?(data["type"])
    errors << "#{relative}: unsupported type '#{data['type']}'"
  end

  if data["permalink"] && !data["permalink"].start_with?("/")
    errors << "#{relative}: permalink must start with '/'"
  end

  key = [data["slug"], data["lang"]]
  if key.all?
    errors << "#{relative}: duplicate slug/language pair #{key.join(':')}" if seen[key]
    seen[key] = relative
  end

  %w[image thumbnail cover].each do |field|
    asset = data[field].to_s
    next if asset.empty? || asset.start_with?("http://", "https://")

    asset_path = File.join(ROOT, asset.sub(%r{\A/}, ""))
    errors << "#{relative}: #{field} not found at #{asset}" unless File.file?(asset_path)
  end
end

if errors.empty?
  puts "Site validation passed (#{seen.length} localized entries checked)."
  exit 0
end

warn "Site validation failed with #{errors.length} issue(s):"
errors.each { |error| warn "- #{error}" }
exit 1
