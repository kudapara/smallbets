module DomHelper
  def dom_prefix(*parts)
    parts.join("_")
  end
end