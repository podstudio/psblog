---
title: Adventures in Angular - Testing Directives and Their Templates 
date: 2014-02-23 14:28 UTC
tags: Angular
category: Angular
---

As you start to build more and more complex AngularJS applications, you will almost certainly find more of your time being spent building out Services and Directives rather than shoving all your logic into the controllers and views. This helps us isolate our code and, in some cases, build components that are much more easily reused.

We've seen how easy it can be to unit test our controllers, but testing our directives can be a little more involved. The vast majority of directives I build necessitate both unit tests to assert our internal functions behave according to our needs, and functional tests to be confident that our templates are being rendered correctly per the state of the directive's scope.

Let's say we have a (very) simple 'author form' directive that we instantiate like this:

~~~~ ruby
  <div author-form></div>
~~~~

and define the directive as:

~~~~ ruby
  app.directive("authorForm", function(AuthorItem) {
    return {
      scope: {},
      templateUrl: "/templates/author-form.html",
      link: function(scope, element, attrs) {
      }
    }
  })
~~~~

In its current state, this directive will simply replace its element with the contents of the `author-form.html` template, which could be something like:

~~~~ ruby
  <form ng-submit="submit()">
    <input type="text" ng-model="name">
    <input type="text" ng-model="email">
    <button type="submit"></button>
  </form>
~~~~

For now, it's just a form which will update the `name` and `email` attributes on our directive's isolate scope. When it's submitted, it will call the directive's `submit` function. Let's add that to our linking function.

~~~~ ruby
  app.directive("authorForm", function(AuthorItem) {
    return {
      scope: {},
      templateUrl: "/templates/author-form.html",
      link: function(scope, element, attrs) {
        scope.submit = function() {
          AuthorItem.save({name: scope.name, email: scope.email}, function(response) {
            // do something with the response.
          })
        }
      }
    }
  })
~~~~

AuthorItem is just a normal ngResource Service that we can use to create a new Author Item:

~~~~ ruby
  app.factory("AuthorItem", function($resource) {
    return $resource("/authors/:id.json", {id: '@id'});
  })
~~~~

### Our first test

Now is a good time to get started on our tests for this directive. Even though it's a pretty simple form and scope method, we want to make sure a couple things happen according to our plan.

- When this directive is instantiated, it correctly fetches the appropriate template and appends the contents of the template to its own html.
- The form fields are bound to the correct attributes on our scope
- Submitting the form will call the `submit` function in our directive

So, to do this we want to create a new spec and start it off like so:

~~~~ ruby
  describe("Directives", function() {
    var element, $scope, httpBackend, compile, dScope;
    beforeEach(module('app'));

    beforeEach(inject(function($compile, $rootScope, $httpBackend) {
      $scope = $rootScope;
      compile = $compile;
      httpBackend = $httpBackend;
    }))

    describe("authorForm", function() {
      beforeEach(function() {
        template = __html__['/templates/author-form.html'],

        httpBackend.whenGET('/templates/author-form.html').respond(200, template);
        element = angular.element("<div author-form></div>");

        compile(element)($scope);

        dScope = element.scope();

        $scope.$apply();
        httpBackend.flush();
      })

     
    })

  })

~~~~

This is a good starting point that I use whenevr I want to begin testing a new directive of mine. Feel free to add or remove anything as you see fit. Let's take a look at this step by step.

~~~~ ruby
  var element, $scope, httpBackend, compile, dScope;
  beforeEach(module('app'));

  beforeEach(inject(function($compile, $rootScope, $httpBackend) {
    $scope = $rootScope;
    compile = $compile;
    httpBackend = $httpBackend;
  }))
~~~~

Here, I am just setting up variables that I am going to want to reference in various parts of our tests. Compile is going to be very important for when we want to inject our directive's scope into the template that we fetch during our spec. the $httpBackend service is important so that we can mock our external http resources.

~~~~ ruby
  template = __html__['/templates/author-form.html']
~~~~ 

This is an important and interesting part of the test. When we include html templates in our Jasmine or Karma configuration, the test suite creates a global `__html__` hash which will act as a cache for all of our templates. In order to get the html representation of any of our templates, we simply access it by name like above. In this case, it will return a string:

~~~~ ruby
  "<form ng-submit="submit()"><input type="text" ng-model="name"><input type="text" ng-model="email"><button type="submit"></button></form>"
~~~~

~~~~ ruby
  httpBackend.whenGET('/templates/author-form.html').respond(200, template);
~~~~

When we instantiate our directive, it is going to make a call to `/templates/author-form.html'. But, in the case of my test suite and application configuration this request fails. (My Angular app is found within a larger Rails applicaiton. So, the test suite runs into some issues retrieving templates correctly due to differences in asset paths).

So, we tell our httpBackend mock service to respond with the string representation of our template when it is requested.

~~~~ ruby
  element = angular.element("<div author-form></div>");
~~~~

Then we create an angular element for use only within this test suite. We simply pass in a string representation of the markup needed to create our directive. It should be identical to the markup we would use outside of our tests.

Now, we have an element and the template that will populate it. But, we need to manually inject our scope into this directive by way of the compile method. This will take the scope and template we provide and bind them together.

~~~~ ruby
  compile(element)($scope);
~~~~

Now, we can easily reference our `element` variable throughout our tests to make assertions on the state of our template!

To help us have access to the internal scope of our element, I like to do the following as well:

~~~~ ruby
  dScope = element.scope();
~~~~

Finally, we need to tell the httpBackend to `flush`. According to the [docs](http://docs.angularjs.org/api/ngMock/service/$httpBackend):

> The $httpBackend used in production always responds to requests with responses asynchronously. If we preserved this behavior in unit testing we'd have to create async unit tests, which are hard to write, understand, and maintain. However, the testing mock can't respond synchronously because that would change the execution of the code under test. For this reason the mock $httpBackend has a flush() method, which allows the test to explicitly flush pending requests and thus preserve the async api of the backend while allowing the test to execute synchronously.

Now we're ready to write a couple tests.

~~~~ ruby
  describe("template is loaded properly", function() {
    it("should have a form present", function() {
      expect(element.find('form').length).toBe(1);
    })
  })

  describe("input fields", function() {
    describe("name field", function() {
      it("should be bound to the scope's attribute", function() {
        dScope.name = "Fake Name";
        dScope.$apply();
        expect(element.find('input')[0].value).toBe("Fake Name")
      })
    })

    describe("email field", function() {
      it("should be bound to the scope's attribute", function() {
        dScope.email = "fake@aol.com";
        dScope.$apply();
        expect(element.find('input')[1].value).toBe("fake@aol.com")
      })
    })
  })

  describe('form submit function', function() {
    it('should call the scopes submit function when submitted', function() {
      spyOn(dScope, 'submit');
      form = element.find('form');
      form.submit();
      expect(dScope.submit).toHaveBeenCalled();
    })
  })
~~~~

This is a pretty good start to our tests. We assert that when we update the scope values for name and email, the inputs are also updated. Then we create a `spy` on our scope's submit function and assert that it is called when the form is submitted.

### Form Validation

Let's say we'd like to add some validation to our form. Before we save our new author, we want to make sure both the name and email fields are not blank, so we'll create a new `invalidFields` function and call it before calling `AuthorItem.save`

~~~~ ruby
  app.directive("authorForm", function(AuthorItem) {
    return {
      scope: {},
      templateUrl: "/templates/author-form.html",
      link: function(scope, element, attrs) {
        scope.formValid = function() {
          return angular.isDefined(scope.name) && scope.name.length > 0 angular.isDefined(scope.email) && scope.email.length > 0;
        }

        scope.submit = function() {
          if (scope.formValid()) {
            AuthorItem.save({name: scope.name, email: scope.email}, function(response) {
              // do something with the response.
            })
          }
        }
      }
    }
  })
~~~~

Our formValid function just checks that both the name and email are defined on the scope and that they both have some text entered for them. Of course this is not how you would want to implement form validation in your application but it will suffice for the needs of this article. Unit tests for this function should be pretty straight forward:

~~~~ ruby
  describe('scope.formValid', function() {
    it('should be false if both fields are undefined', function() {
      dScope.name = undefined;
      dScope.email = undefined;
      dScope.$apply();

      expect(dScope.formValid()).toBe(false);
    })

    it('should be false if both fields are empty', function() {
      dScope.name = "";
      dScope.email = "";
      dScope.$apply();

      expect(dScope.formValid()).toBe(false);
    })

    it('should be false if one field is undefined', function() {
      dScope.name = "fake name";
      dScope.email = undefined;
      dScope.$apply();

      expect(dScope.formValid()).toBe(false);
    })

    it('should be false if one field is empty', function() {
      dScope.name = "fake name";
      dScope.email = "";
      dScope.$apply();

      expect(dScope.formValid()).toBe(false);
    })

    it('should be true if both fields are not empty', function() {
      dScope.name = "fake name";
      dScope.email = "fake@aol.com";
      dScope.$apply();

      expect(dScope.formValid()).toBe(true);
    })
  })
~~~~

We can assert that our `submit` function checks if our form is valid before proceeding.

~~~~ ruby
  describe('scope.submit', function() {
    it('should check that the form is valid first', function() {
      spyOn(dScope, 'formValid');
      dScope.submit();
      expect(dScope.formValid).toHaveBeenCalled();
    })
  })
~~~~

Cool!

Now, we'd like to display something to the user when the form is invalid. So, when the formValid method fails in our `submit` function we want to set a message on the scope.

~~~~ ruby
  scope.submit = function() {
    if (scope.formValid()) {
      scope.message = undefined;
      AuthorItem.save({name: scope.name, email: scope.email}, function(response) {
        // do something with the response.
      })
    } else {
      scope.message = "Please make sure you enter both your name and email address."
    }
  }
~~~~

We can test this just as easily as before. One addition will be telling our `spy` on formValid what to return.

~~~~ ruby
  describe('scope.submit', function() {
    it('should set a message if form is not valid', function() {
      spyOn(dScope, 'formValid').and_return(false);
      dScope.submit();
      expect(dScope.message).toBe("Please make sure you enter both your name and email address.")
    })

    it('should unset the message if form is valid', function() {
      dScope.message = "some message";
      spyOn(dScope, 'formValid').and_return(true);
      dScope.submit();
      expect(dScope.message).toBeUndefined();
    })
  })
~~~~

Notice the `and_return` calls on our spies? We could have manually set the name and email on our scope, which would implicitly make `formValid` return true. But, if that function were to grow in scope or complexity, so would our tests. We don't care what actually needs to happen for that method to return true or false. We simply want to know how our `submit` function will behave according to the different responses from `formValid`.

### Updating our View

Now, we'd like to display this message in our view. So, go ahead and add it above the form. 

~~~~ html
  <h3 ng-if="message" class="message">{{message}}</h3>
  <form ng-submit="submit()">
    <input type="text" ng-model="name">
    <input type="text" ng-model="email">
    <button type="submit"></button>
  </form>
~~~~

Now we can test that this view is updated correctly when our form is validated.

~~~~ ruby
  describe("message text", function() {
    it('should display a message in the view when present', function() {
      dScope.message = "Test Message";
      dScope.$apply();
      expect(element.find('.message').length).toBe(1)
      expect(element.find('.message').innerHTML).toBe("Test Message");
    })

    it('should not display a message if it is undefined on the scope', function() {
      dScope.message = undefined;
      dScope.$apply();
      expect(element.find('.message').length).toBe(0);
    })
  })
~~~~

### Wrapping Up

We've successfully created a new directive in our Angular app and explored how we can implement both unit tests and functional tests for its resulting template and scope. By breaking each function into its smallest parts and testing each part accordingly, we give ourselves much more confidence in our directive and the UI that we present to our user. When we inevitably want to beef up our form validation, we won't have to rewrite EVERYTHING just to conform to whatever api it provides. As long as it returns a true or false value for that `formValid` method, the rest of our tests (and more importantly, our application!) should remain in tact.

