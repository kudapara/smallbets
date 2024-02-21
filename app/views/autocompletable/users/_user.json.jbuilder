json.name       h(user.name)
json.value      user.id
json.avatar_url user.avatar_url.presence || fresh_user_avatar_url(user)
json.sgid       user.attachable_sgid
