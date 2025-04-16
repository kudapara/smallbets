class MarketingController < ApplicationController
  allow_unauthenticated_access
  layout "marketing"

  before_action :restore_authentication, :redirect_signed_in_user_to_chat

  def show
    @user_count = User.active.non_suspended.count

    # Efficient: Only include users who have posted in the last 90 days
    range_start = 90.days.ago.beginning_of_day
    range_end = Time.now.end_of_day

    recent_user_ids = Message
      .joins(:room)
      .where('messages.active = true')
      .where('rooms.type != ?', 'Rooms::Direct')
      .where('messages.created_at >= ? AND messages.created_at <= ?', range_start, range_end)
      .distinct
      .pluck(:creator_id)

    users_with_counts = User
      .select('users.id, users.name, COUNT(messages.id) AS message_count, COALESCE(users.membership_started_at, users.created_at) as joined_at')
      .joins(messages: :room)
      .where('rooms.type != ? AND messages.active = true', 'Rooms::Direct')
      .where('users.active = true AND users.suspended_at IS NULL')
      .where(id: recent_user_ids)
      .group('users.id, users.name, users.membership_started_at, users.created_at')
      .order('message_count DESC, joined_at ASC, users.id ASC')

    user_ids = users_with_counts.map(&:id)
    users_by_id = User.where(id: user_ids).includes(avatar_attachment: :blob).index_by(&:id)

    top_members_with_avatars = []
    users_with_counts.each do |user|
      real_user = users_by_id[user.id]
      if real_user && real_user.avatar.attached?
        top_members_with_avatars << real_user
        break if top_members_with_avatars.size >= 102
      end
    end

    @top_community_members = top_members_with_avatars

    # Build a hash of user_id => { message_count, rank }
    @community_stats_by_user_id = {}
    users_with_counts.each_with_index do |user, idx|
      @community_stats_by_user_id[user.id] = {
        message_count: user.message_count,
        rank: idx + 1
      }
    end
  end
end
