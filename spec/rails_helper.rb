# Configure Rails Environment
ENV["RAILS_ENV"] = "test"
require_relative "../spec/dummy/config/environment"
require "spec_helper"
require "rspec/rails"
