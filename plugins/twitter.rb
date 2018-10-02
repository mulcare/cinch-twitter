require 'net/http'
require 'json'
require 'twitter'

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

  def grab_tweet(tweetid)
    long_tweet = @client.status(tweetid, tweet_mode: 'extended')
    @tweet = long_tweet.attrs[:full_text]
    @user = long_tweet.attrs[:user][:screen_name]
  end

  match /tw (.+)/
  def execute(m, query)
    grab_tweet(query)
    m.reply "#{@user}: #{@tweet}"
  end

end