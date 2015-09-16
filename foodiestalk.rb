require "open-uri"
require "json"
require "pp"
require "yelp"
require "similar_text"

require "./yelp_categories.rb"

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

def print_instagram_locations(posts)
	posts_with_location = instagram_posts_with_location(posts)
	posts_with_location.each {|x| puts x["location"]}
end



def yelp_business(instagram_location)
	client = Yelp::Client.new({
		consumer_key: ENV["YELP_CONSUMER_KEY"],
  		consumer_secret: ENV["YELP_CONSUMER_SECRET"],
        token: ENV["YELP_TOKEN"],
        token_secret: ENV["YELP_TOKEN_SECRET"]
    })

	coordinates = { latitude: instagram_location["latitude"], longitude: instagram_location["longitude"] }

	params = {
		term: instagram_location["name"],
        limit: 1,
        #category_filter: "restaurants,coffee,bars",
        radius_filter: 100,
    }
    begin
		yelp_results = client.search_by_coordinates(coordinates, params)
		yelp_business = yelp_results.businesses[0]

	rescue Yelp::Error::UnavailableForLocation
		p "YELP FAILED US"
		return nil
	end


	if yelp_business == nil
		p "CAN'T FIND IT ON YELP"
		return nil
	end

	if is_this_business_actually_a_city?(yelp_business, instagram_location)
		p "ITS A CITY!"
		return nil
	end
	if is_this_business_ridiculously_far_away?(yelp_business)
		p "TOO FAR!"
		return nil
	end
	if not is_this_business_for_eating?(yelp_business)
		p "NOT FOOD!"
		return nil
	end

	if not are_these_the_same_place?(yelp_business, instagram_location)
		p "NOT THE SAME"
		return nil
	end

	return yelp_business

end

def print_yelp_businesses(posts)
	posts_with_location = instagram_posts_with_location(posts)
	food_business = 0

	posts_with_location.each do |post|
		instagram_location = post["location"]
		puts "\nInstagram Name: #{instagram_location["name"]}"
		yelp_business = yelp_business(instagram_location)

		if yelp_business != nil
			puts "\nInstagram Name: #{instagram_location["name"]}"
			puts "Yelp Name: #{yelp_business.name}"
			puts "Location: #{yelp_business.location.display_address}"
			puts "Distance Away: #{yelp_business.distance}"
			yelp_vs_instagram_name = instagram_location["name"].similar(yelp_business.name)
			puts "Name similarity: #{yelp_vs_instagram_name}"
			food_business += 1
		else
			puts "No Yelp profile."
		end
	end
	puts "I found #{food_business} food businesses!"
end

def is_this_business_for_eating?(yelp_business)
	yelp_business.categories.each do |category|
		#category = ["Music & DVDs", "musicvideo"]
		category_id = category[1]
		if ALL_EATING_CATEGORIES.include?(category_id)
			return true
		end
	end
	return false
end

def is_this_business_ridiculously_far_away?(yelp_business)
	if yelp_business.distance > 100
		return true
	else
		return false
	end
end

def is_this_business_actually_a_city?(yelp_business, instagram_location)
	possible_city_name = instagram_location["name"].split(",")[0]
	if possible_city_name == yelp_business.location.city
		return true
	else
		return false
	end
end

def are_these_the_same_place?(yelp_business, instagram_location)
	yelp_vs_instagram_name = instagram_location["name"].similar(yelp_business.name)
	if yelp_vs_instagram_name >= 40
		return true
	else
		return false
	end
end


instagram_username = ARGV[0]
if instagram_username == nil
	puts "Who are you stalking?"
	exit
end
posts = instagram_posts(instagram_username)
print_yelp_businesses(posts)


