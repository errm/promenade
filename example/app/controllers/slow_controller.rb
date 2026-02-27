class SlowController < ApplicationController
  def index
    sleep 1
    head :ok
  end

  def show
    sleep params[:id].to_i
    head :ok
  end
end
