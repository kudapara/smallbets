require "rufus-scheduler"

Rails.application.config.after_initialize do
  if Rails.env.production? && defined?(Rails::Server) && !defined?($rufus_scheduler)
    Rails.logger.info "Starting Rufus scheduler."
    $rufus_scheduler = Rufus::Scheduler.new

    # Run at 1:00 AM and 1:00 PM every day.
    $rufus_scheduler.cron "0 1,6,7,13 * * * America/Los_Angeles" do
      UnreadMentionsNotifierJob.new.perform
    end
  end
end
