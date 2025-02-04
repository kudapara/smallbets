module Sidebar
  extend ActiveSupport::Concern

  included do
    helper_method :for_each_sidebar_section
  end

  def for_each_sidebar_section
    [ :inbox, :starred_rooms, :shared_rooms ].each do |name|
      yield name
    end
  end
end