class ExpertsController < ApplicationController
  before_action :ensure_administrator!

  def show
    @expert_users = User.where(id: Expert.user_ids).index_by(&:id)
    render layout: "application"
  end

  private

  def ensure_administrator!
    redirect_to root_path unless Current.user&.administrator?
  end
end 