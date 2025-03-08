class StatsController < ApplicationController
  layout "application"
  include AccountsHelper

  def index
    @total_users = User.where(active: true, suspended_at: nil).count
    @total_messages = Message.count
    @total_boosts = Boost.count
    @online_users = online_users_count
    @total_posters = User.active.joins(messages: :room)
                         .where('rooms.type != ?', 'Rooms::Direct')
                         .where('messages.active = ?', true)
                         .distinct.count
    
    db_path = ActiveRecord::Base.connection_db_config.configuration_hash[:database]
    @database_size = File.size(db_path) rescue 0
    
    # System metrics
    begin
      # CPU utilization and cores
      cpu_output = `top -l 1 -n 0 | grep "CPU usage"`.strip
      @cpu_util = cpu_output.match(/(\d+\.\d+)% user/)[1].to_f rescue nil
      
      # Get number of CPU cores
      @cpu_cores = `sysctl -n hw.ncpu`.strip.to_i rescue nil
      
      # Memory usage - improved for macOS
      begin
        memory_info = {}
        `vm_stat`.split("\n").drop(1).each do |line|
          if line =~ /^(.+):\s+(\d+)\.$/
            memory_info[$1.strip] = $2.to_i
          end
        end
        
        # Calculate free memory percentage
        page_size = 4096  # Default page size in bytes
        free_pages = memory_info["Pages free"] || 0
        inactive_pages = memory_info["Pages inactive"] || 0
        speculative_pages = memory_info["Pages speculative"] || 0
        wired_pages = memory_info["Pages wired down"] || 0
        active_pages = memory_info["Pages active"] || 0
        compressed_pages = memory_info["Pages occupied by compressor"] || 0
        
        total_pages = free_pages + inactive_pages + active_pages + speculative_pages + wired_pages + compressed_pages
        available_pages = free_pages + inactive_pages + speculative_pages
        
        @free_memory_percent = ((available_pages.to_f / total_pages) * 100).round(1) if total_pages > 0
        
        # Calculate total memory in GB
        @total_memory_gb = (`sysctl -n hw.memsize`.to_i / 1024.0 / 1024.0 / 1024.0).round(1) rescue nil
      rescue => e
        Rails.logger.error("Error parsing memory info: #{e.message}")
        @free_memory_percent = nil
        @total_memory_gb = nil
      end
      
      # Disk usage
      begin
        disk_output = `df -h /`.strip
        disk_line = disk_output.split("\n").last
        disk_parts = disk_line.split(/\s+/)
        
        @free_disk_percent = 100 - disk_parts[4].to_i rescue nil
        @total_disk_gb = disk_parts[1].gsub(/[A-Za-z]/, '').to_f rescue nil
      rescue => e
        Rails.logger.error("Error parsing disk info: #{e.message}")
        @free_disk_percent = nil
        @total_disk_gb = nil
      end
    rescue => e
      # Silently fail if we can't get system metrics
      Rails.logger.error("Error getting system metrics: #{e.message}")
    end

    @daily_stats = Message.select("strftime('%Y-%m-%d', created_at) as date, count(*) as count")
                         .group('date')
                         .order('date DESC')
                         .limit(30)

    @all_time_stats = Message.select("strftime('%Y-%m-%d', created_at) as date, count(*) as count")
                            .group('date')
                            .order('date ASC')

    # Today (UTC)
    today_start = Time.now.utc.beginning_of_day
    @top_posters_today = User.select('users.id, users.name, COUNT(messages.id) AS message_count, COALESCE(users.membership_started_at, users.created_at) as joined_at')
                           .joins(messages: :room)
                           .where('rooms.type != ? AND messages.created_at >= ? AND messages.active = true', 
                                 'Rooms::Direct', 
                                 today_start)
                           .where('users.active = true AND users.suspended_at IS NULL')
                           .group('users.id, users.name, users.membership_started_at, users.created_at')
                           .order('message_count DESC, joined_at ASC')
                           .limit(30)
    
    # Get current user's stats for today if not in top 10
    if Current.user
      current_user_in_top_10_today = @top_posters_today.first(10).any? { |user| user.id == Current.user.id }
      
      if !current_user_in_top_10_today
        today_start_formatted = today_start.strftime('%Y-%m-%d %H:%M:%S')
        @current_user_today_stats = User.select('users.id, users.name, COALESCE(COUNT(messages.id), 0) AS message_count')
                                    .joins("LEFT JOIN messages ON messages.creator_id = users.id AND messages.created_at >= '#{today_start_formatted}' AND messages.active = true
                                           LEFT JOIN rooms ON messages.room_id = rooms.id AND rooms.type != 'Rooms::Direct'")
                                    .where('users.id = ?', Current.user.id)
                                    .group('users.id')
                                    .first
        
        # Always ensure we have stats for the current user
        if @current_user_today_stats.nil?
          @current_user_today_stats = User.select('users.id, users.name, 0 AS message_count')
                                      .where('users.id = ?', Current.user.id)
                                      .first
        end
        
        if @current_user_today_stats
          # Get total number of active users for proper ranking context
          @total_active_users = User.where(active: true, suspended_at: nil).count
          
          # Count users with more messages
          users_with_more_messages = User.joins(messages: :room)
                                       .where('rooms.type != ? AND messages.created_at >= ? AND messages.active = true', 
                                             'Rooms::Direct', today_start)
                                       .where('users.active = true AND users.suspended_at IS NULL')
                                       .group('users.id')
                                       .having('COUNT(messages.id) > ?', @current_user_today_stats.message_count.to_i)
                                       .count.size
          
          # Count users with same number of messages but earlier join date
          if @current_user_today_stats.message_count.to_i > 0
            users_with_same_messages_earlier_join = User.joins(messages: :room)
                                                     .where('rooms.type != ? AND messages.created_at >= ? AND messages.active = true', 
                                                           'Rooms::Direct', today_start)
                                                     .where('users.active = true AND users.suspended_at IS NULL')
                                                     .group('users.id')
                                                     .having('COUNT(messages.id) = ?', @current_user_today_stats.message_count.to_i)
                                                     .where('COALESCE(users.membership_started_at, users.created_at) < ?', 
                                                           Current.user.membership_started_at || Current.user.created_at)
                                                     .count.size
          else
            # For users with 0 messages, count users with earlier join date
            users_with_same_messages_earlier_join = User.where('COALESCE(membership_started_at, created_at) < ?', 
                                                             Current.user.membership_started_at || Current.user.created_at)
                                                     .where('active = true AND suspended_at IS NULL')
                                                     .count
          end
          
          @current_user_today_rank = users_with_more_messages + users_with_same_messages_earlier_join + 1
          
          # Sanity check: rank should never exceed total active users
          @current_user_today_rank = [@current_user_today_rank, @total_active_users].min
        end
      end
    end

    # This Month (UTC)
    month_start = Time.now.utc.beginning_of_month
    @top_posters_month = User.select('users.id, users.name, COUNT(messages.id) AS message_count, COALESCE(users.membership_started_at, users.created_at) as joined_at')
                           .joins(messages: :room)
                           .where('rooms.type != ? AND messages.created_at >= ? AND messages.active = true', 
                                 'Rooms::Direct', 
                                 month_start)
                           .where('users.active = true AND users.suspended_at IS NULL')
                           .group('users.id, users.name, users.membership_started_at, users.created_at')
                           .order('message_count DESC, joined_at ASC')
                           .limit(30)
    
    # Get current user's stats for month if not in top 10
    if Current.user
      current_user_in_top_10_month = @top_posters_month.first(10).any? { |user| user.id == Current.user.id }
      
      if !current_user_in_top_10_month
        month_start_formatted = month_start.strftime('%Y-%m-%d %H:%M:%S')
        @current_user_month_stats = User.select('users.id, users.name, COALESCE(COUNT(messages.id), 0) AS message_count')
                                    .joins("LEFT JOIN messages ON messages.creator_id = users.id AND messages.created_at >= '#{month_start_formatted}' AND messages.active = true
                                           LEFT JOIN rooms ON messages.room_id = rooms.id AND rooms.type != 'Rooms::Direct'")
                                    .where('users.id = ?', Current.user.id)
                                    .group('users.id')
                                    .first
        
        # Always ensure we have stats for the current user
        if @current_user_month_stats.nil?
          @current_user_month_stats = User.select('users.id, users.name, 0 AS message_count')
                                      .where('users.id = ?', Current.user.id)
                                      .first
        end
        
        if @current_user_month_stats
          # Get total number of active users for proper ranking context
          @total_active_users ||= User.where(active: true, suspended_at: nil).count
          
          # Count users with more messages
          users_with_more_messages = User.joins(messages: :room)
                                       .where('rooms.type != ? AND messages.created_at >= ? AND messages.active = true', 
                                             'Rooms::Direct', month_start)
                                       .where('users.active = true AND users.suspended_at IS NULL')
                                       .group('users.id')
                                       .having('COUNT(messages.id) > ?', @current_user_month_stats.message_count.to_i)
                                       .count.size
          
          # Count users with same number of messages but earlier join date
          if @current_user_month_stats.message_count.to_i > 0
            users_with_same_messages_earlier_join = User.joins(messages: :room)
                                                     .where('rooms.type != ? AND messages.created_at >= ? AND messages.active = true', 
                                                           'Rooms::Direct', month_start)
                                                     .where('users.active = true AND users.suspended_at IS NULL')
                                                     .group('users.id')
                                                     .having('COUNT(messages.id) = ?', @current_user_month_stats.message_count.to_i)
                                                     .where('COALESCE(users.membership_started_at, users.created_at) < ?', 
                                                           Current.user.membership_started_at || Current.user.created_at)
                                                     .count.size
          else
            # For users with 0 messages, count users with earlier join date
            users_with_same_messages_earlier_join = User.where('COALESCE(membership_started_at, created_at) < ?', 
                                                             Current.user.membership_started_at || Current.user.created_at)
                                                     .where('active = true AND suspended_at IS NULL')
                                                     .count
          end
          
          @current_user_month_rank = users_with_more_messages + users_with_same_messages_earlier_join + 1
          
          # Sanity check: rank should never exceed total active users
          @current_user_month_rank = [@current_user_month_rank, @total_active_users].min
        end
      end
    end

    # This Year (UTC)
    year_start = Time.now.utc.beginning_of_year
    @top_posters_year = User.select('users.id, users.name, COUNT(messages.id) AS message_count, COALESCE(users.membership_started_at, users.created_at) as joined_at')
                          .joins(messages: :room)
                          .where('rooms.type != ? AND messages.created_at >= ? AND messages.active = true', 
                                'Rooms::Direct', 
                                year_start)
                          .where('users.active = true AND users.suspended_at IS NULL')
                          .group('users.id, users.name, users.membership_started_at, users.created_at')
                          .order('message_count DESC, joined_at ASC')
                          .limit(30)
    
    # Get current user's stats for year if not in top 10
    if Current.user
      current_user_in_top_10_year = @top_posters_year.first(10).any? { |user| user.id == Current.user.id }
      
      if !current_user_in_top_10_year
        year_start_formatted = year_start.strftime('%Y-%m-%d %H:%M:%S')
        @current_user_year_stats = User.select('users.id, users.name, COALESCE(COUNT(messages.id), 0) AS message_count')
                                   .joins("LEFT JOIN messages ON messages.creator_id = users.id AND messages.created_at >= '#{year_start_formatted}' AND messages.active = true
                                          LEFT JOIN rooms ON messages.room_id = rooms.id AND rooms.type != 'Rooms::Direct'")
                                   .where('users.id = ?', Current.user.id)
                                   .group('users.id')
                                   .first
        
        # Always ensure we have stats for the current user
        if @current_user_year_stats.nil?
          @current_user_year_stats = User.select('users.id, users.name, 0 AS message_count')
                                     .where('users.id = ?', Current.user.id)
                                     .first
        end
        
        if @current_user_year_stats
          # Get total number of active users for proper ranking context
          @total_active_users ||= User.where(active: true, suspended_at: nil).count
          
          # Count users with more messages
          users_with_more_messages = User.joins(messages: :room)
                                      .where('rooms.type != ? AND messages.created_at >= ? AND messages.active = true', 
                                            'Rooms::Direct', year_start)
                                      .where('users.active = true AND users.suspended_at IS NULL')
                                      .group('users.id')
                                      .having('COUNT(messages.id) > ?', @current_user_year_stats.message_count.to_i)
                                      .count.size
          
          # Count users with same number of messages but earlier join date
          if @current_user_year_stats.message_count.to_i > 0
            users_with_same_messages_earlier_join = User.joins(messages: :room)
                                                    .where('rooms.type != ? AND messages.created_at >= ? AND messages.active = true', 
                                                          'Rooms::Direct', year_start)
                                                    .where('users.active = true AND users.suspended_at IS NULL')
                                                    .group('users.id')
                                                    .having('COUNT(messages.id) = ?', @current_user_year_stats.message_count.to_i)
                                                    .where('COALESCE(users.membership_started_at, users.created_at) < ?', 
                                                          Current.user.membership_started_at || Current.user.created_at)
                                                    .count.size
          else
            # For users with 0 messages, count users with earlier join date
            users_with_same_messages_earlier_join = User.where('COALESCE(membership_started_at, created_at) < ?', 
                                                            Current.user.membership_started_at || Current.user.created_at)
                                                    .where('active = true AND suspended_at IS NULL')
                                                    .count
          end
          
          @current_user_year_rank = users_with_more_messages + users_with_same_messages_earlier_join + 1
          
          # Sanity check: rank should never exceed total active users
          @current_user_year_rank = [@current_user_year_rank, @total_active_users].min
        end
      end
    end

    # All Time
    @top_posters_all_time = User.select('users.id, users.name, COUNT(messages.id) AS message_count, COALESCE(users.membership_started_at, users.created_at) as joined_at')
                              .joins(messages: :room)
                              .where('rooms.type != ? AND messages.active = true', 'Rooms::Direct')
                              .where('users.active = true AND users.suspended_at IS NULL')
                              .group('users.id, users.name, users.membership_started_at, users.created_at')
                              .order('message_count DESC, joined_at ASC')
                              .limit(30)
    
    # Get current user's stats for all time if not in top 10
    if Current.user
      current_user_in_top_10_all_time = @top_posters_all_time.first(10).any? { |user| user.id == Current.user.id }
      
      if !current_user_in_top_10_all_time
        @current_user_all_time_stats = User.select('users.id, users.name, COALESCE(COUNT(messages.id), 0) AS message_count')
                                       .joins("LEFT JOIN messages ON messages.creator_id = users.id AND messages.active = true
                                              LEFT JOIN rooms ON messages.room_id = rooms.id AND rooms.type != 'Rooms::Direct'")
                                       .where('users.id = ?', Current.user.id)
                                       .group('users.id')
                                       .first
        
        # Always ensure we have stats for the current user
        if @current_user_all_time_stats.nil?
          @current_user_all_time_stats = User.select('users.id, users.name, 0 AS message_count')
                                         .where('users.id = ?', Current.user.id)
                                         .first
        end
        
        if @current_user_all_time_stats
          # Get total number of active users for proper ranking context
          @total_active_users ||= User.where(active: true, suspended_at: nil).count
          
          # Count users with more messages
          users_with_more_messages = User.joins(messages: :room)
                                      .where('rooms.type != ? AND messages.active = true', 'Rooms::Direct')
                                      .where('users.active = true AND users.suspended_at IS NULL')
                                      .group('users.id')
                                      .having('COUNT(messages.id) > ?', @current_user_all_time_stats.message_count.to_i)
                                      .count.size
          
          # Count users with same number of messages but earlier join date
          if @current_user_all_time_stats.message_count.to_i > 0
            users_with_same_messages_earlier_join = User.joins(messages: :room)
                                                    .where('rooms.type != ? AND messages.active = true', 'Rooms::Direct')
                                                    .where('users.active = true AND users.suspended_at IS NULL')
                                                    .group('users.id')
                                                    .having('COUNT(messages.id) = ?', @current_user_all_time_stats.message_count.to_i)
                                                    .where('COALESCE(users.membership_started_at, users.created_at) < ?', 
                                                          Current.user.membership_started_at || Current.user.created_at)
                                                    .count.size
          else
            # For users with 0 messages, count users with earlier join date
            users_with_same_messages_earlier_join = User.where('COALESCE(membership_started_at, created_at) < ?', 
                                                            Current.user.membership_started_at || Current.user.created_at)
                                                    .where('active = true AND suspended_at IS NULL')
                                                    .count
          end
          
          @current_user_all_time_rank = users_with_more_messages + users_with_same_messages_earlier_join + 1
          
          # Sanity check: rank should never exceed total active users
          @current_user_all_time_rank = [@current_user_all_time_rank, @total_active_users].min
        end
      end
    end

    @newest_members = User
      .select("users.*, COALESCE(users.membership_started_at, users.created_at) as joined_at")
      .where(active: true)
      .where(suspended_at: nil)
      .order("joined_at DESC")
      .limit(30)
  end
end 