class Splam::Rules::GoodWords < Splam::Rule
  
  def run
    good_words = [ /I\'having a problem/, ]
    good_words |= %w( lighthouse lighthouseapp activereload  warehouse install eclipse settings assigned user ticket tickets token api number query request)
    good_words |= %w( browser feed firefox safari skitch vendor rails action_controller railties )
    good_words |= %w( redirect login diff dreamhost setup subversion git  wildcard domain subdomain ssh database )
    good_words |= %w( project billing tags description comment milestone saving happening feature mac implement report)
    good_words |= %w( rss notification subscribe calendar chart note task gantt search service ownership application communicate )
    good_words |= %w( interaction API tickets hosted domain skitch )
    good_words |= %w( pattern template web integer status xml activereload html state page rack diff )
    good_words << "project management"
    good_words << "/usr/local/lib" << "gems"

    body = @body.downcase
    good_words.each { |rule| 
      
      results = Regexp.new("\\b(#{rule})\\b","i").match(body)
      add_score -50 * results.size, "relevant word match: #{rule}" if results
    }
  end
end