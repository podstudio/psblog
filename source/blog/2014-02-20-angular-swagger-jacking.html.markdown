---
title: Adventures in Angular - Swagger Jacking 
date: 2014-02-20 23:48 UTC
tags: Angular
category: Angular
---

Earlier this year, [Backupify](http://www.backupify.com) released its [Developer Platform API](https://www.backupify.com/partners/api-documentation) which allows our customers to do some really itneresting things with our backup platform. Of course, after developing the API itself we were faced with the need to provide its users with a thorough and accurate documentation. We started off with a static site that delineates the different resources and endpoints our API had to offer. Each endpoint would have a list of attributes it expected and the different responses it could be expected to return. I would say that ~90% of our customers are happy with this level of documentation as they are most likely familiar with the ins and outs of authenticating and making requests against an API. But for those remaining 10%, we needed to up the ante a little bit. 

## Enter Swagger UI

> "[Swagger](https://helloreverb.com/developers/swagger) is a specification and complete framework implementation for describing, producing, consuming, and visualizing RESTful web services."

Swagger allows us to create a spec for every endpoint in our API and it will automatically generate a client-side app to describe, and more importantly **test** each call. For example, if you visit their [demo app](http://swagger.wordnik.com/#!/pet/getPetById_get_0) and enter a `petId`..click the button that says "Try it out!".

![](/blog/2014-02-20-angular-swagger-jacking/1.png)

That's pretty nice! We can easily see the request URL, it's response and any response headers we receive. We immediately began updating our API spec to be Swagger-compatible but due to some security implications we were tasked with rolling our own solution that would live behind a login screen. We wanted to emulate the Swagger UI as much as possible, but with the flexibility to customize the whole process to our unique authentication scheme and domain model. Plus, as a Front End Engineer I like having complete control over the look and feel of my apps without having to monkey-patch css files all day.

## Enter AngularJS

It turns out, for all that Swagger does, it's really a rather simple workflow. For each API Endpoint we want to:

- Provide the URL for the endpoint (such as **/authors**)
- List all the required and optional URL parameters and Query String Parameters (such as **/authors/{{authorName}}/posts?tag=angular**)
- Create a form to bind user input to attributes in the URL
- Generate and execute a request which includes the user-provided values to the correct endpoint
- Display the response code and body for the above request

If we satisfy all of the above bullets, we have a pretty solid way to test out different API calls for a given user. So, if we get a ticket saying a user is unable to successfully make a particular API request all we have to do is plug in their user info (in our case: OAuth2 credentials) and try it out in our new UI.

I started using AngularJS a little over a year ago and its effect on my development life has been invaluable. So, once we started on this project Angular was a natural and seamless fit. I'm going to give a little overview on how to get started building your own Swagger-esque Directive that is completely customizable and extendable. Here's a glimpse of the final product:

![](/blog/2014-02-20-angular-swagger-jacking/2.png)

### API Endpoint List

We want to create a new element-level directive that will take in all of the configuration needed to build our API Endpoint UI.

Let's name it something like `apiEndpoint`:

~~~~ ruby
  app.directive("apiEndpoint", function($http, $interpolate, $rootScope, ApiUrl) {
    return {
      scope: {},
      link: function(scope, element, attrs) {
        
      }
    }
  })
~~~~

We can instantiate this in our UI by creating an element with the correct attribute:

~~~~ ruby
  <div api-endpoint></div>
~~~~

This is the simplest implementation of an Angular directive. Now let's muddy it up. What kinds of things did we say we needed to display? Endpoint URL, a title, and the method. We can pass these attribtues into our directive's scope by adding the following to our markup:

~~~~ ruby
  <div api-endpoint method="GET" url="'/authors/{{author}}/posts'" title="List Posts"></div>
~~~~

and updating our directive to set these attributes on its own `isolate scope`:

~~~~ ruby
  app.directive("apiEndpoint", function() {
    return {
      scope: {
        title: "@",
        method: "@",
        url: "="
      },
      link: function(scope, element, attrs) {
        
      }
    }
  })
~~~~

For the title and method attributes we don't need to take advantage of Angular's two-way binding. We just need to define it once and display it as-is in our directive template. But, the URL is dynamic and will be bound to user input, so we must set it use two-way binding via the "=" value for its scope.

Now, we need to create a template that will be populated by our directive.

~~~~ ruby
  app.directive("apiEndpoint", function($http, $interpolate, $rootScope, ApiUrl) {
    return {
      scope: {
        title: "@",
        method: "@",
        url: "="
      },
      templateUrl: '/templates/api_endpoint.html',
      link: function(scope, element, attrs) {
        
      }
    }
  })
~~~~

Which looks a little something like: 

~~~~ ruby
  <div class="accordion-group">
    <div class="accordion-heading">
      <a class="accordion-toggle" data-toggle="collapse" href="#collapse-{{$id}}">{{title}}</a>
    </div>
    <div id="collapse-{{$id}}" class="accordion-body collapse">
      <div class="accordion-inner">
        <!-- our form will go here -->
      </div>
    </div>
  </div>
~~~~

This is a very barebones template which we will build upon. For now, it simply displays the title that we have passed into our directive. But, we have those URL parameters that necessitate the user's input. So, we're going to take advantage of Angular's awesome `transclusion' principle where we can set a whole block of markup that will be placed inline and compiled within our directive. So, if we update our markup which instantiates our api-endpoint with something like this:

~~~~ ruby
  <div api-endpoint method="GET" url="'/authors/{{author}}/posts'" title="List Posts">
    <label>Author Name:</label>
    <input type="text" ng-model="$$prevSibling.author">
  </div>
~~~~

and telling our directive to allow transclusion:

~~~~ ruby
  app.directive("apiEndpoint", function() {
    return {
      scope: {
        title: "@",
        method: "@",
        url: "="
      },
      transclude: true,
      templateUrl: '/templates/api_endpoint.html',
      link: function(scope, element, attrs) {

      }
    }
  })
~~~~

and finally displaying it in our api_endpoint template:

~~~~ ruby
  <div class="accordion-group">
    <div class="accordion-heading">
      <a class="accordion-toggle" data-toggle="collapse" href="#collapse-{{$id}}">{{title}}</a>
    </div>
    <div id="collapse-{{$id}}" class="accordion-body collapse">
      <div class="accordion-inner">
        <form>
          <div ng-transclude></div>
        </form>
      </div>
    </div>
  </div>
~~~~

Now, we should be displaying our author field and its value will be propagated to our directive's scope. Once a user fills in a value for this field, we can easily access it within our directive by calling `$scope.author`. Nice!

### Testing our API Call

Now that we have our input available in scope, we can use them to generate the request URL for our API Endpoint. We have two disparate components that we somehow need to combine to create a meaningful URL. The url attribute passed into the directive upon instantiation is a simple string `'/authors/{{author}}/posts'` and our scope has an attribute named `author` that we'd like to use in place of the `{{author}}` component of our URL.

The way I do this is by utilizing Angular's very hadny [$interpolate Provider](http://docs.angularjs.org/api/ng/service/$interpolate).

> **$interpolate** Compiles a string with markup into an interpolation function. This service is used by the HTML $compile service for data binding. See $interpolateProvider for configuring the interpolation markup.

Angular is already really good at interpolating scope values into templates which include those fancy `{{}}`'s. All this $interpolate function will do is take our URL string and make it ready to be injected with scope attributes (exactly the same way a controller's scope is used in normal Angular views). So how do we do it manually? First, we need to inject the $interpolate provider into our directive.

~~~~ ruby
  app.directive("apiEndpoint", function($interpolate) {
    return {
      scope: {
        title: "@",
        method: "@",
        url: "="
      },
      transclude: true,
      templateUrl: '/templates/api_endpoint.html',
      link: function(scope, element, attrs) {

      }
    }
  })
~~~~

Then, we create our `generateUrl()` function which will do the heavy lifting.

~~~~ ruby
  scope.generateUrl = function() {
    var interpolated_url = $interpolate(scope.url);
    return scope.$eval(interpolated_url);
  }
~~~~

Once we have our URL string correctly interpolated, we use `scope.$eval`:

> **$eval**: Executes the expression on the current scope and returns the result. Any exceptions in the expression are propagated (uncaught). This is useful when evaluating Angular expressions.

So, as long as we have `author` defined on our scope, it's as easy as calling `scope.generateUrl()` to get our desired API Endpoint URL: `/authors/nader/posts`. Awesome!

## Try it out!

The last thing I'd like to touch on is adding the ability to test out our API call directly from our home-grown Swagger UI. Let's add a button to call our new `testCall()` function.

~~~~ ruby
  <div class="accordion-group">
    <div class="accordion-heading">
      <a class="accordion-toggle" data-toggle="collapse" href="#collapse-{{$id}}">{{title}}</a>
    </div>
    <div id="collapse-{{$id}}" class="accordion-body collapse">
      <div class="accordion-inner">
        <form>
          <div ng-transclude></div>
          <button type="submit" ng-click="testCall()">Try it out!</button>
        </form>
      </div>
    </div>
  </div>
~~~~

This method is actually pretty easy. We just need to inject the `$http` provider into our directive and make the call, being to use the correct scope attribtues where needed:

~~~~ ruby
  scope.testCall = function() {
    var promise = $http({
      method: scope.method,
      url: scope.generatedUrl()
    }).then(function(response) {
      return response;
    }, function(error) {
      return error;
    });

    scope.response = promise;
  }
~~~~

You can see that we are using the `scope.method` which we passed in from our view and the `generatedUrl()` which is the interpolated URL for our endpoint. It would be just as easy to add any authorization headers or query string parameters the exact same way!

Once the request resolves, we set the response and the scope and can simply display that in the template:

~~~~ ruby
  <pre ng-if="response">{{response}}</pre>
~~~~

### Wrapping Up

There are alot of other aspects to making our app work and feel as great as Swagger UI, but this article should definitely get you on your way. By utilizing the wide variety of incredibly helpful Angular concepts such as interpolation, transclusion and dependency injection we were able to implement a really impressive proof of concept in relatively few lines of code. 
