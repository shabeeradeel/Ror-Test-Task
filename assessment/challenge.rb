require 'json'
require 'pp'


REQUIRED_USER_KEYS = %w[company_id tokens email_status active_status].freeze

# Load JSON data from files
def load_json(file)
  JSON.parse(File.read(file))
rescue JSON::ParserError => e
  puts "Error parsing JSON from #{file}: #{e.message}"
  []
end

def valid_user?(user)
  REQUIRED_USER_KEYS.all? { |key| !user[key].nil? && !user[key].to_s.empty? }
end

def process_data(users, companies)
  companies_hash = companies.each_with_object({}) { |company, hash| hash[company['id']] = company }
  
  # Grouping users by company_id and filtering out invalid users
  users_by_company = users.select { |user| valid_user?(user) }.group_by { |user| user['company_id'] }
  
  file_output_lines= []
    
  # Process each company
  companies_hash.each do |company_id, company|
    company_users = users_by_company[company_id]
    next unless company_users
    
    # Sort users by last name
    sorted_users = company_users.sort_by { |user| user['last_name'] }
    
    users_emailed = []
    users_not_emailed = []
    total_top_up = 0
    
    # Process each user
    sorted_users.each do |user|
      next unless user['active_status']

      top_up_amount = company['top_up'].to_i # Ensure it's an integer
      new_balance = user['tokens'].to_i + top_up_amount # Ensure tokens are treated as integers
      total_top_up += top_up_amount
      
      # Determine if an email should be sent
      user['email_status'] && company['email_status'] ? users_emailed << formatted_users(user, new_balance) : users_not_emailed << formatted_users(user, new_balance)
      
      # Update the user's token balance (though not persisted)
      user['tokens'] = new_balance
    end
    
    file_output_lines << "Company Id: #{company['id']}"
    file_output_lines << "Company Name: #{company['name']}"

    file_output_lines << "Users Emailed:"
    users_emailed.empty? ? file_output_lines << "\tNo Users Found." : file_output_lines.concat(users_emailed)

    file_output_lines << "Users Not Emailed:"
    users_not_emailed.empty? ? file_output_lines << "\tNo Users Found." : file_output_lines.concat(users_not_emailed)

    file_output_lines << "\tTotal amount of top ups for #{company['name']}: #{total_top_up}\n\n"
  end
  file_output_lines
end

def formatted_users(user, new_balance)
  "\t#{user['last_name']}, #{user['first_name']}, #{user['email']}\n\t  Previous Token Balance: #{user['tokens']}\n\t  New Token Balance: #{new_balance}"
end

def write_output(filename, output_lines)
  File.open(filename, 'w') do |file|
    file.puts output_lines
  end
end

def main
  users = load_json('users.json')
  companies = load_json('companies.json')
  
  file_output_lines = process_data(users, companies)
  write_output('output.txt', file_output_lines)
  puts "Output written to output.txt"

rescue StandardError => e
  puts "An unexpected error occurred: #{e.message}"
end

main
