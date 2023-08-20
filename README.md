# Web Fetcher


### How to use:

#### Locally

1. `gem install nokogiri rspec webmock`
2. `ruby fetcher.rb --metadata https://finevest.co`
3. `rspec fetcher_spec.rb`

#### Docker

1. `docker build -t fetcher-image .`


2.  Run rspec
  ```
  docker run -it --entrypoint /bin/bash fetcher-image
  rspec fetcher_spec.rb
  ```

3. Run the script

  ```bash

  docker run fetcher --metadata https://www.google.com
  ```