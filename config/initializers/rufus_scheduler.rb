require 'rufus-scheduler'

if Rails.env.production? && defined?(Rails::Server) && !defined?($rufus_scheduler)
  puts "Starting Rufus scheduler."
  $rufus_scheduler = Rufus::Scheduler.new(tz: 'America/Los_Angeles')

  # Run at 11:00 AM and 7:00 PM every day.
  $rufus_scheduler.cron '0 11,19 * * *' do
    UnreadMentionsNotifierJob.new.perform
  end
end
