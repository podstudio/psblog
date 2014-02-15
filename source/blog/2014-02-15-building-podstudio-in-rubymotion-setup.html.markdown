---
title: Building podstud.io in Rubymotion - Setup
date: 2014-02-15 21:10 UTC
tags:
category: RubyMotion
---

Remember to add something here...


### Setup & The Player Controller

First, we need to create our new RubyMotion project. I'm a huge fan of the RubyMotionQuery library written by Todd Werth at http://infinitered.com/rmq/, so I am going to use that to get things moving in the right direction. It might(read: would definitely) be useful to check out the project and GitHub and see what @twerth has to say about rmq himself.

`rmq create podstudio-rm`
    
If we run `rake` now, we can see that our app is already up and running!

{<2>}![](/content/images/2014/Feb/iOS_Simulator_Screen_shot_Feb_10__2014_12_28_27_PM.png)

Now, we need to create a controller to display the Podcast Episode Player View. I'll call it the PlayerController and create it by using RMQ's controller creation API:
  
`rmq create controller player`

Let's see what that did. The output of this command is as follows:

~~~ ruby
  Creating controller: player

     Using existing directory: app/controllers
  Δ  Creating file: /Users/nader/Dev/podstudio/podstudio-rm/app/controllers/player_controller.rb
     Using existing directory: app/stylesheets
  Δ  Creating file: /Users/nader/Dev/podstudio/podstudio-rm/app/stylesheets/player_controller_stylesheet.rb
     Using existing directory: spec/controllers
  Δ  Creating file: /Users/nader/Dev/podstudio/podstudio-rm/spec/controllers/player_controller.rb

     Done
~~~~

So, the command created a controller, a stylesheet and a test file for the PlayerController. Now, to load the new PlayerController when the app is launched.

In `app/app_delegate.rb`, change the following lines:

~~~ ruby
  main_controller = MainController.alloc.initWithNibName(nil, bundle: nil)
  @window.rootViewController = UINavigationController.alloc.initWithRootViewController(main_controller)
~~~~

to

~~~ ruby
  player_controller = PlayerController.new
  @window.rootViewController = UINavigationController.alloc.initWithRootViewController(player_controller)
~~~~
Then, add a title to the PlayerController so we can be sure we're in the right place.

In the viewDidLoad method of player_controller.rb, add the following:

~~~ ruby
self.title = "Player"
~~~

Now, if we run `rake` we'll see that we are sent to the Player Controller this time.

{<3>}![](/content/images/2014/Feb/iOS_Simulator_Screen_shot_Feb_10__2014_12_40_11_PM.png)


Now, we don't want our cool new podcasting app to look like every other iOS7 app out there, so let's try and add some basic styling to differentiate ourselves and make the app even more exciting.

### Enter Pixate
According to [their site](http://www.pixate.com/), Pixate is a free framework that lets you style your native iOS views with stylesheets. That means we get to use CSS (and even SASS) to style our UI components! If you haven't made the switch over to SASS from Vanilla CSS, please do yourself (and everyone who reads your code) a favor and at least [give it a look](http://sass-lang.com/).

Pixate has recently released its own CSS Framework that allows us to create a great looking app without writing everything from scratch. If you're familiar with Twitter Bootstrap, you'll immediately understand the advantages of using [Freestyle](http://www.pixate.com/freestyle/). So, let's start incorporating Pixate into our project.

#### Installing Pixate 

I'm going to use a gem called RubyMotion-Pixate to help us get off the ground here. The documentation for setup is fairly straightforward, so I won't duplicate efforts. Please refer to the setup step on [Github](https://github.com/Pixate/RubyMotion-Pixate). If you followed those steps correctly you should be good to go, but I like to use SASS rather than Vanilla CSS so there are a couple more steps. Make sure you have added `gem 'motion-pixate'` to your Gemfile and continue on.

First, we have to create a `sass` folder under our main project directory and copy in the .scss files from the Pixate Freestyle Download.

My directory structure now looks like this:

{<4>}![](/content/images/2014/Feb/Screen_Shot_2014_02_10_at_1_08_26_PM.png)

Feel free to poke around these SASS files and see how simple it is to customize our UI now!

#### Pixate SASS Build Task
One thing that is important to note is that our SASS is only compiled when we manually run `rake pixate:sass`. That's quite annoying to do repeatedly during the development process, so I like to add the following lines to my Rakefile:

~~~ ruby
  task :"build:simulator" => :"pixate:sass"
  task :"build:device" => :"pixate:sass"
~~~~

Now, whenever we build to the simulator or our device, our CSS file will automatically be generated for us by Pixate. 

Lets take a look at what happens when we run `rake` now.

{<5>}![](/content/images/2014/Feb/iOS_Simulator_Screen_shot_Feb_10__2014_1_11_34_PM.png)

Simple, but already starting to look much nicer than our default UI.

### Next Steps

Now that we are all set up, we can start developing the UI for our Podcast Player and exploring the powerful functionality we can introduce over time using RubyMotion. It should be mentioned that I follow the preceding steps for almost every new project I start in RubyMotion. Feel free to check out the project on [GitHub](https://github.com/podstudio/podstudio-rm/tree/setup) and run it yourself. 
