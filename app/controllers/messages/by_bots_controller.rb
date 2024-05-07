class Messages::ByBotsController < MessagesController
  allow_bot_access only: :create

  def create
    super
    head :created, location: message_url(@message)
  end

  private
    def message_params
      if params[:attachment]
        params.permit(:attachment)
      else
        reading(request.body) { |body| { body: format_mentions(body) } }
      end
    end
  
    def format_mentions(body)
      body.to_s.gsub(/@\{(.+?)\}/) do |mention_sig|
        sso_user_id = $1
        user = User.find_by(sso_user_id: sso_user_id)
        if user
          mention_user(user)
        else
          mention_sig
        end
      end
    end

    def mention_user(user)
      attachment_body = render partial: "users/mention", locals: { user: user }
      "<action-text-attachment sgid=\"#{user.attachable_sgid}\" content-type=\"application/vnd.campfire.mention\" content=\"#{attachment_body.gsub('"', '&quot;')}\"></action-text-attachment>"
    end
  
    def reading(io)
      io.rewind
      yield io.read.force_encoding("UTF-8")
    ensure
      io.rewind
    end
end
