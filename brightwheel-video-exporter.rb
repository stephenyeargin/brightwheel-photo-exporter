require 'net/http'
require 'json'
require 'open-uri'
require 'mini_exiftool'
require 'date'
require 'dotenv'

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
  req["Accept"] = 'application/json'
  req.body = ({user: {email: username, password: password}}).to_json
  res = http.request(req)
  return res.header['set-cookie'].split('; ')[0]
rescue => e
  puts "failed #{e}"
  exit(1)
end

def get_activities(auth)
  uri = URI("https://schools.mybrightwheel.com/api/v1/students/#{ENV['BRIGHTWHEEL_STUDENT_ID']}/activities?page=0&page_size=500&action_type=ac_video")
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true
  req = Net::HTTP::Get.new(uri, @headers)
  req.content_type = 'application/json'
  req["Accept"] = 'application/json'
  req['Cookie'] = auth
  res = http.request(req)
  json = JSON.parse(res.body)
  return json
rescue => e
  puts "failed #{e}"
  exit(1)
end

# Login and get activities
if File.exist?('data/activities-videos.json')
  puts '[WARNING] Loading from saved activities feed. Skipping login.'
  data = JSON.parse(File.open('data/activities-videos.json').read)
else
  auth = login(ENV['BRIGHTWHEEL_EMAIL'], ENV['BRIGHTWHEEL_PASSWORD'])
  data = get_activities(auth)
end

unless FileUtils.mkdir_p 'data/videos'
  puts "Could not create directory"
  exit(1)
end

i = 0
for activity in data['activities']
  next if activity['video_info'].nil?
  id = activity['video_info']['object_id']
  timestamp = activity['event_date']
  video_url = activity['video_info']['downloadable_url']

  puts "Downloading data/videos/#{id}.mp4 ..."
  download = URI.open(video_url)
  IO.copy_stream(download, "data/videos/#{id}.mp4")

  # Update EXIF data
  video = MiniExiftool.new "data/videos/#{id}.mp4"
  video.title = activity['video_info']['object_id']
  video.artist = activity['actor']['first_name'] + " " + activity['actor']['last_name']
  video.comment = activity['note']
  video.create_date = DateTime.parse(activity['created_at'])
  video.date_time_original = DateTime.parse(activity['created_at'])
  video.save!
end
