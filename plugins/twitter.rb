require 'net/http'
require 'json'
require 'twitter'
require 'date'

class Cinch::Twitter
  include Cinch::Plugin
 
  listen_to :connect, :method => :setup

  def setup(*)
    @client = Twitter::REST::Client.new do |c|
      c.consumer_key = config[:consumer_key]
      c.consumer_secret = config[:consumer_secret]
      c.access_token = config[:access_token]
      c.access_token_secret = config[:access_token_secret]
    end
  end

  def grab_tweet_by_tweetid(tweetid)
    tweet = @client.status(tweetid, tweet_mode: 'extended')
    tweet = tweet.to_hash.slice(:full_text, :user, :created_at)
    @tweet = {
      name: tweet[:user][:screen_name],
      date: DateTime.strptime(tweet[:created_at], "%a %b %d %H:%M:%S %z %Y").new_offset("-04:00").strftime("%a %b %d %Y %I:%M%P"),
      text: tweet[:full_text]
    }
  end

  match /tw (.+)/
  def execute(m, query)
    grab_tweet_by_tweetid(query)
    m.reply "🐦 #{@tweet[:date]} #{Format(:bold, @tweet[:name])}: #{@tweet[:text]}"
  end

end