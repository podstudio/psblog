---
title: Building podstud.io in RubyMotion - Part 2
date: 2014-02-17 01:37 UTC
tags: Rubymotion
category: RubyMotion
---

In this post, we are going to configure our existing app to take advantage of the built-in support for [Audio Sessions](https://developer.apple.com/library/ios/documentation/Audio/Conceptual/AudioSessionProgrammingGuide/Configuration/Configuration.html) in iOS. We have learned how to successfully play audio from a remote source in previous posts, but if you hit the home button or close out of the app...the music doesn't come with you!

**Important Note:** The iPhone Simulator does not have reliable (or any, at the time of this post) support for background audio sessions. In order to adequately test whether or not this is working, you will need to be running your app *directly on your device.* If you have provisioned your phone correctly it's as simple as running `rake device`. Otherwise, there are a ton of resources that will show you how to test your RubyMotion app on your device..[here's one](http://www.cerebro.com.au/2012/08/23/releasing-rubymotion-to-ios-devices-part-1/).


### AVFoundation Framework

The first thing we need to do is configure the Podstudio app to use the AVFoundation and AudioToolBox Frameworks. On top of this, we need to explicitly tell the iPhone what background modes we are requesting access to. [Ray Wenderlich](http://www.raywenderlich.com/29948/backgrounding-for-ios) has a really great overview of the different options here and what we can accomplishing by using different background modes in our app.

Add the following to your Rakefile:

~~~~ ruby
  app.frameworks << 'AVFoundation'
  app.frameworks << 'AudioToolbox'
  app.background_modes = [:audio]
~~~~

Then we need to configure our app to set the AVAudioSession and instruct it to allow audio in the background. To do this, we add these lines to bottom of the viewDidLoad method in our PlayerController:

~~~~ ruby
  AVAudioSession.sharedInstance.setDelegate(self)
  AVAudioSession.sharedInstance.setCategory(AVAudioSessionCategoryPlayback, error:nil)
  AVAudioSession.sharedInstance.setActive(true, error:nil)
~~~~

As you can see, we are setting the AVAudioSession's 'category' to AVAudioSessionCategoryPlayback. A list of all of our choices can be found here: [Audio Session Programming: Audio Session Categories](https://developer.apple.com/library/ios/documentation/Audio/Conceptual/AudioSessionProgrammingGuide/AudioSessionCategories/AudioSessionCategories.html). You can see why we have chose AVAudioSessionCategoryPlayback as opposed to the other options. Our audio should be output only (of course), should not be silenced by the Ring/Silent switch or by screen locking and should play over audio from any other applications.

Let's give it a quick test by running `rake device`.

If this is your first time running on device, it might take a while to compile all the project files. Once that's done, we should hear the audio start playing as usual. Now here's the moment of truth. Hit the home button to minimize the app and what happens? Nothing! Our audio is still playing even when PodStudio is not visible! Only 6 lines to implement this deceivingly simple, yet important feature.

If you've used any other media playing apps, the next steps should be obvious. We want to be able to start/stop the audio from the Lock Screen, or even the iOS Media Info Center (The one you drag up from the bottom of the screen). We'll get to all that, but the next post in the series will be all about prettying up our UI a bit. I know you're thinking "how could this get *any* better looking!?" but trust me. This is the fun part!
