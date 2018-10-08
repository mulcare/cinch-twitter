require 'net/http'
require 'json'
require 'twitter'
require 'date'

class Cinch::TwitterStreamer
  include Cinch::Plugin

  def initialize(bot)
    @bot = bot
  end

  def start

    @streamer = Twitter::Streaming::Client.new do |c|
      c.consumer_key = config[:consumer_key]
      c.consumer_secret = config[:consumer_secret]
      c.access_token = config[:access_token]
      c.access_token_secret = config[:access_token_secret]
    end

    while true
      @streamer.filter(follow: config[:ids_to_follow]) do |tweet|
        # Twitter's Streaming API works differently than its REST API, so we
        # can't simply use "tweet_mode: 'extended'" and its ":full_text" attr
        # to get the full text of tweets with more than 140 characters. We must
        # instead test for the ":extended_tweet" attr, which is only present
        # in 140+ char tweets.
        if tweet.attrs[:extended_tweet]
          text = tweet.attrs[:extended_tweet][:full_text]
        else
          text = tweet.attrs[:text]
        end

        date = DateTime.strptime(tweet.attrs[:created_at], "%a %b %d %H:%M:%S %z %Y").new_offset("-04:00").strftime("%a %b %d %Y %I:%M%P")
        payload = [config[:channel], date, tweet.user.screen_name, text]

        # Fire off a :tweetstream event with the array containing the payload.
        # Using Cinch's listen_to method, we can handle these events elsewhere,
        # including across plugins.
        # 
        # Ex:
        #     listen_to :tweetstream, :method => :do_something_with_payload
        #     def do_something_with_payload(m, payload)
        #       payload #=> ["#channel", "ex. date", "ex. user", "ex. text"]
        #     end 
        @bot.handlers.dispatch(:tweetstream, nil, payload)
      end
    end
  end
end

class Cinch::Twitter
  include Cinch::Plugin
 
  listen_to :connect, :method => :setup
  listen_to :tweetstream, :method => :stream

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

  def stream(m, tweet)
    channel = tweet[0]
    tweet = {
      date: tweet[1],
      name: tweet[2],
      text: tweet[3]
    }
    Channel(channel).send("🐦 #{tweet[:date]} #{Format(:bold, tweet[:name])}: #{tweet[:text]}")
  end

  match /tw (.+)/
  def execute(m, query)
    grab_tweet_by_tweetid(query)
    m.reply "🐦 #{@tweet[:date]} #{Format(:bold, @tweet[:name])}: #{@tweet[:text]}"
  end

end