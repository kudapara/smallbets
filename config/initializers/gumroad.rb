Rails.application.config.after_initialize do
  GumroadAPI.access_token = ENV["GUMROAD_ACCESS_TOKEN"]
end