module Pagination
  extend ActiveSupport::Concern

  PAGE_SIZE = 40

  included do
    scope :last_page, -> { ordered.last(PAGE_SIZE) }
    scope :first_page, -> { ordered.first(PAGE_SIZE) }

    scope :before, ->(record) { where("#{arel_table.name}.created_at < ?", record.created_at) }
    scope :after, ->(record) { where("#{arel_table.name}.created_at > ?", record.created_at) }

    scope :page_before, ->(record) { before(record).last_page }
    scope :page_after, ->(record) { after(record).first_page }

    scope :page_created_since, ->(time) { where("#{arel_table.name}.created_at > ?", time).first_page }
    scope :page_updated_since, ->(time) { where("#{arel_table.name}.updated_at > ?", time).last_page }
  end

  class_methods do
    def page_around(record)
      page_before(record) + [ record ] + page_after(record)
    end

    def paged?
      count > PAGE_SIZE
    end
  end
end
