#!/usr/bin/env ruby
# frozen_string_literal: true

require 'net/http'
require 'nokogiri'
require 'uri'
# require 'pry'

# Things to be done:
# 1. Some web pages may use advanced loading techniques ( CDNs, or scripts to load content, data URLs, sprites and etc)
# 2. There could be issues with relative URLs, cross-origin assets (-> not handled)
# 3. CSS and JS could be minified or combined. (-> not handled)
# 4. This script does not handle redirects, authentication and cookies
# 5. Dynamic Content, Robots.txt and etc. (-> not handled)
# 6. Script could take a significant amount of time to run, depending on the size of the website (fonts and etc.)

class WebFetcher
  USER_AGENT = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'

  def initialize(url)
    @url = url
    @errors = []
  end

  def fetch_content(url = @url)
    uri = URI(url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true if uri.scheme == 'https'
    request = Net::HTTP::Get.new(uri.request_uri, {
                                   'User-Agent' => USER_AGENT
                                 })
    response = http.request(request)
    response.body
  rescue SocketError, Errno::ECONNREFUSED, Net::OpenTimeout, Net::ReadTimeout, OpenSSL::SSL::SSLError => e
    @errors << "Network Error fetching #{url}: #{e.message}"
    nil
  rescue StandardError => e
    @errors << "Error fetching #{url}: #{e.message}"
    nil
  end

  def create_site_folder
    folder_name = URI(@url).host
    Dir.mkdir(folder_name) unless Dir.exist?(folder_name)
    folder_name
  end

  def save_content(filename, content)
    folder_name = create_site_folder
    full_path = File.join(folder_name, filename)
    File.open(full_path, 'wb') do |file|
      file.write(content)
    end
  end

  def print_metadata(content)
    doc = Nokogiri::HTML(content)
    links = doc.css('a').count
    images = doc.css('img').count
    puts "site: #{URI(@url).host}"
    puts "num_links: #{links}"
    puts "images: #{images}"
    puts "last_fetch: #{Time.now.utc}"
  end

  def download_assets(doc)
    base_uri = URI(@url)

    fetch_and_replace = lambda { |node, attr_name|
      relative_url = node[attr_name]

      return if relative_url.nil?

      return if relative_url.start_with?('data:')

      begin
        asset_url = URI.join(base_uri, relative_url).to_s
        original_url = @url
        @url = asset_url
        asset_content = fetch_content
        @url = original_url

        return unless asset_content

        asset_filename = URI(asset_url).path.split('/').last
        save_content(asset_filename, asset_content)

        if asset_filename.end_with?('.css')
          asset_content.gsub!(/url\(['"]?(.+?)['"]?\)/) do |match|
            nested_relative_url = ::Regexp.last_match(1)

            next match if nested_relative_url.start_with?('data:')

            nested_url = URI.join(URI(asset_url), nested_relative_url).to_s
            nested_content = fetch_content(nested_url)

            if nested_content
              nested_filename = URI(nested_url).path.split('/').last
              save_content(nested_filename, nested_content)
              "url(#{nested_filename})"
            else
              match
            end
          end
          save_content(asset_filename, asset_content)
        end

        node[attr_name] = asset_filename
      rescue URI::InvalidURIError => e
        @errors << "Error processing URL #{relative_url}: #{e.message}"
      rescue StandardError => e
        @errors << "Error processing asset from URL #{asset_url}: #{e.message}"
      end
    }

    doc.css('img').each { |img| fetch_and_replace.call(img, 'src') }
    doc.css('link[rel="stylesheet"]').each { |link| fetch_and_replace.call(link, 'href') }
    doc.css('script[src]').each { |script| fetch_and_replace.call(script, 'src') }

    @errors.each { |error| puts error }
  end

  def fetch(show_metadata: false)
    content = fetch_content
    return unless content

    doc = Nokogiri::HTML(content)

    download_assets(doc)

    updated_html = doc.to_html
    save_content("#{URI(@url).host}.html", updated_html)

    print_metadata(updated_html) if show_metadata
  end
end

def main
  show_metadata = ARGV.include?('--metadata')
  urls = ARGV.reject { |arg| arg == '--metadata' }

  urls.each do |url|
    fetcher = WebFetcher.new(url)
    fetcher.fetch(show_metadata: show_metadata)
  end
end

main
