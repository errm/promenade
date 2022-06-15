Rails.application.routes.draw do
  get "success" => "test_responses#success"
  get "server-error" => "test_responses#server_error"
  get "client-error" => "test_responses#client_error"
  get "not-found" => "test_responses#not_found"
  match "404", to: "errors#not_found", code: "404", via: :all
end
