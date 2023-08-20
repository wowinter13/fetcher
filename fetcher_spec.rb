# frozen_string_literal: true

require_relative './fetcher'
require 'webmock/rspec'

# Specs just cover the basic functionality of the script.
# Because of the time constraints, I didn't have time to write more detailed specs.

RSpec.describe WebFetcher do
  let(:test_url) { 'https://test.com' }
  let(:fetcher) { WebFetcher.new(test_url) }

  describe '#fetch_content' do
    context 'when the URL is valid' do
      before do
        stub_request(:get, test_url).to_return(body: 'Hello, World!')
      end

      it 'fetches the content' do
        expect(fetcher.fetch_content).to eq('Hello, World!')
      end
    end

    context 'when there is a network error' do
      before do
        stub_request(:get, test_url).to_timeout
      end

      it 'captures the error message' do
        fetcher.fetch_content
        expect(fetcher.instance_variable_get(:@errors)).to include(a_string_matching(/Network Error/))
      end
    end
  end

  describe '#print_metadata' do
    let(:sample_content) do
      <<-HTML
        <html>
          <body>
            <a href="#"></a>
            <a href="#"></a>
            <img src="img1.png">
            <img src="img2.png">
          </body>
        </html>
      HTML
    end

    it 'prints metadata information' do
      expect { fetcher.send(:print_metadata, sample_content) }
        .to output(
          match(/site: test.com/)
          .and(match(/num_links: 2/))
          .and(match(/images: 2/))
          .and(match(/last_fetch:/))
        ).to_stdout
    end
  end

  describe '#download_assets' do
    let(:sample_html) { Nokogiri::HTML('<img src="https://test.com/img1.png">') }

    it 'processes assets and updates their references' do
      stub_request(:get, 'https://test.com/img1.png').to_return(body: 'image_content')

      fetcher.send(:download_assets, sample_html)
      img_tag = sample_html.css('img').first
      expect(img_tag['src']).to match(/img1.png/)
      expect(File.exist?('test.com/img1.png')).to be true
    end
  end

  describe '#fetch' do
    before do
      stub_request(:get, test_url).to_return(body: '<html></html>')
    end

    it 'fetches, processes, and saves the content' do
      fetcher.fetch
      expect(File.exist?('test.com/test.com.html')).to be true
    end
  end
end
