# frozen-string-literal: true

require 'csv'
require 'google/apis/civicinfo_v2'
require 'erb'
require 'time'
require 'date'

def clean_zipcode(zipcode)
  zipcode.to_s.rjust(5, '0')[0..4]
end

def clean_phone(phone)
  # sanitize input, remove letters, special chars, whitespace, etc.
  phone = phone.gsub(/[^0-9]/, '')

  return 'Bad number' unless phone.size.between?(10, 11)

  return 'Bad number' if phone.size == 11 && phone[0] != 1

  return phone[1..10] if phone[0] == 1 && phone.size == 11

  phone
end

def legislators_by_zipcode(zip)
  civic_info = Google::Apis::CivicinfoV2::CivicInfoService.new
  civic_info.key = 'AIzaSyClRzDqDh5MsXwnCWi0kOiiBivP6JsSyBw'
  begin
    civic_info.representative_info_by_address(
      address: zip,
      levels: 'country',
      roles: %w[legislatorUpperBody legislatorLowerBody]
    ).officials
  rescue
    'You can find your representatives by visiting www.commoncause.org/take-action/find-elected-officials'
  end
end

def save_thank_you_letter(id, form_letter)
  Dir.mkdir('output') unless Dir.exist?('output')
  filename = "output/thanks_#{id}.html"
  File.open(filename, 'w') do |file|
    file.puts form_letter
  end
end

# Finds the best hour, and returns it
def analyze_reg_times(reg_times)
  reg_times.group_by { |time| Time.strptime(time, '%m/%d/%Y %H:%M').hour }.max_by { |_k, v| v.size }[0]
end

def find_best_day(reg_times)
  weekdays = %w[Sunday Monday Tuesday Wednesday Thursday Friday Saturday]
  wday = reg_times.group_by { |date| Date.strptime(date, '%m/%d/%Y %H:%M').wday }.max_by { |_k, v| v.size }[0]
  weekdays[wday]
end

puts 'EventManager Initialized.'

contents = CSV.open(
  'event_attendees.csv',
  headers: true,
  header_converters: :symbol
)

template_letter = File.read('form_letter.erb')
erb_template = ERB.new template_letter

reg_times = []

contents.each do |row|
  id = row[0]
  name = row[:first_name]
  zipcode = clean_zipcode(row[:zipcode])
  phone = clean_phone(row[:homephone])
  regdate = row[:regdate]
  reg_times << regdate
  legislators = legislators_by_zipcode(zipcode)
  form_letter = erb_template.result(binding)
  save_thank_you_letter(id, form_letter)
end

best_hour = analyze_reg_times(reg_times)
puts "The best hour to run ads is #{best_hour}."
best_day = find_best_day(reg_times)
puts "The day of the week with the most registrations is #{best_day}."
