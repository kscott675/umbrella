begin
require "bundler/setup"
require "http"
require "json"
require "time"
require "active_support/all"
require "ascii_charts"
Bundler.require

class App
  GMAPS_KEY = ENV['GMAPS_KEY']
  PIRATE_WEATHER_KEY = ENV['PIRATE_WEATHER_KEY']


  def get_coordinates(location)
    gmaps_url = "https://maps.googleapis.com/maps/api/geocode/json?address=" + location + "&key=" + GMAPS_KEY
    gmaps_raw_response = HTTP.get(gmaps_url)
    gmaps_parsed_response = JSON.parse(gmaps_raw_response)

    latitude = gmaps_parsed_response.dig('results', 0, 'geometry', 'location', 'lat')
    longitude = gmaps_parsed_response.dig('results', 0, 'geometry', 'location', 'lng')

    # Remove spaces and square brackets from coordinates
    coordinates = "#{latitude},#{longitude}"
    coordinates = coordinates.to_s.gsub(/[\s\[\]]/, '')

    puts ""
    puts location = gmaps_parsed_response.dig('results', 0, 'formatted_address')
    coordinates # Return coordinates
  rescue JSON::ParserError
    puts "Unable to complete request. Try again later."
    nil  # Return nil in case of an error
  end

  def get_weather(coordinates, location)
    pirate_weather_url = "https://api.pirateweather.net/forecast/" + PIRATE_WEATHER_KEY + "/#{coordinates.gsub(/\s+/, '')}"
    pirate_raw_response = HTTP.get(pirate_weather_url)
    pirate_parsed_response = JSON.parse(pirate_raw_response)
    degree_sign = "\u00B0"
    
    time_zone = pirate_parsed_response.dig('timezone')
    current_time = Time.current.in_time_zone(time_zone)
    formatted_time = current_time.strftime('%l:%M%P').strip

    # Define epoch time - get current time and convert it to epoch
    epoch_in_an_hour = current_time + 1.hour
    current_epoch = current_time.to_i
    epoch_in_an_hour = epoch_in_an_hour.to_i

    # Parse for hourly next_hour_temp =
    rounded_time = (current_epoch.to_f / 3600.0).round * 3600

    hourly_data_array = pirate_parsed_response.dig("hourly", "data")

    if hourly_data_array.nil? || hourly_data_array.empty?
      puts "No hourly weather data available."
      return nil
    end

    time_index = nil
    hourly_data_array.each_with_index do |weather_hash, index|
      if weather_hash["time"] == rounded_time
        time_index = index
        break # Stop iterating once the match is found
      end
    end

    current_temp = pirate_parsed_response.dig("currently", "temperature").floor
    next_hour_summary = hourly_data_array.dig(time_index, "summary")
    next_hour_temp = hourly_data_array.dig(time_index, "temperature").floor
    puts "#{next_hour_summary}"
    puts "#{formatted_time}"
    puts "#{current_temp}#{degree_sign}\n"
    puts ""


    precipProbability = []
    precipitation = 0
    temp_time_array = []

    prompt = TTY::Prompt.new

    # Ask the user if they want to see the temperature for the next hour
    response = prompt.yes?("\nWould you like to see the precipitation for the next 12 hours?")
  begin
    if response

      hourly_data_array.drop(time_index).each do |weather_hash|
        upcoming_time = Time.at(weather_hash["time"])
        upcoming_time = upcoming_time.in_time_zone(time_zone)
        upcoming_time = upcoming_time.strftime('%l:%M%P')

        temperature = weather_hash["temperature"].floor
        summary = weather_hash["summary"]
        chance_of_precip = weather_hash["precipProbability"] * 100

        temp_time_array.push([temp_time_array.size, temperature])
      
        precipProbability.push([precipProbability.size+1,chance_of_precip])

        precipitation += chance_of_precip
      end

      temperatures = hourly_data_array.map { |weather_hash| weather_hash['temperature'].floor }
      times = hourly_data_array.map { |weather_hash| Time.at(weather_hash['time']).strftime('%l:%M%P') }
      
      # Display the chart

      precipProbability.slice!(12..-1)
      temp_time_array.slice!(13..-1)
      puts ""
      puts "Temperature for the next 12 hours:"
      temp_graph = AsciiCharts::Cartesian.new(temp_time_array, :bar => true, :hide_zero => false)
      puts temp_graph.draw
      sleep 5
      puts ""

      puts "Precipitation for the next 12 hours:"
      graph = AsciiCharts::Cartesian.new(precipProbability, :bar => true, :hide_zero => false)
      puts graph.draw
      if precipitation >= 420
        puts "You might want to bundle up or bring an umbrella!" 
      end
      puts "Enjoy your day!"
      puts ""
      puts "Thanks for using 'Weather You Like it or Not'! "
      puts "Developed By: Kiowa Scott"
      exit
     else
      puts "Thanks for using 'Weather You Like it or Not'! "
      puts "Developed By: Kiowa Scott"
      exit
     end
    end
  rescue JSON::ParserError => e
    puts "An unexpected error occurred while parsing JSON."
    puts e.message
    exit
  rescue TTY::Reader::InputInterrupt
    exit
    rescue StandardError
      puts "Please refresh and try again."
      exit
  end
end
end

puts ""
puts "Weather You Like it or Not: Reliable Weather Forecasting"
puts ""
sleep 1
print "Please enter your location: "
location = gets.chomp.to_s

app = App.new
coordinates = app.get_coordinates(location)
app.get_weather(coordinates, location)
