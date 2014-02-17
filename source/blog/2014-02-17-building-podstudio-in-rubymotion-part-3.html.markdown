---
title: Building podstud.io in RubyMotion - Part 3
date: 2014-02-17 01:37 UTC
tags: Rubymotion
category: RubyMotion
---

If you've been following along with the series up until now, we have successfully gotten our app to play a remote audio file of our choosing with the ability to stop and start playback with a simple button in the UI. On top of that, we've added the capability to play the audio in the background so that playback can continue even after the user minimizes the app or locks the phone screen. However, the podstud.io app is definitely not going to win any awards when it comes to how it looks. At least in its current state. We're going to make some progress in that direction in this post. 

This is a vague idea of the look and feel we will be hoping to achieve by the end of the day. 

![](/blog/2014-02-17-building-podstudio-in-rubymotion-part-3/1.png)

Now, eventually we will be retrieving all of the information necessary to build our UI by parsing an XML/RSS feed for a particular podcast. But, this falls out of the scope of this particular step in the series and deserves its own attention later on. So, I will be merely creating the components and filling in the expected values until we can retrieve them dynamically. This is a common way to go about building out interfaces without having the added complication of fetching and parsing external dependencies. 

### Layout Breakdown

One thing I like to do when I am building out complex interfaces is to break the layout up into multiple, more manageable pieces. The mockup above, in my opinion, has three distinct areas. I've highlighted them below:

 ![](/blog/2014-02-17-building-podstudio-in-rubymotion-part-3/2.png)

 As you can see, the thumbnail for the episode or podcast represents a very large portion of the screen. Then we have the details view which includes the title of the podcast and the episode title. Towards the bottom of the screen we have our playback view, which will house our play/stop button as well as a progress indicator which will update upon playback. Let's tackle these views one at a time.

### Thumbnail View

First off, we need to create a `UIImageView` and append it to our view, similar to the way we added our play/stop button. In fact, we'll do it right under the code for the button in our PlayerController.

~~~~ ruby
  @thumbnail = rmq.append(UIImageView, :thumbnail).get
  @thumbnail.backgroundColor = UIColor.blackColor
~~~~

I've also set the background color to black for visual purposes while we get things in place. If we run a `rake` now we won't see anything yet. Of course, this is because we have not set a frame for our new view. We will do this the same way we have for the play/stop button using Motion::Layout.

I want to get the play/stop button out of our way temporarily. Sometimes it's nice to have a blank slate so I don't leave myself with too much tech debt or old code to shuffle around while I'm building something new. We want to leave all the functionality for the button itself in place, but just remove it from the layout. So, our `Motion::Layout` block in the PlayerController should now just look like this:

~~~~ ruby
  Motion::Layout.new do |layout|
    layout.view self.view
    layout.subviews "thumbnail" => @thumbnail
    layout.vertical     "|-[thumbnail]-|"
    layout.horizontal   "|-[thumbnail]-|"
  end
~~~~

Now, we can actually see our new image view!

![](/blog/2014-02-17-building-podstudio-in-rubymotion-part-3/3.png)

However, according to our constraints in the layout block, we are telling our image view to stretch both horizontally and vertically. We want the image to fill the width of the screen, but not the height. So, we adjust our constraints to:

~~~~ ruby
  layout.vertical     "|-(==0)-[thumbnail(==300)]-(>=0)-|"
  layout.horizontal   "|-(==0)-[thumbnail]-(==0)-|"
~~~~

Let's examine this change a bit. We are using this `(==0)` metric a couple times to indicate that we want to view to be pinned to the edge of the screen. Otherwise the layout will create some sensible margins around our view. We don't want to keep repeating this in our constraints since that's a great way to introduce bugs...so let's extract it.

#### Motion::Layout Metrics

Motion::Layout allows us to define 'metrics' as variables that we can use while defining constraints via its Visual Formatting Language. To do this, we just call another method from within the layout block:

~~~~ ruby
  layout.subviews "thumbnail" => @thumbnail
  layout.metrics "zero" => 0, "thumbnail_height" => 300
~~~~ 

We define two metrics named 'zero' and 'thumbnail_height' which we can now use to make our constraints a little more readable:

~~~~ ruby
  layout.vertical     "|-zero-[thumbnail(thumbnail_height)]-(>=zero)-|"
  layout.horizontal   "|-zero-[thumbnail]-zero-|"
~~~~

Voila!

![](/blog/2014-02-17-building-podstudio-in-rubymotion-part-3/4.png)

Now that we know are view is in the right place, let's go ahead and set its image to the thumbnail our podcast. The example we will be using is located at `http://cdn.earwolf.com/wp-content/uploads/2011/04/HDTGMFULL.jpg`.

There are a number of ways to populate the UIImageView with the contents of this remote image. However, there's a gem called [AFMotion](https://github.com/usepropeller/afmotion) which is going to come in handy for a *ton* of things moving forward. It's a thin wrapper around the [AFNetworking](https://github.com/AFNetworking/AFNetworking) library and makes dealing with remote content a breeze. It's installed the normal way:

~~~~ ruby
  gem 'afmotion'
~~~~   

And it comes with a really great helper for loading images from the internet. If we simply update our instantiation code for our thumbnail view, we can see how easy it is to grab the remote image and embed it in our application:

~~~~ ruby
  @thumbnail.backgroundColor = UIColor.blackColor
  @thumbnail.url = "http://cdn.earwolf.com/wp-content/uploads/2011/04/HDTGMFULL.jpg"
~~~~

![](/blog/2014-02-17-building-podstudio-in-rubymotion-part-3/5.png)

I don't mean to sound like a broken record when I say this...but that was pretty easy!


### Details View

Now, we want to add the views for the podcast and episode titles respectively. This is fairly straightforward:


~~~~ ruby
  @podcast_title = rmq.append(UILabel, :podcast_title).get
  @episode_title = rmq.append(UILabel, :episode_title).get
~~~~

We can also set the text attributes for the labels just as easily:

~~~~ ruby
  @podcast_title = rmq.append(UILabel, :podcast_title).get
  @podcast_title.text = "How Did This Get Made"

  @episode_title = rmq.append(UILabel, :episode_title).get
  @episode_title.text = "Wicker Man"
~~~~

We want to display these beneath the thumbnail view, with a margin on either side horizontally. So:

~~~~ ruby
  layout.view self.view
  layout.subviews "thumbnail" => @thumbnail, "podcast_title" => @podcast_title, "episode_title" => @episode_title
  layout.metrics "zero" => 0, "thumbnail_height" => 300
  layout.vertical     "|-zero-[thumbnail(thumbnail_height)]-[podcast_title]-[episode_title]-(>=zero)-|"
  layout.horizontal   "|-zero-[thumbnail]-zero-|"
  layout.horizontal   "|-[podcast_title]-|"
  layout.horizontal   "|-[episode_title]-|"
~~~~

Notice how we have multiple `layout.horizontal` methods now. This is perfectly fine, and actually the way we need to proceed if we want to define the horizontal constraints for elements that do not exist on the same horizontal plane.

If we run a `rake` now, we should see the following:

![](/blog/2014-02-17-building-podstudio-in-rubymotion-part-3/6.png)

I'm not a huge fan of the way that text looks. Luckily Pixate Freestyle comes with some sensible and appealing defaults for different font styles. All we have to do is add the class to the element (much like you would in CSS) and the styles will be applied correctly. How do we do this in RubyMotion? Well, Pixate creates a helper on our UI components named styleClass which allows us to provide the class we would like to attach.

~~~~ ruby
  @podcast_title.styleClass = "h3"
  @episode_title.styleClass = "h5"
~~~~

![](/blog/2014-02-17-building-podstudio-in-rubymotion-part-3/7.png)


That's definitely a little cleaner. Moving on...

### Playback View

We're going to follow more or less the same approach as above to get everything in place, with one caveat. It's possible to simply create the necessary elements and place them in our view within our existing Motion::Layout block, however this will quickly get very cumbersome (I'll leave that as an exercise for the reader if you don't believe me!). So, we're going to take advantage of Motion::Layout's powerful ability to nest layouts within each other. First, we'll create a UIView which will house our playback components:

~~~~ ruby
  @playback_view = rmq.append(UIView, :playback_view).get
~~~~ 

We can place this view within our current layout since that's easy enough for now:

~~~~ ruby
  Motion::Layout.new do |layout|
    layout.view self.view
    layout.subviews "thumbnail" => @thumbnail, "podcast_title" => @podcast_title,
                    "episode_title" => @episode_title, "playback_view" => @playback_view
    layout.metrics "zero" => 0, "thumbnail_height" => 300
    layout.vertical     "|-zero-[thumbnail(thumbnail_height)]-[podcast_title]-[episode_title]-[playback_view]-(>=zero)-|"
    layout.horizontal   "|-zero-[thumbnail]-zero-|"
    layout.horizontal   "|-[podcast_title]-|"
    layout.horizontal   "|-[episode_title]-|"
    layout.horizontal   "|-[playback_view]-|"
  end
~~~~

Now, we would like to create the components that will live within the playback view. Those being the play/stop button, the start_time and end_time of the audio and the progress slider.

~~~~ ruby
  @playback_view = rmq.append(UIView, :playback_view).get

  @play_stop = rmq(@playback_view).append(UIButton, :play_stop).get
  @play_stop.setTitle("Play", forState: UIControlStateNormal)
  @play_stop.styleClass = "button"

  @start_time = rmq(@playback_view).append(UILabel, :start_time).get
  @start_time.text = "00:00"

  @end_time = rmq(@playback_view).append(UILabel, :end_time).get
  @end_time.text = "12:34"
  
  @slider = rmq(@playback_view).append(UISlider, :slider).get
~~~~

Notice that instead of simply calling `rmq.append`, we are appending the new views *to* our playback_view. This is very similar to the way things are done in jQuery by design. Now that we have the playback_view in position, we need to move its children into place within the context of the playback_view itself. Luckily, this is very easy to do by simply using another Motion::Layout block! Below our current layout block, add the following:

~~~~ ruby
  Motion::Layout.new do |layout|
    layout.view @playback_view
    layout.subviews "play_stop" => @play_stop, "start_time" => @start_time,
                    "end_time" => @end_time, "slider" => @slider
    layout.metrics "zero" => 0, "top" => 50, "button_size" => 100, "button_size_with_margin" => 115, "text_width" => 50
    layout.vertical  "|-[play_stop]-|"
    layout.vertical  "|-[slider]-(>=zero)-|"
    layout.vertical  "|-top-[start_time]-(>=zero)-|"
    layout.vertical  "|-top-[end_time]-(>=zero)-|"
    layout.horizontal "|-zero-[play_stop(==button_size)]-(>=zero)-|"
    layout.horizontal "|-button_size_with_margin-[slider]-(<=zero)-|"
    layout.horizontal "|-button_size_with_margin-[start_time(==text_width)]-[end_time(==text_width)]-(>=zero)-|"
  end
~~~~

This is a little more intricate than the other layouts we've created but it gets easier with a thoughtful set of metrics and constraints. Imagine having all of this code in our original code block! There are even more ways to simplify this layout. We could extract the start and end time labels into their own layout and nest it within this playback_view layout. we could isolate the slider + time views and simply place them adjacent to the play/stop button. All of these options would make our code much more readable and easy to deal with. I will implement those optimizations in the branch, which you can check out on [GitHub](http://www.github.com/podstudio/podstudio-rm). But for now, let's check out what we have:

![](/blog/2014-02-17-building-podstudio-in-rubymotion-part-3/8.png)

We're looking pretty good so far! I actually kind of like the way that button looks compared to the one in the mockup, so I'm going to leave that for now. 

*Important Note:* I haven't delineated the tests for this article, but I can't stress enough how important it is to write tests as you go. Once our UI gets more and more complicated, we're going to rely on those tests to tell us if anything breaks, and more importantly when everything is running as we expect it to. They can all be found in the `/specs` folder on Github.
