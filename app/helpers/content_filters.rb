module ContentFilters
  TextMessagePresentationFilters = ActionText::Content::Filters.new(RemoveSoloUnfurledLinkText, StyleUnfurledTwitterAvatars)
end
