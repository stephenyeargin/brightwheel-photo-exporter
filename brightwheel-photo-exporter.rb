require 'net/http'
require 'json'
require 'open-uri'
require 'mini_exiftool'
require 'date'

FileUtils.mkdir_p 'data/photos'

data = JSON.load(File.open('data/activities.json'))

i = 0
for activity in data['activities']  
  id = activity['media']['object_id']
  timestamp = activity['event_date']
  photo_url = activity['media']['image_url']

  puts "Downloading data/photos/#{id}.jpg ..."  
  download = open(photo_url)
  IO.copy_stream(download, "data/photos/#{id}.jpg")

  # Update EXIF data
  photo = MiniExiftool.new "data/photos/#{id}.jpg"
  photo.title = activity['media']['object_id']
  photo.artist = activity['actor']['first_name'] + " " + activity['actor']['last_name']
  photo.comment = activity['note']
  photo.create_date = DateTime.parse(activity['created_at'])
  photo.date_time_original = DateTime.parse(activity['created_at'])
  photo.save!
end
