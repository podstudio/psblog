---
title: Adventures in Angular - Test Factories with Rosie 
date: 2014-02-21 14:17 UTC
tags: Angular
category: Angular
---

Over the past few years as a front end engineer, I've seen the scope of my client-side applications grow almost exponentially. And, as is the case with any sufficiently complex project, things tend to get away from you. The more features you add, bugs you fix or external dependencies you add, the more impossible it becomes to keep the entire project in your head. This is where adequate testing can really help out. When I need to refactor some of my code in service of new functionality, I want to be absolutely positive that I'm not breaking anything or causing any regressions.

Alot of the applications I build these days rely heavily on a REST-ful API of some sort. In Angular in particular, it's very common to create a resource that fetches data from a remote server like so:

~~~~ ruby
  app.factory("AuthorItem", function($resource) {
    return $resource("/sauthors/:id", {id: '@id'}, {'update': {method: 'PUT'}});
  })
~~~~

This is a pretty straightforward Angular resource...we can fetch a list of authors, get an author, update an author etc. Our application will respond accordingly, whether it's displaying the response in the correct format in the UI or calling another function that acts upon our new objects. When we test these interactions, it is important to isolate ourselves from the outside world. We don't want our specs actually making all these calls to the API just so we can test our application's functionality.

For example, let's say we have a function in our controller:

~~~~ ruby
  $scope.fetchAuthors = function() {
    AuthorItem.query(function(response) {
      $scope.message = response.length + " authors found!"
    }, function(error) {
      $scope.message = "Error retrieving authors!";
    })
  }
~~~~

This is a simple function that will call the `query` method on our `AuthorItem` resource and set a message on the scope according to the size of the response. Now, of course we don't want to actually hit our API every time our tests run (which should be *very very often*).

So, we want to mock this response. AngularJS comes with a really great way to do this. 

### $httpBackend service in ngMock

From the docs:

> Fake HTTP backend implementation suitable for unit testing applications that use the $http service.

> Note: For fake HTTP backend implementation suitable for end-to-end testing or backend-less development please see e2e $httpBackend mock.

> During unit testing, we want our unit tests to run quickly and have no external dependencies so we don’t want to send XHR or JSONP requests to a real server. All we really need is to verify whether a certain request has been sent or not, or alternatively just let the application make requests, respond with pre-trained responses and assert that the end result is what we expect it to be.

> This mock implementation can be used to respond with static or dynamic responses via the expect and when apis and their shortcuts (expectGET, whenPOST, etc).

> When an Angular application needs some data from a server, it calls the $http service, which sends the request to a real server using $httpBackend service. With dependency injection, it is easy to inject $httpBackend mock (which has the same API as $httpBackend) and use it to verify the requests and respond with some testing data without sending a request to real server.

> There are two ways to specify what test data should be returned as http responses by the mock backend when the code under test makes http requests:

> $httpBackend.expect - specifies a request expectation
> $httpBackend.when - specifies a backend definition

So, all we really need to do in our specs is tell our $httpBackend mock to expect a call to a particular URL and explicitly define how it should respond.

~~~~ ruby
  var response = [
    {name: "first author", post_count: 1234, address: "1234 Angular Lane"},
    {name: "second author", post_count: 5, address: "1 Google Way"},
    {name: "third author", post_count: 23, address: "24 Facebook Court"},
    {name: "fourth author", post_count: 18, address: "114 Twitter Drive"}
  ]

  $httpBackend.whenGET('/authors').respond(200, response)
~~~~

So, whenever our test actually makes the call to `/authors` our mock will intercept it and respond with the corresponding array. We can just as easily have our mock respond with an error:

~~~~ ruby
  $httpBackend.whenGET('/authors').respond(500)
~~~~

Now, we can create some tests to make sure this function works as we expect. I'm not going to include the whole structure of my spec file, just the individual test for now:

~~~~ ruby

  describe('fetchAuthors', function(httpBackend) {
    var httpBackend;
    beforeEach(inject(function($httpBackend) {
      httpBackend = $httpBackend;
    }))

    it("should set the message correctly when there are no authors")

    it("should set the message correctly when there are authors")

    it("should set the message correctly when there is an error")
  })

~~~~

For each of these `it` specs, we will specify a different response for our $httpBackend and assert that the message is as we expect on the scope.

~~~~ ruby
  it('should set the message correctly when there are no authors', function() {
    httpBackend.whenGET('/authors').respond(200, [])
    expect($scope.message).toBe('0 authors found!')
  })

  it('should set the message correctly when there are authors', function() {
    var response = [
      {name: "first author", post_count: 1234, address: "1234 Angular Lane"},
      {name: "second author", post_count: 5, address: "1 Google Way"},
      {name: "third author", post_count: 23, address: "24 Facebook Court"},
      {name: "fourth author", post_count: 18, address: "114 Twitter Drive"}
    ]

    httpBackend.whenGET('/authors').respond(200, response)
    expect($scope.message).toBe('4 authors found!')
  })

  it('should set the message correctly when there are no authors', function() {
    httpBackend.whenGET('/authors').respond(500)
    expect($scope.message).toBe('Error retrieving authors!')
  })
~~~~

Pretty nice! Although, I'm getting kind of sick of writing all those author objects each time I want to include them in a response. What if the model schema changes? What if I want to create them dynamically or set certain attributes to a random value? 

### Enter Rosie.js

![](/blog/2014-02-21-angular-rosie/rosie.jpeg)

> Rosie is a factory for building JavaScript objects, mostly useful for setting up test data. It is inspired by [factory_girl](https://github.com/thoughtbot/factory_girl).

Ok...so what's Factory Girl?

> factory_girl is a fixtures replacement with a straightforward definition syntax, support for multiple build strategies (saved instances, unsaved instances, attribute hashes, and stubbed objects), and support for multiple factories for the same class (user, admin_user, and so on), including factory inheritance.

Basically, we want to define a `Factory` that will describe the objects we are trying to use in our tests. By including [rosie.js](https://github.com/bkeepers/rosie/blob/master/src/rosie.js) in our application we have access to its powerful api. I have a separate file called `factories.js` where we can define the following:

~~~~ javascript
  Factory.define('author')
    .attr('name', 'Fake Name 1')
    .attr('post_count', 1234)
    .attr('address', '1234 fake street')
~~~~

Once we have a factory defined, we can `build` it in our tests:

~~~~ javascript
  var response = [Factory.build(author), Factory.build(author)];
~~~~

and it will automatically instantiate the objects and set them in response array.

Rosie can do much more than simply define static attributes. If we want an auto-incrementing `id` field on our Author model, we can simply add:

~~~~ javascript
  Factory.define('author')
    .sequence('id')
~~~~

Which will automatically create a unique ID for each author factory we build.

The attribute method also takes a function as a second parameter, so if we set:

~~~~ javascript
  Factory.define('author')
    .attr('created_at', function() { return new Date(); })
~~~~

or 

~~~~ javascript
  Factory.define('author')
    .attr('random_number', function() { return Math.random(); })
~~~~

We can even create implicit relationships to other factories in our builder like so:

~~~~ javascript
  Factory.define('post')
    .sequence('id')
    .attr('title', 'Fake Title')

  Factory.define('author')
    .sequence('id')
    .attr('posts', function() {
      return [
        Factory.attributes('post'),
        Factory.attributes('post')
      ];
    });
~~~~

### Updating our Specs

Now that we have the powerful factories in place, we can clean up some of our tests

~~~~ javascript
  it('should set the message correctly when there are authors', function() {
    var response = [
      Factory.build('author'),
      Factory.build('author'),
      Factory.build('author'),
      Factory.build('author')
    ]

    httpBackend.whenGET('/authors').respond(200, response)
    expect($scope.message).toBe('4 authors found!')
  })
~~~~

But, we don't necessarily want them all the have the same names and addresses. With Rosie.js we can easily override any attributes we want, or even **add** new attributes not defined in the factory.

~~~~ javascript
  it('should set the message correctly when there are authors', function() {
    var response = [
      Factory.build('author', {name: "Nader Hendawi"}),
      Factory.build('author', {address: "1600 Pennsylvania Avenue"}),
      Factory.build('author', {isAdmin: true}),
      Factory.build('author', {posts: []})
    ]

    httpBackend.whenGET('/authors').respond(200, response)
    expect($scope.message).toBe('4 authors found!')
  })
~~~~

Now, when we write new functionality for our application and need to be confident that we react correctly to all variations of external requests we can simply update our factories and create a new spec for any new edge cases.

It should be mentioned that this doesnt actually test our external API's at all! That honor falls on the unit and integration tests for the API itself. We simply want to make sure that, given a particular set of expected responses from the API, we update our state and UI correctly and Rosie.JS makes that a whole lot easier.
