---
title: Building podstud.io in RubyMotion - Tests
date: 2014-02-17 01:19 UTC
tags: Rubymotion
category: RubyMotion
---

Up until this point in the series, I have intentionally avoided mentioning tests in the development of the PodStudio app. I've done this because sometimes it's fun to get right to the fun stuff and see the fruits of your labor right on the screen. But, the one thing that's even more fun than building an awesome app is knowing that it won't break!

So, we're going to get started setting up a test harness for our RubyMotion app. RubyMotion comes with a testing framework named [Bacon](https://github.com/chneukirchen/bacon/) which describes itself as "a small RSpec clone weighing less than 350 LoC but nevertheless providing all essential features." If you're familiar with RSpec alot of the syntax and testing process will make sense to you, however it is not necessarily a prerequisite.

First things first, lets run the tests now and see what happens:

~~~~ ruby
  rake spec
~~~~

There might be alot of noisy output in the terminal, but you should see the app being compiled and the tests being run. At the bottom of the output we should see:

~~~~ ruby
PlayerController

Application 'podstudio-rm'
  - has one window

1 specifications (1 requirements), 0 failures, 0 errors
~~~~

That's good news! We only have one spec written (provided by RubyMotion itself) and it has passed!

This output is a little ugly to me, so I'm going to add a couple gems to make it a little more readable.

~~~~ ruby
  gem 'awesome_print_motion'
  gem 'motion-redgreen'
~~~~

and in your Rakefile:

~~~~ ruby
  app.redgreen_style = :full
~~~~
Now if you run `rake spec` you should see some nice green output.

![](/blog/2014-02-17-building-podstudio-in-rubymotion-tests/1.png)

Cool. Now that we have that working, we should go ahead and test some of the code we've written so far in this series.

### Testing the PlayerController

If you recall, when we created the PlayerController using RMQ it came along with a spec file for the newly created controller. This file lives at /spec/controllers/player_controller.rb

Lets write some simple tests for our controller and its associated view now.

One of the first things we do in the viewDidLoad method is set the title for the current controller in the navigation stack.

~~~~ ruby
  self.title = "Player"
~~~~

Let's test that out. In the player_controller.rb spec file, we'll create a new test to assert the correct title is set.

I like to organize my controller specs by the methods they live in, in this case `viewDidLoad`. To do this, we use a `describe` block.

Under the following block in the test file:

~~~~ ruby
  after do
  end
~~~~

add our new test:

~~~~ ruby
  describe "viewDidLoad" do
    it "should have the correct title" do
      controller.title.should == "Player"
    end
  end
~~~~

Pretty simple test. You can see the power of Bacon in how quickly we can assert things using the .should syntax. Lets try running the specs.
    
![](/blog/2014-02-17-building-podstudio-in-rubymotion-tests/2.png)
    
Uh Oh.... "undefined local vairable or method 'controller'". 

Even though our spec file is named 'player_controller' we really have no reasonable expectation that it knows to actually *test* the PlayerController. To do this, we add the following line right below the `describe "PlayerController"` line:

~~~~ ruby
  tests LoginController
~~~~

And just like that, tests pass!
    

### Testing Views

Now, lets test some of the functionality in our view. In general, I like to first test that things are in their correct positions and then test the functionality related to them. Then I move on to unit tests for any helper functions I may have implemented in the controller.

#### Play/Stop Button

In the controller, we've added a button with the title "Play" and styleClass "button". Using Motion::Layout, we have placed the button 50 points from the top of the screen and stretched to fit the width of the screen. Let's see how some of the tests for that will look:

~~~~ ruby
  describe "play_stop button" do
    before do
      @play_stop_button = controller.instance_variable_get("@play_stop")
    end

    it "should have a play_stop button" do
      @play_stop_button.should.not == nil
    end

    it "should be a descendant of the controller's view" do
      @play_stop_button.isDescendantOfView(controller.view).should == true
    end

    it "should have the correct title" do
      @play_stop_button.currentTitle.should == "STOP"
    end

    it "should be in the correct position" do
      expected_rect = CGRectMake(20, 50, 280, 32)
      @play_stop_button.frame.should == expected_rect
    end
  end
~~~~

One very important line of code is this: `@play_stop_button = controller.instance_variable_get("@play_stop")` 

This is very useful for when we want to get access to a particular instance variable within our controller without having to iterate over its subviews, or any other collection of objects.

I like to keep my individual tests *very* small, being sure to always just assert one thing at a time. Of course there are always exceptions, but the above code snippet is a good example of getting some basic sanity checks into our code. The next thing we want to test for our play/stop button is its behavior when tapped. This will lead us into using such concepts as Mocking and Stubbing in our tests.

### Mocking

From [Wikipedia](http://en.wikipedia.org/wiki/Mock_object):

---
In a unit test, mock objects can simulate the behavior of complex, real objects and are therefore useful when a real object is impractical or impossible to incorporate into a unit test. If an object has any of the following characteristics, it may be useful to use a mock object in its place:

* supplies non-deterministic results (e.g., the current time or the current temperature);
* has states that are difficult to create or reproduce (e.g., a network error);
* is slow (e.g., a complete database, which would have to be initialized before the test);
* does not yet exist or may change behavior;
* would have to include information and methods exclusively for testing purposes (and not for its actual task).

For example, an alarm clock program which causes a bell to ring at a certain time might get the current time from the outside world. To test this, the test must wait until the alarm time to know whether it has rung the bell correctly. If a mock object is used in place of the real object, it can be programmed to provide the bell-ringing time (whether it is actually that time or not) so that the alarm clock program can be tested in isolation. 

---

One thing that I like to add to that list is when an object's behavior depends on the behavior or state of an external object. In our controller, we have the following event-binding:

~~~~ ruby
  rmq(@play_stop).on(:tap) do
    if @player.playbackState == MPMoviePlaybackStatePlaying
      stopPlayer
    else
      startPlayer
    end
  end
~~~~

As you can see, the functionality in the callback of the tap function depends almost entirely on the behavior and state of our @player, and will call a helper function depending on the results of that. I like to write small, concise unit tests and don't want to worry about the side-effects of actually calling these helper methods. So, we are going to mock them in our tests. 

#### Enter Motion-Facon

[Motion-Facon](https://github.com/svyatogor/motion-facon) "is a port of Facon mocking library to RubyMotion platform. It brings mocking functionality to Bacon which is the default (and only?) test framework for rubymotion."

It has a very simple API and makes our unit tests really easy to maintain. Follow the usual steps of adding it to your GemFile and Rakefile and let's see how we'll incorporate it into our test.

~~~~ ruby
  it "should call stopPlayer when audio is playing" do
    controller.should.receive(:stopPlayer)

    @player = controller.instance_variable_get("@player")
    @player.play
    tap @play_stop_button
  end
~~~~

First, we use Facon to mock the stopPlayer method on our controller. This method changes the play/stop button's title and stops playing audio. We don't want to actually do this, we just want to make sure it's being called when we expect it to be. So, we start the @player and tap the play_stop_button in the test and the test passes! We'll do a similar thing for the alternative state:

~~~~ ruby
  it "should call startPlayer when audio is stopped" do
    controller.should.receive(:startPlayer)

    @player = controller.instance_variable_get("@player")
    @player.stop
    tap @play_stop_button
  end
~~~~

I'm going to wrap up the rest of the tests on my end, but feel free to checkout the branch on GitHub if you're curious about how I go about testing particular things.

From now on, I will be trying to maintain a Test-Driven approach to implementing new features in the app in the interest of giving myself a little practice and maintaining some confidence in the functionality of PodStudio. I haven't decided exactly how much of that will find its way into the posts, but at the very least I will point out any *interesting* test cases I happen to bump into. 
