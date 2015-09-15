require "open-uri"
require "json"
require "pp"

puts("Welcome to Foodie Stalk!!!")

$access_token = ENV["INSTAGRAM_ACCESS_TOKEN"]

def instagram_user_id(instagram_username)
	search_text = open("https://api.instagram.com/v1/users/search?q=#{instagram_username}&access_token=#{$access_token}").read
	search = JSON.parse(search_text)
	users = search["data"]
	matched_user = users.find {|x| x["username"] == instagram_username}
	user_id = matched_user["id"]
	return user_id
end

def instagram_posts_batch(instagram_url)
	response_text = open(instagram_url).read
	response = JSON.parse(response_text)
	batch = response["data"]
	next_url = response["pagination"]["next_url"]
	return batch, next_url
end

def instagram_posts(instagram_username)
	user_id = instagram_user_id(instagram_username)
	posts = []
	batch_number = 0
	#Instagram will return at most, 33 post per page. WTF
	instagram_url = "https://api.instagram.com/v1/users/#{user_id}/media/recent/?access_token=#{$access_token}&count=33"
	batch, next_url = instagram_posts_batch(instagram_url)
	posts = posts + batch
	batch_number = batch_number + 1
	p "I loaded batch #{batch_number}!"

	while next_url != nil
		batch, next_url = instagram_posts_batch(next_url)
		posts = posts + batch
		batch_number += 1
		p "I loaded batch #{batch_number}!"
	end

	p "I made #{batch_number} batches"
	p "I loaded #{posts.length} posts."
	return posts
end

def instagram_posts_with_location(posts)
	posts_with_location = posts.reject {|x| x["location"] == nil}
	p "I loaded #{posts_with_location.length} posts with locations."
	return posts_with_location
end

def instagram_location_names(posts)
	posts_with_location = instagram_posts_with_location(posts)
	posts_with_location.each {|x| puts x["location"]}

end


instagram_username = "mylifeisshan"
posts = instagram_posts(instagram_username)
instagram_location_names(posts)
