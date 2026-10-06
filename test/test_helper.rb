require 'test/unit'
$:.unshift(File.dirname(__FILE__) + '/../lib')
$:.unshift(File.dirname(__FILE__) + '/../lib/splam')

require 'logger'
require 'splam'
require 'splam/rule'
require 'splam/rules'
# the rules load when a class includes Splam; tests may use them before that
Dir[File.dirname(__FILE__) + '/../lib/splam/rules/*.rb'].sort.each { |f| require f }

begin
  require 'ruby-debug'
  Debugger.start
  if Debugger.respond_to?(:settings)
    Debugger.settings[:autoeval] = true
    Debugger.settings[:autolist] = 1
  end
rescue LoadError
  # ruby-debug wasn't available so neither can the debugging be
end
