---
title: Building podstud.io in RubyMotion - Part 5
date: 2014-02-17 23:26 UTC
tags: Rubymotion
category: RubyMotion
---

In Part 4 of the series, we successfully implemented audio seeking and a progress bar to indicate playback time in our Player Controller. However once we launch our app, the only way to stop the audio or seek to a different time in the stream is from the Player Controller itself. The iPhone comes with a really handy way to control the current audio session without having to open the relevant app. It's called the `MPNowPlayingInfoCenter` and it provides some really cool functionality given not so much effort. According to the [docs](https://developer.apple.com/library/ios/documentation/mediaplayer/reference/MPNowPlayingInfoCenter_Class/Reference/Reference.html):

>Use a now playing info center to set now-playing information for media being played by your app.

We're going to notify the MPNowPlayingInfoCenter class when we start playing audio and have it display the current episode name and podcast title, along with the current playback time.

### MPNowPlayingInfoCenter

The MPNowPlayingInfoCenter has a `defaultCenter`, which is a singleton object that we will use to update the `nowPlayingInfo`. Let's write our method to update this info first, and then decide when to call it.

~~~~ ruby
  def updateNowPlayingInfo(player)
    nowPlayingInfo = {
      MPMediaItemPropertyTitle => "Wicker Man",
      MPMediaItemPropertyArtist => "How Did This Get Made",
      MPMediaItemPropertyPlaybackDuration => player.duration,
      MPNowPlayingInfoPropertyElapsedPlaybackTime => player.currentPlaybackTime,
      MPNowPlayingInfoPropertyPlaybackRate => player.currentPlaybackRate
    }

    MPNowPlayingInfoCenter.defaultCenter.nowPlayingInfo = nowPlayingInfo
  end
~~~~

This is a fairly simple method which takes in a player object and uses its properties to update the defaultCenter's nowPlayingInfo. We generate a Hash (or NSDictionary) with a number of special-named keys with the values that we would like to appear in the Now Playing Center. This is only a tiny subset of the types of things we can set as nowPlayingInfo, [the whole list can be found here](https://developer.apple.com/library/ios/documentation/mediaplayer/reference/MPNowPlayingInfoCenter_Class/Reference/Reference.html#//apple_ref/doc/constant_group/Additional_Metadata_Properties).

A couple things to point out: It is very important to set the Playback Duration, Elapsed Playback Time and Playback Rate. The goal is for the progress bar in the Now Playing Info Center to accurately display the current playback time for our audio. At first glance, you might think it makes sens to simply update this value in the nowPlayingInfo on every call to our `playerTick` method. However:

>*MPNowPlayingInfoPropertyElapsedPlaybackTime*
The elapsed time of the now playing item, in seconds.
Value is an NSNumber object configured as a double. Elapsed time is automatically calculated, by the system, from the previously provided elapsed time and the playback rate. Do not update this property frequently—it is not necessary.

So, all we need to do is set this attribute once and we can leave it alone as long as we have correctly set the Playback Rate. The device will automatically determine the elapsed time for as long as it detects audio playing in the AVAudioSession.

Now, we have to decide when we would like to call this method. We've already ruled out the `playerTick` method as this will cause a significant performance hit by calculating and broadcasting this hash every second. A good place to start is within the callback for the @player object. Let's give that a go:

~~~~ ruby
  @player = BW::Media.play(url) do |player|
    @play_stop.setTitle("STOP", forState: UIControlStateNormal)
    startTimer
    updateNowPlayingInfo(player)
  end
~~~~

Once the player is instantiated, we tell the MPNowPlayingInfoCenter to update itself with the episode information we have provided. If we run our app now, and open up the MPNowPlayingInfoCenter, we should see the following:

*Important Note:* As stated previously, the Simulator does not support Background Audio Sessions so it will also not support our calls to the MPNowPlayingInfoCenter. Be sure to run these tests on your device.

![](/blog/2014-02-17-building-podstudio-in-rubymotion-part-5/1.png)

Woo! We can see both our episode and podcast title displayed in the MPNowPlayingInfoCenter. But, that progress bar obviously doesn't look right. If we put some logging into our `updateNowPlayingInfo` method, we can see that the value that we are passing on for `player.duration` is wrong! Oh yea.. remember when we had to create that Notification Observer to detect when our audio player's duration was updated? Up until that observer is resolved, we have no idea what the duration of our audio is. This would be a better place to call our `updateNowPlayingInfo` method. Let's remove it from our `@player` instantiation code and add it to our `@duration_observer`.

~~~~ ruby
  @player = BW::Media.play(url) do |player|
    @play_stop.setTitle("STOP", forState: UIControlStateNormal)
    startTimer
  end
~~~~

and

~~~~ ruby
  @duration_observer = App.notification_center.observe 'MPMovieDurationAvailableNotification' do |notification|
    duration = @player.duration
    @slider.maximumValue = duration
    @end_time.text = formatted_time(duration)
    updateNowPlayingInfo(@player)
  end
~~~~

If we run our app now, wait for the audio play for a couple seconds and open up the Now Playing Info Center we'll actually see our duration and the current playback time displayed! 

![](/blog/2014-02-17-building-podstudio-in-rubymotion-part-5/2.png)

But, the current playback time is not progressing as we would expect it to..As long as we've set the Elapsed Playback Time, Duration and Playback Rate we would expect the device to automatically update the Elapsed Time. This brings us to an important, and very obscure line of code that will make a ton of things a lot easier for us.

~~~~ ruby
  UIApplication.sharedApplication.beginReceivingRemoteControlEvents
~~~~

According to the docs:

>Tells the application to begin receiving remote-control events. Remote-control events originate as commands issued by headsets and external accessories that are intended to control multimedia presented by an application. To stop the reception of remote-control events, you must call endReceivingRemoteControlEvents.

Now, I'm not entirely sure why we need this line in order to correctly update the elapsed time in the MPNowPlayingInfoCenter but if we add it right after we have declared

~~~~ ruby
  AVAudioSession.sharedInstance.setCategory(AVAudioSessionCategoryPlayback, error:nil)
~~~~

We see the elapsed time updating correctly!

Let's tell our app to update the MPNowPlayingInfoCenter whenever we change the current playback time via seeking with the progress bar since the device will not automatically detect these changes.

~~~~ ruby
  def seekToValue(value)
    @player.currentPlaybackTime = value
    updateNowPlayingInfo(@player)
  end
~~~~

It should be noted that we can also see this Now Playing Info by playing the audio and then locking our screen. 

![](/blog/2014-02-17-building-podstudio-in-rubymotion-part-5/3.png)

### Thumbnail Image

One thing that we can display on the lock screen that's not available in the normal Now Playing Info Center is an image relating to our content. In this instance, it is the thumbnail of our podcast. If we add the following block to our `updateNowPlayingInfo` method let's see what happens:

~~~~ ruby
  if !@thumbnail.image.nil?
    nowPlayingInfo[MPMediaItemPropertyArtwork] = MPMediaItemArtwork.alloc.initWithImage(@thumbnail.image)
  end
~~~~


![](/blog/2014-02-17-building-podstudio-in-rubymotion-part-5/4.png)

Nice! All we have to do is instantiate a new MPMediaItemArtwork class with the image associated with our `@thumbnail` object.

### Remote Control Events

I'm sure you've noticed some of the other functionality that the Now Playing Info appears to provide, but we have yet to touch upon. We actually have the ability to Play, Pause and seek our audio right from the Now Playing Info Center and Lock Screen but it takes a little bit of work.

These buttons actually broadcast Remote Control Events that we need to catch and use to update our audio player accordingly. We've already taken care of the first step which was telling our app to `beginReceivingRemoteControlEvents`.

If we want to detect when one of these remote control buttons is pressed, we have to implement the following method in our controller:

~~~~ ruby
  def remoteControlReceivedWithEvent(event)
    NSLog("RECEIVED EVENT")
  end
~~~~

*Important Note:* I'm using `NSLog` rather than the usual `puts` because we are running our app on device. Logs that are created with anything but NSLog will not appear in our console while the app is running on the phone itself.

If we run our app and click one of the buttons in the Now Playing Info Center, we would expect to see "RECEIVED EVENT" in our console...and we do!

Now, we have access to the RemoteControlEvent that was sent to our app and will have to choose how to act. The event has a `subtype` which will help us determine exactly what button was pressed. A list of all of potential subtypes is available [here](http://www.rubymotion.com/developer-center/api/UIEventSubtype.html).
 In our case, we are interested in the UIEventSubtypeRemoteControlPlay, UIEventSubtypeRemoteControlPause, UIEventSubtypeRemoteControlNextTrack, and UIEventSubtypeRemoteControlPreviousTrack subtypes. All we have to do is check if our event's subtype matches one of these and tell our player what to do.

~~~~ ruby
  def remoteControlReceivedWithEvent(event)
    case event.subtype
    when UIEventSubtypeRemoteControlPlay
      startPlayer
    when UIEventSubtypeRemoteControlPause
      stopPlayer
    when UIEventSubtypeRemoteControlNextTrack
      seekToValue(@player.currentPlaybackTime + 15)
    when UIEventSubtypeRemoteControlPreviousTrack
      seekToValue(@player.currentPlaybackTime - 15)
    end
  end
~~~~

The first two cases are pretty straightforward, play and pause the app when necessary. I should mention that I've updated the `stopPlayer` method to pause the player rather than stop it completely.

~~~~ ruby
  def stopPlayer
    @play_stop.setTitle("Play", forState: UIControlStateNormal)
    @player.pause
    stopTimer
  end
~~~~

Then, if the user clicks the next or previous track buttons we simply want to seek forwards or backwards in the audio file. We can accomplish this pretty easily using our established `seekToValue` method.

Now, if we run `rake device` we can control our app audio right from the lock screen!

![](/blog/2014-02-17-building-podstudio-in-rubymotion-part-5/5.png)

### Wrapping Up

And there we go! We successfuly set the NowPlayingInfo for the MPNowPlayingInfoCenter and the Lock Screen, including a nice thumbnail image for our current podcast. THen we set up our app to respond to Remote Control Events from both of these screens and updated our `@player` object accordingly.

In the next article in the series, I'm going to dig into a very handy app called [Reveal](http://revealapp.com/) that allows us to do some really cool things while debugging the view hierarchy in our app. It might not be entirely necessary now but it is going to be *extremely* helpful once we start building out more complext UI's. Here's a sneak peak of its View Hierarchy Perspective:

![](/blog/2014-02-17-building-podstudio-in-rubymotion-part-5/reveal.jpg)
