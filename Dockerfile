FROM ruby:2.7

# Install system dependencies for nokogiri
RUN apt-get update -qq && apt-get install -y libxml2-dev libxslt1-dev && \
  rm -rf /var/lib/apt/lists/*

RUN gem install nokogiri -v '1.11.7'
RUN gem install rspec webmock

# Create a new user
RUN useradd -m myuser
USER myuser

WORKDIR /app

# Copy our fetch script into the container
COPY --chown=myuser fetcher.rb /app/
COPY --chown=myuser fetcher_spec.rb /app/

# Grant execute permissions to the script
RUN chmod +x /app/fetcher.rb

# Default command to run our fetch script
ENTRYPOINT ["/app/fetcher.rb"]