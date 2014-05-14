class Wordpress 
  def initialize blog, category=nil
    @blog = blog
    @url = "https://public-api.wordpress.com/rest/v1/sites/#{blog.name}/posts#{(category ? '?category='+category : '')}"
    @category = category
  end

  def posts
    json_page = blog_request(@url)
    found_count = JSON.parse(json_page.body)["found"]
    @blog.posts_count = found_count
    @blog.category = @category if @category
    @blog.save
    if(found_count)
      (1..(found_count/20+1)).each do |page|
        posts = blog_request @url+"#{(@category ? '&' : '?')}page="+page.to_s
        posts = JSON.parse(posts.body)
        posts["posts"].each do |post|
          blog = BlogPost.find_or_create_by(blog_url: post["URL"])
          categories = post["categories"].keys
          blog.update_attributes({ title: post["title"], content: post["content"], categories: categories, blog_id: @blog.id.to_s, author: post["author"]["name"]  })
        end
      end
      @blog.posts_count = found_count
      @blog.downloaded = true
      @blog.save
    else
      @blog.error_found = true
      @blog.save
    end
    @blog.reload
    @blog.blog_posts
  end

  def blog_request url
    Net::HTTP.get_response(URI.parse(URI.encode(url)))
  end
end
