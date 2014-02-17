---
title: Building podstud.io in RubyMotion - Part 4
date: 2014-02-17 15:01 UTC
tags: Rubymotion
category: RubyMotion
---

We've finally got our Player Controller looking relatively presentable! The thumbnail view is in place, along with the titles and the playback controller. Here's what it looks like so far:

![](/blog/2014-02-17-building-podstudio-in-rubymotion-part-4/1.png)

In this article, we are going to focus primarily on the slider control which will act as a progress indicator for the current audio playing. We would like this to have all the expected functionality, auto-updating based on the current playback time and the ability to seek forwards and backwards in the audio.

First, we'll get those start and end time labels filled with the correct data.

### MPMoviePlayerController Duration

Since we are using the BubbleWrap media object, our audio is wrapped within an instance of MPMoviePlayerController. If we wanted to, we could manually instantiate an AVPlayer or AVAudioPlayer depending on our needs. We will actually be doing this in the future, as it provides a little more flexibility. But for now, the MPMoviePlayerController is just fine.

We would like to set the value for our end_time label to the total duration of the streaming audio. However, we don't have access to this value until the file itself is loaded over the network. If we look at the documentation for MPMoviePlayerController, we will find an instance method named `duration`:

>The duration of the movie, measured in seconds. (read-only) If the duration of the movie is not known, the value in this property is 0.0. If the duration is subsequently determined, this property is updated and a MPMovieDurationAvailableNotification notification is posted.

So, we are going to create an observer to listen for that `MPMovieDurationAvailableNotification` notification and update our UI accordingly.

We are going to use another BubbleWrap helper to assist us in listening for Notification Center events. Below the code which instantiates our `@player` object:

~~~~ ruby
  @duration_observer = App.notification_center.observe 'MPMovieDurationAvailableNotification' do |notification|
    duration = @player.duration
    @slider.maximumValue = duration
    @end_time.text = formatted_time(duration)
  end
~~~~ 

When the MPMovieDurationAvailableNotification is caught, we do a number of things. First, we get the newly updated `duration` for our player. Then we set this value to the maximumValue of our progress slider. This will allow us to correctly seek to a particular time within the duration of the audio. Then, we set the end_time label's text to a formatted string of the duration in seconds. This is the helper I use, feel free to implement your own, probably better, version. 

~~~~ ruby
  def formatted_time(total_seconds)
    return "00:00:00" if total_seconds.nil? || total_seconds.nan?
    seconds = (total_seconds % 60) || 0
    minutes = (total_seconds / 60) % 60 || 0
    hours = total_seconds / 3600 || 0

    formatted_seconds = "%02d" % seconds
    formatted_minutes = "%02d" % minutes
    formatted_hours = "%02d" % hours
    "#{formatted_hours}:#{formatted_minutes}:#{formatted_seconds}"
  end
~~~~~

If we run a rake now, we should see the end_time label update with the correctly formatted total duration once the notification is received:

![](/blog/2014-02-17-building-podstudio-in-rubymotion-part-4/2.png)

*Important Note:* When we create these observers for the Notification Center, it is very important to invalidate them when we are done. Otherwise, our application will continue to listen for these notifications and cause potential memory issues. This will most likely happen when a new view_controller is pushed to the navigation stack, or if we are positive we no longer need the observer. In our case, we will do this in the `viewWillDisappear` method:

~~~~ ruby
  def viewWillDisappear(animated)
    App.notification_center.unobserve @duration_observer
  end
~~~~ 

### NSTimer

Now, we would like to update our slider control to represent the play progress of our audio file. To do this, we will use the NSTimer class to repeat a certain method call every second. This method will check the current playback time of the MPMoviePlayerController and update the start_time label and slider position. Let's update the player instantiation code to start our timer.

~~~~ ruby
  @player = BW::Media.play(url) do |player|
    @play_stop.setTitle("STOP", forState: UIControlStateNormal)
    startTimer
  end
~~~~

and define `startTimer`:

~~~~ ruby
  def startTimer
    @timer = NSTimer.scheduledTimerWithTimeInterval(1.0, target:self, selector:'playerTick', userInfo:nil, repeats:true)
  end
~~~~

The `scheduledTimerWithTimeInterval` will run every second and call the 'playerTick' moethod, which we implement below:

~~~~ ruby
  def playerTick
    puts "TICK"
  end
~~~~

Now, once the audio starts playing we should see the "TICK" message appear in our console every second. We'd like to build out this method a little more. It's actually going to be quite similar to the way we set the end_time label's value and slider's maximumValue. Instead of using the `duration` method on MPMoviePlayerController, we are now going to use the `currentPlaybackTime`:

~~~~ ruby
  def playerTick
    current_time = @player.currentPlaybackTime

    @slider.value = current_time
    @start_time.text = formatted_time(current_time)
  end
~~~~

Now, if we run our application we should see the start_time label updating every second. Depending on the length of our audio file, we should also see the progress bar advancing in value as the audio plays. Cool!

![](/blog/2014-02-17-building-podstudio-in-rubymotion-part-4/3.png)

The Timer class presents some of the same issues that the Notification Center had before. We don't want this timer to run indefinitely, so we have to invalidate it when it is no longer in use. We create a helper method to do this for us in a number of places:

~~~~ ruby
  def stopTimer
    if !@timer.nil?
      @timer.invalidate
      @timer = nil
    end
  end
~~~~

and call it where appropriate:

~~~~ ruby
  def viewWillDisappear(animated)
    App.notification_center.unobserve @duration_observer
    stopTimer
  end
~~~~

~~~~ ruby
  def stopPlayer
    @play_stop.setTitle("Play", forState: UIControlStateNormal)
    @player.stop
    stopTimer
  end
~~~~

We also want to remember to start the timer again if we play the audio after it has already been stopped:

~~~~ ruby
  def startPlayer
    @play_stop.setTitle("Stop", forState: UIControlStateNormal)
    @player.play
    startTimer
  end
~~~~

### Seeking Audio

The next thing we'd like to accomplish is adding the ability to seek our audio by dragging our UISlider component around. This can be done quite simply using RMQ's event bindings. We want to bind to the `change` event on our control and call a method when it occurs:

~~~~ ruby
  @slider = rmq(@playback_view).append(UISlider, :slider).get
  rmq(@slider).on(:change) do |val|
    puts @slider.value
  end
~~~~

Here's what my output looks like when I drag the slider around a little:

![](/blog/2014-02-17-building-podstudio-in-rubymotion-part-4/4.png)

This is a little too much. We don't actually want to seek the audio for every *change* of the UISlider. We only want to fire off our seek mothod when the user is done selecting the new value. This points us towards the `continuous` method on UISlider:

>Contains a Boolean value indicating whether changes in the sliders value generate continuous update events. If YES, the slider sends update events continuously to the associated target’s action method. If NO, the slider only sends an action event when the user releases the slider’s thumb control to set the final value.The default value of this property is YES.

So, we update our code:

~~~~ ruby
  @slider = rmq(@playback_view).append(UISlider, :slider).get
  @slider.continuous = false
  rmq(@slider).on(:change) do
    ap @slider.value
  end
~~~~

and can see that our event callback is only called when the user intentionally selects a new position for the slider

We'd like to use the slider's new value to choose how far into the audio to seek. So, we create a new method named `seekToValue` and call it within our event handler (being sure to pass in the new slider value).

~~~~ ruby
  rmq(@slider).on(:change) do
    seekToValue(@slider.value)
  end
~~~~

and 

~~~~ ruby
  def seekToValue(value)
    @player.currentPlaybackTime = value
  end
~~~~

And that's it! We can now seek forwards and backwards in our audio and the UI will update itself accordingly. Moving forward, we are going to take a dive into the `MPNowPlayingInfoCenter` and see how we can update the Now Playing screen on our phone's lock screen with metadata from our currently playing audio. If you're not familiar with this screen, all you have to do is swipe up from the bottom of your screen and you should see the following:

![](/blog/2014-02-17-building-podstudio-in-rubymotion-part-4/5.png)

We're going to put our current playback progress and metadata into this view so we can control our audio without having to give our app focus.


