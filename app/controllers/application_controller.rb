class ApplicationController < ActionController::Base
  include AllowBrowser, Authentication, Authorization, SetPlatform, TrackedRoomVisit, VersionHeaders
  include Turbo::Streams::Broadcasts, Turbo::Streams::StreamName
end
