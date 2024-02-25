json.name       h(user.name)
json.value      user.id
json.avatar_url user.avatar_url.presence || user_image_url(user)
json.sgid       user.attachable_sgid
