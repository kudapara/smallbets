class ApplicationController < ActionController::Base
  include AllowBrowser, Authentication, Authorization, SetCurrentRequest, SetPlatform, TrackedRoomVisit, VersionHeaders, FragmentCache
  include Turbo::Streams::Broadcasts, Turbo::Streams::StreamName
end
