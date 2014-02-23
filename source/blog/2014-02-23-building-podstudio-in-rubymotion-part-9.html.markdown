---
title: Building podstud.io in RubyMotion - Part 9
date: 2014-02-23 20:45 UTC
tags: Rubymotion
category: RubyMotion
---

Up until now, we've been managine the Audio Session for our app within the Player Controller itself. This is all well and good, but its not necessarily helpful when we want to affect playback from a different view or if we'd like to see some information about what's currently playing without being in the Player Controller. In this article, we are going to create a new class to manage the state of our audio session. When this is in place, we are going to communicate with it from our Player Controller rather than instantiating and updating playback from within the controller itself.

### NowPlaying Model / Singleton

To do this, we are going to create a model which will instantiate our audio player and manage its playback state. Now, we don't want to create a new instance of this class everytime we want to communicate with it, so we need to follow the [singleton pattern](http://en.wikipedia.org/wiki/Singleton_pattern) to return a single instance of our NowPlaying object.

We've actually already dealt with singletons in our app thus far. Everytime we call `UIApplication.sharedApplication` we are talking to the `sharedApplication` singleton object within the UIApplication class. Similarly, the `defaultCenter` in `MPNowPlayingInfoCenter.defaultCenter` is only instantiated once and manages the state of the device's Now Playing Info Center.

First, let's create our Now Playing model.

~~~~ ruby
  rmq create model now_playing
~~~~

which will create two files for us:

~~~~ ruby
  Creating model: now_playing

     Using existing directory: app/models
  Δ  Creating file: /Users/nader/Dev/podstudio/podstudio-rm/app/models/now_playing.rb
     Using existing directory: spec/models
  Δ  Creating file: /Users/nader/Dev/podstudio/podstudio-rm/spec/models/now_playing.rb

     Done
~~~~

In our new `now_playing.rb` file, we can see some boilerplate code already in place for us. We don't really need all of this just yet, so let's trim it down to the following:

~~~~ ruby
  class NowPlaying
    def initialize(params = {})
    end
  end
~~~~

If we run a `rake` now we can see that we can easily create a new instance of our model and assert that it is of the correct class:

~~~~ ruby
  now_playing = NowPlaying.new
    => #<NowPlaying:0xc45bf00>

  now_playing.class
    => NowPlaying
~~~~

Nice and easy! Now, we want to implement our singleton pattern. We want to be able to call something like `NowPlaying.sharedInstance` and be confident that it will only be dispatched once. Luckily, RubyMotion has put some thought into this and goes into detail about it [here](http://blog.rubymotion.com/post/31917526853/rubymotion-gets-ios-6-iphone-5-debugger).

So, we simply need to add a new class method to the NowPlaying model that will only be dispatched once and return the singleton object.

~~~~ ruby
  class NowPlaying
    def initialize(params = {})
    end

    def self.sharedInstance
      Dispatch.once { @sharedInstance ||= new }
      @sharedInstance
    end
  end
~~~~

### Using NowPlaying.sharedInstance

The first bit of code we want to remove from our PlayerController is the creation and delegation of the `@player` attribute. Currently, it looks like this:

~~~~ ruby
  @player = BW::Media.play(url) do |player|
    @play_stop.setTitle("STOP", forState: UIControlStateNormal)
    startTimer
  end
~~~~

But we want to move the `BW::Media.play` bit into our NowPlaying model. We'll add a `player` method on our sharedInstance:

~~~~ ruby
  def player(url = nil, &block)
    @player ||= BW::Media.play(url) do |player|
      block.call(player)
    end
  end
~~~~

We want the `player` method on our NowPlaying model to have a very similar API to what we currently expect in our PlayerController. So, we simply pass it a URL and a block to call after the `BW::Media.play` method finishes. We return the `@player` object we have either created or retrieved via the `||=` operator, and call the block that is passed in as a parameter. To use this in our controller, we simply update the PlayerController to:

~~~~ ruby
  url = "http://feeds.soundcloud.com/stream/133946490-hdtgm-82-double-team-w-owen-burke.mp3"
  @player = NowPlaying.sharedInstance.player(url) do |player|
    @play_stop.setTitle("STOP", forState: UIControlStateNormal)
    startTimer
  end
~~~~

If we run a `rake` now, we should see that the audio still plays just as we expected. And, since the `@player` object in our controller is of the same class that it was previously, the rest of our references to it in PlayerController still work correctly!

Now, this might not seem like a huge step towards abstracting our player out of the controller, but lets try something in the console.

~~~~ ruby
  NowPlaying.sharedInstance.player
    => #<MPMoviePlayerController:0xd98c840>
~~~~

**Important Note:** For this to work, we need an interface to retrieve the `player` attribute on the NowPlaying model. We can do this by simply adding `attr_accessor :player` to our NowPlaying class.

That's pretty cool...we don't even need to be in our PlayerController to get access to our Audio Player. What if we want to get the current playback time?

~~~~ ruby
  NowPlaying.sharedInstance.player.currentPlaybackTime
    => 66.136439296
~~~~

You can see how easy it will be to include information about the currently playing audio in views other than our PlayerController now!

Eventually, we are going to want to beef up this NowPlaying Model to include more information about our currently playing track such as its Title, Podcast name and thumbnail image. We would like to move all of the logic involving updating the MPNowPlayingInfoCenter into the model and out of our PlayerController.

### Updating the NowPlayingInfo

Currently, our `updateNowPlayingInfo` method directly updates the `MPNowPlayingInfoCenter. Instead, we want to send this information to our NowPlayingInfoCenter and have it update the device itself. So, in PlayerController:

~~~~ ruby
  def updateNowPlayingInfo(player)
    nowPlayingInfo = {
      MPMediaItemPropertyTitle => "Wicker Man",
      MPMediaItemPropertyArtist => "How Did This Get Made",
      MPMediaItemPropertyPlaybackDuration => player.duration,
      MPNowPlayingInfoPropertyElapsedPlaybackTime => player.currentPlaybackTime,
      MPNowPlayingInfoPropertyPlaybackRate => player.currentPlaybackRate
    }

    if !@thumbnail.image.nil?
      nowPlayingInfo[MPMediaItemPropertyArtwork] = MPMediaItemArtwork.alloc.initWithImage(@thumbnail.image)
    end

    NowPlaying.sharedInstance.updateNowPlayingInfo(nowPlayingInfo)
  end
~~~~

and in our NowPlaying model:

~~~~ ruby
  def updateNowPlayingInfo(nowPlayingInfo = {})
    @now_playing_info = nowPlayingInfo
    MPNowPlayingInfoCenter.defaultCenter.nowPlayingInfo = @now_playing_info
  end
~~~~

being sure to add `:now_playing_info` to our attr_accessor line. This sets the now_playing_info on our model so we can view it from outside the model itself, and updates the MPNowPlayingInfoCenter accordingly.

~~~~ ruby
  NowPlaying.sharedInstance.now_playing_info
    => {"title"=>"Wicker Man", "artist"=>"How Did This Get Made", "playbackDuration"=>4097.17551020408, "MPNowPlayingInfoPropertyElapsedPlaybackTime"=>0.0, "MPNowPlayingInfoPropertyPlaybackRate"=>1.0, "artwork"=>#<MPMediaItemArtwork:0xe06adf0>}
~~~~

Now *that's* pretty awesome.

### Moving Forward

We've got our NowPlaying class working as we expect it, so the next stage in the series is going to involve updating and retrieving info from this model from outside out Player Controller. We are going to build a new view that will be displayed in our UI whenever audio is playing, similar to the one used in Spotify:

![](/blog/2014-02-23-building-podstudio-in-rubymotion-part-9/1.png)
