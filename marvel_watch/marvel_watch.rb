require 'scout'
require 'json'

class MarvelWatch < Scout::Plugin
  def build_report
    uri = URI.parse('http://localhost:9200/_aliases')
    response = JSON.parse(Net::HTTP.get(uri))
    marvel_indexes = response.keys.grep(/marvel/)

    report({
      number_of_marvel_indexes: marvel_indexes.length
    })
  end
end
