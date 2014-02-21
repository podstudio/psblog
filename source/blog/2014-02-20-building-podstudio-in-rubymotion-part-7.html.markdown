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

### Updating the Table Data

RMQ gave us a little bit of a head start when it comes to populating our table. We already have a `load_data` method which will instantiate the `@data` instance variable on our controller. The `tableView:numberOfRowsInSection` method will use this object to decide how many entries we have in our data array. The more complicated part comes in the `tableView:cellForRowAtIndexPath:` method. 

### CellForRowAtIndexPath

This method will find the item in our @data array corresponding with the tableView's row and create a `SearchCell` object. We update the UI to display whatever text or images we would like to show the user, and return the cell.

We don't need the random items that RMQ has created in load_data anymore, so lets delete that method alltogether and replace `load_data` in our `viewDidLoad` method with:

~~~~ ruby
  def viewDidLoad
    super

    @data = []
    # Other code here etc...
~~~~

We want to start off with an empty array and populate our @data when our iTunes Search Request returns. So let's do that:

~~~~ ruby
  def searchBarSearchButtonClicked(searchBar)
    AFMotion::JSON.get("https://itunes.apple.com/search", {term: @searchBar.text, media: "podcast"}) do |response|
      @data = response.object[:results]
    end
  end
~~~~

Now, if we conduct a search we would expect the table to fill in right? But it doesn't...

### table.reloadData

We need to actually notify our tableView that our data collection has changed! We do that by calling `reloadData` on our tableView. So:

~~~~ ruby
  def searchBarSearchButtonClicked(searchBar)
    AFMotion::JSON.get("https://itunes.apple.com/search", {term: @searchBar.text, media: "podcast"}) do |response|
      @data = response.object[:results]
      self.tableView.reloadData
    end
  end
~~~~

Hm..something seemed to work. The number of rows in the table updated to match our results, but each row is still empty. Oh yea, we had that whole 'cellForRowAtIndexPath' thing going on.

In `tableView:cellForRowAtIndexPath` we are creating a `SearchCell` and updating it with the object at the correct index. What does this update method do? Where is it defined?

### Search Cell

RMQ created a Cell class for us at `app/views/search_cell.rb`. There's our `update` method! Lets throw some logging in there and see what data is being sent to our cell's update call.

~~~~ ruby
  def update(data)
    puts data
    # Update data here
    @name.text = data[:name]
  end
~~~~

![](/blog/2014-02-20-building-podstudio-in-rubymotion-part-7/4.png)

There we go. There's no key for `:name` in our data hash, so we must change a couple things.

~~~~ ruby
  def update(data)
    @name.text = data['collectionName']
  end
~~~~

Now, if we run a rake and enter a search query we should see our table update.

![](/blog/2014-02-20-building-podstudio-in-rubymotion-part-7/5.png)

I want to close that keyboard after our search is complete, so let's do that really quick. To do that, we just have to tell our `searchBar` that its job is done for now:

~~~~ ruby
  def searchBarSearchButtonClicked(searchBar)
    AFMotion::JSON.get("https://itunes.apple.com/search", {term: @searchBar.text, media: "podcast"}) do |response|
      @data = response.object[:results]
      self.tableView.reloadData
      @searchBar.resignFirstResponder
    end
  end
~~~~

### Selecting a Podcast

Now, we want the user to be able to select a podcast so we can go ahead and do whatever else we want with it. Maybe we want to fetch a list of episodes for a particular podcast, add it to our user's subscriptions. For now, let's just hone in on exactly how we can catch the user's input to discern which podcast he chooses. 

All we have to do is implement another delegate method for our tableView. Similar to the previous `cellForRowAtIndexPath` and `numberOfRowsInSection` method, the tableView delegate has a `didSelectRowAtIndexPath` method that gets called whenever a user selects a row in the table.

~~~~ ruby
  def tableView(table_view, didSelectRowAtIndexPath: index_path)
    ap index_path
  end
~~~~

Now, if we select a row we should see that the index_path is correctly displayed in our logs. To fetch the corresponding podcast, we just have to use this as the index in our `@data` array.

~~~~ ruby
  def tableView(table_view, didSelectRowAtIndexPath: index_path)
    data_row = @data[index_path.row]
    ap "User Selected #{data_row["collectionName"]}"
  end
~~~~

We should now be seeing the above log message! In the next part of this series, we're going to make use of the Core Data Framework to store a list of podcasts the current user would like to follow. Core Data is a little convoluted so we are going to use the awesome [CDQ gem](https://github.com/infinitered/cdq) to make things a little more digestable. It should come as no susprise that this library is written by the very same people who gave us RMQ so we're in great hands.
