module InboxHelper
  def inbox_messages_tag(paginator_url, highlight_mentions: true, date_separator: true, &)
    tag.div id: "inbox", class: "messages searches__results", data: {
      controller: "inbox",
      inbox_target: "messages",
      inbox_first_of_day_class: date_separator ? "message--first-of-day" : "",
      inbox_me_class: "message--me",
      inbox_threaded_class: "message--threaded",
      inbox_mentioned_class: highlight_mentions ? "message--mentioned" : "",
      inbox_formatted_class: "message--formatted",
      inbox_page_url_value: paginator_url
    }, &
  end
end
