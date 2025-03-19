class NotifierMailer < ApplicationMailer
  include ActionView::Helpers::TextHelper
  include RoomsHelper

  helper_method :room_display_name

  def unread_mentions(user, messages)
    @user = user
    total_message_count = messages.count
    @messages = total_message_count > 10 ? messages.first(8) : messages
    @more_mentions_count = [total_message_count - @messages.count, 0].max

    mail(to: @user.email_address, subject: "You have #{pluralize(messages.size, "unread mention")}")
  end
end
