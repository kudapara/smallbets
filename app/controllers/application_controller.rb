class ApplicationController < ActionController::Base
  include AllowBrowser, Authentication, Authorization, SetCurrentRequest, SetPlatform, TrackedRoomVisit, VersionHeaders
  include Turbo::Streams::Broadcasts, Turbo::Streams::StreamName
end
