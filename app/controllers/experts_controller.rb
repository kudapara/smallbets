class ExpertsController < ApplicationController
  before_action :ensure_administrator!

  def show
    expert_ids = [228, 1, 2844, 211, 70, 187, 1196, 333, 391, 39, 343, 697]
    @expert_users = User.where(id: expert_ids).index_by(&:id)
    render layout: "application"
  end

  private

  def ensure_administrator!
    redirect_to root_path unless Current.user&.administrator?
  end
end 