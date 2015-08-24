FROM ruby:2.2.3

ENV LANG="C.UTF-8"
ENV LANGUAGE="C.UTF-8"
ENV LC_ALL="C.UTF-8"

# update stuff, install node (for execjs)
RUN apt-get update -qq && apt-get install -y nodejs

# bundle in cache for faster builds
# see also: http://ilikestuffblog.com/2014/01/06/how-to-skip-bundle-install-when-deploying-a-rails-app-to-docker/
WORKDIR /tmp
COPY Gemfile Gemfile
COPY Gemfile.lock Gemfile.lock
RUN bundle install

RUN mkdir /identity
WORKDIR /identity
ADD . /identity
