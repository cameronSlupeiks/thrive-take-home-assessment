require "json"

# File paths
COMPANIES_FILE = "companies.json"
USERS_FILE = "users.json"
OUTPUT_FILE = "output.txt"

# Read and validate data from a JSON file.
#
# @param filepath [String] the path to the JSON file.
# @param validation_proc [Proc] a validation procedure to apply to each data entry.
# @return [Array<Hash>] the validated data from the JSON file.
def read_and_validate_data(filepath, validation_proc)
  begin
    file = File.read(filepath)
    data = JSON.parse(file)
    data.select { |entry| validation_proc.call(entry) }
  rescue Errno::ENOENT
    puts "Error: File not found - #{filepath}"
    []
  rescue JSON::ParserError
    puts "Error: Invalid JSON in file - #{filepath}"
    []
  end
end

# Validate company data.
#
# @param company [Hash] the company data.
# @return [Boolean] true if the data is valid, false otherwise.
def valid_company?(company)
  required_keys = ["id", "name", "top_up", "email_status"]
  required_keys.all? { |key| company.key?(key) }
end

# Validate user data.
#
# @param user [Hash] the user data.
# @return [Boolean] true if the data is valid, false otherwise.
def valid_user?(user)
  required_keys = ["id", "first_name", "last_name", "email", "company_id", "email_status", "active_status", "tokens"]
  required_keys.all? { |key| user.key?(key) }
end

# Format a string with a number of spaces.
#
# @param num_spaces [Integer] the number of spaces.
# @return [String] the formatted string.
def format_spacing(num_spaces)
  " " * num_spaces
end

# Write user details to the file.
#
# @param file [File] the file object to write to.
# @param users [Array<Hash>] the list of users.
# @param top_up [Integer] the token top up amount.
# @param prefix [String] the prefix for the section (e.g., "Users Emailed").
def write_users(file, users, top_up, prefix)
  file.puts format_spacing(4) + prefix
  users.each do |user|
    file.puts format_spacing(8) + "#{user["last_name"]}, #{user["first_name"]}, #{user["email"]}"
    file.puts format_spacing(10) + "Previous Token Balance: #{user["tokens"]}"
    new_balance = user["active_status"] ? user["tokens"] + top_up : user["tokens"]
    file.puts format_spacing(10) + "New Token Balance: #{new_balance}"
  end
end

# Write final output to a text file.
#
# @param companies [Array<Hash>] the companies data.
def write_output(companies)
  begin
    File.open(OUTPUT_FILE, "w") do |file|
      companies.each_with_index do |company, index|
        file.puts format_spacing(4) + "Company Id: #{company["id"]}"
        file.puts format_spacing(4) + "Company Name: #{company["name"]}"

        # Write categorized users
        write_users(file, company["emailed_users"], 0, "Users Emailed:")
        write_users(file, company["not_emailed_users"], company["top_up"], "Users Not Emailed:")

        # Write total top ups for company
        total_top_up = company["not_emailed_users"].sum { |user| user["active_status"] ? company["top_up"] : 0 }
        file.puts format_spacing(8) + "Total Top Ups for #{company["name"]}: #{total_top_up}"

        file.puts unless index == companies.size - 1
      end
    end
  rescue IOError
    puts "Error: Unable to write to file - #{OUTPUT_FILE}"
  end
end

def main
  # Read and validate data
  companies = read_and_validate_data(COMPANIES_FILE, method(:valid_company?))
  users = read_and_validate_data(USERS_FILE, method(:valid_user?))

  return if companies.empty? || users.empty?

  # Sort companies by ID
  companies.sort_by! { |company| company["id"].to_i }

  # Group users by company and categorize
  users_by_company = users.group_by { |user| user["company_id"] }

  companies.each do |company|
    company_users = users_by_company[company["id"]] || []
    emailed_users = []
    not_emailed_users = []

    company_users.each do |user|
      if company["email_status"] && user["email_status"]
        emailed_users << user
      else
        not_emailed_users << user
      end
    end

    # Sort users by last name
    company["emailed_users"] = emailed_users.sort_by { |user| user["last_name"] }
    company["not_emailed_users"] = not_emailed_users.sort_by { |user| user["last_name"] }
  end

  # Write output
  write_output(companies)
end

if __FILE__ == $0
  main
end
