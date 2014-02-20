---
title: Building podstud.io in RubyMotion - Part 7
date: 2014-02-20 01:50 UTC
tags: Rubymotion
category: RubyMotion
---

In this article we're going to do a little bit of a context switch and start implementing some of the app functionality that will eventually lead back into our audio playing UI. We should remember at this point that we are supposed to be building a podcast management app, not just an audio player! So, the functionality we are going to focus on today is the ability to search for a particular podcast we would like to listen to and prepare an episode to listen to.

### Search Controller

The first thing we want to do is create a new controller to house our Podcast Search functionality. Let's use another handy RMQ command to get us started.

~~~~ ruby
  rmq create table_view_controller search
~~~~

This gives us a nice simple `search_controller.rb` file that we can work with. It has all the boilerplate tableView stuff (I go into more detail on this topic earlier in the series). 

Now we must tell our `AppDelegate` to send us to this controller instead of our Player Controller:

~~~~ ruby
  search_controller = SearchController.new
  @window.rootViewController = UINavigationController.alloc.initWithRootViewController(search_controller)
~~~~

Let's see what RMQ created for us.
![](/blog/2014-02-20-building-podstudio-in-rubymotion-part-7/1.png)

Wow! That's alot of time saved right off the bat. Now, we want to add one of those search bars we are so used to seeing in iOS 7 apps. Once that search bar is in place, we will use it to conduct our search and update the tableview with the results.

### UISearchBar + Delegate

Our SearchController inherits from UITableViewController so we already have a reference to its tableView by calling `self.tableView`. What we need to do now is instantiate a `UISearchBar` and set it as the tableView's `tableHeaderView'. We can actually set this to any view we want, but we're trying to implement some search functionality so we'll use a UISearchBar

In `viewDidLoad`:

~~~~ ruby
  @searchBar = UISearchBar.alloc.initWithFrame(CGRectMake(0, 0, self.tableView.frame.size.width, 0))
  @searchBar.delegate = self
  @searchBar.sizeToFit
  self.tableView.tableHeaderView = @searchBar
~~~~

First we instantiate a new UISearchBar class with a frame to fill the width of the screen. We then set its delegate to the SearchController so we can hook into its search events in the next few steps. Then we set it as the tableView's Header View. Let's see how that looks:

![](/blog/2014-02-20-building-podstudio-in-rubymotion-part-7/2.png)

Cool! We get a nice looking and functional search bar right out of the box. Now, when the user enters some text into the search bar and hits the big `Search` button, we want to know about it. So, we'll take advantage of one of the delegate methods that we signed up for in the last step. To see the list of methods available to us, check the docs for the [UISearchBarDelegate](https://developer.apple.com/library/ios/documentation/uikit/reference/UISearchBarDelegate_Protocol/Reference/Reference.html)

We're going to see what happens during that `searchBarSearchButtonClicked:` method.

~~~~ ruby
  def searchBarSearchButtonClicked(searchBar)
    ap @searchBar.text
  end
~~~~

Simple enough, once that button is clicked we want to log the current text value of the Search Bar field. If you are having issues seeing the output in your logs, make sure you have correctly set the search bar's delegate to `self` above. Now that we have the user's intended search term, we want to find all the podcasts that match it. 

### iTunes API

iTunes provides us with a really great API for searching its store. The docs are lengthy and can be found [here](https://www.apple.com/itunes/affiliates/resources/documentation/itunes-store-web-service-search-api.html#searching). However, we are only interested in a very particular type of search: Podcasts that match a certain title. So, the URL we'll use is simply "https://itunes.apple.com/search?term={Search Term}&media=podcast".

Simple enough, but how can we do that? Oh yea, we have `AFMotion`! This library allows us to make one-off GET or POST requests very easily. If we were going to be making a ton of requests to the same API or needed to maintain a session of some sort, we would move this code out of the controller and into its own model. But for now, we can just place it in our search bar's delegate method.

~~~~ ruby
  def searchBarSearchButtonClicked(searchBar)
    AFMotion::JSON.get("https://itunes.apple.com/search", {term: @searchBar.text, media: "podcast"}) do |response|
      ap response.object[:results]
    end
  end
~~~~

It's important to note that we don't want to construct the url + query string by hand (such as appending the ?media=podcast&term=blahblah). We set the base url and pass in a hash of the options we'd like to send with the request. Once this request returns successfully, we can see the output in our logs:

![](/blog/2014-02-20-building-podstudio-in-rubymotion-part-7/3.png)

Nice! Now we can take these results and use them to populate our tableView. 
