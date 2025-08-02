class ApplicationController < ActionController::Base
  include AllowBrowser, Authentication, Authorization, RackMiniProfilerAuthorization, SetCurrentRequest, SetPlatform, TrackedRoomVisit, VersionHeaders, FragmentCache, Sidebar
  include Turbo::Streams::Broadcasts, Turbo::Streams::StreamName
end
