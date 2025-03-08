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
      # CPU metrics
      os = RbConfig::CONFIG['host_os']
      
      if os =~ /darwin/i
        # macOS
        @cpu_util = `top -l 1 | grep "CPU usage" | awk '{print $3}' | tr -d '%'`.to_f
        @cpu_cores = `sysctl -n hw.ncpu`.to_i
      elsif os =~ /linux/i
        # Linux (Ubuntu, etc.)
        cpu_info = `cat /proc/stat | grep '^cpu '`.split
        user = cpu_info[1].to_i
        nice = cpu_info[2].to_i
        system = cpu_info[3].to_i
        idle = cpu_info[4].to_i
        iowait = cpu_info[5].to_i
        irq = cpu_info[6].to_i
        softirq = cpu_info[7].to_i
        steal = cpu_info[8].to_i if cpu_info.size > 8
        steal ||= 0
        
        total = user + nice + system + idle + iowait + irq + softirq + steal
        used = total - idle - iowait
        @cpu_util = (used.to_f / total * 100).round(1)
        @cpu_cores = `nproc`.to_i
      end
      
      # Memory metrics
      if os =~ /darwin/i
        # macOS
        vm_stat = `vm_stat`
        matches = vm_stat.match(/Pages free:\s+(\d+)/)
        free_pages = matches ? matches[1].to_i : 0
        
        matches = vm_stat.match(/Pages inactive:\s+(\d+)/)
        inactive_pages = matches ? matches[1].to_i : 0
        
        matches = vm_stat.match(/Pages speculative:\s+(\d+)/)
        speculative_pages = matches ? matches[1].to_i : 0
        
        matches = vm_stat.match(/Pages wired down:\s+(\d+)/)
        wired_pages = matches ? matches[1].to_i : 0
        
        matches = vm_stat.match(/Pages active:\s+(\d+)/)
        active_pages = matches ? matches[1].to_i : 0
        
        # Calculate total memory
        total_memory = `sysctl -n hw.memsize`.to_i
        @total_memory_gb = (total_memory / 1024.0 / 1024.0 / 1024.0).round(1)
        
        # Calculate available memory (free + inactive + speculative)
        page_size = 4096 # Default page size on macOS
        available_memory = (free_pages + inactive_pages + speculative_pages) * page_size
        @free_memory_percent = (available_memory.to_f / total_memory * 100).round(1)
        @memory_util_percent = 100 - @free_memory_percent
      elsif os =~ /linux/i
        # Linux (Ubuntu, etc.)
        mem_info = `cat /proc/meminfo`
        
        # Extract memory information
        total_kb = mem_info.match(/MemTotal:\s+(\d+)/)[1].to_i
        free_kb = mem_info.match(/MemFree:\s+(\d+)/)[1].to_i
        buffers_kb = mem_info.match(/Buffers:\s+(\d+)/)[1].to_i
        cached_kb = mem_info.match(/Cached:\s+(\d+)/)[1].to_i
        
        # Calculate total memory in GB
        # Note: We use the configured value if available to match what users expect
        # Otherwise, we convert from KB to GB with proper rounding
        # The discrepancy between configured and reported memory is due to:
        # 1. Binary vs decimal units (1 GiB = 1.074 GB)
        # 2. Memory reserved by BIOS and hardware
        @total_memory_gb = if total_kb > 60_000_000 && total_kb < 63_000_000
                            64 # Use the configured value for 64GB systems
                          elsif total_kb > 30_000_000 && total_kb < 33_000_000
                            32 # Use the configured value for 32GB systems
                          elsif total_kb > 15_000_000 && total_kb < 17_000_000
                            16 # Use the configured value for 16GB systems
                          elsif total_kb > 7_000_000 && total_kb < 9_000_000
                            8  # Use the configured value for 8GB systems
                          else
                            (total_kb / 1024.0 / 1024.0).round(1)
                          end
        
        # Calculate available memory (free + buffers + cached)
        available_kb = free_kb + buffers_kb + cached_kb
        @free_memory_percent = (available_kb.to_f / total_kb * 100).round(1)
        @memory_util_percent = 100 - @free_memory_percent
      end
      
      # Disk metrics
      if os =~ /darwin/i
        # macOS
        df_output = `df -h /`
        df_lines = df_output.split("\n")
        if df_lines.length > 1
          disk_info = df_lines[1].split
          @free_disk_percent = 100 - disk_info[4].to_i
          @disk_util_percent = disk_info[4].to_i
          @total_disk_gb = disk_info[1].gsub(/[^\d.]/, '').to_f
        end
      elsif os =~ /linux/i
        # Linux (Ubuntu, etc.)
        df_output = `df -h /`
        df_lines = df_output.split("\n")
        if df_lines.length > 1
          disk_info = df_lines[1].split
          # Format can be different on various Linux distributions
          # Typically: Filesystem Size Used Avail Use% Mounted on
          @total_disk_gb = disk_info[1].gsub(/[^\d.]/, '').to_f
          @disk_util_percent = disk_info[4].gsub('%', '').to_i
          @free_disk_percent = 100 - @disk_util_percent # Keep this for backward compatibility
        end
      end
    rescue => e
      # Log error but don't crash
      Rails.logger.error "Error getting system metrics: #{e.message}"
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