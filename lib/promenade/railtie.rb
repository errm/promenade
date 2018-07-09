require "promenade/setup"

module Promenade
  class Railtie < ::Rails::Railtie
    initializer "promenade.configure_rails_initialization" do
      Promenade.setup
    end
  end
end
