class Gumroad::ImportUserJob < ApplicationJob
  def perform(event)
    payload = event.payload || {}

    puts "IMPORT_USER_JOB #{payload.inspect}"

    # This will be either:
    # - the buyer's email in case of a normal purchase
    # - the gift receiver email in case of a gift purchase
    # Either way, that's the email we should create the user with
    email = payload["email"]
    order_id = payload["order_number"]
    membership_started_at = payload["sale_timestamp"]
    name = payload["full_name"]

    raise "Expected email to be present. Event ID #{event.id}" unless email.present?
    raise "Expected order ID to be present. Event ID #{event.id}" unless order_id.present?

    ActiveRecord::Base.transaction do
      User.create!(email_address: email, name:, order_id:, membership_started_at:)
      event.update!(processed_at: Time.current)
    end
  end
end
