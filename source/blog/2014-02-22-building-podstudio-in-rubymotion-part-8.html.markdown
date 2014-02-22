---
title: Building podstud.io in RubyMotion - Part 8
date: 2014-02-22 15:53 UTC
tags: Rubymotion
category: RubyMotion
---

In this article, we're going to take our app one step further and start storing information based on our user's decisions that will persist between sessions. To do this, we will use the [Core Data Framework](https://developer.apple.com/library/ios/documentation/cocoa/Reference/CoreData_ObjC/_index.html) provided by default in iOS.

### Core Data

Core Data is described by Apple as a 'schema-driven object graph management and persistence framework'. Basically, this means that the framework will hand the intricacies of storing our data, the method by which to store that data and any memory management implications that might arise.

If you're used to building applications in Ruby on Rails, this will be pretty straightforward. Where we have tables in Rails, we have `entities` or `managed objects` in Core Data. In both Rails and Core Data, our models (or managed objects) will have a particular set of attributes that map to columns in their respective tables. I'm going to save the rest of the explanation and touch upon certain topics as we get to them.

To make dealing with the Core Data Framework, the guys at [InfiniteRed](http://infinitered.com/) have provided us with another great RubyMotion Gem: [CDQ](https://github.com/infinitered/cdq) for CoreDataQuery

### CDQ

> Core Data Query (CDQ) is a library to help you manage your Core Data stack while using RubyMotion. It uses a data model file, which you can generate in XCode, or you can use ruby-xcdm.

> CDQ aims to streamline the process of getting you up and running Core Data, while avoiding too much abstraction or method pollution on top of the SDK. While it borrows many ideas from ActiveRecord (especially AREL), it is designed to harmonize with Core Data's way of doing things first.

So, let's follow the quick start steps:

~~~~ ruby
  # in Gemfile
  gem "cdq"
  bundle install
~~~~

and then run the `cdq init` command which will initialize our schema directory.

We get a little more output from this command which we should make sure to follow:

~~~~ ruby
  Creating init:

  Δ  Creating directory: schemas
  Δ  Creating file: /podstudio-rm/schemas/0001_initial.rb

     Done
  Δ  Checking bundle for cdq... /.rbenv/versions/1.9.3-p194/lib/ruby/gems/1.9.1/gems/cdq-0.1.2
  Δ  Adding schema:build hook to Rakefile... Done.

  Now open app/app_delegate.rb, and add

  include CDQ

  at class level, and

  cdq.setup

  wherever you want the stack to get set up, probably right before you set
  your root controller.  Edit your inital schema, create a few models, and
  you're off and running.
~~~~

We need to update our AppDelegate to the following:

~~~~ ruby
  class AppDelegate
    include CDQ
    attr_reader :window

    def application(application, didFinishLaunchingWithOptions:launchOptions)
      return true if RUBYMOTION_ENV == 'test'
      @window = UIWindow.alloc.initWithFrame(UIScreen.mainScreen.bounds)

      cdq.setup
      
      search_controller = SearchController.new
      @window.rootViewController = UINavigationController.alloc.initWithRootViewController(search_controller)

      @window.styleMode = PXStylingNormal

      @window.makeKeyAndVisible
      true
    end
  end
~~~~

### CDQ Schema / XCDM

CDQ comes bundled with [ruby-xcdm](https://github.com/infinitered/ruby-xcdm) as a dependency. XCDM is a tool for generating the same xcdatamodeld files that XCode creates when designing a datamodel for Core Data. It creates a directory called "schemas" which we saw during our init command and allows us to define our schema in a simple text-based workflow. So, what datamodels are we hoping to store in our application? For now, we just want to know what `podcasts` a user would like to subscribe to. In a normal web app with multiple users, we would most likely use a 'subscriptions' join table to map the relationship between users and podcast entities. But, we only have one user (for now) so we will just have the one table for podcasts. 

To do this, we need to update our `/schemas/0001_initial.rb` file.

The only thing we need to do now is define the name of the entity we would like to persist, and the attributes we'd like to store within that entity.

~~~~ ruby
  
  schema "0001 initial" do

    entity "Podcast" do
      string :name
      integer32 :collection_id
      string :feed_url
      string :thumbnail_url
      string :thumbnail_url_small 
    end
    
  end

~~~~

Pretty simple, for each Podcast we want to store its name, unique collection ID, RSS Feed URL and thumbnail image urls. I'm deciding to store two different thumbnail url's because I know eventually we will want to be displaying an image in our SearchController tableView and we don't want to fetch and render the largest version of the image for every row in the table.

Now that we have that defined we have to actually create our model class. If we run `cdq create model podcast` we should get the following:

~~~~ ruby
  Creating model: podcast

     Using existing directory: app/models
  Δ  Creating file: /Users/nader/Dev/podstudio/podstudio-rm/app/models/podcast.rb
     Using existing directory: spec/models
  Δ  Creating file: /Users/nader/Dev/podstudio/podstudio-rm/spec/models/podcast.rb

     Done
~~~~

There we go! It created a new Podcast model file in our app and an associated spec where we can put our unit tests.

Let's run a `rake` and try out the following commands:

~~~~ ruby
  Podcast.count
  #=> 0

  Podcast.create(name: "test")
  #=> <Podcast: 0xfb44f70> (entity: Podcast; id: 0xfb44fb0 <x-coredata:///Podcast/tC3EC6F8D-E761-4303-855B-67567D8DF7C95> ; data: {
    "collection_id" = nil;
    "feed_url" = nil;
    name = test;
    "thumbnail_url" = nil;
    "thumbnail_url_small" = nil;
})

  Podcast.count
  #=> 1
~~~~

As you can see, it's really to create a new Podcast model with any of the attributes defined in the schema. However, if we close the app and restart it...`Podcast.count` will be back to 0! This is because we haven't actually told CDQ to save our changes. To do this, we call `cdq.save` but we're not going to do that until we have something we actually want to store.

### Creating and Saving a Podcast

Ok, now that we know how to create a new model in our database and retrieve a list of existing models, let's get back to our Search Controller. We have already defined a method in our controller that will print the currently selected podcast when a user clicks on a row in the table. This is where we will create a new Podcast model managed by CDQ and save it to the device. First, we want to confirm with the user that they'd like to save their selection. 

We'll create a UIAlertView with a message containing the currently selected podcast title and have the user confirm. I really like the UI of the popular [SIAlertView library](https://github.com/Sumi-Interactive/SIAlertView) which happens to have a RubyMotion port at [SimpleSI](https://github.com/forrestgrant/simple_si). Follow the Setup and add the following to our `didSelectRowAtIndexPath`:

~~~~ ruby
  def tableView(table_view, didSelectRowAtIndexPath: index_path)
    self.selected_podcast = @data[index_path.row]
    SimpleSI.alert({
      title: "podstud.io",
      message: "Would you like to subscribe to #{self.selected_podcast["collectionName"]}?",
      transition: "drop_down",
      buttons: [
        {title: "Yes!", action: :confirm},
        {title: "Cancel", type: "cancel"}
      ],
      delegate: self
    })
  end
~~~~

**Important Note:** Notice we are setting `self.selected_podcast` instead of a local variable now. We do this because we need to be able to identify which podcast the user has selected when we get to our 'confirm' action. In order for this to work, we need to add an `attr_accessor` to our class:

~~~~ ruby
  class SearchController < UITableViewController
    attr_accessor :selected_podcast
~~~~

Let's take a look at our new alert view:

![](/blog/2014-02-22-building-podstudio-in-rubymotion-part-8/1.png)

That's a nice looking confirm prompt!

Then, we define a `confirm` method to finally create our podcast model and save it to CDQ.

~~~~ ruby
  def confirm
    podcast = self.selected_podcast
    Podcast.create({
                  name: podcast["collectionName"],
                  collection_id: podcast["collectionId"],
                  feed_url: podcast["feedUrl"],
                  thumbnail_url: podcast["artworkUrl600"],
                  thumbnail_url_small: podcast["artworkUrl30"]
                })
    cdq.save
  end
~~~~

And voila! Our Podcast is now being saved to the device and if we restart the app, we can simply run:

~~~~ ruby
  Podcast.array
~~~~

to see the list of currently saved models!

Moving forward, we are going to use our array of current podcast subscriptions to display a collection_view to the user and allow them to view an episode list for each Podcast. We can finally see our app taking form and making strides toward actually managing our Podcast Subscriptions!
