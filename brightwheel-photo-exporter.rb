require 'net/http'
require 'json'
require 'open-uri'
require 'mini_exiftool'
require 'date'
require 'dotenv'
require 'optparse'
require 'optparse/time'

Dotenv.load

@headers = {
  "X-Client-Name": "web",
  "X-Client-Version": "b15cec31e66fa803de35b53260872aa7e5e84e29"
}
def login(username, password)
  uri = URI('https://schools.mybrightwheel.com/api/v1/sessions')
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true
  req = Net::HTTP::Post.new(uri.path, @headers)
  req.content_type = 'application/json'
  req['Accept'] = 'application/json'
  req.body = { user: { email: username, password: password } }.to_json
  res = http.request(req)
  res.header['set-cookie'].split('; ')[0]
rescue RuntimeError => e
  puts "failed #{e}"
  exit(1)
end

def get_activities(auth, options)
  uri = URI("https://schools.mybrightwheel.com/api/v1/students/#{ENV['BRIGHTWHEEL_STUDENT_ID']}/activities?page=0&page_size=500&start_date=#{options[:since]}&action_type=ac_photo")
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true
  req = Net::HTTP::Get.new(uri, @headers)
  req.content_type = 'application/json'
  req['Accept'] = 'application/json'
  req['Cookie'] = auth
  res = http.request(req)
  JSON.parse(res.body)
rescue RuntimeError => e
  puts "failed #{e}"
  exit(1)
end

options = { since: DateTime.parse('2000-01-01').iso8601(3) }
OptionParser.new do |parser|
  parser.on('-s', '--since [SINCE]', Time, 'Return only photos after SINCE.') do |time|
    options[:since] = time.iso8601(3)
  end
end.parse!

# Login and get activities
if File.exist?('data/activities.json')
  puts '[WARNING] Loading from saved activities feed. Skipping login.'
  data = JSON.parse(File.open('data/activities.json').read)
else
  auth = login(ENV['BRIGHTWHEEL_EMAIL'], ENV['BRIGHTWHEEL_PASSWORD'])
  data = get_activities(auth, since: options[:since])
end

FileUtils.mkdir_p 'data/photos'

data['activities'].each do |activity|
  next if activity['media'].nil?

  id = activity['media']['object_id']
  photo_url = activity['media']['image_url']

  puts "Downloading data/photos/#{id}.jpg ..." 
  download = URI.open(photo_url)
  IO.copy_stream(download, "data/photos/#{id}.jpg")

  # Update EXIF data
  photo = MiniExiftool.new "data/photos/#{id}.jpg"
  photo.title = activity['media']['object_id']
  photo.artist = "#{activity['actor']['first_name']} #{activity['actor']['last_name']}"
  photo.comment = activity['note']
  photo.create_date = DateTime.parse(activity['created_at'])
  photo.date_time_original = DateTime.parse(activity['created_at'])
  photo.save!
end
