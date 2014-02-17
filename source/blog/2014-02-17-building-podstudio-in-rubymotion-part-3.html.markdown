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
