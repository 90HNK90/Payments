# Dockerfile
FROM ruby:3.1.2-slim
WORKDIR /usr/src/app
RUN apt-get update -qq && apt-get install -y build-essential libpq-dev
COPY Gemfile* .
RUN bundle install --jobs $(nproc) --retry 3
COPY . .
EXPOSE 4567
CMD ["bundle", "exec", "puma"]
