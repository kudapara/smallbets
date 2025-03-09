class StatsController < ApplicationController
  layout "application"
  include AccountsHelper

  def index
    # Get total counts
    counts = StatsService.total_counts
    @total_users = counts[:total_users]
    @total_messages = counts[:total_messages]
    @total_boosts = counts[:total_boosts]
    @total_posters = counts[:total_posters]
    @online_users = online_users_count
    
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

    # Get daily and all-time stats
    @daily_stats = StatsService.daily_stats(30)
    @all_time_stats = StatsService.all_time_daily_stats

    # Get top posters for different time periods
    @top_posters_today = StatsService.top_posters_today(30)
    @top_posters_month = StatsService.top_posters_month(30)
    @top_posters_year = StatsService.top_posters_year(30)
    @top_posters_all_time = StatsService.top_posters_all_time(30)
    
    # Get current user's stats for today if not in top 10
    if Current.user
      current_user_in_top_10_today = @top_posters_today.first(10).any? { |user| user.id == Current.user.id }
      
      if !current_user_in_top_10_today
        @current_user_today_stats = StatsService.user_stats_for_period(Current.user.id, :today)
        
        if @current_user_today_stats
          @current_user_today_rank = StatsService.calculate_user_rank(Current.user.id, :today)
          @total_active_users = @total_users # Already calculated above
        end
      end
    end

    # Get current user's stats for month if not in top 10
    if Current.user
      current_user_in_top_10_month = @top_posters_month.first(10).any? { |user| user.id == Current.user.id }
      
      if !current_user_in_top_10_month
        @current_user_month_stats = StatsService.user_stats_for_period(Current.user.id, :month)
        
        if @current_user_month_stats
          @current_user_month_rank = StatsService.calculate_user_rank(Current.user.id, :month)
          @total_active_users ||= @total_users # Already calculated above
        end
      end
    end

    # Get current user's stats for year if not in top 10
    if Current.user
      current_user_in_top_10_year = @top_posters_year.first(10).any? { |user| user.id == Current.user.id }
      
      if !current_user_in_top_10_year
        @current_user_year_stats = StatsService.user_stats_for_period(Current.user.id, :year)
        
        if @current_user_year_stats
          @current_user_year_rank = StatsService.calculate_user_rank(Current.user.id, :year)
          @total_active_users ||= @total_users # Already calculated above
        end
      end
    end

    # Get current user's stats for all time if not in top 10
    if Current.user
      current_user_in_top_10_all_time = @top_posters_all_time.first(10).any? { |user| user.id == Current.user.id }
      
      if !current_user_in_top_10_all_time
        @current_user_all_time_stats = StatsService.user_stats_for_period(Current.user.id, :all_time)
        
        if @current_user_all_time_stats
          @current_user_all_time_rank = StatsService.calculate_all_time_rank(Current.user.id)
          @total_active_users ||= @total_users # Already calculated above
        end
      end
    end

    @newest_members = StatsService.newest_members(30)
  end

  def today
    @page_title = "Daily Stats"
    
    # Get all days with messages (no time limit)
    @days = Message.select("strftime('%Y-%m-%d', created_at) as date")
                  .group("date")
                  .order("date DESC")
                  .map(&:date)
    
    # For each day, get the top 10 posters
    @daily_stats = {}
    @days.each do |day|
      @daily_stats[day] = StatsService.top_posters_for_day(day, 10)
    end
    
    render 'stats/today'
  end
  
  def month
    @page_title = "Monthly Stats"
    
    # Get all months with messages
    @months = Message.select("strftime('%Y-%m', created_at) as month")
                    .group("month")
                    .order("month DESC")
                    .map(&:month)
    
    # For each month, get the top 10 posters
    @monthly_stats = {}
    @months.each do |month|
      @monthly_stats[month] = StatsService.top_posters_for_month(month, 10)
    end
    
    render 'stats/month'
  end
  
  def year
    @page_title = "Yearly Stats"
    
    # Get all years with messages
    @years = Message.select("strftime('%Y', created_at) as year")
                   .group("year")
                   .order("year DESC")
                   .map(&:year)
    
    # For each year, get the top 10 posters
    @yearly_stats = {}
    @years.each do |year|
      @yearly_stats[year] = StatsService.top_posters_for_year(year, 10)
    end
    
    render 'stats/year'
  end
  
  def all
    @page_title = "All-Time Stats"
    
    # Get all active users with their message counts (at least 1 message)
    @all_time_stats = StatsService.all_users_with_messages
    
    # Precompute all user ranks to avoid N+1 queries
    @precomputed_ranks = StatsService.precompute_all_time_ranks
    
    # No need to sort here - the database query already returns data in the correct order
    # @all_time_stats is already ordered by message_count DESC, joined_at ASC
    
    # Get total count for context
    @total_users_with_messages = @all_time_stats.length
    @total_active_users = User.where(active: true, suspended_at: nil).count
    
    render 'stats/all'
  end
end 