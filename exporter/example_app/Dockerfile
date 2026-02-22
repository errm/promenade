FROM ruby:4.0

WORKDIR /usr/src/app

COPY Gemfile Gemfile.lock ./
Run bundle install

COPY config.ru ./
COPY pitchfork.rb ./

CMD ["bundle", "exec", "pitchfork", "-c", "pitchfork.rb"]
