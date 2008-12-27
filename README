Splam
=====

Splam is a simple spam scoring plugin.  It contains a set of rules that are run on a field
to help you determine the likelihood of that field being spam.  It doesn't do anything
other than give a field a score.  It's up to you to act on that score.

Check out the tests for instructions on how to use: you'll want to integrate this into
your application's workflow.

It's heavily biased towards the spam I've been seeing in the past two or three hours.
This includes lots of crap with
- bbcode [url=
- lots of links (http://)
- russian text
- links to russian or chinese websites

You can write your own plugins to Splam: simply subclass Splam::Rule. Splam is clever enough
to iterate over all Rule's subclasses and run the 'run' method on the field to be checked.
The other way to do this would be to define Rule.add_rule do ... end but I think the class
form is easier for rubyists to understand and modify.

Splam aggregates the scores from all the rules.  From the brief testing I've done, anything over
about 40 is likely to be spam.  Real spam will blow out of the scoring stratosphere with over 1,000.

Recommended serving directions:

    class Comment
      include Splam
      
      splammable :body
    end
    
    comment = Comment.new :body => "This is spam!!!1"
    comment.splam? # => false
    comment.splam_score # => 2
    comment.splam_reasons # => []

Add this to a model, check the score, and determine (based on other factors such as logged-in
user, time spent on the page, validity of request headers, length of user's membership on the 
site) whether to ban the post or not. 

We recommend showing the post to the user (spambox them in) but hide it from everyone else.

TODO

- Integrate bayesian or other clever algorithm, so that scores aren't hardcoded.
- Switch to using a percentage (0.994) rather than a score (250)
- Write more plugins!
- Test against a larger Ham corpus
- Fix that nasty autoloading code in splam.rb

Copyright (c) 2008 ENTP, released under the MIT license
