#!/usr/bin/env ruby

require 'set'
require 'cgi'

def print_usage
  puts <<USAGE
Usage:
  #{$0} <base_dir> : Check relative links in "*.md" under <base_dir> and report any dead links found.
USAGE
end

class RelativeLink
  attr_reader :url

  def initialize(f, link_expr, index)
    @path = f.path
    @index = index
    @link_expr = link_expr
    relative_path = File.join(File.dirname(@path), @link_expr[/\[.*\]\((.*?)\)/, 1])
    @url = File.expand_path(relative_path).sub(f.base_dir, '')
  end

  def to_s
    "#{@path}:#{@index} --- #{@link_expr}"
  end
end

class MarkdownFile
  attr_reader :base_dir, :path, :section_urls, :rel_links

  def initialize(base_dir, path)
    @base_dir = base_dir
    @path = path
    @content_lines = File.read(@path).split("\n")
    @section_urls = @content_lines.grep(/^#+ /).map { |l| line_to_section_url(l) }
    @rel_links    = @content_lines.flat_map.with_index(1) { |l, i| line_to_relative_links(l, i) }
  end

  def line_to_section_url(l)
    section_name = l.sub(/^#+ /, '').downcase.gsub(' ', '-').gsub(/[!-,:-@\[-\^{-~.\/`]/, '')
    @path + '#' + CGI.escape(section_name)
  end

  def line_to_relative_links(line, index)
    line.scan(/\[.*\]\(.*\)/)
      .select { |match| match !~ /https?:\/\// && match =~ /\.md/ }
      .map { |link_expr| RelativeLink.new(self, link_expr, index) }
  end
end

def check(base_dir)
  base_dir = base_dir.end_with?('/') ? base_dir : base_dir + '/'
  Dir.chdir base_dir

  md_file_paths = Dir['**/*.md'].sort
  md_files = md_file_paths.map { |f| MarkdownFile.new(base_dir, f) }
  section_urls = md_files.flat_map(&:section_urls)
  acceptable_url_set = Set.new(md_file_paths + section_urls)

  relative_links = md_files.flat_map(&:rel_links)
  links_ng = relative_links.reject { |link| acceptable_url_set.include?(link.url) }
  if links_ng.empty?
    puts 'All links are working!'
  else
    puts "Dead links found! (#{links_ng.size})\n\n"
    links_ng.each { |dead_link| puts dead_link }
  end
end

if ARGV.size != 1
  print_usage
else
  check(ARGV.first)
end
