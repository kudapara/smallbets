require "rufus-scheduler"

Rails.application.config.after_initialize do
  if Rails.env.production? && defined?(Rails::Server) && !defined?($rufus_scheduler)
    Rails.logger.info "Starting Rufus scheduler."
    $rufus_scheduler = Rufus::Scheduler.new(tz: "America/Los_Angeles")

    # Run at 1:00 AM and 1:00 PM every day.
    $rufus_scheduler.cron "0 1,4,5,13 * * *" do
      UnreadMentionsNotifierJob.new.perform
    end
  end
end
