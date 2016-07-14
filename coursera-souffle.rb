require "net/http"
require "json"
require "csv"

class CourseImporter
  QUERY_ENDPOINT = "https://www.coursera.org/api/catalogResults.v2?primaryLanguages=en&debug=false&limit=9999&q=bySubdomain&subdomainId=".freeze
  ADDITIONAL_PARAMS = "&fields=courseId,domainId,specializationId,courses.v1(name,description,photoUrl,courseStatus,partnerIds),partners.v1(name)&includes=courseId,courses.v1(partnerIds)".freeze

  attr_accessor :subdomains, :courses

  def initialize
    self.subdomains = extract_subdomains(subdomains_query)
    self.courses = import_courses
  end

  private

  def subdomains_query
    JSON.parse(Net::HTTP.get(URI(QUERY_ENDPOINT + "true"))) # sneaky
  end

  def courses_query(subdomain_id)
    JSON.parse(Net::HTTP.get(URI(QUERY_ENDPOINT + subdomain_id + ADDITIONAL_PARAMS)))
  end

  def import_courses
    imported_courses = []
    subdomains.each do |subdomain|
      puts "CONTINUE TO STIR"
      courses_query_results = courses_query(subdomain.first)

      extracted_courses = extract_courses(courses_query_results)
      partners = extract_partners(courses_query_results)

      extracted_courses = add_providers_to_courses(partners, extracted_courses)
      extracted_courses = add_subdomain_to_courses(subdomain, extracted_courses)

      imported_courses.concat(extracted_courses)
    end
    puts "STIR IN MILK"
    imported_courses
  end

  def extract_subdomains(query_results)
    query_results["paging"]["facets"]["subdomains"]["facetEntries"].map { |s| [s["id"], s["name"]] }
  end

  def extract_courses(query_results)
    query_results["linked"]["courses.v1"]
  end

  def extract_partners(query_results)
    query_results["linked"]["partners.v1"]
  end

  def add_providers_to_courses(partners, courses)
    courses.map do |c|
      c.merge(
        "providers" => partners.select { |p| c["partnerIds"].include?(p["id"]) }
        .map { |p| p["name"] }
      )
    end
  end

  def add_subdomain_to_courses(subdomain, courses)
    courses.map { |c| c.merge("subdomain" => subdomain.last) }
  end
end

class CSVGenerator
  CSV_HEADERS = ["id", "name", "subdomain", "providers", "description", "course_status", "image_url", "course_type"].freeze

  attr_accessor :records

  def initialize(records)
    self.records = records
  end

  def generate_csv
    CSV.open("./csvs/#{Time.now.to_i}.csv", "w") do |csv|
      csv << CSV_HEADERS

      records.each do |r|
        csv << transform_row(r)
      end
    end
  end

  def transform_row(r)
    [
      r["id"],
      r["name"],
      r["subdomain"],
      r["providers"].join(","),
      r["description"],
      r["courseStatus"],
      r["photoUrl"],
      r["courseType"]
    ]
  end
end

puts "MELT BUTTER IN MEDIUM SAUCEPAN OVER LOW HEAT, ADD FLOUR, SALT AND PEPPER"
c = CourseImporter.new
puts "SEPERATE EGGS, BEAT YOLKS AND COMBINE WITH SAUCE"
csv = CSVGenerator.new(c.courses)
puts "BEAT EGG WHITES AND CREAM OF TARTAR UNTIL STIFF, FOLD INTO SAUCE"
puts "BAKE FOR 20-25 MINUTES, OR UNTIL DONE"
csv.generate_csv
puts "YOUR SOUFFLE IS READY TO ENJOY"
