class FalseClass
  def to_i
    0
  end
end

class TrueClass
  def to_i
    1
  end
end

module ApplicationHelper

  # Returns the full title on a per-page basis.
  def full_title(page_title = '')
    base_title = "Cantilever Beam Sim App"
    page_title.empty? ? base_title : page_title + " | " + base_title
  end

  def pluralize_without_count(count, noun, text = nil)
    count == 1 ? "#{noun}#{text}" : "#{noun.pluralize}#{text}"
  end

  def unpluralize_without_count(count, noun, text = nil)
    count == 1 ? "#{noun.pluralize}#{text}" : "#{noun}#{text}"
  end
end
