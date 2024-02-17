# syntax = docker/dockerfile:1

# Make sure it matches the Ruby version in .ruby-version and Gemfile
ARG RUBY_VERSION=3.3.0-rc1
FROM ruby:$RUBY_VERSION-slim as base

# Rails app lives here
WORKDIR /rails

# Set production environment
ENV RAILS_ENV="production" \
    BUNDLE_DEPLOYMENT="1" \
    BUNDLE_PATH="/usr/local/bundle" \
    BUNDLE_WITHOUT="development" \
    DISABLE_SSL=true


# Throw-away build stage to reduce size of final image
FROM --platform=$TARGETPLATFORM base as build

# Install packages need to build gems
RUN apt-get update -qq && \
    apt-get install -y build-essential git pkg-config

# Install application gems
COPY Gemfile Gemfile.lock ./
RUN bundle install && \
    rm -rf ~/.bundle/ "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git

# Copy application code
RUN mkdir -p /home/campfire/storage
RUN ln -s /home/campfire/storage/

COPY . .

# Precompiling assets for production without requiring secret RAILS_MASTER_KEY
RUN SECRET_KEY_BASE_DUMMY=1 ./bin/rails assets:precompile


# Build stage for Thruster
FROM --platform=$BUILDPLATFORM golang:1.21 as thruster
ARG TARGETARCH
WORKDIR /thruster
COPY packaging/thruster ./
# Cross compile for target architecture
RUN GOOS=linux GOARCH=$TARGETARCH go build -o bin/ ./cmd/...


# Final stage for app image
FROM base

# Configure environment defaults
ENV HTTP_IDLE_TIMEOUT=60
ENV HTTP_READ_TIMEOUT=300
ENV HTTP_WRITE_TIMEOUT=300

# Install packages needed to run the application
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y libsqlite3-0 libvips curl ffmpeg redis git openssh-server dialog && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# Copy built artifacts: gems, application
COPY --from=build /usr/local/bundle /usr/local/bundle
COPY --from=build /rails /rails
COPY --from=thruster /thruster/bin/thrust /rails/bin/thrust

# Set version and revision
ARG APP_VERSION
ENV APP_VERSION=$APP_VERSION
ARG GIT_REVISION
ENV GIT_REVISION=$GIT_REVISION

# Expose ports for HTTP and HTTPS
EXPOSE 3000 2222

COPY sshd_config /etc/ssh/
RUN echo "root:Docker!" | chpasswd

RUN mkdir -p /home/campfire/storage

# Start the server by default, this can be overwritten at runtime
CMD service ssh start && bin/boot