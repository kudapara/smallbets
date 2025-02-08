class StatsController < ApplicationController
  layout "application"

  def index
    @daily_stats = Message.select("strftime('%Y-%m-%d', created_at) as date, count(*) as count")
                         .group('date')
                         .order('date DESC')
                         .limit(30)

    @all_time_stats = Message.select("strftime('%Y-%m-%d', created_at) as date, count(*) as count")
                            .group('date')
                            .order('date ASC')

    @top_posters = User.select('users.id, users.name, COUNT(messages.id) AS message_count')
                       .joins(messages: :room)
                       .where('rooms.type != ? AND messages.created_at >= ?', 
                             'Rooms::Direct', 
                             30.days.ago)
                       .group('users.id')
                       .order('message_count DESC')
                       .limit(30)

    @top_posters_all_time = User.select('users.id, users.name, COUNT(messages.id) AS message_count')
                              .joins(messages: :room)
                              .where('rooms.type != ?', 'Rooms::Direct')
                              .group('users.id')
                              .order('message_count DESC')
                              .limit(30)

    @top_posters_24h = User.select('users.id, users.name, COUNT(messages.id) AS message_count')
                          .joins(messages: :room)
                          .where('rooms.type != ? AND messages.created_at >= ?', 
                                'Rooms::Direct', 
                                24.hours.ago)
                          .group('users.id')
                          .order('message_count DESC')
                          .limit(30)

    @newest_members = User
      .where(active: true)
      .where(suspended_at: nil)
      .order(created_at: :desc)
      .limit(30)
  end
end 