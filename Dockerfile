FROM ruby:3.4 AS builder

WORKDIR /app
RUN gem install bundler
RUN bundle config set without 'development test'

COPY Gemfile Gemfile.lock ./
RUN bundle install

COPY config.ru slack_bot.rb ./
COPY config/ config/
COPY lib/ lib/

# hadolint ignore=DL3006
FROM gcr.io/distroless/base-debian12

COPY --from=builder /usr/local /usr/local
COPY --from=builder /app /app
COPY --from=builder /lib /lib

WORKDIR /app

EXPOSE 4567

ENTRYPOINT ["bundle", "exec"]
CMD ["puma", "-C", "config/puma.rb"]
