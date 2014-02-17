---
title: Building podstud.io in RubyMotion - Part 1
date: 2014-02-17 01:14 UTC
tags: Rubymotion
category: RubyMotion
---

In this post, we are going to build upon the app in my previous post. The goal is to be able to simply stream an episode of a particular podcast and start and stop it when we want. Not necessarily groundbreaking stuff, but it will help me introduce some basic concepts that we will be using from here on out.

### BubbleWrap & Media Player

In order to get some audio playing, we are going to use the amazing [BubbleWrap](https://github.com/rubymotion/BubbleWrap) library. This will allow us to bypass some of the boilerplate code necessary to instantiate the Audio Player. First, add `require 'bubble-wrap'` and `require 'bubble-wrap/all'` to the Rakefile. Then add

~~~~ ruby
  gem "bubble-wrap"
~~~~

to the Gemfile and run `bundle install`.

I'm going to choose a random episode of a podcast for my testing purposes and use that for the remainder of the post. The url for this episode is 

~~~~ ruby
  http://streaming.osu.edu/wosu/classical101/In_the_Key_of_Danzmayr_Composer_Performer.mp3
~~~~

To keep things simple, lets just start playing audio when the Player Controller is instantiated.

In the viewDidLoad method of player_controller.rb 
~~~~ ruby
    url = "http://streaming.osu.edu/wosu/classical101/In_the_Key_of_Danzmayr_Composer_Performer.mp3"
    BW::Media.play(url) do |player|
      puts "Playing!"
    end
~~~~

When you run `rake` now, the audio should start playing. Nice!

### Motion::Layout

Now that we have audio playing, we want to start adding some player controls. If you are coming from a Front End (HTML/CSS/Javascript) background, you will quickly find that creating intricate UI's on the iPhone is a completely different ballgame. One library I have grown very fond of is the great [Motion Layout](https://github.com/qrush/motion-layout) which allows me to design the layout of our views using its layout formatting language. I will do an extensive tutorial of Motion Layout in the future, but for now [this tutorial](https://motioninmotion.tv/screencasts/1) on the Motion in Motion Screencasts page will get you started. Or you can follow along and grok at your own speed.

First, we need to add the gem to the Gemfile and RakeFile, respectively.

~~~~ ruby
  gem 'motion-layout'
    
  require 'motion-layout'
~~~~

Then, we should create a text field in our PlayerController that will either start or stop the playing audio. To do that, we are going to take advantage of another very cool feature of RMQ. In the viewDidLoad method in PlayerController, we can add the following above our code for playing the audio:

~~~~ ruby
    @play_stop = rmq.append(UIButton, :play_stop).get
    @play_stop.setTitle("Play", forState: UIControlStateNormal)
    @play_stop.styleClass = "button"
~~~~

This will add a label to the view and set it to an instance variable in the controller.

Now, if we run `rake`, the music will start playing but that label is nowhere to be found! Let's check out yet ANOTHER awesome RMQ feature. In your terminal where you have the rake task running, enter the following:

~~~~ ruby
  rmq.log :tree
~~~~

This will display a tree representation of all the current views in our application. Here's my output:

~~~~ ruby
  (main)> rmq.log :tree
  ─── PXUIView_UIView  ( root_view )  210869984  {l: 0, t: 64, w: 320, h: 504}
  ├─── PXUILabel_UILabel  210931328  {l: 0, t: 0, w: 0, h: 0}
~~~~

There's our label, but it looks like its frame is all 0's. We could use RMQ's stylesheets to set the frame manually, but I want to use Motion Layout's templating engine to get things where they need to be.

Add the following below the BubbleWrap audio code in viewDidLoad

~~~~ ruby
  Motion::Layout.new do |layout|
      layout.view self.view
      layout.subviews "play_stop" => @play_stop
      layout.vertical     "|-50-[play_stop]-(>=50)-|"
      layout.horizontal   "|-[play_stop]-|"
    end
~~~~

For a more thorough explanation of what this is doing, please visit the Motion Layout README until my tutorial is available.

Now, if we run rake we should see the label.

![](/blog/2014-02-17-building-podstudio-in-rubymotion-part-1/1.png)

Now, let's update the label when the audio starts playing. Replace the following

~~~~ ruby
  BW::Media.play(url) do |player|
      puts "Playing!"
    end
~~~~

with

~~~~ ruby
  BW::Media.play(url) do |player|
      @play_stop.setTitle("Stop", forState: UIControlStateNormal)
    end
~~~~

### Event Bindings

Let's make it so that clicking on the play_stop button triggers the expected behavior in our audio player. First things first, we need to maintain a reference to our player outside of this method, so lets set it to an instance variable:

~~~~ ruby
  @player = BW::Media.play(url) do |player|
      @play_stop.setTitle("Stop", forState: UIControlStateNormal)
    end
~~~~

Now we can operate on the Audio Player by dealing with @player directly.

Next, we will use the RMQ's event binding library to toggle the play status of the audio player. If you are familiar with jQuery this will look very familiar.

Below the Motion Layout code, add the following:

~~~~ ruby
    rmq(@play_stop).on(:tap) do
      if @player.playbackState == MPMoviePlaybackStatePlaying
        stopPlayer
      else
        startPlayer
      end
    end
~~~~

When the play_stop button is tapped, we want to check the state using @player.playbackState and act accordingly. When the player is playing (MPMoviePlaybackStatePlaying), we want to stop the player and vice versa. Lets define the two methods now:

~~~~ ruby
  def stopPlayer
    @play_stop.setTitle("Play", forState: UIControlStateNormal)
    @player.stop
  end

  def startPlayer
    @play_stop.setTitle("Stop", forState: UIControlStateNormal)
    @player.play
  end
~~~~

Now, we can start and stop the player just by clicking the button! Not too shabby for a couple lines of code.

### Next Steps
We now have a working audio player and a Play/Stop button to control its playback. However, you will notice that when you click the Home button on your device, the audio stops. In the next post in the series, we will explore the concept of Background Audio Sessions in iOS and make sure the playback continues without the app being key and visible. The code for this post is available on [GitHub](https://github.com/podstudio/podstudio-rm/tree/part1).


