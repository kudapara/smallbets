class Opengraph::Metadata
  include ActiveModel::Model, Fetching

  ATTRIBUTES = %i[ title url image description ]
  attr_accessor *ATTRIBUTES

  validates_presence_of :title, :url, :description
  validate :ensure_valid_image_url

  private
    def ensure_valid_image_url
      if image.present?
        errors.add :image, "url is invalid" unless Opengraph::Location.new(image).valid?
      end
    end
end
