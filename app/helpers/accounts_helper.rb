module AccountsHelper
  def account_logo_tag(style: nil)
    tag.figure image_tag(fresh_account_logo_path, role: "presentation", size: 300), class: "account-logo avatar #{style}"
  end
end
