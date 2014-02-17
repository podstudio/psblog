module ArticleHelpers
  def previous_article_in_category
    return if current_article.nil?
    @previous_article ||= blog.articles.select {|a| (a.data.category == current_article.data.category) && a.date < current_article.date}.first
  end

  def next_article_in_category
    return if current_article.nil?
    @next_article ||= blog.articles.reverse.select {|a| (a.data.category == current_article.data.category) && a.date > current_article.date}.first
  end
end
