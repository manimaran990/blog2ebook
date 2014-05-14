require 'open-uri'
class Blogger
  def initialize blog, category=nil
    @blog = blog
    @category = category
  end
  
  def post link
    visit link
    all(:css, ".post-content").to_a
  end

  def posts
    #items(author/displayName,blog,content,customMetaData,id,images,kind,labels,selfLink,title,titleLink,url)
    res = Net::HTTP.get_response(URI("http://#{@blog.name}/feeds/posts/default?alt=json&start-index=1&max-results=500#{(@category ? '&category='+@category : '')}"))
    res_body = JSON.parse(res.body)
    total_post = res_body["feed"]["openSearch$totalResults"]["$t"]
    pages = (1..total_post.to_i).step(500).to_a
    pages.each do |page|
      res = Net::HTTP.get_response(URI("http://#{@blog.name}/feeds/posts/default?alt=json&start-index=#{page}&max-results=500#{(@category ? '&category='+@category : '')}"))
      res_body = JSON.parse(res.body)
      entries = res_body["feed"]["entry"].collect { |entry| [entry["link"].last["href"], entry["author"][0]["name"]["$t"], entry["title"]["$t"]]}
      entries.each do |entry|
        link = entry[0]
        author = entry[1]
        title = entry[2]
        begin
          uri = URI(link)
          page_res = Net::HTTP.get_response(URI("http://#{@blog.name}/feeds/posts/default?alt=json&v=2&dynamicviews=1&path=#{uri.path}"))
          entry = JSON.parse(page_res.body)["feed"]["entry"][0]["content"]
          if(entry)
            description = entry["$t"]
            blog_post = BlogPost.find_or_create_by(blog_id: @blog.id)
            blog_post.update_attributes({ title: title, content: description, author: author, blog_url: link })
          end
        rescue => e
          puts e.inspect
        end
      end
    end
    @blog.posts_count = total_post
    @blog.category = @category if @category
    @blog.downloaded = true
    @blog.save
    @blog.reload
    @blog.blog_posts
  end

  def posts_api
    #via api
    api_key = "AIzaSyDKoS6fA-WtesuAA9wu3tVqMm5TWqDU8fg"
    blog_stat_url = "https://www.googleapis.com/blogger/v3/blogs/byurl?url=#{CGI.escape("http://"+@blog.name)}&key=#{api_key}"
    puts blog_stat_url
    blog_stat_json_response = Net::HTTP.get_response(URI(blog_stat_url))
    blog_stat_response = JSON.parse(blog_stat_json_response.body)
    blog_id = blog_stat_response["id"]
    puts blog_id
    if(blog_id)
      total_items = blog_stat_response["posts"]["totalItems"]
      @blog.posts_count = total_items
      @blog.save
      page_token=nil
      first_page=true
      loop do
        blog_url = "https://www.googleapis.com/blogger/v3/blogs/6704233987564306738/posts?key=#{api_key}&maxResults=100&fields=items(author/displayName,blog,content,customMetaData,id,images,kind,labels,selfLink,title,titleLink,url)"
        if(page_token.present? || first_page)
          blog_url = blog_url+="&pageToken=#{page_token}"
          puts blog_url
          blog_posts_response = Net::HTTP.get_response(URI(blog_url))
          blog_posts = JSON.parse(blog_posts_response.body)["items"]
          blog_posts.each do |post|
            description = post["content"]
            link = post["url"]
            title = post["title"]
            blog_post = BlogPost.find_or_create_by(blog_id: @blog.id)
            blog_post.update_attributes({title: title, content: description, author: author, blog_url: link})
          end
        end
        first_page = false
      end
    end
    @blog.downloaded = true
    @blog.save
    @blog.reload
    @blog.blog_posts
  end
end
